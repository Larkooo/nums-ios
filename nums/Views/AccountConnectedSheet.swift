//
//  AccountConnectedSheet.swift
//  nums
//
//  Created by Assistant on 2025-10-29.
//

import SwiftUI

// Account Connected Sheet (Native Bottom Sheet)
struct AccountConnectedSheet: View {
    @Environment(\.dismiss) var dismiss
    @ObservedObject var sessionManager: SessionManager
    
    var body: some View {
        ZStack {
            // Background
            Color(red: 0.349, green: 0.122, blue: 1.0)
                .ignoresSafeArea()
            
            VStack(spacing: 24) {
                // Controller Icon
                Image("controller-icon")
                    .resizable()
                    .renderingMode(.template)
                    .aspectRatio(contentMode: .fit)
                    .frame(width: 70, height: 70)
                    .foregroundColor(.white)
                    .padding(.top, 60)
                
                // Title
                Text("Account Connected!")
                    .font(.system(size: 28, weight: .bold))
                    .foregroundColor(.white)
                
                // Account Details Card
                VStack(spacing: 16) {
                    // Username
                    HStack {
                        Text("Username:")
                            .font(.system(size: 16))
                            .foregroundColor(.white.opacity(0.7))
                        Spacer()
                        Text(sessionManager.sessionUsername ?? "Anonymous")
                            .font(.system(size: 16, weight: .semibold))
                            .foregroundColor(.white)
                    }
                    
                    Divider().background(Color.white.opacity(0.2))
                    
                    // Public Key
                    HStack(alignment: .top) {
                        Text("Public Key:")
                            .font(.system(size: 16))
                            .foregroundColor(.white.opacity(0.7))
                        Spacer()
                        Text(truncateAddress(sessionManager.sessionAddress ?? "N/A"))
                            .font(.system(size: 16, weight: .semibold))
                            .foregroundColor(.white)
                            .multilineTextAlignment(.trailing)
                    }
                    
                    Divider().background(Color.white.opacity(0.2))
                    
                    // Expires At
                    HStack {
                        Text("Expires:")
                            .font(.system(size: 16))
                            .foregroundColor(.white.opacity(0.7))
                        Spacer()
                        Text(sessionManager.sessionExpiresAt.map {
                            Date(timeIntervalSince1970: TimeInterval($0)).formatted(date: .abbreviated, time: .shortened)
                        } ?? "N/A")
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundColor(.white)
                        .multilineTextAlignment(.trailing)
                    }
                }
                .padding(20)
                .background(Color.white.opacity(0.1))
                .cornerRadius(16)
                
                Spacer()
                
                // Continue Button styled like top bar icons
                Button(action: {
                    dismiss()
                }) {
                    Text("Continue")
                        .font(.system(size: 18, weight: .bold))
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 16)
                        .background(Color.white.opacity(0.1))
                        .cornerRadius(12)
                }
                .padding(.bottom, 20)
            }
            .padding(.horizontal, 24)
        }
    }
    
    private func truncateAddress(_ address: String) -> String {
        guard address.count > 16 else { return address }
        let start = address.prefix(8)
        let end = address.suffix(8)
        return "\(start)...\(end)"
    }
}



