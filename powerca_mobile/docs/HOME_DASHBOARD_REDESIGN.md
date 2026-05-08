# Home Dashboard Card Redesign

Documentation of UI changes made to the home dashboard summary cards in the PowerCA Mobile app.

## Files Modified

- `lib/features/home/presentation/pages/dashboard_page.dart`
- `lib/features/home/presentation/widgets/modern_work_calendar.dart`

---

## 1. Stat Cards (Logged Days / Leave Days)

Two side-by-side gradient cards displaying monthly statistics.

### Design

| Element | Details |
|---|---|
| Background | Linear gradient (top-left → bottom-right) |
| Logged Days gradient | `#60A5FA → #3B82F6` (blue) |
| Leave Days gradient | `#A78BFA → #8B5CF6` (purple) |
| Card height | `140.h` |
| Border radius | `16.r` |
| Shadow | Gradient color at 25% alpha, 10 blur, offset (0, 3) |

### Layout

```
+-------------------------------+
| [icon]              [ April ] |
|                               |
|                               |
| 0                             |
| Logged Days        [watermark]|
+-------------------------------+
```

### Components

- **Icon container** (top-left)
  - White 20% alpha background, 10.r radius
  - White icon, 18.sp size
- **Month badge** (top-right)
  - White 22% alpha background, 8.r radius
  - White text, 11.sp, weight 600
- **Value** (bottom-left)
  - White, 32.sp, weight 700, letter-spacing -0.8
- **Title** (below value)
  - White 90% alpha, 12.sp, weight 500
- **Watermark icon** (bottom-right)
  - 90.sp size, white 15% alpha
  - Positioned `right: -20.w, bottom: -20.h` (clipped by ClipRRect)

### Code Reference

`_buildStatTile` method in `dashboard_page.dart`.

---

## 2. Day Status Card (Today / Selected Date)

Full-width card showing the selected day's work log summary.

### Design

| Element | Details |
|---|---|
| Background | Solid `cardBg` (white in light mode, `#1E293B` in dark) |
| Border | 1px `borderColor` (`#E2E8F0` light / `#334155` dark) |
| Border radius | `16.r` |
| Card height | `190.h` |
| Padding | `18.w` horizontal, `16.h` vertical |

### Layout

```
+---------------------------------------------------+
| [icon] Today                  • Not Logged        |
|        Work log summary                           |
| --------------------------------------------- |
| HOURS              | ENTRIES                      |
| 0h 0m              | 0 entries                    |
+---------------------------------------------------+
   [<]                                          [>]
```

### Components

- **Header row**
  - Icon container (left): accent-tinted background, 22.sp icon
  - Date label + "Work log summary" subtitle
  - Status pill (right) with colored dot indicator
- **Divider** (1px line in `dividerColor`)
- **Stats row**
  - HOURS section (left): label + workingHours value
  - Vertical divider (1px, 36.h)
  - ENTRIES section (right): label + log count
- **Overlay arrow buttons** (vertically centered)
  - Circular 34.w buttons, white/dark background
  - 1px border in `borderColor`
  - Left arrow at `left: 8.w`
  - Right arrow at `right: 8.w` (dimmed when disabled)

### Status Pills

Status colors driven by the gradient passed into the card:

| Status | Accent color | Source |
|---|---|---|
| Active | `#10B981` (green) | Has logged entries |
| On Leave | `#F59E0B` (amber) | Date is in leave list |
| Not Logged | `#64748B` (slate) | No logged entries |

### Code Reference

- `_buildSwipeableDayStatus` — wrapper with PageView + overlay arrows
- `_buildDayStatusCard` — the card itself
- `_buildOverlayArrow` — circular arrow button
- `_getDayInfo` — determines status, gradient, and stats per date

---

## 3. Removed Elements

| Element | Reason |
|---|---|
| `Working` / `Holidays` count badges on calendar | Cluttered the calendar header |
| `Today` button below the day card | Redundant — swipe + arrows are enough |
| `_buildNavButton` helper | No longer used |
| `_calculateHolidays` method | No longer needed |
| `_holidaysInMonth` / `_workingDaysInMonth` fields | Unused after badge removal |
| `_goToToday` / `_isSelectedDateToday` helpers | Today button removed |

---

## 4. Color Tokens Used

| Token | Light mode | Dark mode |
|---|---|---|
| `cardBg` | `Colors.white` | `#1E293B` |
| `borderColor` | `#E2E8F0` | `#334155` |
| `titleColor` | `#0F172A` | `#F1F5F9` |
| `subtitleColor` | `#64748B` | `#94A3B8` |
| `dividerColor` | `#E2E8F0` | `#334155` |

---

## 5. Typography

All text uses the **Inter** font family.

| Element | Size | Weight | Letter spacing |
|---|---|---|---|
| Stat card value | 32.sp | 700 | -0.8 |
| Stat card title | 12.sp | 500 | — |
| Stat card month badge | 11.sp | 600 | 0.2 |
| Day card date label | 17.sp | 700 | -0.2 |
| Day card subtitle | 11.sp | 500 | — |
| Day card status pill | 11.sp | 600 | — |
| Section labels (HOURS, ENTRIES) | 10.sp | 600 | 0.6 |
| Section values | 20.sp | 700 | -0.3 |

---

## 6. Theme Support

All cards adapt to dark mode via `Provider.of<ThemeProvider>(context).isDarkMode`. Colors are pre-resolved at the top of each builder so the gradient cards keep their solid look while the day status card swaps to the dark surface.

---

## 7. Version

These changes were committed as part of:

- **Branch:** `feature-branch-1`
- **Commit:** `1ed1ef6` (Update dashboard cards UI and remove calendar working/holidays badges)
- **App version:** `1.1.0+10`
