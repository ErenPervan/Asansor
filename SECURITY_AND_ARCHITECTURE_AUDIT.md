### 1. Offline Sync & State Management

#### CRITICAL: Offline writes are silently dropped when the queue exceeds 100 items
- **Files/lines:** `lib/core/services/sync_queue_service.dart:133-135`, `lib/core/services/sync_queue_service.dart:156-175`
- **Failure scenario / attack vector:** `SyncQueueService.enqueue()` writes the new operation and then enforces `maxQueueSize` by deleting the oldest queue entries. A technician working offline for an extended period, or a malicious/buggy UI repeatedly submitting fault reports, can push the Hive box over 100 entries and permanently delete earlier maintenance logs, fault reports, or elevator updates before they ever reach Supabase. This is especially severe because the deletion is only logged with `debugPrint`; the UI still reports the latest item as saved offline.
- **Impact:** Irrecoverable loss of maintenance/fault records and potential regulatory/audit data gaps. Local cache and remote Supabase state diverge with no conflict marker, no retry, and no user-visible failure.
- **Architectural fix:** Never evict unsynced domain writes to enforce a generic queue limit. Replace hard deletion with durable backpressure: reject new enqueue attempts with a surfaced error, require manual sync/export, or split queues by priority with no eviction for maintenance/fault records. Add an append-only audit journal and queue health metric. If storage protection is needed, cap media separately and keep metadata queued with explicit `media_missing` status.

#### CRITICAL: Maintenance log sync can create remote rows, then retry side effects repeatedly after partial failure
- **Files/lines:** `lib/core/services/sync_queue_service.dart:356-385`, `lib/core/services/sync_queue_service.dart:370-373`, `lib/core/services/sync_queue_service.dart:400-490`, `lib/core/services/sync_queue_service.dart:522-564`
- **Failure scenario / attack vector:** `_syncMaintenanceLog()` inserts the maintenance row, stores `pdf_pending`, then generates/uploads a PDF and completes matching schedules. If the app loses network after the insert but before PDF upload or schedule completion, the queue remains and later retries from `pdf_pending`. This protects against duplicate maintenance row inserts, but the remaining side effects are not idempotent: `_generateUploadAndAttachPdf()` creates a new timestamped PDF filename on every retry, and `_completeMatchingSchedule()` best-effort swallows all errors. A flaky connection can leave remote Supabase with a valid maintenance row, multiple orphaned PDF files, no `pdf_url`, or a schedule that remains pending while the log exists.
- **Impact:** Remote state diverges from the user-visible local success state. Customers/admins may see missing reports, duplicate storage artifacts, or incomplete task status despite a completed maintenance log.
- **Architectural fix:** Model sync as explicit durable steps with idempotency keys: `log_inserted`, `pdf_generated`, `pdf_uploaded`, `pdf_linked`, `schedule_completed`, `notifications_sent`. Use deterministic storage paths based on the maintenance log ID, upsert/replace semantics for PDF upload, and persist the uploaded `pdf_url` before linking. Do not swallow schedule completion failures silently; store a retryable side-effect item or mark the parent queue item as `side_effect_pending`.

#### HIGH: Auto-sync is fire-and-forget, so failures and lifecycle cancellation become zombie sync states
- **Files/lines:** `lib/core/providers/connectivity_providers.dart:89-113`, `lib/core/providers/connectivity_providers.dart:107-110`, `lib/features/elevator/widgets/home/home_top_app_bar.dart:283-301`
- **Failure scenario / attack vector:** `setupAutoSyncListener()` calls `queue.flush(...)` without `await`, `unawaited`, error handling, state reporting, or provider invalidation after completion. Manual sync also uses `.then(...)` without `.catchError(...)`. A thrown async error, route disposal, auth expiry, or Supabase timeout can complete outside Riverpod's observable state. Because `flush()` only calls `notifyListeners()` when `synced > 0 || failed == 0`, pure failure runs do not notify watchers, leaving badges and sync UI stale.
- **Impact:** Users can believe sync is in progress or complete while the queue still has failed items. Sync failures after reconnect are not surfaced, and cache-backed screens continue to show stale data until manually invalidated.
- **Architectural fix:** Introduce a Riverpod `SyncCoordinator`/`AsyncNotifier` that owns sync lifecycle state (`idle`, `running`, `failed`, `blockedByConflict`, `completed`). Always await flush in the coordinator, catch/report errors, and invalidate affected read providers after successful writes. Call `notifyListeners()` or publish state after every flush attempt, including all-failure runs.

#### HIGH: Connectivity is treated as internet reachability, causing online writes to bypass the queue during network toggles
- **Files/lines:** `lib/core/providers/connectivity_providers.dart:12-30`, `lib/features/maintenance/providers/maintenance_providers.dart:232-291`, `lib/features/fault/providers/fault_providers.dart:103-143`
- **Failure scenario / attack vector:** `isOnlineProvider` returns `true` while the connectivity stream is loading or errors, and treats any non-`none` transport as online. During captive portal, DNS outage, Supabase outage, token expiry, or a Wi-Fi/cellular toggle, maintenance logs enter the "online" path. Maintenance logs recover only upload failures by enqueueing; the later Supabase insert in `AsyncValue.guard()` is not converted to an offline queue item. Fault reports do not queue online-path failures at all.
- **Impact:** Payloads can be lost from the offline-first pipeline whenever the device has a network interface but cannot complete the Supabase write. The user sees an error state instead of durable offline persistence, and local read caches are not updated with a pending record.
- **Architectural fix:** Base write routing on a Supabase reachability/write failure policy, not `connectivity_plus` alone. For offline-first writes, always build the durable queue payload before attempting the network write; on any transient network/storage/db failure, persist that payload to the queue. Use operation-specific non-retryable error classification for auth/validation failures.

