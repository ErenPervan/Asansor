# UI/UX Audit

Audit date: 2026-06-04  
Project: Asansor Flutter app  
Scope: admin, auth, customer, elevator, fault, and maintenance feature modules, plus shared navigation, theme, and state widgets.

## Method

This audit was performed through static code review of the Flutter UI layer, shared widgets, router, theme tokens, and representative feature screens. I also ran `flutter analyze`; it completed with no analyzer issues.

Key files reviewed include:

- `lib/main.dart`
- `lib/core/router/app_router.dart`
- `lib/core/theme/app_colors.dart`
- `lib/core/theme/app_spacing.dart`
- `lib/core/widgets/*`
- `lib/features/admin/**`
- `lib/features/auth/**`
- `lib/features/customer/**`
- `lib/features/elevator/**`
- `lib/features/fault/**`
- `lib/features/maintenance/**`

## Executive Summary

The app has a solid functional foundation: role-aware routing, Riverpod async state management, offline/cache infrastructure, reusable loading/error/empty widgets, a centralized color palette, and strong coverage of the core elevator maintenance workflows.

The main UX risks are not missing screens; they are consistency, feedback quality, text integrity, accessibility, and workflow polish. The product currently feels like several strong feature implementations stitched together rather than one coherent mobile system.

Highest-priority findings:

1. Multiple user-facing Turkish strings are encoding-corrupted in source, especially in fault detail, technician management, maintenance history, statistics, and PDF generation.
2. Navigation is route-based but not shell-based, so bottom navigation state and back behavior are manually managed per screen.
3. Loading, error, empty, and offline states exist but are inconsistently applied across modules.
4. The maintenance entry submit area contains nested interactive controls with an inner `FilledButton` whose `onPressed` is an empty callback.
5. Accessibility needs a pass for semantics, reduced motion, text scaling, contrast, and minimum touch targets.
6. Rendering performance can be improved by reducing nested shrink-wrapped lists/grids, repeated animations, and uncached network images.

## Current Information Architecture

### Routing And Role Flow

The app uses `GoRouter` with a Riverpod-driven auth state machine in `lib/core/router/app_router.dart`. The router redirects unauthenticated users to login, waits for profile loading, guards admin routes, and scopes customer users to customer pages.

Current primary flows:

- Auth: `/login` -> `/loading` -> role-specific destination.
- Technician/default: `/`, `/elevators`, `/faults`, `/scan`, `/elevator/:id`, `/elevator/:id/maintenance/new`.
- Admin: `/admin/dashboard`, `/admin/assign`, `/admin/map`, `/admin/users`, `/admin/calendar`, `/admin/master-calendar`, `/admin/technicians`, `/admin/checklists`, `/admin/statistics`, `/admin/add-elevator`, `/admin/elevator-qr/:id`, `/admin/conflicts`.
- Customer: `/customer/dashboard`, `/customer/no-elevator`, and fault detail access.

The routing logic is strong functionally, but UX navigation is manually coordinated. `AppBottomNavBar` receives a `currentIndex` from each screen and directly calls `context.go(...)`. Detail screens use `currentIndex: -1`, while admin screens mostly rely on dashboard hub navigation and app bar back behavior.

Recommendation: migrate the main app surfaces to a `StatefulShellRoute` or equivalent shell structure with role-filtered navigation destinations. This will preserve tab state, centralize active destination logic, and reduce inconsistent back stacks.

## Cross-Cutting Findings

### 1. User-Facing Text Encoding Is Corrupted

Severity: Critical

Several files contain mojibake in visible labels, messages, tooltips, comments, and generated PDF text. This is visible in search results for `Ã`, `Ä`, `Å`, `â`, and related sequences.

Examples:

- `lib/features/fault/views/fault_detail_view.dart`: page title, labels, buttons, timestamps, and status text around lines 49, 97, 189, 236, 284, 320, 387, 419, 458, 521, 561, 655, and 831.
- `lib/features/admin/views/technician_management_view.dart`: technician availability, workload, snackbar messages, status labels, and empty states around lines 197, 431, 439, 460, 536, 595, 721, 1027, and 1088.
- `lib/features/admin/views/admin_statistics_dashboard.dart`: quick action labels around lines 818 and 825.
- `lib/features/elevator/widgets/detail/log_maintenance_sheet.dart`: maintenance sheet labels and snackbars around lines 38, 79, 164, 188, 195, and 220.
- `lib/features/elevator/widgets/detail/elevator_maintenance_history.dart`: maintenance history labels, PDF action text, and status chips around lines 50, 75, 86, 161, 328, and 342.
- `lib/core/services/pdf_service.dart`: PDF titles, table headers, labels, month names, and generated status text around lines 534, 593, 663, 676, 734, 780, 907, and 938.

