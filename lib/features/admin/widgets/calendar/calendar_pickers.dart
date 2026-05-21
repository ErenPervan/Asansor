import 'package:flutter/material.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../elevator/models/elevator_model.dart';
import '../../models/profile_model.dart';

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
      title: const Text(
        'Asansör Seç',
        style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
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
            const SizedBox(height: 8),
            Flexible(
              child: ListView.builder(
                shrinkWrap: true,
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
                      style: TextStyle(
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
                            style: const TextStyle(
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
          child: const Text('Vazgeç'),
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
      title: const Text(
        'Teknisyen Seç',
        style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
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
            const SizedBox(height: 8),
            if (widget.technicians.isEmpty)
              const Padding(
                padding: EdgeInsets.all(24),
                child: Text(
                  'Henüz kayıtlı teknisyen yok.',
                  style: TextStyle(color: AppColors.outline),
                ),
              )
            else
              Flexible(
                child: ListView.builder(
                  shrinkWrap: true,
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
                          style: TextStyle(
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
                        style: TextStyle(
                          fontWeight: FontWeight.w600,
                          color: isSelected
                              ? AppColors.primary
                              : AppColors.onSurface,
                        ),
                      ),
                      subtitle: p.phone != null
                          ? Text(
                              p.phone!,
                              style: const TextStyle(
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
          child: const Text('Vazgeç'),
        ),
      ],
    );
  }
}
