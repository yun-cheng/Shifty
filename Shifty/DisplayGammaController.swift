//
//  DisplayGammaController.swift
//  Shifty
//
//  Created by Zeke on 6/21/26.
//

import Cocoa
import CoreGraphics
import SwiftLog

/// Applies gamma-ramp-based color temperature adjustment to external displays.
/// Night Shift via CoreBrightness only works on built-in displays; this utility
/// uses CGSetDisplayTransferByTable to simulate the effect on any display.
class DisplayGammaController {
    static let shared = DisplayGammaController()
    
    /// Saved original gamma tables so we can restore exactly.
    private struct SavedGamma {
        let red: [Float]
        let green: [Float]
        let blue: [Float]
        let sampleCount: UInt32
    }
    private var savedGamma: [CGDirectDisplayID: SavedGamma] = [:]
    private var isApplied = false
    
    private init() {}
    
    /// Apply or remove color-temperature gamma ramps on all non-built-in displays.
    /// - Parameter colorTemperature: 0.0 = natural (6500K), 1.0 = warmest (2700K).
    ///   This is the same scale as CBBlueLightClient.blueLightReductionAmount.
    /// - Parameter active: Whether Night Shift should be visually active.
    func sync(active: Bool, colorTemperature: Float) {
        if active {
            let kelvin = kelvinForColorTemperature(colorTemperature)
            applyColorTemperature(kelvin)
        } else {
            restoreGamma()
        }
    }
    
    // MARK: - Private
    
    private func kelvinForColorTemperature(_ ct: Float) -> Float {
        // Map ct=0.0 → 5500K (natural/cool), ct=1.0 → 3400K (max warmth)
        return 5500.0 - ct * 2100.0
    }
    
    /// Apply a color-temperature-correction gamma ramp to all non-built-in displays.
    private func applyColorTemperature(_ kelvin: Float) {
        let multipliers = rgbMultipliers(for: kelvin)
        let sampleCount: UInt32 = 256
        
        // Build gamma table using per-channel linear gain
        // This shifts the white point uniformly, like f.lux
        var tableR = [Float](repeating: 0, count: Int(sampleCount))
        var tableG = [Float](repeating: 0, count: Int(sampleCount))
        var tableB = [Float](repeating: 0, count: Int(sampleCount))
        
        for i in 0..<Int(sampleCount) {
            let value = Float(i) / Float(sampleCount - 1)
            // Per-channel linear gain — shifts white point uniformly
            tableR[i] = value
            tableG[i] = value * multipliers.g
            tableB[i] = value * multipliers.b
        }
        
        // Apply to each non-built-in display
        var displayRefs = [CGDirectDisplayID](repeating: 0, count: 8)
        var displayCount: UInt32 = 0
        CGGetActiveDisplayList(8, &displayRefs, &displayCount)
        
        for i in 0..<Int(displayCount) {
            let disp = displayRefs[i]
            guard CGDisplayIsBuiltin(disp) == 0 else { continue } // skip built-in
            
            // Save original gamma if not yet saved
            if savedGamma[disp] == nil {
                var origR = [Float](repeating: 0, count: Int(sampleCount))
                var origG = [Float](repeating: 0, count: Int(sampleCount))
                var origB = [Float](repeating: 0, count: Int(sampleCount))
                var origCount: UInt32 = 0
                
                let err = CGGetDisplayTransferByTable(disp, sampleCount, &origR, &origG, &origB, &origCount)
                if err == .success {
                    savedGamma[disp] = SavedGamma(
                        red: origR, green: origG, blue: origB,
                        sampleCount: origCount)
                }
            }
            
            // Set new gamma
            CGSetDisplayTransferByTable(disp, sampleCount, &tableR, &tableG, &tableB)
        }
        
        isApplied = true
        logw("Applied gamma ramp at \(Int(kelvin))K to external displays")
    }
    
    /// Restore original gamma on all displays.
    private func restoreGamma() {
        guard isApplied else { return }
        
        for (disp, saved) in savedGamma {
            // Build arrays with the original sample count
            let count = Int(saved.sampleCount)
            var r = saved.red
            var g = saved.green
            var b = saved.blue
            
            CGSetDisplayTransferByTable(disp, saved.sampleCount, &r, &g, &b)
        }
        savedGamma.removeAll()
        isApplied = false
        logw("Restored original gamma on external displays")
    }
    
    /// Compute RGB multipliers for a given color temperature (Kelvin).
    /// Calibrated from live f.lux readings on this display at three points
    /// and interpolated between them:
    ///   5500K → (1.0, 0.9520, 0.9195)
    ///   4200K → (1.0, 0.8414, 0.6787)
    ///   3400K → (1.0, 0.7635, 0.5193)
    private func rgbMultipliers(for kelvin: Float) -> (r: Float, g: Float, b: Float) {
        let k = max(3400, min(6500, kelvin))
        
        if k >= 5500 {
            // Linear interpolation: 6500K→identity(1,1,1), 5500K→measured
            let t = (k - 5500) / 1000.0  // 0 at 5500K, 1 at 6500K
            let g: Float = 0.9520 + (1.0 - 0.9520) * t
            let b: Float = 0.9195 + (1.0 - 0.9195) * t
            return (1.0, min(1.0, g), min(1.0, b))
        } else if k >= 4200 {
            // Interpolate: 5500K → 4200K
            let t = (5500 - k) / 1300.0  // 0 at 5500K, 1 at 4200K
            let g: Float = 0.9520 - (0.9520 - 0.8414) * t
            let b: Float = 0.9195 - (0.9195 - 0.6787) * t
            return (1.0, g, b)
        } else {
            // Interpolate: 4200K → 3400K
            let t = (4200 - k) / 800.0  // 0 at 4200K, 1 at 3400K
            let g: Float = 0.8414 - (0.8414 - 0.7635) * t
            let b: Float = 0.6787 - (0.6787 - 0.5193) * t
            return (1.0, g, b)
        }
    }
}
