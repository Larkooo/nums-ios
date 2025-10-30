//
//  Constants.swift
//  Game and blockchain constants
//

import Foundation

struct Constants {
    // MARK: - Blockchain Configuration
    
    static let rpcUrl = "https://api.cartridge.gg/x/starknet/sepolia"
    static let cartridgeApiUrl = "https://api.cartridge.gg"
    static let keychainUrl = "https://x.cartridge.gg"
    
    // MARK: - Contract Addresses
    
    // VRF (Verifiable Random Function) Contract
    static let vrfAddress = "0x051fea4450da9d6aee758bdeba88b2f665bcbf549d2c61421aa724e9ac0ced8f"
    
    // NUMS Token Contract
    static let numsAddress = "0x0e69b167a18be231ef14ca474e29cf6356333038162077b551a17d25d166af"
    
    // Game Contract (for session policies - start/set methods AND "Minted By" filter)
    // This contract mints game tokens and handles game logic
    static let gameAddress = "0x277902ea7ce3bbdc25304f3cf1caaed7b6f22d722a8b16827ce11fd5fcb8ac6"
    
    // Denshokan Contract (ERC721-like tokens representing individual games)
    static let denshokanAddress = "0x02334dc9c950c74c3228e2a343d495ae36f0b4edf06767a679569e9f9de08776"
    
    // MARK: - Common Token Contracts (for reference)
    
    static let ethTokenAddress = "0x049d36570d4e46f48e99674bd3fcc84644ddd6b96f7c741b1562b82f9e004dc7"
    static let strkTokenAddress = "0x04718f5a0fc34cc1af16a1cdee98ffb20c31f5cd61d6ab07201858f4287c938d"
    
    // MARK: - Dojo Configuration
    
    static let toriiUrl = "https://api.cartridge.gg/x/nums-bal/torii"
    static let worldAddress = "0x04aebc039a9beb576533eca4075bacdc037b3c7160de6ed1e2e1a3005129a29e"
    static let namespace = "NUMS"
    
    // MARK: - Game Configuration
    
    // Cost to buy a new game in NUMS tokens (without decimals)
    static let gameCostNums: UInt64 = 2000
    // Hex representation of 2000 * 10^18 = 0x6C6B935B8BBD400000
    static let gameCostHexLow = "0x6C6B935B8BBD400000"
    static let gameCostHexHigh = "0x0"
    
    // MARK: - Session Policies
    
    struct SessionPolicyConfig {
        let contractAddress: String
        let methods: [String]
    }
    
    static let defaultSessionPolicies: [SessionPolicyConfig] = [
        // VRF Contract
        SessionPolicyConfig(
            contractAddress: vrfAddress,
            methods: ["request_random"]
        ),
        // NUMS Token Contract
        SessionPolicyConfig(
            contractAddress: numsAddress,
            methods: ["approve", "mint"]
        ),
        // Game Contract
        SessionPolicyConfig(
            contractAddress: gameAddress,
            methods: ["buy", "start", "set"]
        )
    ]
}