#### HIGH: Conflict resolution overwrites newer remote changes without compare-and-swap
- **Files/lines:** `lib/core/services/sync_queue_service.dart:690-711`, `lib/features/admin/conflicts/admin_conflict_provider.dart:93-117`, `lib/features/admin/conflicts/admin_conflict_provider.dart:107-110`
- **Failure scenario / attack vector:** `resolveForceUpdate()` fetches the latest version, stores it as `base_version`, and calls `flush()`. Between the fetch and update, another client can update the elevator. The local forced update may conflict again, but the user action is presented as a force update. The admin path is worse: `resolveForceLocal()` updates `elevators` with `.eq('id', report.elevatorId)` only, manually sets `version = remotePayload.version + 1`, and does not check the current remote version or conflict status. A stale admin dialog can overwrite newer remote state and move the version backward or sideways.
- **Impact:** Lost updates across technicians/admins and broken optimistic concurrency guarantees. Supabase can end up with a resolved conflict report whose forced payload did not account for intervening remote edits.
- **Architectural fix:** Resolve conflicts through a database RPC/transaction that checks `conflict_reports.status = 'pending'`, the elevator's current `version`, and the conflict report's recorded remote version in one atomic operation. Use `update(...).eq('id', id).eq('version', expectedVersion).select().maybeSingle()` for all forced writes, and fail with a new conflict if the row changed.

#### HIGH: Local conflict escalation deletes the only queued copy before admin resolution is durable end-to-end
- **Files/lines:** `lib/core/services/sync_queue_service.dart:714-739`, `lib/features/admin/conflicts/admin_conflict_provider.dart:123-134`
- **Failure scenario / attack vector:** `resolveFlagDisputed()` inserts a `conflict_reports` row and immediately deletes the local queue item. From that point forward, the technician device no longer has the operation in its pending/conflict queue. If RLS, admin action, or a later schema issue causes the admin resolution to fail or discard incorrectly, the originating device has no retryable local copy. The admin discard flow only marks the server conflict row as resolved and does not notify or reconcile the technician's local cache.
- **Impact:** Conflict handling becomes server-only and can strand the origin device with stale cached elevator data, while removing the user's local recovery path.
- **Architectural fix:** Keep a local tombstone/reference until the server conflict reaches a terminal state and the device has refreshed the affected entity. Store `conflict_report_id` on the local queue item, show `escalated_pending`, and only delete after confirmed resolution plus cache reconciliation.

#### HIGH: Read caches are stale snapshots with no pending-write overlay or post-sync invalidation
- **Files/lines:** `lib/core/services/read_cache_service.dart:55-77`, `lib/core/services/read_cache_service.dart:84-108`, `lib/core/services/read_cache_service.dart:134-156`, `lib/core/services/read_cache_service.dart:203-220`, `lib/features/elevator/providers/elevator_providers.dart:66-88`, `lib/features/maintenance/providers/maintenance_providers.dart:46-70`, `lib/features/maintenance/providers/maintenance_providers.dart:98-122`, `lib/core/providers/connectivity_providers.dart:107-110`
- **Failure scenario / attack vector:** Offline writes are stored only in `pending_sync`; read providers return cached remote snapshots and do not merge pending queue items. For example, `_enqueueOfflineLog()` sets a synthetic controller state, but `pendingMaintenanceProvider` and `logsByElevatorProvider` still read stale `ReadCacheService` data. After auto-sync succeeds, there is no invalidation of elevators, schedules, faults, or maintenance logs.
- **Impact:** The app can show "saved offline" while dashboards/history omit the record, then continue showing stale cached data after sync. This creates user confusion and can trigger duplicate submissions.
- **Architectural fix:** Add a read model overlay that projects pending queue operations into relevant providers. After sync completion, invalidate/refetch affected providers by operation type and entity ID. Store cache metadata (`fetched_at`, `source`, `dirty_entity_ids`) so stale fallback data is visibly marked and reconciled after writes.

#### HIGH: Riverpod provider lifetimes retain stale action state and unbounded family caches
- **Files/lines:** `lib/features/maintenance/providers/maintenance_providers.dart:98-122`, `lib/features/maintenance/providers/maintenance_providers.dart:129-337`, `lib/features/elevator/providers/elevator_providers.dart:26-34`, `lib/features/elevator/providers/elevator_providers.dart:47-53`, `lib/features/elevator/providers/elevator_providers.dart:93-117`, `lib/features/admin/conflicts/admin_conflict_provider.dart:145-148`
- **Failure scenario / attack vector:** Several screen/entity-scoped providers are not `autoDispose`: `logsByElevatorProvider`, `latestFaultDateProvider`, `nextScheduledMaintenanceProvider`, `elevatorByIdProvider`, `maintenanceControllerProvider`, and `adminConflictProvider`. Families keyed by elevator IDs can accumulate states across navigation, and action notifiers can retain prior `AsyncData`/`AsyncError` after the submitting screen is gone. `adminConflictProvider` also directly uses `Supabase.instance.client` instead of the injectable `supabaseClientProvider`, so auth/client changes can leave a stale notifier using the wrong client.
- **Impact:** Memory grows with visited elevators, stale "last submission" state can reappear on new screens, and conflict admin state can become a zombie state after sign-out/sign-in or provider overrides in tests.
- **Architectural fix:** Convert screen/entity-scoped read providers and action controllers to `autoDispose` unless they are deliberately app-singletons. For expensive family reads, use `autoDispose` with short `keepAlive` only where needed. Inject Supabase through `supabaseClientProvider` everywhere and reset conflict providers on auth/session changes.

### 2. Authentication & Routing

