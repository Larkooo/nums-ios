# Fix: Cannot find type 'SessionAccount'

## The Problem

`SessionAccount` is not found because the controller.c framework hasn't been built and added to Xcode yet.

## Solution

### Step 1: Build the Controller.c Framework

First, install iOS targets (one-time):

```bash
rustup target add aarch64-apple-ios aarch64-apple-ios-sim
```

Then build controller.c:

```bash
cd ~/Documents/development.nosync/dojo.c/controller.c
./scripts/build_ios.sh
```

This creates:
- `target/controller_uniffi.xcframework`
- `bindings/swift/controller_uniffi.swift`
- `bindings/swift/controller_uniffiFFI.h`

### Step 2: Add Controller Framework to Xcode

1. **Add the XCFramework:**
   - In Xcode, drag `controller.c/target/controller_uniffi.xcframework` into your project
   - When prompted:
     - ✅ Check "Copy items if needed"
     - ✅ Select your nums target
   - **IMPORTANT**: In target's General tab → Frameworks section
     - Set to **"Embed & Sign"** (not "Do Not Embed")

2. **Add the Swift bindings:**
   - Drag `controller.c/bindings/swift/controller_uniffi.swift` into your Xcode project
   - When prompted:
     - ✅ Check "Copy items if needed"
     - ✅ Select your nums target
     - ✅ Add to nums group

3. **Add the FFI header:**
   - Drag `controller.c/bindings/swift/controller_uniffiFFI.h` into your Xcode project
   - When prompted:
     - ✅ Check "Copy items if needed"
     - ✅ Select your nums target

### Step 3: Verify Bridging Header

Make sure `nums/nums-Bridging-Header.h` contains:

```objc
//
//  nums-Bridging-Header.h
//

// Dojo.c FFI (Dojo World interactions)
#import "DojoEngineFFI.h"

// Controller.c FFI (Cartridge Session Account)
#import "controller_uniffiFFI.h"
```

### Step 4: Configure Build Settings

1. Select your target → Build Settings
2. Search for: `bridging`
3. Set **Objective-C Bridging Header** to: `nums/nums-Bridging-Header.h`

### Step 5: Clean and Build

```
Cmd + Shift + K  (Clean Build Folder)
Cmd + B          (Build)
```

## Quick Checklist

- [ ] Built controller.c framework (`./scripts/build_ios.sh`)
- [ ] Added `controller_uniffi.xcframework` to project
- [ ] Set framework to "Embed & Sign"
- [ ] Added `controller_uniffi.swift` to project
- [ ] Added `controller_uniffiFFI.h` to project
- [ ] Bridging header imports `controller_uniffiFFI.h`
- [ ] Bridging header path set in Build Settings
- [ ] Cleaned and rebuilt

## Expected Files in Xcode

After adding, your Project Navigator should show:

```
nums/
├── nums/
│   ├── Managers/
│   │   ├── DojoManager.swift
│   │   └── SessionManager.swift
│   ├── Views/
│   │   └── MainView.swift
│   ├── Models/
│   │   └── ArgumentType.swift
│   ├── numsApp.swift
│   ├── ContentView.swift
│   ├── nums-Bridging-Header.h
│   ├── nums.entitlements
│   ├── Info.plist
│   └── Assets.xcassets/
├── Frameworks/
│   ├── controller_uniffi.xcframework/
│   └── (dojo_uniffi.xcframework if you add it later)
├── Bindings/
│   ├── controller_uniffi.swift
│   ├── controller_uniffiFFI.h
│   └── (Dojo bindings if you add them later)
```

## Common Issues

### ❌ "controller_uniffiFFI.h not found"

**Solution:**
- Make sure the header is in your project
- Verify bridging header path is correct
- Check the header is in the same directory as other files

### ❌ Build script fails

**Solution:**
```bash
# Make sure iOS targets are installed
rustup target list --installed | grep apple

# Should show:
# aarch64-apple-ios
# aarch64-apple-ios-sim

# If not, install them:
rustup target add aarch64-apple-ios aarch64-apple-ios-sim
```

### ❌ "Framework not loaded"

**Solution:**
- Go to target → General → Frameworks
- Make sure controller_uniffi.xcframework is set to **"Embed & Sign"**

## After This Fix

Once you've added the controller framework, these types will be available:

- ✅ `SessionAccount`
- ✅ `SessionPolicies`
- ✅ `SessionPolicy`
- ✅ `Call`
- ✅ `getPublicKey(privateKey:)`

And your SessionManager will compile! 🎉

## Optional: Add Dojo.c Framework Too

If you also want to use Dojo.c (for `DojoManager`):

```bash
cd ~/Documents/development.nosync/dojo.c
./scripts/build_ios.sh
```

Then add to Xcode:
- `dojo.c/target/dojo_uniffi.xcframework` (Embed & Sign)
- `dojo.c/bindings/swift/DojoEngine.swift`
- `dojo.c/bindings/swift/DojoEngineFFI.h`

And update bridging header to import `DojoEngineFFI.h`.


