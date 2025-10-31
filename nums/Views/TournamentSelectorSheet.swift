//
//  TournamentSelectorSheet.swift
//  nums
//
//  Created by Assistant on 2025-10-29.
//

import SwiftUI

// Tournament Selector Sheet
struct TournamentSelectorSheet: View {
    @Environment(\.dismiss) var dismiss
    @ObservedObject var dojoManager: DojoManager
    
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
            
            VStack(spacing: 0) {
                // Custom Header (matching HowToPlaySheet and GameSelectionSheet)
                HStack(alignment: .top) {
                    VStack(alignment: .leading, spacing: 6) {
                        Text("SELECT TOURNAMENT")
                            .font(.system(size: 32, weight: .black, design: .rounded))
                            .foregroundColor(Color(red: 0.7, green: 0.6, blue: 1.0))
                        Text("Choose which tournament to compete in")
                            .font(.system(size: 16, weight: .medium))
                            .foregroundColor(.white.opacity(0.8))
                    }
                    
                    Spacer()
                    
                    Button(action: {
                        dismiss()
                    }) {
                        Image(systemName: "xmark.circle.fill")
                            .font(.system(size: 28))
                            .foregroundColor(.white.opacity(0.6))
                    }
                }
                .padding(.horizontal, 20)
                .padding(.top, 20)
                .padding(.bottom, 20)
                
                // Content
                if dojoManager.isLoadingTournaments {
                    Spacer()
                    ProgressView()
                        .progressViewStyle(CircularProgressViewStyle(tint: .white))
                        .scaleEffect(1.5)
                    Spacer()
                } else if dojoManager.tournaments.isEmpty {
                    Spacer()
                    VStack(spacing: 16) {
                        Image(systemName: "trophy.slash")
                            .font(.system(size: 60))
                            .foregroundColor(.white.opacity(0.5))
                        Text("No tournaments available")
                            .font(.system(size: 18, weight: .medium))
                            .foregroundColor(.white.opacity(0.7))
                        Text("Check back later for new competitions")
                            .font(.system(size: 14))
                            .foregroundColor(.white.opacity(0.5))
                    }
                    Spacer()
                } else {
                    ScrollView {
                        VStack(spacing: 12) {
                            ForEach(dojoManager.tournaments) { tournament in
                                TournamentCard(
                                    tournament: tournament,
                                    isSelected: tournament.id == dojoManager.selectedTournament?.id,
                                    onSelect: {
                                        Task {
                                            await dojoManager.selectTournament(tournament)
                                            dismiss()
                                        }
                                    }
                                )
                            }
                        }
                        .padding(.horizontal, 20)
                        .padding(.bottom, 20)
                    }
                }
            }
        }
    }
}

// Tournament Card
struct TournamentCard: View {
    let tournament: Tournament
    let isSelected: Bool
    let onSelect: () -> Void
    @State private var currentTime = Date()
    
    private var timeRemaining: String {
        let remaining = tournament.endDate.timeIntervalSince(currentTime)
        
        if remaining <= 0 {
            return "ENDED"
        }
        
        let hours = Int(remaining) / 3600
        let minutes = (Int(remaining) % 3600) / 60
        
        if hours >= 24 {
            let days = hours / 24
            return "\(days)d \(hours % 24)h"
        } else if hours > 0 {
            return "\(hours)h \(minutes)m"
        } else {
            return "\(minutes)m"
        }
    }
    
    private var duration: String {
        let totalSeconds = tournament.endDate.timeIntervalSince(tournament.startDate)
        let hours = Int(totalSeconds) / 3600
        
        if hours >= 24 {
            let days = hours / 24
            return "\(days) day\(days == 1 ? "" : "s")"
        } else {
            return "\(hours) hour\(hours == 1 ? "" : "s")"
        }
    }
    
    var body: some View {
        Button(action: onSelect) {
            VStack(spacing: 0) {
                HStack(spacing: 16) {
                    // Trophy icon
                    ZStack {
                        Circle()
                            .fill(isSelected ? Color.yellow : Color.white.opacity(0.15))
                            .frame(width: 60, height: 60)
                        
                        Image(systemName: "trophy.fill")
                            .foregroundColor(isSelected ? Color(red: 0.349, green: 0.122, blue: 1.0) : .white)
                            .font(.system(size: 24))
                    }
                    
                    VStack(alignment: .leading, spacing: 8) {
                        // Tournament name
                        HStack {
                            Text("TOURNAMENT #\(tournament.id)")
                                .font(.system(size: 20, weight: .black, design: .rounded))
                                .foregroundColor(.white)
                            
                            if isSelected {
                                Image(systemName: "checkmark.circle.fill")
                                    .foregroundColor(.yellow)
                                    .font(.system(size: 16))
                            }
                        }
                        
                        // Stats row
                        HStack(spacing: 16) {
                            HStack(spacing: 6) {
                                Image(systemName: "person.2.fill")
                                    .font(.system(size: 12))
                                    .foregroundColor(.cyan.opacity(0.8))
                                Text("\(tournament.entryCount)")
                                    .font(.system(size: 14, weight: .semibold))
                                    .foregroundColor(.white)
                            }
                            
                            HStack(spacing: 6) {
                                Image(systemName: "clock.fill")
                                    .font(.system(size: 12))
                                    .foregroundColor(.purple.opacity(0.8))
                                Text(duration)
                                    .font(.system(size: 14, weight: .semibold))
                                    .foregroundColor(.white)
                            }
                            
                            HStack(spacing: 6) {
                                Image(systemName: "bolt.fill")
                                    .font(.system(size: 12))
                                    .foregroundColor(.yellow.opacity(0.8))
                                Text("\(tournament.powers)")
                                    .font(.system(size: 14, weight: .semibold))
                                    .foregroundColor(.white)
                            }
                        }
                    }
                    
                    Spacer()
                }
                .padding(18)
                
                // Time remaining banner
                HStack {
                    Image(systemName: "timer")
                        .font(.system(size: 12))
                        .foregroundColor(.white.opacity(0.7))
                    Text("Ends in \(timeRemaining)")
                        .font(.system(size: 14, weight: .medium))
                        .foregroundColor(.white.opacity(0.9))
                    Spacer()
                }
                .padding(.horizontal, 18)
                .padding(.vertical, 10)
                .background(
                    Color.white.opacity(0.08)
                )
            }
            .background(
                RoundedRectangle(cornerRadius: 20)
                    .fill(
                        LinearGradient(
                            colors: isSelected 
                                ? [Color.white.opacity(0.2), Color.white.opacity(0.15)]
                                : [Color.white.opacity(0.12), Color.white.opacity(0.08)],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .overlay(
                        RoundedRectangle(cornerRadius: 20)
                            .stroke(
                                isSelected 
                                    ? LinearGradient(
                                        colors: [Color.yellow, Color.orange],
                                        startPoint: .topLeading,
                                        endPoint: .bottomTrailing
                                    )
                                    : LinearGradient(
                                        colors: [Color.white.opacity(0.2), Color.white.opacity(0.1)],
                                        startPoint: .topLeading,
                                        endPoint: .bottomTrailing
                                    ),
                                lineWidth: isSelected ? 2.5 : 1
                            )
                    )
                    .shadow(
                        color: isSelected ? Color.yellow.opacity(0.3) : Color.black.opacity(0.2),
                        radius: isSelected ? 8 : 4,
                        x: 0,
                        y: 2
                    )
            )
        }
        .onAppear {
            // Update timer
            Timer.scheduledTimer(withTimeInterval: 60.0, repeats: true) { _ in
                currentTime = Date()
            }
        }
    }
}