Impact:

- Users see broken Turkish text in critical workflows.
- Generated PDFs may look unprofessional or legally unreliable.
- Search, localization, QA screenshots, and support documentation become harder to trust.

Recommended implementation steps:

1. Fix source encoding and restore all corrupted Turkish literals.
2. Move all user-facing strings into ARB localization files instead of embedding strings in widgets.
3. Add a CI check that fails when known mojibake sequences appear in `lib/` or generated documents.
4. Render and review the fault detail, technician management, maintenance history, and generated PDF after repair.

### 2. Feedback States Are Present But Inconsistent

Severity: High

The app has useful shared widgets:

- `LoadingState` uses shimmer cards.
- `ErrorState` provides a retry CTA.
- `EmptyState` supports an optional action.
- `OfflineBanner` shows a cached-data warning when offline.

However, modules apply them inconsistently.

Examples:

- Customer dashboard uses `OfflineBanner`, `LoadingState`, `ErrorState`, and `EmptyState` well.
- Elevator list uses offline, loading, error, empty, and filtered-empty states.
- Fault list uses shared loading/error/empty states.
- Admin dashboard uses a pull-to-refresh container and component-level async state, but no offline banner.
- Admin calendar uses an app bar spinner but lacks a fully expressive empty/error/offline state for the selected day and schedule load.
- Checklist, technician, map, and user management define local `_EmptyState`, `_ErrorState`, `_ErrorBody`, `_EmptyPane`, and similar widgets instead of reusing shared patterns.
- Auth loading uses only a spinner for profile loading and a sign-out button on error.

Recommended implementation steps:

1. Introduce a shared `AppAsyncView<T>` or `AsyncStateView<T>` wrapper that standardizes loading, error, empty, retry, refresh, and offline-aware copy.
2. Create sliver-compatible state widgets: `SliverLoadingState`, `SliverErrorState`, and `SliverEmptyState`.
3. Add `OfflineBanner` to all data-heavy admin and maintenance screens, not only technician/customer surfaces.
4. Normalize retry behavior so every failed async screen has a clear retry path.
5. Replace local state widgets with shared components unless a screen has a strong domain-specific reason.

### 3. Navigation Needs A Shell Model

Severity: High

`AppBottomNavBar` is manually configured and uses a fixed center spacer for the QR FAB. This works visually for the technician flow, but the model is brittle:

- Active state is passed manually via `currentIndex`.
- Detail screens pass `currentIndex: -1`.
- Admin has a dashboard hub but no persistent admin navigation model.
- Customer has a separate dashboard with no bottom nav.
- Disabled admin-only nav item is visible to non-admin users with opacity and tooltip, but it still occupies primary nav space.

Recommended implementation steps:

1. Define a centralized destination model with route, label, icon, role visibility, and selected path matching.
2. Replace manual `currentIndex` with route-derived selection.
3. Use `StatefulShellRoute` for technician/admin tabs where appropriate.
4. Hide admin-only destinations from non-admin users instead of showing disabled primary navigation.
5. Add a consistent detail-screen policy: either hide bottom nav on deep detail flows or keep it visible with route-derived active parent.

### 4. Maintenance Submit Interaction Is Structurally Wrong

Severity: High

In `lib/features/maintenance/views/maintenance_log_entry_view.dart`, the submit section wraps a `FilledButton.icon` inside `AnimatedPressButton`. The outer wrapper calls `_submit`, but the inner `FilledButton` uses `onPressed: maintenanceState.isLoading ? null : () {}` around lines 739-745.

Impact:

- Nested interactive controls can confuse gesture, focus, and semantics behavior.
- Assistive technologies may announce the wrong action.
- The actual button callback is empty, while the parent wrapper performs the submit.

Recommended implementation steps:

