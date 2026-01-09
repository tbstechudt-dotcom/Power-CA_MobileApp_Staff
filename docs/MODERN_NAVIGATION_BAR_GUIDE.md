# Modern Bottom Navigation Bar Guide

## Overview

The `ModernBottomNavigation` widget provides a sleek, modern navigation experience with the following features:

- **Floating Action Button (FAB)** - Center-positioned elevated button for primary actions
- **Smooth Animations** - Scale and fade animations for selected items
- **Active Indicators** - Dynamic progress bars showing active navigation items
- **Glassmorphism Design** - Modern, clean aesthetic with shadows and gradients
- **Quick Actions Sheet** - Bottom sheet with quick access to common actions
- **Customizable** - Easy to customize colors, icons, and actions

## Files Created

1. **`lib/shared/widgets/modern_bottom_navigation.dart`** - The main navigation widget
2. **`lib/features/home/presentation/pages/dashboard_page_modern_nav.dart`** - Example usage
3. **`docs/MODERN_NAVIGATION_BAR_GUIDE.md`** - This documentation

## Features

### 1. Floating Action Button
- Center-positioned elevated button with gradient background
- Ripple effect on tap
- Customizable action via `onAddPressed` callback
- Default behavior shows quick actions bottom sheet

### 2. Navigation Items
- Smooth scale animation when selected
- Icon changes from outlined to filled when active
- Active indicator bar with animated width
- Label with opacity animation
- Background highlight for selected item

### 3. Quick Actions Bottom Sheet
- Triggered by FAB when no custom action is provided
- Pre-configured actions:
  - New Job
  - Log Work Time
  - Leave Request
- Customizable actions with icons, colors, and callbacks

## Installation

### Step 1: Add the Widget to Your Project

The widget files are already created:
- `lib/shared/widgets/modern_bottom_navigation.dart`
- `lib/features/home/presentation/pages/dashboard_page_modern_nav.dart`

### Step 2: Replace Existing Navigation

In your existing page (e.g., `dashboard_page.dart`), replace:

```dart
// OLD
AppBottomNavigation(
  currentIndex: 0,
  currentStaff: currentStaff,
),
```

With:

```dart
// NEW
ModernBottomNavigation(
  currentIndex: 0,
  currentStaff: currentStaff,
  onAddPressed: () {
    // Optional: Custom action when FAB is pressed
    // If not provided, default quick actions sheet is shown
  },
),
```

## Usage Examples

### Basic Usage

```dart
import 'package:powerca_mobile/shared/widgets/modern_bottom_navigation.dart';

class MyPage extends StatelessWidget {
  final Staff currentStaff;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: YourContent(),
      bottomNavigationBar: ModernBottomNavigation(
        currentIndex: 0,
        currentStaff: currentStaff,
      ),
    );
  }
}
```

### Custom FAB Action

```dart
ModernBottomNavigation(
  currentIndex: 0,
  currentStaff: currentStaff,
  onAddPressed: () {
    // Show custom dialog
    showDialog(
      context: context,
      builder: (context) => MyCustomDialog(),
    );
  },
),
```

### Default Quick Actions Sheet

If you don't provide `onAddPressed`, the FAB will automatically show a quick actions sheet with:
- New Job
- Log Work Time
- Leave Request

### Update All Pages

Update the navigation in all your main pages:

1. **Dashboard Page** (`/dashboard`)
```dart
ModernBottomNavigation(
  currentIndex: 0,
  currentStaff: currentStaff,
),
```

2. **Jobs Page** (`/jobs`)
```dart
ModernBottomNavigation(
  currentIndex: 1,
  currentStaff: currentStaff,
),
```

3. **Leave Requests Page** (`/leave-requests`)
```dart
ModernBottomNavigation(
  currentIndex: 2,
  currentStaff: currentStaff,
),
```

4. **Profile/Pinboard Page** (`/pinboard`)
```dart
ModernBottomNavigation(
  currentIndex: 3,
  currentStaff: currentStaff,
),
```

## Customization

### Change Navigation Items

Edit the navigation items in `modern_bottom_navigation.dart` (lines 94-166):

```dart
_buildNavItem(
  context: context,
  icon: Icons.your_icon_outlined,      // Outlined icon
  selectedIcon: Icons.your_icon,       // Filled icon
  label: 'Your Label',
  index: 0,
  animation: _animations[0],
  onTap: () => _navigateTo(context, '/your-route', 0),
),
```

### Change Colors

Update the gradient colors in the FAB (lines 171-178):

