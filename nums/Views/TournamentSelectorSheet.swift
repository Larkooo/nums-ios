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
        NavigationView {
            ZStack {
                // Background
                Color(red: 0.349, green: 0.122, blue: 1.0)
                    .ignoresSafeArea()
                
                if dojoManager.isLoadingTournaments {
                    ProgressView()
                        .progressViewStyle(CircularProgressViewStyle(tint: .white))
                } else if dojoManager.tournaments.isEmpty {
                    VStack(spacing: 16) {
                        Image(systemName: "trophy.slash")
                            .font(.system(size: 60))
                            .foregroundColor(.white.opacity(0.5))
                        Text("No tournaments available")
                            .foregroundColor(.white.opacity(0.7))
                    }
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
                        .padding(20)
                    }
                }
            }
            .navigationTitle("Select Tournament")
            .navigationBarTitleDisplayMode(.inline)
            // .toolbar {
            //     ToolbarItem(placement: .navigationBarTrailing) {
            //         Button(action: {
            //             dismiss()
            //         }) {
            //             Image(systemName: "xmark.circle.fill")
            //                 .foregroundColor(.white.opacity(0.6))
            //         }
            //     }
            // }
            // .toolbarBackground(Color(red: 0.349, green: 0.122, blue: 1.0), for: .navigationBar)
            // .toolbarBackground(.visible, for: .navigationBar)
            // .toolbarColorScheme(.dark, for: .navigationBar)
        }
    }
}

// Tournament Card
struct TournamentCard: View {
    let tournament: Tournament
    let isSelected: Bool
    let onSelect: () -> Void
    
    var body: some View {
        Button(action: onSelect) {
            HStack(spacing: 16) {
                // Trophy icon
                ZStack {
                    Circle()
                        .fill(isSelected ? Color.yellow : Color.white.opacity(0.1))
                        .frame(width: 50, height: 50)
                    
                    Image(systemName: "trophy.fill")
                        .foregroundColor(isSelected ? Color(red: 0.349, green: 0.122, blue: 1.0) : .white)
                        .font(.title3)
                }
                
                VStack(alignment: .leading, spacing: 4) {
                    Text("Tournament #\(tournament.id)")
                        .font(.system(size: 18, weight: .bold, design: .rounded))
                        .foregroundColor(.white)
                    
                    HStack(spacing: 12) {
                        HStack(spacing: 4) {
                            Image(systemName: "bolt.fill")
                                .font(.caption)
                            Text("Powers: \(tournament.powers)")
                                .font(.system(size: 14))
                        }
                        
                        HStack(spacing: 4) {
                            Image(systemName: "person.3.fill")
                                .font(.caption)
                            Text("\(tournament.entryCount) entries")
                                .font(.system(size: 14))
                        }
                    }
                    .foregroundColor(.white.opacity(0.7))
                }
                
                Spacer()
            }
            .padding(16)
            .background(
                RoundedRectangle(cornerRadius: 16)
                    .fill(isSelected ? Color.white.opacity(0.15) : Color.white.opacity(0.08))
                    .overlay(
                        RoundedRectangle(cornerRadius: 16)
                            .stroke(isSelected ? Color.yellow : Color.clear, lineWidth: 2)
                    )
            )
        }
    }
}



