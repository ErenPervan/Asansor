import 'package:flutter/material.dart';
import 'package:asansor/core/theme/app_spacing.dart';
import 'calendar_helpers.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/widgets/section_label.dart';
import '../../../elevator/models/elevator_model.dart';
import '../../../elevator/providers/elevator_providers.dart';
import '../../models/profile_model.dart';
import '../../providers/admin_providers.dart';
import '../../providers/profile_providers.dart';
import '../../../../core/enums/app_enums.dart';
import 'calendar_pickers.dart';

// ── AssignTaskSheet ──────────────────────────────────────────────────────────

class AssignTaskSheet extends ConsumerStatefulWidget {
  const AssignTaskSheet({super.key, required this.preselectedDate});
  final DateTime preselectedDate;

  @override
  ConsumerState<AssignTaskSheet> createState() => AssignTaskSheetState();
}

class AssignTaskSheetState extends ConsumerState<AssignTaskSheet> {
  ElevatorModel? _selectedElevator;
  ProfileModel? _selectedTechnician;
  late DateTime _date;
  late TimeOfDay _time;
  String _priority = 'normal';
  final _notesCtrl = TextEditingController();
  final _formKey = GlobalKey<FormState>();

  @override
  void initState() {
    super.initState();
    final now = DateTime.now();
    _date = widget.preselectedDate;
    _time = TimeOfDay(hour: now.hour, minute: now.minute);
  }

  @override
  void dispose() {
    _notesCtrl.dispose();
    super.dispose();
  }

  String get _formattedDate =>
      '${_date.day.toString().padLeft(2, '0')}/${_date.month.toString().padLeft(2, '0')}/${_date.year}';

  String get _formattedTime =>
      '${_time.hour.toString().padLeft(2, '0')}:${_time.minute.toString().padLeft(2, '0')}';

