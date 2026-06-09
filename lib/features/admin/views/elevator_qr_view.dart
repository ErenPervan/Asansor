import 'dart:ui' as ui;

import 'package:asansor/core/enums/app_enums.dart';
import 'package:asansor/core/theme/app_colors.dart';
import 'package:asansor/core/theme/app_spacing.dart';
import 'package:asansor/core/widgets/loading_state.dart';
import 'package:asansor/features/elevator/models/elevator_model.dart';
import 'package:asansor/features/elevator/providers/elevator_providers.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import 'package:qr_flutter/qr_flutter.dart';

class ElevatorQrView extends ConsumerWidget {
  const ElevatorQrView({super.key, required this.elevatorId});

  final String elevatorId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colors = AppThemeColors.of(context);
    final elevAsync = ref.watch(elevatorByIdProvider(elevatorId));

    return elevAsync.when(
      loading: () => Scaffold(
        backgroundColor: colors.background,
        body: const LoadingState(),
      ),
      error: (e, st) => Scaffold(
        backgroundColor: colors.background,
        appBar: AppBar(title: const Text('QR Kodu')),
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(AppSpacing.lg),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.error_outline_rounded, size: 52, color: colors.error),
                const SizedBox(height: AppSpacing.md),
                Text(
                  'QR kodu yüklenemedi',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        color: colors.onSurface,
                        fontWeight: FontWeight.w800,
                      ),
                ),
                const SizedBox(height: AppSpacing.sm),
                Text(
                  '$e',
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: colors.onSurfaceVariant,
                      ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: AppSpacing.lg),
                FilledButton(
                  onPressed: () =>
                      ref.invalidate(elevatorByIdProvider(elevatorId)),
                  child: const Text('Tekrar Dene'),
                ),
              ],
            ),
          ),
        ),
      ),
      data: (elevator) => _QrScaffold(elevator: elevator),
    );
  }
}

class _QrScaffold extends StatelessWidget {
  const _QrScaffold({required this.elevator});

  final ElevatorModel elevator;

