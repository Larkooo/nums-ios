# ✅ Files Migrated to Nums!

## What's Been Done

I've copied the core files to your `nums` project:

### ✅ Already in `nums/nums/`:
- `Managers/DojoManager.swift`
- `Managers/SessionManager.swift`
- `Models/ArgumentType.swift`
- `ContentView.swift` (updated for Dojo + Controller)
- `numsApp.swift` (updated with manager initialization)
- `nums-Bridging-Header.h` (imports both frameworks)
- `nums.entitlements` (WebAuthn + Keychain)
- `Info.plist` (configured for deep links)

## 🚀 Next: Run Migration Script

Copy all View files at once:

```bash
cd ~/Documents/development.nosync
chmod +x migrate-to-nums.sh
./migrate-to-nums.sh
```

This will copy:
- All 10 View files (`Views/` folder)
- Documentation files to `nums/` root
- Setup script

## 📱 Then: Add to Xcode

1. **Open** `nums/nums.xcodeproj` in Xcode

2. **Add folders** (drag from Finder into Xcode):
   - `Managers/` folder
   - `Views/` folder
   - `Models/` folder
   - `nums-Bridging-Header.h`
   - `nums.entitlements`

3. **Configure Bridging Header**:
   - Target → Build Settings
   - Search: "Objective-C Bridging Header"
   - Set to: `nums/nums-Bridging-Header.h`

4. **Verify Entitlements**:
   - Target → Signing & Capabilities
   - Should show:
     - Associated Domains
     - Keychain Sharing

## 🔧 Build Frameworks

```bash
# One-time: Install iOS targets
rustup target add aarch64-apple-ios aarch64-apple-ios-sim

# Build dojo.c
cd ~/Documents/development.nosync/dojo.c
./scripts/build_ios.sh

# Build controller.c
cd ~/Documents/development.nosync/dojo.c/controller.c
./scripts/build_ios.sh
```

## 📦 Add Frameworks to Xcode

### Dojo Framework:
Drag into Xcode (set to "Embed & Sign"):
- `~/Documents/development.nosync/dojo.c/target/dojo_uniffi.xcframework`
- `~/Documents/development.nosync/dojo.c/bindings/swift/DojoEngine.swift`
- `~/Documents/development.nosync/dojo.c/bindings/swift/DojoEngineFFI.h`

### Controller Framework:
Drag into Xcode (set to "Embed & Sign"):
- `~/Documents/development.nosync/dojo.c/controller.c/target/controller_uniffi.xcframework`
- `~/Documents/development.nosync/dojo.c/controller.c/bindings/swift/controller_uniffi.swift`
- `~/Documents/development.nosync/dojo.c/controller.c/bindings/swift/controller_uniffiFFI.h`

## ✨ Build & Run!

```
Cmd+Shift+K  (Clean)
Cmd+B        (Build)
Cmd+R        (Run)
```

## 📖 Documentation

See these files in `nums/` folder:
- `SETUP_NUMS.md` - Detailed setup instructions
- `BUILD_INSTRUCTIONS.md` - Framework build guide  
- `QUICKSTART.md` - 10-minute setup
- `PROJECT_STRUCTURE.md` - Architecture details

## 🎉 What You Get

Your nums app will have 4 tabs:
1. **Session** - WebAuthn session creation
2. **World** - Dojo world connection
3. **Execute** - Transaction execution  
4. **Status** - Session info

---

**Ready to proceed?** Run the migration script and add files to Xcode!


