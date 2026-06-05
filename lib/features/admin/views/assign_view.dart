import 'dart:async';
import 'package:flutter/material.dart';
import 'package:asansor/core/theme/app_spacing.dart';
import 'package:flutter/services.dart';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:go_router/go_router.dart';

import '../../elevator/models/elevator_model.dart';

import '../../elevator/providers/elevator_providers.dart';

import '../models/profile_model.dart';

import '../providers/admin_providers.dart';
import '../providers/profile_providers.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/enums/app_enums.dart';
import '../../../core/theme/input_decorations.dart';
import '../../../core/widgets/app_form_field.dart';
import '../../../core/widgets/app_section_header.dart';
import '../../../core/constants/app_durations.dart';
// ── AssignView ────────────────────────────────────────────────────────────────

/// Screen that allows a manager/admin to create a new maintenance schedule:
///  1. Select an elevator from the registered list.
///  2. Enter the technician's user UUID.
///  3. Pick a date and time.
///  4. Optionally add notes.
class AssignView extends ConsumerStatefulWidget {
  const AssignView({super.key});

  @override
  ConsumerState<AssignView> createState() => _AssignViewState();
}

class _AssignViewState extends ConsumerState<AssignView> {
  final _formKey = GlobalKey<FormState>();
  final _technicianIdController = TextEditingController();
  final _notesController = TextEditingController();

  ElevatorModel? _selectedElevator;
  ProfileModel? _selectedTechnician;
  DateTime? _selectedDate;
  TimeOfDay? _selectedTime;

  @override
  void dispose() {
    _technicianIdController.dispose();
    _notesController.dispose();
    super.dispose();
  }

  // ── Date / time pickers ───────────────────────────────────────────────────

  Future<void> _pickDate() async {
    final colors = AppThemeColors.of(context);
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: _selectedDate ?? now,
      firstDate: now,
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
    if (_selectedDate == null) return 'Tarih Seç';
    final d = _selectedDate!;
    return '${d.day.toString().padLeft(2, '0')}/${d.month.toString().padLeft(2, '0')}/${d.year}';
  }

  String get _timeLabel {
    if (_selectedTime == null) return 'Saat Seç';
    return '${_selectedTime!.hour.toString().padLeft(2, '0')}:${_selectedTime!.minute.toString().padLeft(2, '0')}';
  }

  // ── Submit ────────────────────────────────────────────────────────────────

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
          technicianId: _technicianIdController.text.trim(),
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
    } else {
      _showSnack('Görev başarıyla atandı!');
      await HapticFeedback.lightImpact();
      if (mounted) context.pop();
    }
  }

  void _showSnack(String message, {bool isError = false}) {
    if (!mounted) return;
    if (isError) {
      unawaited(HapticFeedback.heavyImpact());
    }
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

  // ── Build ─────────────────────────────────────────────────────────────────

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
          backgroundColor: colors.primary,
          foregroundColor: colors.surface,
          elevation: 0,
          title: Text(
            'Görev Ata',
            style: textTheme.titleLarge?.copyWith(
              fontWeight: FontWeight.w700,
              letterSpacing: 0.0,
              color: colors.surface,
            ),
          ),
        ),
        body: SingleChildScrollView(
          padding: const EdgeInsets.all(AppSpacing.lg),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // ── Elevator Selector ───────────────────────────────────────
                const AppSectionHeader(
                  icon: Icons.elevator_outlined,
                  title: 'Asansör Seç',
                ),
                const SizedBox(height: 12),
                elevatorsAsync.when(
                  loading: () => Center(
                    child: CircularProgressIndicator(color: colors.primary),
                  ),
                  error: (e, _) => _InlineError(
                    message: e.toString().replaceFirst('Exception: ', ''),
                  ),
                  data: (elevators) {
                    if (elevators.isEmpty) {
                      return const _InlineError(
                        message: 'Kayıtlı asansör bulunamadı.',
                      );
                    }
                    return _ElevatorSelector(
                      elevators: elevators,
                      selected: _selectedElevator,
                      onSelected: (e) => setState(() => _selectedElevator = e),
                    );
                  },
                ),

                const SizedBox(height: 28),

                // ── Technician UUID ─────────────────────────────────────────
                const AppSectionHeader(
                  icon: Icons.person_search_outlined,
                  title: 'Teknisyen Seç',
                ),
                const SizedBox(height: 12),
                techniciansAsync.when(
                  loading: () => Center(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      child: CircularProgressIndicator(color: colors.primary),
                    ),
                  ),
                  error: (e, _) => _InlineError(
                    message: e.toString().replaceFirst('Exception: ', ''),
                  ),
                  data: (techs) {
                    if (techs.isEmpty) {
                      return const _InlineError(
                        message: 'Teknisyen bulunamadı.',
                      );
                    }

                    return DropdownButtonFormField<ProfileModel>(
                      initialValue: _selectedTechnician,
                      decoration: appInputDecoration(
                        hint: 'Teknisyen seçin...',
                        helper: 'Teknisyen seçildiğinde UUID otomatik yazılır.',
                      ),
                      icon: const Icon(Icons.expand_more),
                      isExpanded: true,
                      items: techs
                          .map(
                            (t) => DropdownMenuItem<ProfileModel>(
                              value: t,
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Text(
                                    t.displayName,
                                    style: textTheme.labelLarge?.copyWith(
                                      fontWeight: FontWeight.w600,
                                      color: colors.onSurface,
                                    ),
                                  ),
                                  if (t.email != null && t.email!.isNotEmpty)
                                    Text(
                                      t.email!,
                                      style: textTheme.labelSmall?.copyWith(
                                        color: colors.onSurfaceVariant,
                                      ),
                                    ),
                                ],
                              ),
                            ),
                          )
                          .toList(),
                      onChanged: isLoading
                          ? null
                          : (tech) {
                              setState(() {
                                _selectedTechnician = tech;
                                _technicianIdController.text = tech?.id ?? '';
                              });
                            },
                      validator: (_) => _selectedTechnician == null
                          ? 'Teknisyen seçin.'
                          : null,
                    );
                  },
                ),

                const SizedBox(height: 28),

                // ── Date & Time ───────────────────────────────────────────────
                const AppSectionHeader(
                  icon: Icons.event_outlined,
                  title: 'Tarih ve Saat',
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: _PickerButton(
                        icon: Icons.calendar_today_outlined,
                        label: _dateLabel,
                        hasValue: _selectedDate != null,
                        onTap: _pickDate,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: _PickerButton(
                        icon: Icons.access_time_outlined,
                        label: _timeLabel,
                        hasValue: _selectedTime != null,
                        onTap: _pickTime,
                      ),
                    ),
                  ],
                ),

                const SizedBox(height: 28),

                // ── Notes (optional) ──────────────────────────────────────────
                const AppSectionHeader(
                  icon: Icons.notes_outlined,
                  title: 'Notlar (İsteğe Bağlı)',
                ),
                const SizedBox(height: 12),
                AppFormField(
                  controller: _notesController,
                  maxLines: 4,
                  label: '',
                  hint: 'Bakım ile ilgili ek notlar...',
                ),

                const SizedBox(height: 40),

                // ── Submit Button ─────────────────────────────────────────────
                SizedBox(
                  width: double.infinity,
                  height: 56,
                  child: FilledButton(
                    onPressed: isLoading ? null : _submit,
                    style: FilledButton.styleFrom(
                      backgroundColor: colors.primary,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                      ),
                    ),
                    child: isLoading
                        ? const SizedBox(
                            width: 24,
                            height: 24,
                            child: CircularProgressIndicator(
                              color: Colors.white,
                              strokeWidth: 2.5,
                            ),
                          )
                        : Text(
                            'Görevi Ata',
                            style: textTheme.titleSmall?.copyWith(
                              fontWeight: FontWeight.w700,
                              color: colors.surface,
                            ),
                          ),
                  ),
                ),
                const SizedBox(height: AppSpacing.lg),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// ── Elevator Selector ─────────────────────────────────────────────────────────