#### CRITICAL: Profile RLS appears to allow users to update their own `role`, enabling self-service admin escalation
- **Files/lines:** `lib/features/admin/models/profile_model.dart:32-44`, `supabase/migrations/20260531000001_remove_duplicate_profile_rls.sql:1-5`, `lib/features/admin/repositories/profile_repository.dart:97-113`, `lib/features/admin/providers/profile_providers.dart:123-132`
- **Failure scenario / attack vector:** The profile model documents an own-profile update policy (`auth.uid() = id`) and the later migration explicitly says the remaining `"Profiles: Users view/update own"` policy already covers own updates. If that policy allows all columns, a technician/customer can bypass the Flutter UI and call Supabase directly: `update profiles set role = 'admin' where id = auth.uid()`. Once `currentProfileProvider` reloads, `routerRoleNotifier` receives `UserRole.admin`, and `app_router.dart:127-130` permits `/admin/*` deep links.
- **Impact:** Full admin-route access and any admin Supabase operations allowed by RLS. This is a true RBAC break because the server-side role source is mutable by the subject being authorized.
- **Architectural fix:** Split profile updates by column and role. Users may update only benign profile fields (`full_name`, `phone`, maybe `fcm_token`) through a narrow policy or RPC; only admins may update `role` and `elevator_id`. Add `WITH CHECK` clauses and/or column-level privileges, revoke generic authenticated update on `profiles`, and move role changes to a `security definer` RPC that checks the caller is an admin before mutation. Add a regression test that a technician cannot update their own `role`.

#### HIGH: Router role loading is not owned by the router, causing `/loading` deadlock and brittle authorization state
- **Files/lines:** `lib/core/router/app_router.dart:112-124`, `lib/features/admin/providers/profile_providers.dart:61-80`, `lib/features/auth/views/loading_view.dart:4-18`, `lib/features/auth/views/login_view.dart:167-171`
- **Failure scenario / attack vector:** `app_router.dart` redirects every authenticated user with `routerRoleNotifier.role == null` to `/loading`. The only code that populates `routerRoleNotifier` is a side effect inside `currentProfileProvider`, but `LoadingView` does not watch that provider. After successful login or a cold-start deep link to `/admin/*`, the app can land on `/loading` with no active provider fetching the profile, so the role never resolves and the router never evaluates the real RBAC rule.
- **Impact:** Authenticated users can be permanently stuck in an unauthorized fallback state. This is not an admin bypass by itself, but it makes authorization dependent on incidental widget/provider reads elsewhere and creates fragile behavior around deep links, notification launches, and session restoration.
- **Architectural fix:** Make the router refresh source a Riverpod-owned auth/role controller instead of a standalone mutable singleton. At minimum, make `LoadingView` watch `currentProfileProvider` and handle error/null profile states explicitly. Prefer a `GoRouterRefreshStream`/`Notifier` fed by `authStateProvider` and `currentProfileProvider`, with deterministic redirects for `loading`, `profileMissing`, `unauthorized`, and `authenticated`.

#### HIGH: Cached global role is not cleared or revalidated on non-null auth events, so demotions/session swaps can retain admin routing
- **Files/lines:** `lib/core/router/app_router.dart:38-47`, `lib/core/router/app_router.dart:83-88`, `lib/core/router/app_router.dart:103-130`, `lib/features/admin/providers/profile_providers.dart:16-46`, `lib/features/admin/providers/profile_providers.dart:75-80`
- **Failure scenario / attack vector:** `_AuthChangeNotifier` clears `routerRoleNotifier` only when `state.session == null`. Token refreshes, profile role demotions, or a non-null session replacement do not clear the cached role. If an admin is downgraded to technician/customer server-side while the app is open, the router can continue treating the user as admin until `currentProfileProvider` is invalidated and successfully refetched. A stale admin role also risks carrying across unusual session replacement flows because the app does not clear role on every signed-in auth event before loading the new profile.
- **Impact:** Client-side admin screens remain reachable after revocation. Server RLS may still block some data, but routing and UI controls continue to expose admin workflows and can call admin repositories/functions until the stale profile state is corrected.
- **Architectural fix:** Clear `routerRoleNotifier` on every auth event before resolving the current profile, not only on sign-out. Subscribe to profile changes for the current user or force periodic/profile-on-focus refetch. Treat server role as the source of truth at action time: admin mutation providers should verify `currentProfileProvider.future` is still admin immediately before executing.

#### HIGH: Customer routing explicitly allows arbitrary `/fault/:id` deep links without customer/elevator ownership checks
- **Files/lines:** `lib/core/router/app_router.dart:132-147`, `lib/features/fault/providers/fault_providers.dart:83-87`, `lib/features/fault/repositories/fault_repository.dart:173-181`, `lib/features/fault/views/fault_detail_view.dart:31-33`, `lib/features/fault/views/fault_detail_view.dart:157-160`, `lib/features/fault/views/fault_detail_view.dart:517-552`
- **Failure scenario / attack vector:** For `UserRole.customer`, the router allows any route whose matched location starts with `/fault/`. `faultByIdProvider` then loads the fault by ID only, with no client-side check that `fault.elevatorId` equals the customer's assigned `profile.elevatorId`. The fault detail screen also exposes resolve/reopen behavior through the long-press flow. If a fault ID is leaked through a notification, logs, browser history, or predictable sharing, a customer can deep-link to another elevator's fault detail and attempt state-changing actions.
- **Impact:** Potential IDOR/data exposure for fault descriptions, photos, resolution notes, timestamps, and linked elevator metadata. If Supabase RLS for `fault_reports` update/select is broader than customer-owned elevator rows, this becomes an actual cross-customer data and workflow breach.
- **Architectural fix:** Remove the blanket customer exception for `/fault/*`. Add a customer-scoped route/provider that loads the current profile first and only permits faults for `profile.elevatorId`. In `FaultDetailView`, gate resolve/reopen controls to technicians/admins only. Enforce the same rule in Supabase RLS: customers may select only faults for their assigned elevator and may not update fault status.

