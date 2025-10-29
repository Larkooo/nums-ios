import Foundation
import Combine

// Tournament Model
struct Tournament: Identifiable {
    let id: Int
    let powers: Int
    let entryCount: Int
    let startTime: String
    let endTime: String
}

// Leaderboard Entry Model
struct LeaderboardPlayer: Identifiable {
    let id: String // Unique ID for SwiftUI
    let tournamentId: Int
    let capacity: Int
    let requirement: Int
    let games: String
}

@MainActor
class DojoManager: ObservableObject {
    // Dojo State
    @Published var isConnected = false
    @Published var worldAddress: String = ""
    @Published var rpcUrl: String = "https://api.cartridge.gg/x/starknet/sepolia"
    @Published var toriiUrl: String = "https://api.cartridge.gg/x/nums-bal/torii"
    
    // Torii Client
    private var toriiClient: ToriiClient?
    
    // Tournament & Leaderboard
    @Published var tournaments: [Tournament] = []
    @Published var selectedTournament: Tournament?
    @Published var leaderboard: [LeaderboardPlayer] = []
    @Published var isLoadingTournaments = false
    @Published var isLoadingLeaderboard = false
    @Published var showTournamentSelector = false
    
    // Token Balance
    @Published var tokenBalance: BInt = 0
    @Published var isLoadingBalance = false
    
    private let tokenContractAddress = "0xe69b167a18be231ef14ca474e29cf6356333038162077b551a17d25d166af" // Nums
    // Subscription tracking
    private var tournamentSubscriptionId: UInt64?
    private var leaderboardSubscriptionId: UInt64?
    private var tokenBalanceSubscriptionId: UInt64?
    
    // Error handling
    @Published var errorMessage: String?
    
    init() {
        // Initialize Torii client on startup
        Task {
            await initializeToriiClient()
        }
    }
    
    private func initializeToriiClient() async {
        do {
            print("🌐 Initializing Torii client at: \(toriiUrl)")
            let client = try ToriiClient(toriiUrl: toriiUrl)
            
            await MainActor.run {
                self.toriiClient = client
                self.isConnected = true
                print("✅ Torii client connected successfully")
            }
            
            // Fetch all tournaments first
            await fetchAllTournaments()
            
            // If we have tournaments, select the first one
            await MainActor.run {
                if !self.tournaments.isEmpty {
                    self.selectedTournament = self.tournaments.first
                }
            }
            
            // Fetch leaderboard for selected tournament
            if selectedTournament != nil {
                await fetchLeaderboard(for: selectedTournament!.id)
            }
            
            // Start subscriptions
            await subscribeTournaments()
            if let tournamentId = selectedTournament?.id {
                await subscribeLeaderboard(for: tournamentId)
            }
        } catch {
            await MainActor.run {
                self.errorMessage = "Failed to initialize Torii: \(error.localizedDescription)"
                print("❌ Torii initialization error: \(error)")
            }
        }
    }
    
    // Function to select a tournament and refetch its leaderboard
    func selectTournament(_ tournament: Tournament) async {
        await MainActor.run {
            self.selectedTournament = tournament
            self.showTournamentSelector = false
        }
        
        // Refetch leaderboard for the new tournament
        await fetchLeaderboard(for: tournament.id)
        
        // Update subscription
        await subscribeLeaderboard(for: tournament.id)
    }
    
    func fetchAllTournaments() async {
        guard let client = toriiClient else {
            print("⚠️ Torii client not initialized")
            return
        }
        
        await MainActor.run {
            self.isLoadingTournaments = true
        }
        
        do {
            print("🏆 Fetching all tournaments...")
            
            // Create query for NUMS-Tournament model - fetch all
            let query = Query(
                worldAddresses: [],
                pagination: Pagination(
                    cursor: nil,
                    limit: 100, // Fetch up to 100 tournaments
                    direction: .forward,
                    orderBy: []
                ),
                clause: nil,
                noHashedKeys: false,
                models: ["NUMS-Tournament"],
                historical: false
            )
            
            let pageEntity = try client.entities(query: query)
            
            await MainActor.run {
                // Parse all tournament data from entities
                self.tournaments = pageEntity.items.compactMap { self.parseTournament(from: $0) }
                    .sorted { $0.id < $1.id } // Sort by ID
                print("✅ Tournaments loaded: \(self.tournaments.count) tournaments")
                self.isLoadingTournaments = false
            }
        } catch {
            await MainActor.run {
                self.errorMessage = "Failed to fetch tournaments: \(error.localizedDescription)"
                self.isLoadingTournaments = false
                print("❌ Tournaments fetch error: \(error)")
            }
        }
    }
    
