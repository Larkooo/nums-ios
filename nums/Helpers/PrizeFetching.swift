//
//  PrizeFetching.swift
//  nums
//
//  Prize fetching logic to be added to DojoManager
//

import Foundation

/*
 ADD TO DOJO MANAGER CLASS:
 
 // Prizes
 @Published var prizes: [Int: [Prize]] = [:] // Map: tournamentId -> [Prize]
 @Published var isLoadingPrizes = false
 
 
 // Function to fetch prizes for all tournaments
 @MainActor
 func fetchPrizesForTournaments() async {
     guard let client = toriiClient else {
         print("❌ Torii client not initialized")
         return
     }
     
     isLoadingPrizes = true
     print("🏆 Fetching prizes for all tournaments...")
     
     do {
         // Query all NUMS-Prize entities
         let query = Query(
             clause: MemberClause(
                 model: "NUMS-Prize",
                 member: "tournament_id",
                 operator: .gte,
                 value: MemberValue.int(num: 0)
             ),
             limit: 1000,
             offset: 0
         )
         
         let entities = try client.getEntities(query: query)
         print("   Found \(entities.count) prize entities")
         
         var newPrizes: [Int: [Prize]] = [:]
         
         for entity in entities {
             // Parse prize entity
             if let prize = parsePrize(entity: entity) {
                 if newPrizes[prize.tournamentId] == nil {
                     newPrizes[prize.tournamentId] = []
                 }
                 newPrizes[prize.tournamentId]?.append(prize)
             }
         }
         
         await MainActor.run {
             self.prizes = newPrizes
             self.isLoadingPrizes = false
             print("✅ Loaded prizes for \(newPrizes.count) tournaments")
         }
     } catch {
         await MainActor.run {
             self.isLoadingPrizes = false
         }
         print("❌ Failed to fetch prizes: \(error)")
     }
 }
 
 // Helper to parse Prize entity
 private func parsePrize(entity: Entity) -> Prize? {
     guard let model = entity.models.first else {
         return nil
     }
     
     var tournamentId: Int?
     var address: String?
     var amount: String?
     
     // Parse children
     for child in model.children {
         switch child.name {
         case "tournament_id":
             if case .primitive(let primitive) = child.ty,
                case .u16(let value) = primitive {
                 tournamentId = Int(value)
             }
         case "address":
             if case .primitive(let primitive) = child.ty,
                case .felt252(let data) = primitive {
                 // Convert Data to hex string
                 let hexString = "0x" + data.map { String(format: "%02x", $0) }.joined()
                 address = hexString
             }
         case "amount":
             if case .primitive(let primitive) = child.ty,
                case .u128(let data) = primitive {
                 // Convert Data to hex string
                 let hexString = "0x" + data.map { String(format: "%02x", $0) }.joined()
                 amount = hexString
             }
         default:
             break
         }
     }
     
     guard let tid = tournamentId,
           let addr = address,
           let amt = amount else {
         print("⚠️ Incomplete prize data")
         return nil
     }
     
     return Prize(
         id: "\(tid)-\(addr)",
         tournamentId: tid,
         address: addr,
         amount: amt
     )
 }
 
 // Call this in initializeToriiClient after fetching tournaments:
 Task {
     await self.fetchTournamentsSQL()
     await self.fetchPrizesForTournaments() // Add this line
     await self.fetchLeaderboardSQL()
 }
*/


