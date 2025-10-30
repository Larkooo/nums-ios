import Foundation

enum ArgumentType: String, CaseIterable, Identifiable {
    case feltArray = "Felt Array"
    case address = "Address"
    case u256 = "U256"
    case felt = "Felt"
    
    var id: String { rawValue }
    
    var placeholder: String {
        switch self {
        case .feltArray:
            return "0x1,0x2,0x3"
        case .address:
            return "0x1234..."
        case .u256:
            return "amount (low,high)"
        case .felt:
            return "0x1234..."
        }
    }
    
    var description: String {
        switch self {
        case .feltArray:
            return "Comma-separated felt values"
        case .address:
            return "Starknet address"
        case .u256:
            return "U256 value (low, high)"
        case .felt:
            return "Single felt value"
        }
    }
}




