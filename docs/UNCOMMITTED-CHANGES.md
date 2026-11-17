# Uncommitted Changes - powerca_mobile

**Branch:** `feature-branch-1`
**Generated:** 2026-11-14
**Total:** 50 modified files (+7,692 / -14,438 lines) and 7 new files/folders

> **Before committing:** `lib/features/auth/presentation/pages/splash_page.dart` still has the
> temporary splash preview flag `const bool _kPreviewSplash = true;`. Set it to `false` or remove it
> (search for `TEMP (splash preview)`), otherwise logged-out users never get the session check.

---

## Summary of the work

1. **New "soft" UI style across the app**: Geist font bundled locally, shared style kit
   (`soft_page.dart`, `soft_ui.dart`, `home_style.dart`, `auth_sheet.dart`), and most pages restyled to use it.
2. **New Home page**: two-tone headline, "My work log" weekly carousel with day status badges and an info legend,
   and a new "My work log" page with daily entries plus a "Work log overview" page.
3. **Appointments (UI only)**: staff can book, view, complete and cancel client appointments.
   Data is kept in memory only (no Supabase table yet), so it is lost on app restart.
4. **Help & Support links fixed**: email, website and phone links now open on Android 11+.
5. **Friendly network errors**: "No internet" / "timed out" messages with a Retry button instead of raw errors.
6. **Work log reminder notification**: shown at most once per day.

---

## New files (untracked)

| Path | What it is |
|------|------------|
| `assets/fonts/` | Geist font files (Light to ExtraBold) + `OFL.txt` licence |
| `lib/core/utils/error_messages.dart` | `ErrorMessages.friendly(e)` - turns network/timeout errors into user-friendly text |
| `lib/features/appointments/domain/appointment.dart` | `Appointment` model, `AppointmentMode` (office / client site / call), `AppointmentStatus` |
| `lib/features/appointments/data/appointment_store.dart` | In-memory appointment store (add, list upcoming, clash check, set status) |
| `lib/features/appointments/presentation/appointments_card.dart` | Home "Appointments" card, list rows and details bottom sheet |
| `lib/features/appointments/presentation/book_appointment_page.dart` | Book appointment form (client picker from `climaster`, date/time, duration, mode, notes) |
| `lib/shared/widgets/auth_sheet.dart` | Shared layout for splash / sign-in / phone / OTP screens |
| `lib/shared/widgets/home_style.dart` | Home styles (`HomeHeadline`, `HomeDarkPill`) |
| `lib/shared/widgets/soft_page.dart` | Page kit (`SoftPalette`, `SoftPageHeader`, `SoftPillButton`, `SoftStatusPill`, ...) |
| `lib/shared/widgets/soft_ui.dart` | Form kit (`softInputDecoration`, `SoftFieldLabel`) |

---

## Modified files

### Config / app

| File | +/- | Change |
|------|-----|--------|
| `android/app/src/main/AndroidManifest.xml` | +13 / -0 | Added `<queries>` for https, mailto and tel intents (needed for links on Android 11+) |
| `pubspec.yaml` | +17 / -11 | Registered local Geist font family |
| `lib/main.dart` | +21 / -14 | App setup / route updates for the new UI |
| `lib/app/theme.dart` | +138 / -80 | Theme updated to the soft style and Geist font |
| `lib/core/services/notification_service.dart` | +29 / -2 | Work log reminder limited to once per day; added `cancelWorkLogReminder()` |

### Auth & device security

| File | +/- | Change |
|------|-----|--------|
| `features/auth/.../splash_page.dart` | +103 / -237 | Restyled. **Contains TEMP preview flag - revert before commit** |
| `features/auth/.../sign_in_page.dart` | +74 / -229 | Restyled with auth sheet |
| `features/auth/.../select_concern_location_page.dart` | +220 / -389 | Restyled |
| `features/device_security/.../security_gate_page.dart` | +66 / -245 | Restyled phone entry |
| `features/device_security/.../phone_verification_page.dart` | +81 / -282 | Restyled |
| `features/device_security/.../otp_verification_page.dart` | +84 / -179 | Restyled |
| `features/device_security/.../otp_input_field.dart` | +7 / -7 | Style tweaks |

### Home / work log

