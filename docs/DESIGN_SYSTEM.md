# PowerCA Mobile Design System

**Version:** 1.0
**Last Updated:** 2025-11-01
**Framework:** Flutter with Material 3

This design system defines the visual language and UI components for the PowerCA Mobile application, a professional task management app for Chartered Accountants.

---

## Table of Contents

1. [Brand Identity](#brand-identity)
2. [Color Palette](#color-palette)
3. [Typography](#typography)
4. [Spacing System](#spacing-system)
5. [Border Radius & Corners](#border-radius--corners)
6. [Shadows & Elevation](#shadows--elevation)
7. [Components](#components)
8. [Icons & Iconography](#icons--iconography)
9. [Layout Patterns](#layout-patterns)
10. [Responsive Design](#responsive-design)
11. [Usage Guidelines](#usage-guidelines)

---

## Brand Identity

### Personality
- **Professional**: Clean, organized, trust-building
- **Efficient**: Fast, streamlined, focused
- **Modern**: Contemporary design, up-to-date technology
- **Accessible**: Clear, easy-to-use interface

### Design Principles
1. **Clarity First**: Every element should have a clear purpose
2. **Consistency**: Reuse patterns and components
3. **Accessibility**: Meet WCAG 2.1 AA standards
4. **Performance**: Optimize for fast load and smooth interactions
5. **Mobile-First**: Design for mobile, adapt for larger screens

---

## Color Palette

### Primary Colors

```dart
// Brand Primary (Blue)
primaryColor: Color(0xFF2255FC)      // Main brand color
primaryLight: Color(0xFF4A7BFC)      // Hover, light backgrounds
primaryDark: Color(0xFF1744D8)       // Pressed states

// Surface & Background
surfaceColor: Color(0xFFFFFFFF)      // Cards, modals, sheets
backgroundColor: Color(0xFFF8F9FC)   // Page backgrounds
accentColor: Color(0xFF263238)       // Dark accents
```

**Usage:**
- **Primary**: CTAs, links, active states, focus indicators
- **Surface**: Cards, dialogs, bottom sheets, inputs
- **Background**: Page/screen backgrounds
- **Accent**: Headers, high-emphasis text

### Semantic Colors

```dart
// Status Colors
successColor: Color(0xFF4CAF50)      // Completed, success messages
warningColor: Color(0xFFFF9800)      // Warnings, attention needed
errorColor: Color(0xFFF44336)        // Errors, destructive actions
infoColor: Color(0xFF2196F3)         // Information, tips
```

**Usage:**
- **Success**: Job completed status, success toasts, confirmation icons
- **Warning**: Pending tasks, overdue warnings
- **Error**: Failed operations, validation errors, delete actions
- **Info**: Tips, information banners, help text

### Text Colors

```dart
textPrimaryColor: Color(0xFF263238)    // Body text, headings
textSecondaryColor: Color(0xFF757575)  // Secondary text, labels
textDisabledColor: Color(0xFFBDBDBD)   // Disabled text, placeholders
```

**Usage:**
- **Primary**: Main content, headlines, important labels
- **Secondary**: Descriptions, metadata, timestamps, subtitles
- **Disabled**: Inactive elements, placeholder text

### UI Element Colors

```dart
borderColor: Color(0xFFE0E0E0)         // Input borders, dividers
dividerColor: Color(0xFFEEEEEE)        // List separators
cardBorderColor: Color(0xFFE9F0F8)     // Card borders (light blue tint)
```

### Status Badge Colors

Dynamic status badges support custom colors from backend:
- **In Progress**: Blue (#2255FC background, white text)
- **Completed**: Green (#4CAF50 background, white text)
- **Pending**: Orange (#FF9800 background, white text)
- **Cancelled**: Red (#F44336 background, white text)

---

## Typography

### Font Family

**Primary Font:** Poppins (Google Fonts)
- Professional, modern, highly legible
- Good support for numbers and special characters
- Excellent for UI and body text

```dart
import 'package:google_fonts/google_fonts.dart';

// All text uses Poppins
textTheme: GoogleFonts.poppinsTextTheme()
```

### Type Scale

#### Display Styles (Large Headlines)

```dart
// Display Large - 32px / Bold
displayLarge: GoogleFonts.poppins(
  fontSize: 32.sp,
  fontWeight: FontWeight.w700,  // Bold
  color: textPrimaryColor,
)

// Display Medium - 28px / SemiBold
displayMedium: GoogleFonts.poppins(
  fontSize: 28.sp,
  fontWeight: FontWeight.w600,  // SemiBold
  color: textPrimaryColor,
)

// Display Small - 24px / SemiBold
displaySmall: GoogleFonts.poppins(
  fontSize: 24.sp,
  fontWeight: FontWeight.w600,
  color: textPrimaryColor,
)
```

**Usage:** Page titles, large feature headings, empty states

#### Headline Styles (Section Headlines)

```dart
// Headline Large - 20px / SemiBold
headlineLarge: GoogleFonts.poppins(
  fontSize: 20.sp,
  fontWeight: FontWeight.w600,
  color: textPrimaryColor,
)

// Headline Medium - 18px / SemiBold
headlineMedium: GoogleFonts.poppins(
  fontSize: 18.sp,
  fontWeight: FontWeight.w600,
  color: textPrimaryColor,
)

// Headline Small - 16px / SemiBold
headlineSmall: GoogleFonts.poppins(
  fontSize: 16.sp,
  fontWeight: FontWeight.w600,
  color: textPrimaryColor,
)
```

**Usage:** Section headers, card titles, list group headers

#### Body Styles (Content Text)

```dart
// Body Large - 16px / Regular
bodyLarge: GoogleFonts.poppins(
  fontSize: 16.sp,
  fontWeight: FontWeight.w400,  // Regular
  color: textPrimaryColor,
)

// Body Medium - 14px / Regular
bodyMedium: GoogleFonts.poppins(
  fontSize: 14.sp,
  fontWeight: FontWeight.w400,
  color: textPrimaryColor,
)

// Body Small - 12px / Regular
bodySmall: GoogleFonts.poppins(
  fontSize: 12.sp,
  fontWeight: FontWeight.w400,
  color: textSecondaryColor,
)
```

**Usage:**
- **Large**: Primary content, descriptions, notes
- **Medium**: Card content, form text, secondary descriptions
- **Small**: Tags, metadata, timestamps, helper text

#### Label Styles (UI Labels)

```dart
// Label Large - 14px / Medium
labelLarge: GoogleFonts.poppins(
  fontSize: 14.sp,
  fontWeight: FontWeight.w500,  // Medium
  color: textPrimaryColor,
)

// Label Medium - 12px / Medium
labelMedium: GoogleFonts.poppins(
  fontSize: 12.sp,
  fontWeight: FontWeight.w500,
  color: textPrimaryColor,
)

// Label Small - 11px / Medium
labelSmall: GoogleFonts.poppins(
  fontSize: 11.sp,
  fontWeight: FontWeight.w500,
  color: textSecondaryColor,
)
```

**Usage:** Input labels, button text, navigation labels, tags

### Font Weights

```dart
FontWeight.w400  // Regular - Body text
FontWeight.w500  // Medium - Labels, emphasized text
FontWeight.w600  // SemiBold - Headlines, section titles
FontWeight.w700  // Bold - Large display text
```

---

## Spacing System

### Base Unit: 4px

All spacing uses multiples of 4px for consistency:

```dart
class AppSpacing {
  static const double xs = 4.0;    // 4px - Tight spacing
  static const double sm = 8.0;    // 8px - Small spacing
  static const double md = 16.0;   // 16px - Default spacing
  static const double lg = 24.0;   // 24px - Large spacing
  static const double xl = 32.0;   // 32px - Extra large
  static const double xxl = 48.0;  // 48px - Section spacing
}
```

### Usage Guidelines

| Spacing | Use Case | Example |
|---------|----------|---------|
| 4px (xs) | Icon margins, tight grouping | Icon + label gap |
| 8px (sm) | Related elements | Card sections, list items |
| 16px (md) | Standard padding | Card padding, screen margins |
| 24px (lg) | Component spacing | Between major sections |
| 32px (xl) | Large gaps | Between screen sections |
| 48px (xxl) | Major sections | Feature section spacing |

### Common Patterns

```dart
// Card padding
padding: EdgeInsets.all(AppSpacing.md)  // 16px all sides

// Screen horizontal margins
padding: EdgeInsets.symmetric(horizontal: AppSpacing.md)  // 16px

// List item vertical spacing
margin: EdgeInsets.symmetric(vertical: AppSpacing.sm)  // 8px

// Section spacing
SizedBox(height: AppSpacing.lg)  // 24px
```

---

## Border Radius & Corners

### Radius Scale

```dart
class AppRadius {
  static const double xs = 4.0;    // Small elements
  static const double sm = 8.0;    // Chips, tags
  static const double md = 12.0;   // Cards, buttons, inputs
  static const double lg = 16.0;   // Large cards
  static const double xl = 20.0;   // Modals, sheets
  static const double full = 9999; // Circular (badges, avatars)
}
```

### Component Radius

| Component | Radius | Value |
|-----------|--------|-------|
| Buttons | Medium | 12px |
| Input Fields | Medium | 12px |
| Cards | Medium | 12px |
| Chips/Tags | Small | 8px |
| Status Badges | Medium | 12px |
| Avatar | Full | 9999px (circle) |
| Bottom Sheet | Large | 16px (top corners) |
| Modal | Large | 16px |

### Usage

```dart
// Standard card
borderRadius: BorderRadius.circular(AppRadius.md)  // 12px

// Circular button/avatar
shape: BoxShape.circle

// Badge/chip
borderRadius: BorderRadius.circular(AppRadius.sm)  // 8px

// Bottom sheet (top corners only)
borderRadius: BorderRadius.vertical(
  top: Radius.circular(AppRadius.lg),  // 16px
)
```

---

## Shadows & Elevation

### Elevation Levels

```dart
// Level 0 - No shadow
elevation: 0
// Usage: AppBar, inline elements

// Level 1 - Subtle (Cards)
BoxShadow(
  color: Colors.black.withOpacity(0.05),
  blurRadius: 4,
  offset: Offset(0, 2),
)
// Usage: Cards, list items

// Level 2 - Moderate (Floating)
BoxShadow(
  color: Colors.black.withOpacity(0.1),
  blurRadius: 8,
  offset: Offset(0, 4),
)
// Usage: Floating buttons, elevated cards

// Level 3 - Strong (Modals)
BoxShadow(
  color: Colors.black.withOpacity(0.25),
  blurRadius: 9,
  offset: Offset(0, 4),
)
// Usage: Modals, bottom sheets, important CTAs
```

### Usage Guidelines

- **Level 0**: Flat elements integrated into background
- **Level 1**: Subtle separation (most cards)
- **Level 2**: Floating elements that need attention
- **Level 3**: Critical UI, modals, important actions

```dart
// Example: Standard card shadow
decoration: BoxDecoration(
  color: Colors.white,
  borderRadius: BorderRadius.circular(12.r),
  boxShadow: [
    BoxShadow(
      color: Colors.black.withOpacity(0.05),
      blurRadius: 4,
      offset: Offset(0, 2),
    ),
  ],
)
```

---

## Components

### Buttons

#### 1. Primary Button (Elevated)

**Style:**
```dart
ElevatedButton(
  style: ElevatedButton.styleFrom(
    backgroundColor: primaryColor,      // #2255FC
    foregroundColor: surfaceColor,      // White text
    elevation: 0,                        // Flat
    padding: EdgeInsets.symmetric(
      horizontal: 24.w,
      vertical: 16.h,
    ),
    shape: RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(12.r),
    ),
  ),
  onPressed: () {},
  child: Text('Primary Action'),
)
```

**Usage:** Primary CTAs, submit actions, important operations

#### 2. Secondary Button (Outlined)

**Style:**
```dart
OutlinedButton(
  style: OutlinedButton.styleFrom(
    foregroundColor: primaryColor,
    side: BorderSide(color: primaryColor, width: 1.5),
    padding: EdgeInsets.symmetric(
      horizontal: 24.w,
      vertical: 16.h,
    ),
    shape: RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(12.r),
    ),
  ),
  onPressed: () {},
  child: Text('Secondary Action'),
)
```

**Usage:** Secondary actions, cancel buttons, alternative options

#### 3. Text Button

**Style:**
```dart
TextButton(
  style: TextButton.styleFrom(
    foregroundColor: primaryColor,
    padding: EdgeInsets.symmetric(
      horizontal: 16.w,
      vertical: 12.h,
    ),
  ),
  onPressed: () {},
  child: Text('Text Action'),
)
```

**Usage:** Tertiary actions, links, less important operations

#### 4. Icon Button

**Style:**
```dart
IconButton(
  onPressed: () {},
  icon: Icon(Icons.notifications),
  iconSize: 24.sp,
  color: primaryColor,
)
```

**Usage:** Toolbar actions, menu buttons, inline actions

---

### Cards

#### Job Card

**Structure:**
```dart
Container(
  margin: EdgeInsets.symmetric(horizontal: 16.w, vertical: 6.h),
  padding: EdgeInsets.all(16.w),
  decoration: BoxDecoration(
    color: Colors.white,
    borderRadius: BorderRadius.circular(12.r),
    border: Border.all(
      color: Color(0xFFE9F0F8),  // Light blue border
      width: 1,
    ),
    boxShadow: [
      BoxShadow(
        color: Colors.black.withOpacity(0.05),
        blurRadius: 4,
        offset: Offset(0, 2),
      ),
    ],
  ),
  child: Column(...),
)
```

**Elements:**
- **Header**: Job reference, status badge, menu icon
- **Body**: Client name (bold), job type/name
- **Footer**: Additional metadata (optional)

**Spacing:**
- Outer margin: 16px horizontal, 6px vertical
- Internal padding: 16px all sides
- Element spacing: 12px between sections

#### Work Diary Entry Card

Similar structure to Job Card, optimized for time entries:
- **Header**: Date icon + text, hours badge, menu
- **Body**: Notes/description
- **Footer**: Task name (if applicable)

---

### Input Fields

**Text Input:**
```dart
TextField(
  decoration: InputDecoration(
    labelText: 'Label',
    hintText: 'Enter text...',
    filled: true,
    fillColor: surfaceColor,
    contentPadding: EdgeInsets.symmetric(
      horizontal: 16.w,
      vertical: 16.h,
    ),
    border: OutlineInputBorder(
      borderRadius: BorderRadius.circular(12.r),
      borderSide: BorderSide(color: borderColor, width: 1),
    ),
    focusedBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(12.r),
      borderSide: BorderSide(color: primaryColor, width: 2),
    ),
    errorBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(12.r),
      borderSide: BorderSide(color: errorColor, width: 1),
    ),
  ),
)
```

**States:**
- **Default**: Gray border (#E0E0E0), 1px
- **Focused**: Blue border (#2255FC), 2px
- **Error**: Red border (#F44336), 1px
- **Disabled**: Faded gray border, 1px

---

### Badges & Tags

#### Status Badge

**Style:**
```dart
Container(
  padding: EdgeInsets.symmetric(horizontal: 12.w, vertical: 4.h),
  decoration: BoxDecoration(
    color: badgeBackgroundColor,  // Dynamic from backend
    borderRadius: BorderRadius.circular(12.r),
  ),
  child: Text(
    'Status',
    style: TextStyle(
      fontSize: 12.sp,
      fontWeight: FontWeight.w500,
      color: badgeTextColor,  // Dynamic from backend
    ),
  ),
)
```

**Common Statuses:**
- In Progress: Blue background, white text
- Completed: Green background, white text
- Pending: Orange background, white text
- Cancelled: Red background, white text

#### Hours Badge (Work Diary)

**Style:**
```dart
Container(
  padding: EdgeInsets.symmetric(horizontal: 12.w, vertical: 4.h),
  decoration: BoxDecoration(
    color: Color(0xFFE3EFFF),  // Light blue
    borderRadius: BorderRadius.circular(12.r),
  ),
  child: Text(
    'Act. Hrs: 02:30 Hrs',
    style: TextStyle(
      fontSize: 11.sp,
      fontWeight: FontWeight.w500,
      color: primaryColor,
    ),
  ),
)
```

---

### Navigation

#### Top App Bar

**Height:** 64px
**Background:** White (#FFFFFF)
**Elevation:** 0 (flat with border)

**Structure:**
```dart
AppBar(
  backgroundColor: surfaceColor,
  elevation: 0,
  centerTitle: false,
  toolbarHeight: 64.h,
  title: Text(
    'Page Title',
    style: TextStyle(
      fontSize: 20.sp,
      fontWeight: FontWeight.w600,
      color: textPrimaryColor,
    ),
  ),
  actions: [
    IconButton(icon: Icon(Icons.search), onPressed: () {}),
    IconButton(icon: Icon(Icons.more_vert), onPressed: () {}),
  ],
)
```

**Border:**
```dart
decoration: BoxDecoration(
  color: Colors.white,
  border: Border(
    bottom: BorderSide(
      color: Color(0xFFE9F0F8),
      width: 1.5,
    ),
  ),
)
```

#### Bottom Navigation Bar

**Height:** 74px
**Background:** White
**Selected Color:** Primary Blue (#2255FC)
**Unselected Color:** Gray (#A3AAB7)

**Structure:**
```dart
BottomNavigationBar(
  selectedItemColor: primaryColor,
  unselectedItemColor: Color(0xFFA3AAB7),
  type: BottomNavigationBarType.fixed,
  selectedLabelStyle: TextStyle(
    fontSize: 12.sp,
    fontWeight: FontWeight.w600,
  ),
  unselectedLabelStyle: TextStyle(
    fontSize: 12.sp,
    fontWeight: FontWeight.w400,
  ),
  items: [...],
)
```

**Items:**
- Dashboard
- Job List
- Leave Req
- Pinboard

**Selected Indicator:** Blue top line (4px height, 4px radius)

---

### Modals & Sheets

#### Bottom Sheet

**Style:**
```dart
showModalBottomSheet(
  context: context,
  shape: RoundedRectangleBorder(
    borderRadius: BorderRadius.vertical(
      top: Radius.circular(16.r),
    ),
  ),
  builder: (context) => Container(
    padding: EdgeInsets.all(16.w),
    child: Column(...),
  ),
)
```

**Properties:**
- Top corners rounded: 16px
- Padding: 16px all sides
- Max height: 80% of screen

#### Dialog

**Style:**
```dart
Dialog(
  shape: RoundedRectangleBorder(
    borderRadius: BorderRadius.circular(16.r),
  ),
  child: Padding(
    padding: EdgeInsets.all(24.w),
    child: Column(...),
  ),
)
```

---

### Lists & Filters

#### Status Filter Tabs

**Style:**
```dart
Container(
  height: 48.h,
  child: ListView(
    scrollDirection: Axis.horizontal,
    padding: EdgeInsets.symmetric(horizontal: 16.w),
    children: [
      _buildTab('All', count: 10, selected: true),
      _buildTab('In Progress', count: 5, selected: false),
      // ...more tabs
    ],
  ),
)

Widget _buildTab(String label, {required int count, required bool selected}) {
  return Container(
    margin: EdgeInsets.only(right: 8.w),
    padding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 8.h),
    decoration: BoxDecoration(
      color: selected ? primaryColor : Colors.white,
      borderRadius: BorderRadius.circular(8.r),
      border: Border.all(
        color: selected ? primaryColor : borderColor,
        width: 1,
      ),
    ),
    child: Row(
      children: [
        Text(
          label,
          style: TextStyle(
            fontSize: 14.sp,
            fontWeight: FontWeight.w500,
            color: selected ? Colors.white : textPrimaryColor,
          ),
        ),
        SizedBox(width: 6.w),
        Container(
          padding: EdgeInsets.symmetric(horizontal: 6.w, vertical: 2.h),
          decoration: BoxDecoration(
            color: selected ? Colors.white.withOpacity(0.2) : backgroundColor,
            borderRadius: BorderRadius.circular(4.r),
          ),
          child: Text(
            count.toString(),
            style: TextStyle(
              fontSize: 12.sp,
              fontWeight: FontWeight.w600,
              color: selected ? Colors.white : textSecondaryColor,
            ),
          ),
        ),
      ],
    ),
  );
}
```

---

## Icons & Iconography

### Icon Style

- **Source:** Material Icons
- **Size:** 24sp (standard), 16sp-20sp (small), 32sp-48sp (large)
- **Color:** Primary text (#263238) or Primary blue (#2255FC) for emphasis

### Common Icons

| Function | Icon | Usage |
|----------|------|-------|
| Job/Work | `Icons.work_outline` | Job cards, work items |
| Calendar | `Icons.calendar_today` | Dates, scheduling |
| Time | `Icons.access_time` | Hours, duration |
| Task | `Icons.task_alt` | Task lists, checklists |
| Menu | `Icons.menu` | Navigation drawer |
| More | `Icons.more_vert` | Context menus |
| Notifications | `Icons.notifications_outlined` | Alerts, reminders |
| Dashboard | `Icons.dashboard` | Home/overview |
| List | `Icons.list_alt` | Lists, entries |
| Edit | `Icons.edit` | Edit actions |
| Delete | `Icons.delete` | Delete actions |
| Add | `Icons.add` | Create new |
| Check | `Icons.check_circle` | Complete, success |
| Warning | `Icons.warning_amber` | Warnings |
| Error | `Icons.error_outline` | Errors |
| Info | `Icons.info_outline` | Information |

### Icon Usage Guidelines

1. **Consistency**: Use the same icon for the same action throughout
2. **Alignment**: Center icons with adjacent text
3. **Spacing**: 4-6px gap between icon and text
4. **Color**: Match text color or use primary for emphasis
5. **Size**: Scale with text size (16sp icon with 12sp text, 24sp icon with 14-16sp text)

---

## Layout Patterns

### Screen Structure

```
┌─────────────────────────┐
│  Top Navigation (64px)  │  ← AppBar or custom header
├─────────────────────────┤
│                         │
│                         │
│   Main Content Area     │  ← Scrollable content
│                         │
│                         │
├─────────────────────────┤
│ Bottom Nav (74px)       │  ← Navigation bar
└─────────────────────────┘
```

### Content Padding

**Horizontal:** 16px screen margins (cards, lists)
**Vertical:** 8-12px between list items
**Sections:** 24px between major sections

### Grid System

- **Columns:** 12-column grid (rarely needed on mobile)
- **Gutter:** 16px between columns
- **Margin:** 16px screen edges

---

## Responsive Design

### Screen Sizes

PowerCA Mobile uses **flutter_screenutil** for responsive sizing:

```dart
// Initialize in main.dart
ScreenUtil.init(
  context,
  designSize: Size(375, 812),  // iPhone 11 Pro baseline
  minTextAdapt: true,
)

// Usage
Text('Hello', style: TextStyle(fontSize: 14.sp))  // Scales font
Container(width: 100.w, height: 50.h)  // Scales dimensions
SizedBox(width: 16.w, height: 16.h)  // Scales spacing
BorderRadius.circular(12.r)  // Scales radius
```

### Breakpoints

| Device | Width | Notes |
|--------|-------|-------|
| Small Phone | < 360px | Compact layouts |
| Standard Phone | 360-414px | Primary target |
| Large Phone | 415-600px | Comfortable spacing |
| Tablet | > 600px | Multi-column (future) |

### Responsive Strategy

1. **Font Sizing:** Use `.sp` for all font sizes
2. **Dimensions:** Use `.w` and `.h` for widths and heights
3. **Spacing:** Use `.w` and `.h` for padding and margins
4. **Radius:** Use `.r` for border radius
5. **Icons:** Use `.sp` for icon sizes

---

## Usage Guidelines

### Do's

✅ **Use theme colors** - Always reference `AppTheme` colors
✅ **Use spacing constants** - Use `AppSpacing` for padding/margins
✅ **Use typography styles** - Reference theme text styles
✅ **Use responsive units** - Always use `.sp`, `.w`, `.h`, `.r`
✅ **Follow elevation levels** - Use defined shadow levels
✅ **Maintain consistency** - Reuse components and patterns

### Don'ts

❌ **Don't hardcode colors** - Always use theme constants
❌ **Don't use random spacing** - Stick to 4px multiples
❌ **Don't mix font families** - Always use Poppins
❌ **Don't use fixed sizes** - Always use responsive units
❌ **Don't create custom shadows** - Use defined elevation levels
❌ **Don't reinvent components** - Reuse existing patterns

---

## Code Examples

### Creating a New Screen

```dart
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import '../../../app/theme.dart';

class NewFeaturePage extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.backgroundColor,
      appBar: AppBar(
        title: Text('Feature Name'),
      ),
      body: SafeArea(
        child: Padding(
          padding: EdgeInsets.symmetric(horizontal: AppSpacing.md.w),
          child: Column(
            children: [
              SizedBox(height: AppSpacing.lg.h),
              // Your content here
            ],
          ),
        ),
      ),
    );
  }
}
```

### Creating a Custom Card

```dart
Widget buildCustomCard({required String title, required String subtitle}) {
  return Container(
    margin: EdgeInsets.symmetric(
      horizontal: AppSpacing.md.w,
      vertical: AppSpacing.sm.h,
    ),
    padding: EdgeInsets.all(AppSpacing.md.w),
    decoration: BoxDecoration(
      color: AppTheme.surfaceColor,
      borderRadius: BorderRadius.circular(AppRadius.md.r),
      border: Border.all(
        color: AppTheme.cardBorderColor,
        width: 1,
      ),
      boxShadow: [
        BoxShadow(
          color: Colors.black.withOpacity(0.05),
          blurRadius: 4,
          offset: Offset(0, 2),
        ),
      ],
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: Theme.of(context).textTheme.headlineSmall,
        ),
        SizedBox(height: AppSpacing.sm.h),
        Text(
          subtitle,
          style: Theme.of(context).textTheme.bodyMedium?.copyWith(
            color: AppTheme.textSecondaryColor,
          ),
        ),
      ],
    ),
  );
}
```

---

## Design Tokens Reference

Quick reference for developers:

```dart
// Import theme
import '../../../app/theme.dart';

// Colors
AppTheme.primaryColor          // #2255FC
AppTheme.surfaceColor          // #FFFFFF
AppTheme.backgroundColor       // #F8F9FC
AppTheme.textPrimaryColor      // #263238
AppTheme.textSecondaryColor    // #757575
AppTheme.successColor          // #4CAF50
AppTheme.errorColor            // #F44336

// Spacing
AppSpacing.xs    // 4px
AppSpacing.sm    // 8px
AppSpacing.md    // 16px
AppSpacing.lg    // 24px
AppSpacing.xl    // 32px

// Radius
AppRadius.xs     // 4px
AppRadius.sm     // 8px
AppRadius.md     // 12px
AppRadius.lg     // 16px
AppRadius.xl     // 20px

// Typography
Theme.of(context).textTheme.displayLarge    // 32px / Bold
Theme.of(context).textTheme.headlineLarge   // 20px / SemiBold
Theme.of(context).textTheme.bodyLarge       // 16px / Regular
Theme.of(context).textTheme.bodyMedium      // 14px / Regular
Theme.of(context).textTheme.bodySmall       // 12px / Regular
Theme.of(context).textTheme.labelLarge      // 14px / Medium
```

---

## Resources

### Figma Design Files
- **Design System:** [Link to Figma]
- **Component Library:** [Link to Figma]
- **Mockups:** [Link to Figma]

### Documentation
- **Flutter Material 3:** https://m3.material.io/
- **flutter_screenutil:** https://pub.dev/packages/flutter_screenutil
- **google_fonts:** https://pub.dev/packages/google_fonts

### Tools
- **Color Contrast Checker:** https://webaim.org/resources/contrastchecker/
- **Material Design Color Tool:** https://material.io/resources/color/

---

## Changelog

### Version 1.0 (2025-11-01)
- Initial design system documentation
- Extracted from existing implementation
- Documented all colors, typography, spacing
- Added component specifications
- Added usage guidelines and code examples

---

**For questions or design system updates, please consult with the design team or update this document accordingly.**
