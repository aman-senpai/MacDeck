//
//  LibraryScanner.swift
//  MacDeck
//

import Foundation

class LibraryScanner {
    static let shared = LibraryScanner()
    
    private let fileManager = FileManager.default
    
    func scanAllGames() -> [Game] {
        var games: [Game] = []
        games.append(contentsOf: scanSteamGames())
        games.append(contentsOf: scanRyujinxGames())
        games.append(contentsOf: scanMythicGames())
        
        // Remove duplicates by game ID to prevent SwiftUI rendering glitches
        var seenIds = Set<String>()
        var uniqueGames: [Game] = []
        for game in games {
            if !seenIds.contains(game.id) {
                seenIds.insert(game.id)
                uniqueGames.append(game)
            }
        }
        return uniqueGames
    }
    
    // MARK: - Steam Scanner
    private func scanSteamGames() -> [Game] {
        var steamGames: [Game] = []
        let home = NSHomeDirectory()
        let steamAppsPath = SettingsManager.shared.steamAppsPath.replacingOccurrences(of: "~", with: home)
        let libraryFoldersVdf = "\(steamAppsPath)/libraryfolders.vdf"
        
        var libraryPaths: [String] = [steamAppsPath]
        
        if fileManager.fileExists(atPath: libraryFoldersVdf) {
            do {
                let content = try String(contentsOfFile: libraryFoldersVdf, encoding: .utf8)
                // Parse VDF to find paths
                let pattern = "\"path\"\\s+\"([^\"]+)\""
                let regex = try NSRegularExpression(pattern: pattern, options: [])
                let nsContent = content as NSString
                let matches = regex.matches(in: content, options: [], range: NSRange(location: 0, length: nsContent.length))
                
                for match in matches {
                    if match.numberOfRanges > 1 {
                        let path = nsContent.substring(with: match.range(at: 1))
                        let steamAppsFolder = "\(path)/steamapps"
                        if !libraryPaths.contains(steamAppsFolder) && fileManager.fileExists(atPath: steamAppsFolder) {
                            libraryPaths.append(steamAppsFolder)
                        }
                    }
                }
            } catch {
                print("Error reading libraryfolders.vdf: \(error)")
            }
        }
        
        for libraryPath in libraryPaths {
            guard let files = try? fileManager.contentsOfDirectory(atPath: libraryPath) else { continue }
            let acfFiles = files.filter { $0.hasSuffix(".acf") && $0.hasPrefix("appmanifest_") }
            
            for acf in acfFiles {
                let fullPath = "\(libraryPath)/\(acf)"
                if let game = parseSteamManifest(at: fullPath) {
                    steamGames.append(game)
                }
            }
        }
        
        return steamGames
    }
    
    private func parseSteamManifest(at path: String) -> Game? {
        guard let content = try? String(contentsOfFile: path, encoding: .utf8) else { return nil }
        
        func getValue(forKey key: String) -> String? {
            let pattern = "\"\(key)\"\\s+\"([^\"]+)\""
            guard let regex = try? NSRegularExpression(pattern: pattern, options: .caseInsensitive) else { return nil }
            let nsContent = content as NSString
            if let match = regex.firstMatch(in: content, options: [], range: NSRange(location: 0, length: nsContent.length)) {
                if match.numberOfRanges > 1 {
                    return nsContent.substring(with: match.range(at: 1))
                }
            }
            return nil
        }
        
        guard let appid = getValue(forKey: "appid"),
              let name = getValue(forKey: "name") else { return nil }
        
        let sizeString = getValue(forKey: "SizeOnDisk") ?? "0"
        let size = UInt64(sizeString) ?? 0
        
        let lastPlayedString = getValue(forKey: "LastPlayed") ?? "0"
        let lastPlayedInt = Double(lastPlayedString) ?? 0
        let lastPlayedDate = lastPlayedInt > 0 ? Date(timeIntervalSince1970: lastPlayedInt) : nil
        
        return Game(
            title: name,
            launcher: .steam,
            launchId: appid,
            romPath: nil,
            sizeOnDisk: size,
            lastPlayed: lastPlayedDate
        )
    }
    