  DateTime get _scheduledDateTime =>
      DateTime(_date.year, _date.month, _date.day, _time.hour, _time.minute);

  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _date,
      firstDate: DateTime.now().subtract(const Duration(days: 1)),
      lastDate: DateTime.now().add(const Duration(days: 365)),
      builder: (ctx, child) => Theme(
        data: Theme.of(ctx).copyWith(
          colorScheme: const ColorScheme.light(primary: AppColors.primary),
        ),
        child: child!,
      ),
    );
    if (picked != null) setState(() => _date = picked);
  }

  Future<void> _pickTime() async {
    final picked = await showTimePicker(
      context: context,
      initialTime: _time,
      builder: (ctx, child) => Theme(
        data: Theme.of(ctx).copyWith(
          colorScheme: const ColorScheme.light(primary: AppColors.primary),
        ),
        child: child!,
      ),
    );
    if (picked != null) setState(() => _time = picked);
  }

  Future<void> _pickElevator(List<ElevatorModel> elevators) async {
    final result = await showDialog<ElevatorModel>(
      context: context,
      builder: (_) => ElevatorPickerDialog(
        elevators: elevators,
        selected: _selectedElevator,
      ),
    );
    if (result != null) setState(() => _selectedElevator = result);
  }

  Future<void> _pickTechnician(List<ProfileModel> techs) async {
    final result = await showDialog<ProfileModel>(
      context: context,
      builder: (_) => TechnicianPickerDialog(
        technicians: techs,
        selected: _selectedTechnician,
      ),
    );
    if (result != null) setState(() => _selectedTechnician = result);
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    if (_selectedElevator == null || _selectedTechnician == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Lütfen asansör ve teknisyen seçin.'),
          backgroundColor: AppColors.error,
        ),
      );
      return;
    }

    await ref
        .read(scheduleControllerProvider.notifier)
        .assignTask(
          elevatorId: _selectedElevator!.id,
          technicianId: _selectedTechnician!.id,
          scheduledDate: _scheduledDateTime,
          notes: _notesCtrl.text.trim().isEmpty ? null : _notesCtrl.text.trim(),
          priority: _priority,
        );

    if (!mounted) return;
    final ctrl = ref.read(scheduleControllerProvider);
    if (ctrl.hasError) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(ctrl.error.toString().replaceFirst('Exception: ', '')),
          backgroundColor: AppColors.error,
        ),
      );
    } else {
      Navigator.pop(context);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Görev başarıyla atandı.'),
          backgroundColor: AppColors.success,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final elevatorsAsync = ref.watch(elevatorsProvider);
    final techsAsync = ref.watch(profilesByRoleProvider(UserRole.technician));
    final isSubmitting = ref.watch(scheduleControllerProvider).isLoading;

    return DraggableScrollableSheet(
      initialChildSize: 0.92,
      minChildSize: 0.6,
      maxChildSize: 0.95,
      expand: false,
      builder: (_, scrollCtrl) => Container(
        decoration: const BoxDecoration(
          color: AppColors.surfaceContainerLowest,
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        ),
        child: Column(
          children: [
            // Handle
            Container(
              margin: const EdgeInsets.only(top: 12),
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: AppColors.outlineVariant,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 20, 24, 4),
              child: Row(
                children: [
                  Text(
                    'Yeni Görev Ata',
                    style: Theme.of(context).textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.w800,
                      color: AppThemeColors.of(context).onSurface,
                    ),
                  ),
                  const Spacer(),
                  IconButton(
                    onPressed: () => Navigator.pop(context),
                    icon: const Icon(Icons.close),
                    color: AppColors.outline,
                  ),
                ],
              ),
            ),
            const Divider(height: 1, color: AppColors.outlineVariant),
            Expanded(
              child: SingleChildScrollView(
                controller: scrollCtrl,
                padding: const EdgeInsets.all(AppSpacing.lg),
                child: Form(
                  key: _formKey,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // ── Elevator picker ─────────────────────────────────
                      SectionLabel(
                        icon: Icons.elevator_outlined,
                        label: 'Asansör',
                        color: AppColors.primary,
                        iconSize: 15,
                        gap: 6,
                        textStyle: Theme.of(context).textTheme.titleSmall
                            ?.copyWith(
                              fontWeight: FontWeight.w700,
                              letterSpacing: 0.2,
                            ),
                      ),
                      const SizedBox(height: AppSpacing.sm),
                      PickerField(
                        hint: 'Asansör seçin...',
                        value: _selectedElevator?.buildingName,
                        icon: Icons.business_outlined,
                        onTap: elevatorsAsync.valueOrNull == null
                            ? null
                            : () => _pickElevator(elevatorsAsync.value!),
                        isLoading: elevatorsAsync.isLoading,
                        hasError: _selectedElevator == null,
                      ),

                      const SizedBox(height: 20),

                      // ── Technician picker ────────────────────────────────
                      SectionLabel(
                        icon: Icons.engineering_outlined,
                        label: 'Teknisyen',
                        color: AppColors.primary,
                        iconSize: 15,
                        gap: 6,
                        textStyle: Theme.of(context).textTheme.titleSmall
                            ?.copyWith(
                              fontWeight: FontWeight.w700,
                              letterSpacing: 0.2,
                            ),
                      ),
                      const SizedBox(height: AppSpacing.sm),
                      PickerField(
                        hint: 'Teknisyen seçin...',
                        value: _selectedTechnician?.displayName,
                        icon: Icons.person_outline,
                        onTap: techsAsync.valueOrNull == null
                            ? null
                            : () => _pickTechnician(techsAsync.value!),
                        isLoading: techsAsync.isLoading,
                        hasError: _selectedTechnician == null,
                      ),

                      const SizedBox(height: 20),

                      // ── Date & Time pickers ──────────────────────────────
                      SectionLabel(
                        icon: Icons.calendar_today_outlined,
                        label: 'Tarih ve Saat',
                        color: AppColors.primary,
                        iconSize: 15,
                        gap: 6,
                        textStyle: Theme.of(context).textTheme.titleSmall
                            ?.copyWith(
                              fontWeight: FontWeight.w700,
                              letterSpacing: 0.2,
                            ),
                      ),
                      const SizedBox(height: AppSpacing.sm),
                      Row(
                        children: [
                          Expanded(
                            child: PickerField(
                              hint: 'Tarih',
                              value: _formattedDate,
                              icon: Icons.today_outlined,
                              onTap: _pickDate,
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: PickerField(
                              hint: 'Saat',
                              value: _formattedTime,
                              icon: Icons.access_time_outlined,
                              onTap: _pickTime,
                            ),
                          ),
                        ],
                      ),

                      const SizedBox(height: 20),

                      // ── Priority selector ────────────────────────────────
                      SectionLabel(
                        icon: Icons.flag_outlined,
                        label: 'Öncelik',
                        color: AppColors.primary,
                        iconSize: 15,
                        gap: 6,
                        textStyle: Theme.of(context).textTheme.titleSmall
                            ?.copyWith(
                              fontWeight: FontWeight.w700,
                              letterSpacing: 0.2,
                            ),
                      ),
                      const SizedBox(height: 10),
                      PrioritySelector(
                        selected: _priority,
                        onChanged: (p) => setState(() => _priority = p),
                      ),

                      const SizedBox(height: 20),

                      // ── Notes ────────────────────────────────────────────
                      SectionLabel(
                        icon: Icons.notes_outlined,
                        label: 'Notlar (İsteğe Bağlı)',
                        color: AppColors.primary,
                        iconSize: 15,
                        gap: 6,
                        textStyle: Theme.of(context).textTheme.titleSmall
                            ?.copyWith(
                              fontWeight: FontWeight.w700,
                              letterSpacing: 0.2,
                            ),
                      ),
                      const SizedBox(height: AppSpacing.sm),
                      TextFormField(
                        controller: _notesCtrl,
                        maxLines: 3,
                        decoration: InputDecoration(
                          hintText:
                              'Görev hakkında ek bilgi veya talimatlar...',
                          hintStyle: Theme.of(context).textTheme.bodyMedium
                              ?.copyWith(color: AppColors.outline),
                          filled: true,
                          fillColor: AppColors.surfaceContainer,
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: BorderSide.none,
                          ),
                          enabledBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: const BorderSide(
                              color: AppColors.outlineVariant,
                              width: 1,
                            ),
                          ),
                          focusedBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: const BorderSide(
                              color: AppColors.primary,
                              width: 1.5,
                            ),
                          ),
                        ),
                      ),

                      const SizedBox(height: AppSpacing.xl),

                      // ── Submit button ────────────────────────────────────
                      SizedBox(
                        width: double.infinity,
                        height: 52,
                        child: FilledButton.icon(
                          onPressed: isSubmitting ? null : _submit,
                          style: FilledButton.styleFrom(
                            backgroundColor: AppColors.error,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(14),
                            ),
                          ),
                          icon: isSubmitting
                              ? const SizedBox(
                                  width: 18,
                                  height: 18,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                    color: Colors.white,
                                  ),
                                )
                              : const Icon(Icons.assignment_turned_in_outlined),
                          label: Text(
                            isSubmitting ? 'Atanıyor...' : 'Görevi Ata',
                            style: Theme.of(context).textTheme.titleSmall
                                ?.copyWith(fontWeight: FontWeight.w700),
                          ),
                        ),
                      ),
                      const SizedBox(height: AppSpacing.lg),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ── PrioritySelector ─────────────────────────────────────────────────────────

// ── PrioritySelector ─────────────────────────────────────────────────────────

class PrioritySelector extends StatelessWidget {
  const PrioritySelector({
    super.key,
    required this.selected,
    required this.onChanged,
  });

  final String selected;
  final ValueChanged<String> onChanged;

  static const _priorities = [
    ('low', 'Düşük', Icons.arrow_downward_rounded),
    ('normal', 'Normal', Icons.remove_rounded),
    ('high', 'Yüksek', Icons.arrow_upward_rounded),
    ('emergency', 'Acil', Icons.warning_amber_rounded),
  ];

  @override
  Widget build(BuildContext context) {
    return Row(
      children: _priorities.map((entry) {
        final (value, label, icon) = entry;
        final isSelected = selected == value;
        final color = getPriorityColor(value);
        return Expanded(
          child: Padding(
            padding: const EdgeInsets.only(right: 8),
            child: GestureDetector(
              onTap: () => onChanged(value),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 150),
                padding: const EdgeInsets.symmetric(vertical: 10),
                decoration: BoxDecoration(
                  color: isSelected
                      ? color.withValues(alpha: 0.12)
                      : AppColors.surfaceContainer,
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(
                    color: isSelected ? color : AppColors.outlineVariant,
                    width: isSelected ? 1.5 : 1,
                  ),
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      icon,
                      size: 18,
                      color: isSelected ? color : AppColors.outline,
                    ),
                    const SizedBox(height: 4),
                    Text(
                      label,
                      style: Theme.of(context).textTheme.labelSmall?.copyWith(
                        fontWeight: isSelected
                            ? FontWeight.w700
                            : FontWeight.w500,
                        color: isSelected ? color : AppColors.outline,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        );
      }).toList(),
    );
  }
}

// ── PickerField ──────────────────────────────────────────────────────────────

// ── PickerField ──────────────────────────────────────────────────────────────

class PickerField extends StatelessWidget {
  const PickerField({
    super.key,
    required this.hint,
    required this.icon,
    required this.onTap,
    this.value,
    this.isLoading = false,
    this.hasError = false,
  });

  final String hint;
  final String? value;
  final IconData icon;
  final VoidCallback? onTap;
  final bool isLoading;
  final bool hasError;

  @override
  Widget build(BuildContext context) {
    final bool hasValue = value != null;
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
        decoration: BoxDecoration(
          color: AppColors.surfaceContainer,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: hasValue
                ? AppColors.primary.withValues(alpha: 0.5)
                : AppColors.outlineVariant,
            width: hasValue ? 1.5 : 1,
          ),
        ),
        child: Row(
          children: [
            Icon(
              icon,
              size: 18,
              color: hasValue ? AppColors.primary : AppColors.outline,
            ),
            const SizedBox(width: 10),
            Expanded(
              child: isLoading
                  ? const SizedBox(height: 14, child: LinearProgressIndicator())
                  : Text(
                      hasValue ? value! : hint,
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        fontWeight: hasValue
                            ? FontWeight.w600
                            : FontWeight.w400,
                        color: hasValue
                            ? AppColors.onSurface
                            : AppColors.outline,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
            ),
            Icon(
              Icons.arrow_drop_down_rounded,
              color: hasValue ? AppColors.primary : AppColors.outline,
            ),
          ],
        ),
      ),
    );
  }
}

// ── ElevatorPickerDialog ─────────────────────────────────────────────────────
