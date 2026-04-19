import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../models/technician_stats.dart';
import '../providers/admin_providers.dart';

// ── Design tokens ─────────────────────────────────────────────────────────────

const _primary = Color(0xFFB91C1C);
const _primaryDark = Color(0xFF991B1B);
const _success = Color(0xFF16A34A);
const _successContainer = Color(0xFFDCFCE7);
const _onSurface = Color(0xFF0F172A);
const _onSurfaceVariant = Color(0xFF475569);
const _outline = Color(0xFF94A3B8);
const _outlineVariant = Color(0xFFE2E8F0);
const _surface = Colors.white;
const _surfaceContainer = Color(0xFFF1F5F9);
const _background = Color(0xFFF9FAFB);

// ── Main view ─────────────────────────────────────────────────────────────────

class TechnicianManagementView extends ConsumerWidget {
  const TechnicianManagementView({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final dataAsync = ref.watch(technicianManagementProvider);

    return Scaffold(
      backgroundColor: _background,
      appBar: AppBar(
        title: const Text(
          'Teknisyen Ekibi',
          style: TextStyle(fontWeight: FontWeight.w800),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh_rounded),
            tooltip: 'Yenile',
            onPressed: () =>
                ref.invalidate(technicianManagementProvider),
          ),
        ],
      ),
      body: dataAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, st) => _ErrorBody(
          error: e,
          onRetry: () => ref.invalidate(technicianManagementProvider),
        ),
        data: (stats) => _TechnicianList(stats: stats),
      ),
    );
  }
}

// ── List ──────────────────────────────────────────────────────────────────────

class _TechnicianList extends StatelessWidget {
  const _TechnicianList({required this.stats});

  final List<TechnicianStats> stats;

  @override
  Widget build(BuildContext context) {
    if (stats.isEmpty) {
      return const _EmptyBody();
    }

    final activeCount = stats.where((s) => s.hasActiveTasks).length;
    final freeCount = stats.length - activeCount;

    return ListView.separated(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 32),
      itemCount: stats.length + 1, // +1 for header
      separatorBuilder: (_, i) =>
          i == 0 ? const SizedBox(height: 16) : const SizedBox(height: 12),
      itemBuilder: (_, i) {
        if (i == 0) {
          return _SummaryHeader(
            total: stats.length,
            active: activeCount,
            free: freeCount,
          );
        }
        final techStats = stats[i - 1];
        return _TechnicianCard(
          stats: techStats,
          onTap: () => _showDetailSheet(context, techStats),
        );
      },
    );
  }

  void _showDetailSheet(BuildContext context, TechnicianStats stats) {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _TechnicianDetailSheet(stats: stats),
    );
  }
}

// ── Summary header ────────────────────────────────────────────────────────────

class _SummaryHeader extends StatelessWidget {
  const _SummaryHeader({
    required this.total,
    required this.active,
    required this.free,
  });

  final int total;
  final int active;
  final int free;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [_primary, _primaryDark],
        ),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        children: [
          _StatPill(label: 'Toplam', value: total, light: true),
          const SizedBox(width: 12),
          _StatPill(
            label: 'Aktif',
            value: active,
            light: true,
            accent: const Color(0xFF4ADE80),
          ),
          const SizedBox(width: 12),
          _StatPill(
            label: 'Müsait',
            value: free,
            light: true,
            accent: const Color(0xFFFBBF24),
          ),
          const Spacer(),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                DateFormat('d MMMM', 'tr_TR').format(DateTime.now()),
                style: const TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                  color: Colors.white,
                ),
              ),
              Text(
                'Bugün',
                style: TextStyle(
                  fontSize: 11,
                  color: Colors.white.withValues(alpha: 0.7),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _StatPill extends StatelessWidget {
  const _StatPill({
    required this.label,
    required this.value,
    this.light = false,
    this.accent,
  });

  final String label;
  final int value;
  final bool light;
  final Color? accent;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          '$value',
          style: TextStyle(
            fontSize: 22,
            fontWeight: FontWeight.w900,
            color: accent ?? Colors.white,
          ),
        ),
        Text(
          label,
          style: TextStyle(
            fontSize: 11,
            color: Colors.white.withValues(alpha: 0.8),
          ),
        ),
      ],
    );
  }
}

// ── Technician card ───────────────────────────────────────────────────────────

class _TechnicianCard extends StatelessWidget {
  const _TechnicianCard({
    required this.stats,
    required this.onTap,
  });

