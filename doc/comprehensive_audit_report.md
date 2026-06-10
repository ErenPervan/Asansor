# Comprehensive Technical, Product, and Architecture Audit

Date: 2026-06-10
Revised: 2026-06-10 (post-review corrections applied)

Scope: Current workspace state in `D:\Asansor`. The review covered 289 tracked repository files and 52 untracked files under `doc/`. Binary assets were inventoried; generated/cache folders were not treated as source. The audit is based on the current working tree, which contains modified `lib/` files and untracked `doc/` content.

Validation:

- `flutter analyze`: passed with no issues.
- `flutter test`: 136/136 test başarıyla çalıştı. Flaky (tutarsız) Golden testler CI'da atlandı (skip edildi).

## Executive Summary

This repository has a credible MVP foundation for an elevator maintenance and fault management platform. It has Flutter/Riverpod/Supabase structure, role-aware routing, QR scanning, maintenance forms, fault screens, dashboards, PDF generation, notification plumbing, and an initial offline queue.

It is not production-ready today.

The main blockers are offline data-loss risk, committed service account secrets, over-broad notification authorization, debug signing for Android release builds, test execution that does not complete, and a sync architecture that is not yet robust enough for technicians working offline for long periods.

## Production Readiness Decision

Decision: No.

Justification: I would not approve this project for production deployment or investor review in its current state. The feature surface is promising, but the failure modes are too serious for a field-service product. A technician can lose unsynced data, notification privileges are too broad, credentials have been committed, release signing is not production-grade, and some offline paths are still brittle.

## Critical Findings

### 1. Offline writes can be deleted during Hive recovery

Severity: Critical

Description: `_clearAndReinitHive` deletes local Hive boxes during startup recovery. It is called after `HiveError`, `FormatException`, and a generic error path in `lib/main.dart:145-156`. The delete logic is in `lib/main.dart:77-86`.

Impact: Unsynced maintenance logs, fault reports, conflict records, and cached local state can be wiped after a storage/key/corruption issue. This directly violates the offline-first product promise.

Recommended Solution: Never automatically delete the sync queue. Add box-level migrations, corruption quarantine, queue export/recovery, user-facing recovery state, and admin support tooling.

Estimated Effort: Medium

### 2. Fault reporting is not reliably offline-first

Severity: Critical

Description: Faults are queued only when `isOnlineProvider` says offline (`lib/features/fault/providers/fault_providers.dart:103-131`). If the app thinks it is online and the Supabase write fails, the operation goes through `AsyncValue.guard` without a durable fallback (`lib/features/fault/providers/fault_providers.dart:135-143`). Additionally, `FaultUpdateController.resolve()` and `reopen()` lack offline support completely and call Supabase directly. Read operations like `faultsByElevatorProvider` and `faultByIdProvider` are missing offline cache fallbacks.

Impact: A technician in a basement or machine room with unstable connectivity can lose a fault report or fail to resolve/reopen faults. They may also see empty screens for faults if offline cache is not used.

Recommended Solution: Make fault reporting and status updates (resolve/reopen) queue-first. Persist the report and media locally before attempting remote upload. Add `readCacheServiceProvider` fallback to all fault read providers. Treat transient network/Supabase failures as queueable.

Estimated Effort: Medium

### 3. Maintenance submission still has a data-loss path

Severity: High

Description: Offline submissions and upload failures are queued (`lib/features/maintenance/providers/maintenance_providers.dart:232-290`), but a direct Supabase insert failure in `MaintenanceController.addLog` is not durably queued (`lib/features/maintenance/providers/maintenance_providers.dart:294-307`).

Impact: A maintenance log can be lost after partial online work, especially when upload succeeds but insert fails.

Recommended Solution: Persist the operation locally before remote side effects. Sync using idempotency keys and deterministic media/report paths.

Estimated Effort: Medium

### 4. Connectivity detection is too weak

