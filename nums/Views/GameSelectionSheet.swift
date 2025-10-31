import SwiftUI

struct GameSelectionSheet: View {
    @EnvironmentObject var dojoManager: DojoManager
    @EnvironmentObject var sessionManager: SessionManager
    @Environment(\.dismiss) var dismiss
    @State private var currentTime = Date()
    @State private var isBuyingGame = false
    @State private var showNewGameView = false
    @State private var newGameId: String? = nil
    @State private var buyError: String? = nil
    @State private var showBuyError = false
    
    // User's games (already filtered by fetchUserGames), sorted with active games first
    private var userGames: [Game] {
        return dojoManager.games.sorted { game1, game2 in
            let model1 = dojoManager.gameModels[game1.tokenId]
            let model2 = dojoManager.gameModels[game2.tokenId]
            
            let isOver1 = model1?.over ?? false
            let isOver2 = model2?.over ?? false
            
            // Active games (not over) come first
            if isOver1 != isOver2 {
                return !isOver1 && isOver2
            }
            
            // For games with the same status, sort by token ID (newest first)
            return game1.tokenId > game2.tokenId
        }
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
        ZStack {
            // Purple gradient background (matching GameView and MainView)
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
                // Custom Header (similar to HowToPlaySheet)
                HStack(alignment: .top) {
                    VStack(alignment: .leading, spacing: 6) {
                        Text(tournamentName)
                            .font(.system(size: 32, weight: .black, design: .rounded))
                            .foregroundColor(Color(red: 0.7, green: 0.6, blue: 1.0))
                        Text("Ends in \(timeRemaining)")
                            .font(.system(size: 16, weight: .medium))
                            .foregroundColor(.white.opacity(0.8))
                    }
                }
                .padding(.horizontal, 20)
                .padding(.top, 20)
                .padding(.bottom, 20)
                
                // Entry Options
                VStack(spacing: 12) {
                    // Play with Nums - 2000 NUMS (Primary, bigger)
                    Button(action: {
                        buyNewGame()
                    }) {
                        HStack(spacing: 8) {
                            if isBuyingGame {
                                ProgressView()
                                    .progressViewStyle(CircularProgressViewStyle(tint: Color(red: 0.2, green: 0.15, blue: 0.4)))
                                    .scaleEffect(1.2)
                            }
                            Text(isBuyingGame ? "BUYING..." : "\(Constants.gameCostNums) NUMS")
                                .font(.system(size: 20, weight: .black, design: .rounded))
                                .foregroundColor(Color(red: 0.2, green: 0.15, blue: 0.4))
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 18)
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
                    .disabled(isBuyingGame)
                    
                    // Secondary options row
                    HStack(spacing: 12) {
                        // Share on X - Free
                        Button(action: {
                            // TODO: Share on X action
                        }) {
                            Text("Share on X")
                                .font(.system(size: 14, weight: .semibold))
                                .foregroundColor(.white.opacity(0.5))
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 12)
                                .background(Color.white.opacity(0.1))
                                .cornerRadius(12)
                        }
                        .disabled(true)
                        
                        // Play with USD - $1.13
                        Button(action: {
                            // TODO: Play with USD action
                        }) {
                            Text("$1.13")
                                .font(.system(size: 14, weight: .semibold))
                                .foregroundColor(.white.opacity(0.5))
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 12)
                                .background(Color.white.opacity(0.1))
                                .cornerRadius(12)
                        }
                        .disabled(true)
                    }
                }
                .padding(.horizontal, 20)
                .padding(.bottom, 4)
                
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
                    // Games list with sections
                    ScrollView {
                        VStack(alignment: .leading, spacing: 20) {
                            // Active Games Section
                            let activeGames = userGames.filter { game in
                                guard let model = dojoManager.gameModels[game.tokenId] else { return false }
                                return !model.over
                            }
                            
                            if !activeGames.isEmpty {
                                VStack(alignment: .leading, spacing: 12) {
                                    Text("ACTIVE GAMES")
                                        .font(.system(size: 14, weight: .bold))
                                        .foregroundColor(.white.opacity(0.6))
                                        .padding(.horizontal, 4)
                                    
                                    ForEach(activeGames) { game in
                                        GameRow(game: game, dojoManager: dojoManager)
                                    }
                                }
                            }
                            
                            // Finished Games Section
                            let finishedGames = userGames.filter { game in
                                guard let model = dojoManager.gameModels[game.tokenId] else { return false }
                                return model.over
                            }
                            
                            if !finishedGames.isEmpty {
                                VStack(alignment: .leading, spacing: 12) {
                                    Text("FINISHED GAMES")
                                        .font(.system(size: 14, weight: .bold))
                                        .foregroundColor(.white.opacity(0.6))
                                        .padding(.horizontal, 4)
                                    
                                    ForEach(finishedGames) { game in
                                        GameRow(game: game, dojoManager: dojoManager)
                                    }
                                }
                            }
                        }
                        .padding(20)
                    }
                }
            }
            .padding(.top, 20)
        }
        .onAppear {
            // Stop leaderboard polling while in game selection
            dojoManager.stopLeaderboardPolling()
            
            // Start timer to update countdown every second
            Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { _ in
                currentTime = Date()
            }
            
            // Games are already loaded before this sheet is shown (in MainView Play button)
            // No need to fetch here
        }
        .onDisappear {
            // Resume leaderboard polling when returning to main view
            dojoManager.resumeLeaderboardPolling()
        }
        .fullScreenCover(isPresented: $showNewGameView) {
            if let gameId = newGameId {
                GameView(
                    gameTokenId: gameId,
                    isNewGame: true
                )
                .environmentObject(dojoManager)
                .environmentObject(sessionManager)
            }
        }
        .overlay(
            // Buy error banner
            VStack {
                if showBuyError, let error = buyError {
                    HStack {
                        Image(systemName: "exclamationmark.triangle.fill")
                            .font(.system(size: 16))
                            .foregroundColor(.white)
                        Text(error)
                            .font(.system(size: 14, weight: .medium))
                            .foregroundColor(.white)
                            .lineLimit(2)
                        Spacer()
                        Button(action: {
                            withAnimation(.spring()) {
                                showBuyError = false
                            }
                        }) {
                            Image(systemName: "xmark")
                                .font(.system(size: 12, weight: .bold))
                                .foregroundColor(.white.opacity(0.7))
                        }
                    }
                    .padding(.horizontal, 16)
                    .padding(.vertical, 12)
                    .background(
                        RoundedRectangle(cornerRadius: 12)
                            .fill(Color.red.opacity(0.9))
                            .shadow(color: .black.opacity(0.3), radius: 8, x: 0, y: 4)
                    )
                    .padding(.horizontal, 20)
                    .transition(.move(edge: .top).combined(with: .opacity))
                    
                    Spacer()
                }
            }
            .padding(.top, 60)
        )
    }
    
    // Buy a new game
    private func buyNewGame() {
        guard let username = sessionManager.sessionUsername else {
            buyError = "No username found. Please reconnect your wallet."
            withAnimation(.spring()) {
                showBuyError = true
            }
            return
        }
        
        guard let tournament = dojoManager.selectedTournament else {
            buyError = "No tournament selected"
            withAnimation(.spring()) {
                showBuyError = true
            }
            return
        }
        
        isBuyingGame = true
        
        Task {
            do {
                let gameId = try await dojoManager.buyGame(
                    username: username,
                    tournamentId: UInt64(tournament.id),
                    sessionManager: sessionManager
                )
                
                await MainActor.run {
                    isBuyingGame = false
                    newGameId = gameId
                    showNewGameView = true
                }
            } catch {
                await MainActor.run {
                    isBuyingGame = false
                    buyError = error.localizedDescription
                    withAnimation(.spring()) {
                        showBuyError = true
                    }
                    
                    // Auto-dismiss after 5 seconds
                    DispatchQueue.main.asyncAfter(deadline: .now() + 5) {
                        withAnimation(.spring()) {
                            showBuyError = false
                        }
                    }
                }
            }
        }
    }
}

