//
//  Font+Custom.swift
//  nums
//
//  Created by Assistant on 2025-10-31.
//

import SwiftUI

extension Font {
    // Pixel font helpers
    static func pixel(size: CGFloat) -> Font {
        // Using the Pixel Game font from Cartridge NUMS
        // https://github.com/cartridge-gg/nums/blob/main/client/src/assets/fonts/Pixel-Game.otf
        // Family name is "Pixel Game" (with space)
        return .custom("Pixel Game", size: size)
    }
    
    // Common font sizes
    static var pixelTitle: Font {
        pixel(size: 28)
    }
    
    static var pixelHeadline: Font {
        pixel(size: 22)
    }
    
    static var pixelBody: Font {
        pixel(size: 16)
    }
    
    static var pixelCaption: Font {
        pixel(size: 13)
    }
    
    static var pixelSmall: Font {
        pixel(size: 11)
    }
    
    static var pixelNumber: Font {
        pixel(size: 32)
    }
}

// View modifier to apply pixel font globally
struct PixelFontModifier: ViewModifier {
    func body(content: Content) -> some View {
        content
            .font(.pixel(size: 16)) // Default body size
    }
}

extension View {
    func pixelFont() -> some View {
        modifier(PixelFontModifier())
    }
}

// Debug helper - print all available fonts
extension Font {
    static func printAvailableFonts() {
        for family in UIFont.familyNames.sorted() {
            let names = UIFont.fontNames(forFamilyName: family)
            print("Family: \(family) Font names: \(names)")
        }
    }
    
    static func isFontAvailable(_ fontName: String) -> Bool {
        // Check if it's a valid family name
        if UIFont.familyNames.contains(fontName) {
            return true
        }
        // Or if it's a valid font PostScript name
        return UIFont(name: fontName, size: 12) != nil
    }
}

