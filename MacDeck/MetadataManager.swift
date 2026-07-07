//
//  MetadataManager.swift
//  MacDeck
//

import Foundation
import Combine

class MetadataManager: ObservableObject {
    static let shared = MetadataManager()
    
    @Published var cachedAppIds: [String: String] = [:]
    private let cacheFile: URL
    private var pendingRequests = Set<String>()
    private let queue = DispatchQueue(label: "com.senpai.macdeck.metadata", qos: .background)
    
    // Seed mappings for immediate offline/pre-mapped loading of known games
    private let titleToSteamAppIdMap: [String: String] = [
        "hollow knight silksong": "1030300",
        "hollow knight": "367520",
        "inside": "304430",
        "prince of persia the lost crown": "2751000",
        "hogwarts legacy": "990080"
    ]
    
    // Direct cover art URLs for non-Steam console exclusives (like Mario games)
    private let customGameImageUrls: [String: String] = [
        "super mario galaxy 2": "https://www.mariowiki.com/images/d/de/Smg2boxart.png"
    ]
    
    private init() {
        let fileManager = FileManager.default
        let home = NSHomeDirectory()
        let appSupportDir = URL(fileURLWithPath: "\(home)/Library/Application Support/MacDeck")
        
        do {
            try fileManager.createDirectory(at: appSupportDir, withIntermediateDirectories: true)
        } catch {
            print("Failed to create app support directory: \(error)")
        }
        
        self.cacheFile = appSupportDir.appendingPathComponent("metadata_cache.json")
        loadCache()
    }
    
    private func loadCache() {
        guard let data = try? Data(contentsOf: cacheFile),
              let dict = try? JSONDecoder().decode([String: String].self, from: data) else {
            return
        }
        self.cachedAppIds = dict
    }
    
    private func saveCache() {
        queue.async { [weak self] in
            guard let self = self else { return }
            if let data = try? JSONEncoder().encode(self.cachedAppIds) {
                try? data.write(to: self.cacheFile)
            }
        }
    }
    
    func getImageUrl(for game: Game) -> URL? {
        switch game.launcher {
        case .steam:
            // Steam games have their appid locally or in the CDN
            let home = NSHomeDirectory()
            let steamAppsPath = SettingsManager.shared.steamAppsPath.replacingOccurrences(of: "~", with: home)
            let steamPath = URL(fileURLWithPath: steamAppsPath).deletingLastPathComponent().path
            let localPath = "\(steamPath)/appcache/librarycache/\(game.launchId)/library_600x900.jpg"
            if fileExists(atPath: localPath) {
                return URL(fileURLWithPath: localPath)
            }
            return URL(string: "https://shared.fastly.steamstatic.com/store_item_assets/steam/apps/\(game.launchId)/library_600x900.jpg")
            
        case .ryujinx, .mythic:
            // Clean title first to strip group tags, version info, dump tags
            let cleanTitle = getCleanTitle(for: game.title)
            
            // Normalize the game title to use as cache/lookup key
            let normalizedTitle = cleanTitle.lowercased()
                .replacingOccurrences(of: ":", with: "")
                .replacingOccurrences(of: "-", with: "")
                .trimmingCharacters(in: .whitespacesAndNewlines)
            
            // 1. Check custom URLs (e.g. Nintendo exclusives)
            if let customUrlString = customGameImageUrls[normalizedTitle],
               let url = URL(string: customUrlString) {
                return url
            }
            
            // 2. Check titleToSteamAppIdMap pre-seed
            if let steamAppId = titleToSteamAppIdMap[normalizedTitle] {
                return URL(string: "https://shared.fastly.steamstatic.com/store_item_assets/steam/apps/\(steamAppId)/library_600x900.jpg")
            }
            
            // 3. Check dynamic search cache
            if let cachedId = cachedAppIds[normalizedTitle] {
                if cachedId == "notFound" {
                    return nil
                }
                return URL(string: "https://shared.fastly.steamstatic.com/store_item_assets/steam/apps/\(cachedId)/library_600x900.jpg")
            }
            
            // 4. Trigger async search
            resolveSteamAppId(for: cleanTitle, normalizedKey: normalizedTitle)
            return nil
        }
    }
    
    private func fileExists(atPath path: String) -> Bool {
        return FileManager.default.fileExists(atPath: path)
    }
    
    private func getCleanTitle(for title: String) -> String {
        var clean = title
            .replacingOccurrences(of: "™", with: "")
            .replacingOccurrences(of: "®", with: "")
            .replacingOccurrences(of: "__", with: " ")
        
        // Strip brackets [v0] etc
        if let regex = try? NSRegularExpression(pattern: "\\[[^\\]]+\\]", options: []) {
            clean = regex.stringByReplacingMatches(in: clean, options: [], range: NSRange(location: 0, length: clean.utf16.count), withTemplate: "")
        }
        
        // Strip known repack / dump / scene strings
        let patternsToStrip = [
            "Switch-xci\\.com",
            "Switch-xci",
            "FitGirl Repack",
            "FitGirl",
            "Repack",
            "\\(1\\)",
            "\\(2\\)",
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
    
    private func resolveSteamAppId(for cleanTitle: String, normalizedKey: String) {
        queue.async { [weak self] in
            guard let self = self else { return }
            
            // Check if request is already in progress
            guard !self.pendingRequests.contains(normalizedKey) else { return }
            self.pendingRequests.insert(normalizedKey)
            
            guard let encodedTitle = cleanTitle.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed),
                  let url = URL(string: "https://store.steampowered.com/api/storesearch/?term=\(encodedTitle)&l=english&cc=US") else {
                self.pendingRequests.remove(normalizedKey)
                return
            }
            
            URLSession.shared.dataTask(with: url) { [weak self] data, response, error in
                guard let self = self else { return }
                defer { self.pendingRequests.remove(normalizedKey) }
                
                guard let data = data, error == nil else { return }
                
                struct SteamSearchResponse: Codable {
                    struct SearchItem: Codable {
                        let id: Int
                        let name: String
                    }
                    let items: [SearchItem]
                }
                
                if let result = try? JSONDecoder().decode(SteamSearchResponse.self, from: data) {
                    let appId: String
                    if let firstItem = result.items.first {
                        appId = String(firstItem.id)
                    } else {
                        appId = "notFound"
                    }
                    
                    DispatchQueue.main.async {
                        self.cachedAppIds[normalizedKey] = appId
                        self.saveCache()
                        // Notify observers that the cache was updated
                        self.objectWillChange.send()
                    }
                }
            }.resume()
        }
    }
}
