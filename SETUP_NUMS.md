# Setting Up Nums iOS App

## ✅ Files Already Copied

The following files have been copied to your `nums/nums/` folder:

- ✅ `Managers/DojoManager.swift`
- ✅ `Managers/SessionManager.swift`  
- ✅ `Models/ArgumentType.swift`
- ✅ `ContentView.swift` (updated)
- ✅ `numsApp.swift` (updated with managers)
- ✅ `nums-Bridging-Header.h`
- ✅ `nums.entitlements`
- ✅ `Info.plist`

## 📱 Copy Remaining View Files

Run this command to copy all View files:

```bash
chmod +x /Users/nasr/Documents/development.nosync/migrate-to-nums.sh
/Users/nasr/Documents/development.nosync/migrate-to-nums.sh
```

Or copy manually from Finder:
- Copy `/ios-dojo-controller-app/Views/` folder to `/nums/nums/`

## 🏗️ Add Files to Xcode Project

1. **Open** `nums.xcodeproj` in Xcode

2. **Add folders** to your project (drag into Xcode):
   - `Managers/` folder
   - `Views/` folder  
   - `Models/` folder

3. **Add configuration files**:
   - `nums-Bridging-Header.h`
   - `nums.entitlements`
   - Make sure `Info.plist` is included

4. **Configure Build Settings**:
   - Select `nums` target → Build Settings
   - Search: "Bridging Header"
   - Set to: `nums/nums-Bridging-Header.h`

5. **Add Entitlements**:
   - Select `nums` target → Signing & Capabilities
   - The entitlements file should auto-link
   - Verify these capabilities exist:
     - Associated Domains (x.cartridge.gg, cartridge.gg)
     - Keychain Sharing

## 🔧 Build Frameworks

Before building in Xcode, you need to build the Rust frameworks:

```bash
# Install iOS targets (one-time)
rustup target add aarch64-apple-ios aarch64-apple-ios-sim

# Build dojo.c
cd ~/Documents/development.nosync/dojo.c
./scripts/build_ios.sh

# Build controller.c  
cd ~/Documents/development.nosync/dojo.c/controller.c
./scripts/build_ios.sh
```

## 📦 Add Frameworks to Xcode

### 1. Add Dojo Framework

Drag these into your Xcode project:
- `dojo.c/target/dojo_uniffi.xcframework` (set to: Embed & Sign)
- `dojo.c/bindings/swift/DojoEngine.swift`
- `dojo.c/bindings/swift/DojoEngineFFI.h`

### 2. Add Controller Framework

Drag these into your Xcode project:
- `controller.c/target/controller_uniffi.xcframework` (set to: Embed & Sign)
- `controller.c/bindings/swift/controller_uniffi.swift`
- `controller.c/bindings/swift/controller_uniffiFFI.h`

## 🚀 Build & Run

1. Clean build folder: `Cmd+Shift+K`
2. Build: `Cmd+B`
3. Run: `Cmd+R`

## 📚 Features

Your app now has 4 tabs:

1. **Session** - Register Cartridge session with WebAuthn
2. **World** - Connect to Dojo worlds (dojo.c integration)
3. **Execute** - Send transactions
4. **Status** - View session details

## ⚠️ Troubleshooting

### "Cannot find type 'DojoManager' in scope"

**Solution**: Make sure you added the `Managers/` folder to Xcode

### "Use of undeclared type 'SessionAccount'"

**Solution**: 
1. Verify `controller_uniffi.swift` is in project
2. Verify `controller_uniffi.xcframework` is added
3. Check bridging header imports both FFI headers

### "DojoEngineFFI.h not found"

**Solution**:
1. Verify both FFI headers (`DojoEngineFFI.h` and `controller_uniffiFFI.h`) are in project
2. Check bridging header path in Build Settings
3. Ensure it points to: `nums/nums-Bridging-Header.h`

## 📖 More Documentation

- `BUILD_INSTRUCTIONS.md` - How to build frameworks
- `QUICKSTART.md` - Detailed setup guide
- `PROJECT_STRUCTURE.md` - Code organization

## ✨ Success!

Once everything builds:
- ✅ WebAuthn session creation works
- ✅ In-app Safari browser
- ✅ Transaction execution
- ✅ Dojo world connection ready

Happy building! 🎉


