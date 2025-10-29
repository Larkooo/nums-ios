import SwiftUI

// Game view (for when PLAY! button is pressed)
struct ContentView: View {
    @EnvironmentObject var dojoManager: DojoManager
    @EnvironmentObject var sessionManager: SessionManager
    @Environment(\.dismiss) var dismiss
    
    var body: some View {
        ZStack {
            Color(red: 0.349, green: 0.122, blue: 1.0)
                .ignoresSafeArea()
            
            VStack {
                Text("Game Screen")
                    .font(.largeTitle)
                    .foregroundColor(.white)
                
                Text("Coming Soon...")
                    .foregroundColor(.white.opacity(0.7))
                
                Button("Back to Leaderboard") {
                    dismiss()
                }
                .foregroundColor(.white)
                .padding()
                .background(Color.white.opacity(0.2))
                .cornerRadius(12)
            }
        }
    }
}

#Preview {
    ContentView()
        .environmentObject(DojoManager())
        .environmentObject(SessionManager())
}
