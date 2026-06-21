//
//  NightShiftManager.swift
//  Shifty
//
//  Created by Saagar Jha on 1/13/18.
//

import Cocoa
import SwiftLog


class NightShiftManager {
    static let shared = NightShiftManager()
    let client = CBBlueLightClient.shared
    
    var nightShiftChangeListeners = [() -> Void]()

    var userSet: UserSet = .notSet
    var previousFullscreenState: UserSet = .off
    var isFullscreenActive = false
    var userInitiatedShift = false
    var selectedPresetCt: Float = 0.619 // default 4200K
    
    /// Current effective color temperature in Kelvin for external displays
    var currentKelvin: Int {
        let ct = colorTemperature
        let kelvin = 5500.0 - Double(ct) * 2100.0
        return Int(kelvin)
    }
    
    static var supportsNightShift: Bool {
        CBBlueLightClient.supportsNightShift
    }
    
    var isNightShiftEnabled: Bool {
        get {
            client.isNightShiftEnabled
        }
        set {
            setNightShiftEnabled(to: newValue)
        }
    }
    
    var colorTemperature: Float {
        get {
            client.blueLightReductionAmount
        }
        set {
            client.blueLightReductionAmount = newValue
        }
    }
    
    var schedule: ScheduleType {
        get {
            client.schedule
        }
        set {
            client.schedule = newValue
        }
    }
    
    var nightShiftDisableTimerState = DisableTimer.off
    var nightShiftDisableTimer: Timer? {
        willSet {
            if let timer = nightShiftDisableTimer {
                timer.invalidate()
            }
        }
    }
    
    var isDisabledWithTimer: Bool {
        return nightShiftDisableTimerState != .off
    }
    
    /// When true, app or website rule has disabled Night Shift
    var isDisableRuleActive: Bool {
        return RuleManager.shared.disableRuleIsActive
    }

    init() {
        var prevSchedule = client.schedule
        
        updateDarkMode()
        
        // @convention block called by CoreBrightness
        client.setStatusNotificationBlock {
            if self.schedule == prevSchedule {
                self.respond(to: self.isNightShiftEnabled
                        ? .enteredScheduledNightShift : .exitedScheduledNightShift)
            } else {
                self.respond(to: .scheduleChanged)
                prevSchedule = CBBlueLightClient.shared.schedule
            }
            
            self.updateDarkMode()
            
            for listener in self.nightShiftChangeListeners {
                DispatchQueue.main.async {
                    listener()
                }
            }
        }
        
        NSWorkspace.shared.notificationCenter.addObserver(forName: NSWorkspace.didWakeNotification, object: nil, queue: nil) { _ in
            logw("Wake from sleep notification posted")
            
            if CBBlueLightClient.shared.scheduledState !=
                CBBlueLightClient.shared.isNightShiftEnabled
            {
                self.respond(to: CBBlueLightClient.shared.scheduledState
                        ? .enteredScheduledNightShift : .exitedScheduledNightShift)
            }
            
            self.updateDarkMode()
        }
        
        // Sync gamma to current Night Shift state at startup
        updateExternalDisplays()
    }
    
    func onNightShiftChange(_ listener: @escaping () -> Void) {
        nightShiftChangeListeners.append(listener)
    }
    
    func updateDarkMode() {
        if UserDefaults.standard.bool(forKey: Keys.isDarkModeSyncEnabled) {
            let scheduledState = client.scheduledState
            
            switch client.schedule {
            case .off:
                let darkModeState = isNightShiftEnabled || isDisableRuleActive || isDisabledWithTimer || userSet == .on
                SLSSetAppearanceThemeLegacy(darkModeState)
                logw("Dark mode set to \(darkModeState)")
            case .solar:
                SLSSetAppearanceThemeLegacy(scheduledState)
                logw("Dark mode set to \(scheduledState)")
            case .custom(start: _, end: _):
                SLSSetAppearanceThemeLegacy(scheduledState)
                logw("Dark mode set to \(scheduledState)")
            }
        }
    }
    
    func setNightShiftEnabled(to state: Bool) {
        respond(to: state ? .userEnabledNightShift : .userDisabledNightShift)
    }

