import 'dart:async';

import 'package:asansor/core/constants/app_durations.dart';
import 'package:asansor/core/enums/app_enums.dart';
import 'package:asansor/core/theme/app_colors.dart';
import 'package:asansor/core/theme/app_spacing.dart';
import 'package:asansor/core/theme/input_decorations.dart';
import 'package:asansor/core/widgets/app_form_field.dart';
import 'package:asansor/features/admin/models/profile_model.dart';
import 'package:asansor/features/admin/providers/admin_providers.dart';
import 'package:asansor/features/admin/providers/profile_providers.dart';
import 'package:asansor/features/elevator/models/elevator_model.dart';
import 'package:asansor/features/elevator/providers/elevator_providers.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

const _panelLine = Color(0xFFE1E8F0);

class AssignView extends ConsumerStatefulWidget {
  const AssignView({super.key});

  @override
  ConsumerState<AssignView> createState() => _AssignViewState();
}

class _AssignViewState extends ConsumerState<AssignView> {
  final _formKey = GlobalKey<FormState>();
  final _notesController = TextEditingController();

  ElevatorModel? _selectedElevator;
  ProfileModel? _selectedTechnician;
  DateTime? _selectedDate;
  TimeOfDay? _selectedTime;

  @override
  void dispose() {
    _notesController.dispose();
    super.dispose();
  }

