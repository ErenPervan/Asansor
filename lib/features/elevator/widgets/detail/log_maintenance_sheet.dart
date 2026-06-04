import 'package:asansor/core/theme/app_spacing.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:asansor/core/theme/app_colors.dart';
import 'package:asansor/features/auth/providers/auth_providers.dart';
import 'package:asansor/features/maintenance/providers/maintenance_providers.dart';
import 'package:asansor/features/maintenance/models/maintenance_log_model.dart';

class LogMaintenanceSheet extends ConsumerStatefulWidget {
  const LogMaintenanceSheet({super.key, required this.elevatorId});

  final String elevatorId;

  @override
  ConsumerState<LogMaintenanceSheet> createState() =>
      LogMaintenanceSheetState();
}

class LogMaintenanceSheetState extends ConsumerState<LogMaintenanceSheet> {
  final _formKey = GlobalKey<FormState>();
  final _notesController = TextEditingController();

  @override
  void dispose() {
    _notesController.dispose();
    super.dispose();
  }

  void _submit() {
    if (!_formKey.currentState!.validate()) return;
    final userId = ref.read(authControllerProvider).valueOrNull?.id;
    if (userId == null) {
      HapticFeedback.heavyImpact();
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Oturum bilgisi alınamadı. Lütfen tekrar giriş yapın.'),
          behavior: SnackBarBehavior.floating,
          backgroundColor: AppColors.error,
        ),
      );
      return;
    }
    ref
        .read(maintenanceControllerProvider.notifier)
        .addLog(
          elevatorId: widget.elevatorId,
          technicianId: userId,
          notes: _notesController.text.trim(),
          maintenanceDate: DateTime.now(),
        );
  }

  @override
  Widget build(BuildContext context) {
    ref.listen<AsyncValue<dynamic>>(maintenanceControllerProvider, (
      previous,
      next,
    ) {
      if (previous?.isLoading != true) return;
      next.whenOrNull(
        data: (raw) {
          final log = raw as MaintenanceLogModel?;
          if (log == null) return;
          HapticFeedback.lightImpact();
          if (!log.isOfflineQueued) {
            ref.invalidate(logsByElevatorProvider(widget.elevatorId));
            ref.invalidate(pendingMaintenanceProvider);
            ref.invalidate(completedTodayCountProvider);
          }
          if (!context.mounted) return;
          Navigator.of(context).pop();
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                log.isOfflineQueued
                    ? 'İnternet bağlantısı yok. Kayıt cihaza kaydedildi, '
                          'bağlantı sağlandığında otomatik senkronize edilecek.'
                    : 'Bakım kaydı başarıyla eklendi.',
              ),
              behavior: SnackBarBehavior.floating,
              backgroundColor: log.isOfflineQueued
                  ? AppColors.warningLight
                  : AppColors.success,
              duration: log.isOfflineQueued
                  ? const Duration(seconds: 5)
                  : const Duration(seconds: 3),
            ),
          );
        },
        error: (err, _) {
          if (!context.mounted) return;
          HapticFeedback.heavyImpact();
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(err.toString().replaceFirst('Exception: ', '')),
              behavior: SnackBarBehavior.floating,
              backgroundColor: AppColors.error,
            ),
          );
        },
      );
    });

    final isLoading = ref.watch(maintenanceControllerProvider).isLoading;

    return PopScope(
      canPop: !isLoading,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop && isLoading) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Lütfen kayıt tamamlanana kadar bekleyin.'),
              backgroundColor: AppColors.error,
            ),
          );
        }
      },
      child: Padding(
        padding: EdgeInsets.only(
          bottom: MediaQuery.viewInsetsOf(context).bottom,
        ),
        child: SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(24, 16, 24, 24),
            child: Form(
              key: _formKey,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Center(
                    child: Container(
                      width: 40,
                      height: 4,
                      decoration: BoxDecoration(
                        color: AppColors.outlineVariant,
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                  ),
                  const SizedBox(height: 20),
                  Row(
                    children: [
                      Container(
                        width: 40,
                        height: 40,
                        decoration: BoxDecoration(
                          color: AppColors.primary.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Icon(
                          Icons.build_outlined,
                          color: AppColors.primary,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Bakım Ekle',
                            style: Theme.of(context).textTheme.titleMedium
                                ?.copyWith(
                                  fontWeight: FontWeight.w700,
                                  color: AppColors.onSurface,
                                ),
                          ),
                          Text(
                            'Yapılan bakımı kaydedin.',
                            style: Theme.of(context).textTheme.bodySmall
                                ?.copyWith(color: AppColors.outline),
                          ),
                        ],
                      ),
                    ],
                  ),
                  const SizedBox(height: AppSpacing.lg),
                  TextFormField(
                    controller: _notesController,
                    maxLines: 4,
                    minLines: 3,
                    textInputAction: TextInputAction.newline,
                    enabled: !isLoading,
                    decoration: const InputDecoration(
                      labelText: 'Bakım Notları',
                      hintText: 'Yapılan işlemleri açıklayın...',
                      alignLabelWithHint: true,
                      border: OutlineInputBorder(),
                    ),
                    validator: (v) {
                      if (v == null || v.trim().isEmpty) {
                        return 'Lütfen bakım notları girin.';
                      }
                      if (v.trim().length < 10) {
                        return 'Notlar en az 10 karakter olmalıdır.';
                      }
                      return null;
                    },
                  ),
                  const SizedBox(height: 20),
                  FilledButton(
                    onPressed: isLoading ? null : _submit,
                    style: FilledButton.styleFrom(
                      backgroundColor: AppColors.error,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                    ),
                    child: isLoading
                        ? const SizedBox(
                            height: 20,
                            width: 20,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: Colors.white,
                            ),
                          )
                        : Text(
                            'Bakımı Kaydet',
                            style: Theme.of(context).textTheme.labelLarge
                                ?.copyWith(fontWeight: FontWeight.w600),
                          ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
