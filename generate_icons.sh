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

# Background gradient colors (matching MainView.swift)
# Top-left color: rgb(0.4, 0.2, 0.8) = #6633CC
# Bottom-right color: rgb(0.3, 0.1, 0.6) = #4D1A99
GRADIENT_COLOR_1="#6633CC"  # Top-left (lighter purple)
GRADIENT_COLOR_2="#4D1A99"  # Bottom-right (darker purple)

# Icon scale (percentage of canvas to fill with the icon)
# Lower = more padding, higher = less padding
# Recommended: 0.6 to 0.75 (60-75% of canvas)
ICON_SCALE=0.65  # Icon will be 65% of the canvas size

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
        
        # Calculate icon size (scaled down to leave padding)
        icon_size=$(printf "%.0f" $(echo "$size * $ICON_SCALE" | bc))
        
        # Step 1: Create gradient background (perfect diagonal top-left to bottom-right)
        magick -size ${size}x${size} \
            -define gradient:angle=135 \
            gradient:"${GRADIENT_COLOR_1}-${GRADIENT_COLOR_2}" \
            "${OUTPUT_DIR}/temp_bg.png"
        
        # Step 2: Convert SVG logo to PNG preserving aspect ratio
        rsvg-convert -a -w ${icon_size} -h ${icon_size} "$SVG_FILE" -o "${OUTPUT_DIR}/temp_icon.png"
        
        # Step 3: Composite logo on top of gradient background
        magick "${OUTPUT_DIR}/temp_bg.png" \
            "${OUTPUT_DIR}/temp_icon.png" \
            -gravity center \
            -composite \
            "${OUTPUT_DIR}/${filename}"
        
        # Clean up temp files
        rm -f "${OUTPUT_DIR}/temp_bg.png" "${OUTPUT_DIR}/temp_icon.png"
    done
done

echo ""
echo "✅ All icons generated successfully!"
echo ""
echo "📱 Icon files created in: ${OUTPUT_DIR}"
echo "🎨 Background gradient: ${GRADIENT_COLOR_1} → ${GRADIENT_COLOR_2}"
echo "📏 Icon scale: ${ICON_SCALE}"
echo ""
echo "💡 Customization:"
echo "   - To change gradient colors, edit GRADIENT_COLOR_1 and GRADIENT_COLOR_2"
echo "   - To adjust icon size/padding, edit ICON_SCALE (0.6 = more padding, 0.75 = less padding)"
echo ""
echo "Next steps:"
echo "1. Open your project in Xcode"
echo "2. Check Assets.xcassets/AppIcon.appiconset"
echo "3. Icons should show clean gradient background with centered logo"
echo "4. Build and archive your app"
