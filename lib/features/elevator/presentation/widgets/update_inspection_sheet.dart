import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../../../core/theme/app_colors.dart';
import '../../models/elevator_model.dart';
import '../../providers/inspection_controller.dart';
import 'inspection_badge.dart';

class UpdateInspectionSheet extends ConsumerStatefulWidget {
  const UpdateInspectionSheet({super.key, required this.elevator});

  final ElevatorModel elevator;

  @override
  ConsumerState<UpdateInspectionSheet> createState() =>
      _UpdateInspectionSheetState();
}

class _UpdateInspectionSheetState extends ConsumerState<UpdateInspectionSheet> {
  final _formKey = GlobalKey<FormState>();
  DateTime _inspectionDate = DateTime.now();
  String _status = 'none';
  final _inspectorNameController = TextEditingController();
  final _notesController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _status = widget.elevator.inspectionStatus;
  }

  @override
  void dispose() {
    _inspectorNameController.dispose();
    _notesController.dispose();
    super.dispose();
  }

  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _inspectionDate,
      firstDate: DateTime(2000),
      lastDate: DateTime.now().add(const Duration(days: 365)),
    );
    if (picked != null) {
      setState(() {
        _inspectionDate = picked;
      });
    }
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    if (_status == 'none') {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Lütfen bir etiket rengi seçin.')),
      );
      return;
    }

    try {
      await ref.read(inspectionControllerProvider(widget.elevator.id).notifier).addInspection(
            inspectionDate: _inspectionDate,
            status: _status,
            inspectorName: _inspectorNameController.text.trim().isEmpty
                ? null
                : _inspectorNameController.text.trim(),
            notes: _notesController.text.trim().isEmpty
                ? null
                : _notesController.text.trim(),
          );

      if (!mounted) return;
      context.pop();
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Muayene bilgileri başarıyla güncellendi.')),
      );
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Muayene bilgileri kaydedilemedi.')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    // Check loading state
    final controllerState = ref.watch(inspectionControllerProvider(widget.elevator.id));
    final isLoading = controllerState.isLoading;

    return Padding(
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom,
        left: 24,
        right: 24,
        top: 24,
      ),
      child: Form(
        key: _formKey,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Text(
              'Muayene Güncelle',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.w700,
                color: AppColors.textPrimary,
              ),
            ),
            const SizedBox(height: 24),
            // Date Picker
            InkWell(
              onTap: _pickDate,
              borderRadius: BorderRadius.circular(12),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
                decoration: BoxDecoration(
                  border: Border.all(color: AppColors.outlineVariant),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'Tarih: ${DateFormat('dd MMM yyyy', 'tr_TR').format(_inspectionDate)}',
                      style: const TextStyle(fontSize: 16),
                    ),
                    const Icon(Icons.calendar_today, color: AppColors.primary),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),
            // Status Dropdown / Chips
            const Text(
              'Etiket Sonucu',
              style: TextStyle(fontWeight: FontWeight.w600, fontSize: 14),
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                _StatusChip(status: 'red', current: _status, onSelect: (s) => setState(() => _status = s)),
                _StatusChip(status: 'yellow', current: _status, onSelect: (s) => setState(() => _status = s)),
                _StatusChip(status: 'blue', current: _status, onSelect: (s) => setState(() => _status = s)),
                _StatusChip(status: 'green', current: _status, onSelect: (s) => setState(() => _status = s)),
              ],
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _inspectorNameController,
              decoration: InputDecoration(
                labelText: 'Muayene Görevlisi (Opsiyonel)',
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
              ),
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _notesController,
              maxLines: 3,
              decoration: InputDecoration(
                labelText: 'Notlar (Opsiyonel)',
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
              ),
            ),
            const SizedBox(height: 24),
            SizedBox(
              height: 56,
              child: FilledButton(
                onPressed: isLoading ? null : _submit,
                style: FilledButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                child: isLoading
                    ? const CircularProgressIndicator(color: Colors.white)
                    : const Text('Kaydet', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
              ),
            ),
            const SizedBox(height: 32),
          ],
        ),
      ),
    );
  }
}

class _StatusChip extends StatelessWidget {
  const _StatusChip({
    required this.status,
    required this.current,
    required this.onSelect,
  });

  final String status;
  final String current;
  final ValueChanged<String> onSelect;

  @override
  Widget build(BuildContext context) {
    final isSelected = status == current;
    return InkWell(
      onTap: () => onSelect(status),
      borderRadius: BorderRadius.circular(12),
      child: Container(
        decoration: BoxDecoration(
          border: Border.all(
            color: isSelected ? AppColors.primary : AppColors.outlineVariant,
            width: isSelected ? 2 : 1,
          ),
          borderRadius: BorderRadius.circular(12),
        ),
        padding: const EdgeInsets.all(2),
        child: IgnorePointer(child: InspectionBadge(status: status)),
      ),
    );
  }
}