  @override
  Widget build(BuildContext context) {
    final colors = AppThemeColors.of(context);

    return Scaffold(
      backgroundColor: colors.background,
      appBar: AppBar(
        backgroundColor: colors.surface.withValues(alpha: 0.92),
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: Icon(Icons.arrow_back_rounded, color: colors.onSurfaceVariant),
          tooltip: 'Geri',
          onPressed: () => context.pop(),
        ),
        title: Text(
          'QR Kodu',
          style: Theme.of(context).textTheme.titleLarge?.copyWith(
                color: colors.primaryDark,
                fontWeight: FontWeight.w900,
              ),
        ),
        centerTitle: false,
        actions: [
          IconButton(
            icon: const Icon(Icons.add_circle_outline_rounded),
            tooltip: 'Yeni Asansör Ekle',
            onPressed: () => context.pushReplacement('/admin/add-elevator'),
          ),
          const SizedBox(width: AppSpacing.sm),
        ],
      ),
      body: SafeArea(
        top: false,
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(
            AppSpacing.md,
            AppSpacing.lg,
            AppSpacing.md,
            110,
          ),
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 620),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  _QrHeroHeader(elevator: elevator),
                  const SizedBox(height: AppSpacing.lg),
                  _QrCard(elevator: elevator, onPrint: () => _printQr(context)),
                  const SizedBox(height: AppSpacing.lg),
                  TextButton.icon(
                    onPressed: () => context.pushReplacement('/admin/add-elevator'),
                    icon: const Icon(Icons.add_circle_outline_rounded),
                    label: const Text('Yeni Asansör Ekle'),
                    style: TextButton.styleFrom(
                      foregroundColor: colors.secondary,
                      textStyle: Theme.of(context).textTheme.labelLarge
                          ?.copyWith(fontWeight: FontWeight.w900),
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

  Future<void> _printQr(BuildContext context) async {
    try {
      await Printing.layoutPdf(
        name: 'QR_${elevator.buildingName.replaceAll(' ', '_')}',
        onLayout: (format) => _buildPdf(elevator, format),
      );
    } catch (e) {
      if (context.mounted) {
        final colors = AppThemeColors.of(context);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Yazdırma hatası: $e'),
            backgroundColor: colors.error,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    }
  }

  Future<Uint8List> _buildPdf(
    ElevatorModel elevator,
    PdfPageFormat format,
  ) async {
    final qrPainter = QrPainter(
      data: elevator.id,
      version: QrVersions.auto,
      errorCorrectionLevel: QrErrorCorrectLevel.H,
    );
    final imageData = await qrPainter.toImageData(
      600,
      format: ui.ImageByteFormat.png,
    );
    if (imageData == null) throw Exception('QR verisi alınamadı');
    final qrBytes = imageData.buffer.asUint8List();

    final doc = pw.Document(
      theme: pw.ThemeData.withFont(
        base: await PdfGoogleFonts.notoSansRegular(),
        bold: await PdfGoogleFonts.notoSansBold(),
      ),
    );

    final now = DateFormat('d MMMM y, HH:mm', 'tr_TR').format(DateTime.now());

    doc.addPage(
      pw.Page(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(40),
        build: (ctx) => pw.Column(
          crossAxisAlignment: pw.CrossAxisAlignment.center,
          children: [
            pw.Container(
              width: double.infinity,
              padding: const pw.EdgeInsets.symmetric(
                horizontal: 20,
                vertical: 14,
              ),
              decoration: pw.BoxDecoration(
                color: PdfColor.fromHex('#00355F'),
                borderRadius: const pw.BorderRadius.all(pw.Radius.circular(8)),
              ),
              child: pw.Column(
                crossAxisAlignment: pw.CrossAxisAlignment.center,
                children: [
                  pw.Text(
                    'ELEVATEOPS PRO',
                    style: pw.TextStyle(
                      color: PdfColors.white,
                      fontSize: 20,
                      fontWeight: pw.FontWeight.bold,
                    ),
                  ),
                  pw.SizedBox(height: 4),
                  pw.Text(
                    'Bakım ve Arıza Takip Sistemi',
                    style: const pw.TextStyle(
                      color: PdfColors.white,
                      fontSize: 12,
                    ),
                  ),
                ],
              ),
            ),
            pw.SizedBox(height: 28),
            pw.Text(
              elevator.buildingName,
              style: pw.TextStyle(
                fontSize: 22,
                fontWeight: pw.FontWeight.bold,
                color: PdfColor.fromHex('#181C1E'),
              ),
              textAlign: pw.TextAlign.center,
            ),
            if (elevator.address != null && elevator.address!.isNotEmpty) ...[
              pw.SizedBox(height: 6),
              pw.Text(
                elevator.address!,
                style: const pw.TextStyle(fontSize: 13, color: PdfColors.grey700),
                textAlign: pw.TextAlign.center,
              ),
            ],
            pw.SizedBox(height: 32),
            pw.Container(
              padding: const pw.EdgeInsets.all(16),
              decoration: pw.BoxDecoration(
                border: pw.Border.all(color: PdfColors.grey300, width: 1),
                borderRadius: const pw.BorderRadius.all(pw.Radius.circular(8)),
              ),
              child: pw.Image(pw.MemoryImage(qrBytes), width: 220, height: 220),
            ),
            pw.SizedBox(height: 16),
            pw.Container(
              padding: const pw.EdgeInsets.symmetric(
                horizontal: 12,
                vertical: 6,
              ),
              decoration: pw.BoxDecoration(
                color: PdfColors.grey100,
                borderRadius: const pw.BorderRadius.all(pw.Radius.circular(4)),
              ),
              child: pw.Text(
                'ID: ${elevator.id}',
                style: const pw.TextStyle(
                  fontSize: 9,
                  color: PdfColors.grey700,
                ),
              ),
            ),
            pw.SizedBox(height: 24),
            pw.Text(
              'Bu QR kodu tarayarak asansör bakım formuna ulaşabilirsiniz.',
              style: const pw.TextStyle(fontSize: 11, color: PdfColors.grey700),
              textAlign: pw.TextAlign.center,
            ),
            pw.Spacer(),
            pw.Divider(color: PdfColors.grey300),
            pw.SizedBox(height: 4),
            pw.Text(
              'Oluşturulma: $now',
              style: const pw.TextStyle(fontSize: 9, color: PdfColors.grey600),
            ),
          ],
        ),
      ),
    );

    return doc.save();
  }
}

class _QrHeroHeader extends StatelessWidget {
  const _QrHeroHeader({required this.elevator});

  final ElevatorModel elevator;

  @override
  Widget build(BuildContext context) {
    final colors = AppThemeColors.of(context);
    final textTheme = Theme.of(context).textTheme;

    return Container(
      padding: const EdgeInsets.all(AppSpacing.lg),
      decoration: BoxDecoration(
        color: colors.primaryDark,
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: colors.primary.withValues(alpha: 0.16),
            blurRadius: 34,
            offset: const Offset(0, 16),
          ),
        ],
      ),
      child: Stack(
        children: [
          Positioned(
            right: -42,
            top: -54,
            child: Icon(
              Icons.qr_code_2_rounded,
              size: 176,
              color: colors.onPrimary.withValues(alpha: 0.06),
            ),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    width: 48,
                    height: 48,
                    decoration: BoxDecoration(
                      color: colors.onPrimary.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(15),
                    ),
                    child: Icon(Icons.elevator_rounded, color: colors.onPrimary),
                  ),
                  const Spacer(),
                  _StatusChip(status: elevator.status),
                ],
              ),
              const SizedBox(height: AppSpacing.xl),
              Text(
                elevator.buildingName,
                style: textTheme.headlineMedium?.copyWith(
                  color: colors.onPrimary,
                  fontWeight: FontWeight.w900,
                  height: 1.05,
                ),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
              const SizedBox(height: AppSpacing.sm),
              Text(
                elevator.address?.isNotEmpty == true
                    ? elevator.address!
                    : 'Adres belirtilmemiş',
                style: textTheme.bodyMedium?.copyWith(
                  color: colors.onPrimary.withValues(alpha: 0.76),
                  fontWeight: FontWeight.w700,
                ),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
              const SizedBox(height: AppSpacing.lg),
              Wrap(
                spacing: AppSpacing.sm,
                runSpacing: AppSpacing.sm,
                children: [
                  const _HeroPill(
                    icon: Icons.qr_code_scanner_rounded,
                    label: 'Saha taramasına hazır',
                  ),
                  if (elevator.maintenanceDay != null)
                    _HeroPill(
                      icon: Icons.event_repeat_rounded,
                      label: 'Her ay ${elevator.maintenanceDay}. gün',
                    ),
                ],
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _HeroPill extends StatelessWidget {
  const _HeroPill({required this.icon, required this.label});

  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    final colors = AppThemeColors.of(context);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 8),
      decoration: BoxDecoration(
        color: colors.onPrimary.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(AppSpacing.radiusFull),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: AppColors.accentGold, size: 16),
          const SizedBox(width: 7),
          Text(
            label,
            style: Theme.of(context).textTheme.labelSmall?.copyWith(
                  color: colors.onPrimary.withValues(alpha: 0.82),
                  fontWeight: FontWeight.w900,
                ),
          ),
        ],
      ),
    );
  }
}

class _QrCard extends StatelessWidget {
  const _QrCard({required this.elevator, required this.onPrint});

  final ElevatorModel elevator;
  final VoidCallback onPrint;

  @override
  Widget build(BuildContext context) {
    final colors = AppThemeColors.of(context);
    final textTheme = Theme.of(context).textTheme;

    return Container(
      decoration: BoxDecoration(
        color: colors.surfaceContainerLowest,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: colors.outlineVariant.withValues(alpha: 0.35)),
        boxShadow: [
          BoxShadow(
            color: colors.primary.withValues(alpha: 0.06),
            blurRadius: 30,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        children: [
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(AppSpacing.lg),
            decoration: BoxDecoration(
              color: colors.surfaceContainerLow.withValues(alpha: 0.5),
              border: Border(
                bottom: BorderSide(
                  color: colors.outlineVariant.withValues(alpha: 0.35),
                ),
              ),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        elevator.buildingName,
                        style: textTheme.headlineSmall?.copyWith(
                          color: colors.primaryDark,
                          fontWeight: FontWeight.w900,
                        ),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: AppSpacing.xs),
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Icon(
                            Icons.location_on_outlined,
                            size: 17,
                            color: colors.onSurfaceVariant,
                          ),
                          const SizedBox(width: 5),
                          Expanded(
                            child: Text(
                              elevator.address?.isNotEmpty == true
                                  ? elevator.address!
                                  : 'Adres belirtilmemiş',
                              style: textTheme.bodyMedium?.copyWith(
                                color: colors.onSurfaceVariant,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: AppSpacing.sm),
                _StatusChip(status: elevator.status),
              ],
            ),
          ),
          Container(
            width: double.infinity,
            color: Colors.white,
            padding: const EdgeInsets.all(AppSpacing.lg),
            child: Column(
              children: [
                _QrFrame(elevatorId: elevator.id),
                const SizedBox(height: AppSpacing.lg),
                Text(
                  'Asansör ID',
                  style: textTheme.labelSmall?.copyWith(
                    color: colors.outline,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: AppSpacing.xs),
                InkWell(
                  onTap: () => _copyId(context),
                  borderRadius: BorderRadius.circular(12),
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 13,
                      vertical: 10,
                    ),
                    decoration: BoxDecoration(
                      color: colors.surfaceContainer,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Flexible(
                          child: Text(
                            elevator.id,
                            style: textTheme.labelMedium?.copyWith(
                              color: colors.primaryDark,
                              fontWeight: FontWeight.w800,
                              letterSpacing: 0.2,
                            ),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        const SizedBox(width: AppSpacing.sm),
                        Icon(
                          Icons.content_copy_rounded,
                          size: 17,
                          color: colors.outline,
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(AppSpacing.lg),
            child: Column(
              children: [
                FilledButton.icon(
                  onPressed: onPrint,
                  icon: const Icon(Icons.print_outlined),
                  label: const Text('Yazdır / PDF'),
                  style: FilledButton.styleFrom(
                    minimumSize: const Size(double.infinity, 52),
                    backgroundColor: colors.primary,
                    foregroundColor: colors.onPrimary,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                  ),
                ),
                const SizedBox(height: AppSpacing.md),
                OutlinedButton.icon(
                  onPressed: () => context.push('/elevator/${elevator.id}'),
                  icon: const Icon(Icons.info_outline_rounded),
                  label: const Text('Detayına Git'),
                  style: OutlinedButton.styleFrom(
                    minimumSize: const Size(double.infinity, 52),
                    foregroundColor: colors.primary,
                    side: BorderSide(color: colors.primary.withValues(alpha: 0.32)),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _copyId(BuildContext context) async {
    await Clipboard.setData(ClipboardData(text: elevator.id));
    if (!context.mounted) return;
    final colors = AppThemeColors.of(context);
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          content: const Text('Asansör ID kopyalandı.'),
          behavior: SnackBarBehavior.floating,
          backgroundColor: colors.primary,
        ),
      );
  }
}

class _QrFrame extends StatelessWidget {
  const _QrFrame({required this.elevatorId});

  final String elevatorId;

  @override
  Widget build(BuildContext context) {
    final colors = AppThemeColors.of(context);

    return Container(
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: AppColors.background,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: colors.outlineVariant.withValues(alpha: 0.62),
          width: 1.4,
        ),
      ),
      child: Stack(
        children: [
          Padding(
            padding: const EdgeInsets.all(AppSpacing.sm),
            child: QrImageView(
              data: elevatorId,
              version: QrVersions.auto,
              size: 230,
              errorCorrectionLevel: QrErrorCorrectLevel.H,
              eyeStyle: const QrEyeStyle(
                eyeShape: QrEyeShape.square,
                color: AppColors.onSurface,
              ),
              dataModuleStyle: const QrDataModuleStyle(
                dataModuleShape: QrDataModuleShape.square,
                color: AppColors.onSurface,
              ),
            ),
          ),
          _CornerAccent(alignment: Alignment.topLeft),
          _CornerAccent(alignment: Alignment.topRight),
          _CornerAccent(alignment: Alignment.bottomLeft),
          _CornerAccent(alignment: Alignment.bottomRight),
        ],
      ),
    );
  }
}

class _CornerAccent extends StatelessWidget {
  const _CornerAccent({required this.alignment});

  final Alignment alignment;

  @override
  Widget build(BuildContext context) {
    final colors = AppThemeColors.of(context);
    final isLeft = alignment.x < 0;
    final isTop = alignment.y < 0;

    return Positioned.fill(
      child: Align(
        alignment: alignment,
        child: SizedBox(
          width: 22,
          height: 22,
          child: DecoratedBox(
            decoration: BoxDecoration(
              border: Border(
                top: isTop
                    ? BorderSide(color: colors.primary, width: 2)
                    : BorderSide.none,
                bottom: !isTop
                    ? BorderSide(color: colors.primary, width: 2)
                    : BorderSide.none,
                left: isLeft
                    ? BorderSide(color: colors.primary, width: 2)
                    : BorderSide.none,
                right: !isLeft
                    ? BorderSide(color: colors.primary, width: 2)
                    : BorderSide.none,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _StatusChip extends StatelessWidget {
  const _StatusChip({required this.status});

  final ElevatorStatus status;

  @override
  Widget build(BuildContext context) {
    final colors = AppThemeColors.of(context);
    final (label, bg, fg) = _styles(status, colors);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 7),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(AppSpacing.radiusFull),
        border: Border.all(color: fg.withValues(alpha: 0.18)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 7,
            height: 7,
            decoration: BoxDecoration(color: fg, shape: BoxShape.circle),
          ),
          const SizedBox(width: 7),
          Text(
            label,
            style: Theme.of(context).textTheme.labelSmall?.copyWith(
                  fontWeight: FontWeight.w800,
                  color: fg,
                ),
          ),
        ],
      ),
    );
  }

  static (String, Color, Color) _styles(
    ElevatorStatus s,
    AppThemeColors colors,
  ) {
    switch (s) {
      case ElevatorStatus.active:
        return ('Aktif', colors.primaryFixed.withValues(alpha: 0.7), colors.primaryDark);
      case ElevatorStatus.faulty:
        return ('Arızalı', colors.errorContainer, colors.onErrorContainer);
      case ElevatorStatus.underMaintenance:
        return ('Bakım Gerekli', colors.warningContainer, colors.warning);
      case ElevatorStatus.inactive:
        return ('Pasif', colors.surfaceContainer, colors.outline);
    }
  }
}