  Future<void> _pickDate() async {
    final colors = AppThemeColors.of(context);
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: _selectedDate ?? now,
      firstDate: DateTime(now.year, now.month, now.day),
      lastDate: now.add(const Duration(days: 365)),
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: ColorScheme.light(
              primary: colors.primary,
              onPrimary: colors.surface,
            ),
          ),
          child: child!,
        );
      },
    );
    if (picked != null) setState(() => _selectedDate = picked);
  }

  Future<void> _pickTime() async {
    final colors = AppThemeColors.of(context);
    final picked = await showTimePicker(
      context: context,
      initialTime: _selectedTime ?? TimeOfDay.now(),
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: ColorScheme.light(
              primary: colors.primary,
              onPrimary: colors.surface,
            ),
          ),
          child: child!,
        );
      },
    );
    if (picked != null) setState(() => _selectedTime = picked);
  }

  String get _dateLabel {
    if (_selectedDate == null) return 'Tarih seçin';
    return DateFormat('d MMMM y', 'tr_TR').format(_selectedDate!);
  }

  String get _timeLabel {
    if (_selectedTime == null) return 'Saat seçin';
    return '${_selectedTime!.hour.toString().padLeft(2, '0')}:'
        '${_selectedTime!.minute.toString().padLeft(2, '0')}';
  }

  String get _plannedLabel {
    if (_selectedDate == null || _selectedTime == null) {
      return 'Planlama zamanı seçilmedi';
    }
    return '$_dateLabel, $_timeLabel';
  }

  Future<void> _submit() async {
    if (!(_formKey.currentState?.validate() ?? false)) return;
    if (_selectedElevator == null) {
      _showSnack('Lütfen bir asansör seçin.', isError: true);
      return;
    }
    if (_selectedTechnician == null) {
      _showSnack('Lütfen bir teknisyen seçin.', isError: true);
      return;
    }
    if (_selectedDate == null || _selectedTime == null) {
      _showSnack('Lütfen tarih ve saati seçin.', isError: true);
      return;
    }

    final scheduledDateTime = DateTime(
      _selectedDate!.year,
      _selectedDate!.month,
      _selectedDate!.day,
      _selectedTime!.hour,
      _selectedTime!.minute,
    );

    await ref
        .read(scheduleControllerProvider.notifier)
        .assignTask(
          elevatorId: _selectedElevator!.id,
          technicianId: _selectedTechnician!.id,
          scheduledDate: scheduledDateTime,
          notes: _notesController.text.trim().isEmpty
              ? null
              : _notesController.text.trim(),
        );

    final state = ref.read(scheduleControllerProvider);
    if (state.hasError) {
      _showSnack(
        state.error.toString().replaceFirst('Exception: ', ''),
        isError: true,
      );
      return;
    }

    _showSnack('Görev başarıyla atandı.');
    await HapticFeedback.lightImpact();
    if (mounted) context.pop();
  }

  void _showSnack(String message, {bool isError = false}) {
    if (!mounted) return;
    if (isError) unawaited(HapticFeedback.heavyImpact());

    final colors = AppThemeColors.of(context);
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: isError ? colors.error : colors.primary,
        behavior: SnackBarBehavior.floating,
        duration: isError
            ? AppDurations.snackBarError
            : AppDurations.snackBarSuccess,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final colors = AppThemeColors.of(context);
    final textTheme = Theme.of(context).textTheme;
    final elevatorsAsync = ref.watch(elevatorsProvider);
    final techniciansAsync = ref.watch(
      profilesByRoleProvider(UserRole.technician),
    );
    final controllerState = ref.watch(scheduleControllerProvider);
    final isLoading = controllerState.isLoading;

    return PopScope(
      canPop: !isLoading,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop && isLoading) {
          _showSnack('Lütfen işlem tamamlanana kadar bekleyin.', isError: true);
        }
      },
      child: Scaffold(
        backgroundColor: colors.background,
        appBar: AppBar(
          titleSpacing: 20,
          title: Row(
            children: [
              Icon(Icons.elevator_rounded, color: colors.primary),
              const SizedBox(width: 10),
              Text(
                'Asansör',
                style: textTheme.titleMedium?.copyWith(
                  color: colors.primary,
                  fontWeight: FontWeight.w900,
                ),
              ),
            ],
          ),
          actions: [
            Padding(
              padding: const EdgeInsets.only(right: 16),
              child: Row(
                children: [
                  Icon(
                    Icons.manage_accounts_rounded,
                    size: 18,
                    color: colors.onSurfaceVariant,
                  ),
                  const SizedBox(width: 6),
                  Text(
                    'Operasyon Yönetimi',
                    style: textTheme.labelMedium?.copyWith(
                      color: colors.onSurfaceVariant,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
        body: LayoutBuilder(
          builder: (context, constraints) {
            final wide = constraints.maxWidth >= 980;

            return SingleChildScrollView(
              padding: EdgeInsets.fromLTRB(
                wide ? 24 : 16,
                20,
                wide ? 24 : 16,
                36,
              ),
              child: Center(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 1120),
                  child: wide
                      ? Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Expanded(
                              flex: 3,
                              child: _AssignmentFormPanel(
                                formKey: _formKey,
                                elevatorsAsync: elevatorsAsync,
                                techniciansAsync: techniciansAsync,
                                selectedElevator: _selectedElevator,
                                selectedTechnician: _selectedTechnician,
                                selectedDate: _selectedDate,
                                selectedTime: _selectedTime,
                                notesController: _notesController,
                                isLoading: isLoading,
                                dateLabel: _dateLabel,
                                timeLabel: _timeLabel,
                                onElevatorSelected: (value) =>
                                    setState(() => _selectedElevator = value),
                                onTechnicianSelected: (value) =>
                                    setState(() => _selectedTechnician = value),
                                onPickDate: _pickDate,
                                onPickTime: _pickTime,
                                onCancel: () => context.pop(),
                                onSubmit: _submit,
                              ),
                            ),
                            const SizedBox(width: AppSpacing.lg),
                            SizedBox(
                              width: 340,
                              child: _AssignmentSummaryPanel(
                                elevator: _selectedElevator,
                                technician: _selectedTechnician,
                                plannedLabel: _plannedLabel,
                                isLoading: isLoading,
                              ),
                            ),
                          ],
                        )
                      : Column(
                          children: [
                            _AssignmentSummaryPanel(
                              elevator: _selectedElevator,
                              technician: _selectedTechnician,
                              plannedLabel: _plannedLabel,
                              isLoading: isLoading,
                            ),
                            const SizedBox(height: AppSpacing.lg),
                            _AssignmentFormPanel(
                              formKey: _formKey,
                              elevatorsAsync: elevatorsAsync,
                              techniciansAsync: techniciansAsync,
                              selectedElevator: _selectedElevator,
                              selectedTechnician: _selectedTechnician,
                              selectedDate: _selectedDate,
                              selectedTime: _selectedTime,
                              notesController: _notesController,
                              isLoading: isLoading,
                              dateLabel: _dateLabel,
                              timeLabel: _timeLabel,
                              onElevatorSelected: (value) =>
                                  setState(() => _selectedElevator = value),
                              onTechnicianSelected: (value) =>
                                  setState(() => _selectedTechnician = value),
                              onPickDate: _pickDate,
                              onPickTime: _pickTime,
                              onCancel: () => context.pop(),
                              onSubmit: _submit,
                            ),
                          ],
                        ),
                ),
              ),
            );
          },
        ),
      ),
    );
  }
}

