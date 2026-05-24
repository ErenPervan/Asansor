# UI/UX Audit Report — Asansor Flutter App

**Audit Date:** 2026-05-24  
**Scope:** Full `lib/` directory – all screens, widgets, routing, theme, and navigation  
**Auditor:** Expert UI/UX Designer & Senior Flutter Developer (AI)

---

## Executive Summary

The application has a **strong visual foundation**. The design system (`AppColors`, `AppSpacing`), Riverpod state management, and GoRouter navigation are all well-structured. Login, the home screen, and the fault detail view are particularly polished. However, several systemic issues exist across three major dimensions:

1. **Incomplete Navigation** – The bottom nav bar has two dead/partially-wired buttons
2. **Theming Inconsistencies** – Hardcoded colors persist in customer-facing views despite a working design system
3. **Missing UX Flows** – Several screens have no confirmation for destructive actions, no success state after submission, or no graceful degradation path

---

## 🚨 CRITICAL ISSUES (Missing States & Broken Flows)

---

### C-01 · Bottom Nav Bar — "Arızalar" Tab is Dead

**File:** [`lib/core/widgets/app_bottom_nav_bar.dart:37`](file:///d:/Asansor/lib/core/widgets/app_bottom_nav_bar.dart#L37-L38)

```dart
_NavItem(
  icon: Icons.error_outline,
  label: 'Arızalar',
  isActive: currentIndex == 1,
  onPressed: () {}, // Route implementation pending
),
```

**Problem:** The "Arızalar" (Faults) tab is completely non-functional. Tapping it does nothing. This is the most prominently placed call-to-action in the app for technicians, yet it leads nowhere.

**Impact:** Users will tap this repeatedly and assume the app is broken.

**Fix Required:** Either route to a `/faults` list view (highest value), or replace temporarily with another meaningful action. Do not ship a dead nav tab.

---

### C-02 · Bottom Nav Bar — "Program" Tab Disabled for Technicians

**File:** [`lib/core/widgets/app_bottom_nav_bar.dart:40-47`](file:///d:/Asansor/lib/core/widgets/app_bottom_nav_bar.dart#L40-L47)

```dart
_NavItem(
  icon: Icons.event_note_outlined,
  label: 'Program',
  isActive: currentIndex == 2,
  onPressed: isAdmin
      ? () => context.go('/admin/master-calendar')
      : null, // ← Technicians get null = non-tappable
),
```

**Problem:** When `onPressed` is `null`, the `_NavItem` widget returns a plain `child` widget (not wrapped in `InkWell`). Technicians see a "Program" tab that appears enabled (icon + label shown) but is completely inert. There's no visual feedback, no disabled state, no explanation.

**Fix Required:** Route technicians to `/admin/calendar` (their personal schedule view), or visually gray out and add a tooltip. Never present a tappable-looking element that does nothing.

---

### C-03 · `ElevatorDetailView` — `more_vert` Button Has No Action

**File:** [`lib/features/elevator/views/elevator_detail_view.dart:51-54`](file:///d:/Asansor/lib/features/elevator/views/elevator_detail_view.dart#L51-L54)

```dart
IconButton(
  icon: const Icon(Icons.more_vert, color: AppColors.primary),
  onPressed: () {}, // ← Empty callback
),
```

**Problem:** A prominent overflow menu button in the AppBar does nothing when tapped. Users will press this expecting options (delete elevator, edit info, share, etc.) and get zero feedback.

**Fix Required:** Either implement actions (e.g. Edit Elevator, View QR Code, Share) or remove the button entirely.

---

### C-04 · `CustomerDashboardView` — No Offline State

**File:** [`lib/features/customer/views/customer_dashboard_view.dart`](file:///d:/Asansor/lib/features/customer/views/customer_dashboard_view.dart)

**Problem:** The customer dashboard has no `OfflineBanner`. Unlike the technician home view and elevator list view (which both include `const OfflineBanner()`), the customer-facing dashboard shows nothing when the user is offline. A customer looking at a cached elevator status with no internet connection has no way to know the data might be stale.

**Fix Required:** Add `const OfflineBanner()` after the AppBar, consistent with other views.

---

### C-05 · `FaultDetailView` — Loading State is a Plain Spinner

**File:** [`lib/features/fault/views/fault_detail_view.dart:33-34`](file:///d:/Asansor/lib/features/fault/views/fault_detail_view.dart#L33-L34)

```dart
loading: () =>
    const Scaffold(body: Center(child: CircularProgressIndicator())),
```

**Problem:** While the fault data is loading, a bare `CircularProgressIndicator` is shown on a white `Scaffold` — no AppBar, no branded colors, no skeleton. This is jarring compared to the polished detail screen that loads after. The `ElevatorDetailView` and `ElevatorListView` both use the `LoadingState` shimmer widget properly.

**Fix Required:** Replace with the app's `LoadingState` widget (shimmer), or at minimum add a consistent `AppBar` and branded background during the loading phase.

---

### C-06 · `MaintenanceLogEntryView` — Success Dialog Auto-Dismisses Without Letting User Read

**File:** [`lib/features/maintenance/views/maintenance_log_entry_view.dart:265-321`](file:///d:/Asansor/lib/features/maintenance/views/maintenance_log_entry_view.dart#L265-L321)

**Problem:** The success dialog (`AlertDialog`) is displayed but auto-dismissed after **1.5 seconds** with no user action. This is not enough time for users to process the confirmation, especially on slower phones. Additionally, the dialog has no dismiss button or "View Report" CTA — it just vanishes and navigates away.

**Fix Required:** Add an "OK" button to the dialog. Let the user acknowledge success actively. Remove the `Future.delayed(1500ms)` auto-dismiss.

---

### C-07 · `MaintenanceLogEntryView` — AppBar Uses Theme Default (Inconsistent)

**File:** [`lib/features/maintenance/views/maintenance_log_entry_view.dart:360`](file:///d:/Asansor/lib/features/maintenance/views/maintenance_log_entry_view.dart#L360)

```dart
appBar: AppBar(title: const Text('Yeni Bakım Formu')),
```

**Problem:** Every other primary view explicitly sets `backgroundColor: AppColors.primary` (elevator list) or `AppColors.background` (elevator detail). This view uses the default theme AppBar, which may render differently depending on `ThemeData` configuration. The visual inconsistency is immediately noticeable when navigating from the styled `ElevatorDetailView`.

**Fix Required:** Explicitly style the AppBar to match the design language (primary color header or transparent).

---

## ⚠️ HIGH UX FLAWS

---

### H-01 · `ElevatorSystemMonitor` — "Randevu Düzenle" is a Dead Button

**File:** [`lib/features/elevator/widgets/detail/elevator_system_monitor.dart:198-208`](file:///d:/Asansor/lib/features/elevator/widgets/detail/elevator_system_monitor.dart#L198-L208)

```dart
Container(
  // ...
  alignment: Alignment.center,
  child: const Text(
    'Randevu Düzenle',  // ← Static text, no tap handler
```

**Problem:** This appears as a tappable button in the "Sıradaki Bakım" (Next Maintenance) panel but is just a styled `Container` with static text — it has no `GestureDetector` or `InkWell`. Users will tap it expecting to schedule/view maintenance and nothing happens.

**Fix Required:** Either wire this to `/admin/calendar` (for admins) or a technician view, or remove it and replace with a non-interactive informational label.

---

### H-02 · `CustomerDashboardView` — Hardcoded Colors Violate Design System

**File:** [`lib/features/customer/views/customer_dashboard_view.dart:248-272`](file:///d:/Asansor/lib/features/customer/views/customer_dashboard_view.dart#L248-L272)

The maintenance log list uses multiple hardcoded raw colors:
- `Colors.white` (card background)
- `Colors.grey.shade200` (border)
- `Colors.black.withValues(alpha: 0.02)` (shadow)
- `Colors.black54` (subtitle)
- `const Color(0xFFF3F4F6)` (icon background)
- `const Color(0xFF4B5563)` (icon color)
- `Colors.black87` (section title)

**Problem:** This entire view will not adapt to dark mode. All other views use `AppColors.*` tokens that switch with the theme. Customer-facing screens are arguably the highest-visibility views since customers aren't power users — visual polish here matters most.

**Fix Required:** Replace all hardcoded colors with `AppColors.*` equivalents.

---

### H-03 · Sign-Out Has No Confirmation Dialog (Anywhere)

**Files:**  
- [`lib/features/elevator/widgets/home/home_top_app_bar.dart:110`](file:///d:/Asansor/lib/features/elevator/widgets/home/home_top_app_bar.dart#L110)  
- [`lib/features/customer/views/customer_dashboard_view.dart:39-42`](file:///d:/Asansor/lib/features/customer/views/customer_dashboard_view.dart#L39-L42)
- [`lib/features/elevator/views/customer_no_elevator_view.dart:43-44`](file:///d:/Asansor/lib/features/elevator/views/customer_no_elevator_view.dart#L43-L44)

**Problem:** Tapping "Çıkış Yap" (Sign Out) triggers immediate sign-out with no confirmation dialog. On the home screen, this is a small icon button right next to the admin panel shortcut. A misclick will log a technician out in the middle of a maintenance session, potentially losing unsaved state.

**Fix Required:** Show a `showDialog` confirmation (`AlertDialog` with "Oturumu Kapat" / "İptal" buttons) before signing out. This is especially critical on the home screen where the logout button is adjacent to other action buttons.

---

### H-04 · `HomeView` — Admin users see "DURUM: AKTİF" which is hardcoded and always wrong

**File:** [`lib/features/elevator/widgets/home/home_top_app_bar.dart:57-65`](file:///d:/Asansor/lib/features/elevator/widgets/home/home_top_app_bar.dart#L57-L65)

```dart
Text(
  'DURUM: AKTİF', // ← Always shows "ACTIVE" regardless of actual status
  style: TextStyle(fontSize: 10, ...),
),
```

**Problem:** The status label is hardcoded to always display "DURUM: AKTİF". It should reflect the actual connectivity/sync state. When the user is offline (the `OfflineBanner` is visible below), the header still says "DURUM: AKTİF" — a clear contradiction.

**Fix Required:** Make this dynamic: show "DURUM: ÇEVRİMDIŞI" when `isOnline == false`, "DURUM: SENKRONIZE EDİLİYOR" when there are pending sync items, and "DURUM: AKTİF" only when fully online and synced.

---

### H-05 · `FaultDetailView` — Error Snackbar Uses Wrong Color for Errors

**File:** [`lib/features/fault/views/fault_detail_view.dart:503-508`](file:///d:/Asansor/lib/features/fault/views/fault_detail_view.dart#L503-L508)

```dart
SnackBar(
  content: Text('Hata: $err'),
  backgroundColor: AppColors.primary, // ← Should be AppColors.error!
```

**Problem:** When a fault resolve/reopen operation fails, the error snackbar is shown with `AppColors.primary` (the brand red/crimson) rather than `AppColors.error`. While they may look similar, semantically this is wrong and could confuse maintenance when the primary color changes. The same pattern appears in `_handleReopen()`.

**Fix Required:** Change `backgroundColor: AppColors.primary` to `backgroundColor: AppColors.error` for error feedback snackbars.

---

### H-06 · `SyncStatusButton` — Offline Icon Color is Incorrect

**File:** [`lib/features/elevator/widgets/home/home_top_app_bar.dart:153-155`](file:///d:/Asansor/lib/features/elevator/widgets/home/home_top_app_bar.dart#L153-L155)

```dart
if (!isOnline) {
  icon = Icons.cloud_off_outlined;
  color = AppColors.primary; // ← Should be AppColors.error or a warning color
```

Also in `SyncSheet`:
```dart
Icon(Icons.wifi_off_rounded, color: AppColors.primary, size: 18),
Text('...', style: TextStyle(fontSize: 12, color: AppColors.primary)),
```

**Problem:** Offline status is shown in the brand primary color (crimson). Offline/disconnected is a warning/error state, not a primary action state. It blends visually with normal interactive elements. The `OfflineBanner` correctly uses an amber color for this state.

**Fix Required:** Use `AppColors.warning` or `const Color(0xFFD97706)` (amber, already used for sync pending) for the offline icon color.

---

### H-07 · `ElevatorListView` — `Scaffold.backgroundColor` Uses Static `AppColors.background` Instead of Dynamic Token

**File:** [`lib/features/elevator/views/elevator_list_view.dart:106`](file:///d:/Asansor/lib/features/elevator/views/elevator_list_view.dart#L106)

```dart
backgroundColor: AppColors.background, // static, light-mode only
```

**Problem:** `AppColors.background` is a static constant (light mode only). Other views correctly use `AppThemeColors.of(context).background` (or `colors.background`) which resolves the correct value for the current theme brightness. This means the elevator list will not properly support dark mode.

The same issue exists in `FaultDetailView`, `ElevatorDetailView`, and `CustomerDashboardView`.

**Fix Required:** Replace static `AppColors.*` references for `backgroundColor` with `AppThemeColors.of(context).*` equivalents throughout all views.

---

## 📋 MEDIUM UX FINDINGS

---

### M-01 · `HomeView` — Admin Users Have No Quick-Stat Overview

**Problem:** The home view's `StatsSection` shows "Active Faults" and "Completed Today" counts derived from the technician's own schedule. Admin users, who open the same home view, see technician-scoped stats with no summary of their fleet (e.g. total active faults across all technicians, total maintenance done today).

**Fix Required:** Make `StatsSection` role-aware. Show admin-scoped KPIs when `isAdmin == true`.

---

### M-02 · `DailyAgendaSection` — "Upcoming" Tasks Silently Truncated to 3

**File:** [`lib/features/elevator/widgets/home/home_daily_agenda.dart:128-147`](file:///d:/Asansor/lib/features/elevator/widgets/home/home_daily_agenda.dart#L128-L147)

```dart
...upcomingTasks.take(3).map(...),
if (upcomingTasks.length > 3)
  Text('+${upcomingTasks.length - 3} daha görev var.'),
```

**Problem:** Upcoming tasks beyond 3 are truncated and shown only as a plain text "N more tasks" label. This text is not tappable and provides no navigation to the full calendar. A technician with 5 scheduled tasks only sees 3 on their home screen.

**Fix Required:** Make the "+N daha görev var" text a tappable `TextButton` that navigates to `/admin/calendar`, or add a "Tümünü Gör" header button on the section.

---

### M-03 · `ScannerView` — Camera Permission Denied State Not Handled

**File:** [`lib/features/elevator/views/scanner_view.dart`](file:///d:/Asansor/lib/features/elevator/views/scanner_view.dart)

**Problem:** The `MobileScanner` widget is initialized and rendered directly in the body. There is no handling for camera permission denial. If the user denies camera access, `MobileScanner` will display a blank/black screen with no explanation or path to recovery (e.g. a button to open Settings).

**Fix Required:** Wrap the scanner body in a `StreamBuilder` on `controller.state` and show an `ErrorState` widget with "Kamera izni gerekli — Ayarlar'dan izin verin" if the state is `cameraPermissionDenied`.

---

### M-04 · `MaintenanceLogEntryView` — Notes Field Decoration is Inconsistent

**File:** [`lib/features/maintenance/views/maintenance_log_entry_view.dart:562-570`](file:///d:/Asansor/lib/features/maintenance/views/maintenance_log_entry_view.dart#L562-L570)

```dart
TextFormField(
  controller: _notesController,
  maxLines: 4,
  decoration: const InputDecoration(
    hintText: 'Yapılan işlemleri, değiştirilen parçaları...',
    border: OutlineInputBorder(), // ← Generic default, not styled
  ),
),
```

**Problem:** All form fields in `LoginView` use a heavily customized `InputDecoration` (filled, custom fill color, focused border accent, error border). The notes field here uses the bare default `OutlineInputBorder()`. This inconsistency is jarring within the same app.

**Fix Required:** Apply consistent `InputDecoration` from `lib/core/theme/input_decorations.dart` (if it exists) or manually match the style used in `LoginView`.

---

### M-05 · `FaultDetailView` — Notes TextField Has No Character Limit

**File:** [`lib/features/fault/views/fault_detail_view.dart:334-349`](file:///d:/Asansor/lib/features/fault/views/fault_detail_view.dart#L334-L349)

```dart
secondChild: TextField(
  controller: _notesController,
  maxLines: 3,
  decoration: InputDecoration(
    labelText: 'Çözüm Notu',
    // ← No maxLength, no maxLengthEnforcement
```

**Problem:** The resolution notes field has no character limit. If a user accidentally pastes a large amount of text, the database insert may fail or the UI will not visually indicate truncation. Adding `maxLength: 1000` with `maxLengthEnforcement: MaxLengthEnforcement.enforced` would improve UX.

---

### M-06 · `CustomerDashboardView` — Logout is a Raw `Icons.logout` Icon with No Label

**File:** [`lib/features/customer/views/customer_dashboard_view.dart:37-43`](file:///d:/Asansor/lib/features/customer/views/customer_dashboard_view.dart#L37-L43)

```dart
actions: [
  IconButton(
    icon: const Icon(Icons.logout, color: Colors.redAccent),
    onPressed: () { ref.read(authControllerProvider.notifier).signOut(); },
  ),
],
```

**Problem:** The logout icon is `Colors.redAccent` (a hardcoded Material color), has no tooltip, no confirmation dialog, and triggers immediate sign-out. A customer who accidentally taps this loses their session. The color also doesn't match the design system.

**Fix Required:** 
1. Add `tooltip: 'Çıkış Yap'`
2. Add a confirmation dialog (see H-03)
3. Change color to `AppColors.error` or `AppColors.outline`

---

### M-07 · `AdminDashboardView` — No Loading/Error State for Stats Grid

**File:** [`lib/features/admin/views/admin_dashboard_view.dart:25-71`](file:///d:/Asansor/lib/features/admin/views/admin_dashboard_view.dart#L25-L71)

**Problem:** `adminStatsProvider` is watched, but the result is passed directly to `DashboardStatsGrid(stats: stats)` without handling the `AsyncValue` loading/error states. If the stats provider is loading or fails, the behavior depends entirely on how `DashboardStatsGrid` internally handles a null or loading `AsyncValue`. There's no loading shimmer or explicit error state at the view level.

**Fix Required:** Wrap the stats grid in `stats.when(loading: ..., error: ..., data: ...)` for explicit state handling.

---

### M-08 · `ElevatorDetailView` — OfflineBanner is Missing

**File:** [`lib/features/elevator/views/elevator_detail_view.dart`](file:///d:/Asansor/lib/features/elevator/views/elevator_detail_view.dart)

**Problem:** `ElevatorDetailView` does not include the `OfflineBanner`. A technician on-site without internet, viewing a cached elevator detail, gets no indication that data might be stale. The home view and elevator list both correctly include it.

**Fix Required:** Add `const OfflineBanner()` at the top of the body, consistent with other views.

---

## ✨ ENHANCEMENT PROPOSALS

---

### E-01 · Add a "Faults List" Screen and Wire the Nav Tab

The "Arızalar" tab (C-01) needs a destination. A paginated, filterable list of all fault reports ordered by date/severity would be the correct target. This is a high-value screen for both technicians and admins.

---

### E-02 · `MaintenanceLogEntryView` — Add Checklist Progress Indicator

Currently, there's no visual indication of checklist completion progress. A simple linear progress bar showing "X of Y items checked" above the checklist card would provide great feedback and motivate completion.

```dart
// e.g., above the checklist Card:
LinearProgressIndicator(
  value: checkedCount / totalCount,
  backgroundColor: AppColors.surfaceContainer,
  color: AppColors.success,
),
```

---

### E-03 · `ElevatorListView` — Add Filter by Status

The search bar only filters by name/address. Adding status filter chips ("Aktif", "Arızalı", "Bakımda", "Pasif") above the list would significantly improve navigation for large fleets. This is a common pattern in fleet management UIs.

---

### E-04 · `HomeView` — Role-Based Welcome Message

The `TopAppBar` always shows "Merhaba, {username}". Admin users could see "Merhaba, Admin — X açık arıza" or similar contextual greetings that surface key information immediately without scrolling.

---

### E-05 · `FaultDetailView` — Add Swipe-to-Resolve Gesture

The "Arızayı Onar" (Resolve Fault) button is a large `FilledButton` at the bottom of the scroll. For a common, high-frequency action, consider a long-press gesture or a swipe gesture on the fault header that triggers resolution, with a visual confirmation overlay. This is a quality-of-life improvement for technicians on mobile.

---

### E-06 · `ScannerView` — Gallery/Image Import Fallback

Some technicians may need to scan a QR code from a printed photo or saved screenshot. Adding a "Galeriden Seç" option (similar to how other QR apps work) that reads QR codes from an image file would improve usability in edge cases.

---

### E-07 · `CustomerNoElevatorView` — Add Auto-Refresh on Reconnect

Currently, a customer on this screen has no way to know if an elevator has been assigned to them without signing out and back in. Add a stream-based check that watches `routerRoleNotifier.elevatorId` and automatically navigates to `/customer/dashboard` when the value becomes non-null, eliminating the need for manual reload.

---

### E-08 · Global — Add `HeroWidget` Transitions for Elevator Cards → Detail

`ElevatorListView` already adds `Hero` tags to elevator icons and titles:
```dart
Hero(tag: 'elevator_icon_${elevator.id}', child: ...),
Hero(tag: 'elevator_title_${elevator.id}', child: ...),
```
But `ElevatorDetailView`'s `ElevatorDetailHeader` widget doesn't contain matching `Hero` widgets. The hero animation will not fire. Either complete the Hero pairing in the detail header, or remove the Hero wrappers from the list view to avoid confusion.

---

## Summary Table

| ID | Severity | Screen / Widget | Issue |
|----|----------|-----------------|-------|
| C-01 | 🚨 Critical | `AppBottomNavBar` | "Arızalar" tab is dead (`onPressed: () {}`) |
| C-02 | 🚨 Critical | `AppBottomNavBar` | "Program" tab disabled for technicians silently |
| C-03 | 🚨 Critical | `ElevatorDetailView` | `more_vert` AppBar button has no action |
| C-04 | 🚨 Critical | `CustomerDashboardView` | No `OfflineBanner` — customer sees stale data silently |
| C-05 | 🚨 Critical | `FaultDetailView` | Loading state is a bare spinner, no AppBar or skeleton |
| C-06 | 🚨 Critical | `MaintenanceLogEntryView` | Success dialog auto-dismisses (1.5s), no user action |
| C-07 | 🚨 Critical | `MaintenanceLogEntryView` | AppBar uses theme default, inconsistent with other views |
| H-01 | ⚠️ High | `ElevatorSystemMonitor` | "Randevu Düzenle" is a static text container, not interactive |
| H-02 | ⚠️ High | `CustomerDashboardView` | Hardcoded colors (7+ instances) — dark mode will break |
| H-03 | ⚠️ High | Multiple | Sign-out has no confirmation dialog |
| H-04 | ⚠️ High | `HomeTopAppBar` | "DURUM: AKTİF" hardcoded — contradicts offline banner |
| H-05 | ⚠️ High | `FaultDetailView` | Error snackbar uses `AppColors.primary` instead of `.error` |
| H-06 | ⚠️ High | `HomeTopAppBar` | Offline icon uses primary color, not a warning/error color |
| H-07 | ⚠️ High | Multiple Views | Static `AppColors.background` instead of dynamic `AppThemeColors.of(context)` |
| M-01 | 📋 Medium | `HomeView` | Admin users see technician-scoped stats, not fleet overview |
| M-02 | 📋 Medium | `DailyAgendaSection` | "+N more tasks" truncation text is not tappable/navigable |
| M-03 | 📋 Medium | `ScannerView` | Camera permission denied state not handled |
| M-04 | 📋 Medium | `MaintenanceLogEntryView` | Notes field `InputDecoration` is inconsistent with rest of app |
| M-05 | 📋 Medium | `FaultDetailView` | Resolution notes field has no character limit |
| M-06 | 📋 Medium | `CustomerDashboardView` | Logout icon: hardcoded color, no tooltip, no confirmation |
| M-07 | 📋 Medium | `AdminDashboardView` | Stats grid receives `AsyncValue` without loading/error handling |
| M-08 | 📋 Medium | `ElevatorDetailView` | `OfflineBanner` missing — data staleness not communicated |
| E-01 | ✨ Enhancement | Global | Create a Faults list view and wire nav tab |
| E-02 | ✨ Enhancement | `MaintenanceLogEntryView` | Add checklist progress indicator |
| E-03 | ✨ Enhancement | `ElevatorListView` | Add status filter chips |
| E-04 | ✨ Enhancement | `HomeView` | Role-based contextual welcome message |
| E-05 | ✨ Enhancement | `FaultDetailView` | Long-press or swipe gesture for fault resolution |
| E-06 | ✨ Enhancement | `ScannerView` | Gallery import fallback for QR codes |
| E-07 | ✨ Enhancement | `CustomerNoElevatorView` | Auto-refresh when elevator is assigned |
| E-08 | ✨ Enhancement | `ElevatorListView` → `Detail` | Complete Hero animation pairing |
