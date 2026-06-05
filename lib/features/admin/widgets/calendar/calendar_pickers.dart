import 'package:flutter/material.dart';
import 'package:asansor/core/theme/app_spacing.dart';
import 'package:asansor/core/theme/app_colors.dart';
import 'package:asansor/features/elevator/models/elevator_model.dart';
import 'package:asansor/features/admin/models/profile_model.dart';

// ── ElevatorPickerDialog ─────────────────────────────────────────────────────

class ElevatorPickerDialog extends StatefulWidget {
  const ElevatorPickerDialog({
    super.key,
    required this.elevators,
    this.selected,
  });

  final List<ElevatorModel> elevators;
  final ElevatorModel? selected;

  @override
  State<ElevatorPickerDialog> createState() => ElevatorPickerDialogState();
}

class ElevatorPickerDialogState extends State<ElevatorPickerDialog> {
  String _query = '';
  final _ctrl = TextEditingController();

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  List<ElevatorModel> get _filtered {
    if (_query.isEmpty) return widget.elevators;
    final q = _query.toLowerCase();
    return widget.elevators.where((e) {
      return e.buildingName.toLowerCase().contains(q) ||
          (e.address ?? '').toLowerCase().contains(q);
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      backgroundColor: AppColors.surfaceContainerLowest,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      title: Text(
        'Asansör Seç',
        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
          fontSize: 18,
          fontWeight: FontWeight.w700,
        ),
      ),
      contentPadding: const EdgeInsets.fromLTRB(0, 12, 0, 0),
      content: SizedBox(
        width: double.maxFinite,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: TextField(
                controller: _ctrl,
                autofocus: true,
                decoration: InputDecoration(
                  hintText: 'Bina adı veya adres ara...',
                  prefixIcon: const Icon(
                    Icons.search,
                    color: AppColors.outline,
                  ),
                  filled: true,
                  fillColor: AppColors.surfaceContainer,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10),
                    borderSide: BorderSide.none,
                  ),
                  contentPadding: const EdgeInsets.symmetric(vertical: 10),
                ),
                onChanged: (v) => setState(() => _query = v),
              ),
            ),
            const SizedBox(height: AppSpacing.sm),
            Flexible(
              child: ListView.builder(
                itemCount: _filtered.length,
                itemBuilder: (_, i) {
                  final e = _filtered[i];
                  final isSelected = widget.selected?.id == e.id;
                  return ListTile(
                    leading: Container(
                      width: 36,
                      height: 36,
                      decoration: BoxDecoration(
                        color: isSelected
                            ? AppColors.primary.withValues(alpha: 0.1)
                            : AppColors.surfaceContainer,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Icon(
                        Icons.elevator_outlined,
                        size: 18,
                        color: isSelected
                            ? AppColors.primary
                            : AppColors.outline,
                      ),
                    ),
                    title: Text(
                      e.buildingName,
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        fontWeight: FontWeight.w600,
                        color: isSelected
                            ? AppColors.primary
                            : AppColors.onSurface,
                      ),
                    ),
                    subtitle: e.address != null
                        ? Text(
                            e.address!,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: Theme.of(context).textTheme.bodyMedium
                                ?.copyWith(
                                  fontSize: 12,
                                  color: AppColors.outline,
                                ),
                          )
                        : null,
                    trailing: isSelected
                        ? const Icon(
                            Icons.check_circle,
                            color: AppColors.primary,
                          )
                        : null,
                    onTap: () => Navigator.pop(context, e),
                  );
                },
              ),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: Text('Vazgeç'),
        ),
      ],
    );
  }
}

// ── TechnicianPickerDialog ───────────────────────────────────────────────────

class TechnicianPickerDialog extends StatefulWidget {
  const TechnicianPickerDialog({
    super.key,
    required this.technicians,
    this.selected,
  });

  final List<ProfileModel> technicians;
  final ProfileModel? selected;

  @override
  State<TechnicianPickerDialog> createState() => TechnicianPickerDialogState();
}

class TechnicianPickerDialogState extends State<TechnicianPickerDialog> {
  String _query = '';
  final _ctrl = TextEditingController();

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  List<ProfileModel> get _filtered {
    if (_query.isEmpty) return widget.technicians;
    final q = _query.toLowerCase();
    return widget.technicians.where((p) {
      return (p.fullName ?? '').toLowerCase().contains(q) ||
          (p.email ?? '').toLowerCase().contains(q);
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      backgroundColor: AppColors.surfaceContainerLowest,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      title: Text(
        'Teknisyen Seç',
        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
          fontSize: 18,
          fontWeight: FontWeight.w700,
        ),
      ),
      contentPadding: const EdgeInsets.fromLTRB(0, 12, 0, 0),
      content: SizedBox(
        width: double.maxFinite,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: TextField(
                controller: _ctrl,
                autofocus: true,
                decoration: InputDecoration(
                  hintText: 'Ad veya e-posta ara...',
                  prefixIcon: const Icon(
                    Icons.search,
                    color: AppColors.outline,
                  ),
                  filled: true,
                  fillColor: AppColors.surfaceContainer,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10),
                    borderSide: BorderSide.none,
                  ),
                  contentPadding: const EdgeInsets.symmetric(vertical: 10),
                ),
                onChanged: (v) => setState(() => _query = v),
              ),
            ),
            const SizedBox(height: AppSpacing.sm),
            if (widget.technicians.isEmpty)
              Padding(
                padding: EdgeInsets.all(AppSpacing.lg),
                child: Text(
                  'Henüz kayıtlı teknisyen yok.',
                  style: Theme.of(
                    context,
                  ).textTheme.bodyMedium?.copyWith(color: AppColors.outline),
                ),
              )
            else
              Flexible(
                child: ListView.builder(
                  itemCount: _filtered.length,
                  itemBuilder: (_, i) {
                    final p = _filtered[i];
                    final isSelected = widget.selected?.id == p.id;
                    return ListTile(
                      leading: CircleAvatar(
                        backgroundColor: isSelected
                            ? AppColors.primary
                            : AppColors.surfaceContainer,
                        radius: 18,
                        child: Text(
                          p.initials,
                          style: Theme.of(context).textTheme.bodyMedium
                              ?.copyWith(
                                fontSize: 13,
                                fontWeight: FontWeight.w700,
                                color: isSelected
                                    ? Colors.white
                                    : AppColors.onSurface,
                              ),
                        ),
                      ),
                      title: Text(
                        p.displayName,
                        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          fontWeight: FontWeight.w600,
                          color: isSelected
                              ? AppColors.primary
                              : AppColors.onSurface,
                        ),
                      ),
                      subtitle: p.phone != null
                          ? Text(
                              p.phone!,
                              style: Theme.of(context).textTheme.bodyMedium
                                  ?.copyWith(
                                    fontSize: 12,
                                    color: AppColors.outline,
                                  ),
                            )
                          : null,
                      trailing: isSelected
                          ? const Icon(
                              Icons.check_circle,
                              color: AppColors.primary,
                            )
                          : null,
                      onTap: () => Navigator.pop(context, p),
                    );
                  },
                ),
              ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: Text('Vazgeç'),
        ),
      ],
    );
  }
}
