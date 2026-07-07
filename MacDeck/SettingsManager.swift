//
//  SettingsManager.swift
//  MacDeck
//
//  Created by Antigravity on 7/7/26.
//

import Foundation

class SettingsManager: ObservableObject {
    static let shared = SettingsManager()
    
    private let defaults = UserDefaults.standard
    
    // Keys
    private let steamAppsPathKey = "ML_SteamAppsPath"
    private let ryujinxAppPathKey = "ML_RyujinxAppPath"
    private let ryujinxConfigDirKey = "ML_RyujinxConfigDir"
    private let ryujinxRomDirsKey = "ML_RyujinxRomDirs"
    private let mythicInstalledJsonKey = "ML_MythicInstalledJson"
    private let mythicLegendaryCliKey = "ML_MythicLegendaryCli"
    private let mythicWine64Key = "ML_MythicWine64"
    private let mythicDefaultPrefixKey = "ML_MythicDefaultPrefix"
    private let mythicPlistPathKey = "ML_MythicPlistPath"
    private let mythicOfflineModeKey = "ML_MythicOfflineMode"
    
    // Dynamic Default Fallback Values
    var defaultSteamAppsPath: String {
        "\(NSHomeDirectory())/Library/Application Support/Steam/steamapps"
    }
    
    var defaultRyujinxAppPath: String {
        "/Applications/Ryujinx.app/Contents/MacOS/Ryujinx"
    }
    
    var defaultRyujinxConfigDir: String {
        "\(NSHomeDirectory())/Library/Application Support/Ryujinx"
    }
    
    var defaultMythicInstalledJson: String {
        "\(NSHomeDirectory())/Library/Application Support/Mythic/Epic/installed.json"
    }
    
    var defaultMythicLegendaryCli: String {
        "/Applications/Mythic.app/Contents/Resources/legendary/cli"
    }
    
    var defaultMythicWine64: String {
        "\(NSHomeDirectory())/Library/Application Support/Mythic/Engine/wine/bin/wine64"
    }
    
    var defaultMythicDefaultPrefix: String {
        "\(NSHomeDirectory())/Library/Containers/xyz.blackxfiied.Mythic/Containers/Default"
    }
    
    var defaultMythicPlistPath: String {
        "\(NSHomeDirectory())/Library/Preferences/xyz.blackxfiied.Mythic.plist"
    }
    
    // Published Properties
    @Published var steamAppsPath: String {
        didSet {
            defaults.set(steamAppsPath, forKey: steamAppsPathKey)
        }
    }
    
    @Published var ryujinxAppPath: String {
        didSet {
            defaults.set(ryujinxAppPath, forKey: ryujinxAppPathKey)
        }
    }
    
    @Published var ryujinxConfigDir: String {
        didSet {
            defaults.set(ryujinxConfigDir, forKey: ryujinxConfigDirKey)
        }
    }
    
    @Published var ryujinxRomDirs: String {
        didSet {
            defaults.set(ryujinxRomDirs, forKey: ryujinxRomDirsKey)
        }
    }
    
    @Published var mythicInstalledJson: String {
        didSet {
            defaults.set(mythicInstalledJson, forKey: mythicInstalledJsonKey)
        }
    }
    
    @Published var mythicLegendaryCli: String {
        didSet {
            defaults.set(mythicLegendaryCli, forKey: mythicLegendaryCliKey)
        }
    }
    
    @Published var mythicWine64: String {
        didSet {
            defaults.set(mythicWine64, forKey: mythicWine64Key)
        }
    }
    
    @Published var mythicDefaultPrefix: String {
        didSet {
            defaults.set(mythicDefaultPrefix, forKey: mythicDefaultPrefixKey)
        }
    }
    
    @Published var mythicPlistPath: String {
        didSet {
            defaults.set(mythicPlistPath, forKey: mythicPlistPathKey)
        }
    }
    
    @Published var mythicOfflineMode: Bool {
        didSet {
            defaults.set(mythicOfflineMode, forKey: mythicOfflineModeKey)
        }
    }
    
    private init() {
        // Retrieve or use empty, then populate empty with default
        let storedSteam = defaults.string(forKey: steamAppsPathKey) ?? ""
        let storedRyujinxApp = defaults.string(forKey: ryujinxAppPathKey) ?? ""
        let storedRyujinxConf = defaults.string(forKey: ryujinxConfigDirKey) ?? ""
        let storedRyujinxRom = defaults.string(forKey: ryujinxRomDirsKey) ?? ""
        let storedMythicJson = defaults.string(forKey: mythicInstalledJsonKey) ?? ""
        let storedMythicCli = defaults.string(forKey: mythicLegendaryCliKey) ?? ""
        let storedMythicWine = defaults.string(forKey: mythicWine64Key) ?? ""
        let storedMythicPrefix = defaults.string(forKey: mythicDefaultPrefixKey) ?? ""
        let storedMythicPlist = defaults.string(forKey: mythicPlistPathKey) ?? ""
        
        self.steamAppsPath = storedSteam.isEmpty ? "" : storedSteam
        self.ryujinxAppPath = storedRyujinxApp.isEmpty ? "" : storedRyujinxApp
        self.ryujinxConfigDir = storedRyujinxConf.isEmpty ? "" : storedRyujinxConf
        self.ryujinxRomDirs = storedRyujinxRom
        self.mythicInstalledJson = storedMythicJson.isEmpty ? "" : storedMythicJson
        self.mythicLegendaryCli = storedMythicCli.isEmpty ? "" : storedMythicCli
        self.mythicWine64 = storedMythicWine.isEmpty ? "" : storedMythicWine
        self.mythicDefaultPrefix = storedMythicPrefix.isEmpty ? "" : storedMythicPrefix
        self.mythicPlistPath = storedMythicPlist.isEmpty ? "" : storedMythicPlist
        self.mythicOfflineMode = defaults.bool(forKey: mythicOfflineModeKey)
        
        // Dynamic population of empty fields
        if self.steamAppsPath.isEmpty { self.steamAppsPath = defaultSteamAppsPath }
        if self.ryujinxAppPath.isEmpty { self.ryujinxAppPath = defaultRyujinxAppPath }
        if self.ryujinxConfigDir.isEmpty { self.ryujinxConfigDir = defaultRyujinxConfigDir }
        if self.mythicInstalledJson.isEmpty { self.mythicInstalledJson = defaultMythicInstalledJson }
        if self.mythicLegendaryCli.isEmpty { self.mythicLegendaryCli = defaultMythicLegendaryCli }
        if self.mythicWine64.isEmpty { self.mythicWine64 = defaultMythicWine64 }
        if self.mythicDefaultPrefix.isEmpty { self.mythicDefaultPrefix = defaultMythicDefaultPrefix }
        if self.mythicPlistPath.isEmpty { self.mythicPlistPath = defaultMythicPlistPath }
    }
    
    func resetToDefaults() {
        self.steamAppsPath = defaultSteamAppsPath
        self.ryujinxAppPath = defaultRyujinxAppPath
        self.ryujinxConfigDir = defaultRyujinxConfigDir
        self.ryujinxRomDirs = ""
        self.mythicInstalledJson = defaultMythicInstalledJson
        self.mythicLegendaryCli = defaultMythicLegendaryCli
        self.mythicWine64 = defaultMythicWine64
        self.mythicDefaultPrefix = defaultMythicDefaultPrefix
        self.mythicPlistPath = defaultMythicPlistPath
        self.mythicOfflineMode = false
    }
}
