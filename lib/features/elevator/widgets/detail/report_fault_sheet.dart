import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../fault/models/fault_report_model.dart';
import '../../../fault/providers/fault_providers.dart';

class ReportFaultSheet extends ConsumerStatefulWidget {
  const ReportFaultSheet({super.key, required this.elevatorId});

  final String elevatorId;

  @override
  ConsumerState<ReportFaultSheet> createState() => _ReportFaultSheetState();
}

class _ReportFaultSheetState extends ConsumerState<ReportFaultSheet> {
  final _formKey = GlobalKey<FormState>();
  final _descController = TextEditingController();

  @override
  void dispose() {
    _descController.dispose();
    super.dispose();
  }

  void _submit() {
    if (!_formKey.currentState!.validate()) return;
    ref
        .read(faultControllerProvider.notifier)
        .reportFault(
          elevatorId: widget.elevatorId,
          description: _descController.text.trim(),
        );
  }

  @override
  Widget build(BuildContext context) {
    ref.listen<AsyncValue<dynamic>>(faultControllerProvider, (previous, next) {
      if (previous?.isLoading != true) return;
      next.whenOrNull(
        data: (raw) {
          final fault = raw as FaultReportModel?;
          if (fault == null) return;
          HapticFeedback.lightImpact();
          if (!fault.isOfflineQueued) {
            ref.invalidate(activeFaultsProvider);
            ref.invalidate(faultsByElevatorProvider(widget.elevatorId));
          }
          if (!context.mounted) return;
          Navigator.of(context).pop();
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                fault.isOfflineQueued
                    ? 'İnternet bağlantısı yok. Kayıt cihaza kaydedildi, '
                          'bağlantı sağlandığında otomatik senkronize edilecek.'
                    : 'Arıza başarıyla bildirildi.',
              ),
              behavior: SnackBarBehavior.floating,
              backgroundColor: fault.isOfflineQueued
                  ? const Color(0xFFD97706)
                  : const Color(0xFF155724),
              duration: fault.isOfflineQueued
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

    final isLoading = ref.watch(faultControllerProvider).isLoading;

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
                          color: AppColors.errorContainer,
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: const Icon(
                          Icons.warning_amber_outlined,
                          color: AppColors.onErrorContainer,
                        ),
                      ),
                      const SizedBox(width: 12),
                      const Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Arıza Bildir',
                            style: TextStyle(
                              fontSize: 17,
                              fontWeight: FontWeight.w700,
                              color: AppColors.onSurface,
                            ),
                          ),
                          Text(
                            'Gözlemlenen arızayı açıklayın.',
                            style: TextStyle(
                              fontSize: 13,
                              color: AppColors.outline,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                  const SizedBox(height: 24),
                  TextFormField(
                    controller: _descController,
                    maxLines: 4,
                    minLines: 3,
                    textInputAction: TextInputAction.newline,
                    enabled: !isLoading,
                    decoration: const InputDecoration(
                      labelText: 'Arıza Açıklaması',
                      hintText: 'Arızayı detaylı açıklayın...',
                      alignLabelWithHint: true,
                      border: OutlineInputBorder(),
                    ),
                    validator: (v) {
                      if (v == null || v.trim().isEmpty) {
                        return 'Lütfen bir açıklama girin.';
                      }
                      if (v.trim().length < 10) {
                        return 'Açıklama en az 10 karakter olmalıdır.';
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
                        : const Text(
                            'Arızayı Gönder',
                            style: TextStyle(
                              fontWeight: FontWeight.w600,
                              fontSize: 15,
                            ),
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
