//
//  ContentView.swift
//  MacDeck
//

import SwiftUI
import Combine

enum ActiveTab: Hashable, CaseIterable {
    case all
    case steam
    case ryujinx
    case mythic
    case settings
    
    var title: String {
        switch self {
        case .all: return "All Games"
        case .steam: return "Steam"
        case .ryujinx: return "Ryujinx"
        case .mythic: return "Mythic"
        case .settings: return "Settings"
        }
    }
    
    var iconName: String {
        switch self {
        case .all: return "gamecontroller.fill"
        case .steam: return "smoke.fill"
        case .ryujinx: return "switch.2"
        case .mythic: return "bolt.horizontal.fill"
        case .settings: return "gearshape.fill"
        }
    }
    
    var launcher: Launcher? {
        switch self {
        case .all: return nil
        case .steam: return .steam
        case .ryujinx: return .ryujinx
        case .mythic: return .mythic
        case .settings: return nil
        }
    }
}

struct ContentView: View {
    @StateObject private var controllerManager = ControllerManager.shared
    @Namespace private var animationNamespace
    
    @State private var games: [Game] = []
    @State private var activeTab: ActiveTab = .all
    @State private var selectedGameIndex: Int = 0
    @State private var isLaunching = false
    @State private var launchingGameName = ""
    @State private var statusMessage: String? = nil
    @State private var keyMonitor: Any? = nil
    
    // Columns configuration for the grid
    private let columns = [
        GridItem(.adaptive(minimum: 180, maximum: 240), spacing: 20)
    ]
    
    // Compute filtered games based on category
    var filteredGames: [Game] {
        if let category = activeTab.launcher {
            return games.filter { $0.launcher == category }
        }
        return games
    }
    
