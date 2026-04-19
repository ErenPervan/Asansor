import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart' as supabase_flutter;

import '../../../core/providers/connectivity_providers.dart';
import '../../../core/widgets/offline_banner.dart';
import '../../auth/providers/auth_providers.dart';
import '../../elevator/models/elevator_model.dart';
import '../../elevator/providers/elevator_providers.dart';
import '../../fault/models/fault_report_model.dart';
import '../../fault/providers/fault_providers.dart';
import '../../admin/models/schedule_model.dart';
import '../../admin/providers/admin_providers.dart';
import '../../admin/providers/profile_providers.dart';
import '../../maintenance/providers/maintenance_providers.dart';

// ── Design tokens ─────────────────────────────────────────────────────────────

const _primary = Color(0xFFB91C1C);
const _primaryContainer = Color(0xFF991B1B);
const _error = Color(0xFFDC2626);
const _errorContainer = Color(0xFFFEE2E2);
const _onErrorContainer = Color(0xFF991B1B);
const _surfaceContainerLowest = Colors.white;
const _surfaceContainer = Color(0xFFF1F5F9);
const _surfaceContainerHighest = Color(0xFFE2E8F0);
const _onSurface = Color(0xFF0F172A);
const _onSurfaceVariant = Color(0xFF475569);
const _outline = Color(0xFF94A3B8);
const _outlineVariant = Color(0xFFE2E8F0);
const _background = Color(0xFFF9FAFB);

// ── Helpers ──────────────────────────────────────────────────────────────────

String _timeAgo(DateTime dt) {
  final diff = DateTime.now().difference(dt);
  if (diff.inMinutes < 60) return '${diff.inMinutes} dk önce';
  if (diff.inHours < 24) return '${diff.inHours} sa önce';
  return '${diff.inDays} gün önce';
}

ElevatorModel? _findElevator(String id, List<ElevatorModel>? list) {
  if (list == null) return null;
  try {
    return list.firstWhere((e) => e.id == id);
  } catch (_) {
    return null;
  }
}

// ── HomeView ─────────────────────────────────────────────────────────────────

