import 'dart:typed_data';

import 'dart:ui' as ui;

import 'package:flutter/material.dart';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:go_router/go_router.dart';

import 'package:intl/intl.dart';

import 'package:pdf/pdf.dart';

import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';

import 'package:qr_flutter/qr_flutter.dart';

import '../../elevator/models/elevator_model.dart';

import '../../elevator/providers/elevator_providers.dart';

import '../../../core/theme/app_colors.dart';
// ─────────────────────────────────────────────────────────────────────────────

class ElevatorQrView extends ConsumerWidget {
  const ElevatorQrView({super.key, required this.elevatorId});

  final String elevatorId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colors = AppThemeColors.of(context);
    final elevAsync = ref.watch(elevatorByIdProvider(elevatorId));

    return elevAsync.when(
      loading: () =>
          const Scaffold(body: Center(child: CircularProgressIndicator())),
      error: (e, st) => Scaffold(
        appBar: AppBar(title: const Text('QR Kodu')),
        body: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.error_outline, size: 48, color: colors.primary),
              const SizedBox(height: 12),
              Text('$e'),
              const SizedBox(height: 16),
              FilledButton(
                onPressed: () =>
                    ref.invalidate(elevatorByIdProvider(elevatorId)),
                child: const Text('Tekrar Dene'),
              ),
            ],
          ),
        ),
      ),
      data: (elevator) => _QrScaffold(elevator: elevator),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────

class _QrScaffold extends StatelessWidget {
  const _QrScaffold({required this.elevator});

  final ElevatorModel elevator;

