#!/bin/bash

# Icon Generator Script for NUMS App
# This script generates all required iOS app icon sizes from a single 1024x1024 PNG

# Check if ImageMagick is installed
if ! command -v magick &> /dev/null
then
    echo "❌ ImageMagick is not installed. Installing via Homebrew..."
    brew install imagemagick
fi

# Check if source icon exists
if [ ! -f "icon-1024.png" ]; then
    echo "❌ Error: icon-1024.png not found in current directory"
    echo "Please create a 1024x1024 PNG icon file named 'icon-1024.png'"
    exit 1
fi

echo "🎨 Generating all required icon sizes..."

# Output directory
OUTPUT_DIR="nums/Assets.xcassets/AppIcon.appiconset"

# Array of sizes needed
declare -a sizes=(
    "20:20.png"
    "29:29.png"
    "40:40.png:40-1.png:40-2.png"
    "58:58.png:58-1.png"
    "60:60.png"
    "76:76.png"
    "80:80.png:80-1.png"
    "87:87.png"
    "120:120.png:120-1.png"
    "152:152.png"
    "167:167.png"
    "180:180.png"
    "1024:1024.png"
)

# Generate each size
for size_entry in "${sizes[@]}"; do
    IFS=':' read -ra PARTS <<< "$size_entry"
    size="${PARTS[0]}"
    
    # Generate for each filename variant
    for i in "${!PARTS[@]}"; do
        if [ $i -eq 0 ]; then
            continue  # Skip the size part
        fi
        
        filename="${PARTS[$i]}"
        echo "  ✓ Generating ${size}x${size} → ${filename}"
        magick convert icon-1024.png -resize ${size}x${size} "${OUTPUT_DIR}/${filename}"
    done
done

echo "✅ All icons generated successfully!"
echo ""
echo "📱 Icon files created in: ${OUTPUT_DIR}"
echo ""
echo "Next steps:"
echo "1. Open your project in Xcode"
echo "2. Check Assets.xcassets/AppIcon.appiconset"
echo "3. All icons should be filled in"
echo "4. Build and archive your app"

