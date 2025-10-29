import SwiftUI

@main
struct numsApp: App {
    @StateObject private var dojoManager = DojoManager()
    @StateObject private var sessionManager = SessionManager()
    
    var body: some Scene {
        WindowGroup {
            MainView()
                .environmentObject(dojoManager)
                .environmentObject(sessionManager)
        }
    }
}
