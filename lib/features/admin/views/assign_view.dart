import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../elevator/models/elevator_model.dart';
import '../../elevator/providers/elevator_providers.dart';
import '../providers/admin_providers.dart';

// ── Design tokens ─────────────────────────────────────────────────────────────

const _primary = Color(0xFFB91C1C);
const _error = Color(0xFFDC2626);
const _errorContainer = Color(0xFFFEE2E2);
const _onErrorContainer = Color(0xFF991B1B);
const _surfaceContainerLowest = Colors.white;
const _outlineVariant = Color(0xFFE2E8F0);
const _onSurface = Color(0xFF0F172A);
const _onSurfaceVariant = Color(0xFF475569);
const _outline = Color(0xFF94A3B8);
const _background = Color(0xFFF9FAFB);

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
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: _selectedDate ?? now,
      firstDate: now,
      lastDate: now.add(const Duration(days: 365)),
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme:
                const ColorScheme.light(primary: _primary, onPrimary: Colors.white),
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
            colorScheme:
                const ColorScheme.light(primary: _primary, onPrimary: Colors.white),
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

    await ref.read(scheduleControllerProvider.notifier).assignTask(
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
      if (mounted) context.pop();
    }
  }

  void _showSnack(String message, {bool isError = false}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: isError ? _error : _primary,
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  // ── Build ─────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final elevatorsAsync = ref.watch(elevatorsProvider);
    final controllerState = ref.watch(scheduleControllerProvider);
    final isLoading = controllerState.isLoading;

    return Scaffold(
      backgroundColor: _background,
      appBar: AppBar(
        backgroundColor: _primary,
        foregroundColor: Colors.white,
        elevation: 0,
        title: const Text(
          'Görev Ata',
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
              // ── Elevator Selector ─────────────────────────────────────────
              _SectionLabel(
                icon: Icons.elevator_outlined,
                label: 'Asansör Seç',
              ),
              const SizedBox(height: 12),
              elevatorsAsync.when(
                loading: () => const Center(
                  child: CircularProgressIndicator(color: _primary),
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

              // ── Technician UUID ───────────────────────────────────────────
              _SectionLabel(
                icon: Icons.person_search_outlined,
                label: 'Teknisyen UUID',
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _technicianIdController,
                decoration: _inputDecoration(
                  hint: 'xxxxxxxx-xxxx-xxxx-xxxx-xxxxxxxxxxxx',
                  helper:
                      'Teknisyenin Supabase Auth kullanıcı UUID\'sini girin.',
                ),
                validator: (v) {
                  if (v == null || v.trim().isEmpty) {
                    return 'Teknisyen UUID gereklidir.';
                  }
                  // Basic UUID format check (8-4-4-4-12 hex groups)
                  final uuidRegex = RegExp(
                    r'^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$',
                    caseSensitive: false,
                  );
                  if (!uuidRegex.hasMatch(v.trim())) {
                    return 'Geçerli bir UUID girin (xxxxxxxx-xxxx-xxxx-xxxx-xxxxxxxxxxxx).';
                  }
                  return null;
                },
              ),

              const SizedBox(height: 28),

              // ── Date & Time ───────────────────────────────────────────────
              _SectionLabel(
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

              // ── Notes (optional) ──────────────────────────────────────────
              _SectionLabel(
                icon: Icons.notes_outlined,
                label: 'Notlar (İsteğe Bağlı)',
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _notesController,
                maxLines: 4,
                decoration: _inputDecoration(
                  hint: 'Bakım ile ilgili ek notlar...',
                ),
              ),

              const SizedBox(height: 40),

              // ── Submit Button ─────────────────────────────────────────────
              SizedBox(
                width: double.infinity,
                height: 56,
                child: FilledButton(
                  onPressed: isLoading ? null : _submit,
                  style: FilledButton.styleFrom(
                    backgroundColor: _primary,
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
                          'Görevi Ata',
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
    return Container(
      decoration: BoxDecoration(
        color: _surfaceContainerLowest,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: _outlineVariant.withValues(alpha: 0.5)),
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<ElevatorModel>(
          value: selected,
          hint: const Padding(
            padding: EdgeInsets.symmetric(horizontal: 16),
            child: Text(
              'Asansör seçin...',
              style: TextStyle(color: _outline),
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
                            color: _onSurface,
                          ),
                        ),
                        if (e.address != null)
                          Text(
                            e.address!,
                            style: const TextStyle(
                              fontSize: 12,
                              color: _outline,
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

class _SectionLabel extends StatelessWidget {
  const _SectionLabel({required this.icon, required this.label});

  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(icon, size: 18, color: _primary),
        const SizedBox(width: 8),
        Text(
          label,
          style: const TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w700,
            color: _onSurface,
            letterSpacing: 0.1,
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
          ? _primary.withValues(alpha: 0.07)
          : _surfaceContainerLowest,
      borderRadius: BorderRadius.circular(14),
      child: InkWell(
        borderRadius: BorderRadius.circular(14),
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
              color: hasValue ? _primary : _outlineVariant.withValues(alpha: 0.5),
              width: hasValue ? 1.5 : 1,
            ),
          ),
          child: Row(
            children: [
              Icon(
                icon,
                size: 18,
                color: hasValue ? _primary : _onSurfaceVariant,
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  label,
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: hasValue ? FontWeight.w600 : FontWeight.w400,
                    color: hasValue ? _primary : _onSurfaceVariant,
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
        color: _errorContainer,
        borderRadius: BorderRadius.circular(10),
      ),
      child: Row(
        children: [
          const Icon(Icons.error_outline, color: _onErrorContainer, size: 18),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              message,
              style: const TextStyle(
                color: _onErrorContainer,
                fontSize: 13,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

InputDecoration _inputDecoration({required String hint, String? helper}) {
  return InputDecoration(
    hintText: hint,
    helperText: helper,
    helperMaxLines: 2,
    filled: true,
    fillColor: _surfaceContainerLowest,
    border: OutlineInputBorder(
      borderRadius: BorderRadius.circular(14),
      borderSide: BorderSide(color: _outlineVariant.withValues(alpha: 0.5)),
    ),
    enabledBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(14),
      borderSide: BorderSide(color: _outlineVariant.withValues(alpha: 0.5)),
    ),
    focusedBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(14),
      borderSide: const BorderSide(color: _primary, width: 2),
    ),
    errorBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(14),
      borderSide: const BorderSide(color: _error),
    ),
    focusedErrorBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(14),
      borderSide: const BorderSide(color: _error, width: 2),
    ),
    contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
  );
}
