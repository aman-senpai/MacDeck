//
//  SettingsView.swift
//  MacDeck
//
//  Created by Antigravity on 7/7/26.
//

import SwiftUI
import AppKit

struct SettingsView: View {
    @ObservedObject var settings = SettingsManager.shared
    var onSettingsChanged: () -> Void
    
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 25) {
                // Header
                Text("Launcher Settings")
                    .font(.system(size: 24, weight: .bold, design: .rounded))
                    .foregroundColor(.white)
                    .padding(.bottom, 5)
                
                // Steam Section
                SettingsSectionView(title: "Steam Config", icon: "smoke.fill", color: .blue) {
                    PathRow(
                        label: "SteamApps Path",
                        description: "Folder containing your Steam app manifests (*.acf files)",
                        path: $settings.steamAppsPath,
                        chooseFiles: false,
                        chooseDirs: true
                    )
                }
                
                // Ryujinx Section
                SettingsSectionView(title: "Ryujinx", icon: "switch.2", color: .red) {
                    PathRow(
                        label: "Ryujinx Executable",
                        description: "Path to the Ryujinx executable binary inside Ryujinx.app",
                        path: $settings.ryujinxAppPath,
                        chooseFiles: true,
                        chooseDirs: false
                    )
                    
                    PathRow(
                        label: "Ryujinx Config Directory",
                        description: "Application support directory containing games data, config.json, and metadata",
                        path: $settings.ryujinxConfigDir,
                        chooseFiles: false,
                        chooseDirs: true
                    )
                    
                    PathRow(
                        label: "Custom ROM Directories",
                        description: "Comma-separated folders containing Switch games. Leave empty to auto-fetch directories configured in Ryujinx.",
                        path: $settings.ryujinxRomDirs,
                        chooseFiles: false,
                        chooseDirs: true
                    )
                }
                
                // Mythic Section
                SettingsSectionView(title: "Mythic", icon: "bolt.horizontal.fill", color: .purple) {
                    PathRow(
                        label: "Installed JSON Path",
                        description: "Mythic installed.json library file",
                        path: $settings.mythicInstalledJson,
                        chooseFiles: true,
                        chooseDirs: false
                    )
                    
                    PathRow(
                        label: "Legendary CLI Executable",
                        description: "Path to the legendary CLI binary bundled with Mythic.app",
                        path: $settings.mythicLegendaryCli,
                        chooseFiles: true,
                        chooseDirs: false
                    )
                    
                    PathRow(
                        label: "Wine64 Binary Path",
                        description: "Path to wine64 binary inside Mythic support folder",
                        path: $settings.mythicWine64,
                        chooseFiles: true,
                        chooseDirs: false
                    )
                    
                    PathRow(
                        label: "Default Wine Prefix Folder",
                        description: "Default prefix directory where Mythic games launch in Wine container",
                        path: $settings.mythicDefaultPrefix,
                        chooseFiles: false,
                        chooseDirs: true
                    )
                    
                    PathRow(
                        label: "Mythic Preferences Plist",
                        description: "Mythic preferences file containing bottle prefix overrides",
                        path: $settings.mythicPlistPath,
                        chooseFiles: true,
                        chooseDirs: false
                    )
                    
                    HStack {
                        VStack(alignment: .leading, spacing: 4) {
                            Text("Launch Offline")
                                .font(.system(size: 13, weight: .semibold))
                                .foregroundColor(.white)
                            Text("Start Mythic games without requesting online authentication (disable this if games require internet check)")
                                .font(.system(size: 11))
                                .foregroundColor(.secondary)
                        }
                        
                        Spacer()
                        
                        Toggle("", isOn: $settings.mythicOfflineMode)
                            .toggleStyle(.switch)
                    }
                    .padding(.top, 5)
                }
                
                // Action Buttons
                HStack(spacing: 15) {
                    Button(action: {
                        settings.resetToDefaults()
                        onSettingsChanged()
                    }) {
                        HStack {
                            Image(systemName: "arrow.counterclockwise")
                            Text("Reset to Defaults")
                        }
                        .fontWeight(.semibold)
                        .foregroundColor(.white)
                        .padding(.horizontal, 16)
                        .padding(.vertical, 10)
                        .background(Color.white.opacity(0.1))
                        .cornerRadius(8)
                    }
                    .buttonStyle(.plain)
                    
                    Button(action: {
                        onSettingsChanged()
                    }) {
                        HStack {
                            Image(systemName: "checkmark.circle.fill")
                            Text("Apply & Scan Games")
                        }
                        .fontWeight(.semibold)
                        .foregroundColor(.white)
                        .padding(.horizontal, 20)
                        .padding(.vertical, 10)
                        .background(Color.blue)
                        .cornerRadius(8)
                    }
                    .buttonStyle(.plain)
                }
                .padding(.top, 10)
            }
            .padding(30)
        }
    }
}

struct SettingsSectionView<Content: View>: View {
    let title: String
    let icon: String
    let color: Color
    let content: Content
    
    init(title: String, icon: String, color: Color, @ViewBuilder content: () -> Content) {
        self.title = title
        self.icon = icon
        self.color = color
        self.content = content()
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            HStack(spacing: 10) {
                Image(systemName: icon)
                    .foregroundColor(color)
                    .font(.system(size: 16, weight: .bold))
                Text(title)
                    .font(.system(size: 16, weight: .bold, design: .rounded))
                    .foregroundColor(.white)
            }
            .padding(.bottom, 5)
            
            VStack(spacing: 15) {
                content
            }
        }
        .padding(20)
        .background(Color.white.opacity(0.04))
        .cornerRadius(12)
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(Color.white.opacity(0.05), lineWidth: 1)
        )
    }
}

struct PathRow: View {
    let label: String
    let description: String
    @Binding var path: String
    let chooseFiles: Bool
    let chooseDirs: Bool
    
    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(label)
                .font(.system(size: 13, weight: .semibold))
                .foregroundColor(.white)
            
            Text(description)
                .font(.system(size: 11))
                .foregroundColor(.secondary)
            
            HStack(spacing: 10) {
                TextField("", text: $path)
                    .textFieldStyle(.plain)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 8)
                    .background(Color.black.opacity(0.2))
                    .cornerRadius(6)
                    .foregroundColor(.white)
                    .overlay(
                        RoundedRectangle(cornerRadius: 6)
                            .stroke(Color.white.opacity(0.1), lineWidth: 1)
                    )
                
                Button("Browse...") {
                    browsePath()
                }
                .buttonStyle(.plain)
                .padding(.horizontal, 14)
                .padding(.vertical, 8)
                .background(Color.white.opacity(0.08))
                .cornerRadius(6)
                .foregroundColor(.white)
            }
        }
    }
    
    private func browsePath() {
        let panel = NSOpenPanel()
        panel.canChooseFiles = chooseFiles
        panel.canChooseDirectories = chooseDirs
        panel.allowsMultipleSelection = false
        
        // Suggest parent directory as starter
        if !path.isEmpty {
            let expandedPath = path.replacingOccurrences(of: "~", with: NSHomeDirectory())
            panel.directoryURL = URL(fileURLWithPath: expandedPath).deletingLastPathComponent()
        }
        
        if panel.runModal() == .OK {
            if let selectedUrl = panel.url {
                var selectedPath = selectedUrl.path
                let home = NSHomeDirectory()
                // Convert back to home-relative path for clean storage if it's in home directory
                if selectedPath.hasPrefix(home) {
                    selectedPath = selectedPath.replacingOccurrences(of: home, with: "~")
                }
                path = selectedPath
            }
        }
    }
}