struct GameRow: View {
    let game: Game
    @ObservedObject var dojoManager: DojoManager
    @EnvironmentObject var sessionManager: SessionManager
    @State private var showGameView = false
    @State private var isStartingGame = false
    @State private var startError: String? = nil
    @State private var showStartError = false
    
    // Check if a NUMS-Game model exists for this token AND game is actually started
    private var hasGameModel: Bool {
        guard let model = dojoManager.gameModels[game.tokenId] else {
            return false
        }
        // Check if game has been started (number should be > 0)
        return model.number > 0
    }
    
    private var gameModel: GameModel? {
        dojoManager.gameModels[game.tokenId]
    }
    
    // Check if game is over
    private var isGameOver: Bool {
        gameModel?.over ?? false
    }
    
    // Check if reward has been claimed
    private var isRewardClaimed: Bool {
        gameModel?.claimed ?? false
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
    
    // Get reward amount
    private var reward: Int {
        Int(gameModel?.reward ?? 0)
    }
    
    var body: some View {
        HStack(spacing: 16) {
            // Game icon
            ZStack {
                Circle()
                    .fill(isGameOver ? Color.red.opacity(0.2) : Color.white.opacity(0.1))
                    .frame(width: 60, height: 60)
                
                Image(systemName: isGameOver ? "flag.checkered.circle.fill" : "gamecontroller.fill")
                    .font(.system(size: 24))
                    .foregroundColor(isGameOver ? Color.red.opacity(0.8) : .white)
            }
            
            // Game info
            VStack(alignment: .leading, spacing: 4) {
                HStack(spacing: 8) {
                    Text("Game #\(String(format: "%04d", gameIdDecimal))")
                        .font(.system(size: 18, weight: .bold))
                        .foregroundColor(.white)
                    
                    if isGameOver {
                        Text(isRewardClaimed ? "CLAIMED" : "FINISHED")
                            .font(.system(size: 10, weight: .bold))
                            .foregroundColor(isRewardClaimed ? Color.green : Color.orange)
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(
                                RoundedRectangle(cornerRadius: 4)
                                    .fill(isRewardClaimed ? Color.green.opacity(0.2) : Color.orange.opacity(0.2))
                            )
                    }
                }
                
                HStack(spacing: 12) {
                    Text("Score: \(score)")
                        .font(.system(size: 14))
                        .foregroundColor(.white.opacity(0.7))
                    
                    if isGameOver && reward > 0 {
                        Text("Reward: \(reward) NUMS")
                            .font(.system(size: 14, weight: .medium))
                            .foregroundColor(Color.yellow)
                    }
                }
            }
            
            Spacer()
            
            // Action button (Start/Continue/View)
            Button(action: {
                if isGameOver {
                    // For game over games, just view the results
                    print("🎮 View game results: \(game.tokenId)")
                    showGameView = true
                } else if hasGameModel {
                    // Game already started with valid number, continue it
                    print("🎮 Continue game: \(game.tokenId) (number: \(gameModel?.number ?? 0))")
                    showGameView = true
                } else {
                    // Game needs to be started first
                    print("🎮 Start game: \(game.tokenId) (no model or not started)")
                    startGame()
                }
            }) {
                HStack(spacing: 6) {
                    if isStartingGame {
                        ProgressView()
                            .progressViewStyle(CircularProgressViewStyle(tint: Color(red: 0.2, green: 0.15, blue: 0.4)))
                            .scaleEffect(0.8)
                    }
                    Group {
                        if isGameOver {
                            Text("View")
                                .font(.system(size: 14, weight: .bold))
                                .foregroundColor(.white)
                        } else if hasGameModel {
                            Text("Continue")
                                .font(.system(size: 14, weight: .bold))
                                .foregroundColor(.white)
                        } else {
                            Text(isStartingGame ? "Starting..." : "Start")
                                .font(.system(size: 14, weight: .bold))
                                .foregroundColor(Color(red: 0.2, green: 0.15, blue: 0.4))
                        }
                    }
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 10)
                .background(
                    isGameOver
                        ? AnyView(Color.white.opacity(0.15))
                        : hasGameModel 
                            ? AnyView(Color.white.opacity(0.2))
                            : AnyView(
                                LinearGradient(
                                    colors: [Color.yellow, Color.orange],
                                    startPoint: .top,
                                    endPoint: .bottom
                                )
                            )
                )
                .cornerRadius(12)
                .lineLimit(1)
            }
            .disabled(isStartingGame)
        }
        .padding(16)
        .background(
            isGameOver 
                ? Color.white.opacity(0.05)
                : Color.white.opacity(0.1)
        )
        .cornerRadius(16)
        .overlay(
            RoundedRectangle(cornerRadius: 16)
                .stroke(
                    isGameOver ? Color.red.opacity(0.3) : Color.clear,
                    lineWidth: isGameOver ? 1 : 0
                )
        )
        .fullScreenCover(isPresented: $showGameView) {
            GameView(
                gameTokenId: game.tokenId,
                isNewGame: !hasGameModel
            )
            .environmentObject(dojoManager)
            .environmentObject(sessionManager)
        }
        .overlay(
            // Start error banner
            VStack {
                if showStartError, let error = startError {
                    HStack {
                        Image(systemName: "exclamationmark.triangle.fill")
                            .font(.system(size: 14))
                            .foregroundColor(.white)
                        Text(error)
                            .font(.system(size: 12, weight: .medium))
                            .foregroundColor(.white)
                            .lineLimit(2)
                        Spacer()
                        Button(action: {
                            withAnimation(.spring()) {
                                showStartError = false
                            }
                        }) {
                            Image(systemName: "xmark")
                                .font(.system(size: 10, weight: .bold))
                                .foregroundColor(.white.opacity(0.7))
                        }
                    }
                    .padding(.horizontal, 12)
                    .padding(.vertical, 8)
                    .background(
                        RoundedRectangle(cornerRadius: 10)
                            .fill(Color.red.opacity(0.9))
                            .shadow(color: .black.opacity(0.3), radius: 5, x: 0, y: 2)
                    )
                    .transition(.move(edge: .top).combined(with: .opacity))
                }
            },
            alignment: .top
        )
    }
    
    // Start a game (request_random + start)
    private func startGame() {
        isStartingGame = true
        
        Task {
            do {
                // Call the start game function
                try await dojoManager.startGame(
                    gameId: game.tokenId,
                    tournamentId: dojoManager.selectedTournament?.id ?? 0,
                    sessionManager: sessionManager
                )
                
                // Wait a moment for the game to be initialized
                try await Task.sleep(nanoseconds: 1_000_000_000) // 1 second
                
                await MainActor.run {
                    isStartingGame = false
                    showGameView = true
                }
            } catch {
                await MainActor.run {
                    isStartingGame = false
                    startError = error.localizedDescription
                    withAnimation(.spring()) {
                        showStartError = true
                    }
                    
                    // Auto-dismiss after 5 seconds
                    DispatchQueue.main.asyncAfter(deadline: .now() + 5) {
                        withAnimation(.spring()) {
                            showStartError = false
                        }
                    }
                }
            }
        }
    }
}

#Preview {
    GameSelectionSheet()
        .environmentObject(DojoManager())
        .environmentObject(SessionManager())
}