1. Remove the nested interactive structure.
2. Make one button responsible for both visual press animation and `_submit`.
3. If `AnimatedPressButton` is retained, make it non-semantic decoration around a non-interactive child, or convert it into a proper button component.
4. Add a widget test that taps the submit button and verifies the controller submit path is called.

### 5. Component Vocabulary Is Fragmented

Severity: Medium-High

The codebase has many well-built local widgets, but they are mostly screen-private. Common UI concepts are reimplemented across modules:

- Dashboard action cards.
- Status badges/chips.
- Empty/error states.
- Section headers.
- Picker fields.
- Bottom sheets.
- Confirmation dialogs.
- Snackbar success/error feedback.
- Form fields and validation layouts.

Examples:

- Shared `StatusTokens` exists, but several screens still calculate status colors locally.
- `appInputDecoration` exists, while many forms construct `InputDecoration` inline.
- Admin checklist, technician, fault detail, elevator history, and customer dashboard each define their own card/chip language.

Recommended implementation steps:

1. Create a small design-system layer under `lib/core/widgets/components/`.
2. Prioritize these reusable components:
   - `AppPageScaffold`
   - `AppSectionHeader`
   - `AppCard`
   - `AppActionCard`
   - `AppStatusChip`
   - `AppAsyncView`
   - `AppConfirmDialog`
   - `AppBottomSheetScaffold`
   - `AppPrimaryButton`
   - `AppSnackbar`
3. Replace duplicated screen-private empty/error widgets with shared components.
4. Keep domain-specific variants thin and data-driven.

### 6. Accessibility Needs A Dedicated Pass

Severity: Medium-High

Positive signs:

- Some icon buttons have tooltips.
- Scanner controls use `Semantics` and `Tooltip`.
- Forms disable inputs during submission.
- Many screens use `RefreshIndicator`.

Gaps:

- Several `InkWell` and `GestureDetector` interactions rely on visual-only affordances.
- Long-press actions in fault detail are not discoverable enough.
- Some icon-only actions lack explicit tooltips or semantic labels.
- Text styles use negative letter spacing in multiple places, which can reduce readability and increase clipping risk under text scaling.
- There is no visible reduced-motion handling for repeating animations.
- Fixed heights and large decorative cards may not handle large text sizes gracefully.
- The app defines dark theme colors but forces `ThemeMode.light`, limiting system accessibility preference support.

Recommended implementation steps:

1. Test major screens at text scale 1.3, 1.5, and 2.0.
2. Add `Tooltip` and `Semantics` to every icon-only or custom tap target.
3. Replace long-press-only actions with explicit buttons or add a visible affordance.
4. Respect `MediaQuery.disableAnimations` or `MediaQuery.accessibleNavigation` for decorative/repeating animations.
5. Use route/page-level scroll containers that tolerate large fonts and keyboard insets.
6. Consider `ThemeMode.system` after verifying dark-mode contrast.

### 7. Visual Hierarchy Is Uneven Across Modules

Severity: Medium

The visual language varies by module:

- Auth has a polished branded header with animated gears and an industrial motif.
- Technician home uses modular cards, agenda, active faults, and QR FAB.
- Customer dashboard uses a very large status card and simplified history.
- Admin dashboard is dense and card-heavy, with many destinations at equal visual weight.
- Fault detail uses a rich sliver header and action area.
- Checklist uses a gradient sliver app bar.

This gives each module personality, but the app can feel inconsistent. Admin surfaces in particular need hierarchy that distinguishes urgent work, operational overview, and configuration tasks.

Recommended implementation steps:

1. Define page templates for:
   - Operational dashboard.
   - Search/list.
   - Detail.
   - Data-entry form.
   - Admin configuration.
2. Use consistent spacing, card radius, header treatment, and action placement per template.
3. Reduce equal-weight admin dashboard cards by grouping actions into "Operations", "People", "Planning", and "System setup".
4. Make critical alerts and conflicts visually dominant; make low-frequency setup tools quieter.

### 8. Offline UX Is Promising But Underexplained

Severity: Medium

The app includes connectivity providers, cache boxes, a sync queue, conflict handling, and an `OfflineBanner`. This is a strong foundation for a maintenance field app.

Current gaps:

- Offline banner is not consistently present on admin and form screens.
- Some save actions provide offline-specific snackbar copy, but the overall offline capability is not consistently explained.
- Conflict resolution exists but may be hard to discover unless conflict banners appear.
- Users need clearer distinction between cached read-only data and queued write operations.