| File | +/- | Change |
|------|-----|--------|
| `features/home/.../dashboard_page.dart` | +1197 / -638 | New Home (headline, week carousel with status badges, info legend, Appointments card), "My work log" page, "Work log overview" page |
| `features/home/.../modern_work_calendar.dart` | +52 / -18 | Friendly network error + Retry button |
| `features/home/.../work_log_entry_form_page.dart` | +1452 / -1293 | Restyled form |
| `features/home/.../work_log_list_page.dart` | +93 / -581 | Restyled |
| `features/home/.../work_log_detail_page.dart` | +222 / -739 | Restyled |
| `features/home/.../work_log_checklist_page.dart` | +130 / -506 | Restyled |
| `features/home/.../profile_header.dart` | +3 / -3 | Small style tweak |

### Jobs

| File | +/- | Change |
|------|-----|--------|
| `features/jobs/.../jobs_page.dart` | +147 / -404 | Restyled |
| `features/jobs/.../jobs_filtered_page.dart` | +239 / -675 | Restyled |
| `features/jobs/.../job_detail_page.dart` | +233 / -735 | Restyled |
| `features/jobs/.../task_checklist_detail_page.dart` | +108 / -414 | Restyled |

### Leave

| File | +/- | Change |
|------|-----|--------|
| `features/leave/.../leave_page.dart` | +127 / -422 | Restyled |
| `features/leave/.../leave_filtered_page.dart` | +101 / -421 | Restyled |
| `features/leave/.../leave_detail_page.dart` | +129 / -632 | Restyled |
| `features/leave/.../apply_leave_page.dart` | +397 / -512 | Restyled |

### Pinboard

| File | +/- | Change |
|------|-----|--------|
| `features/pinboard/.../pinboard_page.dart` | +18 / -20 | Style tweaks |
| `features/pinboard/.../pinboard_main_page.dart` | +177 / -400 | Restyled |
| `features/pinboard/.../pinboard_category_list_page.dart` | +137 / -278 | Restyled |
| `features/pinboard/.../pinboard_detail_page.dart` | +65 / -242 | Restyled |
| `features/pinboard/.../comments_tab.dart` | +52 / -131 | Restyled |
| `features/pinboard/.../event_details_tab.dart` | +38 / -216 | Restyled |

### Profile, settings, work diary

| File | +/- | Change |
|------|-----|--------|
| `features/profile/.../profile_page.dart` | +125 / -534 | Restyled |
| `features/settings/.../settings_page.dart` | +149 / -444 | Restyled |
| `features/settings/.../app_update_page.dart` | +130 / -441 | Restyled |
| `features/settings/.../help_support_page.dart` | +295 / -782 | Restyled; email/website/phone links fixed (`launchUrl` with error snackbar) |
| `features/work_diary/.../add_work_diary_entry_page.dart` | +68 / -237 | Restyled |
| `features/work_diary/.../work_diary_list_page.dart` | +157 / -256 | Restyled |
| `features/work_diary/.../work_diary_entry_card.dart` | +35 / -132 | Restyled |

### Shared widgets

| File | +/- | Change |
|------|-----|--------|
| `shared/widgets/app_drawer.dart` | +219 / -311 | Restyled drawer |
| `shared/widgets/app_header.dart` | +203 / -102 | Restyled header |
| `shared/widgets/modern_bottom_navigation.dart` | +210 / -118 | Restyled bottom nav |
| `shared/widgets/app_bottom_navigation.dart` | +1 / -1 | Small tweak |
| `shared/widgets/custom_button.dart` | +14 / -3 | Style tweak |
| `shared/widgets/empty_state.dart` | +19 / -32 | Style tweak |
| `shared/widgets/error_widget.dart` | +19 / -27 | Style tweak |
| `shared/widgets/loading_indicator.dart` | +14 / -11 | Style tweak |
| `shared/widgets/notification_settings_bottom_sheet.dart` | +35 / -23 | Style tweak |
| `shared/widgets/update_dialog.dart` | +29 / -29 | Style tweak |

---

## Known follow-ups

- Revert the splash preview flag (see top).
- Appointments are UI-only; add a Supabase table to persist them.
- About 24 other screens still show raw `'Error: $e'` text; these can be switched to `ErrorMessages.friendly(e)`.
