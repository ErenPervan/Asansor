import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:go_router/go_router.dart';

import '../../elevator/models/elevator_model.dart';

import '../../elevator/providers/elevator_providers.dart';

import '../models/profile_model.dart';

import '../providers/admin_providers.dart';
import '../providers/profile_providers.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/input_decorations.dart';
import '../../../core/widgets/section_label.dart';
import '../../../core/constants/app_durations.dart';
// â”€â”€ AssignView â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€

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

  // â”€â”€ Date / time pickers â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€

  Future<void> _pickDate() async {
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: _selectedDate ?? now,
      firstDate: now,
      lastDate: now.add(const Duration(days: 365)),
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: const ColorScheme.light(
              primary: AppColors.primary,
              onPrimary: Colors.white,
            ),
          ),
          child: child!,
        );
      },
    );
    if (picked != null) setState(() => _selectedDate = picked);
  }

  Future<void> _pickTime() async {
    final picked = await showTimePicker(
      context: context,
      initialTime: _selectedTime ?? TimeOfDay.now(),
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: const ColorScheme.light(
              primary: AppColors.primary,
              onPrimary: Colors.white,
            ),
          ),
          child: child!,
        );
      },
    );
    if (picked != null) setState(() => _selectedTime = picked);
  }

  String get _dateLabel {
    if (_selectedDate == null) return 'Tarih SeÃ§';
    final d = _selectedDate!;
    return '${d.day.toString().padLeft(2, '0')}/${d.month.toString().padLeft(2, '0')}/${d.year}';
  }

  String get _timeLabel {
    if (_selectedTime == null) return 'Saat SeÃ§';
    return '${_selectedTime!.hour.toString().padLeft(2, '0')}:${_selectedTime!.minute.toString().padLeft(2, '0')}';
  }

  // â”€â”€ Submit â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€

  Future<void> _submit() async {
    if (!(_formKey.currentState?.validate() ?? false)) return;
    if (_selectedElevator == null) {
      _showSnack('LÃ¼tfen bir asansÃ¶r seÃ§in.', isError: true);
      return;
    }
    if (_selectedTechnician == null) {
      _showSnack('LÃ¼tfen bir teknisyen seÃ§in.', isError: true);
      return;
    }
    if (_selectedDate == null || _selectedTime == null) {
      _showSnack('LÃ¼tfen tarih ve saati seÃ§in.', isError: true);
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
      _showSnack('GÃ¶rev baÅŸarÄ±yla atandÄ±!');
      await HapticFeedback.lightImpact();
      if (mounted) context.pop();
    }
  }

  void _showSnack(String message, {bool isError = false}) {
    if (!mounted) return;
    if (isError) {
      unawaited(HapticFeedback.heavyImpact());
    }
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: isError ? AppColors.error : AppColors.primary,
        behavior: SnackBarBehavior.floating,
        duration: isError
            ? AppDurations.snackBarError
            : AppDurations.snackBarSuccess,
      ),
    );
  }

  // â”€â”€ Build â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€

  @override
  Widget build(BuildContext context) {
    final elevatorsAsync = ref.watch(elevatorsProvider);
    final techniciansAsync = ref.watch(profilesByRoleProvider('technician'));
    final controllerState = ref.watch(scheduleControllerProvider);
    final isLoading = controllerState.isLoading;

    return PopScope(
      canPop: !isLoading,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop && isLoading) {
          _showSnack(
            'LÃ¼tfen iÅŸlem tamamlanana kadar bekleyin.',
            isError: true,
          );
        }
      },
      child: Scaffold(
        backgroundColor: AppColors.background,
        appBar: AppBar(
          backgroundColor: AppColors.primary,
          foregroundColor: Colors.white,
          elevation: 0,
          title: const Text(
            'GÃ¶rev Ata',
            style: TextStyle(fontWeight: FontWeight.w700, letterSpacing: -0.3),
          ),
        ),
        body: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // â”€â”€ Elevator Selector â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€
                const SectionLabel(
                  icon: Icons.elevator_outlined,
                  label: 'AsansÃ¶r SeÃ§',
                ),
                const SizedBox(height: 12),
                elevatorsAsync.when(
                  loading: () => const Center(
                    child: CircularProgressIndicator(color: AppColors.primary),
                  ),
                  error: (e, _) => _InlineError(
                    message: e.toString().replaceFirst('Exception: ', ''),
                  ),
                  data: (elevators) {
                    if (elevators.isEmpty) {
                      return const _InlineError(
                        message: 'KayÄ±tlÄ± asansÃ¶r bulunamadÄ±.',
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

                // â”€â”€ Technician UUID â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€
                const SectionLabel(
                  icon: Icons.person_search_outlined,
                  label: 'Teknisyen SeÃ§',
                ),
                const SizedBox(height: 12),
                techniciansAsync.when(
                  loading: () => const Center(
                    child: Padding(
                      padding: EdgeInsets.symmetric(vertical: 12),
                      child: CircularProgressIndicator(
                        color: AppColors.primary,
                      ),
                    ),
                  ),
                  error: (e, _) => _InlineError(
                    message: e.toString().replaceFirst('Exception: ', ''),
                  ),
                  data: (techs) {
                    if (techs.isEmpty) {
                      return const _InlineError(
                        message: 'Teknisyen bulunamadÄ±.',
                      );
                    }

                    return DropdownButtonFormField<ProfileModel>(
                      initialValue: _selectedTechnician,
                      decoration: appInputDecoration(
                        hint: 'Teknisyen seÃ§in...',
                        helper:
                            'Teknisyen seÃ§ildiÄŸinde UUID otomatik yazÄ±lÄ±r.',
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
                                    style: const TextStyle(
                                      fontWeight: FontWeight.w600,
                                      color: AppColors.onSurface,
                                    ),
                                  ),
                                  if (t.email != null && t.email!.isNotEmpty)
                                    Text(
                                      t.email!,
                                      style: const TextStyle(
                                        fontSize: 12,
                                        color: AppColors.onSurfaceVariant,
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
                          ? 'Teknisyen seÃ§in.'
                          : null,
                    );
                  },
                ),

                const SizedBox(height: 28),

                // â”€â”€ Date & Time â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€
                const SectionLabel(
                  icon: Icons.event_outlined,
                  label: 'Tarih ve Saat',
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

                // â”€â”€ Notes (optional) â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€
                const SectionLabel(
                  icon: Icons.notes_outlined,
                  label: 'Notlar (Ä°steÄŸe BaÄŸlÄ±)',
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: _notesController,
                  maxLines: 4,
                  decoration: appInputDecoration(
                    hint: 'BakÄ±m ile ilgili ek notlar...',
                  ),
                ),

                const SizedBox(height: 40),

                // â”€â”€ Submit Button â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€
                SizedBox(
                  width: double.infinity,
                  height: 56,
                  child: FilledButton(
                    onPressed: isLoading ? null : _submit,
                    style: FilledButton.styleFrom(
                      backgroundColor: AppColors.primary,
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
                        : const Text(
                            'GÃ¶revi Ata',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                  ),
                ),
                const SizedBox(height: 24),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// â”€â”€ Elevator Selector â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€

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
    return Container(
      decoration: BoxDecoration(
        color: AppColors.surfaceContainerLowest,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: AppColors.outlineVariant.withValues(alpha: 0.5),
        ),
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<ElevatorModel>(
          value: selected,
          hint: const Padding(
            padding: EdgeInsets.symmetric(horizontal: 16),
            child: Text(
              'AsansÃ¶r seÃ§in...',
              style: TextStyle(color: AppColors.outline),
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
                          style: const TextStyle(
                            fontWeight: FontWeight.w600,
                            color: AppColors.onSurface,
                          ),
                        ),
                        if (e.address != null)
                          Text(
                            e.address!,
                            style: const TextStyle(
                              fontSize: 12,
                              color: AppColors.outline,
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

// â”€â”€ Sub-widgets â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€

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
    return Material(
      color: hasValue
          ? AppColors.primary.withValues(alpha: 0.07)
          : AppColors.surfaceContainerLowest,
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
                  ? AppColors.primary
                  : AppColors.outlineVariant.withValues(alpha: 0.5),
              width: hasValue ? 1.5 : 1,
            ),
          ),
          child: Row(
            children: [
              Icon(
                icon,
                size: 18,
                color: hasValue
                    ? AppColors.primary
                    : AppColors.onSurfaceVariant,
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  label,
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: hasValue ? FontWeight.w600 : FontWeight.w400,
                    color: hasValue
                        ? AppColors.primary
                        : AppColors.onSurfaceVariant,
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
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.errorContainer,
        borderRadius: BorderRadius.circular(10),
      ),
      child: Row(
        children: [
          const Icon(
            Icons.error_outline,
            color: AppColors.onErrorContainer,
            size: 18,
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              message,
              style: const TextStyle(
                color: AppColors.onErrorContainer,
                fontSize: 13,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
