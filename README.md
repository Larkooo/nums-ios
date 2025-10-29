# Nums - iOS Game

A competitive blockchain-powered game built with SwiftUI, leveraging the Dojo engine and Cartridge Controller for on-chain gaming.

## Features

- 🏆 **Tournament System**: Compete in multiple tournaments with real-time leaderboards
- 🎮 **Session Management**: Seamless authentication via Cartridge Controller
- 💰 **Token Integration**: NUMS token balance tracking and updates
- 📊 **Real-time Updates**: Live tournament and leaderboard data via Torii
- 🔐 **Secure Sessions**: WebAuthn-based passwordless authentication

## Technologies

- **SwiftUI**: Modern iOS UI framework
- **Dojo Engine**: On-chain gaming framework
- **Cartridge Controller**: Session and account management
- **Torii**: Real-time data synchronization
- **Starknet**: Blockchain infrastructure

## Architecture

```
nums/
├── Managers/
│   ├── DojoManager.swift       # Dojo/Torii client management
│   └── SessionManager.swift    # Session & authentication
├── Views/
│   ├── MainView.swift          # Main game interface
│   ├── SetupView.swift         # Session setup
│   ├── SessionInfoSheet.swift  # Session details
│   ├── TournamentSelectorSheet.swift
│   ├── AccountConnectedSheet.swift
│   └── SafariView.swift        # In-app browser
├── Math/
│   └── BInt.swift              # Arbitrary precision integers
└── Assets.xcassets/
```

## Requirements

- iOS 15.0+
- Xcode 14.0+
- Swift 5.5+

## Setup

1. Clone the repository
2. Open `nums.xcodeproj` in Xcode
3. Build and run on simulator or device

## Configuration

The app connects to:
- **RPC**: `https://api.cartridge.gg/x/starknet/sepolia`
- **Torii**: `https://api.cartridge.gg/x/nums-bal/torii`
- **Controller**: `https://x.cartridge.gg`

## Game Flow

1. **Connect**: Authenticate using Cartridge Controller
2. **Select Tournament**: Browse and join active tournaments
3. **Play**: Compete and climb the leaderboard
4. **Track**: Monitor your NUMS token balance and session

## Models

### Tournament
- ID, Powers, Entry Count
- Start/End times
- Active status

### Leaderboard
- Player rankings per tournament
- Capacity, Requirement, Games
- Real-time updates

## License

[Add your license here]

## Contact

[Add your contact information here]

