import Foundation
import Combine

// MARK: - Callbacks

class TokenBalanceCallback: TokenBalanceUpdateCallback {
    private let updateHandler: (TokenBalance) -> Void
    
    init(onUpdate: @escaping (TokenBalance) -> Void) {
        self.updateHandler = onUpdate
    }
    
    func onUpdate(balance: TokenBalance) {
        updateHandler(balance)
    }
    
    func onError(error: String) {
        print("❌ Token balance subscription error: \(error)")
    }
}

class EntityCallback: EntityUpdateCallback {
    private let updateHandler: (Entity) -> Void
    
    init(onUpdate: @escaping (Entity) -> Void) {
        self.updateHandler = onUpdate
    }
    
    func onUpdate(entity: Entity) {
        updateHandler(entity)
    }
    
    func onError(error: String) {
        print("❌ Entity subscription error: \(error)")
    }
}

// MARK: - Models

// Tournament Model
struct Tournament: Identifiable {
    let id: Int
    let powers: Int
    let entryCount: Int
    let startTime: UInt64 // Unix timestamp
    let endTime: UInt64 // Unix timestamp
    
    // Helper to get start time as Date
    var startDate: Date {
        Date(timeIntervalSince1970: TimeInterval(startTime))
    }
    
    // Helper to get end time as Date
    var endDate: Date {
        Date(timeIntervalSince1970: TimeInterval(endTime))
    }
    
    // Helper to check if tournament is active
    var isActive: Bool {
        let now = Date()
        return now >= startDate && now <= endDate
    }
    
    // Helper to get time remaining
    var timeRemaining: TimeInterval {
        max(0, endDate.timeIntervalSinceNow)
    }
}

// Leaderboard Entry Model
struct LeaderboardPlayer: Identifiable {
    let id: String // Unique ID for SwiftUI
    let tournamentId: Int
    let capacity: Int
    let requirement: Int
    let games: String
}

// Game Model
struct Game: Identifiable {
    let id: String // token_id
    let tokenId: String
    let contractAddress: String
    let balance: String
    let accountAddress: String // Player who owns this game
}

// Arcade Leaderboard Entry (one entry per game)
struct ArcadeLeaderboardEntry: Identifiable {
    let id: String // unique id: "\(address)-\(tokenId)"
    let tokenId: String
    let address: String
    let username: String?
    let score: Int
    let reward: UInt32
}

// Helper struct for SQL query results
struct GameData {
    let tokenId: String
    let score: UInt32
    let reward: UInt32
}

// Game Model (NUMS-Game entity)
struct GameModel: Identifiable, Equatable {
    let id: String // token_id as string
    let tokenId: UInt64
    let over: Bool
    let claimed: Bool
    let level: UInt8
    let slotCount: UInt8
    let slotMin: UInt16
    let slotMax: UInt16
    let number: UInt16
    let nextNumber: UInt16
    let tournamentId: UInt16
    let powers: UInt16
    let reward: UInt32
    let score: UInt32
    let slots: String // felt252 encoded slots
    
    // Equatable conformance - compare all stored properties
    static func == (lhs: GameModel, rhs: GameModel) -> Bool {
        return lhs.id == rhs.id &&
               lhs.tokenId == rhs.tokenId &&
               lhs.over == rhs.over &&
               lhs.claimed == rhs.claimed &&
               lhs.level == rhs.level &&
               lhs.slotCount == rhs.slotCount &&
               lhs.slotMin == rhs.slotMin &&
               lhs.slotMax == rhs.slotMax &&
               lhs.number == rhs.number &&
               lhs.nextNumber == rhs.nextNumber &&
               lhs.tournamentId == rhs.tournamentId &&
               lhs.powers == rhs.powers &&
               lhs.reward == rhs.reward &&
               lhs.score == rhs.score &&
               lhs.slots == rhs.slots
    }
    
