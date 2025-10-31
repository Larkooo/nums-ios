import SwiftUI

struct HowToPlaySheet: View {
    @Environment(\.dismiss) var dismiss
    @State private var demoSlots: [Int?] = Array(repeating: nil, count: 10)
    @State private var currentNumber: Int = 0
    @State private var demoScore: Int = 0
    @State private var showSuccess = false
    @State private var showError = false
    
    var body: some View {
        ZStack {
            // Purple gradient background (matching MainView)
            LinearGradient(
                colors: [
                    Color(red: 0.4, green: 0.2, blue: 0.8),
                    Color(red: 0.3, green: 0.1, blue: 0.6)
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            .ignoresSafeArea()
            
            ScrollView {
                VStack(alignment: .leading, spacing: 32) {
                    // Header with close button
                    HStack {
                        Text("HOW TO PLAY")
                            .font(.system(size: 36, weight: .black, design: .rounded))
                            .foregroundColor(Color(red: 0.7, green: 0.6, blue: 1.0))
                    }
                    
                    // Welcome text
                    Text("Welcome to Nums, a fully onchain game build by Cartridge using the Dojo Framework.")
                        .font(.system(size: 18))
                        .foregroundColor(.white)
                        .lineSpacing(8)
                    
                    // Goal description
                    Text("The goal is simple: place randomly generated numbers (1 - 1000) in ascending order. Players compete and earn $NUMS tokens by placing as many numbers as possilbe with the game ending when the timer reaches zero.")
                        .font(.system(size: 18))
                        .foregroundColor(.white)
                        .lineSpacing(8)
                    
                    // Motivational text
                    Text("The better you do the more you earn!")
                        .font(.system(size: 18, weight: .bold))
                        .foregroundColor(.white)
                        .lineSpacing(8)
                    
                    // Demo Section
                    VStack {
                        Text("TRY IT OUT")
                            .font(.system(size: 24, weight: .black, design: .rounded))
                            .foregroundColor(Color(red: 0.7, green: 0.6, blue: 1.0))
                        // Current Number Display
                        VStack {
                            Text("CURRENT NUMBER")
                                .font(.system(size: 12, weight: .bold))
                                .foregroundColor(.white.opacity(0.6))
                            
                            ZStack {
                                Circle()
                                    .fill(
                                        RadialGradient(
                                            colors: [
                                                Color.cyan.opacity(0.3),
                                                Color.cyan.opacity(0.1),
                                                Color.clear
                                            ],
                                            center: .center,
                                            startRadius: 0,
                                            endRadius: 40
                                        )
                                    )
                                    .frame(width: 80, height: 80)
                                
                                Text("\(currentNumber)")
                                    .font(.system(size: 36, weight: .bold, design: .rounded))
                                    .foregroundColor(.white)
                            }
                        }.padding(.top, 8)
                        
                        // Demo Slots Grid (2 columns, 5 rows - vertical layout)
                        VStack(spacing: 8) {
                            ForEach(0..<5, id: \.self) { row in
                                HStack(spacing: 8) {
                                    // Left column: 1-5
                                    DemoSlotButton(
                                        slotNumber: row + 1,
                                        value: demoSlots[row],
                                        currentNumber: currentNumber,
                                        canPlace: canPlaceAt(index: row)
                                    ) {
                                        placeNumberAt(index: row)
                                    }
                                    
                                    // Right column: 6-10
                                    DemoSlotButton(
                                        slotNumber: row + 6,
                                        value: demoSlots[row + 5],
                                        currentNumber: currentNumber,
                                        canPlace: canPlaceAt(index: row + 5)
                                    ) {
                                        placeNumberAt(index: row + 5)
                                    }
                                }
                            }
                        }
                        .padding(.bottom, 20)
                        
                        // Score and Reset
                        HStack {
                            VStack(alignment: .leading, spacing: 4) {
                                Text("SCORE")
                                    .font(.system(size: 12, weight: .bold))
                                    .foregroundColor(.white.opacity(0.6))
                                Text("\(demoScore)")
                                    .font(.system(size: 24, weight: .bold, design: .rounded))
                                    .foregroundColor(.white)
                            }
                            
                            Spacer()
                            
                            Button(action: resetDemo) {
                                HStack(spacing: 6) {
                                    Image(systemName: "arrow.clockwise")
                                    Text("Reset")
                                        .font(.system(size: 16, weight: .bold))
                                }
                                .foregroundColor(.white)
                                .padding(.horizontal, 20)
                                .padding(.vertical, 12)
                                .background(Color.white.opacity(0.2))
                                .cornerRadius(12)
                            }
                        }
                    }
                    .padding(20)
                    .background(Color.white.opacity(0.05))
                    .cornerRadius(20)
                }
                .padding(.vertical, 32)
                .padding(.horizontal, 20)
            }
        }
        .onAppear {
            generateNewNumber()
        }
        .overlay(
            // Success/Error feedback
            VStack {
                if showSuccess {
                    Text("✓ Nice!")
                        .font(.system(size: 18, weight: .bold))
                        .foregroundColor(.white)
                        .padding(.horizontal, 24)
                        .padding(.vertical, 12)
                        .background(Color.green.opacity(0.9))
                        .cornerRadius(12)
                        .transition(.move(edge: .top).combined(with: .opacity))
                } else if showError {
                    Text("✗ Must be in order!")
                        .font(.system(size: 18, weight: .bold))
                        .foregroundColor(.white)
                        .padding(.horizontal, 24)
                        .padding(.vertical, 12)
                        .background(Color.red.opacity(0.9))
                        .cornerRadius(12)
                        .transition(.move(edge: .top).combined(with: .opacity))
                }
            }
            .padding(.top, 60),
            alignment: .top
        )
    }
    
    // Check if number can be placed at index
    private func canPlaceAt(index: Int) -> Bool {
        // Can't place if slot is already filled
        if demoSlots[index] != nil {
            return false
        }
        
        // Find all filled slots before and after this index
        let beforeValues = demoSlots[0..<index].compactMap { $0 }
        let afterValues = demoSlots[(index+1)..<10].compactMap { $0 }
        
        // Check if current number fits between the values
        if let maxBefore = beforeValues.max() {
            if currentNumber <= maxBefore {
                return false
            }
        }
        
        if let minAfter = afterValues.min() {
            if currentNumber >= minAfter {
                return false
            }
        }
        
        return true
    }
    
    // Place number at index
    private func placeNumberAt(index: Int) {
        if canPlaceAt(index: index) {
            demoSlots[index] = currentNumber
            demoScore += 1
            
            // Show success feedback
            withAnimation(.spring()) {
                showSuccess = true
            }
            DispatchQueue.main.asyncAfter(deadline: .now() + 1) {
                withAnimation(.spring()) {
                    showSuccess = false
                }
            }
            
            // Generate new number after a short delay
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                generateNewNumber()
            }
        } else {
            // Show error feedback
            withAnimation(.spring()) {
                showError = true
            }
            DispatchQueue.main.asyncAfter(deadline: .now() + 1) {
                withAnimation(.spring()) {
                    showError = false
                }
            }
        }
    }
    
    // Generate a new random number
    private func generateNewNumber() {
        currentNumber = Int.random(in: 1...100)
    }
    
    // Reset the demo
    private func resetDemo() {
        withAnimation(.spring()) {
            demoSlots = Array(repeating: nil, count: 10)
            demoScore = 0
            showSuccess = false
            showError = false
        }
        generateNewNumber()
    }
}

// Demo Slot Button
struct DemoSlotButton: View {
    let slotNumber: Int
    let value: Int?
    let currentNumber: Int
    let canPlace: Bool
    let action: () -> Void
    
