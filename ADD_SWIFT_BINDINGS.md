# Add Swift Bindings to Xcode

## The Swift File is Too Large

The `controller_uniffi.swift` file is ~10,000+ lines of auto-generated code, so I can't copy it directly.

## Manual Steps

### 1. Copy the Swift File

```bash
cp ~/Documents/development.nosync/dojo.c/controller.c/bindings/swift/controller_uniffi.swift \
   ~/Documents/development.nosync/nums/nums/
```

### 2. Add to Xcode

1. In Xcode, right-click on the `nums` folder in Project Navigator
2. Select **"Add Files to 'nums'..."**
3. Navigate to: `~/Documents/development.nosync/nums/nums/`
4. Select `controller_uniffi.swift`
5. Make sure:
   - ✅ **"Copy items if needed"** is UNCHECKED (it's already there)
   - ✅ **"Add to targets"** has `nums` checked
6. Click **Add**

### 3. Verify Files in Xcode

You should now see in your Project Navigator:

```
nums/
├── nums/
│   ├── Managers/
│   ├── Views/
│   ├── Models/
│   ├── numsApp.swift
│   ├── ContentView.swift
│   ├── nums-Bridging-Header.h
│   ├── controller_uniffiFFI.h          ← Added
│   ├── controller_uniffi.swift         ← Added
│   └── ...
```

### 4. Build

```
Cmd + Shift + K  (Clean)
Cmd + B          (Build)
```

## What This File Contains

`controller_uniffi.swift` contains all the Swift types and functions:
- `SessionAccount`
- `SessionPolicies`
- `SessionPolicy`
- `Call`
- `Controller`
- `Owner`
- `getPublicKey(privateKey:)`
- And many more...

## Alternative: Use Script

I've also created a copy script:

```bash
cd ~/Documents/development.nosync/nums
./copy_bindings.sh
```

This will copy both files to the correct location.


