import SwiftUI

struct GameSelectionSheet: View {
    @EnvironmentObject var dojoManager: DojoManager
    @Environment(\.dismiss) var dismiss
    
    var body: some View {
        ZStack {
            // Purple background
            Color(red: 0.349, green: 0.122, blue: 1.0)
                .ignoresSafeArea()
            
            VStack(spacing: 0) {
                // Custom Header with Close Button
                HStack {
                    Text("Select Game")
                        .font(.system(size: 24, weight: .bold))
                        .foregroundColor(.white)
                    
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
                Text("Game #\(game.tokenId.suffix(6))")
                    .font(.system(size: 18, weight: .bold))
                    .foregroundColor(.white)
                
                if let model = gameModel {
                    Text("Score: \(model.score ?? 0)")
                        .font(.system(size: 14))
                        .foregroundColor(.white.opacity(0.7))
                } else {
                    Text("New Game")
                        .font(.system(size: 14))
                        .foregroundColor(.green.opacity(0.8))
                }
            }
            
            Spacer()
            
            // Play/Continue button
            Button(action: {
                // TODO: Start or continue game
                print("🎮 \(hasGameModel ? "Continue" : "Start") game: \(game.tokenId)")
            }) {
                Text(hasGameModel ? "Continue" : "Play")
                    .font(.system(size: 16, weight: .bold))
                    .foregroundColor(hasGameModel ? .white : Color(red: 0.349, green: 0.122, blue: 1.0))
                    .padding(.horizontal, 24)
                    .padding(.vertical, 12)
                    .background(
                        hasGameModel
                            ? Color.white.opacity(0.2)
                            : LinearGradient(
                                colors: [Color.yellow, Color.orange],
                                startPoint: .top,
                                endPoint: .bottom
                            )
                    )
                    .cornerRadius(12)
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

