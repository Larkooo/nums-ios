import SwiftUI
import SafariServices

struct SetupView: View {
    @EnvironmentObject var sessionManager: SessionManager
    @Environment(\.dismiss) var dismiss
    
    var body: some View {
        NavigationView {
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
                    VStack(spacing: 24) {
                        // Header
                        VStack(spacing: 8) {
                            Image(systemName: "person.badge.key.fill")
                                .font(.system(size: 60))
                                .foregroundColor(.white)
                            
                            Text("Connect Account")
                                .font(.system(size: 28, weight: .bold))
                                .foregroundColor(.white)
                            
                            Text("Create a session to play and compete")
                                .font(.system(size: 16))
                                .foregroundColor(.white.opacity(0.7))
                                .multilineTextAlignment(.center)
                        }
                        .padding(.top, 40)
                        
                        // Generate Key Button
                        if sessionManager.privateKey.isEmpty {
                            Button(action: {
                                // Generate a random private key
                                sessionManager.privateKey = generateRandomPrivateKey()
                                sessionManager.updatePublicKey()
                            }) {
                                HStack {
                                    Image(systemName: "key.fill")
                                    Text("Generate Key")
                                    Spacer()
                                    Image(systemName: "arrow.right")
                                }
                                .font(.system(size: 18, weight: .semibold))
                                .foregroundColor(.white)
                                .padding()
                                .background(Color.white.opacity(0.2))
                                .cornerRadius(12)
                            }
                            .padding(.horizontal, 24)
                        } else {
                            // Register Session Button
                            Button(action: {
                                sessionManager.openSessionInWebView()
                            }) {
                                HStack {
                                    if sessionManager.isLoading {
                                        ProgressView()
                                            .progressViewStyle(CircularProgressViewStyle(tint: .white))
                                    } else {
                                        Image(systemName: "person.badge.plus")
                                        Text("Register Session")
                                    }
                                }
                                .font(.system(size: 18, weight: .bold))
                                .foregroundColor(Color(red: 0.2, green: 0.15, blue: 0.4))
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 18)
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
                            .disabled(sessionManager.isLoading)
                            .padding(.horizontal, 24)
                        }
                        
                        // Error Message
                        if let error = sessionManager.errorMessage {
                            Text(error)
                                .font(.caption)
                                .foregroundColor(.red)
                                .padding()
                                .background(Color.red.opacity(0.1))
                                .cornerRadius(8)
                                .padding(.horizontal, 24)
                        }
                        
                        Spacer()
                    }
                }
            }
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") {
                        dismiss()
                    }
                    .foregroundColor(.white)
                }
            }
        }
        .sheet(isPresented: $sessionManager.showWebView) {
            if let url = URL(string: sessionManager.generateSessionURL()) {
                SafariView(url: url)
            }
        }
        .onChange(of: sessionManager.sessionAccount != nil) { hasSession in
            if hasSession {
                // Session created successfully, dismiss
                dismiss()
            }
        }
    }
}

// Helper function to generate a random private key
func generateRandomPrivateKey() -> String {
    let bytes = (0..<32).map { _ in UInt8.random(in: 0...255) }
    return "0x" + bytes.map { String(format: "%02x", $0) }.joined()
}

#Preview {
    SetupView()
        .environmentObject(SessionManager())
}