  final TechnicianStats stats;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final profile = stats.profile;
    final allDone =
        stats.todayTotal > 0 && stats.progressValue >= 1.0;
    final barColor = allDone ? _success : _primary;

    return Material(
      color: _surface,
      borderRadius: BorderRadius.circular(16),
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: onTap,
        child: Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: _outlineVariant),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.04),
                blurRadius: 10,
                offset: const Offset(0, 3),
              ),
            ],
          ),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // ── Top row: avatar + info ──────────────────────────
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Avatar with status dot
                    Stack(
                      clipBehavior: Clip.none,
                      children: [
                        CircleAvatar(
                          radius: 28,
                          backgroundColor:
                              _primary.withValues(alpha: 0.12),
                          child: Text(
                            profile.initials,
                            style: const TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.w800,
                              color: _primary,
                            ),
                          ),
                        ),
                        Positioned(
                          right: 0,
                          bottom: 0,
                          child: Container(
                            width: 14,
                            height: 14,
                            decoration: BoxDecoration(
                              color: stats.hasActiveTasks
                                  ? _success
                                  : _outline,
                              shape: BoxShape.circle,
                              border: Border.all(
                                  color: _surface, width: 2),
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(width: 14),

                    // Name + contact
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            crossAxisAlignment:
                                CrossAxisAlignment.start,
                            children: [
                              Expanded(
                                child: Text(
                                  profile.displayName,
                                  style: const TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.w800,
                                    color: _onSurface,
                                    letterSpacing: -0.3,
                                  ),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                              const SizedBox(width: 8),
                              _MonthlyBadge(
                                  count: stats.monthlyCompleted),
                            ],
                          ),
                          if (profile.email != null &&
                              profile.email!.isNotEmpty) ...[
                            const SizedBox(height: 3),
                            Row(
                              children: [
                                const Icon(
                                    Icons.email_outlined,
                                    size: 12,
                                    color: _outline),
                                const SizedBox(width: 4),
                                Expanded(
                                  child: Text(
                                    profile.email!,
                                    style: const TextStyle(
                                        fontSize: 12,
                                        color: _outline),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                              ],
                            ),
                          ],
                          if (profile.phone != null &&
                              profile.phone!.isNotEmpty) ...[
                            const SizedBox(height: 2),
                            Row(
                              children: [
                                const Icon(Icons.phone_outlined,
                                    size: 12, color: _outline),
                                const SizedBox(width: 4),
                                Text(
                                  profile.phone!,
                                  style: const TextStyle(
                                      fontSize: 12, color: _outline),
                                ),
                              ],
                            ),
                          ],
                        ],
                      ),
                    ),
                  ],
                ),

                const SizedBox(height: 14),

                // ── Workload bar ────────────────────────────────────
                if (stats.todayTotal > 0) ...[
                  Row(
                    children: [
                      const Text(
                        'Bugünkü İlerleme',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: _onSurfaceVariant,
                        ),
                      ),
                      const Spacer(),
                      Text(
                        '${stats.todayCompleted}/${stats.todayTotal} görev',
                        style: const TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                          color: _onSurfaceVariant,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 7),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(4),
                    child: LinearProgressIndicator(
                      value: stats.progressValue,
                      minHeight: 7,
                      backgroundColor: _outlineVariant,
                      valueColor:
                          AlwaysStoppedAnimation<Color>(barColor),
                    ),
                  ),
                  const SizedBox(height: 5),
                  Text(
                    allDone
                        ? '✓ Tüm görevler tamamlandı'
                        : '${stats.todayPending} görev bekliyor',
                    style: TextStyle(
                      fontSize: 11,
                      color: allDone ? _success : _outline,
                      fontWeight: allDone
                          ? FontWeight.w700
                          : FontWeight.normal,
                    ),
                  ),
                ] else
                  const Text(
                    'Bugün için planlanmış görev yok',
                    style: TextStyle(
                      fontSize: 12,
                      color: _outline,
                      fontStyle: FontStyle.italic,
                    ),
                  ),

                const Divider(height: 20, color: _outlineVariant),

                // ── Action buttons ──────────────────────────────────
                Row(
                  children: [
                    _ActionButton(
                      icon: Icons.phone_outlined,
                      label: 'Ara',
                      onTap: () => _handleCall(context, profile.phone,
                          profile.displayName),
                    ),
                    const SizedBox(width: 6),
                    _ActionButton(
                      icon: Icons.chat_bubble_outline_rounded,
                      label: 'Mesaj',
                      onTap: () => _handleMessage(
                          context, profile.phone, profile.displayName),
                    ),
                    const Spacer(),
                    TextButton.icon(
                      icon: const Icon(Icons.list_alt_rounded, size: 16),
                      label: Text(
                        stats.todayTotal > 0
                            ? '${stats.todayTotal} Görev'
                            : 'Görevler',
                        style: const TextStyle(fontSize: 12),
                      ),
                      style: TextButton.styleFrom(
                        foregroundColor: _primary,
                        padding: const EdgeInsets.symmetric(
                            horizontal: 10, vertical: 6),
                      ),
                      onPressed: onTap,
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  void _handleCall(
      BuildContext context, String? phone, String name) {
    if (phone == null || phone.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('$name için telefon numarası kayıtlı değil.'),
          behavior: SnackBarBehavior.floating,
        ),
      );
      return;
    }
    Clipboard.setData(ClipboardData(text: phone));
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('$name: $phone — Kopyalandı'),
        behavior: SnackBarBehavior.floating,
        action: SnackBarAction(label: 'Tamam', onPressed: () {}),
      ),
    );
  }

  void _handleMessage(
      BuildContext context, String? phone, String name) {
    if (phone == null || phone.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('$name için telefon numarası kayıtlı değil.'),
          behavior: SnackBarBehavior.floating,
        ),
      );
      return;
    }
    Clipboard.setData(ClipboardData(text: phone));
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Numara kopyalandı: $phone'),
        behavior: SnackBarBehavior.floating,
        action: SnackBarAction(label: 'Tamam', onPressed: () {}),
      ),
    );
  }
}

