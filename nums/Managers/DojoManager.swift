import Foundation
import Combine

// MARK: - Token Balance Callback

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

// Player Leaderboard Model (aggregated games by player)
struct PlayerLeaderboard: Identifiable {
    let id: String // address
    let address: String
    let username: String?
    let gameCount: Int
    let games: [Game]
}

// Game Model (NUMS-Game entity)
struct GameModel: Identifiable {
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
    
    // Computed property to extract set slots from the felt252 encoded slots
    var setSlots: Set<Int> {
        // Parse the base64-encoded slots data
        // For now, we'll return empty and implement parsing later
        // The slots field is a felt252 (base64) that encodes which slots are set
        return parseSlots(from: slots)
    }
    
    private func parseSlots(from felt252: String) -> Set<Int> {
        // Decode base64 to bytes
        guard let data = Data(base64Encoded: felt252) else {
            return []
        }
        
        // The slots are stored as a bitfield
        // Each bit represents whether a slot is set (1) or not (0)
        var setSlots: Set<Int> = []
        
        for (byteIndex, byte) in data.enumerated() {
            for bitIndex in 0..<8 {
                if (byte & (1 << bitIndex)) != 0 {
                    let slotNumber = byteIndex * 8 + bitIndex + 1
                    if slotNumber <= slotCount {
                        setSlots.insert(slotNumber)
                    }
                }
            }
        }
        
        return setSlots
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
    @Published var isLoadingLeaderboard = false
    @Published var showTournamentSelector = false
    
    // Token Balance
    @Published var tokenBalance: BInt = 0
    @Published var isLoadingBalance = false
    
    // Games
    @Published var games: [Game] = []
    @Published var isLoadingGames = false
    
    // Player Leaderboard (aggregated by player)
    @Published var playerLeaderboard: [PlayerLeaderboard] = []
    @Published var isLoadingPlayerLeaderboard = false
    
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
            
            // Fetch all games for player leaderboard
            await fetchAllGames()
            
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
    
    func fetchGames(for accountAddress: String) async {
        // Validate that we have a proper address before fetching
        guard !accountAddress.isEmpty, accountAddress.hasPrefix("0x") else {
            print("⚠️ Invalid account address: \(accountAddress)")
            await MainActor.run {
                self.games = []
            }
            return
        }
        
        guard let client = toriiClient else {
            print("⚠️ Torii client not initialized")
            return
        }
        
        await MainActor.run {
            self.isLoadingGames = true
        }
        
        do {
            print("🎮 Fetching games for \(accountAddress)...")
            
            // Step 1: Fetch all token balances for the account to get token IDs with non-zero balance
            let balanceQuery = TokenBalanceQuery(
                contractAddresses: [], // Fetch all contracts
                accountAddresses: [accountAddress],
                tokenIds: [],
                pagination: Pagination(
                    cursor: nil,
                    limit: 100, // Fetch up to 100 tokens
                    direction: .forward,
                    orderBy: []
                )
            )
            
            let balancesPage = try client.tokenBalances(query: balanceQuery)
            print("📦 Found \(balancesPage.items.count) tokens owned by account")
            
            // Filter tokens with non-zero balance
            var tokenIdsToCheck: [U256] = []
            var tokenBalanceMap: [String: TokenBalance] = [:]
            
            for tokenBalance in balancesPage.items {
                // Unwrap optional tokenId
                guard let tokenId = tokenBalance.tokenId else { continue }
                
                let balanceString = tokenBalance.balance.hasPrefix("0x") ?
                    String(tokenBalance.balance.dropFirst(2)) : tokenBalance.balance
                if let balance = BInt(balanceString, radix: 16) ?? BInt(balanceString, radix: 10),
                   balance > 0 {
                    tokenIdsToCheck.append(tokenId)
                    tokenBalanceMap[tokenId] = tokenBalance
                }
            }
            
            print("📊 Checking \(tokenIdsToCheck.count) tokens with non-zero balance")
            
            // Step 2: Query tokens with attribute filter for "Minted By" = game contract address
            guard !tokenIdsToCheck.isEmpty else {
                await MainActor.run {
                    self.games = []
                    self.isLoadingGames = false
                    print("✅ No tokens found")
                }
                return
            }
            
            // Create attribute filter for "Minted By" trait
            let mintedByFilter = AttributeFilter(
                traitName: "Minted By",
                traitValue: gameTokenMintAddress
            )
            
            let tokenQuery = TokenQuery(
                contractAddresses: [], // Check all contracts
                tokenIds: tokenIdsToCheck, // Only check tokens we own
                attributeFilters: [mintedByFilter], // Filter by "Minted By" attribute
                pagination: Pagination(
                    cursor: nil,
                    limit: 100,
                    direction: .forward,
                    orderBy: []
                )
            )
            
            let tokensPage = try client.tokens(query: tokenQuery)
            
            // Step 3: Convert matching tokens to Game objects
            var fetchedGames: [Game] = []
            for token in tokensPage.items {
                // Unwrap optional tokenId
                guard let tokenId = token.tokenId else { continue }
                
                if let tokenBalance = tokenBalanceMap[tokenId] {
                    let game = Game(
                        id: tokenId,
                        tokenId: tokenId,
                        contractAddress: token.contractAddress,
                        balance: tokenBalance.balance,
                        accountAddress: tokenBalance.accountAddress
                    )
                    fetchedGames.append(game)
                    print("✅ Found game token: \(tokenId) owned by \(tokenBalance.accountAddress)")
                }
            }
            
            await MainActor.run {
                self.games = fetchedGames
                self.isLoadingGames = false
                print("✅ Games loaded: \(self.games.count) games")
            }
            
            // Step 4: Aggregate games by player and fetch usernames
            await aggregatePlayerLeaderboard(from: fetchedGames)
            
            // Step 5: Fetch NUMS-Game models for each game token
            await fetchGameModels(for: fetchedGames)
        } catch {
            await MainActor.run {
                self.errorMessage = "Failed to fetch games: \(error.localizedDescription)"
                self.isLoadingGames = false
                self.games = []
                print("❌ Games fetch error: \(error)")
            }
        }
    }
    
    func fetchAllGames() async {
        guard let client = toriiClient else {
            print("⚠️ Torii client not initialized")
            return
        }
        
        await MainActor.run {
            self.isLoadingGames = true
        }
        
        do {
            print("🎮 Fetching all games for leaderboard...")
            print("🔍 Using 'Minted By' filter with address: \(gameTokenMintAddress)")
            
            // Step 1: Query all tokens with the "Minted By" attribute filter
            let mintedByFilter = AttributeFilter(
                traitName: "Minted By",
                traitValue: gameTokenMintAddress
            )
            
            let tokenQuery = TokenQuery(
                contractAddresses: [], // Check all contracts
                tokenIds: [], // Get all token IDs
                attributeFilters: [mintedByFilter], // Filter by "Minted By" attribute
                pagination: Pagination(
                    cursor: nil,
                    limit: 1000, // Fetch up to 1000 tokens for leaderboard
                    direction: .forward,
                    orderBy: []
                )
            )
            
            print("🔍 Querying tokens...")
            let tokensPage = try client.tokens(query: tokenQuery)
            print("📦 Found \(tokensPage.items.count) game tokens")
            
            // Debug: If no tokens found, try without filter
            if tokensPage.items.isEmpty {
                print("⚠️ No tokens found with 'Minted By' filter")
                print("🔍 Trying to fetch ALL tokens to debug...")
                let debugQuery = TokenQuery(
                    contractAddresses: [],
                    tokenIds: [],
                    attributeFilters: [],
                    pagination: Pagination(
                        cursor: nil,
                        limit: 10,
                        direction: .forward,
                        orderBy: []
                    )
                )
                let debugTokensPage = try client.tokens(query: debugQuery)
                print("📦 Total tokens in system (first 10): \(debugTokensPage.items.count)")
                
                if !debugTokensPage.items.isEmpty {
                    print("📋 Sample token attributes:")
                    for (index, token) in debugTokensPage.items.prefix(3).enumerated() {
                        print("  Token \(index + 1): \(token.tokenId ?? "N/A")")
                        print("    Contract: \(token.contractAddress)")
                        print("    Metadata: \(token.metadata)")
                    }
                }
            }
            
            // Step 2: Get token IDs and fetch their balances
            var tokenIds: [U256] = []
            for token in tokensPage.items {
                if let tokenId = token.tokenId {
                    tokenIds.append(tokenId)
                }
            }
            
            guard !tokenIds.isEmpty else {
                await MainActor.run {
                    self.games = []
                    self.isLoadingGames = false
                    print("✅ No game tokens found")
                }
                return
            }
            
            // Step 3: Fetch balances for all these tokens
            let balanceQuery = TokenBalanceQuery(
                contractAddresses: [],
                accountAddresses: [], // Fetch for all accounts
                tokenIds: tokenIds,
                pagination: Pagination(
                    cursor: nil,
                    limit: 1000,
                    direction: .forward,
                    orderBy: []
                )
            )
            
            let balancesPage = try client.tokenBalances(query: balanceQuery)
            print("📦 Found \(balancesPage.items.count) token balances")
            
            // Step 4: Build games list from balances
            var fetchedGames: [Game] = []
            for tokenBalance in balancesPage.items {
                guard let tokenId = tokenBalance.tokenId else { continue }
                
                // Check if balance is non-zero
                let balanceString = tokenBalance.balance.hasPrefix("0x") ?
                    String(tokenBalance.balance.dropFirst(2)) : tokenBalance.balance
                if let balance = BInt(balanceString, radix: 16) ?? BInt(balanceString, radix: 10),
                   balance > 0 {
                    
                    let game = Game(
                        id: tokenId,
                        tokenId: tokenId,
                        contractAddress: tokenBalance.contractAddress,
                        balance: tokenBalance.balance,
                        accountAddress: tokenBalance.accountAddress
                    )
                    fetchedGames.append(game)
                    print("✅ Found game token: \(tokenId) owned by \(tokenBalance.accountAddress)")
                }
            }
            
            await MainActor.run {
                self.games = fetchedGames
                self.isLoadingGames = false
                print("✅ All games loaded: \(self.games.count) games")
            }
            
            // Step 5: Aggregate games by player and fetch usernames
            await aggregatePlayerLeaderboard(from: fetchedGames)
            
            // Step 6: Fetch NUMS-Game models for each game token
            await fetchGameModels(for: fetchedGames)
        } catch {
            await MainActor.run {
                self.errorMessage = "Failed to fetch all games: \(error.localizedDescription)"
                self.isLoadingGames = false
                self.games = []
                print("❌ All games fetch error: \(error)")
            }
        }
    }
    
    func fetchGameModels(for games: [Game]) async {
        guard let client = toriiClient else {
            print("⚠️ Torii client not initialized")
            return
        }
        
        guard !games.isEmpty else {
            print("⚠️ No games to fetch models for")
            return
        }
        
        await MainActor.run {
            self.isLoadingGameModels = true
        }
        
        do {
            print("🎮 Fetching NUMS-Game models for \(games.count) games...")
            
            // Query NUMS-Game entities for all token IDs
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
                models: ["NUMS-Game"],
                historical: false
            )
            
            let entitiesPage = try client.entities(query: query)
            print("📦 Found \(entitiesPage.items.count) NUMS-Game entities")
            
            // Parse game models and map by token ID
            var modelsMap: [String: GameModel] = [:]
            for entity in entitiesPage.items {
                // Try to parse each entity (parseGameModel will check if ID matches games we're looking for)
                for game in games {
                    if let gameModel = parseGameModel(from: entity, gameId: game.tokenId) {
                        modelsMap[game.tokenId] = gameModel
                        print("✅ Found game model for token: \(game.tokenId)")
                        break // Found this game's model, move to next entity
                    }
                }
            }
            
            await MainActor.run {
                self.gameModels = modelsMap
                self.isLoadingGameModels = false
                print("✅ Game models loaded: \(modelsMap.count) models")
            }
        } catch {
            await MainActor.run {
                self.errorMessage = "Failed to fetch game models: \(error.localizedDescription)"
                self.isLoadingGameModels = false
                self.gameModels = [:]
                print("❌ Game models fetch error: \(error)")
            }
        }
    }
    
