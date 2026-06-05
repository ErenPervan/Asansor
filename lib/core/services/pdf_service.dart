import 'package:asansor/core/theme/app_spacing.dart';
import 'dart:io';

import 'package:path_provider/path_provider.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import 'package:flutter/services.dart';

import '../enums/app_enums.dart';
import '../../features/maintenance/models/maintenance_log_model.dart';
import '../../features/elevator/models/elevator_model.dart';

// Alias to match the requested parameter name
typedef MaintenanceLog = MaintenanceLogModel;

/// A simple model to represent a checklist item in the PDF.
/// If you already have this defined elsewhere, you can replace this with your import.
class ChecklistItem {
  final String label;
  final bool isPassed;

  const ChecklistItem({required this.label, required this.isPassed});
}

class PdfService {
  static PdfService _instance = PdfService._internal();
  PdfService._internal();
  factory PdfService() => _instance;

  static set instance(PdfService mock) => _instance = mock;

  /// Generates a highly formatted, Material 3 style PDF report for a maintenance task.
  /// It prepares the file in a temporary directory ready to be uploaded to Supabase Storage.
  Future<File> generateMaintenanceReport({
    required MaintenanceLog log,
    required List<ChecklistItem> checklistDetails,
    String? elevatorLocation,
    String? technicianName,
    List<String>? mediaUrls,
    String? signatureUrl,
    String? customerSignatureUrl,
  }) async {
    final pdf = pw.Document();

    // Load fonts from local assets for offline support
    final regularFont = pw.Font.ttf(
      await rootBundle.load('assets/fonts/NunitoSans-Regular.ttf'),
    );
    final boldFont = pw.Font.ttf(
      await rootBundle.load('assets/fonts/NunitoSans-Bold.ttf'),
    );
    final iconFont = await PdfGoogleFonts.materialIcons();

    final theme = pw.ThemeData.withFont(
      base: regularFont,
      bold: boldFont,
      icons: iconFont,
    );

    // Fetch images asynchronously via the printing package's networkImage utility
    pw.ImageProvider? signatureImageProvider;
    if (signatureUrl != null && signatureUrl.isNotEmpty) {
      try {
        signatureImageProvider = await networkImage(signatureUrl);
      } catch (_) {
        // Fallback to null if the signature image cannot be fetched
      }
    }

    pw.ImageProvider? customerSignatureImageProvider;
    if (customerSignatureUrl != null && customerSignatureUrl.isNotEmpty) {
      try {
        customerSignatureImageProvider = await networkImage(
          customerSignatureUrl,
        );
      } catch (_) {
        // Fallback to null if the signature image cannot be fetched
      }
    }

    final List<pw.ImageProvider> mediaImageProviders = [];
    if (mediaUrls != null) {
      for (final url in mediaUrls) {
        if (url.isNotEmpty) {
          try {
            final image = await networkImage(url);
            mediaImageProviders.add(image);
          } catch (_) {
            // Ignore individual image load failures
          }
        }
      }
    }

    // Material 3 inspired colors
    const primaryColor = PdfColor.fromInt(0xFF005AC1);
    const surfaceColor = PdfColor.fromInt(0xFFF3F4F9);
    const onSurface = PdfColor.fromInt(0xFF1A1C1E);
    const successColor = PdfColor.fromInt(0xFF146C2E);
    const errorColor = PdfColor.fromInt(0xFFBA1A1A);
    const outlineColor = PdfColor.fromInt(0xFF73777F);

    pdf.addPage(
      pw.MultiPage(
        pageTheme: pw.PageTheme(
          pageFormat: PdfPageFormat.a4,
          margin: const pw.EdgeInsets.all(AppSpacing.xl),
          theme: theme,
        ),
        build: (context) {
          return [
            // 1. HEADER SECTION
            pw.Container(
              padding: const pw.EdgeInsets.all(AppSpacing.md),
              decoration: pw.BoxDecoration(
                color: surfaceColor,
                borderRadius: const pw.BorderRadius.all(pw.Radius.circular(12)),
              ),
              child: pw.Row(
                crossAxisAlignment: pw.CrossAxisAlignment.start,
                mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                children: [
                  pw.Column(
                    crossAxisAlignment: pw.CrossAxisAlignment.start,
                    children: [
                      // Corporate Logo Placeholder
                      pw.Container(
                        width: 50,
                        height: 50,
                        decoration: const pw.BoxDecoration(
                          color: primaryColor,
                          shape: pw.BoxShape.circle,
                        ),
                        child: pw.Center(
                          child: pw.Text(
                            'LOGO',
                            style: pw.TextStyle(
                              color: PdfColors.white,
                              fontWeight: pw.FontWeight.bold,
                              fontSize: 12,
                            ),
                          ),
                        ),
                      ),
                      pw.SizedBox(height: AppSpacing.md),
                      pw.Text(
                        'MAINTENANCE REPORT',
                        style: pw.TextStyle(
                          fontSize: 22,
                          fontWeight: pw.FontWeight.bold,
                          color: primaryColor,
                        ),
                      ),
                    ],
                  ),
                  pw.Column(
                    crossAxisAlignment: pw.CrossAxisAlignment.end,
                    children: [
                      _buildHeaderRow(
                        'Date:',
                        _formatDate(log.maintenanceDate),
                        boldFont,
                      ),
                      pw.SizedBox(height: 6),
                      _buildHeaderRow('Elevator ID:', log.elevatorId, boldFont),
                      if (elevatorLocation != null) ...[
                        pw.SizedBox(height: 6),
                        _buildHeaderRow(
                          'Location:',
                          elevatorLocation,
                          boldFont,
                        ),
                      ],
                      pw.SizedBox(height: 6),
                      _buildHeaderRow(
                        'Technician:',
                        technicianName ?? log.technicianId,
                        boldFont,
                      ),
                    ],
                  ),
                ],
              ),
            ),
            pw.SizedBox(height: AppSpacing.xl),

            // 2. BODY SECTION 1: CHECKLIST
            pw.Text(
              'Checklist Overview',
              style: pw.TextStyle(
                fontSize: 16,
                fontWeight: pw.FontWeight.bold,
                color: primaryColor,
              ),
            ),
            pw.SizedBox(height: 12),
            pw.Table(
              border: pw.TableBorder.all(color: outlineColor, width: 0.5),
              children: [
                pw.TableRow(
                  decoration: const pw.BoxDecoration(color: surfaceColor),
                  children: [
                    pw.Padding(
                      padding: const pw.EdgeInsets.all(10),
                      child: pw.Text(
                        'Item Description',
                        style: pw.TextStyle(
                          fontWeight: pw.FontWeight.bold,
                          fontSize: 12,
                        ),
                      ),
                    ),
                    pw.Padding(
                      padding: const pw.EdgeInsets.all(10),
                      child: pw.Text(
                        'Status',
                        style: pw.TextStyle(
                          fontWeight: pw.FontWeight.bold,
                          fontSize: 12,
                        ),
                      ),
                    ),
                  ],
                ),
                ...checklistDetails.map(
                  (item) => pw.TableRow(
                    children: [
                      pw.Padding(
                        padding: const pw.EdgeInsets.all(10),
                        child: pw.Text(
                          item.label,
                          style: const pw.TextStyle(fontSize: 11),
                        ),
                      ),
                      pw.Padding(
                        padding: const pw.EdgeInsets.all(10),
                        child: pw.Row(
                          children: [
                            pw.Icon(
                              item.isPassed
                                  ? const pw.IconData(0xe86c) // check_circle
                                  : const pw.IconData(0xe5c9), // cancel
                              color: item.isPassed ? successColor : errorColor,
                              size: 14,
                            ),
                            pw.SizedBox(width: 6),
                            pw.Text(
                              item.isPassed ? 'Passed' : 'Action Required',
                              style: pw.TextStyle(
                                color: item.isPassed
                                    ? successColor
                                    : errorColor,
                                fontWeight: pw.FontWeight.bold,
                                fontSize: 11,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            pw.SizedBox(height: AppSpacing.xl),

            // 3. BODY SECTION 2: MEDIA
            if (mediaImageProviders.isNotEmpty) ...[
              pw.Text(
                'Media Attachments',
                style: pw.TextStyle(
                  fontSize: 16,
                  fontWeight: pw.FontWeight.bold,
                  color: primaryColor,
                ),
              ),
              pw.SizedBox(height: 12),
              pw.Wrap(
                spacing: 16,
                runSpacing: 16,
                children: mediaImageProviders.map((img) {
                  return pw.Container(
                    width: 140,
                    height: 140,
                    decoration: pw.BoxDecoration(
                      borderRadius: const pw.BorderRadius.all(
                        pw.Radius.circular(8),
                      ),
                      border: pw.Border.all(color: outlineColor, width: 0.5),
                      image: pw.DecorationImage(
                        image: img,
                        fit: pw.BoxFit.cover,
                      ),
                    ),
                  );
                }).toList(),
              ),
              pw.SizedBox(height: AppSpacing.xl),
            ],

            // NOTES SECTION
            if (log.notes != null && log.notes!.isNotEmpty) ...[
              pw.Text(
                'Technician Notes',
                style: pw.TextStyle(
                  fontSize: 16,
                  fontWeight: pw.FontWeight.bold,
                  color: primaryColor,
                ),
              ),
              pw.SizedBox(height: AppSpacing.sm),
              pw.Container(
                width: double.infinity,
                padding: const pw.EdgeInsets.all(12),
                decoration: pw.BoxDecoration(
                  color: surfaceColor,
                  borderRadius: const pw.BorderRadius.all(
                    pw.Radius.circular(8),
                  ),
                ),
                child: pw.Text(
                  log.notes!,
                  style: const pw.TextStyle(fontSize: 11),
                ),
              ),
              pw.SizedBox(height: AppSpacing.xl),
            ],

            // 4. FOOTER: SIGNATURES
            pw.Spacer(),
            pw.Divider(color: outlineColor, thickness: 0.5),
            pw.SizedBox(height: AppSpacing.md),
            pw.Row(
              mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
              crossAxisAlignment: pw.CrossAxisAlignment.end,
              children: [
                pw.Text(
                  'End of Report\nGenerated securely by Asansor System',
                  style: pw.TextStyle(fontSize: 9, color: outlineColor),
                ),
                pw.Row(
                  children: [
                    _buildSignatureBlock(
                      signatureImageProvider,
                      'Technician Signature',
                      onSurface,
                    ),
                    pw.SizedBox(width: AppSpacing.lg),
                    _buildSignatureBlock(
                      customerSignatureImageProvider,
                      'Customer Signature',
                      onSurface,
                    ),
                  ],
                ),
              ],
            ),
          ];
        },
      ),
    );

    // Prepare temp file for Supabase upload
    final outputDir = await getTemporaryDirectory();
    final fileName =
        'maintenance_report_${log.id}_${DateTime.now().millisecondsSinceEpoch}.pdf';
    final file = File('${outputDir.path}/$fileName');

    // Save generated PDF to file
    final bytes = await pdf.save();
    await file.writeAsBytes(bytes);

    return file;
  }

  pw.Widget _buildHeaderRow(String label, String value, pw.Font boldFont) {
    return pw.Row(
      mainAxisSize: pw.MainAxisSize.min,
      children: [
        pw.Text(
          label,
          style: pw.TextStyle(
            color: PdfColor.fromInt(0xFF73777F),
            fontSize: 11,
          ),
        ),
        pw.SizedBox(width: AppSpacing.sm),
        pw.Text(
          value,
          style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 12),
        ),
      ],
    );
  }

  pw.Widget _buildSignatureBlock(
    pw.ImageProvider? imageProvider,
    String label,
    PdfColor lineColor,
  ) {
    return pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.center,
      children: [
        if (imageProvider != null)
          pw.Container(
            height: 60,
            width: 120,
            child: pw.Image(imageProvider, fit: pw.BoxFit.contain),
          )
        else
          pw.SizedBox(height: 60),
        pw.SizedBox(height: AppSpacing.sm),
        pw.Container(width: 140, height: 1, color: lineColor),
        pw.SizedBox(height: 4),
        pw.Text(
          label,
          style: pw.TextStyle(
            fontWeight: pw.FontWeight.bold,
            fontSize: 10,
            color: lineColor,
          ),
        ),
      ],
    );
  }

  String _formatDate(DateTime date) {
    final d = date.toLocal();
    return '${d.day.toString().padLeft(2, '0')}/${d.month.toString().padLeft(2, '0')}/${d.year}';
  }

  // --- Migrated from pdf_report_service.dart ---

  static const _headerBg = PdfColor.fromInt(0xFF004180);
  static const _headerFg = PdfColors.white;
  static const _rowAlt = PdfColor.fromInt(0xFFF0F4FB);
  static const _borderColor = PdfColor.fromInt(0xFFB0BEC5);
  static const _textDark = PdfColor.fromInt(0xFF1A1A2E);
  static const _textMuted = PdfColor.fromInt(0xFF546E7A);
  static const _accentIndigo = PdfColor.fromInt(0xFF3949AB);

  // ─â‚¬─â‚¬ Public API ─â‚¬─â‚¬─â‚¬─â‚¬─â‚¬─â‚¬─â‚¬─â‚¬─â‚¬─â‚¬─â‚¬─â‚¬─â‚¬─â‚¬─â‚¬─â‚¬─â‚¬─â‚¬─â‚¬─â‚¬─â‚¬─â‚¬─â‚¬─â‚¬─â‚¬─â‚¬─â‚¬─â‚¬─â‚¬─â‚¬─â‚¬─â‚¬─â‚¬─â‚¬─â‚¬─â‚¬─â‚¬─â‚¬─â‚¬─â‚¬─â‚¬─â‚¬─â‚¬─â‚¬─â‚¬─â‚¬─â‚¬─â‚¬─â‚¬─â‚¬─â‚¬─â‚¬─â‚¬─â‚¬─â‚¬─â‚¬─â‚¬─â‚¬─â‚¬─â‚¬─â‚¬─â‚¬─â‚¬─â‚¬

  /// Builds a corporate-styled A4 PDF for [elevator] covering [logs].
  ///
  /// The document uses [PdfGoogleFonts.nunitoSans*] which supports the full
  /// Latin-Extended-A block, including all Turkish characters (ç ş ğ ü ö ı İ).
  Future<pw.Document> generateElevatorReport(
    ElevatorModel elevator,
    List<MaintenanceLogModel> logs,
  ) async {
    // Load Turkish-compatible fonts from local assets to support offline generation
    final regular = pw.Font.ttf(
      await rootBundle.load('assets/fonts/NunitoSans-Regular.ttf'),
    );
    final bold = pw.Font.ttf(
      await rootBundle.load('assets/fonts/NunitoSans-Bold.ttf'),
    );
    final italic = pw.Font.ttf(
      await rootBundle.load('assets/fonts/NunitoSans-Italic.ttf'),
    );
    final boldItalic = pw.Font.ttf(
      await rootBundle.load('assets/fonts/NunitoSans-BoldItalic.ttf'),
    );

    final baseTheme = pw.ThemeData.withFont(
      base: regular,
      bold: bold,
      italic: italic,
      boldItalic: boldItalic,
    );

    final now = DateTime.now();
    final period = _periodLabel(now);

    final doc = pw.Document(theme: baseTheme);

    // pageTheme owns ALL page-level settings; never pass pageFormat / margin /
    // theme / orientation / clip / textDirection alongside it Ã¢â‚¬â€ the pdf library
    // asserts that the two styles are mutually exclusive.
    doc.addPage(
      pw.MultiPage(
        pageTheme: pw.PageTheme(
          pageFormat: PdfPageFormat.a4,
          // Content margin kept inside pageTheme so the outer border sits flush
          // against the page edge while the content is properly inset.
          margin: const pw.EdgeInsets.symmetric(horizontal: 36, vertical: 36),
          theme: baseTheme,
          buildBackground: (context) => pw.FullPage(
            ignoreMargins: true,
            child: pw.Container(
              margin: const pw.EdgeInsets.all(14),
              decoration: pw.BoxDecoration(
                border: pw.Border.all(color: _accentIndigo, width: 1.8),
              ),
            ),
          ),
        ),
        build: (context) => [
          _buildHeader(elevator, bold, regular, period),
          pw.SizedBox(height: 18),
          _buildInfoSection(elevator, bold, regular, period),
          pw.SizedBox(height: 20),
          _buildTable(logs, bold, regular, italic),
          pw.SizedBox(height: 28),
          _buildFooter(bold, regular, now),
        ],
      ),
    );

    return doc;
  }

  // ─â‚¬─â‚¬ Section builders ─â‚¬─â‚¬─â‚¬─â‚¬─â‚¬─â‚¬─â‚¬─â‚¬─â‚¬─â‚¬─â‚¬─â‚¬─â‚¬─â‚¬─â‚¬─â‚¬─â‚¬─â‚¬─â‚¬─â‚¬─â‚¬─â‚¬─â‚¬─â‚¬─â‚¬─â‚¬─â‚¬─â‚¬─â‚¬─â‚¬─â‚¬─â‚¬─â‚¬─â‚¬─â‚¬─â‚¬─â‚¬─â‚¬─â‚¬─â‚¬─â‚¬─â‚¬─â‚¬─â‚¬─â‚¬─â‚¬─â‚¬─â‚¬─â‚¬─â‚¬─â‚¬─â‚¬─â‚¬─â‚¬─â‚¬─â‚¬─â‚¬─â‚¬

  pw.Widget _buildHeader(
    ElevatorModel elevator,
    pw.Font bold,
    pw.Font regular,
    String period,
  ) {
    return pw.Container(
      width: double.infinity,
      padding: const pw.EdgeInsets.symmetric(horizontal: 24, vertical: 20),
      decoration: const pw.BoxDecoration(
        color: _headerBg,
        borderRadius: pw.BorderRadius.all(pw.Radius.circular(6)),
      ),
      child: pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          pw.Text(
            'ASANSÖR BAKIM RAPORU',
            style: pw.TextStyle(
              font: bold,
              fontSize: 20,
              color: _headerFg,
              letterSpacing: 1.2,
            ),
          ),
          pw.SizedBox(height: 4),
          pw.Text(
            'ELEVATOR MAINTENANCE REPORT',
            style: pw.TextStyle(
              font: regular,
              fontSize: 10,
              color: PdfColor.fromInt(0xFFB0C4DE),
              letterSpacing: 0.8,
            ),
          ),
          pw.SizedBox(height: 12),
          pw.Container(height: 1, color: PdfColor.fromInt(0xFF295999)),
          pw.SizedBox(height: 12),
          pw.Row(
            mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
            children: [
              pw.Text(
                elevator.buildingName,
                style: pw.TextStyle(font: bold, fontSize: 14, color: _headerFg),
              ),
              pw.Text(
                period,
                style: pw.TextStyle(
                  font: regular,
                  fontSize: 10,
                  color: PdfColor.fromInt(0xFFB0C4DE),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  pw.Widget _buildInfoSection(
    ElevatorModel elevator,
    pw.Font bold,
    pw.Font regular,
    String period,
  ) {
    return pw.Container(
      padding: const pw.EdgeInsets.all(AppSpacing.md),
      decoration: pw.BoxDecoration(
        color: _rowAlt,
        borderRadius: const pw.BorderRadius.all(pw.Radius.circular(6)),
        border: pw.Border.all(color: _borderColor, width: 0.8),
      ),
      child: pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          _sectionLabel('ASANSÖR BİLGİLERİ', bold),
          pw.SizedBox(height: 10),
          pw.Row(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              pw.Expanded(
                child: _infoRow(
                  'Bina Adı',
                  elevator.buildingName,
                  bold,
                  regular,
                ),
              ),
              pw.SizedBox(width: AppSpacing.lg),
              pw.Expanded(
                child: _infoRow(
                  'Adres',
                  elevator.address ?? 'Belirtilmemiş',
                  bold,
                  regular,
                ),
              ),
            ],
          ),
          pw.SizedBox(height: AppSpacing.sm),
          pw.Row(
            children: [
              pw.Expanded(
                child: _infoRow(
                  'Durum',
                  _statusTr(elevator.status),
                  bold,
                  regular,
                ),
              ),
              pw.SizedBox(width: AppSpacing.lg),
              pw.Expanded(
                child: _infoRow('Rapor Dönemi', period, bold, regular),
              ),
            ],
          ),
        ],
      ),
    );
  }

  pw.Widget _buildTable(
    List<MaintenanceLogModel> logs,
    pw.Font bold,
    pw.Font regular,
    pw.Font italic,
  ) {
    return pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        _sectionLabel('BAKIM GEÇMİŞİ', bold),
        pw.SizedBox(height: 10),
        pw.Table(
          border: pw.TableBorder.all(color: _borderColor, width: 0.6),
          columnWidths: {
            0: const pw.FixedColumnWidth(90),
            1: const pw.FixedColumnWidth(110),
            2: const pw.FlexColumnWidth(),
            3: const pw.FixedColumnWidth(72),
          },
          children: [
            // ————————————————— Header row ——————————————————————————————————————————————————————————————————————————————————————————————————————————————————————————————————————
            pw.TableRow(
              decoration: const pw.BoxDecoration(color: _accentIndigo),
              children: [
                _tableHeader('TARİH', bold),
                _tableHeader('TEKNİSYEN', bold),
                _tableHeader('YAPILAN İŞLEMLER / NOTLAR', bold),
                _tableHeader('ONAY', bold),
              ],
            ),
            // ————————————————— Data rows ———————————————————————————————————————————————————————————————————————————————————————————————————————————————————————————————————————
            if (logs.isEmpty)
              pw.TableRow(
                children: [
                  pw.Padding(
                    padding: const pw.EdgeInsets.all(10),
                    child: pw.Text(
                      'Bu dönemde kayıt bulunamadı.',
                      style: pw.TextStyle(font: italic, color: _textMuted),
                      textAlign: pw.TextAlign.center,
                    ),
                  ),
                  pw.SizedBox(),
                  pw.SizedBox(),
                  pw.SizedBox(),
                ],
              )
            else
              ...logs.asMap().entries.map((entry) {
                final i = entry.key;
                final log = entry.value;
                final bg = i.isOdd ? _rowAlt : PdfColors.white;
                return pw.TableRow(
                  decoration: pw.BoxDecoration(color: bg),
                  children: [
                    _tableCell(_fmtDate(log.maintenanceDate), regular),
                    _tableCell(_shortId(log.technicianId), regular),
                    _tableCell(log.notes ?? '—', regular),
                    _tableCellCenter(
                      log.isApproved ? '✓' : '✗',
                      log.isApproved ? bold : regular,
                      color: log.isApproved
                          ? PdfColor.fromInt(0xFF1B6B3A)
                          : _textMuted,
                    ),
                  ],
                );
              }),
          ],
        ),
        pw.SizedBox(height: 6),
        pw.Text(
          'Toplam kayıt: ${logs.length}',
          style: pw.TextStyle(font: regular, fontSize: 9, color: _textMuted),
        ),
      ],
    );
  }

  pw.Widget _buildFooter(pw.Font bold, pw.Font regular, DateTime generatedAt) {
    return pw.Container(
      padding: const pw.EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      decoration: pw.BoxDecoration(
        border: pw.Border.all(color: _borderColor, width: 0.8),
        borderRadius: const pw.BorderRadius.all(pw.Radius.circular(6)),
      ),
      child: pw.Row(
        crossAxisAlignment: pw.CrossAxisAlignment.end,
        children: [
          // Signature block
          pw.Expanded(
            child: pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                pw.Text(
                  'Onaylayan / İmza',
                  style: pw.TextStyle(
                    font: bold,
                    fontSize: 9,
                    color: _textMuted,
                    letterSpacing: 0.6,
                  ),
                ),
                pw.SizedBox(height: AppSpacing.lg),
                pw.Container(height: 0.8, width: 160, color: _textDark),
                pw.SizedBox(height: 4),
                pw.Text(
                  'Ad Soyad / Unvan',
                  style: pw.TextStyle(
                    font: regular,
                    fontSize: 8,
                    color: _textMuted,
                  ),
                ),
              ],
            ),
          ),
          // Timestamp + disclaimer
          pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.end,
            children: [
              pw.Text(
                'Oluşturulma Tarihi',
                style: pw.TextStyle(
                  font: bold,
                  fontSize: 9,
                  color: _textMuted,
                  letterSpacing: 0.5,
                ),
              ),
              pw.SizedBox(height: 4),
              pw.Text(
                _fmtDateTime(generatedAt),
                style: pw.TextStyle(
                  font: regular,
                  fontSize: 10,
                  color: _textDark,
                ),
              ),
              pw.SizedBox(height: AppSpacing.sm),
              pw.Text(
                'Bu rapor otomatik olarak oluşturulmuştur.',
                style: pw.TextStyle(
                  font: regular,
                  fontSize: 8,
                  color: _textMuted,
                  fontStyle: pw.FontStyle.italic,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  // ————————————————— Small helpers ——————————————————————————————————————————————————————————————————————————————————————————————————————————————————————————————————————

  pw.Widget _sectionLabel(String text, pw.Font bold) {
    return pw.Row(
      children: [
        pw.Container(
          width: 3,
          height: 14,
          color: _accentIndigo,
          margin: const pw.EdgeInsets.only(right: 8),
        ),
        pw.Text(
          text,
          style: pw.TextStyle(
            font: bold,
            fontSize: 10,
            color: _accentIndigo,
            letterSpacing: 1.0,
          ),
        ),
      ],
    );
  }

  pw.Widget _infoRow(
    String label,
    String value,
    pw.Font bold,
    pw.Font regular,
  ) {
    return pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        pw.Text(
          label.toUpperCase(),
          style: pw.TextStyle(
            font: bold,
            fontSize: 8,
            color: _textMuted,
            letterSpacing: 0.8,
          ),
        ),
        pw.SizedBox(height: 2),
        pw.Text(
          value,
          style: pw.TextStyle(font: regular, fontSize: 11, color: _textDark),
        ),
      ],
    );
  }

  pw.Widget _tableHeader(String text, pw.Font bold) {
    return pw.Padding(
      padding: const pw.EdgeInsets.symmetric(horizontal: 8, vertical: 7),
      child: pw.Text(
        text,
        style: pw.TextStyle(
          font: bold,
          fontSize: 9,
          color: _headerFg,
          letterSpacing: 0.5,
        ),
      ),
    );
  }

  pw.Widget _tableCell(String text, pw.Font regular) {
    return pw.Padding(
      padding: const pw.EdgeInsets.symmetric(horizontal: 8, vertical: 7),
      child: pw.Text(
        text,
        style: pw.TextStyle(font: regular, fontSize: 9, color: _textDark),
      ),
    );
  }

  pw.Widget _tableCellCenter(String text, pw.Font font, {PdfColor? color}) {
    return pw.Padding(
      padding: const pw.EdgeInsets.symmetric(horizontal: 8, vertical: 7),
      child: pw.Center(
        child: pw.Text(
          text,
          style: pw.TextStyle(
            font: font,
            fontSize: 10,
            color: color ?? _textDark,
          ),
        ),
      ),
    );
  }

  // ————————————————— Date/string utilities ——————————————————————————————————————————————————————————————————————————————————————————————————————————————————————————————————————

  String _fmtDate(DateTime dt) {
    final d = dt.toLocal();
    return '${d.day.toString().padLeft(2, '0')}/'
        '${d.month.toString().padLeft(2, '0')}/'
        '${d.year}';
  }

  String _fmtDateTime(DateTime dt) {
    final d = dt.toLocal();
    return '${_fmtDate(d)}  '
        '${d.hour.toString().padLeft(2, '0')}:'
        '${d.minute.toString().padLeft(2, '0')}';
  }

  /// Returns a human-readable "last 6 months" period label, e.g. "Eki 2025 – Nis 2026".
  String _periodLabel(DateTime now) {
    const months = [
      'Oca',
      'Şub',
      'Mar',
      'Nis',
      'May',
      'Haz',
      'Tem',
      'Ağu',
      'Eyl',
      'Eki',
      'Kas',
      'Ara',
    ];
    final from = DateTime(now.year, now.month - 5, 1);
    final fromNorm = DateTime(
      from.year + (from.month <= 0 ? -1 : 0),
      from.month <= 0 ? 12 + from.month : from.month,
      1,
    );
    return '${months[fromNorm.month - 1]} ${fromNorm.year} – '
        '${months[now.month - 1]} ${now.year}';
  }

  /// Shortens a UUID to a readable 8-character fragment.
  String _shortId(String id) =>
      id.length > 8 ? '…${id.substring(id.length - 8)}' : id;

  String _statusTr(ElevatorStatus status) {
    switch (status) {
      case ElevatorStatus.active:
        return 'Aktif';
      case ElevatorStatus.faulty:
        return 'Arızalı';
      case ElevatorStatus.underMaintenance:
        return 'Bakımda';
      case ElevatorStatus.inactive:
        return 'Pasif';
    }
  }
}