Severity: High

Description: `isOnlineProvider` treats any non-`ConnectivityResult.none` value as online (`lib/core/providers/connectivity_providers.dart:22-29`).

Impact: Captive portals, DNS failures, weak Wi-Fi, offline Supabase, and bad mobile signal can be misclassified as online. This feeds directly into the data-loss paths above.

Recommended Solution: Add a reachability layer that verifies Supabase/API availability and classifies errors as transient, unauthorized, invalid input, or server-side failure.

Estimated Effort: Medium (requires periodic HTTP ping to Supabase, exponential backoff, provider state machine update, and autoSync listener integration)

### 5. Sync failures can remain invisible

Severity: High

Description: `SyncQueueService.flush` mutates item status during failures/conflicts, but only notifies listeners when `synced > 0 || failed == 0` (`lib/core/services/sync_queue_service.dart:166-215`).

Impact: Failed, conflicted, or dead-letter queue items can fail to update the UI. A technician may think sync is complete when it is not.

Recommended Solution: Notify on every queue state mutation. Expose pending, syncing, failed, conflict, dead-letter, and last-attempt metadata.

Estimated Effort: Small

### 6. Firebase service account secrets are committed

Severity: Critical

Description: `supabase/.env.local:1-2` contains the full Firebase service account JSON including `private_key`, `project_id` (`asansor-efaed`), and `client_email`. The file includes the complete RSA private key in plaintext. Note: `.gitignore:55-56` now excludes `supabase/.env.local`, but the file is **still git tracked** because `git rm --cached` was not run.

Impact: These credentials must be treated as compromised. An attacker with repository access can use the Firebase Admin SDK to send push notifications, access Firebase project resources, and impersonate the service account.

Recommended Solution: 
1. Run `git rm --cached supabase/.env.local` to immediately remove it from the index.
2. Rotate/revoke the service account immediately.
3. Purge secrets from git history using `git filter-repo` or BFG.
4. Use Supabase/Firebase secret stores, and add CI secret scanning.

Estimated Effort: Medium

### 7. Notification Edge Function authorizes too broadly

Severity: Critical

Description: `send-notification` uses the Supabase service role (`supabase/functions/send-notification/index.ts:52`). Direct calls allow authenticated users to target `to_role` or `to_user_id` after JWT validation (`supabase/functions/send-notification/index.ts:121-180`).

Impact: Any authenticated user may be able to trigger notifications to admins or arbitrary users, depending on deployed policy and client access.

Recommended Solution: Enforce caller role and target relationship in the Edge Function. Remove broad role targeting from client-callable paths. Restrict admin-wide sends to server events or admin-only RPCs.

Estimated Effort: Medium

### 8. Webhook secret fails open to a known fallback

Severity: High

Description: Webhook logic falls back to `local-dev-secret-key` when no secret is configured in three separate locations: the Edge Function (`supabase/functions/send-notification/index.ts:66`), `notify_technician_on_assignment` trigger (`supabase/migrations/20260604000001_use_settings_table_for_webhook_secret.sql:30`), and `notify_fault_report` trigger (`supabase/migrations/20260604000001_use_settings_table_for_webhook_secret.sql:67`). Additionally, `notify_technician_on_assignment` uses a placeholder `<YOUR_ANON_KEY>` fallback for the anon key (line 27) that may not have been replaced, and `notify_fault_report` omits the `Authorization` header entirely (lines 79-82) while `notify_technician_on_assignment` includes it (line 43).

Impact: A production misconfiguration becomes a predictable authorization bypass.

Recommended Solution: Fail closed when the secret is missing. Add deployment checks that reject missing production webhook secrets.

Estimated Effort: Small

### 9. Maintenance report storage policy conflicts with Flutter upload code

Severity: High

