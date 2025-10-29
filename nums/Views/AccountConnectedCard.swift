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
                // Success Icon
                ZStack {
                    Circle()
                        .fill(Color.green)
                        .frame(width: 80, height: 80)
                    
                    Image(systemName: "checkmark")
                        .font(.system(size: 40, weight: .bold))
                        .foregroundColor(.white)
                }
                
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
                
                // Continue Button
                Button(action: {
                    isPresented = false
                }) {
                    Text("Continue")
                        .font(.system(size: 18, weight: .bold))
                        .foregroundColor(Color(red: 0.2, green: 0.15, blue: 0.4))
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 16)
                        .background(
                            LinearGradient(
                                colors: [Color.yellow, Color.orange],
                                startPoint: .top,
                                endPoint: .bottom
                            )
                        )
                        .cornerRadius(12)
                        .shadow(color: .black.opacity(0.3), radius: 10, x: 0, y: 5)
                }
                .padding(.horizontal, 24)
            }
            .padding(.vertical, 40)
            .background(
                Color(red: 0.349, green: 0.122, blue: 1.0)
            )
            .cornerRadius(24)
            .shadow(color: .black.opacity(0.5), radius: 20, x: 0, y: 10)
            .padding(.horizontal, 32)
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

