import Foundation
import Combine

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
    let id: String // token_id
    let tokenId: String
    let score: Int?
    let state: String?
    // Add more fields as needed from NUMS-Game model
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
    
    // Games
    @Published var games: [Game] = []
    @Published var isLoadingGames = false
    
    // Player Leaderboard (aggregated by player)
    @Published var playerLeaderboard: [PlayerLeaderboard] = []
    @Published var isLoadingPlayerLeaderboard = false
    
    // Game Models (NUMS-Game entities mapped by token ID)
    @Published var gameModels: [String: GameModel] = [:]
    @Published var isLoadingGameModels = false
    
    private let tokenContractAddress = "0xe69b167a18be231ef14ca474e29cf6356333038162077b551a17d25d166af" // Nums
    private let gameContractAddress = "0x277902ea7ce3bbdc25304f3cf1caaed7b6f22d722a8b16827ce11fd5fcb8ac6" // Game contract
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
                traitValue: gameContractAddress
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
            
            // Step 1: Query all tokens with the "Minted By" attribute filter
            let mintedByFilter = AttributeFilter(
                traitName: "Minted By",
                traitValue: gameContractAddress
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
            
            let tokensPage = try client.tokens(query: tokenQuery)
            print("📦 Found \(tokensPage.items.count) game tokens")
            
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
                if let gameModel = parseGameModel(from: entity) {
                    modelsMap[gameModel.tokenId] = gameModel
                    print("✅ Found game model for token: \(gameModel.tokenId)")
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
    
    private func parseGameModel(from entity: Entity) -> GameModel? {
        // Parse NUMS-Game entity
        let models = entity.models
        
        // Extract token_id - this is the key field to match with Game.tokenId
        guard let tokenIdString = extractString(from: models, key: "token_id") else {
            print("⚠️ Game entity missing token_id")
            return nil
        }
        
        let score = extractInt(from: models, key: "score")
        let state = extractString(from: models, key: "state")
        
        return GameModel(
            id: tokenIdString,
            tokenId: tokenIdString,
            score: score,
            state: state
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