class HomeView extends ConsumerWidget {
  const HomeView({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final authState = ref.watch(authControllerProvider);
    final activeFaults = ref.watch(activeFaultsProvider);
    final mySchedules = ref.watch(technicianScheduleStreamProvider);
    final elevators = ref.watch(elevatorsProvider);
    final completedCount = ref.watch(completedTodayCountProvider);

    final pendingCount = ref.watch(pendingSyncCountProvider);
    final isOnline = ref.watch(isOnlineProvider);
    final userEmail = authState.valueOrNull?.email ?? '';

    return Scaffold(
      backgroundColor: _background,
      body: SafeArea(
        child: Column(
          children: [
            _TopAppBar(
              userEmail: userEmail,
              pendingSyncCount: pendingCount,
              isOnline: isOnline,
              onSignOut: () =>
                  ref.read(authControllerProvider.notifier).signOut(),
            ),
            // Shown only when the device is offline; renders nothing otherwise.
            const OfflineBanner(),
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.symmetric(horizontal: 24),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const SizedBox(height: 16),
                    _ActiveFaultsSection(
                      activeFaults: activeFaults,
                      elevators: elevators.valueOrNull,
                    ),
                    const SizedBox(height: 32),
                    _DailyAgendaSection(
                      mySchedules: mySchedules,
                      elevators: elevators.valueOrNull,
                    ),
                    const SizedBox(height: 32),
                    _StatsSection(
                      activeFaultCount: activeFaults.valueOrNull?.length ?? 0,
                      completedCount: completedCount.valueOrNull ?? 0,
                    ),
                    const SizedBox(height: 24),
                    _ElevatorsShortcutCard(
                      onTap: () => context.push('/elevators'),
                    ),
                    // Bottom padding so content clears the FAB + nav bar.
                    const SizedBox(height: 120),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
      floatingActionButton: _QrFab(onPressed: () => context.push('/scan')),
      floatingActionButtonLocation: FloatingActionButtonLocation.centerDocked,
      bottomNavigationBar: const _BottomNavBar(),
    );
  }
}

// ── Top App Bar ───────────────────────────────────────────────────────────────

class _TopAppBar extends StatelessWidget {
  const _TopAppBar({
    required this.userEmail,
    required this.pendingSyncCount,
    required this.isOnline,
    required this.onSignOut,
  });

  final String userEmail;
  final int pendingSyncCount;
  final bool isOnline;
  final VoidCallback onSignOut;

  @override
  Widget build(BuildContext context) {
    final displayName = userEmail.isNotEmpty
        ? userEmail.split('@').first
        : 'Teknisyen';

    return Container(
      color: _background,
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
      child: Row(
        children: [
          // Avatar circle
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: _surfaceContainer,
              shape: BoxShape.circle,
              border: Border.all(
                color: _primary.withValues(alpha: 0.12),
                width: 2,
              ),
            ),
            child: const Icon(Icons.person_outline, color: _primary, size: 20),
          ),
          const SizedBox(width: 12),
          // Status + greeting
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text(
                  'DURUM: AKTİF',
                  style: TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.w600,
                    color: _outline,
                    letterSpacing: 1.1,
                  ),
                ),
                Text(
                  'Merhaba, $displayName',
                  style: const TextStyle(
                    fontSize: 17,
                    fontWeight: FontWeight.w600,
                    color: _primary,
                    letterSpacing: -0.3,
                  ),
                ),
              ],
            ),
          ),
          // Admin panel shortcut (for testing)
          Material(
            color: _surfaceContainerLowest,
            shape: const CircleBorder(),
            elevation: 1,
            shadowColor: Colors.black12,
            child: InkWell(
              customBorder: const CircleBorder(),
              onTap: () => context.push('/admin/dashboard'),
              child: const Padding(
                padding: EdgeInsets.all(10),
                child: Icon(
                  Icons.admin_panel_settings_outlined,
                  color: _primary,
                  size: 20,
                ),
              ),
            ),
          ),
          const SizedBox(width: 8),
          // Cloud sync status indicator
          _SyncStatusButton(
            pendingCount: pendingSyncCount,
            isOnline: isOnline,
          ),
          const SizedBox(width: 8),
          // Sign-out button
          Material(
            color: _surfaceContainerLowest,
            shape: const CircleBorder(),
            elevation: 1,
            shadowColor: Colors.black12,
            child: InkWell(
              customBorder: const CircleBorder(),
              onTap: onSignOut,
              child: const Padding(
                padding: EdgeInsets.all(10),
                child: Icon(Icons.logout_outlined, color: _primary, size: 20),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ── Sync status button ────────────────────────────────────────────────────────

/// Small button shown in the top bar to indicate cloud sync state.
///
/// - Green cloud-done icon  → all data is synced.
/// - Amber cloud-upload icon with a count badge → items are queued offline.
/// - No network icon (red)  → device is currently offline.
class _SyncStatusButton extends ConsumerWidget {
  const _SyncStatusButton({
    required this.pendingCount,
    required this.isOnline,
  });

  final int pendingCount;
  final bool isOnline;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final hasPending = pendingCount > 0;

    final IconData icon;
    final Color color;
    final String tooltip;

    if (!isOnline) {
      icon = Icons.cloud_off_outlined;
      color = _primary;
      tooltip = 'Çevrimdışı';
    } else if (hasPending) {
      icon = Icons.cloud_upload_outlined;
      color = const Color(0xFFD97706); // amber-600
      tooltip = '$pendingCount öğe senkronize bekleniyor';
    } else {
      icon = Icons.cloud_done_outlined;
      color = const Color(0xFF16A34A); // green-600
      tooltip = 'Tüm veriler senkronize';
    }

    return Tooltip(
      message: tooltip,
      child: Material(
        color: _surfaceContainerLowest,
        shape: const CircleBorder(),
        elevation: 1,
        shadowColor: Colors.black12,
        child: InkWell(
          customBorder: const CircleBorder(),
          onTap: () => _showSyncSheet(context, ref),
          child: Padding(
            padding: const EdgeInsets.all(10),
            child: Stack(
              clipBehavior: Clip.none,
              children: [
                Icon(icon, color: color, size: 20),
                if (hasPending)
                  Positioned(
                    right: -4,
                    top: -4,
                    child: Container(
                      padding: const EdgeInsets.all(2),
                      constraints: const BoxConstraints(
                          minWidth: 14, minHeight: 14),
                      decoration: const BoxDecoration(
                        color: Color(0xFFD97706),
                        shape: BoxShape.circle,
                      ),
                      child: Text(
                        '$pendingCount',
                        style: const TextStyle(
                          fontSize: 8,
                          fontWeight: FontWeight.w800,
                          color: Colors.white,
                        ),
                        textAlign: TextAlign.center,
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  static supabase_flutter.SupabaseClient get _supabaseClient =>
      supabase_flutter.Supabase.instance.client;

  void _showSyncSheet(BuildContext context, WidgetRef ref) {
    final queue = ref.read(syncQueueServiceProvider);
    final count = queue.pendingCount;

    showModalBottomSheet<void>(
      context: context,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius:
            BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (_) => _SyncSheet(
        pendingCount: count,
        isOnline: isOnline,
        onSync: () {
          Navigator.pop(context);
          queue.flush(_supabaseClient).then((result) {
            if (context.mounted) {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text(result.hasFailures
                      ? '${result.synced} senkronize edildi, '
                          '${result.failed} başarısız'
                      : '${result.synced} öğe başarıyla senkronize edildi'),
                  backgroundColor: result.hasFailures
                      ? _primary
                      : const Color(0xFF16A34A),
                ),
              );
            }
          });
        },
      ),
    );
  }
}

/// Bottom sheet showing the current sync status with a manual sync button.
class _SyncSheet extends StatelessWidget {
  const _SyncSheet({
    required this.pendingCount,
    required this.isOnline,
    required this.onSync,
  });

  final int pendingCount;
  final bool isOnline;
  final VoidCallback onSync;

  @override
  Widget build(BuildContext context) {
    final hasPending = pendingCount > 0;

    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 20, 24, 40),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Handle
          Container(
            width: 36,
            height: 4,
            decoration: BoxDecoration(
              color: _outlineVariant,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          const SizedBox(height: 20),

          // Icon
          Container(
            width: 56,
            height: 56,
            decoration: BoxDecoration(
              color: hasPending
                  ? const Color(0xFFFFFBEB)
                  : const Color(0xFFDCFCE7),
              shape: BoxShape.circle,
            ),
            child: Icon(
              hasPending
                  ? Icons.cloud_upload_outlined
                  : Icons.cloud_done_outlined,
              size: 28,
              color: hasPending
                  ? const Color(0xFFD97706)
                  : const Color(0xFF16A34A),
            ),
          ),
          const SizedBox(height: 14),

          Text(
            hasPending ? 'Bekleyen Senkronizasyon' : 'Tüm Veriler Senkronize',
            style: const TextStyle(
              fontSize: 17,
              fontWeight: FontWeight.w800,
              color: _onSurface,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            hasPending
                ? '$pendingCount kayıt çevrimdışı olarak saklandı.'
                    '${isOnline ? ' Şimdi senkronize edebilirsiniz.' : ' İnternet bağlantısı gerekli.'}'
                : 'Tüm bakım ve arıza kayıtları Supabase ile senkronize.',
            textAlign: TextAlign.center,
            style: const TextStyle(
              fontSize: 13,
              color: _onSurfaceVariant,
              height: 1.5,
            ),
          ),

          const SizedBox(height: 24),

          if (hasPending && isOnline)
            FilledButton.icon(
              icon: const Icon(Icons.sync_rounded),
              label: const Text('Şimdi Senkronize Et'),
              style: FilledButton.styleFrom(
                backgroundColor: const Color(0xFF16A34A),
                minimumSize: const Size(double.infinity, 50),
              ),
              onPressed: onSync,
            ),

          if (!isOnline)
            Container(
              padding: const EdgeInsets.symmetric(
                  horizontal: 16, vertical: 12),
              decoration: BoxDecoration(
                color: const Color(0xFFFEE2E2),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Row(
                children: const [
                  Icon(Icons.wifi_off_rounded,
                      color: _primary, size: 18),
                  SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      'İnternet bağlantısı yok. Bağlantı kurulduğunda otomatik senkronize edilecek.',
                      style: TextStyle(
                          fontSize: 12, color: _primary, height: 1.4),
                    ),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}

// ── Active Faults Section ─────────────────────────────────────────────────────

class _ActiveFaultsSection extends StatelessWidget {
  const _ActiveFaultsSection({
    required this.activeFaults,
    required this.elevators,
  });

  final AsyncValue<List<FaultReportModel>> activeFaults;
  final List<ElevatorModel>? elevators;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Section header
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            const Text(
              'Açık Arızalar',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.w800,
                color: _onSurface,
                letterSpacing: -0.5,
              ),
            ),
            activeFaults.maybeWhen(
              data: (faults) => Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: _primary.withValues(alpha: 0.06),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  '${faults.length} Aktif',
                  style: const TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    color: _primary,
                  ),
                ),
              ),
              orElse: () => const SizedBox.shrink(),
            ),
          ],
        ),
        const SizedBox(height: 16),

        // Content
        activeFaults.when(
          loading: () => const _LoadingCard(),
          error: (e, _) =>
              _ErrorCard(message: e.toString().replaceFirst('Exception: ', '')),
          data: (faults) {
            if (faults.isEmpty) {
              return const _EmptyCard(
                icon: Icons.check_circle_outline,
                message: 'Aktif arıza bulunmuyor.',
              );
            }
            // Horizontal scroll — height sized to fit the card design.
            return SizedBox(
              height: 190,
              child: ListView.separated(
                scrollDirection: Axis.horizontal,
                clipBehavior: Clip.none,
                padding: EdgeInsets.zero,
                itemCount: faults.length,
                separatorBuilder: (context, index) => const SizedBox(width: 16),
                itemBuilder: (context, i) {
                  final elevator = _findElevator(
                    faults[i].elevatorId,
                    elevators,
                  );
                  return _FaultCard(
                    fault: faults[i],
                    buildingName: elevator?.buildingName ?? 'Asansör',
                    address: elevator?.address ?? faults[i].description,
                    onTap: () => context.push('/fault/${faults[i].id}'),
                  );
                },
              ),
            );
          },
        ),
      ],
    );
  }
}

class _FaultCard extends StatelessWidget {
  const _FaultCard({
    required this.fault,
    required this.buildingName,
    required this.address,
    this.onTap,
  });

  final FaultReportModel fault;
  final String buildingName;
  final String address;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    // Non-empty description for the card body.
    final description = fault.description.isNotEmpty
        ? fault.description
        : 'Arıza bildirimi alındı.';

    return GestureDetector(
      onTap: onTap,
      child: Container(
      width: 264,
      decoration: BoxDecoration(
        color: _surfaceContainerLowest,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: _error.withValues(alpha: 0.12),
            blurRadius: 16,
            offset: const Offset(0, 4),
          ),
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisSize: MainAxisSize.min,
        children: [
          // ── Crimson header band ─────────────────────────────────────
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.centerLeft,
                end: Alignment.centerRight,
                colors: [Color(0xFFB91C1C), Color(0xFFDC2626)],
              ),
              borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                // "ACİL" badge
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(
                      Icons.warning_rounded,
                      color: Colors.white,
                      size: 14,
                    ),
                    const SizedBox(width: 5),
                    const Text(
                      'ACİL ARIZA',
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w800,
                        color: Colors.white,
                        letterSpacing: 1.2,
                      ),
                    ),
                  ],
                ),
                // Time ago
                Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 7, vertical: 3),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.18),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Text(
                    _timeAgo(fault.reportedAt),
                    style: const TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.w600,
                      color: Colors.white,
                    ),
                  ),
                ),
              ],
            ),
          ),

          // ── Card body ───────────────────────────────────────────────
          Padding(
            padding: const EdgeInsets.all(14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                // Building name
                Text(
                  buildingName,
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w800,
                    color: _onSurface,
                    letterSpacing: -0.3,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                // Address
                if (address.isNotEmpty) ...[
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      const Icon(
                        Icons.location_on_outlined,
                        size: 13,
                        color: _outline,
                      ),
                      const SizedBox(width: 3),
                      Expanded(
                        child: Text(
                          address,
                          style: const TextStyle(
                            fontSize: 12,
                            color: _outline,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                ],
                const SizedBox(height: 10),
                // Description
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: _surfaceContainer,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    description,
                    style: const TextStyle(
                      fontSize: 12,
                      color: _onSurfaceVariant,
                      height: 1.4,
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
      ),
    );
  }
}

// ── Daily Agenda Section (real-time) ─────────────────────────────────────────

class _DailyAgendaSection extends StatelessWidget {
  const _DailyAgendaSection({
    required this.mySchedules,
    required this.elevators,
  });

  final AsyncValue<List<ScheduleModel>> mySchedules;
  final List<ElevatorModel>? elevators;

  static bool _isToday(DateTime dt) {
    final now = DateTime.now();
    final d = dt.toLocal();
    return d.year == now.year && d.month == now.month && d.day == now.day;
  }

  static String _fmtScheduleDate(DateTime dt) {
    final local = dt.toLocal();
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final day = DateTime(local.year, local.month, local.day);
    final time =
        '${local.hour.toString().padLeft(2, '0')}:${local.minute.toString().padLeft(2, '0')}';
    if (day == today) return 'Bugün $time';
    if (day == today.add(const Duration(days: 1))) return 'Yarın $time';
    return '${local.day}/${local.month}/${local.year} $time';
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Section header
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Row(
              children: [
                const Text(
                  'Günlük Ajanda',
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.w800,
                    color: _onSurface,
                    letterSpacing: -0.5,
                  ),
                ),
                const SizedBox(width: 8),
                // Live dot — visible only when the stream is active
                mySchedules.when(
                  loading: () => const SizedBox.shrink(),
                  error: (e, st) => const SizedBox.shrink(),
                  data: (s) => Container(
                    width: 7,
                    height: 7,
                    decoration: const BoxDecoration(
                      color: Color(0xFF2E7D32),
                      shape: BoxShape.circle,
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
        const SizedBox(height: 16),

        // Content
        mySchedules.when(
          loading: () => const _LoadingCard(),
          error: (e, _) =>
              _ErrorCard(message: e.toString().replaceFirst('Exception: ', '')),
          data: (schedules) {
            if (schedules.isEmpty) {
              return const _EmptyCard(
                icon: Icons.event_available_outlined,
                message: 'Atanmış göreviniz bulunmuyor.',
              );
            }

            // Split into today vs upcoming
            final todayTasks =
                schedules.where((s) => _isToday(s.scheduledDate)).toList();
            final upcomingTasks =
                schedules.where((s) => !_isToday(s.scheduledDate)).toList();

            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (todayTasks.isNotEmpty) ...[
                  _AgendaGroupHeader(
                    label: "Bugün",
                    count: todayTasks.length,
                    highlight: true,
                  ),
                  const SizedBox(height: 8),
                  ...todayTasks.map(
                    (s) => _AgendaTaskCard(
                      schedule: s,
                      elevator: _findElevator(s.elevatorId, elevators),
                      dateLabel: _fmtScheduleDate(s.scheduledDate),
                    ),
                  ),
                ],
                if (upcomingTasks.isNotEmpty) ...[
                  if (todayTasks.isNotEmpty) const SizedBox(height: 12),
                  _AgendaGroupHeader(
                    label: "Yaklaşan",
                    count: upcomingTasks.length,
                    highlight: false,
                  ),
                  const SizedBox(height: 8),
                  ...upcomingTasks.take(3).map(
                        (s) => _AgendaTaskCard(
                          schedule: s,
                          elevator: _findElevator(s.elevatorId, elevators),
                          dateLabel: _fmtScheduleDate(s.scheduledDate),
                        ),
                      ),
                  if (upcomingTasks.length > 3)
                    Padding(
                      padding: const EdgeInsets.only(top: 4),
                      child: Text(
                        '+${upcomingTasks.length - 3} daha görev var.',
                        style: const TextStyle(
                          fontSize: 12,
                          color: _outline,
                        ),
                      ),
                    ),
                ],
              ],
            );
          },
        ),
      ],
    );
  }
}

class _AgendaGroupHeader extends StatelessWidget {
  const _AgendaGroupHeader({
    required this.label,
    required this.count,
    required this.highlight,
  });

  final String label;
  final int count;
  final bool highlight;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Text(
          label,
          style: TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w700,
            color: highlight ? _primary : _onSurfaceVariant,
            letterSpacing: 0.3,
          ),
        ),
        const SizedBox(width: 6),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
          decoration: BoxDecoration(
            color: highlight
                ? _primary.withValues(alpha: 0.1)
                : _surfaceContainer,
            borderRadius: BorderRadius.circular(20),
          ),
          child: Text(
            '$count',
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w700,
              color: highlight ? _primary : _outline,
            ),
          ),
        ),
      ],
    );
  }
}

