//
//  PresetSelectorView.swift
//  Shifty
//
//  Created by Zeke on 6/21/26.
//

import Cocoa

/// A row of three radio-style buttons for selecting color temperature preset:
/// 5500K (cool), 4200K (default), 3400K (warm)
class PresetSelectorView: NSView {
    
    private var buttons: [NSButton] = []
    private var onPresetSelected: (Float) -> Void
    
    /// ct values for each preset
    private let presets: [(label: String, ct: Float)] = [
        ("5500K", 0.0),
        ("4200K", 0.619),
        ("3400K", 1.0),
    ]
    
    var selectedIndex: Int = 1 { // default = 4200K
        didSet {
            for (i, btn) in buttons.enumerated() {
                btn.state = (i == selectedIndex) ? .on : .off
            }
        }
    }
    
    init(onPresetSelected: @escaping (Float) -> Void) {
        self.onPresetSelected = onPresetSelected
        super.init(frame: .zero)
        setupViews()
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    private func setupViews() {
        let stack = NSStackView()
        stack.orientation = .vertical
        stack.distribution = .fillEqually
        stack.spacing = 2
        stack.translatesAutoresizingMaskIntoConstraints = false
        
        for (i, preset) in presets.enumerated() {
            let btn = NSButton()
            btn.setButtonType(.radio)
            btn.title = preset.label
            btn.tag = i
            btn.target = self
            btn.action = #selector(presetClicked(_:))
            btn.state = (i == 1) ? .on : .off  // default 4200K
            buttons.append(btn)
            stack.addArrangedSubview(btn)
        }
        
        addSubviewAndConstrainToEqualSize(
            stack,
            withInsets: NSEdgeInsets(top: 6, left: 12, bottom: 6, right: 12))
    }
    
    @objc private func presetClicked(_ sender: NSButton) {
        let idx = sender.tag
        guard idx >= 0 && idx < presets.count else { return }
        selectedIndex = idx
        onPresetSelected(presets[idx].ct)
    }
}