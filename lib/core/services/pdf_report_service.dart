import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';

import '../../features/elevator/models/elevator_model.dart';
import '../../features/maintenance/models/maintenance_log_model.dart';

// ── Corporate colour palette (mirrors app primary #004180) ───────────────────

const _headerBg = PdfColor.fromInt(0xFF004180);
const _headerFg = PdfColors.white;
const _rowAlt = PdfColor.fromInt(0xFFF0F4FB);
const _borderColor = PdfColor.fromInt(0xFFB0BEC5);
const _textDark = PdfColor.fromInt(0xFF1A1A2E);
const _textMuted = PdfColor.fromInt(0xFF546E7A);
const _accentIndigo = PdfColor.fromInt(0xFF3949AB);

// ── Public API ────────────────────────────────────────────────────────────────

/// Builds a corporate-styled A4 PDF for [elevator] covering [logs].
///
/// The document uses [PdfGoogleFonts.nunitoSans*] which supports the full
/// Latin-Extended-A block, including all Turkish characters (ç ş ğ ü ö ı İ).
Future<pw.Document> generateElevatorReport(
  ElevatorModel elevator,
  List<MaintenanceLogModel> logs,
) async {
  // Load Turkish-compatible fonts from the Google Fonts CDN (cached after first
  // download by the `printing` package).
  final regular = await PdfGoogleFonts.nunitoSansRegular();
  final bold = await PdfGoogleFonts.nunitoSansBold();
  final italic = await PdfGoogleFonts.nunitoSansItalic();
  final boldItalic = await PdfGoogleFonts.nunitoSansBoldItalic();

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
  // theme / orientation / clip / textDirection alongside it — the pdf library
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

// ── Section builders ──────────────────────────────────────────────────────────

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
        pw.Container(
          height: 1,
          color: PdfColor.fromInt(0xFF295999),
        ),
        pw.SizedBox(height: 12),
        pw.Row(
          mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
          children: [
            pw.Text(
              elevator.buildingName,
              style: pw.TextStyle(
                font: bold,
                fontSize: 14,
                color: _headerFg,
              ),
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
    padding: const pw.EdgeInsets.all(16),
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
              child: _infoRow('Bina Adı', elevator.buildingName, bold, regular),
            ),
            pw.SizedBox(width: 24),
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
        pw.SizedBox(height: 8),
        pw.Row(
          children: [
            pw.Expanded(
              child: _infoRow('Durum', _statusTr(elevator.status), bold, regular),
            ),
            pw.SizedBox(width: 24),
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
          // ── Header row ────────────────────────────────────────────────
          pw.TableRow(
            decoration: const pw.BoxDecoration(color: _accentIndigo),
            children: [
              _tableHeader('TARİH', bold),
              _tableHeader('TEKNİSYEN', bold),
              _tableHeader('YAPILAN İŞLEMLER / NOTLAR', bold),
              _tableHeader('ONAY', bold),
            ],
          ),
          // ── Data rows ─────────────────────────────────────────────────
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
                    log.isApproved ? '✓' : '⏳',
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

pw.Widget _buildFooter(
  pw.Font bold,
  pw.Font regular,
  DateTime generatedAt,
) {
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
              pw.SizedBox(height: 24),
              pw.Container(
                height: 0.8,
                width: 160,
                color: _textDark,
              ),
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
              style: pw.TextStyle(font: regular, fontSize: 10, color: _textDark),
            ),
            pw.SizedBox(height: 8),
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

// ── Small helpers ─────────────────────────────────────────────────────────────

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

// ── Date/string utilities ─────────────────────────────────────────────────────

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
    'Oca', 'Şub', 'Mar', 'Nis', 'May', 'Haz',
    'Tem', 'Ağu', 'Eyl', 'Eki', 'Kas', 'Ara',
  ];
  final from = DateTime(now.year, now.month - 5, 1);
  final fromNorm = DateTime(from.year + (from.month <= 0 ? -1 : 0),
      from.month <= 0 ? 12 + from.month : from.month, 1);
  return '${months[fromNorm.month - 1]} ${fromNorm.year} – '
      '${months[now.month - 1]} ${now.year}';
}

/// Shortens a UUID to a readable 8-character fragment.
String _shortId(String id) =>
    id.length > 8 ? '…${id.substring(id.length - 8)}' : id;

String _statusTr(String status) {
  switch (status.toLowerCase()) {
    case 'active':
      return 'Aktif';
    case 'faulty':
      return 'Arızalı';
    case 'under_maintenance':
      return 'Bakımda';
    case 'inactive':
      return 'Pasif';
    default:
      return 'Bilinmiyor';
  }
}