    // Computed property to extract set slots from the felt252 encoded slots
    var setSlots: Set<Int> {
        // Unpack the felt252 hex string using the Packer algorithm
        return unpackSlots(from: slots, slotCount: Int(slotCount), slotMax: Int(slotMax))
    }
    
    private func unpackSlots(from hexString: String, slotCount: Int, slotMax: Int) -> Set<Int> {
        // Remove "0x" prefix if present
        let hex = hexString.hasPrefix("0x") ? String(hexString.dropFirst(2)) : hexString
        
        // Convert hex string to BInt (big integer)
        guard var packed = BInt(hex, radix: 16) else {
            print("⚠️ Failed to parse slots hex: \(hexString)")
            return []
        }
        
        // SLOT_SIZE is the modulo value (slotMax + 1 to include 0)
        let slotSize = BInt(slotMax + 1)
        var result: Set<Int> = []
        
        // Unpack algorithm: extract slotCount values
        for index in 0..<slotCount {
            // Extract current value: packed % slotSize
            let value = packed % slotSize
            
            // Convert to Int and check if slot is set (non-zero)
            if let intValue = value.asInt(), intValue > 0 {
                // Slot positions are 1-based (1-20)
                result.insert(index + 1)
            }
            
            // Shift to next value: packed / slotSize
            packed = packed / slotSize
            
            // Early exit if packed becomes 0 (no more data)
            if packed == 0 {
                break
            }
        }
        
        return result
    }
}

@MainActor
class DojoManager: ObservableObject {
    // Dojo State (from Constants)
    @Published var isConnected = false
    @Published var worldAddress: String = Constants.worldAddress
    @Published var rpcUrl: String = Constants.rpcUrl
    @Published var toriiUrl: String = Constants.toriiUrl
    
    // Torii Client
    private var toriiClient: ToriiClient?
    
    // Tournament & Leaderboard
    @Published var tournaments: [Tournament] = []
    @Published var selectedTournament: Tournament?
    @Published var leaderboard: [LeaderboardPlayer] = []
    @Published var isLoadingTournaments = false
    @Published var showTournamentSelector = false
    
    // Token Balance
    @Published var tokenBalance: BInt = 0
    @Published var isLoadingBalance = false
    
    // Games
    @Published var games: [Game] = []
    @Published var isLoadingGames = false
    
    // Arcade Leaderboard (one entry per game)
    @Published var arcadeLeaderboard: [ArcadeLeaderboardEntry] = []
    @Published var isLoadingLeaderboard = false
    @Published var isLoadingMoreLeaderboard = false // For pagination only
    @Published var hasMoreLeaderboardEntries = true
    private var leaderboardOffset = 0
    private let leaderboardPageSize = 10
    
    // Game Models (NUMS-Game entities mapped by token ID)
    @Published var gameModels: [String: GameModel] = [:]
    @Published var isLoadingGameModels = false
    
    // Contract addresses (from Constants)
    private let tokenContractAddress = Constants.numsAddress
    private let gameTokenMintAddress = Constants.gameAddress // Game contract address for "Minted By" filter
    
    // Subscription tracking
    private var tournamentSubscriptionId: UInt64?
    private var leaderboardSubscriptionId: UInt64?
    private var tokenBalanceSubscriptionId: UInt64?
    private var gameSubscriptions: [String: UInt64] = [:] // game_id -> subscription_id
    
    // Polling timer for leaderboard
    private var leaderboardTimer: Timer?
    
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
            
            // Start subscriptions
            await subscribeTournaments()
            
