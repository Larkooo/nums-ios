#!/bin/bash

# Icon Generator Script for NUMS App
# Generates all required iOS app icon sizes from SVG with custom background

# Check if ImageMagick is installed
if ! command -v magick &> /dev/null
then
    echo "❌ ImageMagick is not installed. Installing via Homebrew..."
    brew install imagemagick
fi

# Check if librsvg is installed (for better SVG rendering)
if ! command -v rsvg-convert &> /dev/null
then
    echo "📦 Installing librsvg for high-quality SVG rendering..."
    brew install librsvg
fi

# Source SVG
SVG_FILE="nums/Assets.xcassets/nums-icon.imageset/nums-icon.svg"

# Check if source icon exists
if [ ! -f "$SVG_FILE" ]; then
    echo "❌ Error: $SVG_FILE not found"
    exit 1
fi

echo "🎨 Generating all required icon sizes from SVG..."
echo "📁 Source: $SVG_FILE"

# Output directory
OUTPUT_DIR="nums/Assets.xcassets/AppIcon.appiconset"

# Background color (customize this!)
# Options:
# - Solid color: "#5931FF" (purple)
# - Gradient: Use ImageMagick to create gradient background
BACKGROUND_COLOR="#5931FF"  # Purple matching your app theme

# Array of all sizes needed: size:filename1:filename2:...
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
        
        # Step 1: Convert SVG to PNG at target size (high quality, no interpolation)
        rsvg-convert -w ${size} -h ${size} "$SVG_FILE" -o "${OUTPUT_DIR}/temp_icon.png"
        
        # Step 2: Create background and composite
        magick convert -size ${size}x${size} xc:"${BACKGROUND_COLOR}" \
            "${OUTPUT_DIR}/temp_icon.png" \
            -gravity center \
            -composite \
            "${OUTPUT_DIR}/${filename}"
        
        # Clean up temp file
        rm "${OUTPUT_DIR}/temp_icon.png"
    done
done

echo ""
echo "✅ All icons generated successfully!"
echo ""
echo "📱 Icon files created in: ${OUTPUT_DIR}"
echo "🎨 Background color: ${BACKGROUND_COLOR}"
echo ""
echo "💡 To change the background color, edit this script and modify BACKGROUND_COLOR"
echo ""
echo "Next steps:"
echo "1. Open your project in Xcode"
echo "2. Check Assets.xcassets/AppIcon.appiconset"
echo "3. All icons should be filled in with purple background"
echo "4. Build and archive your app"