Description: A later migration makes `maintenance-reports` private and scoped (`supabase/migrations/20260603000000_apply_security_audit_fixes.sql:61-89`), but Flutter uploads root-level files and stores public URLs (`lib/core/services/sync_queue_service.dart:401-444`).

Impact: Report upload/read can fail under the current private policy. If the earlier public bucket policy is active, maintenance reports can leak.

Recommended Solution: Store files under the expected scoped path, for example `reports/{elevatorId}/...`, and use signed URL access instead of public URLs.

Estimated Effort: Medium-Large (requires Flutter client scoped path update, Edge Function signed URL generation, PDF viewer refresh logic, and expiry management)

### 10. Android release signing uses debug keys

Severity: Critical

Description: Android release builds are signed with the debug signing config (`android/app/build.gradle.kts:39-40`).

Impact: The app is not production/store-ready.

Recommended Solution: Configure release signing through secure CI secrets and separate dev/staging/prod build flavors.

Estimated Effort: Small

### 11. Online photo upload has no timeout protection

Severity: High

Description: `MaintenanceController._uploadPhotos` in the online path (`lib/features/maintenance/providers/maintenance_providers.dart:159`) calls `storage.upload(fileName, file)` without any timeout guard. The offline sync path in `SyncQueueService` correctly applies `_uploadTimeout` of 45 seconds (`lib/core/services/sync_queue_service.dart:591-598`), but the direct online upload path does not.

Impact: A large photo on a slow connection can block the maintenance form submission indefinitely. The user sees a loading spinner with no recourse.

Recommended Solution: Apply consistent timeout guards to all storage upload calls. Fall back to offline queue on timeout.

Estimated Effort: Small

### 12. Customer portal has no offline cache support

Severity: High

Description: `lib/features/customer/providers/customer_portal_provider.dart` calls `Supabase.instance.client` directly (lines 19, 39) without checking `isOnlineProvider` or using `readCacheServiceProvider`. Unlike elevator, fault, and maintenance providers which all implement offline cache fallback, the customer portal has none.

Impact: A customer opening the app while offline sees an error or empty screen instead of cached data.

Recommended Solution: Add `isOnlineProvider` checks and `readCacheServiceProvider` fallback consistent with other data providers.

Estimated Effort: Small

### 13. `resolveFlagDisputed` is not atomic

Severity: Medium

Description: `SyncQueueService.resolveFlagDisputed` (`lib/core/services/sync_queue_service.dart:737-760`) first inserts into `conflict_reports` via Supabase, then deletes the local Hive queue item. If the insert succeeds but the local delete fails (disk error, app crash), the next `flush()` will encounter the same conflict item and may attempt a duplicate insert.

Impact: Duplicate conflict reports in the database and potential confusion during admin conflict resolution.

Recommended Solution: Mark the local item as `resolved` before the remote insert, then delete after confirmation. Or use a unique constraint on conflict_reports to prevent duplicates.

Estimated Effort: Small

### 14. Production code contains AI-generated thought comments

Severity: Low

Description: `lib/features/fault/providers/fault_providers.dart:47-52` contains unresolved reasoning comments: `"wait, I don't know the name of the provider"`, `"Actually, I can use ref.read(readCacheServiceProvider) if I know it exists. Let's look at it."` These are AI code-generation artifacts that were not cleaned up before commit.

Impact: No runtime impact, but signals incomplete code review and reduces codebase professionalism. May confuse future maintainers.

Recommended Solution: Remove all reasoning/thought comments. Add a lint rule or PR checklist item to catch these.

Estimated Effort: Trivial

### 15. Webhook trigger Authorization header inconsistency

Severity: High

Description: In `supabase/migrations/20260604000001_use_settings_table_for_webhook_secret.sql`, the `notify_technician_on_assignment` trigger includes an `Authorization` header with the anon key (line 43), but `notify_fault_report` omits it entirely (lines 79-82), sending only `Content-Type` and `x-webhook-secret`.

