import SwiftUI

struct GameView: View {
    @EnvironmentObject var dojoManager: DojoManager
    @EnvironmentObject var sessionManager: SessionManager
    @Environment(\.dismiss) var dismiss
    
    let gameTokenId: String
    let isNewGame: Bool
    
    @State private var currentTime = Date()
    @State private var currentNumber: UInt16 = 0
    @State private var nextNumber: UInt16 = 0
    @State private var gameLevel: UInt8 = 1
    @State private var powers: UInt16 = 0
    @State private var score: UInt32 = 0
    @State private var reward: UInt32 = 0
    @State private var slotMin: UInt16 = 1
    @State private var slotMax: UInt16 = 999
    @State private var slotCount: UInt8 = 20
    @State private var isGameOver = false
    @State private var setSlots: Set<Int> = []
    @State private var isSettingSlot = false
    @State private var selectedSlot: Int? = nil
    
    var body: some View {
        ZStack {
            // Background
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
                // Top bar with back button
                HStack {
                    Button(action: {
                        dismiss()
                    }) {
                        Image(systemName: "chevron.left")
                            .font(.system(size: 20, weight: .semibold))
                            .foregroundColor(.white)
                            .frame(width: 44, height: 44)
                    }
                    Spacer()
                }
                .padding(.horizontal, 16)
                .padding(.top, 8)
                
                // Current Number Display
                VStack(spacing: 4) {
                    Text("YOUR NUMBER IS...")
                        .font(.system(size: 14, weight: .bold, design: .rounded))
                        .foregroundColor(.white.opacity(0.7))
                        .tracking(2)
                    
                    if currentNumber > 0 {
                        Text("\(currentNumber)")
                            .font(.system(size: 80, weight: .black, design: .rounded))
                            .foregroundColor(.white)
                            .shadow(color: .black.opacity(0.3), radius: 4, x: 0, y: 4)
                    } else if isNewGame {
                        Text("START")
                            .font(.system(size: 40, weight: .black, design: .rounded))
                            .foregroundColor(.white.opacity(0.5))
                    } else {
                        ProgressView()
                            .progressViewStyle(CircularProgressViewStyle(tint: .white))
                            .scaleEffect(1.5)
                    }
                }
                .padding(.top, 8)
                .padding(.bottom, 12)
                
                // Slots Grid (2 columns, 10 rows) - Full width and centered
                VStack(spacing: 10) {
                    ForEach(0..<10, id: \.self) { row in
                        HStack(spacing: 12) {
                            // Left column
                            SlotButton(
                                slotNumber: row + 1,
                                isSet: setSlots.contains(row + 1),
                                isDisabled: isGameOver || isSettingSlot,
                                action: {
                                    setSlot(row + 1)
                                }
                            )
                            .frame(maxWidth: .infinity)
                            
                            // Right column
                            SlotButton(
                                slotNumber: row + 11,
                                isSet: setSlots.contains(row + 11),
                                isDisabled: isGameOver || isSettingSlot,
                                action: {
                                    setSlot(row + 11)
                                }
                            )
                            .frame(maxWidth: .infinity)
                        }
                    }
                }
                .padding(.horizontal, 16)
                
                Spacer(minLength: 8)
                
                // Bottom Score and Reward Info
                HStack(spacing: 0) {
                    // Score
                    VStack(alignment: .center, spacing: 4) {
                        Text("SCORE")
                            .font(.system(size: 14, weight: .bold, design: .rounded))
                            .foregroundColor(.white.opacity(0.6))
                        Text("\(score)")
                            .font(.system(size: 28, weight: .black, design: .rounded))
                            .foregroundColor(.white)
                    }
                    .frame(maxWidth: .infinity)
                    
                    Divider()
                        .frame(width: 1, height: 50)
                        .background(Color.white.opacity(0.2))
                    
                    // Reward
                    VStack(alignment: .center, spacing: 4) {
                        Text("REWARD")
                            .font(.system(size: 14, weight: .bold, design: .rounded))
                            .foregroundColor(.white.opacity(0.6))
                        Text("\(reward)")
                            .font(.system(size: 28, weight: .black, design: .rounded))
                            .foregroundColor(.yellow)
                    }
                    .frame(maxWidth: .infinity)
                }
                .padding(20)
                .background(Color.black.opacity(0.3))
                .cornerRadius(16)
                .padding(.horizontal, 16)
                .padding(.bottom, 16)
            }
        }
        .navigationBarHidden(true)
        .onAppear {
            print("🎮 GameView appeared for token: \(gameTokenId), isNewGame: \(isNewGame)")
            
            // Check if model already exists in dictionary
            if let existingModel = dojoManager.gameModels[gameTokenId] {
                print("   📦 Found existing model in dictionary, loading immediately...")
                loadModelData(existingModel)
            } else {
                print("   ⏳ No existing model, will fetch from network...")
            }
            
            // Start timer for countdown
            Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { _ in
                currentTime = Date()
            }
            
            // Subscribe and load game
            Task {
                // Subscribe to this specific game for real-time updates
                await dojoManager.subscribeToGame(gameTokenId)
                
                if isNewGame {
                    // Start a new game
                    await dojoManager.startGame(
                        gameId: gameTokenId,
                        tournamentId: dojoManager.selectedTournament?.id ?? 1,
                        sessionManager: sessionManager
                    )
                    
                    // Wait a moment for blockchain state to update
                    try? await Task.sleep(nanoseconds: 2_000_000_000)
                }
                
                // Load the current game state (works for both new and existing games)
                _ = await dojoManager.fetchGameModel(gameId: gameTokenId)
            }
        }
        .onDisappear {
            // Unsubscribe from this game
            Task {
                await dojoManager.unsubscribeFromGame(gameTokenId)
            }
        }
        .onChange(of: dojoManager.gameModels[gameTokenId]) { newModel in
            // Update UI when game model changes via subscription or fetch
            print("🔄 GameView onChange triggered for \(gameTokenId)")
            if let model = newModel {
                print("   📊 Updating UI - Score: \(model.score), Number: \(model.number), Next: \(model.nextNumber)")
                print("   🎰 Set slots: \(model.setSlots)")
                loadModelData(model)
            } else {
                print("   ⚠️ Model is nil")
            }
        }
    }
    
    // Helper function to load model data into state
    private func loadModelData(_ model: GameModel) {
        currentNumber = model.number
        nextNumber = model.nextNumber
        gameLevel = model.level
        powers = model.powers
        score = model.score
        reward = model.reward
        slotMin = model.slotMin
        slotMax = model.slotMax
        slotCount = model.slotCount
        isGameOver = model.over
        setSlots = model.setSlots
        
        // Clear loading state if we were setting a slot
        if isSettingSlot {
            isSettingSlot = false
            selectedSlot = nil
        }
        
        print("   ✅ UI state updated successfully")
    }
    
    private func setSlot(_ slotNumber: Int) {
        guard !isSettingSlot, !setSlots.contains(slotNumber), !isGameOver else { return }
        
        isSettingSlot = true
        selectedSlot = slotNumber
        
        print("🎯 Setting slot #\(slotNumber) for game \(gameTokenId)")
        
        Task {
            await dojoManager.setGameSlot(
                gameId: gameTokenId,
                slot: UInt8(slotNumber),
                sessionManager: sessionManager
            )
            
            // Game state will update automatically via subscription
            // No need to manually reload
        }
    }
}