class _AssignmentFormPanel extends StatelessWidget {
  const _AssignmentFormPanel({
    required this.formKey,
    required this.elevatorsAsync,
    required this.techniciansAsync,
    required this.selectedElevator,
    required this.selectedTechnician,
    required this.selectedDate,
    required this.selectedTime,
    required this.notesController,
    required this.isLoading,
    required this.dateLabel,
    required this.timeLabel,
    required this.onElevatorSelected,
    required this.onTechnicianSelected,
    required this.onPickDate,
    required this.onPickTime,
    required this.onCancel,
    required this.onSubmit,
  });

  final GlobalKey<FormState> formKey;
  final AsyncValue<List<ElevatorModel>> elevatorsAsync;
  final AsyncValue<List<ProfileModel>> techniciansAsync;
  final ElevatorModel? selectedElevator;
  final ProfileModel? selectedTechnician;
  final DateTime? selectedDate;
  final TimeOfDay? selectedTime;
  final TextEditingController notesController;
  final bool isLoading;
  final String dateLabel;
  final String timeLabel;
  final ValueChanged<ElevatorModel> onElevatorSelected;
  final ValueChanged<ProfileModel?> onTechnicianSelected;
  final VoidCallback onPickDate;
  final VoidCallback onPickTime;
  final VoidCallback onCancel;
  final VoidCallback onSubmit;

