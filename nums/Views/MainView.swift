import SwiftUI

struct LeaderboardEntry: Identifiable {
    let id = UUID()
    let rank: Int
    let player: String
    let score: Int
    let prize: String
    let isCurrentUser: Bool
}

struct MainView: View {
    @EnvironmentObject var dojoManager: DojoManager
    @EnvironmentObject var sessionManager: SessionManager
    
    @State private var currentPage = 1
    @State private var totalPages = 64
    @State private var showSessionInfo = false
    @State private var showGameSelection = false
    @State private var showHowToPlay = false
    @State private var isSoundEnabled = true
    @State private var currentTime = Date() // For updating countdown timer
    @State private var sessionInfoDetent: PresentationDetent = .medium
    
    // Check if session is valid (not expired and not revoked)
    private var isSessionValid: Bool {
        guard sessionManager.sessionAccount != nil else { return false }
        return !sessionManager.isExpired && !sessionManager.isRevoked
    }
    
    // Helper function to generate a random private key
    func generateRandomPrivateKey() -> String {
        let bytes = (0..<32).map { _ in UInt8.random(in: 0...255) }
        return "0x" + bytes.map { String(format: "%02x", $0) }.joined()
    }
    
    // Helper function to format balance with thousand separators
    func formatBalance(_ balance: BInt) -> String {
        // Convert BInt to string and format with thousand separators
        let balanceString = balance.description
        
        // If negative, handle sign separately
        let isNegative = balanceString.hasPrefix("-")
        let numberString = isNegative ? String(balanceString.dropFirst()) : balanceString
        
        // Add thousand separators
        var result = ""
        var count = 0
        for char in numberString.reversed() {
            if count > 0 && count % 3 == 0 {
                result.append(",")
            }
            result.append(char)
            count += 1
        }
        
        // Reverse back and add sign if negative
        let formattedString = String(result.reversed())
        return isNegative ? "-\(formattedString)" : formattedString
    }
    
    // Tournament data from DojoManager
    private var tournamentId: Int {
        dojoManager.selectedTournament?.id ?? 1
    }
    
    private var entryCount: Int {
        dojoManager.selectedTournament?.entryCount ?? 0
    }
    
    private var timeRemaining: String {
        guard let tournament = dojoManager.selectedTournament else {
            return "00:00:00"
        }
        
        // Use currentTime to trigger updates every second
        let remaining = tournament.endDate.timeIntervalSince(currentTime)
        
        // If tournament has ended
        if remaining <= 0 {
            return "ENDED"
        }
        
        // Calculate hours, minutes, seconds
        let hours = Int(remaining) / 3600
        let minutes = (Int(remaining) % 3600) / 60
        let seconds = Int(remaining) % 60
        
        return String(format: "%02d:%02d:%02d", hours, minutes, seconds)
    }
    
    // Leaderboard data from DojoManager (shows player leaderboard if available)
    private var leaderboard: [LeaderboardEntry] {
        let currentAddress = sessionManager.sessionAddress?.lowercased() ?? ""
        
        // Show player leaderboard (games aggregated by player) if available
        if !dojoManager.playerLeaderboard.isEmpty {
            return dojoManager.playerLeaderboard.enumerated().map { (index, player) in
                LeaderboardEntry(
                    rank: index + 1,
                    player: player.username ?? String(player.address.prefix(10)), // Show username or address
                    score: player.gameCount, // Game count as score
                    prize: "-", // No prize for game leaderboard
                    isCurrentUser: player.address.lowercased() == currentAddress
                )
            }
        }
        
        // Fall back to tournament leaderboard
        return dojoManager.leaderboard.enumerated().map { (index, player) in
            LeaderboardEntry(
                rank: index + 1,
                player: String(player.games.prefix(10)), // Show first 10 chars of games
                score: player.capacity,
                prize: String(player.requirement),
                isCurrentUser: false // TODO: Compare with current user's address
            )
        }
    }
    
