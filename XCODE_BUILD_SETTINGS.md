# Xcode Build Settings for Nums

## Required Build Settings

### 1. Objective-C Bridging Header

**Setting:** `Objective-C Bridging Header`
**Path:** `nums/nums-Bridging-Header.h`

**How to set:**
1. Select your `nums` target
2. Go to **Build Settings** tab
3. Search for: `bridging`
4. Set **Objective-C Bridging Header** to: `nums/nums-Bridging-Header.h`

### 2. Swift Language Version

**Setting:** `Swift Language Version`
**Value:** `Swift 5`

This should be set by default, but verify it's set to Swift 5 or later.

### 3. Enable Bitcode (Disable it)

**Setting:** `Enable Bitcode`
**Value:** `No`

Rust frameworks don't support Bitcode, so you must disable it.

**How to set:**
1. Search for: `bitcode`
2. Set **Enable Bitcode** to: `No`

### 4. Validate Workspace (Optional but recommended)

**Setting:** `Validate Workspace`
**Value:** `Yes`

### 5. Dead Code Stripping (Optional)

**Setting:** `Dead Code Stripping`
**Value:** `Yes`

Helps reduce binary size.

## Framework Configuration

### After Adding XCFrameworks

When you drag `dojo_uniffi.xcframework` and `controller_uniffi.xcframework` into Xcode:

1. **Make sure they are set to "Embed & Sign"**
   - Select your target
   - Go to **General** tab
   - Scroll to **Frameworks, Libraries, and Embedded Content**
   - Both frameworks should show **"Embed & Sign"**

2. **Framework Search Paths** (usually automatic)
   
   If Xcode doesn't find the frameworks:
   - Setting: `Framework Search Paths`
   - Add: `$(PROJECT_DIR)/path/to/frameworks`

## Signing & Capabilities

### 1. Signing

**Automatically manage signing:** `Checked` ✅

Select your development team.

### 2. Capabilities to Add

Click the **+ Capability** button and add:

#### **Associated Domains**
- `webcredentials:x.cartridge.gg`
- `webcredentials:cartridge.gg`
- `applinks:x.cartridge.gg`
- `applinks:cartridge.gg`

#### **Keychain Sharing**
- Will auto-populate with your bundle ID

These should already be in `nums.entitlements` file.

## Build Settings Summary (Copy-Paste)

Here are the exact values to set:

```
Objective-C Bridging Header: nums/nums-Bridging-Header.h
Enable Bitcode: No
Swift Language Version: Swift 5
Build Active Architecture Only (Debug): Yes
Build Active Architecture Only (Release): No
```

## Common Issues & Solutions

### ❌ "Bridging header not found"

**Solution:**
- Make sure path is: `nums/nums-Bridging-Header.h` (relative to project root)
- Or try: `$(SRCROOT)/nums/nums-Bridging-Header.h`

### ❌ "Framework not found"

**Solution:**
- Verify XCFrameworks are added to target
- Check they're set to "Embed & Sign" not "Do Not Embed"
- Clean build folder (Cmd+Shift+K)

### ❌ "Symbol not found" at runtime

**Solution:**
- Make sure both `.xcframework` AND `.swift` bindings are added
- Verify bridging header imports both FFI headers:
  ```objc
  #import "DojoEngineFFI.h"
  #import "controller_uniffiFFI.h"
  ```

### ❌ Bitcode errors

**Solution:**
- Disable bitcode in Build Settings (set to `No`)

## Deployment Target

**Setting:** `iOS Deployment Target`
**Minimum:** `iOS 16.0` (or whatever you set)

## Quick Checklist

Before building:

- [ ] Bridging Header path set correctly
- [ ] Enable Bitcode = No
- [ ] Both XCFrameworks added and set to "Embed & Sign"
- [ ] Both Swift binding files added to project
- [ ] Both FFI headers added to project
- [ ] Bridging header imports both FFI headers
- [ ] Entitlements file added to target
- [ ] Signing configured with team selected
- [ ] Associated Domains capability added

## Build and Run

Once everything is configured:

1. **Clean Build Folder**: `Cmd + Shift + K`
2. **Build**: `Cmd + B`
3. **Run**: `Cmd + R`

If build succeeds, you should see your purple leaderboard screen! 🎉