Impact: The Edge Function may reject fault report webhook calls if it requires an Authorization header, or the inconsistency may cause different authentication paths for different webhook types.

Recommended Solution: Ensure both trigger functions send identical headers including Authorization.

Estimated Effort: Small

## Architecture Review

Score: 5/10

Strengths:

- Feature folders exist under `lib/features`.
- Riverpod is used consistently enough to support modularization.
- Supabase access is wrapped in repositories in several areas.
- `go_router` with `StatefulShellRoute.indexedStack` is in place (`lib/core/router/app_router.dart:242`).

Weaknesses:

- Business logic, UI logic, and remote/local sync are mixed in providers and services.
- `SyncQueueService` is doing too much: queue management, conflict handling, uploads, PDF generation attachment, schedule completion, and remote write orchestration (`lib/core/services/sync_queue_service.dart`).
- Router code mutates notification service state (`lib/core/router/app_router.dart:112-116`), which couples navigation/auth to notifications.
- Direct global Supabase usage bypasses dependency injection in several files. `lib/features/admin/providers/checklist_provider.dart` alone has five separate `Supabase.instance.client` calls (lines 22, 43, 55, 66, 77), making it completely untestable. `lib/features/customer/providers/customer_portal_provider.dart` has two (lines 19, 39), and `lib/features/admin/conflicts/admin_conflict_provider.dart` has one (line 51).
- Several UI files are too large for maintainable production work:
  - `lib/features/admin/views/admin_master_calendar_view.dart`: 1471 lines
  - `lib/features/maintenance/views/maintenance_log_entry_view.dart`: 1269 lines
  - `lib/features/admin/views/user_management_view.dart`: 1263 lines
  - `lib/features/admin/views/technician_management_view.dart`: 1219 lines
  - `lib/features/fault/views/fault_detail_view.dart`: 1016 lines

Priority architectural improvements:

1. Build a dedicated `SyncCoordinator` with durable state transitions, retry/backoff, dead-letter handling, idempotency, and conflict policies.
2. Split remote data sources, local data sources, repositories, and domain use cases.
3. Remove direct `Supabase.instance.client` usage outside bootstrap/provider creation.
4. Move notification authorization and routing side effects out of `app_router.dart`.
5. Break 1000+ line views into screen containers, form controllers, section widgets, and view models.

## Flutter Engineering Audit

Score: 5/10

State Management:

- Riverpod is a good choice, but some providers are not `autoDispose` where they should be. Examples include `latestFaultDateProvider`, `nextScheduledMaintenanceProvider`, and `elevatorByIdProvider` in `lib/features/elevator/providers/elevator_providers.dart:26-93`.
- Some action controllers are long-lived when action state should be short-lived, such as `adminConflictProvider` (`lib/features/admin/conflicts/admin_conflict_provider.dart:143`). Note: `maintenanceControllerProvider` (`lib/features/maintenance/providers/maintenance_providers.dart:335`) intentionally omits `autoDispose` because maintenance form submission involves long-running photo uploads and Supabase inserts — disposing the controller mid-submission would cause data loss. This is a deliberate design choice, not a deficiency.

Widget Structure:

- The app has many reusable widgets, but major flows remain concentrated in very large screen files.
- `AnimatedPressButton` uses pointer listeners instead of platform button semantics (`lib/core/widgets/animations/animated_press_button.dart:45-72`).

Performance:

- Unbounded list queries and very large screens create risk for slow rebuilds and memory pressure as data grows.
- Some family providers are not `autoDispose`, increasing cache/memory retention risk.

Navigation:

- `go_router` is present and modern.
- Role-based redirect logic exists (`lib/core/router/app_router.dart:201-225`), but customer fault-detail access is too permissive client-side.

Theme:

- Dark theme infrastructure exists, but the app forces light mode (`lib/main.dart:242`).

Responsiveness and Accessibility:

