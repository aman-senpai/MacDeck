//
//  LaunchManager.swift
//  MacDeck
//

import Cocoa

class LaunchManager {
    static let shared = LaunchManager()
    
    func launch(game: Game, completion: @escaping (Bool, String?) -> Void) {
        switch game.launcher {
        case .steam:
            launchSteam(game: game, completion: completion)
        case .ryujinx:
            launchRyujinx(game: game, completion: completion)
        case .mythic:
            launchMythic(game: game, completion: completion)
        }
    }
    
    private func launchSteam(game: Game, completion: @escaping (Bool, String?) -> Void) {
        guard let url = URL(string: "steam://run/\(game.launchId)") else {
            completion(false, "Invalid Steam URL")
            return
        }
        
        NSWorkspace.shared.open(url)
        completion(true, nil)
    }
    
    private func launchRyujinx(game: Game, completion: @escaping (Bool, String?) -> Void) {
        guard let romPath = game.romPath else {
            completion(false, "ROM path not found")
            return
        }
        
        let home = NSHomeDirectory()
        let ryujinxPath = SettingsManager.shared.ryujinxAppPath.replacingOccurrences(of: "~", with: home)
        guard FileManager.default.fileExists(atPath: ryujinxPath) else {
            completion(false, "Ryujinx app not found at: \(ryujinxPath)")
            return
        }
        
        // Update Ryujinx config to launch on the same screen as MacDeck
        updateRyujinxPositionToCurrentScreen()
        
        let process = Process()
        process.executableURL = URL(fileURLWithPath: ryujinxPath)
        process.arguments = [romPath]
        
        do {
            try process.run()
            completion(true, nil)
        } catch {
            completion(false, "Failed to launch Ryujinx process: \(error.localizedDescription)")
        }
    }
    
    private func updateRyujinxPositionToCurrentScreen() {
        let home = NSHomeDirectory()
        let ryujinxConfigDir = SettingsManager.shared.ryujinxConfigDir.replacingOccurrences(of: "~", with: home)
        let configPath = "\(ryujinxConfigDir)/Config.json"
        let url = URL(fileURLWithPath: configPath)
        
        guard let data = try? Data(contentsOf: url),
              var configDict = try? JSONSerialization.jsonObject(with: data, options: .mutableContainers) as? [String: Any] else {
            return
        }
        
        // Get the active screen (where MacDeck is focused/running)
        guard let activeScreen = NSScreen.main ?? NSScreen.screens.first else { return }
        let screenFrame = activeScreen.frame
        
        var windowStartup = configDict["window_startup"] as? [String: Any] ?? [:]
        let width = windowStartup["window_size_width"] as? CGFloat ?? 1280
        let height = windowStartup["window_size_height"] as? CGFloat ?? 720
        
        // Center the window on the active screen
        let x = screenFrame.origin.x + (screenFrame.size.width - width) / 2
        let y = screenFrame.origin.y + (screenFrame.size.height - height) / 2
        
        windowStartup["window_position_x"] = Int(x)
        windowStartup["window_position_y"] = Int(y)
        configDict["window_startup"] = windowStartup
        
        if let updatedData = try? JSONSerialization.data(withJSONObject: configDict, options: .prettyPrinted) {
            try? updatedData.write(to: url)
        }
    }
    
    private func launchMythic(game: Game, completion: @escaping (Bool, String?) -> Void) {
        let home = NSHomeDirectory()
        let legendaryCli = SettingsManager.shared.mythicLegendaryCli.replacingOccurrences(of: "~", with: home)
        let wine64Path = SettingsManager.shared.mythicWine64.replacingOccurrences(of: "~", with: home)
        
        guard FileManager.default.fileExists(atPath: legendaryCli) else {
            completion(false, "Legendary CLI not found at: \(legendaryCli)")
            return
        }
        
        guard FileManager.default.fileExists(atPath: wine64Path) else {
            completion(false, "Wine64 binary not found at: \(wine64Path)")
            return
        }
        
        let winePrefix = getMythicWinePrefix(for: game.launchId)
        
        let process = Process()
        process.executableURL = URL(fileURLWithPath: legendaryCli)
        
        var args = [
            "launch",
            game.launchId,
            "--wine",
            wine64Path,
            "--wine-prefix",
            winePrefix
        ]
        if SettingsManager.shared.mythicOfflineMode {
            args.append("--offline")
        }
        process.arguments = args
        
        var env = ProcessInfo.processInfo.environment
        let mythicInstalledJson = SettingsManager.shared.mythicInstalledJson.replacingOccurrences(of: "~", with: home)
        let legendaryConfigPath = URL(fileURLWithPath: mythicInstalledJson).deletingLastPathComponent().path
        env["LEGENDARY_CONFIG_PATH"] = legendaryConfigPath
        env["WINEPREFIX"] = winePrefix
        env["CX_BOTTLE"] = "Legendary"
        process.environment = env
        
        do {
            try process.run()
            completion(true, nil)
        } catch {
            completion(false, "Failed to launch Mythic/Legendary game: \(error.localizedDescription)")
        }
    }
    
    private func getMythicWinePrefix(for appid: String) -> String {
        let home = NSHomeDirectory()
        let plistPath = SettingsManager.shared.mythicPlistPath.replacingOccurrences(of: "~", with: home)
        let defaultPrefix = SettingsManager.shared.mythicDefaultPrefix.replacingOccurrences(of: "~", with: home)
        
        guard FileManager.default.fileExists(atPath: plistPath) else { return defaultPrefix }
        guard let dict = NSDictionary(contentsOfFile: plistPath) else { return defaultPrefix }
        
        if let containerURL = dict["\(appid)_containerURL"] as? String {
            return containerURL.replacingOccurrences(of: "~", with: home)
        }
        
        return defaultPrefix
    }
}