    var isSet: Bool {
        value != nil
    }
    
    var displayText: String {
        if let val = value {
            return "\(val)"
        }
        return "?"
    }
    
    var isGreyedOut: Bool {
        !isSet && !canPlace
    }
    
    var body: some View {
        Button(action: action) {
            HStack(spacing: 6) {
                Text("\(slotNumber).")
                    .font(.system(size: 13, weight: .semibold, design: .rounded))
                    .foregroundColor(isGreyedOut ? .white.opacity(0.25) : .white.opacity(0.5))
                    .frame(width: 20, alignment: .trailing)
                
                Text(displayText)
                    .font(.system(size: 16, weight: .bold, design: .rounded))
                    .foregroundColor(isSet ? .white : (isGreyedOut ? .white.opacity(0.2) : .white.opacity(0.4)))
                    .frame(width: 40)
                    .lineLimit(1)
                    .minimumScaleFactor(0.7)
            }
            .frame(maxWidth: .infinity)
            .frame(height: 44)
            .background(
                Group {
                    if isSet {
                        LinearGradient(
                            colors: [Color.green.opacity(0.7), Color.green.opacity(0.5)],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    } else if isGreyedOut {
                        LinearGradient(
                            colors: [Color.white.opacity(0.08), Color.white.opacity(0.05)],
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
                                ? [Color.green.opacity(0.6), Color.green.opacity(0.3)]
                                : (isGreyedOut 
                                    ? [Color.white.opacity(0.1), Color.white.opacity(0.05)]
                                    : [Color.white.opacity(0.3), Color.white.opacity(0.1)]),
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        ),
                        lineWidth: 1.5
                    )
            )
            .shadow(
                color: isSet ? Color.green.opacity(0.3) : (isGreyedOut ? Color.clear : Color.black.opacity(0.2)),
                radius: isSet ? 5 : 2,
                x: 0,
                y: 1.5
            )
        }
        .disabled(isGreyedOut || isSet)
    }
}

#Preview {
    HowToPlaySheet()
}