#### HIGH: Admin/customer providers bypass injectable auth state and read `Supabase.instance.client` directly
- **Files/lines:** `lib/core/providers/connectivity_providers.dart:34-46`, `lib/features/admin/conflicts/admin_conflict_provider.dart:50-58`, `lib/features/customer/providers/customer_portal_provider.dart:19-23`, `lib/features/customer/providers/customer_portal_provider.dart:39-44`, `lib/features/admin/providers/checklist_provider.dart:22-77`
- **Failure scenario / attack vector:** The codebase documents that providers should inject Supabase through `supabaseClientProvider`, but several security-sensitive providers call `Supabase.instance.client` directly. This makes auth/session transitions harder to reason about, bypasses provider overrides in tests, and can leave providers using global client state instead of a scoped, invalidated dependency after sign-out/sign-in.
- **Impact:** Stale session reads, test blind spots around RBAC, and inconsistent unauthorized fallbacks. In practice this can mask routes/actions that should fail for technicians/customers until they are discovered in production.
- **Architectural fix:** Replace all direct `Supabase.instance.client` calls inside providers/notifiers with `ref.watch/read(supabaseClientProvider)`. Invalidate admin/customer providers on `authStateProvider` changes. Add provider tests that override Supabase clients for technician/customer sessions and assert admin data providers do not execute or return data.

#### HIGH: Session persistence and token refresh are treated as implicit success, with no explicit unauthorized fallback
- **Files/lines:** `lib/features/auth/providers/auth_providers.dart:19-25`, `lib/features/auth/providers/auth_providers.dart:33-38`, `lib/core/router/app_router.dart:103-124`, `lib/features/auth/repositories/auth_repository.dart:70-74`, `lib/main.dart:65-68`
- **Failure scenario / attack vector:** Initial auth state is derived from `currentUser`, and the router treats any non-null `currentUser` as authenticated before proving that a valid profile can be fetched. If the persisted Supabase session is expired, revoked, missing a profile, or failing refresh/profile fetch, the app falls into `/loading` or stale provider error paths rather than a deterministic sign-out/unauthorized route. There is no explicit timeout or recovery path for role fetch failure.
- **Impact:** Users can get stuck after token/session problems, and stale authenticated state can remain visible in the app shell. This also weakens auditability because unauthorized state is represented as an indefinite loading spinner instead of a clear security transition.
- **Architectural fix:** Add an auth bootstrap state machine: `unauthenticated`, `sessionRefreshing`, `profileLoading`, `authorized(role)`, `profileMissing`, `unauthorized/error`. On refresh/profile failure, clear local role state and route to login or an explicit unauthorized screen. Configure and test Supabase auth persistence/auto-refresh behavior intentionally, and add integration tests for expired session, deleted profile, and role-revoked session restore.

### 3. Backend Security & Supabase

#### CRITICAL: `send-notification` accepts unauthenticated forged webhook payloads while using the service-role key
- **Files/lines:** `supabase/functions/send-notification/index.ts:22-30`, `supabase/functions/send-notification/index.ts:50-53`, `supabase/functions/send-notification/index.ts:60-81`, `supabase/migrations/20260516205500_create_fault_webhook.sql:21-32`, `supabase/migrations/20260531000002_database_webhook_setup.sql:14-20`, `supabase/migrations/20260531000002_database_webhook_setup.sql:60-83`
- **Failure scenario / attack vector:** The Edge Function is documented for `--no-verify-jwt`, creates a Supabase client with `SUPABASE_SERVICE_ROLE_KEY`, and treats any JSON body with `{ "type": "INSERT", "table": "fault_reports", "record": ... }` as a trusted database webhook. The direct app-call branch validates a JWT, but the webhook branch does not validate any signature, shared secret, service token, timestamp, or source. Anyone who knows the public function URL can POST a fake fault webhook and trigger admin notification broadcasts with attacker-controlled `description` and `/fault/{id}` route data.
- **Impact:** Unauthenticated push-notification spam/phishing to every admin, service-role-backed profile enumeration side effects, alert fatigue, and malicious deep-link delivery. Because the function uses service-role credentials internally, all authorization must be explicit in the function.
- **Required TypeScript fix:** Require a webhook secret for webhook payloads and validate direct calls against allowed senders/recipients. Deploy with the secret set via `supabase secrets set WEBHOOK_SECRET=...`.

```ts
// supabase/functions/send-notification/index.ts
const CORS_HEADERS = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers":
    "authorization, x-client-info, apikey, content-type, x-webhook-secret",
};

function json(status: number, body: unknown) {
  return new Response(JSON.stringify(body), {
    status,
    headers: { ...CORS_HEADERS, "Content-Type": "application/json" },
  });
}

function assertWebhookSecret(req: Request) {
  const expected = Deno.env.get("WEBHOOK_SECRET");
  const received = req.headers.get("x-webhook-secret");
  if (!expected || received !== expected) {
    throw new Response(JSON.stringify({ error: "Unauthorized webhook" }), {
      status: 401,
      headers: { ...CORS_HEADERS, "Content-Type": "application/json" },
    });
  }
}

// Inside serve(), before accepting webhook payloads:
if (reqBody.type === "INSERT" && reqBody.table === "fault_reports" && reqBody.record) {
  assertWebhookSecret(req);
  const record = reqBody.record;
  if (!record.id || !record.elevator_id) return json(400, { error: "Invalid fault webhook record" });
  // Continue with admin notification lookup.
}
```

- **Required SQL fix:** Send the same secret from database triggers and stop relying on anon keys for internal webhooks.

```sql
-- Store this outside source control:
-- alter database postgres set app.settings.webhook_secret = '<random-32-byte-secret>';

CREATE OR REPLACE FUNCTION public.notify_fault_report()
RETURNS trigger
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, net
AS $$
DECLARE
  v_url text := 'https://fuwmrhahwvsouhcxycyr.supabase.co/functions/v1/send-notification';
  v_secret text := current_setting('app.settings.webhook_secret', true);
  v_payload jsonb;
BEGIN
  IF v_secret IS NULL OR length(v_secret) < 32 THEN
    RAISE EXCEPTION 'Missing app.settings.webhook_secret';
  END IF;

  v_payload := jsonb_build_object(
    'type', 'INSERT',
    'table', TG_TABLE_NAME,
    'schema', TG_TABLE_SCHEMA,
    'record', to_jsonb(NEW),
    'old_record', null
  );

  PERFORM net.http_post(
    url := v_url,
    headers := jsonb_build_object(
      'Content-Type', 'application/json',
      'x-webhook-secret', v_secret
    ),
    body := v_payload
  );

  RETURN NEW;
END;
$$;
```