Recommended implementation steps:

1. Use a global offline/queued-sync status surface near top-level navigation.
2. Add per-form copy for "saved on this device, sync pending" after offline writes.
3. Show queued item count and last sync time in a reusable sync status sheet.
4. Disable or annotate operations that cannot work offline.
5. Add empty/offline variants: "No cached data available yet" is different from "No records exist."

### 9. Rendering Performance Risks

Severity: Medium

Notable patterns:

- `LoadingState` uses a shrink-wrapped, non-scrollable `ListView`.
- Several screens place shrink-wrapped lists/grids inside scroll views.
- Customer maintenance logs use `ListView.separated` with `shrinkWrap: true` inside another `ListView`.
- Admin dashboard uses `SingleChildScrollView` plus multiple async sections and card grids.
- Repeating animations exist on login, scanner, active fault cards, and press interactions.
- Fault detail uses `Image.network` directly for photos.

Recommended implementation steps:

1. Prefer slivers for complex scroll pages instead of nested scrollables.
2. Use `SliverList`/`SliverGrid` for dashboard and long-list modules.
3. Avoid `shrinkWrap: true` on potentially large collections.
4. Use `CachedNetworkImage` or an image wrapper with loading/error placeholders for remote photos.
5. Wrap expensive custom-paint and animated regions in `RepaintBoundary`.
6. Pause decorative animations when not visible and honor reduced-motion settings.

### 10. Theme System Is Good But Not Fully Enforced

Severity: Medium

The app defines centralized `AppColors`, `AppThemeColors`, `AppSpacing`, `StatusTokens`, and global `ThemeData`. This is valuable.

Issues:

- `ThemeMode.light` is forced even though dark tokens exist.
- Theme typography uses negative letter spacing in several tokens.
- Some colors and decorations are still hard-coded in screens.
- Input styling is split between global `InputDecorationTheme`, `appInputDecoration`, and inline definitions.

Recommended implementation steps:

1. Decide whether dark mode is supported. If yes, switch to `ThemeMode.system` and audit contrast. If no, remove or quarantine dark tokens to avoid false confidence.
2. Normalize letter spacing in global theme and use explicit display styles only where needed.
3. Replace inline color/status logic with `StatusTokens`.
4. Standardize form fields on one input decoration path.

## Module-by-Module Audit

## Auth Module

Strengths:

- Login screen has a strong branded first impression.
- Form validation, disabled state, snackbar errors, and loading button state are present.
- Profile-loading error state provides a sign-out path.

Deficiencies:

- Decorative repeating gear animation does not appear to honor reduced-motion preferences.
- Password visibility icon needs an explicit tooltip/semantic label.
- Login screen layout uses a fixed 38% header area; this may crowd small devices or large text.
- Loading screen shows a spinner only during profile loading, with no explanatory text.
- There is no visible password reset or account recovery entry point.

Recommendations:

1. Add reduced-motion handling to decorative login animations.
2. Add tooltip/semantics for the password visibility toggle.
3. Add a concise loading message, such as "Loading profile..." localized through ARB.
4. Add password reset if the product supports email recovery.
5. Test login with keyboard open, small device heights, and text scale 1.5+.

## Admin Module

Strengths:

- Admin dashboard clearly exposes core operational areas.
- Conflict banner creates a good entry point for sync conflict resolution.
- Pull-to-refresh exists on the dashboard.
- Master calendar, map, user management, technician management, checklist management, QR, and statistics screens cover meaningful admin workflows.
- Calendar and map screens provide domain-specific interaction instead of generic lists.

Deficiencies:

- Admin dashboard has too many equal-weight cards, which weakens priority scanning.
- Admin surfaces do not consistently show offline status.
- Many admin screens define local empty/error widgets instead of shared states.
- Admin navigation depends on returning to the dashboard or using app bar back, not on a coherent admin navigation model.
- Technician management includes corrupted Turkish strings.
- Statistics quick actions include corrupted labels.
- Map markers and overlays need semantics and clearer empty states.

Recommendations:

1. Group admin dashboard actions by priority and role frequency.
2. Add offline and sync indicators to admin screens.
3. Convert local admin state widgets to shared state components.
4. Introduce an admin shell/destination model.
5. Fix text encoding before visual polish.
6. Add semantic labels for map markers, legend controls, and action cards.