class _ElevatorSelector extends StatelessWidget {
  const _ElevatorSelector({
    required this.elevators,
    required this.selected,
    required this.onSelected,
  });

  final List<ElevatorModel> elevators;
  final ElevatorModel? selected;
  final ValueChanged<ElevatorModel> onSelected;

  @override
  Widget build(BuildContext context) {
    final colors = AppThemeColors.of(context);
    final textTheme = Theme.of(context).textTheme;

    return Container(
      decoration: BoxDecoration(
        color: colors.surfaceContainerLowest,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: colors.outlineVariant.withValues(alpha: 0.5)),
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<ElevatorModel>(
          value: selected,
          hint: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Text(
              'Asansör seçin...',
              style: textTheme.labelLarge?.copyWith(color: colors.outline),
            ),
          ),
          isExpanded: true,
          borderRadius: BorderRadius.circular(16),
          padding: const EdgeInsets.symmetric(horizontal: 8),
          items: elevators
              .map(
                (e) => DropdownMenuItem<ElevatorModel>(
                  value: e,
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 8),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          e.buildingName,
                          style: textTheme.labelLarge?.copyWith(
                            fontWeight: FontWeight.w600,
                            color: colors.onSurface,
                          ),
                        ),
                        if (e.address != null)
                          Text(
                            e.address!,
                            style: textTheme.labelSmall?.copyWith(
                              color: colors.outline,
                            ),
                          ),
                      ],
                    ),
                  ),
                ),
              )
              .toList(),
          onChanged: (e) {
            if (e != null) onSelected(e);
          },
        ),
      ),
    );
  }
}

// ── Sub-widgets ───────────────────────────────────────────────────────────────

class _PickerButton extends StatelessWidget {
  const _PickerButton({
    required this.icon,
    required this.label,
    required this.hasValue,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final bool hasValue;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final colors = AppThemeColors.of(context);
    final textTheme = Theme.of(context).textTheme;

    return Material(
      color: hasValue
          ? colors.primary.withValues(alpha: 0.07)
          : colors.surfaceContainerLowest,
      borderRadius: BorderRadius.circular(14),
      child: InkWell(
        borderRadius: BorderRadius.circular(14),
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
              color: hasValue
                  ? colors.primary
                  : colors.outlineVariant.withValues(alpha: 0.5),
              width: hasValue ? 1.5 : 1,
            ),
          ),
          child: Row(
            children: [
              Icon(
                icon,
                size: 18,
                color: hasValue ? colors.primary : colors.onSurfaceVariant,
              ),
              const SizedBox(width: AppSpacing.sm),
              Expanded(
                child: Text(
                  label,
                  style: textTheme.labelLarge?.copyWith(
                    fontWeight: hasValue ? FontWeight.w600 : FontWeight.w400,
                    color: hasValue ? colors.primary : colors.onSurfaceVariant,
                  ),
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
        borderRadius: BorderRadius.circular(10),
      ),
      child: Row(
        children: [
          Icon(Icons.error_outline, color: colors.onErrorContainer, size: 18),
          const SizedBox(width: AppSpacing.sm),
          Expanded(
            child: Text(
              message,
              style: textTheme.labelLarge?.copyWith(
                color: colors.onErrorContainer,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