#### CRITICAL: `fault_reports` RLS allows any authenticated user to create faults for any elevator
- **Files/lines:** `supabase/migrations/20260528000003_fix_fault_reports_rls.sql:1-15`
- **Failure scenario / attack vector:** The migration drops anonymous insert but recreates `Faults: Authenticated users can report` with `WITH CHECK (true)`. A customer from building A, or any technician/customer account, can insert a fault for building B by guessing or obtaining another `elevator_id`. That insert also triggers the notification webhook, creating a cross-tenant alert and potential data pollution.
- **Impact:** Cross-tenant write access, fake fault reports against other buildings, notification flooding, and polluted maintenance/fault analytics.
- **Required SQL fix:** Replace broad authenticated insert with role/elevator-scoped insert and select/update policies. Adjust the technician scope if technicians are intentionally global; customers must be limited to their assigned elevator.

```sql
DROP POLICY IF EXISTS "Faults: Authenticated users can report" ON public.fault_reports;
DROP POLICY IF EXISTS "Authenticated users can insert fault reports" ON public.fault_reports;

CREATE POLICY "Faults: admins full access"
ON public.fault_reports
FOR ALL
TO authenticated
USING (
  EXISTS (
    SELECT 1 FROM public.profiles p
    WHERE p.id = auth.uid() AND p.role = 'admin'
  )
)
WITH CHECK (
  EXISTS (
    SELECT 1 FROM public.profiles p
    WHERE p.id = auth.uid() AND p.role = 'admin'
  )
);

CREATE POLICY "Faults: technicians can insert and read"
ON public.fault_reports
FOR INSERT
TO authenticated
WITH CHECK (
  EXISTS (
    SELECT 1 FROM public.profiles p
    WHERE p.id = auth.uid() AND p.role = 'technician'
  )
);

CREATE POLICY "Faults: customers insert own elevator"
ON public.fault_reports
FOR INSERT
TO authenticated
WITH CHECK (
  EXISTS (
    SELECT 1 FROM public.profiles p
    WHERE p.id = auth.uid()
      AND p.role = 'customer'
      AND p.elevator_id = fault_reports.elevator_id
  )
);

CREATE POLICY "Faults: customers read own elevator"
ON public.fault_reports
FOR SELECT
TO authenticated
USING (
  EXISTS (
    SELECT 1 FROM public.profiles p
    WHERE p.id = auth.uid()
      AND p.role = 'customer'
      AND p.elevator_id = fault_reports.elevator_id
  )
  OR EXISTS (
    SELECT 1 FROM public.profiles p
    WHERE p.id = auth.uid()
      AND p.role IN ('admin', 'technician')
  )
);

CREATE POLICY "Faults: technicians/admins update"
ON public.fault_reports
FOR UPDATE
TO authenticated
USING (
  EXISTS (
    SELECT 1 FROM public.profiles p
    WHERE p.id = auth.uid()
      AND p.role IN ('admin', 'technician')
  )
)
WITH CHECK (
  EXISTS (
    SELECT 1 FROM public.profiles p
    WHERE p.id = auth.uid()
      AND p.role IN ('admin', 'technician')
  )
);
```

#### CRITICAL: Maintenance report storage is public and any authenticated user can upload/update any report object
- **Files/lines:** `supabase/migrations/20260516000000_create_maintenance_reports_bucket.sql:1-25`
- **Failure scenario / attack vector:** The `maintenance-reports` bucket is created with `public = true`, public SELECT is granted for every object in the bucket, and authenticated users can update any object where `bucket_id = 'maintenance-reports'`. Report URLs generated by the app are public bearerless URLs; any leaked URL exposes maintenance reports, signatures, customer details, and building information. Any authenticated user can overwrite another report object if they know the path.
- **Impact:** Cross-tenant PII leakage, report tampering, signature exposure, and audit evidence corruption.
- **Required SQL fix:** Make the bucket private, drop public read/update-all policies, and scope object access to admins, technicians, or customers linked to the report/elevator. If storage paths are `reports/{elevator_id}/{log_id}.pdf`, enforce ownership via path parsing.

```sql
UPDATE storage.buckets
SET public = false
WHERE id = 'maintenance-reports';

DROP POLICY IF EXISTS "Allow public to read maintenance reports" ON storage.objects;
DROP POLICY IF EXISTS "Allow authenticated to update maintenance reports" ON storage.objects;
DROP POLICY IF EXISTS "Allow authenticated users to upload maintenance reports" ON storage.objects;

CREATE POLICY "Reports: technicians/admins upload"
ON storage.objects
FOR INSERT
TO authenticated
WITH CHECK (
  bucket_id = 'maintenance-reports'
  AND (storage.foldername(name))[1] = 'reports'
  AND EXISTS (
    SELECT 1 FROM public.profiles p
    WHERE p.id = auth.uid()
      AND p.role IN ('admin', 'technician')
  )
);

CREATE POLICY "Reports: scoped read"
ON storage.objects
FOR SELECT
TO authenticated
USING (
  bucket_id = 'maintenance-reports'
  AND (
    EXISTS (
      SELECT 1 FROM public.profiles p
      WHERE p.id = auth.uid()
        AND p.role IN ('admin', 'technician')
    )
    OR EXISTS (
      SELECT 1
      FROM public.profiles p
      WHERE p.id = auth.uid()
        AND p.role = 'customer'
        AND p.elevator_id::text = (storage.foldername(name))[2]
    )
  )
);

CREATE POLICY "Reports: owner roles update"
ON storage.objects
FOR UPDATE
TO authenticated
USING (
  bucket_id = 'maintenance-reports'
  AND EXISTS (
    SELECT 1 FROM public.profiles p
    WHERE p.id = auth.uid()
      AND p.role IN ('admin', 'technician')
  )
)
WITH CHECK (
  bucket_id = 'maintenance-reports'
  AND EXISTS (
    SELECT 1 FROM public.profiles p
    WHERE p.id = auth.uid()
      AND p.role IN ('admin', 'technician')
  )
);
```

