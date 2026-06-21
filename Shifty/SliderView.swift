//
//  SliderView.swift
//  Shifty
//
//  Created by Nate Thompson on 5/7/17.
//

import Cocoa
import SwiftLog

class SliderView: NSView {

    @IBOutlet weak var shiftSlider: NSSlider!

    @IBAction func shiftSliderMoved(_ sender: NSSlider) {
        let event = NSApplication.shared.currentEvent
        let value = sender.floatValue / 100
        
        if event?.type == .leftMouseUp {
            // Commit value to hardware
            CBBlueLightClient.shared.blueLightReductionAmount = value
            
            // Update external display gamma ramp with committed value
            if NightShiftManager.shared.isNightShiftEnabled {
                DisplayGammaController.shared.sync(active: true, colorTemperature: value)
            }
            
            // Don't close menu — let the slider stay where the user set it
            // Let the menu naturally close when user clicks elsewhere
            
            Event.sliderMoved(value: sender.floatValue).record()
            logw("Slider set to \(sender.floatValue)")
        } else {
            // Preview on built-in display
            CBBlueLightClient.shared.previewBlueLightReductionAmount(value)
            
            // Live preview on external display via gamma ramp
            if NightShiftManager.shared.isNightShiftEnabled {
                DisplayGammaController.shared.sync(active: true, colorTemperature: value)
            }
        }
    }

    @IBAction func clickEnableSlider(_ sender: Any) {
        NightShiftManager.shared.isNightShiftEnabled = true
        
        let statusMenuController = (NSApplication.shared.delegate as! AppDelegate).statusMenu.delegate as! StatusMenuController
        statusMenuController.updateMenuItems()
        
        shiftSlider.isEnabled = true
        Event.enableSlider.record()
        logw("Enable slider button clicked")
    }
}


class ScrollableSlider: NSSlider {
    override func scrollWheel(with event: NSEvent) {
        guard isEnabled else { return }

        let range = maxValue - minValue
        var delta: CGFloat = 0.0

        //Allow horizontal scrolling on horizontal and circular sliders
        if self.isVertical && self.sliderType == .linear {
            delta = event.deltaY
        } else if self.userInterfaceLayoutDirection == .rightToLeft {
            delta = event.deltaY + event.deltaX
        } else {
            delta = event.deltaY - event.deltaX
        }

        //Account for natural scrolling
        if event.isDirectionInvertedFromDevice {
            delta *= -1
        }

        let increment = range * Double(delta) / 100
        var value = doubleValue + increment

        //Wrap around if slider is circular
        if sliderType == .circular {
            let minValue = self.minValue
            let maxValue = self.maxValue

            if value < minValue {
                value = maxValue - abs(increment)
            }
            if value > maxValue {
                value = minValue + abs(increment)
            }
        }

        self.doubleValue = value
        self.sendAction(action, to: target)
    }
}