  @override
  Widget build(BuildContext context) {
    final colors = AppThemeColors.of(context);
    final textTheme = Theme.of(context).textTheme;

    return Scaffold(
      backgroundColor: colors.background,
      appBar: AppBar(
        title: Text(
          'QR Kodu',
          style: textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w800),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.print_outlined),
            tooltip: 'Yazdır / Kaydet',
            onPressed: () => _printQr(context, elevator),
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(20, 16, 20, 48),
        children: [
          // ── Success banner ────────────────────────────────────────
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            decoration: BoxDecoration(
              color: colors.successContainer,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: colors.success.withValues(alpha: 0.3)),
            ),
            child: Row(
              children: [
                Icon(
                  Icons.check_circle_rounded,
                  color: colors.success,
                  size: 22,
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Asansör başarıyla oluşturuldu!',
                        style: textTheme.titleSmall?.copyWith(
                          fontWeight: FontWeight.w800,
                          color: colors.success,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        'QR kodu yazdırın ve asansöre yapıştırın.',
                        style: textTheme.labelSmall?.copyWith(
                          color: colors.success.withValues(alpha: 0.8),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(height: 16),

          // ── Elevator info card ────────────────────────────────────
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: colors.surface,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: colors.outlineVariant),
              boxShadow: [
                BoxShadow(
                  color: colors.onSurface.withValues(alpha: 0.04),
                  blurRadius: 8,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: Row(
              children: [
                Container(
                  width: 48,
                  height: 48,
                  decoration: BoxDecoration(
                    color: colors.primary.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(
                    Icons.elevator_outlined,
                    color: colors.primary,
                    size: 26,
                  ),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        elevator.buildingName,
                        style: textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.w800,
                          color: colors.onSurface,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      if (elevator.address != null &&
                          elevator.address!.isNotEmpty) ...[
                        const SizedBox(height: 3),
                        Row(
                          children: [
                            Icon(
                              Icons.location_on_outlined,
                              size: 13,
                              color: colors.outline,
                            ),
                            const SizedBox(width: 4),
                            Expanded(
                              child: Text(
                                elevator.address!,
                                style: textTheme.labelSmall?.copyWith(
                                  color: colors.outline,
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ],
                  ),
                ),
                _StatusChip(status: elevator.status),
              ],
            ),
          ),

          const SizedBox(height: 24),

          // ── QR code card ──────────────────────────────────────────
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 28),
            decoration: BoxDecoration(
              color: colors.surface,
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: colors.outlineVariant),
              boxShadow: [
                BoxShadow(
                  color: colors.primary.withValues(alpha: 0.07),
                  blurRadius: 20,
                  offset: const Offset(0, 6),
                ),
                BoxShadow(
                  color: colors.onSurface.withValues(alpha: 0.04),
                  blurRadius: 10,
                  offset: const Offset(0, 3),
                ),
              ],
            ),
            child: Column(
              children: [
                // Label
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      Icons.qr_code_2_rounded,
                      size: 16,
                      color: colors.primary,
                    ),
                    const SizedBox(width: 6),
                    Text(
                      'ASANSÖR QR KODU',
                      style: textTheme.labelSmall?.copyWith(
                        fontWeight: FontWeight.w800,
                        color: colors.primary,
                        letterSpacing: 1.5,
                      ),
                    ),
                  ],
                ),

                const SizedBox(height: 20),

                // QR code itself
                RepaintBoundary(
                  child: Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: colors.outlineVariant),
                    ),
                    child: QrImageView(
                      data: elevator.id,
                      version: QrVersions.auto,
                      size: 240,
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
                ),

                const SizedBox(height: 16),

                // UUID display
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 7,
                  ),
                  decoration: BoxDecoration(
                    color: colors.surfaceContainer,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: SelectableText(
                    elevator.id,
                    style: textTheme.labelSmall?.copyWith(
                      fontFamily: 'monospace',
                      color: colors.onSurfaceVariant,
                      letterSpacing: 0.5,
                    ),
                    textAlign: TextAlign.center,
                  ),
                ),

                const SizedBox(height: 10),

                Text(
                  'Bu QR kodu tarayarak asansör bilgilerine ulaşabilirsiniz.',
                  textAlign: TextAlign.center,
                  style: textTheme.bodySmall?.copyWith(
                    color: colors.outline,
                    height: 1.5,
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(height: 24),

          // ── Actions ───────────────────────────────────────────────
          FilledButton.icon(
            icon: const Icon(Icons.print_outlined),
            label: Text(
              'Yazdır / Kaydet',
              style: textTheme.titleSmall?.copyWith(
                fontWeight: FontWeight.w700,
              ),
            ),
            style: FilledButton.styleFrom(
              minimumSize: const Size(double.infinity, 54),
              backgroundColor: colors.primary,
              foregroundColor: colors.surface,
            ),
            onPressed: () => _printQr(context, elevator),
          ),

          const SizedBox(height: 10),

          OutlinedButton.icon(
            icon: const Icon(Icons.elevator_outlined),
            label: const Text('Asansör Detayına Git'),
            style: OutlinedButton.styleFrom(
              minimumSize: const Size(double.infinity, 50),
              side: BorderSide(color: colors.outlineVariant),
              foregroundColor: colors.onSurface,
            ),
            onPressed: () => context.push('/elevator/${elevator.id}'),
          ),

          const SizedBox(height: 10),

          TextButton.icon(
            icon: const Icon(Icons.add_rounded),
            label: const Text('Yeni Asansör Ekle'),
            style: TextButton.styleFrom(
              minimumSize: const Size(double.infinity, 48),
              foregroundColor: colors.primary,
            ),
            onPressed: () => context.pushReplacement('/admin/add-elevator'),
          ),
        ],
      ),
    );
  }

  Future<void> _printQr(BuildContext context, ElevatorModel elevator) async {
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
            backgroundColor: colors.primary,
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
    // Render QR to image bytes.
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
            // ── Header ────────────────────────────────────────────
            pw.Container(
              width: double.infinity,
              padding: const pw.EdgeInsets.symmetric(
                horizontal: 20,
                vertical: 14,
              ),
              decoration: pw.BoxDecoration(
                color: PdfColor.fromHex('#B91C1C'),
                borderRadius: const pw.BorderRadius.all(pw.Radius.circular(8)),
              ),
              child: pw.Column(
                crossAxisAlignment: pw.CrossAxisAlignment.center,
                children: [
                  pw.Text(
                    'ASANSÖR SİSTEMİ',
                    style: pw.TextStyle(
                      color: PdfColors.white,
                      fontSize: 20,
                      fontWeight: pw.FontWeight.bold,
                    ),
                  ),
                  pw.SizedBox(height: 4),
                  pw.Text(
                    'Bakım ve Arıza Takip Sistemi',
                    style: pw.TextStyle(color: PdfColors.white, fontSize: 12),
                  ),
                ],
              ),
            ),

            pw.SizedBox(height: 28),

            // ── Building info ──────────────────────────────────────
            pw.Text(
              elevator.buildingName,
              style: pw.TextStyle(
                fontSize: 22,
                fontWeight: pw.FontWeight.bold,
                color: PdfColor.fromHex('#0F172A'),
              ),
              textAlign: pw.TextAlign.center,
            ),

            if (elevator.address != null && elevator.address!.isNotEmpty) ...[
              pw.SizedBox(height: 6),
              pw.Text(
                elevator.address!,
                style: pw.TextStyle(fontSize: 13, color: PdfColors.grey700),
                textAlign: pw.TextAlign.center,
              ),
            ],

            pw.SizedBox(height: 32),

            // ── QR code ────────────────────────────────────────────
            pw.Container(
              padding: const pw.EdgeInsets.all(16),
              decoration: pw.BoxDecoration(
                border: pw.Border.all(color: PdfColors.grey300, width: 1),
                borderRadius: const pw.BorderRadius.all(pw.Radius.circular(8)),
              ),
              child: pw.Image(pw.MemoryImage(qrBytes), width: 220, height: 220),
            ),

            pw.SizedBox(height: 16),

            // ── UUID ───────────────────────────────────────────────
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
              'Bu QR kodu tarayarak asansör bilgilerine ulaşabilirsiniz.',
              style: const pw.TextStyle(fontSize: 11, color: PdfColors.grey700),
              textAlign: pw.TextAlign.center,
            ),

            pw.Spacer(),

            // ── Footer ────────────────────────────────────────────
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

// ── Status chip ───────────────────────────────────────────────────────────────

class _StatusChip extends StatelessWidget {
  const _StatusChip({required this.status});

  final String status;

  @override
  Widget build(BuildContext context) {
    final colors = AppThemeColors.of(context);
    final textTheme = Theme.of(context).textTheme;

    final (label, bg, fg) = _styles(status, colors);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        label,
        style: textTheme.labelSmall?.copyWith(
          fontWeight: FontWeight.w700,
          color: fg,
        ),
      ),
    );
  }

  static (String, Color, Color) _styles(String s, AppThemeColors colors) {
    switch (s) {
      case 'active':
        return ('Aktif', colors.successContainer, colors.success);
      case 'faulty':
        return ('Arızalı', colors.errorContainer, colors.error);
      case 'under_maintenance':
        return ('Bakımda', colors.warningContainer, colors.warning);
      default:
        return ('Pasif', colors.surfaceContainer, colors.outline);
    }
  }
}