## Customer Module

Strengths:

- Customer dashboard is focused and understandable.
- It shows assigned elevator status, report fault action, recent maintenance history, logout confirmation, offline banner, and retry states.
- Fault reporting reuses the existing `ReportFaultSheet`.

Deficiencies:

- The health card is very large and may dominate the screen at the expense of recent faults or next maintenance.
- Customer users can report a fault, but the dashboard does not clearly surface active/recent fault report status after submission.
- PDF launch feedback is limited to snackbars.
- Maintenance history uses a shrink-wrapped list inside another list.

Recommendations:

1. Add "Active fault" or "Latest report status" to the customer dashboard.
2. Add next scheduled maintenance if available.
3. Make the health card more compact on small screens.
4. Replace nested maintenance list with a sliver or direct list section.
5. Use a shared file-opening state pattern for PDF open/download failures.

## Elevator Module

Strengths:

- Technician home has a useful operational structure: sync status, stats, agenda, active faults, elevator shortcut, QR scanner.
- Elevator list supports search, filters, loading/error/empty states, refresh, and offline banner.
- Elevator detail is decomposed into header, actions, system monitor, and maintenance history.
- Scanner has strong full-screen affordance and includes semantics/tooltips for custom scanner controls.
- Add elevator flow includes loading guards and post-create QR flow.

Deficiencies:

- Bottom nav state is manual and not route-derived.
- Elevator detail keeps a bottom nav with no active tab, which can feel ambiguous.
- Maintenance history and log sheet contain corrupted strings.
- Some detail widgets still reference "Stitch" design notes in comments, suggesting design code was ported without full normalization.
- Scanner animations should honor reduced-motion preferences.

Recommendations:

1. Route-drive bottom nav selection.
2. Decide whether detail screens keep or hide bottom nav.
3. Fix corrupted maintenance/history strings.
4. Standardize detail-page section components.
5. Add loading/error placeholders to all remote images and generated PDF actions.

## Fault Module

Strengths:

- Fault list is clean: filters, refresh, shared loading/error/empty states, and fault cards.
- Fault detail has a rich status header and clear resolve/reopen actions.
- Elevator cross-linking exists from fault detail.

Deficiencies:

- Fault detail contains extensive corrupted Turkish strings.
- The fault detail action model is dense and mixes notes, resolve, reopen, and navigation in one area.
- Long-press behavior on the status header is not discoverable enough.
- `Image.network` is used directly for photos.
- Loading state for update actions is shared, so multiple controls can appear blocked or busy together.

Recommendations:

1. Fix text encoding immediately.
2. Replace long-press-only interactions with explicit visible controls.
3. Split the action area into "Resolution", "Elevator", and "History" sections.
4. Use cached/loading/error image handling.
5. Track per-action loading state if multiple actions can exist in the same view.

## Maintenance Module

Strengths:

- Maintenance entry is comprehensive: elevator context, checklist, notes, signature, PDF/save flow, loading protection, and snackbars.
- `PopScope` prevents leaving during active save.
- Checklist load states and empty states are represented.

Deficiencies:

- Submit button structure is incorrect due to nested interactive controls and empty inner callback.
- The form is long and likely heavy on small screens.
- Offline save behavior needs a more durable visible state than snackbar-only feedback.
- Signature and checklist interactions need accessibility labels and large-text testing.
- Related quick log sheet has corrupted strings.

Recommendations:

1. Fix submit button interaction structure.
2. Break the long form into sections with a sticky bottom submit bar or stepper-like progress.
3. Add autosave/draft or explicit "saved locally" feedback if offline field work is common.
4. Add semantic labels to checklist items and signature actions.
5. Standardize maintenance form fields with shared input components.

## Shared Widgets And Design System

Current reusable assets:

- `AppColors`, `AppThemeColors`, `AppSpacing`
- `StatusTokens`
- `LoadingState`, `ErrorState`, `EmptyState`, `OfflineBanner`
- `AppBottomNavBar`
- `InfoCard`, `SectionLabel`, `AnimatedCounter`, `ShimmerCard`
- `AnimatedPressButton`, `FadeInSlide`

Recommended additions:

