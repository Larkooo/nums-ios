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
    @State private var errorMessage: String? = nil
    @State private var showError = false
    @State private var isSpinning = false
    @State private var spinningNumber: UInt16 = 0
    @State private var optimisticSlotValues: [Int: UInt16] = [:] // slot number -> value
    @State private var showGameOverAnimation = false
    @State private var gameOverOpacity: Double = 0.0
    @State private var glowPulse: CGFloat = 1.0
    
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
                ZStack {
                    // Continuously pulsating glow effect (subtle)
                    if currentNumber > 0 || isSpinning {
                        Circle()
                            .fill(
                                RadialGradient(
                                    colors: [
                                        Color.purple.opacity(0.15 * glowPulse),
                                        Color.purple.opacity(0.08 * glowPulse),
                                        Color.clear
                                    ],
                                    center: .center,
                                    startRadius: 0,
                                    endRadius: 50
                                )
                            )
                            .frame(width: 100, height: 100)
                            .scaleEffect(0.9 + (0.1 * glowPulse))
                    }
                    
                    VStack(spacing: 6) {
                        Text("YOUR NUMBER IS...")
                            .font(.system(size: 11, weight: .semibold, design: .rounded))
                            .foregroundColor(.white.opacity(0.6))
                            .tracking(2)
                        
                        if isSpinning {
                            Text("\(spinningNumber)")
                                .font(.system(size: 56, weight: .black, design: .rounded))
                                .foregroundColor(.white)
                                .shadow(color: .purple.opacity(0.6), radius: 10, x: 0, y: 3)
                                .shadow(color: .black.opacity(0.3), radius: 3, x: 0, y: 2)
                                .transition(.opacity)
                        } else if currentNumber > 0 {
                            Text("\(currentNumber)")
                                .font(.system(size: 56, weight: .black, design: .rounded))
                                .foregroundColor(.white)
                                .shadow(color: .purple.opacity(0.6), radius: 10, x: 0, y: 3)
                                .shadow(color: .black.opacity(0.3), radius: 3, x: 0, y: 2)
                                .transition(.scale.combined(with: .opacity))
                        } else if isNewGame {
                            Text("START")
                                .font(.system(size: 28, weight: .black, design: .rounded))
                                .foregroundColor(.white.opacity(0.5))
                        } else {
                            ProgressView()
                                .progressViewStyle(CircularProgressViewStyle(tint: .white))
                                .scaleEffect(1.2)
                        }
                    }
                }
                .frame(height: 75)
                .padding(.top, 4)
                .padding(.bottom, 12)
                
                Spacer()
                
                // Slots Grid (2 columns, 10 rows) - Centered with padding
                VStack(spacing: 6) {
                    ForEach(0..<10, id: \.self) { row in
                        HStack(spacing: 10) {
                            // Left column
                            SlotButton(
                                slotNumber: row + 1,
                                slotValue: optimisticSlotValues[row + 1] ?? (slotValues.indices.contains(row) ? slotValues[row] : 0),
                                isOptimistic: optimisticSlotValues[row + 1] != nil,
                                isDisabled: isGameOver || isSettingSlot,
                                action: {
                                    setSlot(row + 1)
                                }
                            )
                            .frame(maxWidth: .infinity)
                            
                            // Right column
                            SlotButton(
                                slotNumber: row + 11,
                                slotValue: optimisticSlotValues[row + 11] ?? (slotValues.indices.contains(row + 10) ? slotValues[row + 10] : 0),
                                isOptimistic: optimisticSlotValues[row + 11] != nil,
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
                
                Spacer()
                
                // Bottom Score and Reward Info
                HStack(spacing: 0) {
                    // Score
                    VStack(alignment: .center, spacing: 4) {
                        Image(systemName: "star.fill")
                            .font(.system(size: 16))
                            .foregroundColor(.purple.opacity(0.8))
                        Text("SCORE")
                            .font(.system(size: 10, weight: .semibold, design: .rounded))
                            .foregroundColor(.white.opacity(0.5))
                            .tracking(0.8)
                        Text("\(score)")
                            .font(.system(size: 24, weight: .black, design: .rounded))
                            .foregroundColor(.white)
                            .shadow(color: .purple.opacity(0.3), radius: 3, x: 0, y: 2)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 4)
                    
                    Divider()
                        .frame(width: 2, height: 60)
                        .background(
                            LinearGradient(
                                colors: [.white.opacity(0.1), .white.opacity(0.3), .white.opacity(0.1)],
                                startPoint: .top,
                                endPoint: .bottom
                            )
                        )
                    
                    // Reward
                    VStack(alignment: .center, spacing: 4) {
                        Image(systemName: "trophy.fill")
                            .font(.system(size: 16))
                            .foregroundColor(.yellow.opacity(0.9))
                        Text("REWARD")
                            .font(.system(size: 10, weight: .semibold, design: .rounded))
                            .foregroundColor(.white.opacity(0.5))
                            .tracking(0.8)
                        Text("\(reward)")
                            .font(.system(size: 24, weight: .black, design: .rounded))
                            .foregroundColor(.yellow)
                            .shadow(color: .yellow.opacity(0.3), radius: 3, x: 0, y: 2)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 4)
                }
                .padding(.horizontal, 20)
                .padding(.vertical, 14)
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
                .padding(.bottom, 20)
            }
            .safeAreaInset(edge: .top, spacing: 0) {
                Color.clear.frame(height: 0)
            }
            .safeAreaInset(edge: .bottom, spacing: 0) {
                Color.clear.frame(height: 0)
            }
            
            // Error banner
            if showError, let error = errorMessage {
                VStack {
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
                                showError = false
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
                .padding(.top, 60)
            }
            
            // Game Over Animation Overlay
            if showGameOverAnimation {
                // Blurred background
                Color.black.opacity(0.3)
                    .background(.ultraThinMaterial)
                    .ignoresSafeArea()
                    .onTapGesture {
                        dismissGameOver()
                    }
                
                VStack(spacing: 32) {
                    // Game Over Title
                    Text("GAME OVER")
                        .font(.system(size: 36, weight: .black, design: .rounded))
                        .foregroundColor(.white)
                        .tracking(2)
                        .shadow(color: .black.opacity(0.3), radius: 10, x: 0, y: 0)
                    
                    // Score Card (scaled up version of bottom card)
                    HStack(spacing: 0) {
                        // Final Score
                        VStack(alignment: .center, spacing: 8) {
                            Image(systemName: "star.fill")
                                .font(.system(size: 28))
                                .foregroundColor(.purple.opacity(0.8))
                            Text("FINAL SCORE")
                                .font(.system(size: 13, weight: .semibold, design: .rounded))
                                .foregroundColor(.white.opacity(0.5))
                                .tracking(1)
                            Text("\(score)")
                                .font(.system(size: 36, weight: .black, design: .rounded))
                                .foregroundColor(.white)
                                .shadow(color: .purple.opacity(0.3), radius: 5, x: 0, y: 3)
                                .lineLimit(1)
                                .minimumScaleFactor(0.5)
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 8)
                        
                        Divider()
                            .frame(width: 2, height: 85)
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
                                .font(.system(size: 28))
                                .foregroundColor(.yellow.opacity(0.9))
                            Text("REWARD")
                                .font(.system(size: 13, weight: .semibold, design: .rounded))
                                .foregroundColor(.white.opacity(0.5))
                                .tracking(1)
                            Text("\(reward)")
                                .font(.system(size: 36, weight: .black, design: .rounded))
                                .foregroundColor(.yellow)
                                .shadow(color: .yellow.opacity(0.3), radius: 5, x: 0, y: 3)
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 8)
                    }
                    .padding(.horizontal, 32)
                    .padding(.vertical, 28)
                    .background(
                        RoundedRectangle(cornerRadius: 24)
                            .fill(
                                LinearGradient(
                                    colors: [Color.black.opacity(0.5), Color.black.opacity(0.4)],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                )
                            )
                            .overlay(
                                RoundedRectangle(cornerRadius: 24)
                                    .stroke(
                                        LinearGradient(
                                            colors: [.white.opacity(0.3), .white.opacity(0.1)],
                                            startPoint: .topLeading,
                                            endPoint: .bottomTrailing
                                        ),
                                        lineWidth: 1.5
                                    )
                            )
                            .shadow(color: .black.opacity(0.4), radius: 20, x: 0, y: 10)
                    )
                    .padding(.horizontal, 32)
                    
                    // Buttons
                    HStack(spacing: 12) {
                        // Home Button
                        Button(action: {
                            dismiss()
                        }) {
                            HStack(spacing: 6) {
                                Image(systemName: "house.fill")
                                    .font(.system(size: 16))
                                Text("Home")
                                    .font(.system(size: 18, weight: .bold))
                            }
                            .foregroundColor(.white)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 16)
                            .background(
                                LinearGradient(
                                    colors: [Color.white.opacity(0.25), Color.white.opacity(0.15)],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                )
                            )
                            .cornerRadius(16)
                            .overlay(
                                RoundedRectangle(cornerRadius: 16)
                                    .stroke(Color.white.opacity(0.2), lineWidth: 1)
                            )
                        }
                        
                        // Close Button
                        Button(action: {
                            dismissGameOver()
                        }) {
                            Text("Close")
                                .font(.system(size: 18, weight: .bold))
                                .foregroundColor(.white)
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 16)
                                .background(
                                    LinearGradient(
                                        colors: [Color.white.opacity(0.25), Color.white.opacity(0.15)],
                                        startPoint: .topLeading,
                                        endPoint: .bottomTrailing
                                    )
                                )
                                .cornerRadius(16)
                                .overlay(
                                    RoundedRectangle(cornerRadius: 16)
                                        .stroke(Color.white.opacity(0.2), lineWidth: 1)
                                )
                        }
                    }
                    .padding(.horizontal, 32)
                }
                .opacity(gameOverOpacity)
            }
        }
        .navigationBarHidden(true)
        .onAppear {
            print("🎮 GameView appeared for token: \(gameTokenId), isNewGame: \(isNewGame)")
            
            // Stop leaderboard polling while in game view
            dojoManager.stopLeaderboardPolling()
            
            // Start continuous glow pulsation
            startGlowAnimation()
            
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
            // Resume leaderboard polling when returning to main view
            dojoManager.resumeLeaderboardPolling()
            
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
        withAnimation(.spring()) {
            currentNumber = model.number
        }
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
        
        // Clear optimistic values now that real data has arrived
        // Remove optimistic values for slots that now have real values
        for slotNum in optimisticSlotValues.keys {
            if setSlots.contains(slotNum) {
                withAnimation(.spring()) {
                    optimisticSlotValues.removeValue(forKey: slotNum)
                }
            }
        }
        
        // Clear loading state if we were setting a slot
        if isSettingSlot {
            isSettingSlot = false
            selectedSlot = nil
        }
        
        print("   ✅ UI state updated successfully")
        print("   🎰 Slot values loaded: \(slotValues.enumerated().filter { $0.element > 0 }.map { "Slot \($0.offset + 1)=\($0.element)" })")
        
        // Check if game is already over from blockchain or calculate if over
        checkForGameOver()
    }
    
    // Check if the current number can be placed in any available slot
    private func checkForGameOver() {
        // If game is already marked as over from blockchain, show modal
        if isGameOver && currentNumber > 0 && !showGameOverAnimation {
            print("🎮❌ Game is marked as OVER from blockchain")
            showGameOverModal()
            return
        }
        
        // Skip further checks if already over or no current number
        guard !isGameOver, currentNumber > 0, !setSlots.isEmpty else { return }
        
        // Get all set slot values sorted by slot number
        var sortedSetSlots: [(slot: Int, value: UInt16)] = []
        for slotNum in setSlots.sorted() {
            let index = slotNum - 1
            if index >= 0 && index < slotValues.count {
                sortedSetSlots.append((slot: slotNum, value: slotValues[index]))
            }
        }
        
        // Check if current number can fit between any two consecutive values
        var canPlaceNumber = false
        
        // Check if number is less than the first set slot (can place before)
        if let firstSlot = sortedSetSlots.first, currentNumber < firstSlot.value {
            canPlaceNumber = true
        }
        
        // Check if number is greater than the last set slot (can place after)
        if let lastSlot = sortedSetSlots.last, currentNumber > lastSlot.value {
            canPlaceNumber = true
        }
        
        // Check if number fits between any two consecutive set slots
        for i in 0..<(sortedSetSlots.count - 1) {
            let current = sortedSetSlots[i].value
            let next = sortedSetSlots[i + 1].value
            
            if currentNumber > current && currentNumber < next {
                canPlaceNumber = true
                break
            }
        }
        
        // If all slots are filled, game is definitely over
        if setSlots.count >= Int(slotCount) {
            canPlaceNumber = false
        }
        
        // Trigger game over animation if no valid placement exists
        if !canPlaceNumber {
            print("🎮❌ GAME OVER! No valid placement for \(currentNumber)")
            print("   Set slots: \(sortedSetSlots.map { "Slot \($0.slot)=\($0.value)" })")
            showGameOverModal()
        }
    }
    
    private func showGameOverModal() {
        showGameOverAnimation = true
        
        // Simple fade in
        withAnimation(.easeInOut(duration: 0.3)) {
            gameOverOpacity = 1.0
        }
    }
    
    private func dismissGameOver() {
        // Simple fade out
        withAnimation(.easeOut(duration: 0.2)) {
            gameOverOpacity = 0.0
        }
        
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
            showGameOverAnimation = false
        }
    }
    
    private func startGlowAnimation() {
        withAnimation(
            Animation.easeInOut(duration: 2.0)
                .repeatForever(autoreverses: true)
        ) {
            glowPulse = 1.5
        }
    }
    
    private func setSlot(_ slotNumber: Int) {
        print("🎯 Attempting to set slot #\(slotNumber)")
        print("   isSettingSlot: \(isSettingSlot)")
        print("   setSlots contains \(slotNumber): \(setSlots.contains(slotNumber))")
        print("   setSlots: \(setSlots)")
        print("   isGameOver: \(isGameOver)")
        print("   currentNumber: \(currentNumber)")
        
        guard !isSettingSlot else {
            print("❌ Cannot set slot - already setting a slot")
            return
        }
        guard !setSlots.contains(slotNumber) else {
            print("❌ Cannot set slot - slot \(slotNumber) already set")
            return
        }
        guard !isGameOver else {
            print("❌ Cannot set slot - game is over")
            return
        }
        guard currentNumber > 0 else {
            print("❌ Cannot set slot - no current number")
            return
        }
        
        isSettingSlot = true
        selectedSlot = slotNumber
        
        print("✅ Setting slot #\(slotNumber) for game \(gameTokenId) with number \(currentNumber)")
        
        // Start roulette spinning animation
        startRouletteAnimation()
        
        // Optimistically set the slot value
        optimisticSlotValues[slotNumber] = currentNumber
        
        Task {
            do {
                try await dojoManager.setGameSlot(
                    gameId: gameTokenId,
                    slot: UInt8(slotNumber),
                    sessionManager: sessionManager
                )
                
                // Game state will update automatically via subscription
                // Stop spinning after a short delay to show the result
                await MainActor.run {
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                        withAnimation(.spring()) {
                            self.isSpinning = false
                        }
                    }
                }
            } catch {
                // Show error banner
                await MainActor.run {
                    // Stop spinning
                    withAnimation(.spring()) {
                        isSpinning = false
                    }
                    
                    // Remove optimistic value
                    optimisticSlotValues.removeValue(forKey: slotNumber)
                    
                    errorMessage = error.localizedDescription
                    withAnimation(.spring()) {
                        showError = true
                    }
                    
                    // Auto-dismiss after 5 seconds
                    DispatchQueue.main.asyncAfter(deadline: .now() + 5) {
                        withAnimation(.spring()) {
                            showError = false
                        }
                    }
                    
                    // Reset setting state
                    isSettingSlot = false
                    selectedSlot = nil
                }
            }
        }
    }
    
    // Roulette animation - rapidly cycles through random numbers
    private func startRouletteAnimation() {
        isSpinning = true
        spinningNumber = currentNumber
        
        var count = 0
        Timer.scheduledTimer(withTimeInterval: 0.05, repeats: true) { timer in
            count += 1
            
            if count > 20 {
                // Slow down and stop at current number
                timer.invalidate()
                self.spinningNumber = self.currentNumber
            } else {
                // Generate random number in slot range
                self.spinningNumber = UInt16.random(in: self.slotMin...self.slotMax)
            }
        }
    }
}