    func respond(to event: NightShiftEvent) {
        //Prevent BlueLightNotification from triggering one of these two events after every event
        if event == .enteredScheduledNightShift || event == .exitedScheduledNightShift {
            if userInitiatedShift {
                userInitiatedShift = false
                return
            } else {
                userInitiatedShift = false
            }
        } else {
            userInitiatedShift = true
        }
        
        switch event {
        case .enteredScheduledNightShift:
            userSet = .notSet
            if isDisabledWithTimer || isDisableRuleActive {
                client.setNightShiftEnabled(false)
            }
        case .exitedScheduledNightShift:
            userSet = .notSet
        case .userEnabledNightShift:
            userSet = .on
            nightShiftDisableTimerState = .off
            
            if isDisableRuleActive {
                RuleManager.shared.removeRulesForCurrentState()
            }
            client.setNightShiftEnabled(true)
        case .userDisabledNightShift:
            client.setNightShiftEnabled(false)
            userSet = .off
        case .nightShiftDisableRuleActivated:
            client.setNightShiftEnabled(false)
            if UserDefaults.standard.bool(forKey: Keys.trueToneControl) {
                if #available(macOS 10.14, *) {
                    CBTrueToneClient.shared.isTrueToneEnabled = false
                }
            }
        case .nightShiftDisableRuleDeactivated:
            if !isDisabledWithTimer && !isDisableRuleActive {
                switch userSet {
                case .notSet:
                    client.setToSchedule()
                case .on:
                    client.setNightShiftEnabled(true)
                case .off:
                    client.setNightShiftEnabled(false)
                }
            }
            
            if !isDisableRuleActive && UserDefaults.standard.bool(forKey: Keys.trueToneControl) {
                if #available(macOS 10.14, *) {
                    CBTrueToneClient.shared.isTrueToneEnabled = true
                }
            }
        case .nightShiftEnableRuleActivated:
            switch userSet {
            case .on, .notSet:
                client.setNightShiftEnabled(true)
            case .off:
                client.setNightShiftEnabled(false)
            }
        case .nightShiftEnableRuleDeactivated:
            if isDisabledWithTimer || isDisableRuleActive {
                client.setNightShiftEnabled(false)
            } else {
                client.setToSchedule()
            }
        case .nightShiftDisableTimerStarted:
            client.setNightShiftEnabled(false)
        case .nightShiftDisableTimerEnded:
            if !isDisableRuleActive {
                switch userSet {
                case .notSet:
                    client.setToSchedule()
                case .on:
                    client.setNightShiftEnabled(true)
                case .off:
                    client.setNightShiftEnabled(false)
                }
            }
        case .fullscreenDisableActivated:
            previousFullscreenState = userSet
            isFullscreenActive = true
            client.setNightShiftEnabled(false)
        case .fullscreenDisableDeactivated:
            isFullscreenActive = false
            if !isDisabledWithTimer && !isDisableRuleActive {
                switch previousFullscreenState {
                case .notSet:
                    client.setToSchedule()
                case .on:
                    client.setNightShiftEnabled(true)
                case .off:
                    client.setNightShiftEnabled(false)
                }
            }
        case .scheduleChanged:
            userSet = .notSet
            client.setToSchedule()
        }
        logw("Responded to event: \(event)")
        updateExternalDisplays()
    }
    
    func updateExternalDisplays() {
        let effectiveState = client.isNightShiftEnabled && !isDisableRuleActive && !isDisabledWithTimer && !isFullscreenActive
        DisplayGammaController.shared.sync(active: effectiveState, colorTemperature: selectedPresetCt)
    }
    
    
    func setDisableTimer(forTimeInterval timeInterval: TimeInterval) {
        DispatchQueue.main.async {
            let disableTimer = Timer.scheduledTimer(
                withTimeInterval: timeInterval,
                repeats: false,
                block: { _ in
                    self.nightShiftDisableTimerState = .off
                    self.respond(to: .nightShiftDisableTimerEnded)
                })
            
            // For longer timers, increase the tolerance to save resources
            if timeInterval > 1800 {
                disableTimer.tolerance = 60
            } else if timeInterval > 300 {
                disableTimer.tolerance = 10
            }
            
            if timeInterval.rounded() == 3600 {
                self.nightShiftDisableTimerState = .hour(endDate: disableTimer.fireDate)
            } else {
                self.nightShiftDisableTimerState = .custom(endDate: disableTimer.fireDate)
            }
            
            self.nightShiftDisableTimer = disableTimer
            self.respond(to: .nightShiftDisableTimerStarted)
        }
    }
    
    func invalidateDisableTimer() {
        nightShiftDisableTimerState = .off
        respond(to: .nightShiftDisableTimerEnded)
    }
}

enum NightShiftEvent {
    case enteredScheduledNightShift
    case exitedScheduledNightShift
    case userEnabledNightShift
    case userDisabledNightShift
    case nightShiftDisableTimerStarted
    case nightShiftDisableTimerEnded
    case nightShiftDisableRuleActivated
    case nightShiftDisableRuleDeactivated
    case nightShiftEnableRuleActivated
    case nightShiftEnableRuleDeactivated
    case fullscreenDisableActivated
    case fullscreenDisableDeactivated
    case scheduleChanged
}

enum UserSet {
    case notSet
    case on
    case off
}

enum DisableTimer: Equatable {
    case off
    case hour(endDate: Date)
    case custom(endDate: Date)
    
    static func == (lhs: DisableTimer, rhs: DisableTimer) -> Bool {
        switch (lhs, rhs) {
        case (.off, .off):
            return true
        case (let .hour(leftDate), let .hour(rightDate)),
             (let .custom(leftDate), let .custom(rightDate)):
            return leftDate == rightDate
        default:
            return false
        }
    }
}