    // MARK: - Ryujinx Scanner
    struct RyujinxConfig: Codable {
        let game_dirs: [String]?
    }
    
    struct RyujinxMetadata: Codable {
        let title: String?
        let favorite: Bool?
        let timespan_played: String?
        let last_played_utc: String?
    }
    
    private func scanRyujinxGames() -> [Game] {
        var ryujinxGames: [Game] = []
        let home = NSHomeDirectory()
        let ryujinxConfigDir = SettingsManager.shared.ryujinxConfigDir.replacingOccurrences(of: "~", with: home)
        let ryujinxConfigPath = "\(ryujinxConfigDir)/Config.json"
        
        var gameDirs: [String] = []
        let customDirs = SettingsManager.shared.ryujinxRomDirs
        if !customDirs.isEmpty {
            gameDirs = customDirs.components(separatedBy: ",").map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }.filter { !$0.isEmpty }
        } else if fileManager.fileExists(atPath: ryujinxConfigPath) {
            if let data = try? Data(contentsOf: URL(fileURLWithPath: ryujinxConfigPath)),
               let config = try? JSONDecoder().decode(RyujinxConfig.self, from: data) {
                gameDirs = config.game_dirs ?? []
            }
        }
        
        guard !gameDirs.isEmpty else { return [] }
        
        // Find title ID from filename (16 hex character string)
        let titleIdRegex = try? NSRegularExpression(pattern: "(?:\\[|\\s)([0-9a-fA-F]{16})(?:\\]|\\s|\\.)", options: [])
        
        for gameDir in gameDirs {
            let expandedDir = gameDir.replacingOccurrences(of: "~", with: home)
            guard let enumerator = fileManager.enumerator(atPath: expandedDir) else { continue }
            
            while let file = enumerator.nextObject() as? String {
                let lowercaseFile = file.lowercased()
                guard lowercaseFile.hasSuffix(".nsp") || lowercaseFile.hasSuffix(".xci") || lowercaseFile.hasSuffix(".nsz") || lowercaseFile.hasSuffix(".xcz") else { continue }
                
                // Skip hidden files
                let basename = (file as NSString).lastPathComponent
                if basename.hasPrefix(".") { continue }
                
                let fullPath = "\(expandedDir)/\(file)"
                
                // Find title ID in path
                var titleId: String? = nil
                let nsFile = basename as NSString
                if let match = titleIdRegex?.firstMatch(in: basename, options: [], range: NSRange(location: 0, length: nsFile.length)) {
                    if match.numberOfRanges > 1 {
                        let tid = nsFile.substring(with: match.range(at: 1)).lowercased()
                        // Skip updates and DLCs (Switch base games always end in "000")
                        if !tid.hasSuffix("000") {
                            continue
                        }
                        titleId = tid
                    }
                }
                
                // Default title
                var title = basename
                    .replacingOccurrences(of: ".nsp", with: "", options: .caseInsensitive)
                    .replacingOccurrences(of: ".xci", with: "", options: .caseInsensitive)
                    .replacingOccurrences(of: ".nsz", with: "", options: .caseInsensitive)
                    .replacingOccurrences(of: ".xcz", with: "", options: .caseInsensitive)
                
                title = cleanRyujinxTitle(title)
                
                var lastPlayed: Date? = nil
                
                if let tid = titleId {
                    let metadataPath = "\(ryujinxConfigDir)/games/\(tid)/gui/metadata.json"
                    if fileManager.fileExists(atPath: metadataPath),
                       let metaData = try? Data(contentsOf: URL(fileURLWithPath: metadataPath)),
                       let metadataObj = try? JSONDecoder().decode(RyujinxMetadata.self, from: metaData) {
                        if let metaTitle = metadataObj.title, !metaTitle.isEmpty {
                            title = metaTitle
                        }
                        if let dateStr = metadataObj.last_played_utc {
                            let isoFormatter = ISO8601DateFormatter()
                            isoFormatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
                            lastPlayed = isoFormatter.date(from: dateStr)
                            if lastPlayed == nil {
                                // Fallback
                                let simpleFormatter = ISO8601DateFormatter()
                                lastPlayed = simpleFormatter.date(from: dateStr)
                            }
                        }
                    }
                }
                
                let attrs = try? fileManager.attributesOfItem(atPath: fullPath)
                let size = attrs?[.size] as? UInt64 ?? 0
                
                ryujinxGames.append(
                    Game(
                        title: title,
                        launcher: .ryujinx,
                        launchId: titleId ?? basename,
                        romPath: fullPath,
                        sizeOnDisk: size,
                        lastPlayed: lastPlayed
                    )
                )
            }
        }
        