class _AgendaTaskCard extends ConsumerWidget {
  const _AgendaTaskCard({
    required this.schedule,
    required this.elevator,
    required this.dateLabel,
  });

  final ScheduleModel schedule;
  final ElevatorModel? elevator;
  final String dateLabel;

  static Color _priorityColor(String p) {
    switch (p) {
      case 'low':
        return const Color(0xFF78909C);
      case 'high':
        return const Color(0xFFE65100);
      case 'emergency':
        return const Color(0xFFBA1A1A);
      default:
        return _primary;
    }
  }

  static String _priorityLabel(String p) {
    switch (p) {
      case 'low':
        return 'Düşük';
      case 'high':
        return 'Yüksek';
      case 'emergency':
        return '⚠ Acil';
      default:
        return 'Normal';
    }
  }

  static bool _isActive(String s) =>
      s == 'pending' || s == 'in_progress';

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final pColor = _priorityColor(schedule.priority);
    final isEmergency = schedule.priority == 'emergency';
    final shortElevatorId = schedule.elevatorId.length > 6
        ? schedule.elevatorId.substring(0, 6)
        : schedule.elevatorId;

    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Container(
        decoration: BoxDecoration(
          color: isEmergency
              ? const Color(0xFFFFDAD6).withValues(alpha: 0.4)
              : _surfaceContainerLowest,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: isEmergency
                ? const Color(0xFFBA1A1A).withValues(alpha: 0.3)
                : _outlineVariant.withValues(alpha: 0.4),
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.03),
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: IntrinsicHeight(
          child: Row(
            children: [
              // Priority stripe
              Container(
                width: 4,
                decoration: BoxDecoration(
                  color: pColor,
                  borderRadius: const BorderRadius.only(
                    topLeft: Radius.circular(16),
                    bottomLeft: Radius.circular(16),
                  ),
                ),
              ),
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(14, 14, 14, 12),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Time + priority badge
                      Row(
                        children: [
                          Icon(
                            Icons.access_time_outlined,
                            size: 13,
                            color: pColor,
                          ),
                          const SizedBox(width: 4),
                          Text(
                            dateLabel,
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w700,
                              color: pColor,
                            ),
                          ),
                          const Spacer(),
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 6, vertical: 2),
                            decoration: BoxDecoration(
                              color: pColor.withValues(alpha: 0.12),
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: Text(
                              _priorityLabel(schedule.priority),
                              style: TextStyle(
                                fontSize: 10,
                                fontWeight: FontWeight.w700,
                                color: pColor,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      // Building name
                      Text(
                        elevator?.buildingName ??
                            'Asansör $shortElevatorId',
                        style: const TextStyle(
                          fontWeight: FontWeight.w700,
                          fontSize: 15,
                          color: _onSurface,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      // Address
                      if (elevator?.address != null)
                        Padding(
                          padding: const EdgeInsets.only(top: 2),
                          child: Row(
                            children: [
                              const Icon(
                                Icons.location_on_outlined,
                                size: 12,
                                color: _outline,
                              ),
                              const SizedBox(width: 3),
                              Expanded(
                                child: Text(
                                  elevator!.address!,
                                  style: const TextStyle(
                                    fontSize: 12,
                                    color: _outline,
                                  ),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                            ],
                          ),
                        ),
                      if (schedule.notes != null &&
                          schedule.notes!.isNotEmpty)
                        Padding(
                          padding: const EdgeInsets.only(top: 4),
                          child: Text(
                            schedule.notes!,
                            style: const TextStyle(
                              fontSize: 12,
                              color: _onSurfaceVariant,
                              fontStyle: FontStyle.italic,
                            ),
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      const SizedBox(height: 10),
                      // İşe Başla button — only for active tasks
                      if (_isActive(schedule.status))
                        SizedBox(
                          width: double.infinity,
                          height: 38,
                          child: FilledButton.icon(
                            onPressed: () {
                              // Mark in_progress then open elevator hub
                              if (schedule.status == 'pending') {
                                ref
                                    .read(scheduleControllerProvider.notifier)
                                    .updateStatus(
                                      taskId: schedule.id,
                                      status: 'in_progress',
                                    );
                              }
                              context.push('/elevator/${schedule.elevatorId}');
                            },
                            style: FilledButton.styleFrom(
                              backgroundColor: pColor,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(10),
                              ),
                            ),
                            icon: const Icon(
                              Icons.play_arrow_rounded,
                              size: 18,
                            ),
                            label: const Text(
                              'İşe Başla',
                              style: TextStyle(
                                fontWeight: FontWeight.w700,
                                fontSize: 13,
                              ),
                            ),
                          ),
                        )
                      else
                        Row(
                          children: [
                            Icon(
                              schedule.status == 'completed'
                                  ? Icons.check_circle_outline
                                  : Icons.cancel_outlined,
                              size: 14,
                              color: schedule.status == 'completed'
                                  ? const Color(0xFF2E7D32)
                                  : _outline,
                            ),
                            const SizedBox(width: 4),
                            Text(
                              schedule.status == 'completed'
                                  ? 'Tamamlandı'
                                  : 'İptal Edildi',
                              style: TextStyle(
                                fontSize: 12,
                                color: schedule.status == 'completed'
                                    ? const Color(0xFF2E7D32)
                                    : _outline,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ],
                        ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ── Stats Section (Asymmetric Bento) ─────────────────────────────────────────

class _StatsSection extends StatelessWidget {
  const _StatsSection({
    required this.activeFaultCount,
    required this.completedCount,
  });

  final int activeFaultCount;
  final int completedCount;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        // Left — completed (primary background)
        Expanded(
          child: AspectRatio(
            aspectRatio: 1,
            child: Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [_primary, _primaryContainer],
                ),
                borderRadius: BorderRadius.circular(32),
              ),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Icon(
                    Icons.check_circle_outline,
                    color: Colors.white,
                    size: 32,
                  ),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '$completedCount',
                        style: const TextStyle(
                          fontSize: 36,
                          fontWeight: FontWeight.w700,
                          color: Colors.white,
                        ),
                      ),
                      const Text(
                        'TAMAMLANAN',
                        style: TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.w500,
                          color: Colors.white70,
                          letterSpacing: 1.5,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
        const SizedBox(width: 16),
        // Right — active faults (surface background)
        Expanded(
          child: AspectRatio(
            aspectRatio: 1,
            child: Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: _surfaceContainerHighest,
                borderRadius: BorderRadius.circular(32),
              ),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Icon(
                    Icons.error_outline,
                    color: _onSurfaceVariant,
                    size: 32,
                  ),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '$activeFaultCount',
                        style: const TextStyle(
                          fontSize: 36,
                          fontWeight: FontWeight.w700,
                          color: _onSurface,
                        ),
                      ),
                      const Text(
                        'AÇIK ARIZA',
                        style: TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.w500,
                          color: _onSurfaceVariant,
                          letterSpacing: 1.5,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }
}

// ── Elevators Shortcut Card ───────────────────────────────────────────────────

class _ElevatorsShortcutCard extends StatelessWidget {
  const _ElevatorsShortcutCard({required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      borderRadius: BorderRadius.circular(20),
      child: InkWell(
        borderRadius: BorderRadius.circular(20),
        onTap: onTap,
        child: Ink(
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [_primary, _primaryContainer],
            ),
            borderRadius: BorderRadius.circular(20),
            boxShadow: [
              BoxShadow(
                color: _primary.withValues(alpha: 0.28),
                blurRadius: 18,
                offset: const Offset(0, 8),
              ),
            ],
          ),
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Row(
              children: [
                Container(
                  width: 52,
                  height: 52,
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: const Icon(
                    Icons.domain_outlined,
                    color: Colors.white,
                    size: 28,
                  ),
                ),
                const SizedBox(width: 16),
                const Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Asansörlerim',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w700,
                          color: Colors.white,
                          letterSpacing: -0.3,
                        ),
                      ),
                      SizedBox(height: 4),
                      Text(
                        'Sistemdeki tüm asansörleri listele ve ara',
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.white70,
                          height: 1.3,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                const Icon(
                  Icons.arrow_forward_ios_rounded,
                  color: Colors.white70,
                  size: 16,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// ── QR FAB ────────────────────────────────────────────────────────────────────

class _QrFab extends StatelessWidget {
  const _QrFab({required this.onPressed});

  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 80,
      height: 80,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        // White border that "cuts into" the BottomAppBar notch, matching the
        // Stitch design's `border-8 border-background` class.
        border: Border.all(color: _background, width: 8),
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [_primary, _primaryContainer],
        ),
        boxShadow: [
          BoxShadow(
            color: _primary.withValues(alpha: 0.30),
            blurRadius: 32,
            offset: const Offset(0, 12),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        shape: const CircleBorder(),
        child: InkWell(
          customBorder: const CircleBorder(),
          onTap: onPressed,
          child: const Icon(
            Icons.qr_code_scanner,
            color: Colors.white,
            size: 32,
          ),
        ),
      ),
    );
  }
}

// ── Bottom Navigation Bar ─────────────────────────────────────────────────────

class _BottomNavBar extends ConsumerWidget {
  const _BottomNavBar();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final role = ref.watch(roleProvider);
    final isAdmin = role == 'admin';

    return BottomAppBar(
      // CircularNotchedRectangle carves out a circle for the centre-docked FAB.
      shape: const CircularNotchedRectangle(),
      notchMargin: 8,
      color: Colors.white.withValues(alpha: 0.92),
      elevation: 0,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            _NavItem(
              icon: Icons.domain_outlined,
              label: 'Filo',
              isActive: false,
              onPressed: () => context.push('/elevators'),
            ),
            _NavItem(
              icon: Icons.error_outline,
              label: 'Arızalar',
              isActive: false,
            ),
            const SizedBox(width: 56), // spacer for the centre FAB
            _NavItem(
              icon: Icons.event_note_outlined,
              label: 'Program',
              isActive: false,
              onPressed: isAdmin
                  ? () => context.push('/admin/master-calendar')
                  : null,
            ),
            _NavItem(icon: Icons.history, label: 'Günlük', isActive: true),
          ],
        ),
      ),
    );
  }
}

class _NavItem extends StatelessWidget {
  const _NavItem({
    required this.icon,
    required this.label,
    required this.isActive,
    this.onPressed,
  });

  final IconData icon;
  final String label;
  final bool isActive;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    final color = isActive ? _primary : const Color(0xFF94A3B8);
    final child = Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, color: color, size: 24),
        const SizedBox(height: 2),
        Text(
          label.toUpperCase(),
          style: TextStyle(
            fontSize: 10,
            fontWeight: isActive ? FontWeight.w700 : FontWeight.w500,
            color: color,
            letterSpacing: 0.6,
          ),
        ),
      ],
    );

    if (onPressed == null) return child;

    return InkWell(
      onTap: onPressed,
      borderRadius: BorderRadius.circular(8),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        child: child,
      ),
    );
  }
}

// ── Shared state widgets ──────────────────────────────────────────────────────

class _LoadingCard extends StatelessWidget {
  const _LoadingCard();

  @override
  Widget build(BuildContext context) {
    return const Center(
      child: Padding(
        padding: EdgeInsets.symmetric(vertical: 24),
        child: CircularProgressIndicator(color: _primary),
      ),
    );
  }
}

class _ErrorCard extends StatelessWidget {
  const _ErrorCard({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: _errorContainer,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          const Icon(Icons.error_outline, color: _onErrorContainer),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              message,
              style: const TextStyle(color: _onErrorContainer),
            ),
          ),
        ],
      ),
    );
  }
}

class _EmptyCard extends StatelessWidget {
  const _EmptyCard({required this.icon, required this.message});

  final IconData icon;
  final String message;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: _surfaceContainer,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        children: [
          Icon(icon, color: _outline),
          const SizedBox(width: 12),
          Text(message, style: const TextStyle(color: _outline)),
        ],
      ),
    );
  }
}
