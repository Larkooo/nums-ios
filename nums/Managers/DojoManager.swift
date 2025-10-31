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

// Prize Model (NUMS-Prize entity)
struct Prize: Identifiable {
    let id: String // Unique ID: "\(tournamentId)-\(address)"
    let tournamentId: Int
    let address: String // Token contract address (STRK, ETH, etc.)
    let amount: String // u128 as string (we'll format for display)
    var customTokenName: String? // Fetched token name from RPC
    
    // Helper to get the token symbol for known addresses
    var tokenSymbol: String {
        // If we fetched a custom name, use it
        if let customName = customTokenName, !customName.isEmpty {
            return customName
        }
        
        switch address.lowercased() {
        case Constants.strkTokenAddress.lowercased():
            return "STRK"
        case Constants.ethTokenAddress.lowercased():
            return "ETH"
        default:
            return "TOKEN"
        }
    }
    
    // Helper to format amount for display
    var formattedAmount: String {
        // Parse u128 string to BInt and format
        if let amountInt = BInt(amount, radix: 10) {
            // Divide by 10^18 to get human-readable amount
            let divisor = BInt(10) ** 18
            let tokens = amountInt / divisor
            return "\(tokens)"
        }
        return amount
    }
    
    // Helper to format amount compactly (e.g., 2M, 500K, 1.5B)
    var compactFormattedAmount: String {
        // Parse u128 string to BInt and format
        guard let amountInt = BInt(amount, radix: 10) else {
            return amount
        }
        
        // Divide by 10^18 to get human-readable amount
        let divisor = BInt(10) ** 18
        let tokens = amountInt / divisor
        
        // Convert to Double for compact formatting
        guard let doubleValue = Double(tokens.description) else {
            return "\(tokens)"
        }
        
        // Format with K, M, B suffixes
        if doubleValue >= 1_000_000_000 {
            return String(format: "%.1fB", doubleValue / 1_000_000_000)
        } else if doubleValue >= 1_000_000 {
            return String(format: "%.1fM", doubleValue / 1_000_000)
        } else if doubleValue >= 1_000 {
            return String(format: "%.1fK", doubleValue / 1_000)
        } else {
            return String(format: "%.0f", doubleValue)
        }
    }
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
        // Unpack the felt252 hex string to get which slots have values
        let slotValues = unpackSlotValues(from: slots, slotCount: Int(slotCount))
        return Set(slotValues.enumerated().compactMap { $0.element > 0 ? $0.offset + 1 : nil })
    }
    
    // Computed property to get the actual slot values (0 if not set)
    var slotValues: [UInt16] {
        return unpackSlotValues(from: slots, slotCount: Int(slotCount))
    }
    
    private func unpackSlotValues(from hexString: String, slotCount: Int) -> [UInt16] {
        // Remove "0x" prefix if present
        let hex = hexString.hasPrefix("0x") ? String(hexString.dropFirst(2)) : hexString
        
        // Handle empty or zero slots
        if hex.isEmpty || hex.trimmingCharacters(in: CharacterSet(charactersIn: "0")) == "" {
            print("   📭 Slots empty or all zeros")
            return Array(repeating: 0, count: slotCount)
        }
        
        print("   🔢 Unpacking slots: hex=\(hex)")
        
        // Convert hex string to BInt
        guard var packed = BInt(hex, radix: 16) else {
            print("⚠️ Failed to parse slots hex: \(hexString)")
            return Array(repeating: 0, count: slotCount)
        }
        
        print("   📦 Packed value (decimal): \(packed)")
        
        // Use 12-bit packing (matches JavaScript implementation)
        // Each slot is 12 bits (0-4095, covering 0-999)
        let slotSize = 12
        let mask = BInt((1 << slotSize) - 1) // 0xFFF = 4095
        print("   🔧 Using 12-bit packing (SLOT_SIZE=12)")
        
        var values: [UInt16] = []
        
        print("   📋 Extracting slot values (slot 1 → 20):")
        
        // Extract each slot using bit-shift and mask
        // slot[0] at LSB, slot[19] higher up
        for index in 0..<slotCount {
            // Extract lower 12 bits
            let value = packed & mask
            
            if let intValue = value.asInt(), intValue >= 0 && intValue <= 4095 {
                let slotValue = UInt16(intValue)
                values.append(slotValue)
                if slotValue > 0 {
                    print("      Slot \(index + 1): \(slotValue) ✓")
                }
            } else {
                values.append(0)
            }
            
            // Shift right by 12 bits to get next slot
            packed = packed >> slotSize
            
            // Early exit if packed becomes 0 (no more data)
            if packed == 0 {
                // Fill remaining slots with 0
                while values.count < slotCount {
                    values.append(0)
                }
                break
            }
        }
        
        print("   ✅ Extracted \(values.count) slot values")
        return values
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
    
    // Prizes (mapped by tournament ID)
    @Published var prizes: [Int: [Prize]] = [:]
    @Published var isLoadingPrizes = false
    
    // Token name cache (address -> name)
    private var tokenNameCache: [String: String] = [:]
    
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
    private let leaderboardPageSize = 20
    
    // Game Models (NUMS-Game entities mapped by token ID)
    @Published var gameModels: [String: GameModel] = [:]
    @Published var isLoadingGameModels = false
    
    // Contract addresses (from Constants)
    private let tokenContractAddress = Constants.numsAddress
    private let gameTokenMintAddress = Constants.gameAddress // Game contract address for "Minted By" filter
    
    // Subscription tracking
    private var tournamentAndPrizeSubscriptionId: UInt64?
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
            await subscribeTournamentsAndPrizes()
            
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
            
            // Fetch prizes for all tournaments
            await fetchAllPrizes()
            
            // Fetch token names for unknown prizes
            await fetchTokenNamesForPrizes()
            
        } catch {
            await MainActor.run {
                self.errorMessage = "Failed to fetch tournaments: \(error.localizedDescription)"
                self.isLoadingTournaments = false
                print("❌ Tournaments fetch error: \(error)")
            }
        }
    }
    
    func fetchAllPrizes() async {
        guard let client = toriiClient else {
            print("⚠️ Torii client not initialized")
            return
        }
        
        await MainActor.run {
            self.isLoadingPrizes = true
        }
        
        do {
            print("💎 Fetching all prizes...")
            
            // Create query for NUMS-Prize model - fetch all
            let query = Query(
                worldAddresses: [],
                pagination: Pagination(
                    cursor: nil,
                    limit: 1000, // Fetch many prizes (multiple per tournament)
                    direction: .forward,
                    orderBy: []
                ),
                clause: nil,
                noHashedKeys: false,
                models: ["NUMS-Prize"],
                historical: false
            )
            
            let pageEntity = try client.entities(query: query)
            
            await MainActor.run {
                // Parse all prize data from entities and group by tournament ID
                var prizesByTournament: [Int: [Prize]] = [:]
                
                for entity in pageEntity.items {
                    if let prize = self.parsePrize(from: entity) {
                        if prizesByTournament[prize.tournamentId] == nil {
                            prizesByTournament[prize.tournamentId] = []
                        }
                        prizesByTournament[prize.tournamentId]?.append(prize)
                    }
                }
                
                self.prizes = prizesByTournament
                print("✅ Prizes loaded: \(pageEntity.items.count) total prizes across \(prizesByTournament.keys.count) tournaments")
                self.isLoadingPrizes = false
            }
        } catch {
            await MainActor.run {
                self.errorMessage = "Failed to fetch prizes: \(error.localizedDescription)"
                self.isLoadingPrizes = false
                print("❌ Prizes fetch error: \(error)")
            }
        }
    }
    
    // MARK: - Token Name Fetching
    
    func fetchTokenNamesForPrizes() async {
        print("🏷️ Fetching token names for unknown prizes...")
        
        // Get all unique unknown token addresses
        var unknownAddresses: Set<String> = []
        await MainActor.run {
            for (_, prizeList) in self.prizes {
                for prize in prizeList {
                    // Skip if it's a known token or already cached
                    let isKnown = prize.address.lowercased() == Constants.strkTokenAddress.lowercased() ||
                                  prize.address.lowercased() == Constants.ethTokenAddress.lowercased()
                    if !isKnown && self.tokenNameCache[prize.address] == nil {
                        unknownAddresses.insert(prize.address)
                    }
                }
            }
        }
        
        // Fetch names for each unknown address
        for address in unknownAddresses {
            if let tokenName = await fetchTokenName(address: address) {
                await MainActor.run {
                    self.tokenNameCache[address] = tokenName
                    print("✅ Fetched token name: \(tokenName) for \(address.prefix(10))...")
                    
                    // Update prizes with the new token name
                    for (tournamentId, prizeList) in self.prizes {
                        var updatedPrizes: [Prize] = []
                        for var prize in prizeList {
                            if prize.address == address {
                                prize.customTokenName = tokenName
                            }
                            updatedPrizes.append(prize)
                        }
                        self.prizes[tournamentId] = updatedPrizes
                    }
                }
            }
        }
        
        print("✅ Token name fetching complete")
    }
    
    func fetchTokenName(address: String) async -> String? {
        // Call Starknet RPC to get token symbol/name
        guard let url = URL(string: rpcUrl) else {
            return nil
        }
        
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        
        // Starknet call: symbol() function selector
        // selector for "symbol()" = 0x216b05c387bab9ac31918a3e61672f4618601f3c598a2f3f2710f37053e1ea4
        let symbolSelector = "0x216b05c387bab9ac31918a3e61672f4618601f3c598a2f3f2710f37053e1ea4"
        
        let requestBody: [String: Any] = [
            "jsonrpc": "2.0",
            "method": "starknet_call",
            "params": [
                [
                    "contract_address": address,
                    "entry_point_selector": symbolSelector,
                    "calldata": []
                ],
                "latest"
            ],
            "id": 1
        ]
        
        do {
            request.httpBody = try JSONSerialization.data(withJSONObject: requestBody)
            
            let (data, response) = try await URLSession.shared.data(for: request)
            
            guard let httpResponse = response as? HTTPURLResponse,
                  httpResponse.statusCode == 200 else {
                print("❌ RPC call failed for \(address.prefix(10))...")
                return nil
            }
            
            // Parse response
            if let json = try JSONSerialization.jsonObject(with: data) as? [String: Any],
               let result = json["result"] as? [String] {
                // Decode the felt252 response to string
                if let symbolFelt = result.first {
                    let symbol = decodeFelt252ToString(symbolFelt)
                    return symbol
                }
            }
        } catch {
            print("❌ Error fetching token name for \(address.prefix(10))...: \(error)")
        }
        
        return nil
    }
    
    // Helper to decode felt252 to ASCII string
    private func decodeFelt252ToString(_ felt: String) -> String {
        // Remove 0x prefix
        let hex = felt.hasPrefix("0x") ? String(felt.dropFirst(2)) : felt
        
        // Convert hex to bytes
        var bytes: [UInt8] = []
        var index = hex.startIndex
        while index < hex.endIndex {
            let nextIndex = hex.index(index, offsetBy: 2, limitedBy: hex.endIndex) ?? hex.endIndex
            let byteString = String(hex[index..<nextIndex])
            if let byte = UInt8(byteString, radix: 16) {
                if byte != 0 { // Skip null bytes
                    bytes.append(byte)
                }
            }
            index = nextIndex
        }
        
        // Convert bytes to string
        return String(bytes: bytes, encoding: .utf8) ?? "TOKEN"
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
            
            if !canLoad {
                print("❌ Cannot load: isLoading=\(self.isLoadingLeaderboard), isLoadingMore=\(self.isLoadingMoreLeaderboard), hasMore=\(self.hasMoreLeaderboardEntries), reset=\(reset)")
            }
            
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
                    print("✅ SQL Leaderboard refreshed: \(entries.count) entries, hasMore: \(self.hasMoreLeaderboardEntries)")
                } else {
                    // Append new entries (pagination)
                    let oldCount = self.arcadeLeaderboard.count
                    self.arcadeLeaderboard.append(contentsOf: entries)
                    self.leaderboardOffset += entries.count
                    
                    // If we got fewer entries than page size, no more to load
                    if entries.count < self.leaderboardPageSize {
                        self.hasMoreLeaderboardEntries = false
                        print("✅ SQL Leaderboard loaded more: \(entries.count) new entries (total: \(self.arcadeLeaderboard.count)) - NO MORE TO LOAD")
                    } else {
                        print("✅ SQL Leaderboard loaded more: \(entries.count) new entries (total: \(self.arcadeLeaderboard.count)) - hasMore: \(self.hasMoreLeaderboardEntries)")
                    }
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
    
    // Public method to stop leaderboard polling
    func stopLeaderboardPolling() {
        leaderboardTimer?.invalidate()
        leaderboardTimer = nil
        print("⏸️ Stopped leaderboard polling")
    }
    
    // Public method to resume leaderboard polling for current tournament
    func resumeLeaderboardPolling() {
        guard let tournament = selectedTournament else {
            print("⚠️ Cannot resume polling: No tournament selected")
            return
        }
        startLeaderboardPolling(tournamentId: tournament.id)
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
    
    private func parsePrize(from entity: Entity) -> Prize? {
        let models = entity.models
        
        guard let tournamentId = extractInt(from: models, key: "tournament_id") else {
            print("⚠️ Prize missing tournament_id")
            return nil
        }
        guard let address = extractString(from: models, key: "address") else {
            print("⚠️ Prize missing address")
            return nil
        }
        guard let amount = extractU128(from: models, key: "amount") else {
            print("⚠️ Prize missing amount")
            return nil
        }
        
        return Prize(
            id: "\(tournamentId)-\(address)",
            tournamentId: tournamentId,
            address: address,
            amount: amount,
            customTokenName: nil
        )
    }
    
    private func extractU128(from models: [Struct], key: String) -> String? {
        for model in models {
            for member in model.children {
                if member.name == key {
                    return extractU128FromTy(member.ty)
                }
            }
        }
        return nil
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
    
    private func extractU128FromTy(_ ty: Ty) -> String? {
        switch ty {
        case .primitive(let primitive):
            switch primitive {
            case .u128(let value):
                // u128 comes as Data, convert to decimal string
                // The data is in big-endian format
                let bigInt = BInt(bytes: value)
                return bigInt.asString(radix: 10)
            default: return nil
            }
        default: return nil
        }
    }
    
    // MARK: - Subscriptions
    
    private func subscribeTournamentsAndPrizes() async {
        guard let client = toriiClient else {
            print("⚠️ Torii client not initialized for subscription")
            return
        }
        
        do {
            print("🔔 Subscribing to tournament and prize updates...")
            
            // Create unified callback for both tournaments and prizes
            let callback = EntityCallback { [weak self] entity in
                guard let self = self else { return }
                
                // Check which model type this entity is
                let modelNames = entity.models.map { $0.name }
                
                if modelNames.contains("NUMS-Tournament") {
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
                                self.tournaments.sort { $0.id < $1.id }
                            }
                            print("✅ Tournament updated: #\(updatedTournament.id)")
                        }
                    }
                }
                
                if modelNames.contains("NUMS-Prize") {
                    print("💎 Prize entity update received")
                    
                    // Parse the updated prize
                    if let updatedPrize = self.parsePrize(from: entity) {
                        Task { @MainActor in
                            // Update prize in the prizes dictionary
                            if self.prizes[updatedPrize.tournamentId] == nil {
                                self.prizes[updatedPrize.tournamentId] = []
                            }
                            
                            // Check if prize already exists (update) or is new (add)
                            if let index = self.prizes[updatedPrize.tournamentId]?.firstIndex(where: { $0.id == updatedPrize.id }) {
                                // Update existing prize, preserve custom token name if already fetched
                                var prizeToUpdate = updatedPrize
                                if let existingCustomName = self.prizes[updatedPrize.tournamentId]?[index].customTokenName {
                                    prizeToUpdate.customTokenName = existingCustomName
                                }
                                self.prizes[updatedPrize.tournamentId]?[index] = prizeToUpdate
                                print("✅ Prize updated: \(updatedPrize.id)")
                            } else {
                                // New prize, add to list
                                self.prizes[updatedPrize.tournamentId]?.append(updatedPrize)
                                print("✅ New prize added: \(updatedPrize.id)")
                                
                                // Fetch token name if it's an unknown token
                                let isKnown = updatedPrize.address.lowercased() == Constants.strkTokenAddress.lowercased() ||
                                              updatedPrize.address.lowercased() == Constants.ethTokenAddress.lowercased()
                                if !isKnown && self.tokenNameCache[updatedPrize.address] == nil {
                                    Task {
                                        if let tokenName = await self.fetchTokenName(address: updatedPrize.address) {
                                            await MainActor.run {
                                                self.tokenNameCache[updatedPrize.address] = tokenName
                                                
                                                // Update the prize with the fetched name
                                                if let prizeIndex = self.prizes[updatedPrize.tournamentId]?.firstIndex(where: { $0.id == updatedPrize.id }) {
                                                    self.prizes[updatedPrize.tournamentId]?[prizeIndex].customTokenName = tokenName
                                                    print("✅ Fetched token name: \(tokenName) for new prize")
                                                }
                                            }
                                        }
                                    }
                                }
                            }
                        }
                    }
                }
            }
            
            // Create keys clause to filter for both NUMS-Tournament and NUMS-Prize models
            let keysClause = KeysClause(
                keys: [],
                patternMatching: .variableLen,
                models: ["NUMS-Tournament", "NUMS-Prize"]
            )
            let clause = Clause.keys(clause: keysClause)
            
            // Subscribe to both model types with a single subscription
            let subscriptionId = try client.subscribeEntityUpdates(
                clause: clause,
                worldAddresses: [],
                callback: callback
            )
            
            tournamentAndPrizeSubscriptionId = subscriptionId
            print("✅ Subscribed to tournaments and prizes (ID: \(subscriptionId))")
        } catch {
            print("❌ Tournament and prize subscription error: \(error)")
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
            
            // Convert hex game ID to UInt64
            let hexString = gameId.hasPrefix("0x") ? String(gameId.dropFirst(2)) : gameId
            guard let gameIdU64 = UInt64(hexString, radix: 16) else {
                print("❌ Failed to parse game ID as hex: \(gameId)")
                return nil
            }
            
            print("   Converted gameId to UInt64: \(gameIdU64)")
            
            // Create MemberClause to filter on id field
            let memberClause = MemberClause(
                model: "NUMS-Game",
                member: "id",
                operator: .eq,
                value: .primitive(value: .u64(value: gameIdU64))
            )
            let clause = Clause.member(clause: memberClause)
            
            let query = Query(
                worldAddresses: [],
                pagination: Pagination(
                    cursor: nil,
                    limit: 1,
                    direction: .forward,
                    orderBy: []
                ),
                clause: clause,
                noHashedKeys: false,
                models: ["NUMS-Game"],
                historical: false
            )
            
            let pageEntity = try client.entities(query: query)
            
            // Parse the game model
            if let entity = pageEntity.items.first {
                if let parsedGame = parseGameModel(from: entity, gameId: gameId) {
                    print("✅ Game model loaded for #\(gameId)")
                    print("   Score: \(parsedGame.score), Number: \(parsedGame.number), Next: \(parsedGame.nextNumber)")
                    print("   Set slots: \(parsedGame.setSlots)")
                    
                    // Store in gameModels dictionary so onChange triggers
                    await MainActor.run {
                        self.gameModels[parsedGame.id] = parsedGame
                    }
                    
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
                
                // Return the game model (already filtered by query)
                print("   ✅ Found game: tokenId=\(tokenId)")
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
        
        return nil
    }
    
    func startGame(gameId: String, tournamentId: Int, sessionManager: SessionManager) async throws {
        print("🎮 Starting game #\(gameId)")
        
        guard let session = sessionManager.sessionAccount else {
            print("❌ No session account available")
            throw NSError(domain: "DojoManager", code: 1, userInfo: [NSLocalizedDescriptionKey: "No active session. Please reconnect your wallet."])
        }
        
        // Game ID should already be a hex string (e.g., "0x4c")
        let gameIdFelt = gameId
        
        print("   🎲 Game ID: \(gameIdFelt)")
        
        // Multi-call: VRF request_random + game start
        let vrfCall = Call(
            contractAddress: Constants.vrfAddress,
            entrypoint: "request_random",
            calldata: [
                Constants.gameAddress,  // caller: the game contract
                "0x0",                  // source type: 0 = Nonce
                Constants.gameAddress   // source data: game contract address for Nonce
            ]
        )
        
        let startCall = Call(
            contractAddress: Constants.gameAddress,
            entrypoint: "start",
            calldata: [gameIdFelt]  // Only game ID
        )
        
        do {
            let txHash = try session.executeFromOutside(calls: [vrfCall, startCall])
            print("✅ Game started! Transaction: \(txHash)")
            
            // Subscribe to the game for real-time updates
            await subscribeToGame(gameId)
        } catch {
            print("❌ Failed to start game: \(error)")
            let errorMessage = extractErrorMessage(from: error)
            throw NSError(domain: "DojoManager", code: 2, userInfo: [NSLocalizedDescriptionKey: errorMessage])
        }
    }
    
    // Buy a new game (approve + buy + request_random + start)
    func buyGame(username: String, tournamentId: UInt64, sessionManager: SessionManager) async throws -> String {
        print("🛒 Buying new game for username: \(username)")
        
        guard let session = sessionManager.sessionAccount else {
            print("❌ No session account available")
            throw NSError(domain: "DojoManager", code: 1, userInfo: [NSLocalizedDescriptionKey: "No active session. Please reconnect your wallet."])
        }
        
        // Convert username to felt252
        let usernameFelt = try shortStringToFelt(username)
        let tournamentIdFelt = String(format: "0x%llx", tournamentId)
        
        // Use constants for game cost
        let approvalAmountLow = Constants.gameCostHexLow
        let approvalAmountHigh = Constants.gameCostHexHigh
        
        print("   💰 Approving \(Constants.gameCostNums) NUMS tokens")
        print("   🏆 Tournament ID: \(tournamentIdFelt)")
        
        // Step 1: Approve NUMS tokens for game contract
        let approveCall = Call(
            contractAddress: Constants.numsAddress,
            entrypoint: "approve",
            calldata: [
                Constants.gameAddress,  // spender
                approvalAmountLow,      // amount.low
                approvalAmountHigh      // amount.high
            ]
        )
        
        // Step 2: Buy the game
        let buyCall = Call(
            contractAddress: Constants.gameAddress,
            entrypoint: "buy",
            calldata: [usernameFelt]
        )
        
        // Execute approve + buy
        print("   📝 Submitting approve + buy transaction...")
        do {
            let txHash = try session.executeFromOutside(calls: [approveCall, buyCall])
            print("✅ Game purchased! Transaction: \(txHash)")
            
            // Wait a moment for the transaction to be processed
            try await Task.sleep(nanoseconds: 2_000_000_000) // 2 seconds
            
            // Fetch the newly created game token for this user
            print("   🔍 Fetching new game token...")
            let accountAddress = session.address()
            await fetchUserGames(for: accountAddress)
            
            // Find the most recent game token (highest ID by comparing hex strings as numbers)
            let sortedGames = games.sorted { game1, game2 in
                let id1 = UInt64(game1.tokenId.dropFirst(2), radix: 16) ?? 0
                let id2 = UInt64(game2.tokenId.dropFirst(2), radix: 16) ?? 0
                return id1 > id2
            }
            
            guard let latestGame = sortedGames.first else {
                throw NSError(domain: "DojoManager", code: 3, userInfo: [NSLocalizedDescriptionKey: "Failed to find newly created game"])
            }
            
            let latestGameId = latestGame.tokenId
            
            print("   🎮 New game ID: \(latestGameId)")
            
            // Step 3: Request random + start the game
            let gameIdFelt = latestGameId
            
            let vrfCall = Call(
                contractAddress: Constants.vrfAddress,
                entrypoint: "request_random",
                calldata: [
                    Constants.gameAddress,  // caller: the game contract
                    "0x0",                  // source type: 0 = Nonce
                    Constants.gameAddress   // source data: game contract address for Nonce
                ]
            )
            
            let startCall = Call(
                contractAddress: Constants.gameAddress,
                entrypoint: "start",
                calldata: [gameIdFelt]
            )
            
            print("   🎲 Starting game with random number...")
            let startTxHash = try session.executeFromOutside(calls: [vrfCall, startCall])
            print("✅ Game started! Transaction: \(startTxHash)")
            
            // Subscribe to the new game
            await subscribeToGame(latestGameId)
            
            return latestGameId
            
        } catch {
            print("❌ Failed to buy game: \(error)")
            let errorMessage = extractErrorMessage(from: error)
            throw NSError(domain: "DojoManager", code: 3, userInfo: [NSLocalizedDescriptionKey: errorMessage])
        }
    }
    
    // Helper to convert short string to felt252
    private func shortStringToFelt(_ string: String) throws -> String {
        // Convert ASCII string to felt252 (Cairo short string)
        var felt: UInt64 = 0
        for char in string.prefix(31) {  // Max 31 characters
            felt = felt * 256 + UInt64(char.asciiValue ?? 0)
        }
        return String(format: "0x%llx", felt)
    }
    
    func setGameSlot(gameId: String, slot: UInt8, sessionManager: SessionManager) async throws {
        print("🎮 Setting slot #\(slot) for game #\(gameId)")
        
        // Get the game model to know the slot min/max range
        guard let gameModel = gameModels[gameId] else {
            print("❌ Game model not found for game #\(gameId)")
            throw NSError(domain: "DojoManager", code: 1, userInfo: [NSLocalizedDescriptionKey: "Game not found"])
        }
        
        // Game ID is already a hex string, use it directly
        let gameIdFelt = gameId
        let slotIndex = String(format: "0x%x", slot - 1) // Convert to 0-based index
        
        print("   🎲 Game ID: \(gameIdFelt)")
        print("   🎯 Slot index (0-based): \(slotIndex)")
        
        // Multi-call: VRF request_random + game set
        guard let session = sessionManager.sessionAccount else {
            print("❌ No session account available")
            throw NSError(domain: "DojoManager", code: 2, userInfo: [NSLocalizedDescriptionKey: "No active session. Please reconnect your wallet."])
        }
        
        // Create both calls
        // VRF request_random(caller: ContractAddress, source: Source)
        // Source enum: Nonce(ContractAddress) = type 0, Salt(felt252) = type 1
        // Using Source::Nonce with game contract address (matching JS example)
        let vrfCall = Call(
            contractAddress: Constants.vrfAddress,
            entrypoint: "request_random",
            calldata: [
                Constants.gameAddress,  // caller: the game contract
                "0x0",                  // source type: 0 = Nonce
                Constants.gameAddress   // source data: game contract address for Nonce
            ]
        )
        
        // Game set takes game ID and slot index (0-based)
        let setCall = Call(
            contractAddress: Constants.gameAddress,
            entrypoint: "set",
            calldata: [gameIdFelt, slotIndex]
        )
        
        // Execute multi-call
        do {
            let txHash = try session.executeFromOutside(calls: [vrfCall, setCall])
            print("✅ Slot set transaction submitted: \(txHash)")
            print("💡 Game state will update via subscription")
        } catch {
            print("❌ Failed to set slot: \(error)")
            // Extract a user-friendly error message
            let errorMessage = extractErrorMessage(from: error)
            throw NSError(domain: "DojoManager", code: 3, userInfo: [NSLocalizedDescriptionKey: errorMessage])
        }
    }
    
    // Helper to extract user-friendly error messages
    private func extractErrorMessage(from error: Error) -> String {
        let errorDescription = error.localizedDescription
        
        // Check for common error patterns
        if errorDescription.contains("invalid number of arguments") {
            return "Transaction failed: Invalid parameters sent to contract"
        } else if errorDescription.contains("UnexpectedError") {
            return "Transaction failed: Contract error occurred"
        } else if errorDescription.contains("ExecutionError") {
            return "Transaction failed: Execution error"
        } else if errorDescription.contains("VRF") {
            return "Random number generation failed. Please try again."
        } else {
            return "Failed to set slot: \(errorDescription)"
        }
    }
    
    // MARK: - User Games
    
    func fetchUserGames(for accountAddress: String) async {
        guard let client = toriiClient else {
            print("⚠️ Torii client not initialized")
            return
        }
        
        guard !accountAddress.isEmpty else {
            print("⚠️ Invalid account address")
            return
        }
        
        await MainActor.run {
            self.isLoadingGames = true
        }
        
        do {
            print("🎮 Fetching games for user: \(accountAddress)...")
            
            // Query for game tokens owned by this user
            let tokenBalanceQuery = TokenBalanceQuery(
                contractAddresses: [Constants.denshokanAddress],
                accountAddresses: [accountAddress],
                tokenIds: [],
                pagination: Pagination(
                    cursor: nil,
                    limit: 100,
                    direction: .forward,
                    orderBy: []
                )
            )
            
            let tokenBalances = try client.tokenBalances(query: tokenBalanceQuery)
            
            print("📦 Found \(tokenBalances.items.count) token balances for user")
            
            // Extract token IDs from balances
            let tokenIds = tokenBalances.items.compactMap { $0.tokenId }
            
            if tokenIds.isEmpty {
                print("ℹ️ No game tokens found for user")
                await MainActor.run {
                    self.games = []
                    self.isLoadingGames = false
                }
                return
            }
            
            // Now fetch the actual tokens with their attributes to filter by "Minted By"
            let tokenQuery = TokenQuery(
                contractAddresses: [Constants.denshokanAddress],
                tokenIds: tokenIds,
                attributeFilters: [
                    AttributeFilter(
                        traitName: "Minted By",
                        traitValue: Constants.gameAddress
                    )
                ],
                pagination: Pagination(
                    cursor: nil,
                    limit: 100,
                    direction: .forward,
                    orderBy: []
                )
            )
            
            let tokens = try client.tokens(query: tokenQuery)
            
            print("🎮 Found \(tokens.items.count) game tokens minted by game contract")
            
            // Build Game objects
            let games = tokens.items.compactMap { token -> Game? in
                guard let tokenId = token.tokenId else { return nil }
                
                return Game(
                    id: tokenId,
                    tokenId: tokenId,
                    contractAddress: token.contractAddress,
                    balance: "1",
                    accountAddress: accountAddress
                )
            }
            
            await MainActor.run {
                self.games = games
                self.isLoadingGames = false
                print("✅ User games loaded: \(games.count) games")
            }
            
            // Now fetch game models for each token
            if !games.isEmpty {
                await fetchGameModelsForUser(games: games)
            }
            
        } catch {
            await MainActor.run {
                self.errorMessage = "Failed to fetch games: \(error.localizedDescription)"
                self.isLoadingGames = false
                print("❌ Games fetch error: \(error)")
            }
        }
    }
    
    private func fetchGameModelsForUser(games: [Game]) async {
        print("🎮 Fetching game models for \(games.count) games...")
        
        // Fetch each game model using the improved fetchGameModel function
        for game in games {
            _ = await fetchGameModel(gameId: game.tokenId)
        }
        
        let modelCount = await MainActor.run { self.gameModels.count }
        print("✅ Game models fetched: \(modelCount) models")
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


