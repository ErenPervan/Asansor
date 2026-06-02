# QA Validation Report: Security and Architecture Audit

## Executive Summary
I have conducted a thorough "Red Team" validation of the `SECURITY_AND_ARCHITECTURE_AUDIT.md` report against the actual Flutter/Riverpod and Supabase codebase. 

The original auditor's report is exceptionally accurate. There are **no false positives** or hallucinations. Every reported issue exists exactly as described, and the proposed architectural fixes are idiomatic, practical, and highly recommended for a production-grade application.

However, during the cross-examination, I identified **two significant blind spots (Missing Criticals)** in the router and RLS migrations that the original auditor missed.

---

## 1. False Positives & Hallucinations
**Verdict: 100% Accurate. No False Positives.**

I cross-referenced the auditor's claims with the codebase and confirmed their validity:
- **`SyncQueueService` Dropping Writes**: Verified in `lib/core/services/sync_queue_service.dart:156-175`. The queue enforces a 100-item limit by silently deleting the oldest entries (`_box.deleteAll(keysToRemove)`).
- **Maintenance Side-Effect Retries**: Verified in `lib/core/services/sync_queue_service.dart:356-385`. If `_completeMatchingSchedule` fails (it silently catches exceptions), the queue retries from `pdf_pending`, generating redundant PDFs.
- **Conflict Resolution (Compare-and-Swap)**: Verified in `lib/features/admin/conflicts/admin_conflict_provider.dart:103-111`. `resolveForceLocal()` updates the DB by incrementing the remote version directly (`sanitized['version'] = currentVersion + 1`) and ignoring the current DB state with a simple `.eq('id', report.elevatorId)`.
- **Profile RLS Self-Escalation**: Verified in `supabase/migrations/20260531000001_remove_duplicate_profile_rls.sql`. The broad `"Profiles: Users view/update own"` policy permits any authenticated user to update *any* column on their profile, including changing their own `role` to `admin`.
- **Fault Webhook Unauthenticated Forgery**: Verified in `supabase/migrations/20260531000002_database_webhook_setup.sql`. It relies on a hardcoded anon key and Edge Functions deployed with `--no-verify-jwt` without checking a shared secret.
- **Public Maintenance Reports**: Verified in `supabase/migrations/20260516000000_create_maintenance_reports_bucket.sql`. The bucket is initialized with `public = true` and `FOR UPDATE TO authenticated`, allowing anyone to tamper with reports.

---

## 2. Blind Spots (Missing Criticals)
The original auditor missed the following two high-severity issues:

### CRITICAL: Route bypass allows customers with no elevator to access the dashboard
- **File/lines:** `lib/core/router/app_router.dart:132-147`
- **Failure scenario:** The `app_router.dart` is supposed to redirect customers who don't have an assigned elevator to `/customer/no-elevator`. However, the redirect logic includes:
  ```dart
  final isOnDashboard = loc == '/customer/dashboard';
  // ...
  if (isOnDashboard || isOnNoElevatorPage || isOnFaultDetail) return null;
  ```
  Because `isOnDashboard` returns `null` (allowing navigation to proceed) *before* checking if `custElevatorId != null`, a customer with no assigned elevator can bypass the restriction entirely by deep-linking to `/customer/dashboard`.
- **Impact:** Customers bypass the onboarding/blocking flow and access a dashboard state that may throw null-reference errors or query unauthorized data.

### HIGH: `conflict_reports` RLS fails to verify the user is actually a technician
- **File/lines:** `supabase/migrations/20260517005000_add_occ_elevator_versioning.sql:45-54`
- **Failure scenario:** The policies intended to restrict `conflict_reports` to technicians do not actually check the user's role:
  ```sql
  -- Technicians can insert their own reports
  CREATE POLICY "Technicians can insert their own conflict reports"
      ON public.conflict_reports FOR INSERT
      WITH CHECK (auth.uid() = technician_id);
  ```
  This policy only verifies that the `technician_id` matches the authenticated user's ID. It fails to join against the `profiles` table to ensure the user is actually a `technician`.
- **Impact:** Any authenticated user (including customers) can insert garbage conflict reports for any elevator, provided they set the `technician_id` payload to their own `uid`.

---

## 3. Quality of Proposed Fixes
**Verdict: Excellent.**

The architectural fixes suggested by the first auditor are robust and address the root causes rather than just patching symptoms:
- **Offline Sync & State Management**: Transitioning to an explicitly defined durable state machine with idempotency keys (`SyncItemType`) and a Riverpod `SyncCoordinator` is the gold standard for Flutter offline-first applications. 
- **Routing & RBAC**: Clearing `routerRoleNotifier` on every auth event and utilizing a proper state machine for authentication (`profileLoading`, `authorized`, `unauthorized`) will reliably eliminate the stale-admin-state issues and `/loading` deadlocks. 
- **Backend Security**: Using standard `x-webhook-secret` headers for the Edge Functions and pinning the `search_path` on the Postgres `SECURITY DEFINER` triggers are critical, standard security practices that the project currently lacks.

No alternative fixes are necessary; the engineering team should adopt the original auditor's recommendations verbatim, alongside fixing the two blind spots identified above.