// Slot Button Component
struct SlotButton: View {
    let slotNumber: Int
    let isSet: Bool
    let isDisabled: Bool
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            HStack(spacing: 12) {
                Text("\(slotNumber).")
                    .font(.system(size: 20, weight: .bold, design: .rounded))
                    .foregroundColor(.white.opacity(0.6))
                    .frame(width: 35, alignment: .trailing)
                
                Text(isSet ? "✓" : "Set")
                    .font(.system(size: 18, weight: .bold, design: .rounded))
                    .foregroundColor(.white)
                    .frame(width: 70)
            }
            .frame(maxWidth: .infinity)
            .frame(height: 44)
            .background(
                isSet
                    ? Color.green.opacity(0.6)
                    : Color.white.opacity(0.15)
            )
            .cornerRadius(12)
            .overlay(
                RoundedRectangle(cornerRadius: 12)
                    .stroke(Color.white.opacity(0.2), lineWidth: 1)
            )
        }
        .disabled(isDisabled || isSet)
    }
}

// Jackpot Info Component
struct JackpotInfo: View {
    let tournamentId: Int
    let jackpotAmount: String
    let isActive: Bool
    let timeRemaining: TimeInterval
    let currentTime: Date
    
    private var timeRemainingString: String {
        let hours = Int(timeRemaining) / 3600
        let minutes = (Int(timeRemaining) % 3600) / 60
        let seconds = Int(timeRemaining) % 60
        return String(format: "%02d:%02d:%02d", hours, minutes, seconds)
    }
    
    var body: some View {
        HStack(spacing: 0) {
            VStack(alignment: .leading, spacing: 4) {
                Text("JACKPOT #\(tournamentId)")
                    .font(.system(size: 20, weight: .black, design: .rounded))
                    .foregroundColor(.white)
                
                Text(isActive ? "ACTIVE" : "ENDED")
                    .font(.system(size: 14, weight: .bold, design: .rounded))
                    .foregroundColor(isActive ? Color.green : Color.red)
            }
            
            Spacer()
            
            VStack(alignment: .trailing, spacing: 4) {
                Text(jackpotAmount)
                    .font(.system(size: 20, weight: .black, design: .rounded))
                    .foregroundColor(.white)
                
                HStack(spacing: 4) {
                    Text("ENDS IN:")
                        .font(.system(size: 12, weight: .bold, design: .rounded))
                        .foregroundColor(.white.opacity(0.6))
                    Text(timeRemainingString)
                        .font(.system(size: 12, weight: .bold, design: .rounded))
                        .foregroundColor(.white.opacity(0.6))
                }
            }
        }
        .padding(16)
        .background(Color.black.opacity(0.3))
        .cornerRadius(16)
    }
}

#Preview {
    GameView(gameTokenId: "1", isNewGame: true)
        .environmentObject(DojoManager())
        .environmentObject(SessionManager())
}

