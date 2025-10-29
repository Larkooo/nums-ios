#!/bin/bash
# Copy controller.c and dojo.c Swift bindings to nums project

set -e

echo "📦 Copying Swift bindings to nums..."

DOJO_PATH="$HOME/Documents/development.nosync/dojo.c"
CONTROLLER_PATH="$HOME/Documents/development.nosync/dojo.c/controller.c"
NUMS_PATH="$HOME/Documents/development.nosync/nums/nums"

# Check if controller.c files exist
if [ ! -f "$CONTROLLER_PATH/bindings/swift/controller_uniffi.swift" ]; then
    echo "❌ Error: controller_uniffi.swift not found"
    echo "   Did you build controller.c? Run: cd controller.c && ./scripts/build_ios.sh"
    exit 1
fi

# Check if dojo.c files exist
if [ ! -f "$DOJO_PATH/bindings/swift/DojoEngine.swift" ]; then
    echo "❌ Error: DojoEngine.swift not found"
    echo "   Did you build dojo.c? Run: cd dojo.c && ./scripts/build_ios.sh"
    exit 1
fi

echo ""
echo "📁 Copying controller.c bindings..."
cp "$CONTROLLER_PATH/bindings/swift/controller_uniffi.swift" "$NUMS_PATH/"
echo "  ✓ controller_uniffi.swift"
cp "$CONTROLLER_PATH/bindings/swift/controller_uniffiFFI.h" "$NUMS_PATH/"
echo "  ✓ controller_uniffiFFI.h"

echo ""
echo "📁 Copying dojo.c bindings..."
cp "$DOJO_PATH/bindings/swift/DojoEngine.swift" "$NUMS_PATH/"
echo "  ✓ DojoEngine.swift"
cp "$DOJO_PATH/bindings/swift/DojoEngineFFI.h" "$NUMS_PATH/"
echo "  ✓ DojoEngineFFI.h"

echo ""
echo "✅ All files copied successfully!"
echo ""
echo "Files copied to: $NUMS_PATH/"
echo ""
echo "Controller.c bindings:"
echo "  - controller_uniffi.swift"
echo "  - controller_uniffiFFI.h"
echo ""
echo "Dojo.c bindings:"
echo "  - DojoEngine.swift"
echo "  - DojoEngineFFI.h"
echo ""
echo "Next steps:"
echo "1. In Xcode, right-click 'nums' folder"
echo "2. Select 'Add Files to nums...'"
echo "3. Add all 4 files"
echo "4. Make sure nums target is checked"
echo "5. Clean and build (Cmd+Shift+K, then Cmd+B)"