// Slot Button Component
struct SlotButton: View {
    let slotNumber: Int
    let slotValue: UInt16
    let isOptimistic: Bool
    let isDisabled: Bool
    let action: () -> Void
    
    @State private var pulseAnimation = false
    
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
        Button(action: {
            print("🔘 Slot #\(slotNumber) clicked - isSet: \(isSet), isDisabled: \(isDisabled), slotValue: \(slotValue)")
            action()
        }) {
            HStack(spacing: 8) {
                Text("\(slotNumber).")
                    .font(.system(size: 15, weight: .semibold, design: .rounded))
                    .foregroundColor(.white.opacity(0.5))
                    .frame(width: 28, alignment: .trailing)
                
                Text(displayText)
                    .font(.system(size: 17, weight: .bold, design: .rounded))
                    .foregroundColor(isSet ? .white : .white.opacity(0.4))
                    .frame(width: 58)
                    .lineLimit(1)
                    .minimumScaleFactor(0.7)
                    .scaleEffect(isOptimistic && pulseAnimation ? 1.1 : 1.0)
                    .animation(.easeInOut(duration: 0.6).repeatForever(autoreverses: true), value: pulseAnimation)
            }
            .frame(maxWidth: .infinity)
            .frame(height: 38)
            .background(
                Group {
                    if isSet {
                        LinearGradient(
                            colors: isOptimistic 
                                ? [Color.yellow.opacity(0.8), Color.orange.opacity(0.6)]
                                : [Color.green.opacity(0.7), Color.green.opacity(0.5)],
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
            .cornerRadius(12)
            .overlay(
                RoundedRectangle(cornerRadius: 12)
                    .stroke(
                        LinearGradient(
                            colors: isSet
                                ? (isOptimistic 
                                    ? [Color.yellow.opacity(0.8), Color.orange.opacity(0.4)]
                                    : [Color.green.opacity(0.6), Color.green.opacity(0.3)])
                                : [Color.white.opacity(0.3), Color.white.opacity(0.1)],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        ),
                        lineWidth: 1.5
                    )
            )
            .shadow(
                color: isSet 
                    ? (isOptimistic ? Color.orange.opacity(0.5) : Color.green.opacity(0.3))
                    : Color.black.opacity(0.2), 
                radius: isSet ? (isOptimistic ? 8 : 5) : 2, 
                x: 0, 
                y: 1.5
            )
        }
        .disabled(isDisabled || (isSet && !isOptimistic))
        .buttonStyle(ScaleButtonStyle())
        .onChange(of: isOptimistic) { newValue in
            if newValue {
                pulseAnimation = true
            } else {
                pulseAnimation = false
            }
        }
        .onAppear {
            if isOptimistic {
                pulseAnimation = true
            }
        }
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

