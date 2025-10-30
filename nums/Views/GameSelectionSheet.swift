import SwiftUI

struct GameSelectionSheet: View {
    @EnvironmentObject var dojoManager: DojoManager
    @EnvironmentObject var sessionManager: SessionManager
    @Environment(\.dismiss) var dismiss
    @State private var currentTime = Date()
    
    // User's games (already filtered by fetchUserGames)
    private var userGames: [Game] {
        return dojoManager.games
    }
    
    private var tournamentName: String {
        guard let tournament = dojoManager.selectedTournament else {
            return "Tournament"
        }
        return "TOURNAMENT #\(tournament.id)"
    }
    
    private var timeRemaining: String {
        guard let tournament = dojoManager.selectedTournament else {
            return "00:00:00"
        }
        
        let remaining = tournament.endDate.timeIntervalSince(currentTime)
        
        if remaining <= 0 {
            return "ENDED"
        }
        
        let hours = Int(remaining) / 3600
        let minutes = (Int(remaining) % 3600) / 60
        let seconds = Int(remaining) % 60
        
        return String(format: "%02d:%02d:%02d", hours, minutes, seconds)
    }
    
    var body: some View {
        NavigationStack {
            ZStack {
                // Purple gradient background (matching GameView)
                LinearGradient(
                    colors: [
                        Color(red: 0.4, green: 0.2, blue: 0.8),
                        Color(red: 0.3, green: 0.1, blue: 0.6)
                    ],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
                .ignoresSafeArea()
            
            VStack(spacing: 0) {
                // Glass morphism container
                VStack(spacing: 0) {
                    // Custom Header with Close Button
                    HStack {
                        VStack(alignment: .leading, spacing: 4) {
                            Text("Enter \(tournamentName)")
                                .font(.system(size: 24, weight: .bold))
                                .foregroundColor(.white)
                            Text("Tournament ends in \(timeRemaining)")
                                .font(.system(size: 14))
                                .foregroundColor(.white.opacity(0.7))
                        }
                        
                        Spacer()
                        
                        Button(action: {
                            dismiss()
                        }) {
                            Image(systemName: "xmark.circle.fill")
                                .font(.system(size: 28))
                                .foregroundColor(.white.opacity(0.6))
                        }
                    }
                    .padding(.horizontal, 20)
                    .padding(.top, 20)
                    .padding(.bottom, 16)
                
                // Entry Options
                HStack(spacing: 12) {
                    // Share on X - Free
                    Button(action: {
                        // TODO: Share on X action
                    }) {
                        Text("Share on X")
                            .font(.system(size: 16, weight: .bold))
                            .foregroundColor(.white.opacity(0.5))
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 12)
                            .background(
                                RoundedRectangle(cornerRadius: 12)
                                    .fill(.ultraThinMaterial)
                                    .overlay(
                                        RoundedRectangle(cornerRadius: 12)
                                            .fill(Color.white.opacity(0.15))
                                    )
                                    .overlay(
                                        RoundedRectangle(cornerRadius: 12)
                                            .stroke(Color.white.opacity(0.3), lineWidth: 1)
                                    )
                            )
                    }
                    .disabled(true)
                    
                    // Play with Nums - 2000 NUMS (Active)
                    Button(action: {
                        // TODO: Play with NUMS action
                    }) {
                        Text("2000 Nums")
                            .font(.system(size: 16, weight: .bold))
                            .foregroundColor(Color(red: 0.2, green: 0.15, blue: 0.4))
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 12)
                            .background(
                                LinearGradient(
                                    colors: [Color.yellow, Color.orange],
                                    startPoint: .top,
                                    endPoint: .bottom
                                )
                            )
                            .cornerRadius(12)
                    }
                    
                    // Play with USD - $1.13
                    Button(action: {
                        // TODO: Play with USD action
                    }) {
                        Text("$1.13")
                            .font(.system(size: 16, weight: .bold))
                            .foregroundColor(.white.opacity(0.5))
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 12)
                            .background(
                                RoundedRectangle(cornerRadius: 12)
                                    .fill(.ultraThinMaterial)
                                    .overlay(
                                        RoundedRectangle(cornerRadius: 12)
                                            .fill(Color.white.opacity(0.15))
                                    )
                                    .overlay(
                                        RoundedRectangle(cornerRadius: 12)
                                            .stroke(Color.white.opacity(0.3), lineWidth: 1)
                                    )
                            )
                    }
                    .disabled(true)
                }
                .padding(.horizontal, 20)
                .padding(.bottom, 16)
                
                if dojoManager.isLoadingGames {
                    // Loading state
                    VStack(spacing: 16) {
                        ProgressView()
                            .progressViewStyle(CircularProgressViewStyle(tint: .white))
                            .scaleEffect(1.5)
                        Text("Loading your games...")
                            .font(.system(size: 16))
                            .foregroundColor(.white.opacity(0.7))
                    }
                    .frame(maxHeight: .infinity)
                } else if userGames.isEmpty {
                    // No games state
                    VStack(spacing: 16) {
                        Image(systemName: "gamecontroller")
                            .font(.system(size: 60))
                            .foregroundColor(.white.opacity(0.3))
                        Text("No games found")
                            .font(.system(size: 20, weight: .semibold))
                            .foregroundColor(.white)
                        Text("You don't have any game tokens yet")
                            .font(.system(size: 14))
                            .foregroundColor(.white.opacity(0.7))
                    }
                    .frame(maxHeight: .infinity)
                } else {
                    // Games list
                    ScrollView {
                        VStack(spacing: 12) {
                            ForEach(userGames) { game in
                                GameRow(game: game, dojoManager: dojoManager)
                            }
                        }
                        .padding(20)
                    }
                }
                }
                .background(
                    ZStack {
                        // Glassmorphism effect
                        RoundedRectangle(cornerRadius: 30)
                            .fill(.ultraThinMaterial)
                            .overlay(
                                RoundedRectangle(cornerRadius: 30)
                                    .fill(
                                        LinearGradient(
                                            colors: [
                                                Color.white.opacity(0.25),
                                                Color.white.opacity(0.1),
                                                Color.white.opacity(0.05)
                                            ],
                                            startPoint: .topLeading,
                                            endPoint: .bottomTrailing
                                        )
                                    )
                            )
                            .overlay(
                                RoundedRectangle(cornerRadius: 30)
                                    .stroke(
                                        LinearGradient(
                                            colors: [
                                                Color.white.opacity(0.6),
                                                Color.white.opacity(0.3),
                                                Color.white.opacity(0.1)
                                            ],
                                            startPoint: .topLeading,
                                            endPoint: .bottomTrailing
                                        ),
                                        lineWidth: 1.5
                                    )
                            )
                            .shadow(color: Color.black.opacity(0.3), radius: 20, x: 0, y: 10)
                            .shadow(color: Color.purple.opacity(0.3), radius: 30, x: 0, y: 20)
                    }
                )
                .padding(.horizontal, 16)
                .padding(.top, 20)
                .padding(.bottom, 20)
            }
            }
            .navigationBarHidden(true)
        }
        .onAppear {
            // Stop leaderboard polling while in game selection
            dojoManager.stopLeaderboardPolling()
            
            // Start timer to update countdown every second
            Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { _ in
                currentTime = Date()
            }
            
            // Fetch user's games when sheet opens
            if let userAddress = sessionManager.sessionAddress {
                print("🎮 GameSelectionSheet opened for user: \(userAddress)")
                Task {
                    await dojoManager.fetchUserGames(for: userAddress)
                }
            }
        }
        .onDisappear {
            // Resume leaderboard polling when returning to main view
            dojoManager.resumeLeaderboardPolling()
        }
    }
}

