import SwiftUI
import CoreText
import UIKit

@main
struct numsApp: App {
    @StateObject private var dojoManager = DojoManager()
    @StateObject private var sessionManager = SessionManager()
    
    init() {
        // Debug: Check bundle for font file
        print("🎨 Checking for Pixel Game font...")
        
        if let fontPath = Bundle.main.path(forResource: "Pixel-Game", ofType: "otf") {
            print("✅ Font file found at: \(fontPath)")
            
            // Try to register it manually
            if let fontDataProvider = CGDataProvider(filename: fontPath),
               let font = CGFont(fontDataProvider) {
                var error: Unmanaged<CFError>?
                if CTFontManagerRegisterGraphicsFont(font, &error) {
                    print("✅ Font registered successfully")
                } else {
                    print("⚠️ Font already registered or registration failed")
                }
                
                // Print the actual PostScript name
                if let postScriptName = font.postScriptName {
                    print("📝 PostScript name: \(postScriptName)")
                }
            }
        } else {
            print("❌ Font file NOT found in bundle!")
        }
        
        // Check if font is available
        print("\n🔍 Checking font availability...")
        if Font.isFontAvailable("Pixel Game") {
            print("✅ 'Pixel Game' (family) is available!")
        } else if UIFont(name: "PixelGame", size: 12) != nil {
            print("✅ 'PixelGame' (PostScript) is available!")
        } else {
            print("❌ Font NOT found. Available font families:")
            for family in UIFont.familyNames.sorted().prefix(10) {
                print("  - \(family)")
            }
            print("  ... (showing first 10)")
        }
    }
    
    var body: some Scene {
        WindowGroup {
            MainView()
                .environmentObject(dojoManager)
                .environmentObject(sessionManager)
        }
    }
}