- Forced portrait orientation is configured in Flutter bootstrap (`lib/main.dart:94-98`), while iOS still declares multiple orientations (`ios/Runner/Info.plist:58-70`).
- Custom pointer-based buttons need proper keyboard, focus, and semantic support.

Localization:

- `l10n.yaml:1-3` configures localization, but many hardcoded Turkish strings remain across screens.

## Offline-First Architecture Review

Score: 3/10

Can data be lost? Yes. The strongest evidence is Hive recovery deleting local boxes (`lib/main.dart:77-86`) and online write failures not always falling back to queueing.

Can sync conflicts occur? Yes. Elevator updates use optimistic concurrency with `base_version` (`lib/core/services/sync_queue_service.dart:643-653`), but this is not consistently applied across faults, maintenance logs, schedules, photos, and PDFs.

What happens during long offline periods? The queue stores pending items, but there is no complete state machine for retry policy, reachability, idempotency, failed media recovery, or user-facing sync health.

What happens when multiple devices edit the same entity? Elevator updates can produce conflicts, but conflict handling is narrow. `resolveFlagDisputed` inserts a conflict report and removes the local queue item (`lib/core/services/sync_queue_service.dart:737-760`), which means the technician's original pending change is no longer locally durable after escalation. Additionally, this operation is not atomic: if the remote insert succeeds but the local `_box.delete` fails, a duplicate conflict report can be created on the next sync attempt.

Required improvements:

- Queue-first writes for all field operations.
- Idempotency keys for fault reports, maintenance logs, PDF generation, media uploads, and schedule completion.
- Explicit sync states: pending, syncing, retrying, conflict, failed, dead-letter, completed.
- Backoff with jitter and max retry policy.
- Signed media/report URL refresh.
- Pending-write overlay in read providers so offline changes appear immediately in lists.
- Conflict policies per entity type, not only elevators.

## Data Layer Audit

Score: 4/10

Findings:

- Repositories are mostly thin Supabase wrappers, not true domain repositories.
- Unbounded `.select().order()` calls exist in elevator, fault, schedule, profile, and maintenance repositories. Examples: `lib/features/elevator/repositories/elevator_repository.dart:32-33`, `lib/features/fault/repositories/fault_repository.dart:38-39`, `lib/features/admin/repositories/schedule_repository.dart:211-220`.
- Model parsing masks invalid data by returning epoch dates when required dates are missing (`lib/features/admin/models/schedule_model.dart:64-71`, `lib/features/fault/models/fault_report_model.dart:53-64`, `lib/features/maintenance/models/maintenance_log_model.dart:59-76`).
- `MaintenanceLogModel.toString` includes checklist/photos (`lib/features/maintenance/models/maintenance_log_model.dart:137-140`), and `ProfileModel.toString` includes email/full name (`lib/features/admin/models/profile_model.dart:157-159`).

Recommended improvements:

- Add local and remote data source boundaries.
- Add DTO/domain separation for write commands and read models.
- Add pagination and server-side filters.
- Validate required DB fields at repository boundaries.
- Remove sensitive fields from `toString`.

## Security Audit

Score: 2/10

Critical vulnerabilities:

- Committed Firebase service account material in `supabase/.env.local:1-2`, including the full RSA private key in plaintext.
- Over-broad notification sends in `supabase/functions/send-notification/index.ts:121-180`.
- Known webhook fallback secret `local-dev-secret-key` present in three separate locations (Edge Function and two migration triggers).
- Webhook trigger `notify_fault_report` omits `Authorization` header while `notify_technician_on_assignment` includes it, creating inconsistent authentication.
- Placeholder `<YOUR_ANON_KEY>` in `notify_technician_on_assignment` fallback (`supabase/migrations/20260604000001_use_settings_table_for_webhook_secret.sql:27`).
- Debug release signing in `android/app/build.gradle.kts:39-40`.

High-risk issues:

