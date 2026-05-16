import 'dart:io';
import 'dart:typed_data';

import 'package:intl/intl.dart';
import 'package:path_provider/path_provider.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;

/// A service that generates a corporate-branded maintenance report PDF.
///
/// The design mirrors the "Industrial Dark" identity using a deep-navy/slate
/// base with red brand accents — rendered in print-safe CMYK-approximate
/// RGB values since PDF uses a white paper background.
class PdfService {
  // ── Brand constants (PDF-safe, light-background equivalents) ─────────────
  static const _brandRed = PdfColor.fromInt(0xFFB91C1C);
  static const _slate900 = PdfColor.fromInt(0xFF0F172A);
  static const _slate700 = PdfColor.fromInt(0xFF334155);
  static const _slate500 = PdfColor.fromInt(0xFF64748B);
  static const _slate200 = PdfColor.fromInt(0xFFE2E8F0);
  static const _white = PdfColors.white;
  static const _black = PdfColors.black;

  /// Generates a PDF maintenance report and saves it to the temp directory.
  ///
  /// Returns the [File] pointing to the saved PDF.
  Future<File> generateMaintenanceReport({
    required String elevatorId,
    required String elevatorLocation,
    required String technicianName,
    required DateTime maintenanceDate,
    required Map<String, bool> checklist,
    required String notes,
    Uint8List? technicianSignatureBytes,
    Uint8List? customerSignatureBytes,
  }) async {
    final doc = pw.Document(
      title: 'Bakım Raporu',
      author: 'Asansör Yönetim Sistemi',
    );

    // Pre-process signature images
    final techSigImage = technicianSignatureBytes != null
        ? pw.MemoryImage(technicianSignatureBytes)
        : null;
    final custSigImage = customerSignatureBytes != null
        ? pw.MemoryImage(customerSignatureBytes)
        : null;

    doc.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(40),
        header: (context) => _buildHeader(maintenanceDate),
        footer: (context) => _buildFooter(context),
        build: (context) => [
          _buildInfoSection(
            elevatorId: elevatorId,
            elevatorLocation: elevatorLocation,
            technicianName: technicianName,
            maintenanceDate: maintenanceDate,
          ),
          pw.SizedBox(height: 24),
          _buildChecklistSection(checklist),
          if (notes.isNotEmpty) ...[
            pw.SizedBox(height: 24),
            _buildNotesSection(notes),
          ],
          pw.SizedBox(height: 24),
          _buildSignaturesSection(techSigImage, custSigImage),
        ],
      ),
    );

    final bytes = await doc.save();
    final dir = await getTemporaryDirectory();
    final dateStr = DateFormat('yyyyMMdd_HHmmss').format(maintenanceDate);
    final file = File('${dir.path}/maintenance_report_$dateStr.pdf');
    await file.writeAsBytes(bytes);
    return file;
  }

  // ── Header ────────────────────────────────────────────────────────────────
  pw.Widget _buildHeader(DateTime date) {
    return pw.Container(
      padding: const pw.EdgeInsets.only(bottom: 16),
      decoration: const pw.BoxDecoration(
        border: pw.Border(
          bottom: pw.BorderSide(color: _brandRed, width: 2.5),
        ),
      ),
      child: pw.Row(
        mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
        children: [
          pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              pw.Text(
                'ASANSÖR YÖNETİM SİSTEMİ',
                style: pw.TextStyle(
                  fontSize: 18,
                  fontWeight: pw.FontWeight.bold,
                  color: _slate900,
                ),
              ),
              pw.SizedBox(height: 4),
              pw.Text(
                'Teknik Bakım Raporu',
                style: pw.TextStyle(fontSize: 12, color: _slate500),
              ),
            ],
          ),
          pw.Container(
            padding: const pw.EdgeInsets.symmetric(horizontal: 14, vertical: 8),
            decoration: pw.BoxDecoration(
              color: _brandRed,
              borderRadius: const pw.BorderRadius.all(pw.Radius.circular(6)),
            ),
            child: pw.Text(
              DateFormat('dd.MM.yyyy').format(date),
              style: pw.TextStyle(
                fontSize: 13,
                fontWeight: pw.FontWeight.bold,
                color: _white,
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ── Info Section ──────────────────────────────────────────────────────────
  pw.Widget _buildInfoSection({
    required String elevatorId,
    required String elevatorLocation,
    required String technicianName,
    required DateTime maintenanceDate,
  }) {
    return pw.Container(
      margin: const pw.EdgeInsets.only(top: 16),
      padding: const pw.EdgeInsets.all(16),
      decoration: pw.BoxDecoration(
        color: const PdfColor.fromInt(0xFFF8FAFC),
        border: pw.Border.all(color: _slate200),
        borderRadius: const pw.BorderRadius.all(pw.Radius.circular(8)),
      ),
      child: pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          pw.Text(
            'BAKIMI YAPILAN ASANSÖR BİLGİLERİ',
            style: pw.TextStyle(
              fontSize: 10,
              fontWeight: pw.FontWeight.bold,
              color: _brandRed,
              letterSpacing: 1.2,
            ),
          ),
          pw.Divider(color: _slate200, height: 16),
          pw.Row(
            children: [
              _infoCell('Asansör ID', elevatorId),
              _infoCell('Konum', elevatorLocation),
            ],
          ),
          pw.SizedBox(height: 8),
          pw.Row(
            children: [
              _infoCell('Teknisyen', technicianName),
              _infoCell(
                'Bakım Tarihi',
                DateFormat('dd.MM.yyyy HH:mm').format(maintenanceDate),
              ),
            ],
          ),
        ],
      ),
    );
  }

  pw.Widget _infoCell(String label, String value) {
    return pw.Expanded(
      child: pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          pw.Text(label,
              style: pw.TextStyle(fontSize: 9, color: _slate500)),
          pw.SizedBox(height: 2),
          pw.Text(value,
              style: pw.TextStyle(
                  fontSize: 12,
                  fontWeight: pw.FontWeight.bold,
                  color: _slate900)),
        ],
      ),
    );
  }

  // ── Checklist ─────────────────────────────────────────────────────────────
  pw.Widget _buildChecklistSection(Map<String, bool> checklist) {
    return pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        _sectionTitle('KONTROL LİSTESİ'),
        pw.SizedBox(height: 8),
        pw.Table(
          border: pw.TableBorder.all(color: _slate200),
          columnWidths: {
            0: const pw.FlexColumnWidth(4),
            1: const pw.FlexColumnWidth(1),
          },
          children: [
            // Header row
            pw.TableRow(
              decoration: const pw.BoxDecoration(color: _slate900),
              children: [
                _tableCell('Kontrol Maddesi', isHeader: true),
                _tableCell('Durum', isHeader: true, center: true),
              ],
            ),
            ...checklist.entries.map((entry) {
              return pw.TableRow(
                decoration: pw.BoxDecoration(
                  color: checklist.keys.toList().indexOf(entry.key).isEven
                      ? const PdfColor.fromInt(0xFFF8FAFC)
                      : _white,
                ),
                children: [
                  _tableCell(entry.key),
                  pw.Padding(
                    padding: const pw.EdgeInsets.all(8),
                    child: pw.Center(
                      child: pw.Container(
                        width: 16,
                        height: 16,
                        decoration: pw.BoxDecoration(
                          color: entry.value ? _brandRed : _white,
                          border: pw.Border.all(
                            color: entry.value ? _brandRed : _slate500,
                          ),
                          borderRadius:
                              const pw.BorderRadius.all(pw.Radius.circular(3)),
                        ),
                        child: entry.value
                            ? pw.Center(
                                child: pw.Text('✓',
                                    style: pw.TextStyle(
                                        color: _white,
                                        fontSize: 11,
                                        fontWeight: pw.FontWeight.bold)),
                              )
                            : pw.SizedBox(),
                      ),
                    ),
                  ),
                ],
              );
            }),
          ],
        ),
        pw.SizedBox(height: 8),
        // Summary row
        pw.Row(
          mainAxisAlignment: pw.MainAxisAlignment.end,
          children: [
            pw.Text(
              'Tamamlanan: ${checklist.values.where((v) => v).length} / ${checklist.length}',
              style: pw.TextStyle(
                fontSize: 11,
                fontWeight: pw.FontWeight.bold,
                color: _slate700,
              ),
            ),
          ],
        ),
      ],
    );
  }

  pw.Widget _tableCell(String text,
      {bool isHeader = false, bool center = false}) {
    return pw.Padding(
      padding: const pw.EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      child: center
          ? pw.Center(
              child: pw.Text(
                text,
                style: pw.TextStyle(
                  fontSize: isHeader ? 10 : 11,
                  fontWeight:
                      isHeader ? pw.FontWeight.bold : pw.FontWeight.normal,
                  color: isHeader ? _white : _slate900,
                ),
              ),
            )
          : pw.Text(
              text,
              style: pw.TextStyle(
                fontSize: isHeader ? 10 : 11,
                fontWeight:
                    isHeader ? pw.FontWeight.bold : pw.FontWeight.normal,
                color: isHeader ? _white : _slate900,
              ),
            ),
    );
  }

  // ── Notes ─────────────────────────────────────────────────────────────────
  pw.Widget _buildNotesSection(String notes) {
    return pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        _sectionTitle('EK NOTLAR'),
        pw.SizedBox(height: 8),
        pw.Container(
          width: double.infinity,
          padding: const pw.EdgeInsets.all(12),
          decoration: pw.BoxDecoration(
            border: pw.Border.all(color: _slate200),
            borderRadius: const pw.BorderRadius.all(pw.Radius.circular(6)),
          ),
          child: pw.Text(notes,
              style: pw.TextStyle(fontSize: 11, color: _slate700)),
        ),
      ],
    );
  }

  // ── Signatures ────────────────────────────────────────────────────────────
  pw.Widget _buildSignaturesSection(
      pw.MemoryImage? techSig, pw.MemoryImage? custSig) {
    return pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        _sectionTitle('İMZALAR'),
        pw.SizedBox(height: 12),
        pw.Row(
          children: [
            pw.Expanded(child: _signatureBox('Teknisyen İmzası', techSig)),
            pw.SizedBox(width: 24),
            pw.Expanded(
                child: _signatureBox('Bina Yetkilisi İmzası', custSig)),
          ],
        ),
      ],
    );
  }

  pw.Widget _signatureBox(String label, pw.MemoryImage? image) {
    return pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        pw.Text(label,
            style: pw.TextStyle(fontSize: 10, color: _slate500)),
        pw.SizedBox(height: 6),
        pw.Container(
          height: 100,
          decoration: pw.BoxDecoration(
            border: pw.Border.all(color: _slate200),
            borderRadius: const pw.BorderRadius.all(pw.Radius.circular(6)),
          ),
          child: image != null
              ? pw.Padding(
                  padding: const pw.EdgeInsets.all(8),
                  child: pw.Image(image, fit: pw.BoxFit.contain),
                )
              : pw.Center(
                  child: pw.Text('İmza Alınmadı',
                      style: pw.TextStyle(fontSize: 10, color: _slate500)),
                ),
        ),
        pw.SizedBox(height: 6),
        pw.Divider(color: _black, height: 1),
        pw.SizedBox(height: 4),
        pw.Text(label.split(' ').first,
            style: pw.TextStyle(fontSize: 9, color: _slate500)),
      ],
    );
  }

  // ── Footer ────────────────────────────────────────────────────────────────
  pw.Widget _buildFooter(pw.Context context) {
    return pw.Container(
      padding: const pw.EdgeInsets.only(top: 8),
      decoration: const pw.BoxDecoration(
        border: pw.Border(
          top: pw.BorderSide(color: _slate200),
        ),
      ),
      child: pw.Row(
        mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
        children: [
          pw.Text(
            'Bu belge Asansör Yönetim Sistemi tarafından otomatik oluşturulmuştur.',
            style: pw.TextStyle(fontSize: 8, color: _slate500),
          ),
          pw.Text(
            'Sayfa ${context.pageNumber} / ${context.pagesCount}',
            style: pw.TextStyle(fontSize: 8, color: _slate500),
          ),
        ],
      ),
    );
  }

  // ── Helper ────────────────────────────────────────────────────────────────
  pw.Widget _sectionTitle(String title) {
    return pw.Row(
      children: [
        pw.Container(
          width: 4,
          height: 16,
          color: _brandRed,
          margin: const pw.EdgeInsets.only(right: 8),
        ),
        pw.Text(
          title,
          style: pw.TextStyle(
            fontSize: 11,
            fontWeight: pw.FontWeight.bold,
            color: _slate900,
            letterSpacing: 1.0,
          ),
        ),
      ],
    );
  }

  // ── Elevator Report ────────────────────────────────────────────────────────
  Future<pw.Document> generateElevatorReport(
      dynamic elevator, List<dynamic> logs) async {
    final doc = pw.Document(
      title: 'Asansör Geçmiş Raporu',
      author: 'Asansör Yönetim Sistemi',
    );

    doc.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(40),
        header: (context) => _buildHeader(DateTime.now()),
        footer: (context) => _buildFooter(context),
        build: (context) => [
          _buildInfoSection(
            elevatorId: elevator.id as String,
            elevatorLocation: (elevator.address as String?) ?? 'Adres belirtilmemiş',
            technicianName: 'Sistem Raporu',
            maintenanceDate: DateTime.now(),
          ),
          pw.SizedBox(height: 24),
          _sectionTitle('BAKIM GEÇMİŞİ'),
          pw.SizedBox(height: 8),
          pw.Table(
            border: pw.TableBorder.all(color: _slate200),
            columnWidths: {
              0: const pw.FlexColumnWidth(2),
              1: const pw.FlexColumnWidth(3),
              2: const pw.FlexColumnWidth(2),
              3: const pw.FlexColumnWidth(2),
            },
            children: [
              pw.TableRow(
                decoration: const pw.BoxDecoration(color: _slate900),
                children: [
                  _tableCell('Tarih', isHeader: true),
                  _tableCell('Notlar', isHeader: true),
                  _tableCell('Teknisyen', isHeader: true),
                  _tableCell('Durum', isHeader: true, center: true),
                ],
              ),
              ...logs.map((log) {
                return pw.TableRow(
                  decoration: pw.BoxDecoration(
                    color: logs.indexOf(log).isEven
                        ? const PdfColor.fromInt(0xFFF8FAFC)
                        : _white,
                  ),
                  children: [
                    _tableCell(DateFormat('dd.MM.yyyy').format(log.maintenanceDate as DateTime)),
                    _tableCell((log.notes as String?) ?? '-'),
                    _tableCell((log.technicianName as String?) ?? (log.technicianId as String).substring(0, 8)),
                    _tableCell((log.isApproved as bool) ? 'ONAYLANDI' : 'BEKLİYOR', center: true),
                  ],
                );
              }),
            ],
          ),
        ],
      ),
    );

    return doc;
  }
}