            // Fetch leaderboard using SQL
            if let tournamentId = selectedTournament?.id {
                await fetchLeaderboardSQL(tournamentId: tournamentId)
                
                // Start polling timer for leaderboard updates (every 3 seconds)
                await MainActor.run {
                    self.startLeaderboardPolling(tournamentId: tournamentId)
                }
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
        
        // Stop existing polling
        await MainActor.run {
            self.leaderboardTimer?.invalidate()
            self.leaderboardTimer = nil
        }
        
        // Fetch leaderboard using SQL for the new tournament
        await fetchLeaderboardSQL(tournamentId: tournament.id)
        
        // Restart polling for new tournament
        await MainActor.run {
            self.startLeaderboardPolling(tournamentId: tournament.id)
        }
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
    
    // MARK: - SQL-Based Leaderboard
    
    func fetchLeaderboardSQL(tournamentId: Int, reset: Bool = true) async {
        guard let client = toriiClient else {
            print("⚠️ Torii client not initialized")
            return
        }
        
        // Check if we should fetch (don't clear data yet!)
        let (canLoad, currentOffset, isInitialLoad) = await MainActor.run {
            let offset = reset ? 0 : self.leaderboardOffset
            let canLoad = !self.isLoadingLeaderboard && !self.isLoadingMoreLeaderboard && (reset || self.hasMoreLeaderboardEntries)
            let isInitial = self.arcadeLeaderboard.isEmpty
            return (canLoad, offset, isInitial)
        }
        
        guard canLoad else { return }
        
        await MainActor.run {
            // Only show loading indicator for initial load or pagination, not refresh
            if reset && isInitialLoad {
                self.isLoadingLeaderboard = true
            } else if !reset {
                self.isLoadingMoreLeaderboard = true
            }
        }
        
        do {
            print("📊 Fetching leaderboard via SQL for tournament #\(tournamentId) (offset: \(currentOffset))...")
            
            // SQL query to get arcade-style leaderboard (one entry per game)
            let query = """
            SELECT t.token_id, c.username, g.score, g.reward, tb.account_address
            FROM tokens AS t
            JOIN token_balances AS tb ON tb.token_id = t.id
            JOIN token_attributes AS ta ON ta.token_id = t.id
            JOIN controllers AS c ON c.address = tb.account_address
            JOIN "NUMS-Game" AS g ON lower(substr(t.token_id, -16)) = lower(substr(g.id, -16))
            WHERE t.contract_address = '\(Constants.denshokanAddress)'
                AND tb.balance != '0x0000000000000000000000000000000000000000000000000000000000000000'
                AND ta.trait_name = 'Minted By'
                AND ta.trait_value = '\(Constants.gameAddress)'
                AND g.tournament_id = \(tournamentId)
            ORDER BY g.score DESC
            LIMIT \(leaderboardPageSize) OFFSET \(currentOffset)
            """
            
            let rows = try client.sql(query: query)
            print("📦 SQL returned \(rows.count) rows")
            
            // Build arcade-style leaderboard (one entry per game, no deduplication)
            var entries: [ArcadeLeaderboardEntry] = []
            
            for row in rows {
                var owner: String?
                var tokenId: String?
                var score: UInt32 = 0
                var reward: UInt32 = 0
                var username: String?
                
                for field in row.fields {
                    switch field.name {
                    case "account_address":
                        if case .text(let value) = field.value {
                            owner = value
                        }
                    case "token_id":
                        if case .text(let value) = field.value {
                            tokenId = value
                        }
                    case "score":
                        if case .integer(let value) = field.value {
                            score = UInt32(value)
                        }
                    case "reward":
                        if case .integer(let value) = field.value {
                            reward = UInt32(value)
                        }
                    case "username":
                        if case .text(let value) = field.value {
                            username = value
                        }
                    default:
                        break
                    }
                }
                
                if let owner = owner, let tokenId = tokenId {
                    // Cache username for this player
                    if let username = username {
                        usernameCache[owner] = username
                    }
                    
                    // Create one leaderboard entry per game (arcade-style)
                    let entry = ArcadeLeaderboardEntry(
                        id: "\(owner)-\(tokenId)", // Unique ID per game
                        tokenId: tokenId,
                        address: owner,
                        username: username ?? usernameCache[owner],
                        score: Int(score),
                        reward: reward
                    )
                    entries.append(entry)
                }
            }
            
            // Update state
            await MainActor.run {
                if reset {
                    // Replace entire leaderboard (polling/refresh)
                    self.arcadeLeaderboard = entries
                    self.leaderboardOffset = entries.count
                    self.hasMoreLeaderboardEntries = entries.count >= self.leaderboardPageSize
                    print("✅ SQL Leaderboard refreshed: \(entries.count) entries")
                } else {
                    // Append new entries (pagination)
                    self.arcadeLeaderboard.append(contentsOf: entries)
                    self.leaderboardOffset += entries.count
                    
                    // If we got fewer entries than page size, no more to load
                    if entries.count < self.leaderboardPageSize {
                        self.hasMoreLeaderboardEntries = false
                    }
                    print("✅ SQL Leaderboard loaded more: \(entries.count) new entries (total: \(self.arcadeLeaderboard.count))")
                }
                
                self.isLoadingLeaderboard = false
                self.isLoadingMoreLeaderboard = false
            }
            
        } catch {
            await MainActor.run {
                self.errorMessage = "Failed to fetch leaderboard: \(error.localizedDescription)"
                self.isLoadingLeaderboard = false
                self.isLoadingMoreLeaderboard = false
                print("❌ SQL Leaderboard error: \(error)")
            }
        }
    }
    
    func loadMoreLeaderboard(tournamentId: Int) async {
        await fetchLeaderboardSQL(tournamentId: tournamentId, reset: false)
    }
    
    private var usernameCache: [String: String] = [:]
    
    private func startLeaderboardPolling(tournamentId: Int) {
        // Cancel existing timer
        leaderboardTimer?.invalidate()
        
        // Create timer that runs every 3 seconds
        leaderboardTimer = Timer.scheduledTimer(withTimeInterval: 3.0, repeats: true) { [weak self] _ in
            guard let self = self else { return }
            Task {
                await self.refreshLeaderboard(tournamentId: tournamentId)
            }
        }
        
        print("⏰ Started leaderboard polling (every 3s)")
    }
    
    private func refreshLeaderboard(tournamentId: Int) async {
        // Only refresh if user hasn't paginated beyond first page
        // This prevents resetting their scroll position
        let shouldRefresh = await MainActor.run {
            self.leaderboardOffset <= self.leaderboardPageSize
        }
        
        if shouldRefresh {
            await fetchLeaderboardSQL(tournamentId: tournamentId, reset: true)
        } else {
            print("⏭️ Skipping leaderboard refresh - user has paginated beyond first page")
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
                        let divisor = BInt(10) ** 18
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
            
            // Create callback for token balance updates
            let callback = TokenBalanceCallback { [weak self] balance in
                Task { @MainActor in
                    guard let self = self else { return }
                    
                    // Convert balance from hex/string to BInt
                    let balanceString = balance.balance.hasPrefix("0x") ?
                        String(balance.balance.dropFirst(2)) : balance.balance
                    
                    if let balanceValue = BInt(balanceString, radix: 16) ?? BInt(balanceString, radix: 10) {
                        // Convert from WEI to tokens (divide by 10^18)
                        let divisor = BInt(10) ** 18
                        let tokenAmount = balanceValue / divisor
                        
                        self.tokenBalance = tokenAmount
                        print("💰 Token balance updated: \(tokenAmount) NUMS")
                    }
                }
            }
            
            // Subscribe to balance updates
            let subscriptionId = try client.subscribeTokenBalanceUpdates(
                contractAddresses: [tokenContractAddress],
                accountAddresses: [accountAddress],
                tokenIds: [],
                callback: callback
            )
            
            // Store subscription ID for cleanup later
            tokenBalanceSubscriptionId = subscriptionId
            
            print("✅ Subscribed to token balance for \(accountAddress) (ID: \(subscriptionId))")
        } catch {
            print("❌ Token balance subscription error: \(error)")
        }
    }
    
    // MARK: - Parsing Helpers
    
    private func parseTournament(from entity: Entity) -> Tournament? {
        let models = entity.models
        
        guard let id = extractInt(from: models, key: "id") else { return nil }
        let powers = extractInt(from: models, key: "powers") ?? 0
        let entryCount = extractInt(from: models, key: "entry_count") ?? 0
        
        guard let startTime = extractU64(from: models, key: "start_time") else {
            print("⚠️ Tournament missing start_time")
            return nil
        }
        guard let endTime = extractU64(from: models, key: "end_time") else {
            print("⚠️ Tournament missing end_time")
            return nil
        }
        
        return Tournament(
            id: id,
            powers: powers,
            entryCount: entryCount,
            startTime: startTime,
            endTime: endTime
        )
    }
    
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
    
    private func extractU64(from models: [Struct], key: String) -> UInt64? {
        for model in models {
            for member in model.children {
                if member.name == key {
                    return extractU64FromTy(member.ty)
                }
            }
        }
        return nil
    }
    
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
            case .felt252(let feltElement): return "\(feltElement)"
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
    
    private func extractU64FromTy(_ ty: Ty) -> UInt64? {
        switch ty {
        case .primitive(let primitive):
            switch primitive {
            case .u64(let value): return value
            default: return nil
            }
        default: return nil
        }
    }
    
    private func extractUInt8FromTy(_ ty: Ty) -> UInt8 {
        switch ty {
        case .primitive(let primitive):
            switch primitive {
            case .u8(let value): return value
            default: return 0
            }
        default: return 0
        }
    }
    
    private func extractUInt16FromTy(_ ty: Ty) -> UInt16 {
        switch ty {
        case .primitive(let primitive):
            switch primitive {
            case .u16(let value): return value
            case .u8(let value): return UInt16(value)
            default: return 0
            }
        default: return 0
        }
    }
    
    private func extractUInt32FromTy(_ ty: Ty) -> UInt32 {
        switch ty {
        case .primitive(let primitive):
            switch primitive {
            case .u32(let value): return value
            case .u16(let value): return UInt32(value)
            case .u8(let value): return UInt32(value)
            default: return 0
            }
        default: return 0
        }
    }
    
    private func extractUInt64FromTy(_ ty: Ty) -> UInt64 {
        switch ty {
        case .primitive(let primitive):
            switch primitive {
            case .u64(let value): return value
            case .u32(let value): return UInt64(value)
            case .u16(let value): return UInt64(value)
            case .u8(let value): return UInt64(value)
            default: return 0
            }
        default: return 0
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
            
            // Create callback for tournament updates
            let callback = EntityCallback { [weak self] entity in
                guard let self = self else { return }
                
                print("🏆 Tournament entity update received")
                
                // Parse the updated tournament
                if let updatedTournament = self.parseTournament(from: entity) {
                    Task { @MainActor in
                        // Update tournament in list
                        if let index = self.tournaments.firstIndex(where: { $0.id == updatedTournament.id }) {
                            self.tournaments[index] = updatedTournament
                            
                            // Update selected tournament if it matches
                            if self.selectedTournament?.id == updatedTournament.id {
                                self.selectedTournament = updatedTournament
                            }
                        } else {
                            // New tournament, add to list
                            self.tournaments.append(updatedTournament)
                        }
                        print("✅ Tournament updated: #\(updatedTournament.id)")
                    }
                }
            }
            
            // Create keys clause to filter for NUMS-Tournament model only
            let keysClause = KeysClause(
                keys: [],
                patternMatching: .variableLen,
                models: ["NUMS-Tournament"]
            )
            let clause = Clause.keys(clause: keysClause)
            
            // Subscribe to all NUMS-Tournament entities
            let subscriptionId = try client.subscribeEntityUpdates(
                clause: clause,
                worldAddresses: [],
                callback: callback
            )
            
            tournamentSubscriptionId = subscriptionId
            print("✅ Subscribed to tournaments (ID: \(subscriptionId))")
        } catch {
            print("❌ Tournament subscription error: \(error)")
        }
    }
    
    
    // MARK: - Game Management
    
    func fetchGameModel(gameId: String) async -> GameModel? {
        guard let client = toriiClient else {
            print("⚠️ Torii client not initialized")
            return nil
        }
        
        do {
            print("🎮 Fetching game model for game #\(gameId)...")
            
            // Create query for NUMS-Game model with game ID filter
            let query = Query(
                worldAddresses: [],
                pagination: Pagination(
                    cursor: nil,
                    limit: 1,
                    direction: .forward,
                    orderBy: []
                ),
                clause: nil, // TODO: Add filter for game ID if needed
                noHashedKeys: false,
                models: ["NUMS-Game"],
                historical: false
            )
            
            let pageEntity = try client.entities(query: query)
            
            // Parse and find the game with matching ID
            for entity in pageEntity.items {
                if let parsedGame = parseGameModel(from: entity, gameId: gameId) {
                    print("✅ Game model loaded for #\(gameId)")
                    return parsedGame
                }
            }
            
            print("⚠️ Game model not found for #\(gameId)")
            return nil
        } catch {
            print("❌ Game model fetch error: \(error)")
            return nil
        }
    }
    
    private func parseGameModel(from entity: Entity, gameId: String) -> GameModel? {
        let models = entity.models
        
        for model in models {
            if model.name == "NUMS-Game" {
                // Extract fields from the model
                var tokenId: UInt64 = 0
                var over = false
                var claimed = false
                var level: UInt8 = 1
                var slotCount: UInt8 = 20
                var slotMin: UInt16 = 1
                var slotMax: UInt16 = 999
                var number: UInt16 = 0
                var nextNumber: UInt16 = 0
                var tournamentId: UInt16 = 0
                var powers: UInt16 = 0
                var reward: UInt32 = 0
                var score: UInt32 = 0
                var slots: String = ""
                
                for child in model.children {
                    switch child.name {
                    case "id":
                        tokenId = extractUInt64FromTy(child.ty)
                    case "over":
                        over = extractBoolFromTy(child.ty) ?? false
                    case "claimed":
                        claimed = extractBoolFromTy(child.ty) ?? false
                    case "level":
                        level = extractUInt8FromTy(child.ty)
                    case "slot_count":
                        slotCount = extractUInt8FromTy(child.ty)
                    case "slot_min":
                        slotMin = extractUInt16FromTy(child.ty)
                    case "slot_max":
                        slotMax = extractUInt16FromTy(child.ty)
                    case "number":
                        number = extractUInt16FromTy(child.ty)
                    case "next_number":
                        nextNumber = extractUInt16FromTy(child.ty)
                    case "tournament_id":
                        tournamentId = extractUInt16FromTy(child.ty)
                    case "powers":
                        powers = extractUInt16FromTy(child.ty)
                    case "reward":
                        reward = extractUInt32FromTy(child.ty)
                    case "score":
                        score = extractUInt32FromTy(child.ty)
                    case "slots":
                        slots = extractStringFromTy(child.ty) ?? ""
                    default:
                        break
                    }
                }
                
                // Check if this is the game we're looking for
                if String(tokenId) == gameId {
                    return GameModel(
                        id: gameId,
                        tokenId: tokenId,
                        over: over,
                        claimed: claimed,
                        level: level,
                        slotCount: slotCount,
                        slotMin: slotMin,
                        slotMax: slotMax,
                        number: number,
                        nextNumber: nextNumber,
                        tournamentId: tournamentId,
                        powers: powers,
                        reward: reward,
                        score: score,
                        slots: slots
                    )
                }
            }
        }
        
        return nil
    }
    
    func startGame(gameId: String, tournamentId: Int, sessionManager: SessionManager) async {
        print("🎮 Starting new game #\(gameId) for tournament #\(tournamentId)")
        
        // Convert game ID to felt252 (hex string)
        let gameIdFelt = String(format: "0x%x", UInt64(gameId) ?? 0)
        let tournamentIdFelt = String(format: "0x%x", tournamentId)
        
        await sessionManager.executeTransaction(
            contractAddress: Constants.gameAddress,
            entrypoint: "start",
            calldata: [gameIdFelt, tournamentIdFelt]
        )
    }
    
    func setGameSlot(gameId: String, slot: UInt8, sessionManager: SessionManager) async {
        print("🎮 Setting slot #\(slot) for game #\(gameId)")
        
        // Convert parameters to felt252 (hex strings)
        let gameIdFelt = String(format: "0x%x", UInt64(gameId) ?? 0)
        let slotIndex = String(format: "0x%x", slot - 1) // Convert to 0-based index
        
        // Multi-call: VRF request_random + game set
        guard let session = sessionManager.sessionAccount else {
            print("❌ No session account available")
            return
        }
        
        do {
            // Create both calls
            // VRF request_random takes game address as both parameters
            let vrfCall = Call(
                contractAddress: Constants.vrfAddress,
                entrypoint: "request_random",
                calldata: [Constants.gameAddress, Constants.gameAddress]
            )
            
            // Game set takes game ID and slot index (0-based)
            let setCall = Call(
                contractAddress: Constants.gameAddress,
                entrypoint: "set",
                calldata: [gameIdFelt, slotIndex]
            )
            
            // Execute multi-call
            let txHash = try session.executeFromOutside(calls: [vrfCall, setCall])
            
            print("✅ Slot set transaction submitted: \(txHash)")
            print("💡 Game state will update via subscription")
            
        } catch {
            print("❌ Failed to set slot: \(error.localizedDescription)")
        }
    }
    
    // MARK: - Game Subscription (Per-Game)
    
    func subscribeToGame(_ gameId: String) async {
        guard let client = toriiClient else {
            print("⚠️ Torii client not initialized")
            return
        }
        
        // Check if already subscribed
        if gameSubscriptions[gameId] != nil {
            print("ℹ️ Already subscribed to game \(gameId)")
            return
        }
        
        print("🔔 Subscribing to game entity updates for game #\(gameId)...")
        
        do {
            // Build clause to match the specific game entity
            // NUMS-Game entity has keys: [game_id]
            let keysClause = KeysClause(
                keys: [gameId],
                patternMatching: .variableLen,
                models: ["NUMS-Game"]
            )
            let clause = Clause.keys(clause: keysClause)
            
            // Subscribe with callback
            let callback = EntityCallback { [weak self] entity in
                guard let self = self else { return }
                
                print("🎮 Game entity update received for game #\(gameId)")
                
                // Parse the updated entity into GameModel
                if let updatedModel = self.parseGameModel(from: entity, gameId: gameId) {
                    Task { @MainActor in
                        // Update the game model in our dictionary
                        self.gameModels[updatedModel.id] = updatedModel
                        print("✅ Game model updated: #\(updatedModel.id) - score=\(updatedModel.score), number=\(updatedModel.number)")
                    }
                }
            }
            
            let subscriptionId = try client.subscribeEntityUpdates(
                clause: clause,
                worldAddresses: [],
                callback: callback
            )
            
            gameSubscriptions[gameId] = subscriptionId
            print("✅ Subscribed to game #\(gameId) (subscription ID: \(subscriptionId))")
            
        } catch {
            print("❌ Failed to subscribe to game: \(error.localizedDescription)")
        }
    }
    
    func unsubscribeFromGame(_ gameId: String) async {
        guard let client = toriiClient else {
            print("⚠️ Torii client not initialized")
            return
        }
        
        guard let subscriptionId = gameSubscriptions[gameId] else {
            print("ℹ️ No active subscription for game \(gameId)")
            return
        }
        
        do {
            try client.cancelSubscription(subscriptionId: subscriptionId)
            gameSubscriptions.removeValue(forKey: gameId)
            print("✅ Unsubscribed from game #\(gameId)")
        } catch {
            print("❌ Failed to unsubscribe from game: \(error.localizedDescription)")
        }
    }
    
}