        return ryujinxGames
    }
    
    // MARK: - Mythic Scanner
    struct MythicGame: Codable {
        let app_name: String
        let title: String
        let install_path: String
        let executable: String
        let launch_parameters: String?
        let install_size: UInt64?
    }
    
    private func scanMythicGames() -> [Game] {
        var mythicGames: [Game] = []
        let home = NSHomeDirectory()
        let mythicInstalledJson = SettingsManager.shared.mythicInstalledJson.replacingOccurrences(of: "~", with: home)
        
        guard fileManager.fileExists(atPath: mythicInstalledJson) else { return [] }
        
        guard let data = try? Data(contentsOf: URL(fileURLWithPath: mythicInstalledJson)),
              let jsonDict = try? JSONSerialization.jsonObject(with: data, options: []) as? [String: [String: Any]] else {
            return []
        }
        
        for (appid, gameDict) in jsonDict {
            guard let title = gameDict["title"] as? String,
                  let installPath = gameDict["install_path"] as? String,
                  let executable = gameDict["executable"] as? String else { continue }
            
            let size = gameDict["install_size"] as? UInt64
            
            mythicGames.append(
                Game(
                    title: title,
                    launcher: .mythic,
                    launchId: appid,
                    romPath: "\(installPath)/\(executable)",
                    sizeOnDisk: size,
                    lastPlayed: nil
                )
            )
        }
        
        return mythicGames
    }
    
    private func cleanRyujinxTitle(_ title: String) -> String {
        var clean = title
            .replacingOccurrences(of: "__", with: " ")
            .replacingOccurrences(of: "_", with: " ")
            .replacingOccurrences(of: "™", with: "")
            .replacingOccurrences(of: "®", with: "")
        
        // Strip bracketed components (e.g. [01007EF00C192000] or [v0])
        if let regex = try? NSRegularExpression(pattern: "\\[[^\\]]+\\]", options: []) {
            clean = regex.stringByReplacingMatches(in: clean, options: [], range: NSRange(location: 0, length: clean.utf16.count), withTemplate: "")
        }
        
        // Strip parentheses components
        if let regex = try? NSRegularExpression(pattern: "\\([^\\)]+\\)", options: []) {
            clean = regex.stringByReplacingMatches(in: clean, options: [], range: NSRange(location: 0, length: clean.utf16.count), withTemplate: "")
        }
        
        // Strip known repack / dump / scene strings and version tags
        let patternsToStrip = [
            "Switch-xci\\.com",
            "Switch-xci",
            "FitGirl Repack",
            "FitGirl",
            "Repack",
            "v[0-9]+(?:\\.[0-9]+)*",
            "v[0-9]+"
        ]
        for pattern in patternsToStrip {
            if let regex = try? NSRegularExpression(pattern: "(?i)" + pattern, options: []) {
                clean = regex.stringByReplacingMatches(in: clean, options: [], range: NSRange(location: 0, length: clean.utf16.count), withTemplate: "")
            }
        }
        
        // Replace multiple spaces with a single space
        if let spaceRegex = try? NSRegularExpression(pattern: "\\s+", options: []) {
            clean = spaceRegex.stringByReplacingMatches(in: clean, options: [], range: NSRange(location: 0, length: clean.utf16.count), withTemplate: " ")
        }
        
        return clean.trimmingCharacters(in: .whitespacesAndNewlines)
    }
}