```dart
gradient: const LinearGradient(
  begin: Alignment.topLeft,
  end: Alignment.bottomRight,
  colors: [
    Color(0xFF0846B1),  // Your primary color
    Color(0xFF2255FC),  // Your secondary color
  ],
),
```

### Change Quick Actions

Edit the quick actions sheet in `_showQuickActionsSheet()` method (lines 319-409):

```dart
_buildQuickActionItem(
  icon: Icons.your_icon,
  title: 'Your Action Title',
  subtitle: 'Your action description',
  color: const Color(0xFF2196F3),
  onTap: () {
    Navigator.pop(context);
    // Your custom action
  },
),
```

### Adjust Navigation Bar Height

Change the height in line 87:

```dart
height: 75.h,  // Adjust this value
```

### Adjust FAB Position

Change the top offset in line 148:

```dart
top: -28.h,  // Adjust this value (negative = above the bar)
```

### Adjust FAB Size

Change the FAB dimensions in lines 161-162:

```dart
width: 64.w,   // Adjust width
height: 64.h,  // Adjust height
```

## Animation Details

### Scale Animation
- Duration: 200ms
- Curve: `Curves.easeInOut`
- Scale factor: 1.0 to 1.15 (15% increase)

### Opacity Animation
- Duration: 200ms
- Curve: `Curves.easeInOut`
- Opacity: 0.6 to 1.0

### Active Indicator Animation
- Duration: 200ms
- Curve: `Curves.easeInOut`
- Width: 0 to 20.w

## Navigation Routes

The navigation bar uses these routes:

| Index | Route | Label | Icon |
|-------|-------|-------|------|
| 0 | `/dashboard` | Home | home_rounded |
| 1 | `/jobs` | Jobs | work_rounded |
| 2 | `/leave-requests` | Leave | calendar_month_rounded |
| 3 | `/pinboard` | Profile | person_rounded |

Make sure these routes are defined in your `app/routes.dart`:

```dart
static Route<dynamic> generateRoute(RouteSettings settings) {
  final args = settings.arguments;

  switch (settings.name) {
    case '/dashboard':
      return MaterialPageRoute(
        builder: (_) => DashboardPage(currentStaff: args as Staff),
      );
    case '/jobs':
      return MaterialPageRoute(
        builder: (_) => JobListPage(currentStaff: args as Staff),
      );
    case '/leave-requests':
      return MaterialPageRoute(
        builder: (_) => LeaveRequestsPage(currentStaff: args as Staff),
      );
    case '/pinboard':
      return MaterialPageRoute(
        builder: (_) => PinboardPage(currentStaff: args as Staff),
      );
    // ... other routes
  }
}
```

## Troubleshooting

### Issue: Navigation doesn't animate
**Solution**: Make sure your page widget is wrapped in `Scaffold` and has proper routing setup.

### Issue: FAB position is off
**Solution**: Adjust the `top` value in the `Positioned` widget (line 148):
```dart
top: -28.h,  // Increase/decrease to move FAB up/down
```

### Issue: Bottom sheet doesn't show
**Solution**: Check that your `Navigator` context is correct and the modal sheet can overlay.

### Issue: Icons don't change on selection
**Solution**: Verify that both `icon` and `selectedIcon` are provided and different.

### Issue: Navigation clears stack
**Solution**: Use `pushReplacementNamed` instead of `pushNamedAndRemoveUntil` for non-home pages.

## Performance Notes

- Uses `TickerProviderStateMixin` for efficient animations
- Animation controllers are properly disposed in `dispose()`
- List generation is optimized with `List.generate`
- Animations only run when navigation index changes

## Accessibility

The navigation bar includes:
- Semantic labels for screen readers
- Touch target size meets accessibility guidelines (42x42 minimum)
- High contrast between active/inactive states
- Visual feedback on tap (ripple effect)

## Dependencies

Required packages (already in your `pubspec.yaml`):
- `flutter_screenutil` - Responsive sizing
- `flutter/material.dart` - Material Design widgets

## Future Enhancements

Potential improvements:
1. Add badge support for notifications
2. Add long-press tooltips
3. Add custom FAB icons per page
4. Add haptic feedback on tap
5. Add swipe gestures between pages
6. Add page transition animations
7. Add dark mode support

## Credits

Created for PowerCA Mobile App
Design inspired by modern mobile UI/UX trends
Implements Material Design 3 principles

## Support

For issues or questions:
1. Check this documentation
2. Review the example implementation in `dashboard_page_modern_nav.dart`
3. Check the widget source code in `modern_bottom_navigation.dart`

---

**Last Updated**: 2025-11-07
**Version**: 1.0.0
**Author**: Claude Code