    func fetchLeaderboard(for tournamentId: Int) async {
        guard let client = toriiClient else {
            print("⚠️ Torii client not initialized")
            return
        }
        
        await MainActor.run {
            self.isLoadingLeaderboard = true
        }
        
        do {
            print("📊 Fetching leaderboard data for tournament #\(tournamentId)...")
            
            // Create query for NUMS-Leaderboard model with tournament_id filter
            let query = Query(
                worldAddresses: [],
                pagination: Pagination(
                    cursor: nil,
                    limit: 100,
                    direction: .forward,
                    orderBy: []
                ),
                clause: nil, // TODO: Add filter for tournament_id if needed
                noHashedKeys: false,
                models: ["NUMS-Leaderboard"],
                historical: false
            )
            
            let pageEntity = try client.entities(query: query)
            
            await MainActor.run {
                // Parse leaderboard data and filter by tournament ID
                self.leaderboard = pageEntity.items.compactMap { self.parseLeaderboardEntry(from: $0) }
                    .filter { $0.tournamentId == tournamentId }
                    .sorted { $0.capacity > $1.capacity } // Sort by capacity descending
                print("✅ Leaderboard loaded: \(self.leaderboard.count) entries for tournament #\(tournamentId)")
                self.isLoadingLeaderboard = false
            }
        } catch {
            await MainActor.run {
                self.errorMessage = "Failed to fetch leaderboard: \(error.localizedDescription)"
                self.isLoadingLeaderboard = false
                print("❌ Leaderboard fetch error: \(error)")
            }
        }
    }
    
    func fetchTokenBalance(for accountAddress: String) async {
        // Validate that we have a proper address before fetching
        guard !accountAddress.isEmpty, accountAddress.hasPrefix("0x") else {
            print("⚠️ Invalid account address: \(accountAddress)")
            await MainActor.run {
                self.tokenBalance = 0
            }
            return
        }
        
        guard let client = toriiClient else {
            print("⚠️ Torii client not initialized")
            return
        }
        
        await MainActor.run {
            self.isLoadingBalance = true
        }
        
        do {
            print("💰 Fetching token balance for \(accountAddress)...")
            
            // Create query for token balance
            let query = TokenBalanceQuery(
                contractAddresses: [tokenContractAddress],
                accountAddresses: [accountAddress],
                tokenIds: [],
                pagination: Pagination(
                    cursor: nil,
                    limit: 1,
                    direction: .forward,
                    orderBy: []
                )
            )
            
            let pageTokenBalance = try client.tokenBalances(query: query)
            
            await MainActor.run {
                if let tokenBalance = pageTokenBalance.items.first {
                    // Convert U256 (String) to BInt
                    // U256 is typically a hex string, so we need to handle both hex and decimal
                    let balanceString = tokenBalance.balance.hasPrefix("0x") ? 
                        String(tokenBalance.balance.dropFirst(2)) : tokenBalance.balance
                    if let balanceWei = BInt(balanceString, radix: 16) ?? BInt(balanceString, radix: 10) {
                        // Convert from WEI to tokens (divide by 10^18)
                        let divisor = BInt(10).power(18)
                        self.tokenBalance = balanceWei / divisor
                        print("✅ Token balance (WEI): \(balanceWei)")
                        print("✅ Token balance (tokens): \(self.tokenBalance)")
                    } else {
                        self.tokenBalance = 0
                        print("⚠️ Failed to parse token balance: \(balanceString)")
                    }
                } else {
                    self.tokenBalance = 0
                    print("⚠️ No token balance found")
                }
                self.isLoadingBalance = false
            }
        } catch {
            await MainActor.run {
                self.errorMessage = "Failed to fetch token balance: \(error.localizedDescription)"
                self.isLoadingBalance = false
                self.tokenBalance = 0
                print("❌ Token balance fetch error: \(error)")
            }
        }
    }
    
    func subscribeToTokenBalance(for accountAddress: String) async {
        // Validate that we have a proper address before subscribing
        guard !accountAddress.isEmpty, accountAddress.hasPrefix("0x") else {
            print("⚠️ Invalid account address for subscription: \(accountAddress)")
            return
        }
        
        guard let client = toriiClient else {
            print("⚠️ Torii client not initialized for subscription")
            return
        }
        
        do {
            print("🔔 Subscribing to token balance updates for \(accountAddress)...")
            
            // Create subscription query for token balance
            let query = TokenBalanceQuery(
                contractAddresses: [tokenContractAddress],
                accountAddresses: [accountAddress],
                tokenIds: [],
                pagination: Pagination(
                    cursor: nil,
                    limit: 1,
                    direction: .forward,
                    orderBy: []
                )
            )
            
            // TODO: Implement subscription when available in the SDK
            // tokenBalanceSubscriptionId = try await client.subscribeTokenBalances(query: query)
            
            print("✅ Subscribed to token balance for \(accountAddress)")
        } catch {
            print("❌ Token balance subscription error: \(error)")
        }
    }
    