// ── Monthly badge ─────────────────────────────────────────────────────────────

class _MonthlyBadge extends StatelessWidget {
  const _MonthlyBadge({required this.count});

  final int count;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: count > 0
            ? _successContainer
            : _surfaceContainer,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        'Bu Ay: $count İş',
        style: TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w700,
          color: count > 0 ? _success : _outline,
        ),
      ),
    );
  }
}

// ── Action button ─────────────────────────────────────────────────────────────

class _ActionButton extends StatelessWidget {
  const _ActionButton({
    required this.icon,
    required this.label,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(8),
      child: Container(
        padding:
            const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
        decoration: BoxDecoration(
          color: _surfaceContainer,
          borderRadius: BorderRadius.circular(8),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 15, color: _onSurfaceVariant),
            const SizedBox(width: 5),
            Text(
              label,
              style: const TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: _onSurfaceVariant,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ── Technician detail sheet (DraggableScrollableSheet) ────────────────────────

class _TechnicianDetailSheet extends StatelessWidget {
  const _TechnicianDetailSheet({required this.stats});

  final TechnicianStats stats;

  @override
  Widget build(BuildContext context) {
    return DraggableScrollableSheet(
      initialChildSize: 0.55,
      minChildSize: 0.35,
      maxChildSize: 0.92,
      expand: false,
      builder: (context, scrollController) {
        return Container(
          decoration: const BoxDecoration(
            color: _surface,
            borderRadius:
                BorderRadius.vertical(top: Radius.circular(24)),
          ),
          child: Column(
            children: [
              // ── Handle ─────────────────────────────────────────────
              const SizedBox(height: 12),
              Center(
                child: Container(
                  width: 36,
                  height: 4,
                  decoration: BoxDecoration(
                    color: _outlineVariant,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              const SizedBox(height: 16),

              // ── Sheet header ────────────────────────────────────────
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: Row(
                  children: [
                    CircleAvatar(
                      radius: 22,
                      backgroundColor:
                          _primary.withValues(alpha: 0.12),
                      child: Text(
                        stats.profile.initials,
                        style: const TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w800,
                          color: _primary,
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            stats.profile.displayName,
                            style: const TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w800,
                              color: _onSurface,
                            ),
                          ),
                          Text(
                            stats.todayTotal == 0
                                ? 'Bugün görev yok'
                                : '${stats.todayTotal} görev — '
                                    '${stats.todayCompleted} tamamlandı',
                            style: const TextStyle(
                              fontSize: 12,
                              color: _onSurfaceVariant,
                            ),
                          ),
                        ],
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.close, color: _outline),
                      onPressed: () => Navigator.of(context).pop(),
                    ),
                  ],
                ),
              ),

              const Divider(height: 20, color: _outlineVariant),

              // ── Task list ───────────────────────────────────────────
              Expanded(
                child: stats.todayTasks.isEmpty
                    ? _SheetEmptyView(name: stats.profile.displayName)
                    : ListView.builder(
                        controller: scrollController,
                        padding: const EdgeInsets.fromLTRB(
                            16, 0, 16, 32),
                        itemCount: stats.todayTasks.length,
                        itemBuilder: (_, i) => _TimelineTaskItem(
                          task: stats.todayTasks[i],
                          isLast: i == stats.todayTasks.length - 1,
                          onNavigate: () {
                            Navigator.of(context).pop();
                            context.push(
                              '/elevator/${stats.todayTasks[i].elevatorId}',
                            );
                          },
                        ),
                      ),
              ),
            ],
          ),
        );
      },
    );
  }
}

// ── Timeline task item ────────────────────────────────────────────────────────

class _TimelineTaskItem extends StatelessWidget {
  const _TimelineTaskItem({
    required this.task,
    required this.isLast,
    required this.onNavigate,
  });

  final TechnicianTask task;
  final bool isLast;
  final VoidCallback onNavigate;

  @override
  Widget build(BuildContext context) {
    final time = DateFormat('HH:mm', 'tr_TR')
        .format(task.scheduledTime.toLocal());

    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Time column with connecting line
          SizedBox(
            width: 56,
            child: Column(
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 6, vertical: 4),
                  decoration: BoxDecoration(
                    color: task.isCompleted
                        ? _successContainer
                        : _primary.withValues(alpha: 0.08),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    time,
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w800,
                      color: task.isCompleted ? _success : _primary,
                    ),
                  ),
                ),
                if (!isLast)
                  Expanded(
                    child: Center(
                      child: Container(
                        width: 2,
                        margin:
                            const EdgeInsets.symmetric(vertical: 4),
                        color: _outlineVariant,
                      ),
                    ),
                  ),
              ],
            ),
          ),
          const SizedBox(width: 10),

          // Task card
          Expanded(
            child: Padding(
              padding: EdgeInsets.only(bottom: isLast ? 0 : 10),
              child: Material(
                color: _surface,
                borderRadius: BorderRadius.circular(12),
                child: InkWell(
                  borderRadius: BorderRadius.circular(12),
                  onTap: onNavigate,
                  child: Container(
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: _outlineVariant),
                    ),
                    child: IntrinsicHeight(
                      child: Row(
                        crossAxisAlignment:
                            CrossAxisAlignment.stretch,
                        children: [
                          // Priority stripe
                          Container(
                            width: 4,
                            decoration: BoxDecoration(
                              color: _priorityColor(task.priority),
                              borderRadius:
                                  const BorderRadius.horizontal(
                                      left: Radius.circular(12)),
                            ),
                          ),
                          Expanded(
                            child: Padding(
                              padding: const EdgeInsets.all(12),
                              child: Column(
                                crossAxisAlignment:
                                    CrossAxisAlignment.start,
                                children: [
                                  // Building name
                                  Text(
                                    task.buildingName,
                                    style: const TextStyle(
                                      fontSize: 14,
                                      fontWeight: FontWeight.w700,
                                      color: _onSurface,
                                    ),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                  // Address
                                  if (task.address != null &&
                                      task.address!.isNotEmpty) ...[
                                    const SizedBox(height: 3),
                                    Row(
                                      children: [
                                        const Icon(
                                          Icons.location_on_outlined,
                                          size: 12,
                                          color: _outline,
                                        ),
                                        const SizedBox(width: 3),
                                        Expanded(
                                          child: Text(
                                            task.address!,
                                            style: const TextStyle(
                                                fontSize: 12,
                                                color: _outline),
                                            maxLines: 1,
                                            overflow:
                                                TextOverflow.ellipsis,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ],
                                  // Notes
                                  if (task.notes != null &&
                                      task.notes!.isNotEmpty) ...[
                                    const SizedBox(height: 5),
                                    Text(
                                      task.notes!,
                                      style: const TextStyle(
                                        fontSize: 11,
                                        color: _onSurfaceVariant,
                                        fontStyle: FontStyle.italic,
                                      ),
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ],
                                  const SizedBox(height: 8),
                                  // Badges row
                                  Wrap(
                                    spacing: 6,
                                    runSpacing: 4,
                                    children: [
                                      _SmallBadge.status(
                                          task.status),
                                      _SmallBadge.priority(
                                          task.priority),
                                    ],
                                  ),
                                ],
                              ),
                            ),
                          ),
                          // Navigate arrow
                          Padding(
                            padding: const EdgeInsets.only(right: 8),
                            child: Icon(
                              Icons.arrow_forward_ios_rounded,
                              size: 12,
                              color: _outline.withValues(alpha: 0.6),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  static Color _priorityColor(String p) {
    switch (p) {
      case 'emergency':
        return const Color(0xFFDC2626);
      case 'high':
        return const Color(0xFFEA580C);
      case 'normal':
        return const Color(0xFF2563EB);
      default:
        return const Color(0xFF94A3B8);
    }
  }
}

// ── Small badge ───────────────────────────────────────────────────────────────

class _SmallBadge extends StatelessWidget {
  const _SmallBadge({
    required this.label,
    required this.bg,
    required this.fg,
  });

  final String label;
  final Color bg;
  final Color fg;

  factory _SmallBadge.status(String s) {
    final (lbl, bg, fg) = switch (s) {
      'completed' => ('TAMAMLANDI', const Color(0xFFDCFCE7), const Color(0xFF166534)),
      'in_progress' => ('DEVAM', const Color(0xFFFFF7ED), const Color(0xFF92400E)),
      'cancelled' => ('İPTAL', const Color(0xFFF1F5F9), const Color(0xFF64748B)),
      _ => ('BEKLİYOR', const Color(0xFFF1F5F9), const Color(0xFF475569)),
    };
    return _SmallBadge(label: lbl, bg: bg, fg: fg);
  }

  factory _SmallBadge.priority(String p) {
    final (lbl, bg, fg) = switch (p) {
      'emergency' => ('ACİL', const Color(0xFFFEE2E2), const Color(0xFFB91C1C)),
      'high' => ('YÜKSEK', const Color(0xFFFFF7ED), const Color(0xFFC2410C)),
      'low' => ('DÜŞÜK', const Color(0xFFF1F5F9), const Color(0xFF94A3B8)),
      _ => ('NORMAL', const Color(0xFFF1F5F9), const Color(0xFF475569)),
    };
    return _SmallBadge(label: lbl, bg: bg, fg: fg);
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(4),
      ),
      child: Text(
        label,
        style: TextStyle(
          fontSize: 9,
          fontWeight: FontWeight.w800,
          color: fg,
          letterSpacing: 0.5,
        ),
      ),
    );
  }
}

// ── Empty / error states ──────────────────────────────────────────────────────

class _EmptyBody extends StatelessWidget {
  const _EmptyBody();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            padding: const EdgeInsets.all(22),
            decoration: const BoxDecoration(
                color: _surfaceContainer, shape: BoxShape.circle),
            child: const Icon(Icons.engineering_outlined,
                size: 40, color: _outline),
          ),
          const SizedBox(height: 16),
          const Text(
            'Henüz teknisyen kaydı yok',
            style: TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w700,
                color: _onSurface),
          ),
          const SizedBox(height: 4),
          const Text(
            'Kullanıcı yönetiminden teknisyen rolü atayın.',
            style: TextStyle(fontSize: 13, color: _onSurfaceVariant),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }
}

class _ErrorBody extends StatelessWidget {
  const _ErrorBody({required this.error, required this.onRetry});

  final Object error;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.cloud_off_outlined,
                size: 48, color: _outline),
            const SizedBox(height: 12),
            const Text(
              'Veriler yüklenemedi',
              style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w700,
                  color: _onSurface),
            ),
            const SizedBox(height: 6),
            Text(
              error.toString(),
              style: const TextStyle(
                  fontSize: 12, color: _onSurfaceVariant),
              textAlign: TextAlign.center,
              maxLines: 3,
              overflow: TextOverflow.ellipsis,
            ),
            const SizedBox(height: 20),
            FilledButton.icon(
              onPressed: onRetry,
              icon: const Icon(Icons.refresh),
              label: const Text('Tekrar Dene'),
            ),
          ],
        ),
      ),
    );
  }
}

class _SheetEmptyView extends StatelessWidget {
  const _SheetEmptyView({required this.name});

  final String name;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.event_available_outlined,
                size: 36, color: _outline),
            const SizedBox(height: 12),
            Text(
              '$name için bugün\nplanlanmış görev yok',
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontSize: 14,
                color: _onSurfaceVariant,
                height: 1.5,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
