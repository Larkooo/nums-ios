//
//  TokenIcon.swift
//  nums
//
//  Dynamic token icon generator
//

import SwiftUI

struct TokenIcon: View {
    let tokenSymbol: String
    let address: String
    let size: CGFloat
    
    init(tokenSymbol: String, address: String, size: CGFloat = 20) {
        self.tokenSymbol = tokenSymbol
        self.address = address
        self.size = size
    }
    
    var body: some View {
        Group {
            switch tokenSymbol {
            case "STRK":
                Image("strk-icon")
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                    .frame(width: size, height: size)
            case "ETH":
                Image("eth-icon")
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                    .frame(width: size, height: size)
            default:
                // Generate dynamic icon based on address
                DynamicTokenIcon(address: address, size: size)
            }
        }
    }
}

struct DynamicTokenIcon: View {
    let address: String
    let size: CGFloat
    
    // Generate background color from address
    private var backgroundColor: Color {
        let cleaned = address.hasPrefix("0x") ? String(address.dropFirst(2)) : address
        let hash = cleaned.prefix(8).hashValue
        let hue = Double(abs(hash) % 360) / 360.0
        return Color(hue: hue, saturation: 0.5, brightness: 0.85)
    }
    
    // Generate 5x5 symmetric grid pattern (like GitHub identicons)
    private var gridPattern: [[Bool]] {
        let cleaned = address.hasPrefix("0x") ? String(address.dropFirst(2)) : address
        var pattern: [[Bool]] = Array(repeating: Array(repeating: false, count: 5), count: 5)
        
        // Generate pattern for left half + middle column (symmetric)
        for row in 0..<5 {
            for col in 0..<3 { // Only generate left half + middle
                let index = row * 3 + col
                if index < cleaned.count {
                    let char = String(cleaned[cleaned.index(cleaned.startIndex, offsetBy: index)])
                    if let value = Int(char, radix: 16) {
                        let filled = value % 2 == 0
                        pattern[row][col] = filled
                        // Mirror to right side
                        if col < 2 {
                            pattern[row][4 - col] = filled
                        }
                    }
                }
            }
        }
        
        return pattern
    }
    
    // Generate spot color (darker version of background)
    private var spotColor: Color {
        let cleaned = address.hasPrefix("0x") ? String(address.dropFirst(2)) : address
        let hash = cleaned.prefix(8).hashValue
        let hue = Double(abs(hash) % 360) / 360.0
        return Color(hue: hue, saturation: 0.7, brightness: 0.6)
    }
    
    var body: some View {
        ZStack {
            // Background
            Circle()
                .fill(backgroundColor)
            
            // Grid pattern
            GeometryReader { geometry in
                let cellSize = geometry.size.width / 5
                
                ForEach(0..<5) { row in
                    ForEach(0..<5) { col in
                        if gridPattern[row][col] {
                            RoundedRectangle(cornerRadius: cellSize * 0.15)
                                .fill(spotColor)
                                .frame(width: cellSize * 0.9, height: cellSize * 0.9)
                                .position(
                                    x: CGFloat(col) * cellSize + cellSize / 2,
                                    y: CGFloat(row) * cellSize + cellSize / 2
                                )
                        }
                    }
                }
            }
        }
        .frame(width: size, height: size)
        .clipShape(Circle())
    }
}

