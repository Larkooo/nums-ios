# Fix: Cannot find uniffi functions in scope

## The Problem

Swift can't find the C functions because the bridging header isn't properly set up.

## Solution

### Step 1: Verify Bridging Header Content

Make sure `nums/nums-Bridging-Header.h` contains:

```objc
//
//  nums-Bridging-Header.h
//

// Controller.c FFI (Cartridge Session Account)
#import "controller_uniffiFFI.h"

// Dojo.c FFI (if using it later)
// #import "DojoEngineFFI.h"
```

### Step 2: Verify Header File is in Xcode

1. In Xcode Project Navigator, make sure you see:
   - `nums/nums-Bridging-Header.h`
   - `nums/controller_uniffiFFI.h`

2. **If `controller_uniffiFFI.h` is NOT in Xcode:**
   - Right-click `nums` folder
   - "Add Files to 'nums'..."
   - Select `controller_uniffiFFI.h`
   - Make sure target is checked
   - Add

### Step 3: Set Bridging Header Path in Build Settings

1. Select your `nums` target
2. Go to **Build Settings** tab
3. Search for: `bridging`
4. Find **Objective-C Bridging Header**
5. Set to: `nums/nums-Bridging-Header.h`

   Or try the full path: `$(SRCROOT)/nums/nums-Bridging-Header.h`

### Step 4: Clean and Rebuild

```
Cmd + Shift + K  (Clean)
Cmd + B          (Build)
```

## Still Not Working?

Try this:

### Option A: Remove and Re-add Bridging Header

1. Select `nums-Bridging-Header.h` in Xcode
2. Delete → Remove Reference (don't move to trash)
3. Drag it back into Xcode from Finder
4. Make sure target is checked
5. Reset Build Settings path

### Option B: Check File Paths

In Terminal:
```bash
cd ~/Documents/development.nosync/nums/nums
ls -la | grep -E "(Bridging|controller_uniffi)"
```

You should see:
- `nums-Bridging-Header.h`
- `controller_uniffiFFI.h`
- `controller_uniffi.swift`

### Option C: Verify Header Import

The bridging header MUST use the exact filename. Check that:
- Header file is named: `controller_uniffiFFI.h` (note the capitalization)
- Import statement uses: `#import "controller_uniffiFFI.h"`

## Common Issues

### Issue: "File not found"

**Solution**: The header file isn't in the same directory as the bridging header, or isn't added to Xcode target.

### Issue: "No such file or directory"

**Solution**: The bridging header path in Build Settings is wrong. Should be relative to project root:
- Correct: `nums/nums-Bridging-Header.h`
- Wrong: `/nums-Bridging-Header.h`
- Wrong: `nums-Bridging-Header.h`

### Issue: Still can't find functions

**Solution**: Make sure the XCFramework is added and set to "Embed & Sign":
1. Target → General → Frameworks, Libraries, and Embedded Content
2. `controller_uniffi.xcframework` should be there
3. Should say "Embed & Sign"

## Debug: Print Header Search Paths

In Build Settings, search for "Header Search Paths" and verify it includes your project directory.


