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
    
    private func isFrontmostAppFullscreen() -> Bool {
        guard let app = NSWorkspace.shared.frontmostApplication else { return false }
        
        let axApp = AXUIElementCreateApplication(app.processIdentifier)
        var focusedWindow: CFTypeRef?
        let result = AXUIElementCopyAttributeValue(
            axApp,
            "AXFocusedWindow" as CFString,
            &focusedWindow
        )
        
        guard result == .success, let win = focusedWindow else { return false }
        
        var fullscreenVal: CFTypeRef?
        AXUIElementCopyAttributeValue(
            win as! AXUIElement,
            "AXFullScreen" as CFString,
            &fullscreenVal
        )
        
        return (fullscreenVal as? Bool) ?? false
    }
}