    private func aggregatePlayerLeaderboard(from games: [Game]) async {
        guard let client = toriiClient else {
            print("⚠️ Torii client not initialized")
            return
        }
        
        await MainActor.run {
            self.isLoadingPlayerLeaderboard = true
        }
        
        do {
            print("👥 Aggregating player leaderboard from \(games.count) games...")
            
            // Step 1: Group games by player address
            var gamesByPlayer: [String: [Game]] = [:]
            for game in games {
                if gamesByPlayer[game.accountAddress] == nil {
                    gamesByPlayer[game.accountAddress] = []
                }
                gamesByPlayer[game.accountAddress]?.append(game)
            }
            
            print("📊 Found \(gamesByPlayer.count) unique players")
            
            // Step 2: Fetch controller usernames for all player addresses
            let playerAddresses = Array(gamesByPlayer.keys)
            
            let controllerQuery = ControllerQuery(
                pagination: Pagination(
                    cursor: nil,
                    limit: 100,
                    direction: .forward,
                    orderBy: []
                ),
                contractAddresses: playerAddresses,
                usernames: []
            )
            
            let controllersPage = try client.controllers(query: controllerQuery)
            print("🎮 Fetched \(controllersPage.items.count) controllers")
            
            // Step 3: Create username lookup map
            var usernameMap: [String: String] = [:]
            for controller in controllersPage.items {
                usernameMap[controller.address] = controller.username
            }
            
            // Step 4: Build player leaderboard
            var leaderboard: [PlayerLeaderboard] = []
            for (address, playerGames) in gamesByPlayer {
                let player = PlayerLeaderboard(
                    id: address,
                    address: address,
                    username: usernameMap[address],
                    gameCount: playerGames.count,
                    games: playerGames
                )
                leaderboard.append(player)
                
                if let username = player.username {
                    print("✅ Player: \(username) (\(address)) - \(player.gameCount) games")
                } else {
                    print("✅ Player: \(address) (no username) - \(player.gameCount) games")
                }
            }
            
            // Sort by game count (descending)
            leaderboard.sort { $0.gameCount > $1.gameCount }
            
            await MainActor.run {
                self.playerLeaderboard = leaderboard
                self.isLoadingPlayerLeaderboard = false
                print("✅ Player leaderboard loaded: \(leaderboard.count) players")
            }
        } catch {
            await MainActor.run {
                self.errorMessage = "Failed to aggregate player leaderboard: \(error.localizedDescription)"
                self.isLoadingPlayerLeaderboard = false
                self.playerLeaderboard = []
                print("❌ Player leaderboard aggregation error: \(error)")
            }
        }
    }
    