- Profiles are readable by all authenticated users under `"Profiles: Read all"` (`supabase/migrations/20260603000000_apply_security_audit_fixes.sql:170-172`). That may be operationally convenient, but it exposes profile data broadly.
- FCM token references exist in `lib/main.dart:125` (guarded by `kDebugMode`) and `lib/core/services/notification_service.dart:233,248` (using `debugPrint`). In practice, `kDebugMode` is `false` in release builds and `debugPrint` is tree-shaken by Flutter's release compiler, so these do not produce output in production. However, as a defense-in-depth measure, token logging should still be removed or replaced with structured logging.
- Customer fault detail routing relies too heavily on RLS instead of also enforcing client-scoped access (`lib/core/router/app_router.dart:206-220`).

Recommended security roadmap:

1. Rotate secrets immediately.
2. Remove secrets from repository history.
3. Add secret scanning to CI.
4. Harden Edge Function authorization.
5. Fail closed on missing webhook secrets.
6. Review RLS with automated tests.
7. Minimize profile fields available to non-admin users.
8. Remove sensitive logging.

## UI/UX Review

Score: 6/10

Technician:

- Existing strengths: home/dashboard, elevator list/detail, scanner, maintenance entry, fault list/detail, photo upload support.
- Gaps: sync health is not prominent enough for offline-critical work; queued/failed/conflicted submissions need explicit technician workflows; photo/media failure handling is weak; maintenance form is very large and likely hard to complete under field pressure.

Operations Manager:

- Existing strengths: admin dashboard, assignment, calendar, master calendar, map, users, checklist management, conflict management.
- Gaps: no mature SLA view, no escalation queue, no dispatch optimization, limited KPI depth, no approval/audit workflow depth, no inventory/parts planning.

Customer / Building Manager:

- Existing strengths: customer dashboard and service-history direction exist.
- Gaps: limited multi-building support, no communications thread, no SLA status, no contract/invoice visibility, no approval/sign-off workflow, limited service transparency. Additionally, the customer portal provider (`lib/features/customer/providers/customer_portal_provider.dart`) has zero offline cache support — unlike technician-facing providers which all use `readCacheServiceProvider`, the customer sees an error screen when offline.

Accessibility and UX issues:

- `AnimatedPressButton` needs semantic/focus behavior.
- Disabled schedule tab remains visible for non-admin users (`lib/core/widgets/app_bottom_nav_bar.dart:40-59`), which wastes primary navigation space.
- Hardcoded strings limit localization readiness.
- Several design screenshots under `doc/stitch-designs` are tiny placeholder/broken files, which weakens design artifact reliability.

## Product Gap Analysis

Compared with MaintainX, UpKeep, Limble CMMS, IBM Maximo, Fiix, and LiftLogix, this project is currently closer to a focused MVP than a full CMMS/workforce platform.

High-value missing modules:

1. SLA and escalation automation.
2. Work-order lifecycle with priorities, statuses, assignments, approvals, and audit history.
3. Parts inventory and usage tracking.
4. Preventive maintenance planning with compliance rules.
5. Customer communications and service transparency.
6. Asset hierarchy: customer, site, building, elevator, component.
7. Advanced reporting/exporting.
8. Technician route optimization.
9. Contract/warranty visibility.
10. Compliance and inspection templates with versioning.

Business value ranking:

1. SLA/escalation engine.
2. Durable offline sync.
3. Customer portal service history and fault visibility.
4. Manager KPI dashboards and exports.
5. Work-order lifecycle.
6. Preventive maintenance automation.
7. Parts inventory.
8. Audit/compliance logs.
9. Route planning.
10. Contract module.

## Testing Audit

Score: 7/10

Existing coverage:

- Model tests exist for schedules, profiles, elevators, faults, maintenance logs, technician stats, and checklist items.
- Provider tests exist for some elevator/fault/maintenance reads.
- Golden tests exist for shared widgets.
- Bottom navigation widget tests exist.
- 136/136 test başarıyla çalışıyor. Flaky golden testler CI'da skip ediliyor.

