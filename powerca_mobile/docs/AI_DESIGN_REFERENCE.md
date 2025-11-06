# PowerCA Mobile - AI Design Reference

**Quick Reference for AI Agents and Claude Code**

This is a condensed design system reference optimized for AI agents implementing new UI features. For complete details, see [DESIGN_SYSTEM.md](DESIGN_SYSTEM.md).

---

## Quick Start Checklist

When implementing new UI, always:

1. ✅ Import theme: `import '../../../app/theme.dart';`
2. ✅ Use responsive units: `.sp`, `.w`, `.h`, `.r`
3. ✅ Use AppTheme colors (never hardcode)
4. ✅ Use AppSpacing for padding/margins
5. ✅ Use Theme.of(context).textTheme for text styles
6. ✅ Follow existing card/component patterns

---

## Color Palette (Copy-Paste Ready)

```dart
// Primary Colors
AppTheme.primaryColor          // #2255FC - CTAs, links, active states
AppTheme.primaryLight          // #4A7BFC - Hover states
AppTheme.primaryDark           // #1744D8 - Pressed states

// Surfaces
AppTheme.surfaceColor          // #FFFFFF - Cards, modals, inputs
AppTheme.backgroundColor       // #F8F9FC - Page backgrounds
AppTheme.accentColor           // #263238 - Dark accents

// Semantic
AppTheme.successColor          // #4CAF50 - Success, completed
AppTheme.warningColor          // #FF9800 - Warnings, pending
AppTheme.errorColor            // #F44336 - Errors, destructive
AppTheme.infoColor             // #2196F3 - Information

// Text
AppTheme.textPrimaryColor      // #263238 - Body text, headings
AppTheme.textSecondaryColor    // #757575 - Secondary text
AppTheme.textDisabledColor     // #BDBDBD - Disabled text

// Borders
AppTheme.borderColor           // #E0E0E0 - Input borders
AppTheme.dividerColor          // #EEEEEE - Dividers
Color(0xFFE9F0F8)              // Card borders (light blue tint)
```

---

## Typography (Copy-Paste Ready)

```dart
// Large Headlines
Theme.of(context).textTheme.displayLarge    // 32px / Bold
Theme.of(context).textTheme.displayMedium   // 28px / SemiBold
Theme.of(context).textTheme.displaySmall    // 24px / SemiBold

// Section Headlines
Theme.of(context).textTheme.headlineLarge   // 20px / SemiBold
Theme.of(context).textTheme.headlineMedium  // 18px / SemiBold
Theme.of(context).textTheme.headlineSmall   // 16px / SemiBold

// Body Text
Theme.of(context).textTheme.bodyLarge       // 16px / Regular
Theme.of(context).textTheme.bodyMedium      // 14px / Regular
Theme.of(context).textTheme.bodySmall       // 12px / Regular - Use with textSecondaryColor

// Labels (Buttons, Inputs, Nav)
Theme.of(context).textTheme.labelLarge      // 14px / Medium
Theme.of(context).textTheme.labelMedium     // 12px / Medium
Theme.of(context).textTheme.labelSmall      // 11px / Medium

// Font: Poppins (Google Fonts) - Already configured in theme
```

---

## Spacing (Copy-Paste Ready)

```dart
AppSpacing.xs    // 4.w or 4.h   - Tight spacing, icon gaps
AppSpacing.sm    // 8.w or 8.h   - Small spacing, list items
AppSpacing.md    // 16.w or 16.h - Default spacing, card padding
AppSpacing.lg    // 24.w or 24.h - Large spacing, sections
AppSpacing.xl    // 32.w or 32.h - Extra large
AppSpacing.xxl   // 48.w or 48.h - Major sections

// Common Patterns
EdgeInsets.all(AppSpacing.md.w)                          // Card padding
EdgeInsets.symmetric(horizontal: AppSpacing.md.w)        // Screen margins
EdgeInsets.symmetric(vertical: AppSpacing.sm.h)          // List item spacing
SizedBox(height: AppSpacing.lg.h)                        // Section gap
```

---

## Border Radius (Copy-Paste Ready)

```dart
AppRadius.xs     // 4.r  - Small elements
AppRadius.sm     // 8.r  - Chips, tags
AppRadius.md     // 12.r - Cards, buttons, inputs (MOST COMMON)
AppRadius.lg     // 16.r - Large cards, modals
AppRadius.xl     // 20.r - Bottom sheets
AppRadius.full   // 9999 - Circular (badges, avatars)

// Common Usage
BorderRadius.circular(AppRadius.md.r)  // Standard cards, buttons, inputs
```

