# Splash Screen Assets

This directory contains the assets needed for the splash screen.

## Asset Status

### 1. PowerCA Logo ✅ COMPLETE
- **File**: `powerca_logo.svg` (2.3 KB)
- **Status**: ✅ Integrated and working!
- **Format**: SVG (vector graphics)
- **Used in**: `lib/features/auth/presentation/widgets/powerca_logo.dart`

### 2. Welcome Illustration ⚠️ NEEDS EXPORT
- **File**: Placeholder currently used
- **Recommendation**: Export as PNG (SVG is too large at 50KB+)
- **Suggested name**: `welcome_illustration.png`
- **Recommended size**: 600x600px at 2x or 3x resolution

## How to Export from Figma

### Method 1: Using Figma Desktop App
1. Open the Figma file
2. Select the layer you want to export
3. In the right panel, scroll down to "Export" section
4. Click "+" to add export settings
5. Choose format (SVG for vector graphics, PNG for raster)
6. Click "Export [layer name]"
7. Save the file to this directory

### Method 2: Using Figma Web
1. Right-click on the layer in Figma
2. Select "Copy/Paste as" → "Copy as SVG" or "Copy as PNG"
3. Save the copied content to a file in this directory

### Method 3: Using Figma API (for batch export)
The asset URLs from your Figma design:
- Logo parts: Multiple SVG components
- Illustration: Multiple grouped elements
- You may need to export the entire frame and use it as a single image

## After Adding Assets

Once you've added the assets to this directory, update the splash screen code:

**File**: `lib/features/auth/presentation/pages/splash_page.dart`

Replace the placeholder widgets with actual image widgets:

```dart
// For logo (around line 60)
import 'package:flutter_svg/flutter_svg.dart';

SvgPicture.asset(
  'assets/images/splash/logo.svg',
  width: 61,
  height: 49,
),

// For illustration (around line 115)
Image.asset(
  'assets/images/splash/welcome_illustration.png',
  width: screenWidth * 0.7,
  fit: BoxFit.contain,
),
```

## Current Status

- [ ] Logo exported and added
- [ ] Welcome illustration exported and added
- [ ] Splash screen code updated to use actual assets

## Notes

- SVG format is preferred for logos and icons (scalable, smaller file size)
- PNG format works well for complex illustrations with gradients
- Ensure assets are optimized for mobile (not too large in file size)
- Recommended max file size: 500KB per asset
