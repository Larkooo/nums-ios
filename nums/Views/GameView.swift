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
    @State private var slotValues: [UInt16] = []
    @State private var isSettingSlot = false
    @State private var selectedSlot: Int? = nil
    @State private var dragOffset: CGFloat = 0
    
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
                .padding(.top, 16)
                
                // Current Number Display
                VStack(spacing: 8) {
                    Text("YOUR NUMBER IS...")
                        .font(.system(size: 13, weight: .semibold, design: .rounded))
                        .foregroundColor(.white.opacity(0.6))
                        .tracking(2.5)
                    
                    if currentNumber > 0 {
                        Text("\(currentNumber)")
                            .font(.system(size: 72, weight: .black, design: .rounded))
                            .foregroundColor(.white)
                            .shadow(color: .purple.opacity(0.6), radius: 12, x: 0, y: 4)
                            .shadow(color: .black.opacity(0.3), radius: 4, x: 0, y: 2)
                    } else if isNewGame {
                        Text("START")
                            .font(.system(size: 36, weight: .black, design: .rounded))
                            .foregroundColor(.white.opacity(0.5))
                    } else {
                        ProgressView()
                            .progressViewStyle(CircularProgressViewStyle(tint: .white))
                            .scaleEffect(1.5)
                    }
                }
                .frame(height: 100)
                .padding(.top, 8)
                .padding(.bottom, 16)
                
                // Slots Grid (2 columns, 10 rows) - Centered with padding
                VStack(spacing: 8) {
                    ForEach(0..<10, id: \.self) { row in
                        HStack(spacing: 12) {
                            // Left column
                            SlotButton(
                                slotNumber: row + 1,
                                slotValue: slotValues.indices.contains(row) ? slotValues[row] : 0,
                                isDisabled: isGameOver || isSettingSlot,
                                action: {
                                    setSlot(row + 1)
                                }
                            )
                            .frame(maxWidth: .infinity)
                            
                            // Right column
                            SlotButton(
                                slotNumber: row + 11,
                                slotValue: slotValues.indices.contains(row + 10) ? slotValues[row + 10] : 0,
                                isDisabled: isGameOver || isSettingSlot,
                                action: {
                                    setSlot(row + 11)
                                }
                            )
                            .frame(maxWidth: .infinity)
                        }
                    }
                }
                .padding(.horizontal, 40)
                
                Spacer(minLength: 32)
                
                // Bottom Score and Reward Info
                HStack(spacing: 0) {
                    // Score
                    VStack(alignment: .center, spacing: 8) {
                        Image(systemName: "star.fill")
                            .font(.system(size: 20))
                            .foregroundColor(.purple.opacity(0.8))
                        Text("SCORE")
                            .font(.system(size: 12, weight: .semibold, design: .rounded))
                            .foregroundColor(.white.opacity(0.5))
                            .tracking(1)
                        Text("\(score)")
                            .font(.system(size: 32, weight: .black, design: .rounded))
                            .foregroundColor(.white)
                            .shadow(color: .purple.opacity(0.3), radius: 4, x: 0, y: 2)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 4)
                    
                    Divider()
                        .frame(width: 2, height: 80)
                        .background(
                            LinearGradient(
                                colors: [.white.opacity(0.1), .white.opacity(0.3), .white.opacity(0.1)],
                                startPoint: .top,
                                endPoint: .bottom
                            )
                        )
                    
                    // Reward
                    VStack(alignment: .center, spacing: 8) {
                        Image(systemName: "trophy.fill")
                            .font(.system(size: 20))
                            .foregroundColor(.yellow.opacity(0.9))
                        Text("REWARD")
                            .font(.system(size: 12, weight: .semibold, design: .rounded))
                            .foregroundColor(.white.opacity(0.5))
                            .tracking(1)
                        Text("\(reward)")
                            .font(.system(size: 32, weight: .black, design: .rounded))
                            .foregroundColor(.yellow)
                            .shadow(color: .yellow.opacity(0.3), radius: 4, x: 0, y: 2)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 4)
                }
                .padding(.horizontal, 24)
                .padding(.vertical, 20)
                .background(
                    RoundedRectangle(cornerRadius: 20)
                        .fill(
                            LinearGradient(
                                colors: [Color.black.opacity(0.4), Color.black.opacity(0.3)],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                        .overlay(
                            RoundedRectangle(cornerRadius: 20)
                                .stroke(
                                    LinearGradient(
                                        colors: [.white.opacity(0.3), .white.opacity(0.1)],
                                        startPoint: .topLeading,
                                        endPoint: .bottomTrailing
                                    ),
                                    lineWidth: 1
                                )
                        )
                        .shadow(color: .black.opacity(0.3), radius: 10, x: 0, y: 5)
                )
                .padding(.horizontal, 20)
                .padding(.bottom, 32)
            }
            .safeAreaInset(edge: .top, spacing: 0) {
                Color.clear.frame(height: 0)
            }
            .safeAreaInset(edge: .bottom, spacing: 0) {
                Color.clear.frame(height: 0)
            }
        }
        .offset(x: dragOffset)
        .gesture(
            DragGesture()
                .onChanged { gesture in
                    // Only allow dragging from left edge (swipe right)
                    if gesture.translation.width > 0 {
                        dragOffset = gesture.translation.width
                    }
                }
                .onEnded { gesture in
                    if gesture.translation.width > 100 {
                        // Swipe threshold met, dismiss
                        dismiss()
                    } else {
                        // Animate back
                        withAnimation(.spring()) {
                            dragOffset = 0
                        }
                    }
                }
        )
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
        slotValues = model.slotValues
        
        // Clear loading state if we were setting a slot
        if isSettingSlot {
            isSettingSlot = false
            selectedSlot = nil
        }
        
        print("   ✅ UI state updated successfully")
        print("   🎰 Slot values loaded: \(slotValues.enumerated().filter { $0.element > 0 }.map { "Slot \($0.offset + 1)=\($0.element)" })")
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
    let slotValue: UInt16
    let isDisabled: Bool
    let action: () -> Void
    
    var isSet: Bool {
        slotValue > 0
    }
    
    var displayText: String {
        if slotValue > 0 {
            return "\(slotValue)"
        } else {
            return "?"
        }
    }
    
    var body: some View {
        Button(action: action) {
            HStack(spacing: 10) {
                Text("\(slotNumber).")
                    .font(.system(size: 18, weight: .semibold, design: .rounded))
                    .foregroundColor(.white.opacity(0.5))
                    .frame(width: 32, alignment: .trailing)
                
                Text(displayText)
                    .font(.system(size: 20, weight: .bold, design: .rounded))
                    .foregroundColor(isSet ? .white : .white.opacity(0.4))
                    .frame(width: 65)
                    .lineLimit(1)
                    .minimumScaleFactor(0.7)
            }
            .frame(maxWidth: .infinity)
            .frame(height: 48)
            .background(
                Group {
                    if isSet {
                        LinearGradient(
                            colors: [Color.green.opacity(0.7), Color.green.opacity(0.5)],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    } else {
                        LinearGradient(
                            colors: [Color.white.opacity(0.2), Color.white.opacity(0.12)],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    }
                }
            )
            .cornerRadius(14)
            .overlay(
                RoundedRectangle(cornerRadius: 14)
                    .stroke(
                        LinearGradient(
                            colors: isSet
                                ? [Color.green.opacity(0.6), Color.green.opacity(0.3)]
                                : [Color.white.opacity(0.3), Color.white.opacity(0.1)],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        ),
                        lineWidth: 1.5
                    )
            )
            .shadow(color: isSet ? Color.green.opacity(0.3) : Color.black.opacity(0.2), radius: isSet ? 6 : 3, x: 0, y: 2)
        }
        .disabled(isDisabled || isSet)
        .buttonStyle(ScaleButtonStyle())
    }
}

// Custom button style for scale effect
struct ScaleButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? 0.95 : 1.0)
            .animation(.easeInOut(duration: 0.1), value: configuration.isPressed)
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