#### HIGH: Direct notification API lets any authenticated user send arbitrary notifications to any user
- **Files/lines:** `supabase/functions/send-notification/index.ts:82-127`, `supabase/functions/send-notification/index.ts:167-199`
- **Failure scenario / attack vector:** The direct-call branch only verifies that the caller has any valid Supabase JWT. It does not check caller role, relationship to `to_user_id`, allowed notification type, or route safety. A technician/customer can call the function with another user's UUID, arbitrary title/body, and route data such as `/admin/users` or `/fault/{id}`.
- **Impact:** Cross-tenant phishing/spam through trusted app push notifications and unauthorized disclosure that a target user has an FCM token.
- **Required TypeScript fix:** Restrict direct notification sends to admins or to specific server-approved workflows. For client-triggered maintenance notifications, validate that the caller is the technician on the related maintenance record and that the target customer owns the same elevator.

```ts
// After supabase.auth.getUser(callerToken):
const { data: callerProfile, error: callerProfileError } = await supabase
  .from("profiles")
  .select("role")
  .eq("id", user.id)
  .maybeSingle();

if (callerProfileError || !callerProfile) return json(403, { error: "Profile not found" });

const allowedDirectTypes = new Set(["maintenance_completed"]);
const notificationType = String(reqBody.data?.type ?? "");

if (callerProfile.role !== "admin" && !allowedDirectTypes.has(notificationType)) {
  return json(403, { error: "Forbidden notification type" });
}

if (callerProfile.role !== "admin" && notificationType === "maintenance_completed") {
  const elevatorId = String(reqBody.data?.elevator_id ?? "");
  const { data: targetProfile } = await supabase
    .from("profiles")
    .select("id, role, elevator_id")
    .eq("id", reqBody.to_user_id)
    .maybeSingle();

  if (!targetProfile || targetProfile.role !== "customer" || targetProfile.elevator_id !== elevatorId) {
    return json(403, { error: "Target is not the customer for this elevator" });
  }
}

const allowedRoutes = new Set(["/", "/customer/dashboard"]);
if (reqBody.data?.route && !allowedRoutes.has(String(reqBody.data.route))) {
  return json(400, { error: "Disallowed notification route" });
}
```

#### HIGH: Database webhook migration hardcodes a live anon key and encourages `--no-verify-jwt`
- **Files/lines:** `supabase/migrations/20260531000002_database_webhook_setup.sql:14-20`, `supabase/migrations/20260531000002_database_webhook_setup.sql:60-64`, `supabase/migrations/20260531000002_database_webhook_setup.sql:77-83`
- **Failure scenario / attack vector:** The migration contains a concrete JWT-looking anon key in source control and comments instruct deploying the function with `--no-verify-jwt`. The anon key is not secret, but hardcoding project credentials into migrations normalizes credential sprawl and makes future secret misuse more likely. More importantly, the header does not authenticate internal webhook origin if JWT verification is disabled.
- **Impact:** Weak webhook security posture and increased risk of accidentally committing actual service credentials later. It also creates false confidence that `Authorization: Bearer <anon>` protects the function.
- **Required SQL fix:** Remove the embedded key, store only a webhook secret in database settings/secrets, and pass `x-webhook-secret` as shown in the critical webhook fix. If JWT verification is re-enabled, use a short-lived service-generated token rather than a static anon key.

```sql
-- Remove this pattern:
-- _anon_key := COALESCE(current_setting('app.settings.anon_key', true), '<hardcoded jwt>');
-- 'Authorization', 'Bearer ' || _anon_key

-- Replace with:
_webhook_secret := current_setting('app.settings.webhook_secret', true);
headers := jsonb_build_object(
  'Content-Type', 'application/json',
  'x-webhook-secret', _webhook_secret
);
```

#### HIGH: `notify_fault_report()` is `SECURITY DEFINER` without `SET search_path`, making it vulnerable to search-path hijacking
- **Files/lines:** `supabase/migrations/20260516205500_create_fault_webhook.sql:5-37`
- **Failure scenario / attack vector:** The older fault webhook trigger function is `SECURITY DEFINER` but does not pin `search_path`. In PostgreSQL, definer functions that reference unqualified objects can be abused if an attacker can influence the search path or create shadow objects in schemas earlier in resolution order. The newer schedule webhook correctly uses `SET search_path = public`; the fault webhook does not.
- **Impact:** Privilege-escalation risk inside a definer function and inconsistent hardening across webhook triggers.
- **Required SQL fix:** Recreate the function with a pinned search path and schema-qualify extension calls.

```sql
CREATE OR REPLACE FUNCTION public.notify_fault_report()
RETURNS trigger
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, net
AS $$
BEGIN
  -- Existing body, but call net.http_post explicitly.
  RETURN NEW;
END;
$$;

REVOKE ALL ON FUNCTION public.notify_fault_report() FROM PUBLIC;
```

#### HIGH: Elevator RLS fix is incomplete because it only drops one broad policy and does not assert final tenant-scoped policies
- **Files/lines:** `supabase/migrations/20260528000002_fix_elevators_rls.sql:1-12`
- **Failure scenario / attack vector:** The migration removes `"Elevators are viewable by authenticated users"` but does not create or verify the replacement policies. It relies on pre-existing policies named in comments. In a new environment, partially migrated database, or policy drift scenario, customers may either see no elevators or retain overly broad access through another permissive policy.
- **Impact:** Cross-tenant elevator data exposure or production drift where security depends on migration history instead of declarative final state.
- **Required SQL fix:** Make the migration idempotently define the final desired RLS policies and helper functions.