    var body: some View {
        ZStack {
            // Purple background
            Color(red: 0.349, green: 0.122, blue: 1.0)
                .ignoresSafeArea()
            
            VStack(spacing: 0) {
                // Top Bar
                HStack(spacing: 10) {
                    // NUMS icon button
                    Button(action: {}) {
                        Image("nums-icon")
                            .resizable()
                            .renderingMode(.template)
                            .aspectRatio(contentMode: .fit)
                            .frame(width: 22, height: 30)
                            .foregroundColor(.white)
                            .frame(width: 50, height: 50)
                            .background(Color.white.opacity(0.1))
                            .cornerRadius(12)
                    }
                    
                    // Sound toggle button
                    Button(action: {
                        isSoundEnabled.toggle()
                    }) {
                        Image(systemName: isSoundEnabled ? "speaker.wave.2.fill" : "speaker.slash.fill")
                            .font(.system(size: 20))
                            .foregroundColor(.white)
                            .frame(width: 50, height: 50)
                            .background(Color.white.opacity(0.1))
                            .cornerRadius(12)
                    }
                    
                    // Balance
                    HStack(spacing: 10) {
                        if dojoManager.isLoadingBalance {
                            ProgressView()
                                .progressViewStyle(CircularProgressViewStyle(tint: .white))
                        } else {
                            Text(formatBalance(dojoManager.tokenBalance))
                                .font(.system(size: 20, weight: .bold, design: .rounded))
                                .foregroundColor(.white)
                                .lineLimit(1)
                                .minimumScaleFactor(0.6)
                        }
                    }
                    .padding(.horizontal, 14)
                    .padding(.vertical, 12)
                    .frame(height: 50)
                    .background(Color.white.opacity(0.1))
                    .cornerRadius(12)
                    
                    Spacer()
                    
                    // Connection Status
                    if isSessionValid {
                        // Show username with controller icon - tap to show session info
                        Button(action: {
                            showSessionInfo = true
                        }) {
                            HStack(spacing: 8) {
                                Image("controller-icon")
                                    .resizable()
                                    .renderingMode(.template)
                                    .aspectRatio(contentMode: .fit)
                                    .frame(width: 18, height: 18)
                                    .foregroundColor(.white)
                                Text(sessionManager.sessionUsername ?? "User")
                                    .font(.system(size: 16, weight: .semibold))
                                    .foregroundColor(.white)
                                    .lineLimit(1)
                                    .minimumScaleFactor(0.7)
                            }
                            .padding(.horizontal, 14)
                            .frame(height: 50)
                            .background(Color.white.opacity(0.1))
                            .cornerRadius(12)
                        }
                    } else {
                        // Show connect button
                        Button(action: {
                            // Generate key and open session registration directly
                            if sessionManager.privateKey.isEmpty {
                                sessionManager.privateKey = generateRandomPrivateKey()
                                sessionManager.updatePublicKey()
                            }
                            sessionManager.openSessionInWebView()
                        }) {
                            HStack(spacing: 8) {
                                if sessionManager.isLoading {
                                    ProgressView()
                                        .progressViewStyle(CircularProgressViewStyle(tint: .white))
                                } else {
                                    Image(systemName: "person.crop.circle.badge.plus")
                                        .font(.system(size: 18))
                                    Text("Connect")
                                        .font(.system(size: 16, weight: .semibold))
                                }
                            }
                            .foregroundColor(.white)
                            .padding(.horizontal, 14)
                            .frame(height: 50)
                            .background(Color.green.opacity(0.8))
                            .cornerRadius(12)
                        }
                        .disabled(sessionManager.isLoading)
                    }
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 12)
                
                // Jackpot Header
                VStack(spacing: 8) {
                    HStack {
                        Image(systemName: "trophy.fill")
                            .foregroundColor(.yellow)
                        
                        Button(action: {
                            dojoManager.showTournamentSelector = true
                        }) {
                            HStack(spacing: 4) {
                                Text("TOURNAMENT #\(tournamentId)")
                                    .font(.system(size: 28, weight: .black, design: .rounded))
                                    .foregroundColor(.white)
                                    .minimumScaleFactor(0.5)
                                    .lineLimit(1)
                                Image(systemName: "chevron.down")
                                    .foregroundColor(.white)
                                    .font(.caption)
                            }
                        }
                        
                        Spacer()
                        
                        Button(action: {
                            showHowToPlay = true
                        }) {
                            Image(systemName: "info.circle")
                                .font(.title2)
                                .foregroundColor(.white)
                        }
                    }
                    .padding(.horizontal, 20)
                }
                .padding(.vertical, 12)
                
                // Tournament Info Card
                VStack(spacing: 12) {
                    HStack {
                        VStack(alignment: .leading, spacing: 4) {
                            Text("TOURNAMENT #\(tournamentId)")
                                .font(.system(size: 26, weight: .bold, design: .rounded))
                                .foregroundColor(.white)
                                .minimumScaleFactor(0.6)
                                .lineLimit(1)
                            Text("ACTIVE")
                                .font(.system(size: 14, weight: .bold))
                                .foregroundColor(.green)
                        }
                        
                        Spacer()
                        
                        VStack(alignment: .trailing, spacing: 4) {
                            Text("\(entryCount) ENTRIES")
                                .font(.system(size: 18, weight: .heavy, design: .rounded))
                                .foregroundColor(.white)
                            HStack(spacing: 4) {
                                Text("ENDS IN:")
                                    .font(.caption)
                                    .foregroundColor(.purple.opacity(0.8))
                                Text(timeRemaining)
                                    .font(.caption)
                                    .foregroundColor(.purple.opacity(0.8))
                            }
                        }
                    }
                    .padding(20)
                    .background(Color.white.opacity(0.08))
                    .cornerRadius(16)
                }
                .padding(.horizontal, 16)
                .padding(.bottom, 12)
                
                // Leaderboard
                VStack(spacing: 0) {
                    // Header
                    HStack {
                        Text("RANK")
                            .frame(width: 60, alignment: .leading)
                        Text("PLAYER")
                            .frame(maxWidth: .infinity, alignment: .leading)
                        Text("SCORE")
                            .frame(width: 70, alignment: .center)
                        Text("PRIZE")
                            .frame(width: 70, alignment: .trailing)
                    }
                    .font(.system(size: 14, weight: .bold, design: .rounded))
                    .foregroundColor(.white.opacity(0.5))
                    .padding(.horizontal, 20)
                    .padding(.vertical, 12)
                    
                    // Entries
                    ScrollView {
                        VStack(spacing: 8) {
                            ForEach(leaderboard) { entry in
                                HStack {
                                    Text("\(entry.rank)")
                                        .font(.system(size: 18, weight: .bold, design: .rounded))
                                        .foregroundColor(entry.isCurrentUser ? .yellow : .white.opacity(0.6))
                                        .frame(width: 60, alignment: .leading)
                                    
                                    Text(entry.player)
                                        .font(.system(size: 16, weight: .semibold, design: .rounded))
                                        .foregroundColor(entry.isCurrentUser ? .yellow : .white)
                                        .frame(maxWidth: .infinity, alignment: .leading)
                                    
                                    Text("\(entry.score)")
                                        .font(.system(size: 18, weight: .bold, design: .rounded))
                                        .foregroundColor(entry.isCurrentUser ? .yellow : .white)
                                        .frame(width: 70, alignment: .center)
                                    
                                    Text(entry.prize)
                                        .font(.system(size: 16, weight: .bold, design: .rounded))
                                        .foregroundColor(entry.isCurrentUser ? .yellow : .white)
                                        .frame(width: 70, alignment: .trailing)
                                }
                                .padding(.horizontal, 20)
                                .padding(.vertical, 8)
                            }
                        }
                    }
                }
                .frame(maxHeight: .infinity)
                .padding(.horizontal, 16)
                
                // Page Navigation (TODO: Implement pagination or infinite scrolling)
                // HStack(spacing: 12) {
                //     Button(action: {}) {
                //         Image(systemName: "arrow.left")
                //             .foregroundColor(.white.opacity(0.6))
                //             .frame(width: 44, height: 44)
                //     }
                //     
                //     Button(action: {}) {
                //         Text("1")
                //             .font(.system(size: 18, weight: .bold))
                //             .foregroundColor(.white)
                //             .frame(width: 44, height: 44)
                //             .background(Color.white.opacity(0.2))
                //             .cornerRadius(12)
                //     }
                //     
                //     Button(action: {}) {
                //         Text("2")
                //             .font(.system(size: 18, weight: .bold))
                //             .foregroundColor(.white.opacity(0.6))
                //             .frame(width: 44, height: 44)
                //     }
                //     
                //     Text("...")
                //         .foregroundColor(.white.opacity(0.6))
                //     
                //     Button(action: {}) {
                //         Text("\(totalPages)")
                //             .font(.system(size: 18, weight: .bold))
                //             .foregroundColor(.white.opacity(0.6))
                //             .frame(width: 44, height: 44)
                //     }
                //     
                //     Button(action: {}) {
                //         Image(systemName: "arrow.right")
                //             .foregroundColor(.white.opacity(0.6))
                //             .frame(width: 44, height: 44)
                //     }
                // }
                // .padding(.vertical, 12)
                
                // Play Button
                Button(action: {
                    if isSessionValid {
                        showGameSelection = true
                    } else {
                        // Prompt user to connect
                        if sessionManager.privateKey.isEmpty {
                            sessionManager.privateKey = generateRandomPrivateKey()
                            sessionManager.updatePublicKey()
                        }
                        sessionManager.openSessionInWebView()
                    }
                }) {
                    Text(isSessionValid ? "PLAY!" : "CONNECT TO PLAY")
                        .font(.system(size: 28, weight: .black, design: .rounded))
                        .foregroundColor(Color(red: 0.2, green: 0.15, blue: 0.4))
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 20)
                        .background(
                            LinearGradient(
                                colors: [Color.yellow, Color.orange],
                                startPoint: .top,
                                endPoint: .bottom
                            )
                        )
                        .cornerRadius(16)
                        .shadow(color: .black.opacity(0.3), radius: 10, x: 0, y: 5)
                }
                .padding(.horizontal, 16)
                .padding(.bottom, 20)
            }
        }
        .sheet(isPresented: $sessionManager.showWebView) {
            if let url = URL(string: sessionManager.generateSessionURL()) {
                SafariView(url: url)
            }
        }
        .sheet(isPresented: $showSessionInfo) {
            SessionInfoSheet(sessionManager: sessionManager, selectedDetent: $sessionInfoDetent)
                .presentationDetents([.medium, .large], selection: $sessionInfoDetent)
                .presentationDragIndicator(.visible)
        }
        .sheet(isPresented: $sessionManager.showAccountConnectedCard) {
            AccountConnectedSheet(sessionManager: sessionManager)
                .presentationDetents([.medium])
                .presentationDragIndicator(.visible)
        }
        .sheet(isPresented: $dojoManager.showTournamentSelector) {
            TournamentSelectorSheet(dojoManager: dojoManager)
                .presentationDetents([.medium, .large])
                .presentationDragIndicator(.visible)
        }
        .sheet(isPresented: $showGameSelection) {
            GameSelectionSheet()
                .environmentObject(dojoManager)
                .environmentObject(sessionManager)
                .presentationDetents([.medium, .large])
                .presentationDragIndicator(.visible)
        }
        .sheet(isPresented: $showHowToPlay) {
            HowToPlaySheet()
                .presentationDetents([.medium, .large])
                .presentationDragIndicator(.visible)
        }
        .onAppear {
            // Check for persisted session on app launch
            if sessionManager.sessionAccount == nil {
                sessionManager.loadPersistedSession()
            }
            
            // Fetch token balance and subscribe if session is active AND Torii is connected
            if isSessionValid, let address = sessionManager.sessionAddress, dojoManager.isConnected {
                Task {
                    // Fetch initial balance
                    await dojoManager.fetchTokenBalance(for: address)
                    // Subscribe to balance updates
                    await dojoManager.subscribeToTokenBalance(for: address)
                    // Note: fetchAllGames() is called during Torii initialization for leaderboard
                }
            }
            
            // Start timer to update countdown every second
            Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { _ in
                currentTime = Date()
            }
        }
        .onChange(of: dojoManager.isConnected) { isConnected in
            // When Torii client connects, fetch balance if we have a valid session
            if isConnected, isSessionValid, let address = sessionManager.sessionAddress {
                Task {
                    print("🔄 Torii connected - fetching balance for session")
                    await dojoManager.fetchTokenBalance(for: address)
                    await dojoManager.subscribeToTokenBalance(for: address)
                    // Note: fetchAllGames() is already called during Torii initialization
                }
            }
        }
        .onChange(of: sessionManager.sessionAddress) { newAddress in
            // Fetch balance and subscribe when session address changes (only if Torii is connected)
            if isSessionValid, let address = newAddress, dojoManager.isConnected {
                Task {
                    // Fetch initial balance
                    await dojoManager.fetchTokenBalance(for: address)
                    // Subscribe to balance updates
                    await dojoManager.subscribeToTokenBalance(for: address)
                    // Note: Global games and leaderboard remain populated from fetchAllGames()
                }
            } else {
                // Reset balance when disconnected (keep global games/leaderboard)
                dojoManager.tokenBalance = 0
            }
        }
    }
}

#Preview {
    MainView()
        .environmentObject(DojoManager())
        .environmentObject(SessionManager())
}

