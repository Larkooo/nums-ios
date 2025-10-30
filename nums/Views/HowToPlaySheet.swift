import SwiftUI

struct HowToPlaySheet: View {
    @Environment(\.dismiss) var dismiss
    
    var body: some View {
        ZStack {
            // Purple background
            Color(red: 0.349, green: 0.122, blue: 1.0)
                .ignoresSafeArea()
            
            ScrollView {
                VStack(alignment: .leading, spacing: 32) {
                    // Header with close button
                    HStack {
                        Text("HOW TO PLAY")
                            .font(.system(size: 36, weight: .black, design: .rounded))
                            .foregroundColor(Color(red: 0.7, green: 0.6, blue: 1.0))
                        
                        Spacer()
                        
                        Button(action: {
                            dismiss()
                        }) {
                            Image(systemName: "xmark.circle.fill")
                                .font(.system(size: 28))
                                .foregroundColor(.white.opacity(0.6))
                        }
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
                }
                .padding(32)
            }
        }
    }
}

#Preview {
    HowToPlaySheet()
}