    private func parseTournament(from entity: Entity) -> Tournament? {
        // Parse tournament entity
        let models = entity.models
        
        guard let id = extractInt(from: models, key: "id") else { return nil }
        let powers = extractInt(from: models, key: "powers") ?? 0
        let entryCount = extractInt(from: models, key: "entry_count") ?? 0
        
        // Extract timestamps as UInt64
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
        let slotFelt = String(format: "0x%x", slot)
        
        // Multi-call: VRF request_random + game set
        guard let session = sessionManager.sessionAccount else {
            print("❌ No session account available")
            return
        }
        
        do {
            // Create both calls
            let vrfCall = Call(
                contractAddress: Constants.vrfAddress,
                entrypoint: "request_random",
                calldata: [gameIdFelt, "0x1"] // game_id, num_words (1)
            )
            
            let setCall = Call(
                contractAddress: Constants.gameAddress,
                entrypoint: "set",
                calldata: [gameIdFelt, slotFelt] // game_id, slot
            )
            
            // Execute multi-call
            let txHash = try session.executeFromOutside(calls: [vrfCall, setCall])
            
            print("✅ Slot set transaction submitted: \(txHash)")
            print("💡 Game state will update via subscription")
            
        } catch {
            print("❌ Failed to set slot: \(error.localizedDescription)")
        }
    }
    
}