---

## Shadows (Copy-Paste Ready)

```dart
// Level 1 - Subtle (Most Cards)
boxShadow: [
  BoxShadow(
    color: Colors.black.withOpacity(0.05),
    blurRadius: 4,
    offset: Offset(0, 2),
  ),
]

// Level 2 - Moderate (Floating Elements)
boxShadow: [
  BoxShadow(
    color: Colors.black.withOpacity(0.1),
    blurRadius: 8,
    offset: Offset(0, 4),
  ),
]

// Level 3 - Strong (Modals, Important CTAs)
boxShadow: [
  BoxShadow(
    color: Colors.black.withOpacity(0.25),
    blurRadius: 9,
    offset: Offset(0, 4),
  ),
]
```

---

## Component Templates

### Standard Card

```dart
Container(
  margin: EdgeInsets.symmetric(horizontal: 16.w, vertical: 6.h),
  padding: EdgeInsets.all(16.w),
  decoration: BoxDecoration(
    color: AppTheme.surfaceColor,
    borderRadius: BorderRadius.circular(AppRadius.md.r),
    border: Border.all(color: Color(0xFFE9F0F8), width: 1),
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
      // Card content here
    ],
  ),
)
```

### Primary Button

```dart
ElevatedButton(
  style: ElevatedButton.styleFrom(
    backgroundColor: AppTheme.primaryColor,
    foregroundColor: Colors.white,
    elevation: 0,
    padding: EdgeInsets.symmetric(horizontal: 24.w, vertical: 16.h),
    shape: RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(AppRadius.md.r),
    ),
  ),
  onPressed: () {},
  child: Text('Button Text'),
)
```

### Text Input

```dart
TextField(
  decoration: InputDecoration(
    labelText: 'Label',
    hintText: 'Enter text...',
    filled: true,
    fillColor: AppTheme.surfaceColor,
    contentPadding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 16.h),
    border: OutlineInputBorder(
      borderRadius: BorderRadius.circular(AppRadius.md.r),
      borderSide: BorderSide(color: AppTheme.borderColor, width: 1),
    ),
    focusedBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(AppRadius.md.r),
      borderSide: BorderSide(color: AppTheme.primaryColor, width: 2),
    ),
  ),
)
```

### Status Badge

```dart
Container(
  padding: EdgeInsets.symmetric(horizontal: 12.w, vertical: 4.h),
  decoration: BoxDecoration(
    color: AppTheme.primaryColor,  // Or dynamic color
    borderRadius: BorderRadius.circular(AppRadius.md.r),
  ),
  child: Text(
    'Status',
    style: Theme.of(context).textTheme.labelMedium?.copyWith(
      color: Colors.white,
    ),
  ),
)
```

### Bottom Sheet

```dart
showModalBottomSheet(
  context: context,
  shape: RoundedRectangleBorder(
    borderRadius: BorderRadius.vertical(
      top: Radius.circular(AppRadius.lg.r),
    ),
  ),
  builder: (context) => Container(
    padding: EdgeInsets.all(AppSpacing.md.w),
    child: Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        // Sheet content
      ],
    ),
  ),
)
```

---

## Common Patterns

### Screen Structure

```dart
Scaffold(
  backgroundColor: AppTheme.backgroundColor,
  appBar: AppBar(
    title: Text('Title'),
  ),
  body: SafeArea(
    child: Padding(
      padding: EdgeInsets.symmetric(horizontal: AppSpacing.md.w),
      child: Column(
        children: [
          SizedBox(height: AppSpacing.lg.h),
          // Content here
        ],
      ),
    ),
  ),
)
```

### List with Cards

```dart
ListView.builder(
  padding: EdgeInsets.symmetric(vertical: AppSpacing.sm.h),
  itemCount: items.length,
  itemBuilder: (context, index) {
    return Container(
      margin: EdgeInsets.symmetric(
        horizontal: AppSpacing.md.w,
        vertical: AppSpacing.sm.h,
      ),
      // Card decoration here
    );
  },
)
```

### Icon + Text Row

```dart
Row(
  children: [
    Icon(
      Icons.calendar_today,
      size: 14.sp,
      color: AppTheme.textSecondaryColor,
    ),
    SizedBox(width: 6.w),
    Text(
      'Text here',
      style: Theme.of(context).textTheme.bodySmall,
    ),
  ],
)
```

### Header + Body Layout

