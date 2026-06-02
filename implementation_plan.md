# Dynamic UI Implementation Plan

> [!IMPORTANT]
> **Status: APPROVED — Awaiting Phase 1 green light.**
> All design decisions have been resolved. The Open Questions section has been converted to Resolved Decisions below.

## Overview

This plan covers every static, hardcoded UI value found across the entire `lib/` directory after a full audit.
The goal is **100% dynamic, theme-aware, and responsive** UI — no raw colors, no scattered `TextStyle`s, no rigid fixed dimensions outside of semantic spacing tokens.

The audit confirmed the app already has a strong foundation:
- `AppThemeColors.of(context)` is widely adopted.
- `AppSpacing` token class exists with spacing and radius constants.
- `Theme.of(context).textTheme` is used in most widgets.

What follows is a precise, file-by-file record of every remaining violation and the exact fix strategy.

---

## Pillar 1 — Dynamic Theming (Colors & Decorations)

### Category A — Static `AppColors.*` used directly in widgets (not via `AppThemeColors.of(context)`)

`AppColors` is a static constants class intended only as raw palette storage.
Using it directly in widget `build()` methods bypasses the theme switch, so the widget never adapts to dark mode.

| File | Violation | Fix |
|---|---|---|
| [admin_conflict_management_view.dart](file:///d:/Asansor/lib/features/admin/conflicts/admin_conflict_management_view.dart) | `AppColors.surface`, `AppColors.primary`, `AppColors.onSurface`, `AppColors.error`, `AppColors.onSurfaceVariant`, `AppColors.surfaceContainerLowest` | Replace all with `AppThemeColors.of(context).*` |
| [admin_conflict_management_view.dart](file:///d:/Asansor/lib/features/admin/conflicts/admin_conflict_management_view.dart) | `backgroundColor: AppColors.surface` (Scaffold, line 18) | `AppThemeColors.of(context).background` |

### Category B — File-scoped `const Color(0xFF…)` declarations

These are light-mode-only values baked as compile-time constants. They never respond to dark mode.

| File | Constant | Semantic Equivalent | Fix Strategy |
|---|---|---|---|
| [admin_conflict_detail_dialog.dart](file:///d:/Asansor/lib/features/admin/conflicts/admin_conflict_detail_dialog.dart) | `_error = Color(0xFFBA1A1A)`, `_localBg = Color(0xFFFFF1F2)`, `_localLabel = Color(0xFF93000A)`, `_serverBg`, `_serverLabel` | `colors.error`, `colors.errorContainer`, `colors.onErrorContainer` | Remove top-level constants; look up via `AppThemeColors.of(context)` in `build()` |
| [admin_conflict_management_view.dart](file:///d:/Asansor/lib/features/admin/conflicts/admin_conflict_management_view.dart#L76) | `Color(0xFF002D59)` (gradient stop) | `colors.navy` (already defined in `AppColors`) | `AppThemeColors.of(context).navy` |
| [admin_conflict_management_view.dart](file:///d:/Asansor/lib/features/admin/conflicts/admin_conflict_management_view.dart#L102) | `Color(0xFFFBBF24)` (warning dot), `Color(0xFF4ADE80)` (success dot) | `colors.warningLight`, `colors.successLight` | Inline lookup via `AppThemeColors.of(context)` |
| [admin_conflict_management_view.dart](file:///d:/Asansor/lib/features/admin/conflicts/admin_conflict_management_view.dart#L271) | `Color(0xFFDCFCE7)`, `Color(0xFF166534)` (empty state circle) | `colors.successContainer`, `colors.success` | Inline lookup |
| [admin_statistics_dashboard.dart](file:///d:/Asansor/lib/features/admin/views/admin_statistics_dashboard.dart#L232) | `Color(0xFF4ADE80)` ("live" indicator dot) | `colors.successLight` | Inline lookup |
| [technician_management_view.dart](file:///d:/Asansor/lib/features/admin/views/technician_management_view.dart#L137) | `Color(0xFF4ADE80)` (accent dot) | `colors.successLight` | Inline lookup |
| [user_management_view.dart](file:///d:/Asansor/lib/features/admin/views/user_management_view.dart#L31) | `Color(0xFF4CAF50)` (customer avatar bg) | `colors.successLight` | Inline lookup |
| [user_management_view.dart](file:///d:/Asansor/lib/features/admin/views/user_management_view.dart#L37) | `Color(0xFFD6E3FF)` (technician badge bg) | `colors.primaryFixed` (already in `AppColors`) | Inline lookup |

### Category C — `Colors.white` / `Colors.black` in content areas

These are acceptable on top of a coloured background (e.g., white text on primary), but the following usages bypass the theme:

| File | Line | Issue | Fix |
|---|---|---|---|
| [fault_detail_view.dart](file:///d:/Asansor/lib/features/fault/views/fault_detail_view.dart#L176) | `Icon(color: Colors.white)` | on primary/success AppBar | `colors.onPrimary` |
| [fault_detail_view.dart](file:///d:/Asansor/lib/features/fault/views/fault_detail_view.dart#L185) | `Icon(color: Colors.white)` | action icon on primary | `colors.onPrimary` |
| [fault_detail_view.dart](file:///d:/Asansor/lib/features/fault/views/fault_detail_view.dart#L686) | `Icon(color: Colors.white, size: 36)` | icon inside status header circle | `colors.onPrimary` |
| [fault_detail_view.dart](file:///d:/Asansor/lib/features/fault/views/fault_detail_view.dart#L694) | `Text(color: Colors.white)` | label on coloured header | `colors.onPrimary` |
| [fault_detail_view.dart](file:///d:/Asansor/lib/features/fault/views/fault_detail_view.dart#L702) | `Text(color: Colors.white.withValues(alpha: 0.85))` | sub-label on header | `colors.onPrimary.withValues(alpha: 0.85)` |
| [admin_statistics_dashboard.dart](file:///d:/Asansor/lib/features/admin/views/admin_statistics_dashboard.dart#L200) | `color: Colors.white` (text on primary header) | on primary SliverAppBar | `colors.onPrimary` |
| [admin_statistics_dashboard.dart](file:///d:/Asansor/lib/features/admin/views/admin_statistics_dashboard.dart#L207) | `Colors.white60` (sub-text on header) | on primary SliverAppBar | `colors.onPrimary.withValues(alpha: 0.6)` |
| [admin_statistics_dashboard.dart](file:///d:/Asansor/lib/features/admin/views/admin_statistics_dashboard.dart#L241) | `color: Colors.white` ("live" badge label) | inside primary container | `colors.onPrimary` |
| [admin_statistics_dashboard.dart](file:///d:/Asansor/lib/features/admin/views/admin_statistics_dashboard.dart#L503) | `Colors.white60`, `Colors.white` | chart axis labels on gradient | `colors.onPrimary.withValues(alpha: 0.7)` |
| [admin_conflict_management_view.dart](file:///d:/Asansor/lib/features/admin/conflicts/admin_conflict_management_view.dart#L69) | `foregroundColor: Colors.white` | on primary AppBar | `colors.onPrimary` |
| [admin_conflict_management_view.dart](file:///d:/Asansor/lib/features/admin/conflicts/admin_conflict_management_view.dart#L87) | `color: Colors.white` (title) | on primary header | `colors.onPrimary` |
| [admin_conflict_management_view.dart](file:///d:/Asansor/lib/features/admin/conflicts/admin_conflict_management_view.dart#L113) | `Colors.white.withValues(alpha: 0.75)` | sub-text on header | `colors.onPrimary.withValues(alpha: 0.75)` |
| [fault_detail_view.dart](file:///d:/Asansor/lib/features/fault/views/fault_detail_view.dart#L683) | `Colors.white.withValues(alpha: 0.18)` (icon circle bg) | inside status header | Replace with a translucent semantic token: `colors.onPrimary.withValues(alpha: 0.18)` |
| [fault_detail_view.dart](file:///d:/Asansor/lib/features/fault/views/fault_detail_view.dart#L713) | `Colors.black.withValues(alpha: 0.2)` (hint pill bg) | inside status header | `colors.primaryDark.withValues(alpha: 0.35)` |
| [maintenance_log_entry_view.dart](file:///d:/Asansor/lib/features/maintenance/views/maintenance_log_entry_view.dart#L47) | `exportBackgroundColor: Colors.transparent` | Signature controller | ✅ Acceptable — transparent canvas |
| [shimmer_card.dart](file:///d:/Asansor/lib/core/widgets/shimmer_card.dart#L27) | `color: Colors.white` (shimmer child container) | Shimmer library requirement | ✅ Acceptable — library-mandated |
| [fault_detail_view.dart](file:///d:/Asansor/lib/features/fault/views/fault_detail_view.dart#L502) | `Colors.green, Colors.blue, Colors.pink, Colors.orange, Colors.purple` | confetti colors | Map to themed palette tokens: `colors.success, colors.blue, colors.error, colors.warning, colors.violet` |
| [user_management_view.dart](file:///d:/Asansor/lib/features/admin/views/user_management_view.dart#L533) | `backgroundColor: Theme.of(context).colorScheme.surface` | modal bottom sheet | `colors.surface` for consistency |

### Category D — `Colors.black.*` used as shadow colors

Using `Colors.black.withValues(alpha: X)` for shadows is a common pattern and **functionally acceptable**. However, in dark mode these shadows can look harsh. The recommended fix is to replace with `colors.outline.withValues(alpha: X)` or `colors.onSurface.withValues(alpha: X)` which are already dark-mode-aware.

Affected files (partial list — shadow fixes are lower priority):
- `info_card.dart`, `admin_map_view.dart`, `admin_master_calendar_view.dart`, `admin_statistics_dashboard.dart`, `elevator_qr_view.dart`, `technician_management_view.dart`, `user_management_view.dart`, `calendar_task_card.dart`, `dashboard_*.dart` widgets, `home_active_faults.dart`, `home_daily_agenda.dart`, `dashboard_stats.dart`

> [!NOTE]
> Shadow color fixes (`Colors.black.withValues(alpha: 0.03–0.12)`) are grouped in a single pass at the end because they are low-risk and do not affect layout. The `home_top_app_bar.dart` uses `Colors.black12` for shadowColor, which should become `colors.outline.withValues(alpha: 0.12)`.

### Category E — Scanner view (intentional dark UI)

`scanner_view.dart` uses `Colors.black` for its camera overlay background. This is **intentional** (camera viewfinder must be dark). Mark as exempted with a `// ignore: themed_color` annotation.

`Colors.greenAccent.shade400` (line 331) for the scan-success bracket color should become `colors.successLight`.

---

## Pillar 2 — Dynamic Typography

### Category A — Standalone `const TextStyle(…)` in widget `build()` methods

These are never connected to `textTheme` and will not respect font scaling or custom typeface changes.

| File | Lines | Issue | Fix |
|---|---|---|---|
| [admin_conflict_management_view.dart](file:///d:/Asansor/lib/features/admin/conflicts/admin_conflict_management_view.dart) | L86, L112, L126, L192, L209, L224, L290, L301, L350 | `TextStyle(fontSize: X, color: AppColors.*)` | Replace with `textTheme.titleLarge?.copyWith(…)` etc., map color to `AppThemeColors.of(context)` |
| [admin_conflict_detail_dialog.dart](file:///d:/Asansor/lib/features/admin/conflicts/admin_conflict_detail_dialog.dart) | L42, L57, L171, L194, L204 | Standalone `TextStyle` with hardcoded sizes | Map to `textTheme.*` equivalents |
| [admin_statistics_dashboard.dart](file:///d:/Asansor/lib/features/admin/views/admin_statistics_dashboard.dart) | L239, L423, L502, L510 | Standalone `TextStyle` for chart labels and section titles | Use `textTheme.labelSmall?.copyWith(…)` |
| [checklist_management_view.dart](file:///d:/Asansor/lib/features/admin/views/checklist_management_view.dart) | L493, L509 | Standalone `TextStyle` | Replace with `textTheme.*` |
| [maintenance_log_entry_view.dart](file:///d:/Asansor/lib/features/maintenance/views/maintenance_log_entry_view.dart) | L307–L313 (success dialog "Bakım Kaydedildi") | `const TextStyle(fontSize: 20, fontWeight: FontWeight.bold)` | `textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.bold, color: colors.onSurface)` |
| [offline_banner.dart](file:///d:/Asansor/lib/core/widgets/offline_banner.dart) | L49–L55 | `TextStyle(fontSize: 12, …)` | `textTheme.labelSmall?.copyWith(…)` |
| [admin_calendar_view.dart](file:///d:/Asansor/lib/features/admin/views/admin_calendar_view.dart) | L163–L202 | `TextStyle()` passed to calendar widget | Use `textTheme.labelSmall?.copyWith(…)` where possible |
| [admin_master_calendar_view.dart](file:///d:/Asansor/lib/features/admin/views/admin_master_calendar_view.dart) | L255, L357–L404, L828 | Mixed `TextStyle` and `textTheme` | Unify to `textTheme.*?.copyWith(…)` |
| [calendar_assign_sheet.dart](file:///d:/Asansor/lib/features/admin/widgets/calendar/calendar_assign_sheet.dart) | L183, L215, L242, L269, L307, L328, L341 | Multiple `TextStyle(color: …)` | Replace with `textTheme.*?.copyWith(color: colors.*)` |
| [admin_map_view.dart](file:///d:/Asansor/lib/features/admin/views/admin_map_view.dart) | L412–L413, L530–L531 | `TextStyle(fontSize: 12/11)` | `textTheme.labelSmall?.copyWith(…)` |

> [!NOTE]
> `pdf_service.dart` uses `pw.TextStyle` (the `printing` package). These are **PDF-only** and intentionally hardcoded at print resolution — they are **exempt** from Flutter text theming.

### Category B — `fontSize` overrides that bypass the type scale

Some widgets use `textTheme.X?.copyWith(fontSize: Y)` which overrides the central type scale. These should be audited but are lower priority than standalone `TextStyle`s.

---

## Pillar 3 — Responsive Layouts & Scaling

### Category A — Rigid fixed heights / widths without `MediaQuery` scaling

| File | Widget / Issue | Fix |
|---|---|---|
| [login_view.dart](file:///d:/Asansor/lib/features/auth/views/login_view.dart) | Hero panel uses `screenH * 0.38` — check it clamps correctly on tablets (≥600 dp) | Add `.clamp(220.0, 320.0)` |
| [admin_statistics_dashboard.dart](file:///d:/Asansor/lib/features/admin/views/admin_statistics_dashboard.dart#L484) | `height: 220` (chart container) — fixed regardless of screen size | Replace with `(screenH * 0.28).clamp(180.0, 260.0)` |
| [add_elevator_view.dart](file:///d:/Asansor/lib/features/elevator/views/add_elevator_view.dart#L248) | `height: 200` (map preview?) | Apply `.clamp()` based on screen height |
| Various `SizedBox(height: 40)` in scroll views | Absolute gaps in `ListView` children | Replace with `AppSpacing.xl` (32) or `AppSpacing.xxl` (48) tokens |

### Category B — `AppSpacing` token adoption

The `AppSpacing` class exists but many files still use raw integer literals for padding and spacing. All `const EdgeInsets.all(16)`, `const EdgeInsets.all(24)`, `const EdgeInsets.all(32)` should be expressed as `AppSpacing.md`, `AppSpacing.lg`, `AppSpacing.xl` respectively.

Priority files with the most raw spacing literals:
1. `admin_conflict_management_view.dart` — uses raw `16`, `20`, `40`, `100`
2. `admin_conflict_detail_dialog.dart` — uses raw `20`, `16`, `8`, `12`, `24`
3. `fault_detail_view.dart` — uses raw `16`, `20`, `40`, `32`
4. `elevator_list_view.dart` — uses raw `16`, `12`, `8`
5. `user_management_view.dart` — uses raw `16`, `10`, `12`, `24`, `14`

### Category C — Missing `LayoutBuilder` / `MediaQuery` for multi-size support

The app is locked to portrait mode but still needs to handle:
- Small phones (< 360 dp width): font scaling must remain legible
- Tablets (> 600 dp width): dashboard grids should expand to 3+ columns

| File | Current | Recommended |
|---|---|---|
| `admin_dashboard_view.dart` | `LayoutBuilder` already in use ✅ | Verify breakpoints at 600 dp |
| `elevator_list_view.dart` | Single-column `ListView` | Add `LayoutBuilder` → `GridView` at ≥ 600 dp |
| `user_management_view.dart` | Single-column list | Add `LayoutBuilder` for tablet layout |
| `technician_management_view.dart` | Single-column list | Same as above |

---

## Pillar 4 — State-Driven UI Dynamics

### Category A — Missing animated transitions on state changes

| File | Current Behavior | Improvement |
|---|---|---|
| [fault_detail_view.dart](file:///d:/Asansor/lib/features/fault/views/fault_detail_view.dart) | `AnimatedSwitcher` on the status icon ✅ | Extend to the subtitle text below the icon |
| [elevator_list_view.dart](file:///d:/Asansor/lib/features/elevator/views/elevator_list_view.dart) | `FadeInSlide` on list items ✅ | Add `AnimatedSwitcher` on the filter chips row when `_selectedStatus` changes |
| [user_management_view.dart](file:///d:/Asansor/lib/features/admin/views/user_management_view.dart) | Tab switch is instant | Wrap `TabBarView` content panes with `AnimatedSwitcher` |
| `admin_statistics_dashboard.dart` | Charts appear instantly | Wrap chart containers with `AnimatedOpacity` / `FadeInSlide` on first build |

### Category B — Loading skeleton coverage

| Screen | Current | Gap |
|---|---|---|
| `fault_detail_view.dart` (loading state) | Full-screen `LoadingState` ✅ | AppBar also shown during load — good |
| `user_management_view.dart` | `CircularProgressIndicator` only | Replace with `LoadingState(count: 4)` shimmer skeleton |
| `elevator_list_view.dart` | `LoadingState(count: 6)` ✅ | — |
| `admin_conflict_management_view.dart` | `CircularProgressIndicator` | Replace with `LoadingState(count: 3)` |

### Category C — Error state consistency

`admin_conflict_management_view.dart` uses a custom `_ErrorState` widget that duplicates the `ErrorState` core widget. Replace with the shared core widget for consistency.

---

## Proposed Execution Order

Phases are ordered from highest risk reduction to lowest:

### Phase 1 — Color Tokens (Critical)
Fix all `AppColors.*` direct usages and file-scoped `const Color(0xFF…)` declarations. This is the highest-priority work because it causes incorrect dark-mode rendering.

**Files to touch (in order):**
1. `app_colors.dart` — add `navyDark = Color(0xFF1E293B)` token and wire it into `AppThemeColors` (light keeps `navy`, dark uses `navyDark`). This must land first since Phase 1 files depend on it.
2. `admin_conflict_management_view.dart` — most violations, touches `AppColors.*` and `const Color`; gradient stop now uses `colors.navy`
3. `admin_conflict_detail_dialog.dart` — file-scoped color constants
4. `admin_statistics_dashboard.dart` — `const Color(0xFF4ADE80)` + `Colors.white*` on header
5. `technician_management_view.dart` — `const Color(0xFF4ADE80)` accent
6. `user_management_view.dart` — technician badge bg uses `colors.primaryDark.withValues(alpha: 0.25)` in dark, `colors.primaryFixed` in light (no new static token)
7. `fault_detail_view.dart` — `Colors.white` → `colors.onPrimary`; confetti mapped to `[colors.success, colors.blue, colors.error, colors.warning, colors.violet]`
8. `scanner_view.dart` — `Colors.greenAccent.shade400` → `colors.successLight`

### Phase 2 — Typography Normalization
Replace all standalone `TextStyle(…)` instances with `textTheme.*?.copyWith(…)` equivalents.

**Files to touch (in order):**
1. `admin_conflict_management_view.dart` (9 sites)
2. `admin_conflict_detail_dialog.dart` (5 sites)
3. `maintenance_log_entry_view.dart` (success dialog)
4. `offline_banner.dart`
5. `admin_statistics_dashboard.dart` (chart labels)
6. `checklist_management_view.dart`
7. `calendar_assign_sheet.dart`
8. `admin_map_view.dart`
9. `admin_master_calendar_view.dart`
10. `admin_calendar_view.dart`

### Phase 3 — Shadow Color Tokens
Sweep all `Colors.black.withValues(alpha: X)` shadow usages and replace with `colors.onSurface.withValues(alpha: X)`.

### Phase 4 — Spacing Tokens
Replace raw spacing literals with `AppSpacing.*` constants across high-traffic files.

### Phase 5 — Responsive Layout Enhancements
Add **width-based** `LayoutBuilder` grid expansions for tablet portrait (≥ 600 dp). Landscape and true multi-window support are deferred until the portrait orientation lock is lifted.

### Phase 6 — Animation & Skeleton Polish
Add `AnimatedSwitcher` transitions and replace `CircularProgressIndicator` with shimmer skeletons.

---

## Resolved Decisions

All open questions have been answered by the user. These decisions are final and baked into the relevant phases above.

| # | Question | Decision |
|---|---|---|
| Q1 | `navy` in dark mode | ✅ Add `navyDark = Color(0xFF1E293B)` to `AppColors` and wire into `AppThemeColors`. Gradient stops use `colors.navy` (light) / `colors.navyDark` (dark). |
| Q2 | `primaryFixed` in dark mode | ✅ **No new static token.** Technician badge bg dynamically falls back to `colors.primaryDark.withValues(alpha: 0.25)` in dark mode. |
| Q3 | Confetti colors | ✅ Map to app palette: `[colors.success, colors.blue, colors.error, colors.warning, colors.violet]`. |
| Q4 | Phase 5 scope | ✅ Width-based grid expansion for tablet portrait (≥ 600 dp) only. Landscape deferred. |

---

## Verification Plan

### After Each Phase
- Run `flutter analyze` — zero new warnings.
- Hot-reload in both **light mode** and **dark mode** on a simulator and confirm no visual regressions.

### Full Regression Check (After All Phases)
- Toggle system theme between light/dark; verify every screen adapts correctly.
- Walk through: Login → Admin Dashboard → Statistics → Technician List → User Management → Elevator List → Fault Detail → Maintenance Log Entry → Conflict Management.
- Confirm no `Colors.white` or `Colors.black` text appears on a same-tone background in either mode.
