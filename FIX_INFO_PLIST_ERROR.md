# Fix: Multiple commands produce Info.plist

## The Problem

Xcode is trying to copy `Info.plist` twice, which causes a build error:
```
Multiple commands produce '.../nums.app/Info.plist'
```

## Solution

### Step 1: Remove Info.plist from Copy Bundle Resources

1. In Xcode, select your **nums** target
2. Go to **Build Phases** tab
3. Expand **Copy Bundle Resources**
4. Look for `Info.plist` in the list
5. Select it and click the **-** (minus) button to remove it

**Info.plist should NOT be in Copy Bundle Resources!**

Xcode automatically processes Info.plist - you don't need to copy it manually.

### Step 2: Verify Info.plist Location

1. Select your target
2. Go to **Build Settings**
3. Search for: `Info.plist`
4. Find **Info.plist File** setting
5. It should be set to: `nums/Info.plist` (or blank if using default)

### Step 3: Clean and Rebuild

1. Clean build folder: `Cmd + Shift + K`
2. Build: `Cmd + B`

## Alternative Solution (If above doesn't work)

If Info.plist is still causing issues:

1. **Remove Info.plist reference from Xcode**
   - Right-click `Info.plist` in Project Navigator
   - Delete → "Remove Reference" (not "Move to Trash")

2. **Re-add Info.plist**
   - Drag `Info.plist` back into Xcode
   - **IMPORTANT**: When adding, make sure:
     - ✅ "Copy items if needed" is UNCHECKED
     - ✅ Target is selected
     - ✅ "Add to targets" has your nums target checked

3. **Verify it's NOT in Copy Bundle Resources**
   - Build Phases → Copy Bundle Resources
   - Info.plist should NOT be there

## What NOT to Do

❌ Don't add Info.plist to Copy Bundle Resources
❌ Don't have multiple Info.plist files in your project
❌ Don't copy Info.plist to the app bundle manually

## Quick Check

After fixing, your Build Phases should look like:

**Copy Bundle Resources** should contain:
- ✅ Assets.xcassets
- ✅ Any other resources
- ❌ NO Info.plist

**Compile Sources** should contain:
- ✅ All your .swift files
- ❌ NO Info.plist

Info.plist is handled automatically by Xcode!

## Still Having Issues?

Try this nuclear option:

1. Clean Build Folder: `Cmd + Shift + K`
2. Close Xcode
3. Delete Derived Data:
   ```bash
   rm -rf ~/Library/Developer/Xcode/DerivedData
   ```
4. Reopen Xcode
5. Build

This should fix it! 🎉