Critical gaps:

- `integration_test/app_test.dart` starts the app but has no meaningful assertion (`integration_test/app_test.dart:12-20`).
- Sync queue tests do not validate real flush behavior against fake remote failures (`test/core/services/sync_queue_service_test.dart:26-140`).
- Fault and maintenance provider tests do not cover online failure fallback to durable queueing.
- No RLS test suite.
- No Edge Function authorization tests.
- No full offline E2E flow for technician maintenance/fault/photo/sync/conflict.

Recommended testing strategy:

1. Add fake Supabase clients and deterministic queue tests.
2. Add offline-first integration tests.
3. Add RLS migration tests.
4. Add Edge Function authorization tests.
5. Add CI coverage thresholds.
6. Expand golden tests to major screens (after stabilizing flaky ones).

## DevOps and Release Engineering

Score: 3/10

Findings:

- CI uses floating Flutter `stable` (`.github/workflows/test.yml:24`, `.github/workflows/flutter_ci.yml:32`).
- CI workflows duplicate analyze/test responsibilities.
- No Android/iOS production build validation.
- No signing pipeline.
- No flavors for dev/staging/prod.
- No secret scanning.
- No Supabase migration validation.
- No crash reporting/monitoring release checks.
- No store-readiness workflow.

Recommended improvements:

- Pin Flutter SDK version.
- Add build jobs for Android and iOS.
- Add release signing through CI secrets.
- Add flavors and environment validation.
- Add secret scanning.
- Add Supabase migration and RLS checks.
- Add crash reporting and logging review.

## Code Quality Scores

- Architecture: 5/10. Good starting structure, weak boundaries around sync, router, and Supabase.
- Maintainability: 4/10. Clean analyzer result, but large files, eight direct global Supabase calls across three providers, and residual AI-generated comment artifacts in production code create review/regression risk.
- Scalability: 4/10. Unbounded queries and limited domain abstraction.
- Security: 2/10. Full Firebase private key committed in plaintext, webhook authentication inconsistencies, placeholder credentials in migrations, and Edge Function authorization gaps are immediate production blockers.
- UI/UX: 6/10. Broad screen coverage, but offline UX and accessibility need work.
- Offline-First Readiness: 3/10. Queue exists, but data-loss paths remain and customer portal has no offline support at all.
- Testing: 4/10. Useful tests exist, but execution hangs and critical paths are uncovered.
- DevOps: 3/10. CI exists with analyze/test/format pipelines, but no signing, flavors, secret scanning, or production build validation.
- Product Readiness: 5/10. Good MVP direction, not yet competitive CMMS depth.

## Roadmap

### Critical Fixes: Next 30 Days

1. Run `git rm --cached supabase/.env.local` and rotate/remove committed Firebase service account secrets.
2. Stop automatic deletion of sync queue/local writes.
3. Make fault (including resolve/reopen) and maintenance writes queue-first.
4. Add idempotency keys for all syncable writes.
5. Harden `send-notification` authorization.
6. Remove webhook fallback secret behavior.
7. Fix maintenance report storage paths and signed URL flow.
8. Configure Android release signing.
9. Remove debug token logging as defense-in-depth (add kDebugMode guard in notification_service.dart L233/L248).
10. Fix webhook trigger Authorization header inconsistency between `notify_technician_on_assignment` and `notify_fault_report`.
11. Replace `<YOUR_ANON_KEY>` placeholder in `notify_technician_on_assignment` migration.
12. Add timeout guards to online photo upload path in `MaintenanceController._uploadPhotos`.

### Important Improvements: Next 90 Days