```sql
ALTER TABLE public.elevators ENABLE ROW LEVEL SECURITY;

CREATE OR REPLACE FUNCTION public.current_user_role()
RETURNS text
LANGUAGE sql
STABLE
SECURITY DEFINER
SET search_path = public
AS $$
  SELECT role FROM public.profiles WHERE id = auth.uid()
$$;

DROP POLICY IF EXISTS "Elevators: Admins full access" ON public.elevators;
DROP POLICY IF EXISTS "Elevators: Technicians can view all" ON public.elevators;
DROP POLICY IF EXISTS "Elevators: Customers view own" ON public.elevators;
DROP POLICY IF EXISTS "Elevators are viewable by authenticated users" ON public.elevators;

CREATE POLICY "Elevators: Admins full access"
ON public.elevators
FOR ALL
TO authenticated
USING (public.current_user_role() = 'admin')
WITH CHECK (public.current_user_role() = 'admin');

CREATE POLICY "Elevators: Technicians can view all"
ON public.elevators
FOR SELECT
TO authenticated
USING (public.current_user_role() = 'technician');

CREATE POLICY "Elevators: Customers view own"
ON public.elevators
FOR SELECT
TO authenticated
USING (
  EXISTS (
    SELECT 1 FROM public.profiles p
    WHERE p.id = auth.uid()
      AND p.role = 'customer'
      AND p.elevator_id = elevators.id
  )
);
```

### 4. Error Handling & Edge Cases

#### HIGH: Offline mutation paths can leave UI permanently stuck in loading
- **Files/lines:** `lib/features/maintenance/providers/maintenance_providers.dart:166-199`, `lib/features/maintenance/providers/maintenance_providers.dart:230-245`, `lib/features/maintenance/providers/maintenance_providers.dart:279-290`, `lib/features/fault/providers/fault_providers.dart:101-130`, `lib/features/elevator/widgets/detail/log_maintenance_sheet.dart:109-120`, `lib/features/elevator/widgets/detail/report_fault_sheet.dart:87-98`
- **Failure scenario / attack vector:** Both maintenance and fault submission set `state = const AsyncLoading()` before the offline queue path. The offline maintenance path copies media files and writes Hive queue entries outside `AsyncValue.guard`; the offline fault path writes the Hive queue outside `AsyncValue.guard`. If file copy, document-directory lookup, JSON encoding, Hive write, or queue-capacity enforcement throws, the notifier method exits with an uncaught Future error and never sets `AsyncError` or `AsyncData`. The sheets disable their submit buttons and block pop while `isLoading` is true, so users can be trapped in a modal with no retry or dismiss path.
- **Impact:** Permanent local UI lock during exactly the degraded/offline path the app depends on most. Users may force-close the app, losing form context and potentially duplicating submissions after restart.
- **Architectural fix:** Wrap the entire mutation, including offline enqueue and media stabilization, in `AsyncValue.guard` or a single `try/catch/finally` that always exits loading. Treat offline enqueue failure as a first-class `SyncPersistenceException` with a user-visible recovery message. Add a modal escape hatch after timeout and a test that injects a failing queue/cache service and asserts the sheet shows an error instead of staying loading.

#### HIGH: Best-effort side effects are silently swallowed, hiding backend divergence
- **Files/lines:** `lib/features/admin/repositories/schedule_repository.dart:376-412`, `lib/core/services/sync_queue_service.dart:522-564`, `lib/core/services/notification_service.dart:205-258`, `lib/core/services/sync_queue_service.dart:456-486`
- **Failure scenario / attack vector:** Schedule completion and notifications are intentionally swallowed with `catch (_) {}` or debug-only logs. A maintenance log can be saved successfully while the matching schedule remains pending, admin/customer notifications fail, or customer notification routes are malformed. The UI reports success and there is no durable retry, metric, dead-letter queue, or visible "side effect failed" state.
- **Impact:** Local and remote workflows diverge: technicians believe a task is complete, admins still see pending schedules, and customers may never receive maintenance completion notifications. Operational failures become invisible until someone manually notices inconsistent data.
- **Architectural fix:** Separate primary write success from side-effect status. Persist side effects as retryable jobs (`schedule_completion`, `admin_notification`, `customer_notification`) with status, attempt count, and last error. Surface non-blocking warnings in UI when side effects fail, and expose an admin health view for dead-lettered jobs. Keep "best effort" only for truly optional telemetry, not workflow state transitions.

#### HIGH: Cache corruption and decode errors are converted into valid empty data
- **Files/lines:** `lib/core/services/read_cache_service.dart:63-73`, `lib/core/services/read_cache_service.dart:92-103`, `lib/core/services/read_cache_service.dart:119-129`, `lib/core/services/read_cache_service.dart:145-156`, `lib/core/services/read_cache_service.dart:168-178`, `lib/core/services/read_cache_service.dart:188-198`, `lib/core/services/read_cache_service.dart:210-220`, `lib/features/elevator/providers/elevator_providers.dart:82-86`, `lib/features/maintenance/providers/maintenance_providers.dart:64-68`, `lib/features/fault/providers/fault_providers.dart:34-37`
- **Failure scenario / attack vector:** Every cache loader catches decode/model errors and returns `[]` or `0`. Online providers then fall back to cached data only when it is non-empty; corrupted cache is indistinguishable from "no data." During a network outage, a corrupted cache makes dashboards appear empty or throws the original network error, while the root cause is never reported.
- **Impact:** Data appears to vanish, offline mode becomes unreliable, and support/debugging loses the only evidence of local corruption. A malformed cached row can also mask a backend failure by returning a valid-looking empty screen.
- **Architectural fix:** Return a typed cache result (`CacheHit<T>`, `CacheMiss`, `CacheCorrupt(error, key)`) instead of raw lists. Log and surface corruption separately, keep the bad raw payload until diagnostics/export, and provide cache repair/invalidation flows. Add checksum/schema-version metadata to cached snapshots and provider tests for corrupted JSON.