  @override
  Widget build(BuildContext context) {
    final colors = AppThemeColors.of(context);
    final textTheme = Theme.of(context).textTheme;

    return Container(
      decoration: BoxDecoration(
        color: colors.surface,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: _panelLine),
        boxShadow: [
          BoxShadow(
            color: colors.primary.withValues(alpha: 0.06),
            blurRadius: 30,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: Form(
        key: formKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(AppSpacing.lg),
              decoration: BoxDecoration(
                color: colors.background,
                borderRadius: const BorderRadius.vertical(
                  top: Radius.circular(8),
                ),
                border: const Border(bottom: BorderSide(color: _panelLine)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Yeni Görev Ata',
                    style: textTheme.headlineSmall?.copyWith(
                      color: colors.primary,
                      fontWeight: FontWeight.w900,
                      letterSpacing: 0,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    'Sahadaki teknisyenlere bakım veya arıza giderme '
                    'görevleri planlayın.',
                    style: textTheme.bodyMedium?.copyWith(
                      color: colors.onSurfaceVariant,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(AppSpacing.lg),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _FieldLabel(
                    icon: Icons.elevator_rounded,
                    label: 'Asansör Seçimi',
                    required: true,
                  ),
                  const SizedBox(height: AppSpacing.sm),
                  elevatorsAsync.when(
                    loading: () => const _InlineLoading(label: 'Asansörler'),
                    error: (e, _) => _InlineError(
                      message: e.toString().replaceFirst('Exception: ', ''),
                    ),
                    data: (elevators) {
                      if (elevators.isEmpty) {
                        return const _InlineError(
                          message: 'Kayıtlı asansör bulunamadı.',
                        );
                      }
                      return _ElevatorDropdown(
                        elevators: elevators,
                        selected: selectedElevator,
                        isLoading: isLoading,
                        onSelected: onElevatorSelected,
                      );
                    },
                  ),
                  const SizedBox(height: AppSpacing.lg),
                  _FieldLabel(
                    icon: Icons.engineering_rounded,
                    label: 'Teknisyen',
                    required: true,
                  ),
                  const SizedBox(height: AppSpacing.sm),
                  techniciansAsync.when(
                    loading: () => const _InlineLoading(label: 'Teknisyenler'),
                    error: (e, _) => _InlineError(
                      message: e.toString().replaceFirst('Exception: ', ''),
                    ),
                    data: (technicians) {
                      if (technicians.isEmpty) {
                        return const _InlineError(
                          message: 'Teknisyen bulunamadı.',
                        );
                      }
                      return _TechnicianDropdown(
                        technicians: technicians,
                        selected: selectedTechnician,
                        isLoading: isLoading,
                        onSelected: onTechnicianSelected,
                      );
                    },
                  ),
                  const SizedBox(height: AppSpacing.lg),
                  Row(
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            _FieldLabel(
                              icon: Icons.calendar_today_rounded,
                              label: 'Tarih',
                              required: true,
                            ),
                            const SizedBox(height: AppSpacing.sm),
                            _PickerButton(
                              icon: Icons.calendar_today_rounded,
                              label: dateLabel,
                              hasValue: selectedDate != null,
                              enabled: !isLoading,
                              onTap: onPickDate,
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: AppSpacing.md),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            _FieldLabel(
                              icon: Icons.schedule_rounded,
                              label: 'Saat',
                              required: true,
                            ),
                            const SizedBox(height: AppSpacing.sm),
                            _PickerButton(
                              icon: Icons.schedule_rounded,
                              label: timeLabel,
                              hasValue: selectedTime != null,
                              enabled: !isLoading,
                              onTap: onPickTime,
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: AppSpacing.lg),
                  _FieldLabel(
                    icon: Icons.notes_rounded,
                    label: 'Notlar',
                    trailing: 'Opsiyonel',
                  ),
                  const SizedBox(height: AppSpacing.sm),
                  AppFormField(
                    controller: notesController,
                    maxLines: 4,
                    label: '',
                    hint: 'Arıza detayı veya bakım talimatları...',
                  ),
                  const SizedBox(height: AppSpacing.lg),
                  Divider(height: 1, color: colors.outlineVariant),
                  const SizedBox(height: AppSpacing.lg),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      TextButton(
                        onPressed: isLoading ? null : onCancel,
                        child: Text(
                          'İptal',
                          style: textTheme.labelLarge?.copyWith(
                            color: colors.primary,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      ),
                      const SizedBox(width: AppSpacing.md),
                      FilledButton.icon(
                        onPressed: isLoading ? null : onSubmit,
                        icon: isLoading
                            ? SizedBox(
                                width: 18,
                                height: 18,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2.4,
                                  color: colors.onPrimary,
                                ),
                              )
                            : const Icon(Icons.add_task_rounded),
                        label: Text(isLoading ? 'Atanıyor' : 'Görev Ata'),
                        style: FilledButton.styleFrom(
                          backgroundColor: colors.primary,
                          foregroundColor: colors.onPrimary,
                          minimumSize: const Size(150, 48),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(8),
                          ),
                        ),
                      ),
                    ],
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

class _AssignmentSummaryPanel extends StatelessWidget {
  const _AssignmentSummaryPanel({
    required this.elevator,
    required this.technician,
    required this.plannedLabel,
    required this.isLoading,
  });

  final ElevatorModel? elevator;
  final ProfileModel? technician;
  final String plannedLabel;
  final bool isLoading;

  @override
  Widget build(BuildContext context) {
    final colors = AppThemeColors.of(context);
    final textTheme = Theme.of(context).textTheme;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(AppSpacing.lg),
      decoration: BoxDecoration(
        color: colors.primary,
        borderRadius: BorderRadius.circular(8),
        boxShadow: [
          BoxShadow(
            color: colors.primary.withValues(alpha: 0.20),
            blurRadius: 30,
            offset: const Offset(0, 12),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.14),
              borderRadius: BorderRadius.circular(8),
            ),
            child: const Icon(
              Icons.task_alt_rounded,
              color: Colors.white,
              size: 26,
            ),
          ),
          const SizedBox(height: AppSpacing.lg),
          Text(
            'Atama Özeti',
            style: textTheme.titleLarge?.copyWith(
              color: Colors.white,
              fontWeight: FontWeight.w900,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            isLoading
                ? 'Görev kaydı oluşturuluyor.'
                : 'Seçimlerinizi kontrol edip görevi teknisyene atayın.',
            style: textTheme.bodyMedium?.copyWith(
              color: Colors.white.withValues(alpha: 0.78),
              fontWeight: FontWeight.w600,
              height: 1.4,
            ),
          ),
          const SizedBox(height: AppSpacing.lg),
          _SummaryItem(
            label: 'Asansör',
            value: elevator?.buildingName ?? 'Seçilmedi',
            icon: Icons.elevator_rounded,
          ),
          _SummaryItem(
            label: 'Teknisyen',
            value: technician?.displayName ?? 'Seçilmedi',
            icon: Icons.engineering_rounded,
          ),
          _SummaryItem(
            label: 'Planlanan Zaman',
            value: plannedLabel,
            icon: Icons.event_rounded,
          ),
        ],
      ),
    );
  }
}

class _SummaryItem extends StatelessWidget {
  const _SummaryItem({
    required this.label,
    required this.value,
    required this.icon,
  });

  final String label;
  final String value;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;

    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(bottom: AppSpacing.sm),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.10),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.white.withValues(alpha: 0.14)),
      ),
      child: Row(
        children: [
          Icon(icon, size: 19, color: Colors.white.withValues(alpha: 0.82)),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: textTheme.labelSmall?.copyWith(
                    color: Colors.white.withValues(alpha: 0.64),
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  value,
                  style: textTheme.bodySmall?.copyWith(
                    color: Colors.white,
                    fontWeight: FontWeight.w800,
                  ),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _ElevatorDropdown extends StatelessWidget {
  const _ElevatorDropdown({
    required this.elevators,
    required this.selected,
    required this.isLoading,
    required this.onSelected,
  });

  final List<ElevatorModel> elevators;
  final ElevatorModel? selected;
  final bool isLoading;
  final ValueChanged<ElevatorModel> onSelected;

  @override
  Widget build(BuildContext context) {
    final colors = AppThemeColors.of(context);

    return DropdownButtonFormField<ElevatorModel>(
      initialValue: selected,
      isExpanded: true,
      icon: Icon(Icons.expand_more_rounded, color: colors.outline),
      decoration: appInputDecoration(
        hint: 'Hedef asansörü seçin',
        prefixIcon: Icon(Icons.elevator_rounded, color: colors.outline),
        fillColor: colors.surfaceContainer,
        radius: 8,
      ),
      items: elevators
          .map(
            (elevator) => DropdownMenuItem<ElevatorModel>(
              value: elevator,
              child: _ElevatorMenuItem(elevator: elevator),
            ),
          )
          .toList(),
      onChanged: isLoading
          ? null
          : (value) {
              if (value != null) onSelected(value);
            },
      validator: (value) => value == null ? 'Asansör seçin.' : null,
    );
  }
}

class _ElevatorMenuItem extends StatelessWidget {
  const _ElevatorMenuItem({required this.elevator});

  final ElevatorModel elevator;

  @override
  Widget build(BuildContext context) {
    final colors = AppThemeColors.of(context);
    final textTheme = Theme.of(context).textTheme;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          elevator.buildingName,
          style: textTheme.labelLarge?.copyWith(
            fontWeight: FontWeight.w800,
            color: colors.onSurface,
          ),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
        if (elevator.address != null && elevator.address!.isNotEmpty)
          Text(
            elevator.address!,
            style: textTheme.labelSmall?.copyWith(
              color: colors.onSurfaceVariant,
              fontWeight: FontWeight.w600,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
      ],
    );
  }
}

class _TechnicianDropdown extends StatelessWidget {
  const _TechnicianDropdown({
    required this.technicians,
    required this.selected,
    required this.isLoading,
    required this.onSelected,
  });

  final List<ProfileModel> technicians;
  final ProfileModel? selected;
  final bool isLoading;
  final ValueChanged<ProfileModel?> onSelected;

  @override
  Widget build(BuildContext context) {
    final colors = AppThemeColors.of(context);

    return DropdownButtonFormField<ProfileModel>(
      initialValue: selected,
      isExpanded: true,
      icon: Icon(Icons.expand_more_rounded, color: colors.outline),
      decoration: appInputDecoration(
        hint: 'Görevlendirilecek teknisyeni seçin',
        helper: 'Teknisyen seçildiğinde görev bu kullanıcıya atanır.',
        prefixIcon: Icon(Icons.engineering_rounded, color: colors.outline),
        fillColor: colors.surfaceContainer,
        radius: 8,
      ),
      items: technicians
          .map(
            (technician) => DropdownMenuItem<ProfileModel>(
              value: technician,
              child: _TechnicianMenuItem(technician: technician),
            ),
          )
          .toList(),
      onChanged: isLoading ? null : onSelected,
      validator: (value) => value == null ? 'Teknisyen seçin.' : null,
    );
  }
}

class _TechnicianMenuItem extends StatelessWidget {
  const _TechnicianMenuItem({required this.technician});

  final ProfileModel technician;

  @override
  Widget build(BuildContext context) {
    final colors = AppThemeColors.of(context);
    final textTheme = Theme.of(context).textTheme;

    return Row(
      children: [
        CircleAvatar(
          radius: 15,
          backgroundColor: colors.primary.withValues(alpha: 0.10),
          child: Text(
            technician.initials,
            style: textTheme.labelSmall?.copyWith(
              color: colors.primary,
              fontWeight: FontWeight.w900,
            ),
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                technician.displayName,
                style: textTheme.labelLarge?.copyWith(
                  fontWeight: FontWeight.w800,
                  color: colors.onSurface,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
              if (technician.email != null && technician.email!.isNotEmpty)
                Text(
                  technician.email!,
                  style: textTheme.labelSmall?.copyWith(
                    color: colors.onSurfaceVariant,
                    fontWeight: FontWeight.w600,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
            ],
          ),
        ),
      ],
    );
  }
}

class _PickerButton extends StatelessWidget {
  const _PickerButton({
    required this.icon,
    required this.label,
    required this.hasValue,
    required this.enabled,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final bool hasValue;
  final bool enabled;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final colors = AppThemeColors.of(context);
    final textTheme = Theme.of(context).textTheme;
    final borderColor = hasValue ? colors.primary : Colors.transparent;

    return Material(
      color: colors.surfaceContainer,
      borderRadius: BorderRadius.circular(8),
      child: InkWell(
        borderRadius: BorderRadius.circular(8),
        onTap: enabled ? onTap : null,
        child: Container(
          constraints: const BoxConstraints(minHeight: 54),
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 13),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(8),
            border: Border.all(
              color: borderColor,
              width: hasValue ? 1.5 : 1,
            ),
          ),
          child: Row(
            children: [
              Icon(
                icon,
                size: 19,
                color: hasValue ? colors.primary : colors.outline,
              ),
              const SizedBox(width: AppSpacing.sm),
              Expanded(
                child: Text(
                  label,
                  style: textTheme.bodyMedium?.copyWith(
                    color: hasValue ? colors.onSurface : colors.outline,
                    fontWeight: FontWeight.w700,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _FieldLabel extends StatelessWidget {
  const _FieldLabel({
    required this.icon,
    required this.label,
    this.required = false,
    this.trailing,
  });

  final IconData icon;
  final String label;
  final bool required;
  final String? trailing;

  @override
  Widget build(BuildContext context) {
    final colors = AppThemeColors.of(context);
    final textTheme = Theme.of(context).textTheme;

    return Row(
      children: [
        Icon(icon, size: 17, color: colors.primary),
        const SizedBox(width: 7),
        Text(
          label,
          style: textTheme.labelLarge?.copyWith(
            color: colors.onSurfaceVariant,
            fontWeight: FontWeight.w900,
          ),
        ),
        if (required) ...[
          const SizedBox(width: 3),
          Text(
            '*',
            style: textTheme.labelLarge?.copyWith(
              color: colors.error,
              fontWeight: FontWeight.w900,
            ),
          ),
        ],
        if (trailing != null) ...[
          const SizedBox(width: 8),
          Text(
            trailing!,
            style: textTheme.labelSmall?.copyWith(
              color: colors.outline,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ],
    );
  }
}

class _InlineLoading extends StatelessWidget {
  const _InlineLoading({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    final colors = AppThemeColors.of(context);

    return Container(
      constraints: const BoxConstraints(minHeight: 54),
      padding: const EdgeInsets.symmetric(horizontal: 14),
      decoration: BoxDecoration(
        color: colors.surfaceContainer,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        children: [
          SizedBox(
            width: 18,
            height: 18,
            child: CircularProgressIndicator(
              strokeWidth: 2.2,
              color: colors.primary,
            ),
          ),
          const SizedBox(width: 10),
          Text(
            '$label yükleniyor',
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
              color: colors.onSurfaceVariant,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }
}

class _InlineError extends StatelessWidget {
  const _InlineError({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    final colors = AppThemeColors.of(context);
    final textTheme = Theme.of(context).textTheme;

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: colors.errorContainer,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        children: [
          Icon(Icons.error_outline_rounded, color: colors.onErrorContainer),
          const SizedBox(width: AppSpacing.sm),
          Expanded(
            child: Text(
              message,
              style: textTheme.labelLarge?.copyWith(
                color: colors.onErrorContainer,
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