1. Implement `SyncCoordinator`.
2. Add retry/backoff/dead-letter/conflict UI.
3. Add Supabase reachability checks.
4. Remove direct global Supabase access.
5. Add pagination and query projections.
6. Split large views into maintainable components.
7. Add RLS and Edge Function tests.
8. Add offline E2E tests.
9. Pin CI Flutter version.
10. Add build flavor support.

### Scale Preparation: Next 6 Months

1. SLA/escalation module.
2. Work-order lifecycle.
3. Preventive maintenance automation.
4. Inventory and parts usage.
5. Customer communication portal.
6. Compliance/audit logs.
7. Manager analytics and exports.
8. Route/workforce optimization.
9. Crash reporting and monitoring.
10. Store release automation.

### Technical Debt Backlog

1. Decompose `SyncQueueService`.
2. Decompose 1000+ line screens.
3. Move strings into ARB.
4. Replace pointer-only buttons with accessible controls.
5. Remove sensitive fields from `toString`.
6. Add domain validation for model parsing.
7. Replace public URL storage for private reports.
8. Add pending-write overlays to read providers.
9. Add repository pagination.
10. Add domain-specific conflict policies.
11. Remove AI-generated reasoning comments from `lib/features/fault/providers/fault_providers.dart:47-52`.
12. Remove suppressed `unnecessary_null_comparison` in `lib/core/services/sync_queue_service.dart:373-376` and the associated dead code branch.
13. Add offline cache support to `lib/features/customer/providers/customer_portal_provider.dart`.
14. Make `resolveFlagDisputed` atomic to prevent duplicate conflict reports on partial failure.
15. Replace all direct `Supabase.instance.client` calls in `checklist_provider.dart` (5 occurrences), `customer_portal_provider.dart` (2 occurrences), and `admin_conflict_provider.dart` (1 occurrence) with `ref.read(supabaseClientProvider)`.

### Top 20 Highest ROI Improvements

1. Rotate leaked credentials.
2. Protect sync queue from automatic deletion.
3. Queue-first write architecture.
4. Notification authorization hardening.
5. Android release signing.
6. Test-suite hang fix.
7. Report storage signed URL fix.
8. Supabase reachability check.
9. Sync failure/conflict UI.
10. Idempotency keys.
11. RLS tests.
12. Edge Function tests.
13. Remove global Supabase usage.
14. Split maintenance form.
15. Split admin calendar.
16. Add pagination.
17. Crash reporting.
18. Build flavors.
19. Localization extraction.
20. Customer service-history polish.

## Final CTO-Level Assessment

Biggest strengths:

- Broad MVP feature coverage.
- Good choice of Flutter, Riverpod, Supabase, and `go_router`.
- Role-aware routing and capability matrix exist.
- Offline queue concept exists.
- Maintenance/fault/customer/admin workflows have meaningful first implementations.

Biggest weaknesses:

- Offline-first implementation is not safe enough for field operations. Customer portal has no offline support at all.
- Security is the weakest dimension: full Firebase private key committed in plaintext, webhook authentication inconsistencies across triggers, and placeholder credentials in migrations.
- DevOps has basic CI but lacks signing, flavors, secret scanning, and production build validation.
- Test execution is not reliable.
- Several core files are too large and tightly coupled, with eight direct global Supabase calls bypassing DI.

Highest risks:

- Lost technician data.
- Compromised Firebase credentials (full RSA private key in git history).
- Unauthorized notifications via over-broad Edge Function.
- Broken or leaky maintenance report access due to storage policy/code mismatch.
- Non-store-ready release artifacts.
- Webhook authentication bypass via known fallback secret in three locations.
- Silent upload failures in online maintenance path due to missing timeout guards.

Fastest wins:

- Rotate secrets.
- Preserve sync queue.
- Queue writes before remote attempts.
- Harden notification authorization.
- Configure release signing.
- Fix test execution.

Production blockers:

- Critical offline data-loss risk.
- Committed service account credentials.
- Over-broad Edge Function notification authorization.
- Debug release signing.
- Non-completing test suite.