```dart
Column(
  crossAxisAlignment: CrossAxisAlignment.start,
  children: [
    // Header
    Text(
      'Header Text',
      style: Theme.of(context).textTheme.headlineSmall,
    ),
    SizedBox(height: AppSpacing.sm.h),
    // Body
    Text(
      'Body text',
      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
        color: AppTheme.textSecondaryColor,
      ),
    ),
  ],
)
```

---

## Common Icons

```dart
Icons.work_outline              // Jobs, work items
Icons.calendar_today            // Dates, scheduling
Icons.access_time               // Time, duration
Icons.task_alt                  // Tasks, checklists
Icons.menu                      // Menu button
Icons.more_vert                 // Context menu (3-dot)
Icons.notifications_outlined    // Notifications
Icons.dashboard                 // Home/dashboard
Icons.list_alt                  // Lists
Icons.edit                      // Edit action
Icons.delete                    // Delete action
Icons.add                       // Create new
Icons.check_circle              // Complete, success
Icons.error_outline             // Errors
Icons.info_outline              // Information
```

---

## Responsive Design

**Always use responsive units:**

```dart
// Font sizes
fontSize: 14.sp

// Dimensions
width: 100.w
height: 50.h

// Padding/Margins
padding: EdgeInsets.all(16.w)
margin: EdgeInsets.symmetric(horizontal: 16.w, vertical: 8.h)

// Border Radius
borderRadius: BorderRadius.circular(12.r)

// Icon sizes
size: 24.sp
```

---

## DO's and DON'Ts

### ✅ DO

```dart
// ✅ Use theme colors
color: AppTheme.primaryColor

// ✅ Use spacing constants
padding: EdgeInsets.all(AppSpacing.md.w)

// ✅ Use theme text styles
style: Theme.of(context).textTheme.bodyMedium

// ✅ Use responsive units
fontSize: 14.sp, width: 100.w

// ✅ Copy existing component patterns
// (Look at JobCard, WorkDiaryEntryCard as templates)
```

### ❌ DON'T

```dart
// ❌ Don't hardcode colors
color: Color(0xFF2255FC)  // Use AppTheme.primaryColor instead

// ❌ Don't use random spacing
padding: EdgeInsets.all(13.0)  // Use AppSpacing.md.w instead

// ❌ Don't hardcode text styles
style: TextStyle(fontSize: 14)  // Use Theme.of(context).textTheme

// ❌ Don't use fixed units
fontSize: 14.0  // Use 14.sp instead

// ❌ Don't reinvent components
// Reuse existing patterns from JobCard, WorkDiaryEntryCard, etc.
```

---

## Testing Your Implementation

Before finalizing UI code, verify:

1. ✅ All colors from AppTheme
2. ✅ All spacing using AppSpacing with `.w` or `.h`
3. ✅ All text using Theme.of(context).textTheme
4. ✅ All sizes using `.sp`, `.w`, `.h`, `.r`
5. ✅ Shadows match defined levels
6. ✅ Border radius using AppRadius
7. ✅ Component pattern matches existing cards/widgets

---

## Quick Copy-Paste: Complete Screen Template

```dart
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import '../../../app/theme.dart';

class NewFeaturePage extends StatelessWidget {
  const NewFeaturePage({super.key});

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
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              SizedBox(height: AppSpacing.lg.h),

              // Section header
              Text(
                'Section Title',
                style: Theme.of(context).textTheme.headlineLarge,
              ),
              SizedBox(height: AppSpacing.md.h),

              // Card example
              Container(
                padding: EdgeInsets.all(AppSpacing.md.w),
                decoration: BoxDecoration(
                  color: AppTheme.surfaceColor,
                  borderRadius: BorderRadius.circular(AppRadius.md.r),
                  border: Border.all(color: Color(0xFFE9F0F8), width: 1),
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
                      'Card Title',
                      style: Theme.of(context).textTheme.headlineSmall,
                    ),
                    SizedBox(height: AppSpacing.sm.h),
                    Text(
                      'Card content text',
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        color: AppTheme.textSecondaryColor,
                      ),
                    ),
                  ],
                ),
              ),

              SizedBox(height: AppSpacing.lg.h),

              // Button example
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: () {},
                  child: Text('Action Button'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
```

---

## Need More Details?

For complete documentation, component specifications, and usage guidelines, see:
- **[Complete Design System](DESIGN_SYSTEM.md)** - Full documentation
- **[Existing Components](../lib/features/)** - Reference implementations
- **[Theme File](../lib/app/theme.dart)** - Theme configuration

---

**Remember:** Consistency is key! Always reference existing components (JobCard, WorkDiaryEntryCard) as templates when creating new UI elements.
