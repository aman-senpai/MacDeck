//
//  ControllerManager.swift
//  MacDeck
//

import Foundation
import GameController
import Combine
import SwiftUI

enum ControllerDirection {
    case up, down, left, right
}

class ControllerManager: ObservableObject {
    static let shared = ControllerManager()
    
    @Published var isControllerConnected = false
    @Published var controllerName = "No Controller"
    
    var onButtonAPressed: (() -> Void)?
    var onButtonBPressed: (() -> Void)?
    var onLeftShoulderPressed: (() -> Void)?
    var onRightShoulderPressed: (() -> Void)?
    var onDirectionPressed: ((ControllerDirection) -> Void)?
    
    private var lastDpadPressTime: Date = Date.distantPast
    private let dpadCooldown: TimeInterval = 0.18
    
    init() {
        setupNotifications()
        checkConnectedControllers()
    }
    
    private func setupNotifications() {
        NotificationCenter.default.addObserver(self, selector: #selector(controllerDidConnect(_:)), name: .GCControllerDidConnect, object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(controllerDidDisconnect(_:)), name: .GCControllerDidDisconnect, object: nil)
    }
    
    private func checkConnectedControllers() {
        let controllers = GCController.controllers()
        isControllerConnected = !controllers.isEmpty
        if let first = controllers.first {
            controllerName = first.vendorName ?? "Gamepad"
            setupGamepad(first)
        } else {
            controllerName = "No Controller"
        }
    }
    
    @objc private func controllerDidConnect(_ notification: Notification) {
        guard let controller = notification.object as? GCController else { return }
        DispatchQueue.main.async {
            self.isControllerConnected = true
            self.controllerName = controller.vendorName ?? "Gamepad"
            self.setupGamepad(controller)
        }
    }
    
    @objc private func controllerDidDisconnect(_ notification: Notification) {
        DispatchQueue.main.async {
            self.checkConnectedControllers()
        }
    }
    
    private func setupGamepad(_ controller: GCController) {
        if let gamepad = controller.extendedGamepad {
            gamepad.buttonA.pressedChangedHandler = { [weak self] (button, value, pressed) in
                if pressed {
                    DispatchQueue.main.async {
                        self?.onButtonAPressed?()
                    }
                }
            }
            
            gamepad.buttonB.pressedChangedHandler = { [weak self] (button, value, pressed) in
                if pressed {
                    DispatchQueue.main.async {
                        self?.onButtonBPressed?()
                    }
                }
            }
            
            gamepad.leftShoulder.pressedChangedHandler = { [weak self] (button, value, pressed) in
                if pressed {
                    DispatchQueue.main.async {
                        self?.onLeftShoulderPressed?()
                    }
                }
            }
            
            gamepad.rightShoulder.pressedChangedHandler = { [weak self] (button, value, pressed) in
                if pressed {
                    DispatchQueue.main.async {
                        self?.onRightShoulderPressed?()
                    }
                }
            }
            
            // D-Pad navigation
            gamepad.dpad.valueChangedHandler = { [weak self] (dpad, x, y) in
                self?.handleDirectionInput(x: x, y: y)
            }
            
            // Left Stick navigation
            gamepad.leftThumbstick.valueChangedHandler = { [weak self] (stick, x, y) in
                self?.handleDirectionInput(x: x, y: y)
            }
        }
    }
    
    private func handleDirectionInput(x: Float, y: Float) {
        let now = Date()
        guard now.timeIntervalSince(lastDpadPressTime) > dpadCooldown else { return }
        
        let threshold: Float = 0.5
        
        if x > threshold {
            lastDpadPressTime = now
            DispatchQueue.main.async { [weak self] in
                self?.onDirectionPressed?(.right)
            }
        } else if x < -threshold {
            lastDpadPressTime = now
            DispatchQueue.main.async { [weak self] in
                self?.onDirectionPressed?(.left)
            }
        } else if y > threshold {
            lastDpadPressTime = now
            DispatchQueue.main.async { [weak self] in
                self?.onDirectionPressed?(.up)
            }
        } else if y < -threshold {
            lastDpadPressTime = now
            DispatchQueue.main.async { [weak self] in
                self?.onDirectionPressed?(.down)
            }
        }
    }
}