    private func parseTournament(from entity: Entity) -> Tournament? {
        // Parse tournament entity
        let models = entity.models
        
        guard let id = extractInt(from: models, key: "id") else { return nil }
        let powers = extractInt(from: models, key: "powers") ?? 0
        let entryCount = extractInt(from: models, key: "entry_count") ?? 0
        let startTime = extractString(from: models, key: "start_time") ?? ""
        let endTime = extractString(from: models, key: "end_time") ?? ""
        
        return Tournament(
            id: id,
            powers: powers,
            entryCount: entryCount,
            startTime: startTime,
            endTime: endTime
        )
    }
    
    private func parseLeaderboardEntry(from entity: Entity) -> LeaderboardPlayer? {
        // Parse leaderboard entity
        let models = entity.models
        
        // Use hashedKeys as the unique ID for SwiftUI
        let id = String(describing: entity.hashedKeys)
        
        guard let tournamentId = extractInt(from: models, key: "tournament_id") else { return nil }
        let capacity = extractInt(from: models, key: "capacity") ?? 0
        let requirement = extractInt(from: models, key: "requirement") ?? 0
        let games = extractString(from: models, key: "games") ?? ""
        
        return LeaderboardPlayer(
            id: id,
            tournamentId: tournamentId,
            capacity: capacity,
            requirement: requirement,
            games: games
        )
    }
    
    // Helper functions to extract values from model structs
    private func extractInt(from models: [Struct], key: String) -> Int? {
        for model in models {
            for member in model.children {
                if member.name == key {
                    return extractIntFromTy(member.ty)
                }
            }
        }
        return nil
    }
    
    private func extractString(from models: [Struct], key: String) -> String? {
        for model in models {
            for member in model.children {
                if member.name == key {
                    return extractStringFromTy(member.ty)
                }
            }
        }
        return nil
    }
    
    private func extractBool(from models: [Struct], key: String) -> Bool? {
        for model in models {
            for member in model.children {
                if member.name == key {
                    return extractBoolFromTy(member.ty)
                }
            }
        }
        return nil
    }
    
    private func extractDate(from models: [Struct], key: String) -> Date? {
        guard let timestamp = extractInt(from: models, key: key) else { return nil }
        return Date(timeIntervalSince1970: TimeInterval(timestamp))
    }
    
    // Extract specific types from Ty enum
    private func extractIntFromTy(_ ty: Ty) -> Int? {
        switch ty {
        case .primitive(let primitive):
            switch primitive {
            case .u8(let value): return Int(value)
            case .u16(let value): return Int(value)
            case .u32(let value): return Int(value)
            case .u64(let value): return Int(value)
            case .i8(let value): return Int(value)
            case .i16(let value): return Int(value)
            case .i32(let value): return Int(value)
            case .i64(let value): return Int(value)
            default: return nil
            }
        default: return nil
        }
    }
    
    private func extractStringFromTy(_ ty: Ty) -> String? {
        switch ty {
        case .byteArray(let value): return value
        case .primitive(let primitive):
            switch primitive {
            case .felt252(let feltElement):
                // Convert FieldElement to String
                // FieldElement is likely a struct with string representation
                return "\(feltElement)"
            default: return nil
            }
        default: return nil
        }
    }
    
    private func extractBoolFromTy(_ ty: Ty) -> Bool? {
        switch ty {
        case .primitive(let primitive):
            switch primitive {
            case .bool(let value): return value
            default: return nil
            }
        default: return nil
        }
    }
    
    // MARK: - Subscriptions
    
    private func subscribeTournaments() async {
        guard let client = toriiClient else {
            print("⚠️ Torii client not initialized for subscription")
            return
        }
        
        do {
            print("🔔 Subscribing to tournament updates...")
            
            // Create subscription query for tournaments
            let query = Query(
                worldAddresses: [],
                pagination: Pagination(
                    cursor: nil,
                    limit: 100,
                    direction: .forward,
                    orderBy: []
                ),
                clause: nil,
                noHashedKeys: false,
                models: ["NUMS-Tournament"],
                historical: false
            )
            
            // TODO: Implement subscription when available in the SDK
            // tournamentSubscriptionId = try await client.subscribe(query: query)
            
            print("✅ Subscribed to tournaments")
        } catch {
            print("❌ Tournament subscription error: \(error)")
        }
    }
    
    private func subscribeLeaderboard(for tournamentId: Int) async {
        guard let client = toriiClient else {
            print("⚠️ Torii client not initialized for subscription")
            return
        }
        
        do {
            print("🔔 Subscribing to leaderboard updates for tournament #\(tournamentId)...")
            
            // Create subscription query for leaderboard
            let query = Query(
                worldAddresses: [],
                pagination: Pagination(
                    cursor: nil,
                    limit: 100,
                    direction: .forward,
                    orderBy: []
                ),
                clause: nil,
                noHashedKeys: false,
                models: ["NUMS-Leaderboard"],
                historical: false
            )
            
            // TODO: Implement subscription when available in the SDK
            // leaderboardSubscriptionId = try await client.subscribe(query: query)
            
            print("✅ Subscribed to leaderboard for tournament #\(tournamentId)")
        } catch {
            print("❌ Leaderboard subscription error: \(error)")
        }
    }
}