struct GameRow: View {
    let game: Game
    @ObservedObject var dojoManager: DojoManager
    @EnvironmentObject var sessionManager: SessionManager
    
    // Check if a NUMS-Game model exists for this token
    private var hasGameModel: Bool {
        dojoManager.gameModels[game.tokenId] != nil
    }
    
    private var gameModel: GameModel? {
        dojoManager.gameModels[game.tokenId]
    }
    
    // Convert hex token ID to decimal
    private var gameIdDecimal: Int {
        // Remove "0x" prefix if present
        let hexString = game.tokenId.hasPrefix("0x") ? String(game.tokenId.dropFirst(2)) : game.tokenId
        // Convert hex to decimal
        return Int(hexString, radix: 16) ?? 0
    }
    
    // Get score from model or default to 0
    private var score: Int {
        Int(gameModel?.score ?? 0)
    }
    
    var body: some View {
        HStack(spacing: 16) {
            // Game icon
            ZStack {
                Circle()
                    .fill(.ultraThinMaterial)
                    .overlay(
                        Circle()
                            .fill(
                                LinearGradient(
                                    colors: [
                                        Color.white.opacity(0.3),
                                        Color.white.opacity(0.1)
                                    ],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                )
                            )
                    )
                    .overlay(
                        Circle()
                            .stroke(Color.white.opacity(0.4), lineWidth: 1.5)
                    )
                    .frame(width: 60, height: 60)
                    .shadow(color: Color.purple.opacity(0.3), radius: 8, x: 0, y: 4)
                
                Image(systemName: "gamecontroller.fill")
                    .font(.system(size: 24))
                    .foregroundColor(.white)
            }
            
            // Game info
            VStack(alignment: .leading, spacing: 4) {
                Text("Game #\(String(format: "%04d", gameIdDecimal))")
                    .font(.system(size: 18, weight: .bold))
                    .foregroundColor(.white)
                
                Text("Score: \(score)")
                    .font(.system(size: 14))
                    .foregroundColor(.white.opacity(0.7))
            }
            
            Spacer()
            
            // Play/Continue button
            NavigationLink(destination: GameView(
                gameTokenId: game.tokenId,
                isNewGame: !hasGameModel
            )
            .environmentObject(dojoManager)
            .environmentObject(sessionManager)
            .navigationBarHidden(true)
            ) {
                Group {
                    if hasGameModel {
                        Text("Continue")
                            .font(.system(size: 14, weight: .bold))
                            .foregroundColor(.white)
                            .padding(.horizontal, 16)
                            .padding(.vertical, 10)
                            .background(
                                RoundedRectangle(cornerRadius: 12)
                                    .fill(.ultraThinMaterial)
                                    .overlay(
                                        RoundedRectangle(cornerRadius: 12)
                                            .fill(Color.white.opacity(0.2))
                                    )
                                    .overlay(
                                        RoundedRectangle(cornerRadius: 12)
                                            .stroke(Color.white.opacity(0.4), lineWidth: 1)
                                    )
                            )
                            .lineLimit(1)
                    } else {
                        Text("Play")
                            .font(.system(size: 14, weight: .bold))
                            .foregroundColor(Color(red: 0.2, green: 0.15, blue: 0.4))
                            .padding(.horizontal, 16)
                            .padding(.vertical, 10)
                            .background(
                                LinearGradient(
                                    colors: [Color.yellow, Color.orange],
                                    startPoint: .top,
                                    endPoint: .bottom
                                )
                            )
                            .cornerRadius(12)
                            .lineLimit(1)
                    }
                }
            }
        }
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 20)
                .fill(.ultraThinMaterial)
                .overlay(
                    RoundedRectangle(cornerRadius: 20)
                        .fill(
                            LinearGradient(
                                colors: [
                                    Color.white.opacity(0.2),
                                    Color.white.opacity(0.1)
                                ],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 20)
                        .stroke(
                            Color.white.opacity(0.3),
                            lineWidth: 1
                        )
                )
                .shadow(color: Color.black.opacity(0.2), radius: 8, x: 0, y: 4)
        )
    }
}

#Preview {
    GameSelectionSheet()
        .environmentObject(DojoManager())
        .environmentObject(SessionManager())
}