    var body: some View {
        ScrollViewReader { proxy in
            ZStack {
                // Background Gradient
                LinearGradient(
                    gradient: Gradient(colors: [
                        Color(nsColor: .windowBackgroundColor),
                        Color(nsColor: .underPageBackgroundColor),
                        Color(nsColor: .shadowColor).opacity(0.8)
                    ]),
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
                .ignoresSafeArea()
                
                VStack(spacing: 0) {
                    // Header Bar (Horizontal menu)
                    HStack {
                        // App Title
                        Text("MacDeck")
                            .font(.system(size: 20, weight: .bold, design: .rounded))
                            .foregroundStyle(.white)
                        
                        Spacer()
                        
                        // Navigation Pills (with premium sliding matched geometry highlight)
                        HStack(spacing: 4) {
                            ForEach(ActiveTab.allCases, id: \.self) { tab in
                                let isSelected = activeTab == tab
                                
                                Button(action: {
                                    withAnimation(.spring(response: 0.3, dampingFraction: 0.75)) {
                                        activeTab = tab
                                        selectedGameIndex = 0
                                    }
                                }) {
                                    HStack(spacing: 8) {
                                        Image(systemName: tab.iconName)
                                            .font(.system(size: 13))
                                        Text(tab.title)
                                            .font(.system(size: 13, weight: .semibold, design: .rounded))
                                    }
                                    .padding(.horizontal, 16)
                                    .padding(.vertical, 8)
                                    .foregroundColor(isSelected ? .white : .white.opacity(0.6))
                                    .background(
                                        ZStack {
                                            if isSelected {
                                                Capsule()
                                                    .fill(Color.white.opacity(0.15))
                                                    .matchedGeometryEffect(id: "activeTabBackground", in: animationNamespace)
                                            }
                                        }
                                    )
                                }
                                .buttonStyle(.plain)
                            }
                        }
                        .padding(4)
                        .background(Color.black.opacity(0.25))
                        .clipShape(Capsule())
                        .overlay(
                            Capsule()
                                .stroke(Color.white.opacity(0.08), lineWidth: 1)
                        )
                        
                        Spacer()
                        
                        // Controller Status Banner
                        HStack(spacing: 8) {
                            Circle()
                                .fill(controllerManager.isControllerConnected ? Color.green : Color.red)
                                .frame(width: 8, height: 8)
                            Text(controllerManager.isControllerConnected ? controllerManager.controllerName : "Connect Controller")
                                .font(.system(size: 11, weight: .medium, design: .rounded))
                                .foregroundColor(.secondary)
                        }
                        .padding(.horizontal, 12)
                        .padding(.vertical, 6)
                        .background(Color.white.opacity(0.05))
                        .clipShape(Capsule())
                    }
                    .padding(.horizontal, 25)
                    .padding(.vertical, 15)
                    .background(.ultraThinMaterial)
                    
                    Divider()
                        .background(Color.white.opacity(0.05))
                    
                    // Main Grid View
                    VStack(alignment: .leading, spacing: 20) {
                        if let msg = statusMessage {
                            HStack {
                                Text(msg)
                                    .foregroundColor(.white)
                                    .font(.callout)
                                Spacer()
                                Button("Dismiss") {
                                    statusMessage = nil
                                }
                                .buttonStyle(.plain)
                                .foregroundColor(.blue)
                            }
                            .padding()
                            .background(Color.red.opacity(0.2))
                            .cornerRadius(8)
                            .padding(.horizontal, 25)
                        }
                        
                        if activeTab == .settings {
                            SettingsView(onSettingsChanged: {
                                loadGames()
                            })
                            .frame(maxWidth: .infinity, maxHeight: .infinity)
                        } else {
                            if filteredGames.isEmpty {
                                VStack(spacing: 15) {
                                    Spacer()
                                    Image(systemName: "tray.fill")
                                        .font(.system(size: 64))
                                        .foregroundColor(.secondary)
                                    Text("No games found")
                                        .font(.title2)
                                        .fontWeight(.semibold)
                                    Text("Make sure Steam, Ryujinx, or Mythic are installed and have configured libraries.")
                                        .font(.body)
                                        .foregroundColor(.secondary)
                                        .multilineTextAlignment(.center)
                                        .padding(.horizontal, 50)
                                    Spacer()
                                }
                                .frame(maxWidth: .infinity, maxHeight: .infinity)
                            } else {
                                ScrollView {
                                    LazyVGrid(columns: columns, spacing: 25) {
                                        ForEach(0..<filteredGames.count, id: \.self) { index in
                                            let game = filteredGames[index]
                                            GameCardView(
                                                game: game,
                                                isSelected: index == selectedGameIndex
                                            )
                                            .id(game.id)
                                            .zIndex(index == selectedGameIndex ? 1 : 0)
                                            .onTapGesture {
                                                selectedGameIndex = index
                                                launchSelectedGame()
                                            }
                                        }
                                    }
                                    .padding(25)
                                }
                                .clipped()
                                .onChange(of: selectedGameIndex) { _, newIndex in
                                    if newIndex >= 0 && newIndex < filteredGames.count {
                                        withAnimation(.easeOut(duration: 0.15)) {
                                            proxy.scrollTo(filteredGames[newIndex].id, anchor: .center)
                                        }
                                    }
                                }
                            }
                            
                            // Game Details Panel / Controller bar
                            if !filteredGames.isEmpty && selectedGameIndex < filteredGames.count {
                                let selectedGame = filteredGames[selectedGameIndex]
                                HStack {
                                    VStack(alignment: .leading, spacing: 4) {
                                        Text(selectedGame.title)
                                            .font(.title3)
                                            .fontWeight(.bold)
                                        
                                        HStack(spacing: 15) {
                                            Text(selectedGame.launcher.rawValue)
                                                .foregroundColor(.blue)
                                                .fontWeight(.semibold)
                                            Text(selectedGame.formattedSize)
                                                .foregroundColor(.secondary)
                                            if let last = selectedGame.lastPlayed {
                                                Text("Last played: \(last.formatted(date: .abbreviated, time: .omitted))")
                                                    .foregroundColor(.secondary)
                                            }
                                        }
                                        .font(.caption)
                                    }
                                    
                                    Spacer()
                                    
                                    Button(action: launchSelectedGame) {
                                        Text("Launch Game")
                                            .fontWeight(.bold)
                                            .foregroundColor(.white)
                                            .padding(.horizontal, 24)
                                            .padding(.vertical, 12)
                                            .background(Color.blue)
                                            .cornerRadius(8)
                                    }
                                    .buttonStyle(.plain)
                                }
                                .padding(20)
                                .background(.ultraThinMaterial)
                                .overlay(
                                    VStack {
                                        Divider()
                                            .background(Color.white.opacity(0.1))
                                        Spacer()
                                    }
                                )
                            }
                        }
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                }
                
                // Launching Overlay
                if isLaunching {
                    Color.black.opacity(0.85)
                        .ignoresSafeArea()
                    
                    VStack(spacing: 20) {
                        ProgressView()
                            .scaleEffect(1.5)
                        Text("Launching \(launchingGameName)...")
                            .font(.title2)
                            .fontWeight(.bold)
                        Text("Get your controller ready!")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                    }
                    .foregroundColor(.white)
                }
            }
            .onAppear {
                loadGames()
                setupControllerHandlers()
                setupKeyboardMonitor()
            }
            .onDisappear {
                removeKeyboardMonitor()
            }
            .frame(minWidth: 850, minHeight: 550)
        }
    }
    
    private func loadGames() {
        games = LibraryScanner.shared.scanAllGames()
        if selectedGameIndex >= filteredGames.count {
            selectedGameIndex = max(0, filteredGames.count - 1)
        }
    }
    
    private func handleDirectionKey(_ direction: ControllerDirection) {
        if self.activeTab == .settings { return }
        let count = self.filteredGames.count
        guard count > 0 else { return }
        
        // Assume 4 columns for grid nav calculations dynamically based on window width or roughly 4
        let cols = 4
        
        switch direction {
        case .left:
            if self.selectedGameIndex > 0 {
                self.selectedGameIndex -= 1
            }
        case .right:
            if self.selectedGameIndex < count - 1 {
                self.selectedGameIndex += 1
            }
        case .up:
            if self.selectedGameIndex >= cols {
                self.selectedGameIndex -= cols
            } else {
                self.selectedGameIndex = 0
            }
        case .down:
            if self.selectedGameIndex + cols < count {
                self.selectedGameIndex += cols
            } else {
                self.selectedGameIndex = count - 1
            }
        }
    }
    
    private func setupControllerHandlers() {
        controllerManager.onButtonAPressed = {
            if self.activeTab != .settings {
                self.launchSelectedGame()
            }
        }
        
        controllerManager.onButtonBPressed = {
            // Unfocus game or clear categories
            if self.activeTab != .all {
                self.activeTab = .all
                self.selectedGameIndex = 0
            }
        }
        
        controllerManager.onLeftShoulderPressed = {
            self.selectPreviousCategory()
        }
        
        controllerManager.onRightShoulderPressed = {
            self.selectNextCategory()
        }
        
        controllerManager.onDirectionPressed = { direction in
            self.handleDirectionKey(direction)
        }
    }
    
    private func setupKeyboardMonitor() {
        self.keyMonitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { event in
            // If the user is typing in settings, let normal textfields handle keyboard events
            if self.activeTab == .settings {
                return event
            }
            
            switch event.keyCode {
            case 123: // Left arrow
                self.handleDirectionKey(.left)
                return nil
            case 124: // Right arrow
                self.handleDirectionKey(.right)
                return nil
            case 125: // Down arrow
                self.handleDirectionKey(.down)
                return nil
            case 126: // Up arrow
                self.handleDirectionKey(.up)
                return nil
            case 36: // Enter / Return
                self.launchSelectedGame()
                return nil
            case 49: // Space
                self.launchSelectedGame()
                return nil
            case 53: // Escape
                if self.activeTab != .all {
                    self.activeTab = .all
                    self.selectedGameIndex = 0
                }
                return nil
            case 48: // Tab
                if event.modifierFlags.contains(.shift) {
                    self.selectPreviousCategory()
                } else {
                    self.selectNextCategory()
                }
                return nil
            default:
                return event
            }
        }
    }
    
    private func removeKeyboardMonitor() {
        if let monitor = self.keyMonitor {
            NSEvent.removeMonitor(monitor)
            self.keyMonitor = nil
        }
    }
    
    private func selectNextCategory() {
        let tabs = ActiveTab.allCases
        guard let currentIndex = tabs.firstIndex(of: activeTab) else { return }
        let nextIndex = (currentIndex + 1) % tabs.count
        activeTab = tabs[nextIndex]
        selectedGameIndex = 0
    }
    
    private func selectPreviousCategory() {
        let tabs = ActiveTab.allCases
        guard let currentIndex = tabs.firstIndex(of: activeTab) else { return }
        let prevIndex = (currentIndex - 1 + tabs.count) % tabs.count
        activeTab = tabs[prevIndex]
        selectedGameIndex = 0
    }
    
    private func launchSelectedGame() {
        let count = filteredGames.count
        guard count > 0, selectedGameIndex < count else { return }
        
        let game = filteredGames[selectedGameIndex]
        launchingGameName = game.title
        withAnimation {
            isLaunching = true
        }
        
        LaunchManager.shared.launch(game: game) { success, errorMsg in
            DispatchQueue.main.async {
                withAnimation {
                    self.isLaunching = false
                }
                if !success {
                    self.statusMessage = errorMsg ?? "Unknown error launching game"
                }
            }
        }
    }
    

}

// Game Card View for grid
struct GameCardView: View {
    let game: Game
    let isSelected: Bool
    @ObservedObject var metadataManager = MetadataManager.shared
    
    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            ZStack {
                // Background fallback gradient
                RoundedRectangle(cornerRadius: 12)
                    .fill(
                        LinearGradient(
                            gradient: Gradient(colors: launcherColors(for: game.launcher)),
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                
                // Real cover image loaded asynchronously
                if let url = metadataManager.getImageUrl(for: game) {
                    AsyncImage(url: url) { phase in
                        switch phase {
                        case .success(let image):
                            image
                                .resizable()
                                .aspectRatio(contentMode: .fill)
                                .frame(minWidth: 0, maxWidth: .infinity, minHeight: 0, maxHeight: .infinity)
                                .clipped()
                                .cornerRadius(12)
                        case .failure:
                            placeholderView
                        case .empty:
                            ProgressView()
                                .scaleEffect(0.8)
                        @unknown default:
                            placeholderView
                        }
                    }
                } else {
                    placeholderView
                }
            }
            .aspectRatio(0.667, contentMode: .fit) // Standard 600x900 aspect ratio
            .scaleEffect(isSelected ? 1.05 : 1.0)
            .overlay(
                RoundedRectangle(cornerRadius: 12)
                    .stroke(isSelected ? Color.blue : Color.clear, lineWidth: 3)
            )
            .shadow(radius: isSelected ? 15 : 5)
            .padding(6) // Prevent clipping from scaleEffect and selection border
            .animation(.easeInOut(duration: 0.15), value: isSelected)
            
            Text(game.title)
                .font(.headline)
                .lineLimit(1)
                .foregroundColor(isSelected ? .blue : .primary)
        }
    }
    
    private var placeholderView: some View {
        VStack {
            Spacer()
            Image(systemName: launcherIcon(for: game.launcher))
                .font(.system(size: 32))
                .foregroundColor(.white.opacity(0.8))
            Spacer()
        }
    }
    
    private func launcherIcon(for launcher: Launcher) -> String {
        switch launcher {
        case .steam: return "steam"
        case .ryujinx: return "gamecontroller"
        case .mythic: return "bolt"
        }
    }
    
    private func launcherColors(for launcher: Launcher) -> [Color] {
        switch launcher {
        case .steam:
            return [Color.blue.opacity(0.8), Color.black.opacity(0.8)]
        case .ryujinx:
            return [Color.red.opacity(0.8), Color.blue.opacity(0.8)]
        case .mythic:
            return [Color.purple.opacity(0.8), Color.black.opacity(0.8)]
        }
    }
}