// Preview for testing
#Preview {
    ScrollView {
        VStack(spacing: 20) {
            Text("Known Tokens")
                .font(.headline)
                .foregroundColor(.white)
            
            HStack(spacing: 30) {
                VStack {
                    TokenIcon(tokenSymbol: "STRK", address: "0x04718f5a0fc34cc1af16a1cdee98ffb20c31f5cd61d6ab07201858f4287c938d", size: 50)
                    Text("STRK")
                        .font(.caption)
                        .foregroundColor(.white)
                }
                VStack {
                    TokenIcon(tokenSymbol: "ETH", address: "0x049d36570d4e46f48e99674bd3fcc84644ddd6b96f7c741b1562b82f9e004dc7", size: 50)
                    Text("ETH")
                        .font(.caption)
                        .foregroundColor(.white)
                }
            }
            
            Divider().background(Color.white)
            
            Text("Generated Identicons")
                .font(.headline)
                .foregroundColor(.white)
            
            Text("GitHub-style 5x5 symmetric patterns")
                .font(.caption)
                .foregroundColor(.white.opacity(0.7))
            
            // Large examples
            HStack(spacing: 20) {
                VStack(spacing: 8) {
                    TokenIcon(tokenSymbol: "TOKEN", address: "0x00112233445566778899aabbccddeeff", size: 50)
                    Text("Pattern A")
                        .font(.caption2)
                        .foregroundColor(.white.opacity(0.7))
                }
                VStack(spacing: 8) {
                    TokenIcon(tokenSymbol: "TOKEN", address: "0x11223344556677889900aabbccddeeff", size: 50)
                    Text("Pattern B")
                        .font(.caption2)
                        .foregroundColor(.white.opacity(0.7))
                }
                VStack(spacing: 8) {
                    TokenIcon(tokenSymbol: "TOKEN", address: "0x2233445566778899aabbccddeeff0011", size: 50)
                    Text("Pattern C")
                        .font(.caption2)
                        .foregroundColor(.white.opacity(0.7))
                }
            }
            
            // More variety
            HStack(spacing: 15) {
                TokenIcon(tokenSymbol: "TOKEN", address: "0xaabbccdd11223344", size: 45)
                TokenIcon(tokenSymbol: "TOKEN", address: "0xffeeddccbbaa9988", size: 45)
                TokenIcon(tokenSymbol: "TOKEN", address: "0x1122334455667788", size: 45)
                TokenIcon(tokenSymbol: "TOKEN", address: "0x9988776655443322", size: 45)
            }
            
            HStack(spacing: 15) {
                TokenIcon(tokenSymbol: "TOKEN", address: "0x123456789abcdef0", size: 45)
                TokenIcon(tokenSymbol: "TOKEN", address: "0xabcdef0123456789", size: 45)
                TokenIcon(tokenSymbol: "TOKEN", address: "0xdeadbeefcafebabe", size: 45)
                TokenIcon(tokenSymbol: "TOKEN", address: "0xcafebabadeadbeef", size: 45)
            }
            
            Divider().background(Color.white)
            
            Text("Small Size (20pt)")
                .font(.headline)
                .foregroundColor(.white)
            
            HStack(spacing: 15) {
                TokenIcon(tokenSymbol: "STRK", address: "0x04718f5a0fc34cc1af16a1cdee98ffb20c31f5cd61d6ab07201858f4287c938d", size: 20)
                TokenIcon(tokenSymbol: "ETH", address: "0x049d36570d4e46f48e99674bd3fcc84644ddd6b96f7c741b1562b82f9e004dc7", size: 20)
                TokenIcon(tokenSymbol: "TOKEN", address: "0x0034567890abcdef", size: 20)
                TokenIcon(tokenSymbol: "TOKEN", address: "0x11abcdef12345678", size: 20)
                TokenIcon(tokenSymbol: "TOKEN", address: "0x2234567890abcdef", size: 20)
                TokenIcon(tokenSymbol: "TOKEN", address: "0x3334567890abcdef", size: 20)
            }
            
            Divider().background(Color.white)
            
            Text("Tiny Size (14pt)")
                .font(.headline)
                .foregroundColor(.white)
            
            HStack(spacing: 12) {
                TokenIcon(tokenSymbol: "STRK", address: "0x04718f5a0fc34cc1af16a1cdee98ffb20c31f5cd61d6ab07201858f4287c938d", size: 14)
                TokenIcon(tokenSymbol: "ETH", address: "0x049d36570d4e46f48e99674bd3fcc84644ddd6b96f7c741b1562b82f9e004dc7", size: 14)
                TokenIcon(tokenSymbol: "TOKEN", address: "0x0034567890abcdef", size: 14)
                TokenIcon(tokenSymbol: "TOKEN", address: "0x11abcdef12345678", size: 14)
                TokenIcon(tokenSymbol: "TOKEN", address: "0x2234567890abcdef", size: 14)
                TokenIcon(tokenSymbol: "TOKEN", address: "0x3334567890abcdef", size: 14)
                TokenIcon(tokenSymbol: "TOKEN", address: "0xaabbccddeeff0011", size: 14)
                TokenIcon(tokenSymbol: "TOKEN", address: "0xffeeddccbbaa9988", size: 14)
            }
        }
        .padding()
    }
    .background(
        LinearGradient(
            colors: [
                Color(red: 0.4, green: 0.2, blue: 0.8),
                Color(red: 0.3, green: 0.1, blue: 0.6)
            ],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
    )
}

