//
//  FullscreenManager.swift
//  Shifty
//
//  Created by Zeke on 6/21/26.
//

import Cocoa
import SwiftLog

class FullscreenManager {
    static let shared = FullscreenManager()
    
    private var monitorTimer: Timer?
    private var isFullscreenActive = false
    private var isObserving = false
    
    private init() {}
    
    func startMonitoring() {
        guard !isObserving else { return }
        isObserving = true
        
        monitorTimer?.invalidate()
        monitorTimer = Timer.scheduledTimer(
            withTimeInterval: 1.0,
            repeats: true
        ) { [weak self] _ in
            self?.checkFullscreenState()
        }
        
        // Also observe app changes for responsiveness
        NSWorkspace.shared.notificationCenter.addObserver(
            self,
            selector: #selector(checkFullscreenState),
            name: NSWorkspace.didActivateApplicationNotification,
            object: nil
        )
        
        logw("Fullscreen monitoring started")
    }
    
    func stopMonitoring() {
        monitorTimer?.invalidate()
        monitorTimer = nil
        isObserving = false
        isFullscreenActive = false
        logw("Fullscreen monitoring stopped")
    }
    
    @objc private func checkFullscreenState() {
        guard UserDefaults.standard.bool(forKey: Keys.isFullscreenControlEnabled) else {
            if isFullscreenActive {
                logw("Fullscreen control disabled while fullscreen was active — restoring")
                isFullscreenActive = false
                NightShiftManager.shared.respond(to: .fullscreenDisableDeactivated)
            }
            return
        }
        
        let isNowFullscreen = isFrontmostAppFullscreen()
        
        if isNowFullscreen && !isFullscreenActive {
            isFullscreenActive = true
            logw("Fullscreen detected — disabling Night Shift")
            NightShiftManager.shared.respond(to: .fullscreenDisableActivated)
        } else if !isNowFullscreen && isFullscreenActive {
            isFullscreenActive = false
            logw("Exited fullscreen — restoring Night Shift")
            NightShiftManager.shared.respond(to: .fullscreenDisableDeactivated)
        }
    }
    
    /// Returns the frontmost running application with a regular window.
    /// Uses frontmostApplication as primary (deprecated but still works),
    /// falls back to runningApplications for future macOS compatibility.
    private func frontmostApp() -> NSRunningApplication? {
        if let app = NSWorkspace.shared.frontmostApplication {
            return app
        }
        return NSWorkspace.shared.runningApplications
            .first(where: { $0.activationPolicy == .regular && $0.isActive })
    }
    
    /// Check if the frontmost app has any window in fullscreen mode.
    /// Uses CGWindowListCopyWindowInfo (Window Server API) instead of AX API,
    /// so this works without Accessibility permissions.
    private func isFrontmostAppFullscreen() -> Bool {
        guard let app = frontmostApp() else { return false }
        
        let windowInfoList = CGWindowListCopyWindowInfo(
            .optionOnScreenOnly,
            kCGNullWindowID
        ) as? [[CFString: Any]] ?? []
        
        let pid = app.processIdentifier
        guard let mainScreen = NSScreen.main else { return false }
        let screenFrame = mainScreen.frame
        
        for info in windowInfoList {
            guard (info[kCGWindowOwnerPID] as? Int32) == pid,
                  (info[kCGWindowLayer] as? Int) == 0,
                  let bounds = info[kCGWindowBounds] as? [String: CGFloat],
                  let w = bounds["Width"],
                  let h = bounds["Height"]
            else { continue }
            
            // Fullscreen windows cover the entire screen area.
            // Allow small tolerance for menu bar / dock differences.
            let coversScreen = abs(w - screenFrame.width) < 1 && abs(h - screenFrame.height) < 1
            if coversScreen {
                return true
            }
        }
        
        return false
    }
}