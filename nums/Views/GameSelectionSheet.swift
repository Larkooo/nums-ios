import SwiftUI

struct GameSelectionSheet: View {
    @EnvironmentObject var dojoManager: DojoManager
    @Environment(\.dismiss) var dismiss
    @State private var currentTime = Date()
    
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
        ZStack {
            // Purple background
            Color(red: 0.349, green: 0.122, blue: 1.0)
                .ignoresSafeArea()
            
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
                    
                    // Button(action: {
                    //     dismiss()
                    // }) {
                    //     Image(systemName: "xmark.circle.fill")
                    //         .font(.system(size: 28))
                    //         .foregroundColor(.white.opacity(0.6))
                    // }
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
                            .background(Color.white.opacity(0.2))
                            .cornerRadius(12)
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
                            .background(Color.white.opacity(0.2))
                            .cornerRadius(12)
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
                } else if dojoManager.games.isEmpty {
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
                            ForEach(dojoManager.games) { game in
                                GameRow(game: game, dojoManager: dojoManager)
                            }
                        }
                        .padding(20)
                    }
                }
            }
            .padding(.top, 20)
        }
        .onAppear {
            // Start timer to update countdown every second
            Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { _ in
                currentTime = Date()
            }
        }
    }
}

struct GameRow: View {
    let game: Game
    @ObservedObject var dojoManager: DojoManager
    
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
        gameModel?.score ?? 0
    }
    
    var body: some View {
        HStack(spacing: 16) {
            // Game icon
            ZStack {
                Circle()
                    .fill(Color.white.opacity(0.1))
                    .frame(width: 60, height: 60)
                
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
            Button(action: {
                // TODO: Start or continue game
                print("🎮 \(hasGameModel ? "Continue" : "Start") game: \(game.tokenId)")
            }) {
                Group {
                    if hasGameModel {
                        Text("Continue")
                            .font(.system(size: 16, weight: .bold))
                            .foregroundColor(.white)
                            .padding(.horizontal, 24)
                            .padding(.vertical, 12)
                            .background(Color.white.opacity(0.2))
                            .cornerRadius(12)
                    } else {
                        Text("Play")
                            .font(.system(size: 16, weight: .bold))
                            .foregroundColor(Color(red: 0.2, green: 0.15, blue: 0.4))
                            .padding(.horizontal, 24)
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
                }
            }
        }
        .padding(16)
        .background(Color.white.opacity(0.1))
        .cornerRadius(16)
    }
}

#Preview {
    GameSelectionSheet()
        .environmentObject(DojoManager())
}