#### HIGH: Exception mapping loses important Supabase/PostgREST failure classes
- **Files/lines:** `lib/core/exceptions/app_exception.dart:83-118`, `lib/core/exceptions/app_exception.dart:120-145`, repository catch patterns such as `lib/features/fault/repositories/fault_repository.dart:47-52`, `lib/features/admin/repositories/schedule_repository.dart:93-99`, `lib/features/elevator/repositories/elevator_repository.dart:39-44`
- **Failure scenario / attack vector:** `mapPostgrestException()` checks `e.code` for string values like `'401'` and `'403'`, but Supabase/PostgREST often uses semantic codes (`PGRST...`, SQLSTATE values) and may put HTTP status in another field. Validation failures, RLS failures, duplicate-key errors, expired JWTs, and missing rows can collapse into generic `ServerException`. UI code then shows a generic error instead of signing out, denying access, retrying, or preventing duplicate writes.
- **Impact:** Incorrect recovery behavior and poor security UX: expired sessions are not reliably routed to login, permission errors look like server outages, and duplicate/constraint violations are not handled deterministically.
- **Architectural fix:** Expand `AppException` into domain-specific failures (`ValidationException`, `ConflictWriteException`, `DuplicateException`, `SessionExpiredException`, `CacheException`, `SyncPersistenceException`). Map from `PostgrestException.code`, `message`, `details`, and status when available, and add repository tests with real Supabase error fixtures. Avoid throwing raw `Exception` in services; always map to typed exceptions before crossing provider boundaries.

#### HIGH: Unawaited cache writes and token refresh updates can fail without observation
- **Files/lines:** `lib/features/elevator/providers/elevator_providers.dart:79-80`, `lib/features/maintenance/providers/maintenance_providers.dart:61-62`, `lib/features/maintenance/providers/maintenance_providers.dart:86-87`, `lib/features/fault/providers/fault_providers.dart:31-32`, `lib/features/fault/providers/fault_providers.dart:60-61`, `lib/features/admin/providers/admin_providers.dart:83-85`, `lib/core/services/notification_service.dart:173-180`, `lib/core/services/notification_service.dart:186-200`
- **Failure scenario / attack vector:** Cache saves are fired with `unawaited(...)`, and realtime schedule cache saves are called without awaiting or catching. FCM token refresh uses `unawaited(_updateToken(...))`; `_updateToken` catches and logs only. If Hive write fails, token update fails, or serialization throws, the app continues as if persistence succeeded. Offline fallback later serves stale data or missing push tokens.
- **Impact:** The app's offline-read and notification layers silently decay. Users may stop receiving notifications, and offline screens can revert to stale snapshots without any visible failure.
- **Architectural fix:** Use a small background task runner that captures unawaited job results, logs structured errors, and exposes health/retry state. For cache writes, either await when consistency matters or wrap `unawaited(future.catchError(...))` with a telemetry/error sink. For FCM token updates, persist a local `token_sync_pending` flag and retry after sign-in/connectivity changes.

#### HIGH: Realtime schedule stream hides stream errors and can become a stale zombie stream
- **Files/lines:** `lib/features/admin/providers/admin_providers.dart:60-105`, `lib/features/admin/repositories/schedule_repository.dart:263-280`
- **Failure scenario / attack vector:** `technicianScheduleStreamProvider` proxies Supabase Realtime through a `StreamController`. On stream error, it emits cached tasks and keeps the controller open. There is no error state, no reconnect/backoff signal, no stale marker, and no timeout to indicate that realtime has stopped updating. If the underlying subscription remains broken, the home agenda can continue showing stale data indefinitely.
- **Impact:** Technicians may miss newly assigned tasks or status changes while the UI appears healthy. This is especially risky for operational dispatch workflows.
- **Architectural fix:** Emit a typed stream state (`live`, `staleFromCache`, `reconnecting`, `error`) instead of only `List<ScheduleModel>`. On errors, close and recreate the Supabase subscription with backoff, mark cached emissions as stale, and show a banner/action when realtime is degraded. Add integration tests that force stream errors and verify stale state is visible.

#### HIGH: Sync queue failures are reduced to counters, losing root cause and retry policy
- **Files/lines:** `lib/core/services/sync_queue_service.dart:189-235`, `lib/core/services/sync_queue_service.dart:221-229`, `lib/core/services/sync_queue_service.dart:487-490`, `lib/features/elevator/widgets/home/home_top_app_bar.dart:283-301`
- **Failure scenario / attack vector:** `flush()` catches all unexpected exceptions, prints debug output, increments `failed`, and keeps the item queued. The returned `SyncResult` has only `synced` and `failed`, so UI cannot distinguish transient timeout, missing media file, RLS permission denial, deleted remote row, malformed payload, or PDF generation failure. The PDF path also replaces the original error with a generic `Exception('PDF generation/upload failed')`.
- **Impact:** Permanent failures retry forever with no actionable status, while users see only "N failed." Debug logs are not available in production, so support cannot identify whether the user should reconnect, re-authenticate, reattach media, or escalate a conflict.
- **Architectural fix:** Persist per-item failure metadata (`last_error_type`, `last_error_message`, `attempt_count`, `next_retry_at`, `terminal_failure`). Split retryable network failures from terminal validation/auth/media failures. Return a richer `SyncResult` with item-level outcomes and expose a queue detail UI. Preserve original exception type/stack where safe, and add dead-letter handling for terminal errors.

#### HIGH: Notification initialization can partially fail and then never retry
- **Files/lines:** `lib/core/services/notification_service.dart:68-81`, `lib/core/services/notification_service.dart:88-129`, `lib/main.dart:100-101`
- **Failure scenario / attack vector:** `NotificationService.initialize()` sets `_initialised = true` before awaiting permission requests, local notification initialization, channel creation, and Firebase listeners. If any awaited step throws, `main()` can fail startup or a later retry will no-op because `_initialised` is already true, leaving listeners/channels partially unregistered.
- **Impact:** Push and local notification behavior becomes nondeterministic after one transient initialization failure. The app may lose foreground/background notification handling until process restart, with no health signal.
- **Architectural fix:** Track initialization as a state machine (`notStarted`, `initializing`, `ready`, `failed(error)`) and set ready only after all required setup completes. Catch setup failures at app bootstrap, allow retry, and register listeners idempotently after successful prerequisites. Surface notification setup failure as non-blocking app health state.
