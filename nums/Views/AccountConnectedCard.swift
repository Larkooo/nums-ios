import SwiftUI

struct AccountConnectedCard: View {
    @EnvironmentObject var sessionManager: SessionManager
    @Binding var isPresented: Bool
    
    var body: some View {
        ZStack {
            // Semi-transparent background
            Color.black.opacity(0.3)
                .ignoresSafeArea()
                .onTapGesture {
                    isPresented = false
                }
            
            // Success Card
            VStack(spacing: 20) {
                // Controller Icon with extra top padding
                Image(systemName: "gamecontroller.fill")
                    .font(.system(size: 60))
                    .foregroundColor(.white)
                    .padding(.top, 20)
                
                // Title
                Text("Account Connected!")
                    .font(.system(size: 24, weight: .bold))
                    .foregroundColor(.white)
                
                // Username
                if let username = sessionManager.sessionUsername {
                    Text(username)
                        .font(.system(size: 20, weight: .semibold))
                        .foregroundColor(.yellow)
                }
                
                // Account Details
                VStack(spacing: 12) {
                    // Public Key
                    if !sessionManager.publicKey.isEmpty {
                        VStack(alignment: .leading, spacing: 4) {
                            Text("Public Key")
                                .font(.caption)
                                .foregroundColor(.white.opacity(0.7))
                            Text(sessionManager.publicKey.prefix(20) + "..." + sessionManager.publicKey.suffix(6))
                                .font(.system(size: 14, weight: .medium, design: .monospaced))
                                .foregroundColor(.white)
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(.horizontal, 20)
                        .padding(.vertical, 12)
                        .background(Color.white.opacity(0.1))
                        .cornerRadius(10)
                    }
                    
                    // Session Info
                    if let expiresAt = sessionManager.sessionExpiresAt {
                        VStack(alignment: .leading, spacing: 4) {
                            Text("Session Expires")
                                .font(.caption)
                                .foregroundColor(.white.opacity(0.7))
                            Text(formatExpirationDate(expiresAt))
                                .font(.system(size: 14, weight: .medium))
                                .foregroundColor(.white)
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(.horizontal, 20)
                        .padding(.vertical, 12)
                        .background(Color.white.opacity(0.1))
                        .cornerRadius(10)
                    }
                }
                .padding(.horizontal, 24)
                
                // Continue Button styled like top bar icons
                Button(action: {
                    isPresented = false
                }) {
                    Text("Continue")
                        .font(.system(size: 18, weight: .bold))
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 16)
                        .background(Color.white.opacity(0.1))
                        .cornerRadius(12)
                }
                .padding(.horizontal, 24)
            }
            .padding(.top, 60)
            .padding(.bottom, 40)
            .padding(.horizontal, 24)
            .background(
                Color(red: 0.349, green: 0.122, blue: 1.0)
            )
            .cornerRadius(24)
            .shadow(color: .black.opacity(0.5), radius: 20, x: 0, y: 10)
            .padding(.horizontal, 32)
            .padding(.top, 80)
        }
        .transition(.opacity.combined(with: .scale))
        .animation(.spring(response: 0.4, dampingFraction: 0.8), value: isPresented)
    }
    
    private func formatExpirationDate(_ timestamp: UInt64) -> String {
        let date = Date(timeIntervalSince1970: TimeInterval(timestamp))
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .short
        return formatter.string(from: date)
    }
}

#Preview {
    AccountConnectedCard(isPresented: .constant(true))
        .environmentObject(SessionManager())
}