1. `AppAsyncView<T>` for async data rendering.
2. `AppScreenScaffold` with optional offline banner, refresh, bottom action, and sliver support.
3. `AppStatusChip` backed by `StatusTokens`.
4. `AppActionCard` for dashboard and shortcut tiles.
5. `AppFormField` wrappers for text, dropdown, date/time, picker, and search fields.
6. `AppSnackbar` helper with success/error/warning/offline variants.
7. `AppConfirmDialog` for destructive or state-changing confirmation.
8. `AppRemoteImage` for cached network image with placeholder and error state.

## Accessibility Checklist

Implement and verify:

- Minimum 48 x 48 logical pixel tap targets.
- Tooltips and semantic labels for every icon-only action.
- No important action available only through long press.
- Text scale testing at 1.3, 1.5, and 2.0.
- No clipped labels in cards, chips, buttons, tabs, or bottom navigation.
- Color contrast for status chips, warnings, errors, and disabled states.
- Reduced-motion support for decorative/repeating animations.
- Keyboard-safe layouts for login, assignment, add elevator, maintenance, and bottom sheets.
- Screen reader order for forms, scanner controls, map markers, and bottom sheets.
- Localized strings in ARB files rather than hard-coded screen strings.

## Performance Checklist

Implement and verify:

- Replace nested `SingleChildScrollView` + shrink-wrapped lists with sliver layouts where lists can grow.
- Avoid `shrinkWrap: true` for large or unbounded data.
- Use `ListView.builder`/`SliverList` for long lists.
- Add `RepaintBoundary` around animated/custom-painted regions.
- Pause decorative animations when inaccessible or offscreen.
- Use cached network image handling for fault photos and any remote media.
- Keep dashboard cards const where possible and avoid rebuilding heavy child trees on unrelated provider changes.
- Profile map and statistics screens on a low-end Android device.

## Recommended Implementation Roadmap

### Phase 0: Critical UX Quality Fixes

1. Fix all corrupted user-facing strings and generated PDF text.
2. Move visible strings into localization ARB files.
3. Add a mojibake CI check.
4. Fix the maintenance submit button structure.
5. Add missing tooltips/semantics to obvious icon-only actions.

### Phase 1: State And Navigation Foundation

1. Build `AppAsyncView` and sliver state variants.
2. Replace local empty/error/loading implementations in admin and feature modules.
3. Introduce route-derived navigation destinations.
4. Move main tabs to a shell route.
5. Add global offline/sync visibility to major data screens.

### Phase 2: Design System Consolidation

1. Create reusable action cards, status chips, section headers, bottom sheet scaffolds, and form fields.
2. Refactor admin dashboard cards into grouped sections.
3. Normalize page templates for dashboards, lists, details, forms, and admin configuration.
4. Standardize snackbar copy, colors, duration, and actions.

### Phase 3: Accessibility And Performance Hardening

1. Run text-scale QA across all modules.
2. Add reduced-motion support.
3. Replace nested scrollables with sliver-based layouts in large screens.
4. Add cached remote image handling.
5. Perform low-end Android profiling for scanner, map, dashboard, statistics, and maintenance form.

## Suggested Acceptance Criteria

- No mojibake sequences remain in user-facing code or PDFs.
- All primary screens have loading, error, empty, offline, and retry behavior where applicable.
- Bottom navigation selection is route-derived and role-aware.
- Custom tap targets have semantic labels and meet minimum touch size.
- Large text does not clip or overlap on login, home, dashboard, calendar, fault detail, customer dashboard, and maintenance form.
- Maintenance submit triggers exactly one accessible action path.
- `flutter analyze` remains clean.
- Key user flows are covered with widget or integration tests:
  - Login error/loading/success.
  - Customer report fault.
  - Technician scan -> maintenance form.
  - Elevator list search/filter empty state.
  - Fault resolve/reopen.
  - Admin assignment.
  - Offline queued maintenance save.
  - Conflict management entry point.

## Final Assessment

The app is functionally mature and already contains many of the right building blocks. The next UX improvement should not be a visual redesign from scratch. The best path is to stabilize text quality, unify navigation/state patterns, consolidate reusable components, and then polish module-specific flows.

Once the encoding issue, maintenance submit bug, and async/offline consistency gaps are fixed, the product will feel much more trustworthy and coherent without needing a broad rewrite.
