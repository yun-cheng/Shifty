//
//  AccessibilityWindow.swift
//  Shifty
//
//  Created by Nate Thompson on 1/1/18.
//

import Cocoa
import AXSwift
import SwiftLog

class AccessibilityWindow: NSWindowController {

    @IBOutlet weak var notNowButton: NSButton!
    @IBOutlet weak var openSysPrefsButton: NSButton!
    
    private(set) var wasGranted = false
    private var isWaiting = false
    private var pollingThread: Thread?
    
    override var windowNibName: NSNib.Name {
        get { return "AccessibilityWindow" }
    }
    
    override func windowDidLoad() {
        window?.center()
        
        notNowButton.title = NSLocalizedString("alert.not_now", comment: "Not now")
        openSysPrefsButton.title = NSLocalizedString("alert.open_preferences", comment: "Open System Preferences")
    }
    
    @IBAction func openSysPrefsClicked(_ sender: Any) {
        // Register the current process with TCC so the app appears in the list
        let options = [kAXTrustedCheckOptionPrompt.takeUnretainedValue() as String: true] as CFDictionary
        AXIsProcessTrustedWithOptions(options)
        
        NSWorkspace.shared.open(
            URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility")!)
        
        // Switch to waiting state
        openSysPrefsButton.title = NSLocalizedString("accessibility.waiting", comment: "Waiting for access...")
        openSysPrefsButton.isEnabled = false
        notNowButton.title = NSLocalizedString("general.cancel", comment: "Cancel")
        
        isWaiting = true
        startPollingThread()
    }
    
    @IBAction func notNowClicked(_ sender: Any) {
        isWaiting = false
        pollingThread?.cancel()
        window?.close()
        NSApp.stopModal()
    }
    
    @IBAction func helpClicked(_ sender: Any) {
        NSWorkspace.shared.open(
            URL(string: "https://support.apple.com/guide/mac-help/allow-accessibility-apps-to-access-your-mac-mh43185")!)
    }
    
    /// Live probe: try reading a system-wide AX attribute.
    /// AXIsProcessTrusted() caches per-process (TCC decision at first call).
    /// AXUIElementCopyAttributeValue goes through AX IPC → Window Server,
    /// which can re-check TCC in real-time.
    private func probeAccessibilityViaAX() -> Bool {
        let systemWide = AXUIElementCreateSystemWide()
        var value: CFTypeRef?
        let error = AXUIElementCopyAttributeValue(
            systemWide,
            "AXFocusedApplication" as CFString,
            &value)
        return error != .apiDisabled
    }
    
    /// Polls on a background thread where AXIsProcessTrusted() is cached,
    /// so we use a live AX probe instead.
    private func startPollingThread() {
        pollingThread?.cancel()
        pollingThread = Thread { [weak self] in
            while !Thread.current.isCancelled {
                Thread.sleep(forTimeInterval: 1.0)
                
                guard let self = self else { return }
                guard self.isWaiting else { return }
                
                // AXIsProcessTrusted() is cached per-process — also check
                // via live AX IPC to get real-time TCC state.
                if AXIsProcessTrusted() || self.probeAccessibilityViaAX() {
                    DispatchQueue.main.async {
                        guard self.isWaiting else { return }
                        logw("Accessibility permission granted — auto-closing window")
                        self.wasGranted = true
                        self.isWaiting = false
                        self.openSysPrefsButton.title = NSLocalizedString("accessibility.granted", comment: "Granted ✓")
                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                            self.window?.close()
                            NSApp.stopModal()
                        }
                    }
                    return
                }
            }
        }
        pollingThread?.name = "com.shifty.accessibility-poll"
        pollingThread?.start()
    }
}