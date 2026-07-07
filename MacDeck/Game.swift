//
//  Game.swift
//  MacDeck
//

import Foundation

enum Launcher: String, Codable, CaseIterable {
    case steam = "Steam"
    case ryujinx = "Ryujinx"
    case mythic = "Mythic"
}

struct Game: Identifiable, Hashable, Codable {
    var id: String {
        return "\(launcher.rawValue)-\(launchId)"
    }
    
    let title: String
    let launcher: Launcher
    let launchId: String
    let romPath: String?
    let sizeOnDisk: UInt64?
    let lastPlayed: Date?
    
    var formattedSize: String {
        guard let size = sizeOnDisk else { return "Unknown size" }
        let formatter = ByteCountFormatter()
        formatter.allowedUnits = [.useGB, .useMB]
        formatter.countStyle = .file
        return formatter.string(fromByteCount: Int64(size))
    }
}
