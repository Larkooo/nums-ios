//
//  SessionInfoSheet.swift
//  nums
//
//  Created by Assistant on 2025-10-29.
//

import SwiftUI

// Session Info Sheet (Native Bottom Sheet)
struct SessionInfoSheet: View {
    @Environment(\.dismiss) var dismiss
    @ObservedObject var sessionManager: SessionManager
    @State private var isPoliciesExpanded = false
    @Binding var selectedDetent: PresentationDetent
    
    private var isFullyExpanded: Bool {
        selectedDetent == .large
    }
    
    private func truncateMiddle(_ text: String) -> String {
        guard text.count > 16 else { return text }
        let start = text.prefix(8)
        let end = text.suffix(8)
        return "\(start)...\(end)"
    }
    
    var body: some View {
        ZStack {
            // Background
            Color(red: 0.349, green: 0.122, blue: 1.0)
                .ignoresSafeArea()
            
            VStack(spacing: 0) {
                // Session Details Card
                VStack(spacing: 16) {
                    // Username
                    InfoRow(
                        icon: "person.circle.fill",
                        label: "Username",
                        value: sessionManager.sessionUsername ?? "Anonymous"
                    )
                    
                    Divider().background(Color.white.opacity(0.2))
                    
                    // Address
                    InfoRow(
                        icon: "number.circle.fill",
                        label: "Address",
                        value: sessionManager.sessionAddress ?? "N/A",
                        truncate: true
                    )
                    
                    Divider().background(Color.white.opacity(0.2))
                    
                    // Expires At
                    InfoRow(
                        icon: "clock.circle.fill",
                        label: "Expires",
                        value: sessionManager.sessionExpiresAt.map { 
                            Date(timeIntervalSince1970: TimeInterval($0)).formatted()
                        } ?? "N/A"
                    )
                    
                    Divider().background(Color.white.opacity(0.2))
                    
                    // App ID
                    if let appId = sessionManager.appId, !appId.isEmpty {
                        InfoRow(
                            icon: "app.badge.fill",
                            label: "App ID",
                            value: appId
                        )
                        Divider().background(Color.white.opacity(0.2))
                    }
                    
                    // Status
                    HStack {
                        Image(systemName: sessionManager.isExpired ? "exclamationmark.triangle.fill" : "checkmark.circle.fill")
                            .foregroundColor(sessionManager.isExpired ? .orange : .green)
                        Text("Status")
                            .foregroundColor(.white.opacity(0.7))
                        Spacer()
                        Text(sessionManager.isExpired ? "Expired" : "Active")
                            .foregroundColor(sessionManager.isExpired ? .orange : .green)
                            .fontWeight(.semibold)
                    }
                    .font(.system(size: 16))
                    
                    // Policies Section (Collapsible) - Only show when sheet is fully expanded
                    if isFullyExpanded {
                        Divider().background(Color.white.opacity(0.2))
                        
                        VStack(alignment: .leading, spacing: 12) {
                            // Header
                            Button(action: {
                                withAnimation(.spring(response: 0.3)) {
                                    isPoliciesExpanded.toggle()
                                }
                            }) {
                                HStack {
                                    Image(systemName: "shield.checkered")
                                        .foregroundColor(.white.opacity(0.7))
                                        .frame(width: 24)
                                    Text("Policies")
                                        .font(.system(size: 16))
                                        .foregroundColor(.white.opacity(0.7))
                                    Spacer()
                                    Image(systemName: isPoliciesExpanded ? "chevron.up" : "chevron.down")
                                        .foregroundColor(.white.opacity(0.5))
                                        .font(.system(size: 14))
                                }
                            }
                            
                            // Expanded Content
                            if isPoliciesExpanded {
                                VStack(alignment: .leading, spacing: 8) {
                                    ForEach(sessionManager.policies.filter { $0.enabled }) { policy in
                                        VStack(alignment: .leading, spacing: 4) {
                                            HStack {
                                                Circle()
                                                    .fill(Color.green)
                                                    .frame(width: 6, height: 6)
                                                Text(policy.entrypoint)
                                                    .font(.system(size: 14, weight: .medium))
                                                    .foregroundColor(.white)
                                            }
                                            
                                            Text(truncateMiddle(policy.contractAddress))
                                                .font(.system(size: 12, weight: .regular))
                                                .foregroundColor(.white.opacity(0.6))
                                                .padding(.leading, 14)
                                        }
                                        .padding(.vertical, 4)
                                    }
                                    
                                    if sessionManager.policies.filter({ $0.enabled }).isEmpty {
                                        Text("No policies configured")
                                            .font(.system(size: 14))
                                            .foregroundColor(.white.opacity(0.5))
                                            .padding(.leading, 14)
                                    }
                                }
                                .padding(.top, 4)
                                .padding(.leading, 12)
                            }
                        }
                    }
                }
                .padding(20)
                .background(Color.white.opacity(0.1))
                .cornerRadius(16)
                .padding(.horizontal, 20)
                
                Spacer()
                
                // Disconnect Button
                Button(action: {
                    sessionManager.reset()
                    dismiss()
                }) {
                    HStack {
                        Image(systemName: "arrow.right.square.fill")
                        Text("Disconnect")
                            .fontWeight(.semibold)
                    }
                    .font(.system(size: 18))
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 16)
                    .background(Color.red.opacity(0.8))
                    .cornerRadius(16)
                }
                .padding(.horizontal, 20)
                .padding(.bottom, 20)
            }
            .padding(.top, 60)
        }
        .onChange(of: selectedDetent) { newDetent in
            // Collapse policies when sheet is minimized
            if newDetent == .medium && isPoliciesExpanded {
                withAnimation(.spring(response: 0.3)) {
                    isPoliciesExpanded = false
                }
            }
        }
    }
}

// Helper view for info rows
struct InfoRow: View {
    let icon: String
    let label: String
    let value: String
    var truncate: Bool = false
    
    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: icon)
                .foregroundColor(.white.opacity(0.7))
                .frame(width: 24)
            
            VStack(alignment: .leading, spacing: 4) {
                Text(label)
                    .font(.system(size: 14))
                    .foregroundColor(.white.opacity(0.7))
                Text(truncate ? truncateMiddle(value) : value)
                    .font(.system(size: 16, weight: .medium))
                    .foregroundColor(.white)
            }
            
            Spacer()
        }
    }
    
    private func truncateMiddle(_ text: String) -> String {
        guard text.count > 16 else { return text }
        let start = text.prefix(8)
        let end = text.suffix(8)
        return "\(start)...\(end)"
    }
}

