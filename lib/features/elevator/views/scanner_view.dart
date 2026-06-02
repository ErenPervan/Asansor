import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'package:image_picker/image_picker.dart';
import '../../../core/widgets/error_state.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/constants/app_durations.dart';

class ScannerView extends ConsumerStatefulWidget {
  const ScannerView({super.key});

  @override
  ConsumerState<ScannerView> createState() => _ScannerViewState();
}

class _ScannerViewState extends ConsumerState<ScannerView>
    with SingleTickerProviderStateMixin {
  late final MobileScannerController _controller;
  late final AnimationController _lineAnim;

  bool _isProcessing = false;

  static const _uuidRegex =
      r'^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}'
      r'-[0-9a-f]{4}-[0-9a-f]{12}$';

  @override
  void initState() {
    super.initState();
    _controller = MobileScannerController(
      detectionSpeed: DetectionSpeed.normal,
      facing: CameraFacing.back,
      torchEnabled: false,
    );
    // Scan-line animation — sweeps top-to-bottom and repeats.
    _lineAnim = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1800),
    )..repeat(reverse: true);
  }

  @override
  void dispose() {
    _lineAnim.dispose();
    _controller.dispose();
    super.dispose();
  }

  Future<void> _onDetect(BarcodeCapture capture) async {
    // Guard: ignore reads while one is already being processed.
    if (_isProcessing) return;

    final rawValue = capture.barcodes.firstOrNull?.rawValue?.trim();
    if (rawValue == null || rawValue.isEmpty) return;

    // Stop the camera immediately so we don't get further reads.
    setState(() => _isProcessing = true);
    await _controller.stop();

    if (!mounted) return;

    final isValidUuid = RegExp(
      _uuidRegex,
      caseSensitive: false,
    ).hasMatch(rawValue);

    if (isValidUuid) {
      await HapticFeedback.mediumImpact();
      if (!mounted) return;
      // Route based on role:
      // Since customers are guarded from reaching this view, only
      // technicians and admins will scan QR codes to start maintenance.
      await context.push('/elevator/$rawValue/maintenance/new');
      if (mounted) {
        setState(() => _isProcessing = false);
        await _controller.start();
      }
    } else {
      await HapticFeedback.heavyImpact();
      if (!mounted) return;
      final colors = AppThemeColors.of(context);
      // Invalid payload — show feedback and resume scanning.
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(
          SnackBar(
            content: const Text(
              'Geçersiz QR kod. Lütfen bir asansör QR kodu tarayın.',
            ),
            behavior: SnackBarBehavior.floating,
            backgroundColor: colors.error,
            duration: AppDurations.snackBarError,
          ),
        );
      setState(() => _isProcessing = false);
      await _controller.start();
    }
  }

  Future<void> _pickImage() async {
    if (_isProcessing) return;

    final picker = ImagePicker();
    final xFile = await picker.pickImage(source: ImageSource.gallery);
    if (xFile == null) return;

    setState(() => _isProcessing = true);

    final capture = await _controller.analyzeImage(xFile.path);
    final rawValue = capture?.barcodes.firstOrNull?.rawValue?.trim();

    if (rawValue == null || rawValue.isEmpty) {
      if (!mounted) return;
      final colors = AppThemeColors.of(context);
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(
          SnackBar(
            content: const Text('Bu görselde QR kod bulunamadı.'),
            behavior: SnackBarBehavior.floating,
            backgroundColor: colors.error,
            duration: AppDurations.snackBarError,
          ),
        );
      setState(() => _isProcessing = false);
      return;
    }

    if (!mounted) return;
    final isValidUuid = RegExp(
      _uuidRegex,
      caseSensitive: false,
    ).hasMatch(rawValue);

    if (isValidUuid) {
      await HapticFeedback.mediumImpact();
      if (!mounted) return;
      await context.push('/elevator/$rawValue/maintenance/new');
      if (mounted) setState(() => _isProcessing = false);
    } else {
      await HapticFeedback.heavyImpact();
      if (!mounted) return;
      final colors = AppThemeColors.of(context);
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(
          SnackBar(
            content: const Text(
              'Geçersiz QR kod. Lütfen bir asansör QR kodu seçin.',
            ),
            behavior: SnackBarBehavior.floating,
            backgroundColor: colors.error,
            duration: AppDurations.snackBarError,
          ),
        );
      setState(() => _isProcessing = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        fit: StackFit.expand,
        children: [
          // ── Full-screen camera feed ──────────────────────────────────────
          MobileScanner(
            controller: _controller,
            onDetect: _onDetect,
            errorBuilder: (context, error) {
              return Scaffold(
                backgroundColor: Colors.black,
                body: ErrorState(
                  message:
                      error.errorCode == MobileScannerErrorCode.permissionDenied
                      ? "Kamera izni gerekli — Ayarlar'dan izin verin."
                      : 'Kamera başlatılamadı: ${error.errorCode.name}',
                ),
              );
            },
          ),

          // ── Animated overlay with transparent cutout ────────────────────
          AnimatedBuilder(
            animation: _lineAnim,
            builder: (context, child) => RepaintBoundary(
              child: CustomPaint(
                painter: _ScanOverlayPainter(
                  scanLineProgress: _lineAnim.value,
                  isProcessing: _isProcessing,
                  primaryColor: AppThemeColors.of(context).primary,
                  successColor: AppThemeColors.of(context).success,
                ),
              ),
            ),
          ),

          // ── Top controls: back + torch ───────────────────────────────────
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  _CircleIconButton(
                    icon: Icons.arrow_back,
                    tooltip: 'Geri',
                    onTap: () => context.pop(),
                  ),
                  Row(
                    children: [
                      _CircleIconButton(
                        icon: Icons.photo_library_outlined,
                        tooltip: 'Galeriden Seç',
                        onTap: _pickImage,
                      ),
                      const SizedBox(width: 12),
                      _CircleIconButton(
                        icon: Icons.flashlight_on_outlined,
                        tooltip: 'Fener',
                        onTap: () => _controller.toggleTorch(),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),

          // ── Instruction label below the cutout ──────────────────────────
          Align(
            alignment: const Alignment(0, 0.52),
            child: AnimatedSwitcher(
              duration: const Duration(milliseconds: 300),
              child: _isProcessing
                  ? _label('İşleniyor...', key: const ValueKey('proc'))
                  : _label(
                      'QR kodu kareye hizalayın',
                      key: const ValueKey('idle'),
                    ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _label(String text, {required Key key}) {
    return Container(
      key: key,
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.55),
        borderRadius: BorderRadius.circular(32),
      ),
      child: Text(
        text,
        style: const TextStyle(
          color: Colors.white,
          fontSize: 14,
          fontWeight: FontWeight.w500,
        ),
      ),
    );
  }
}

// ── Scan overlay ─────────────────────────────────────────────────────────────

class _ScanOverlayPainter extends CustomPainter {
  const _ScanOverlayPainter({
    required this.scanLineProgress,
    required this.isProcessing,
    required this.primaryColor,
    required this.successColor,
  });

  final double scanLineProgress;
  final bool isProcessing;
  final Color primaryColor;
  final Color successColor;

  static const double _cutout = 280;
  static const double _radius = 16;
  static const double _bracketLen = 36;
  static const double _bracketStroke = 4;

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final rect = Rect.fromCenter(
      center: center,
      width: _cutout,
      height: _cutout,
    );

    // ── Semi-transparent overlay, punched out in the centre ───────────────
    canvas.saveLayer(Offset.zero & size, Paint());

    canvas.drawRect(
      Offset.zero & size,
      Paint()..color = Colors.black.withValues(alpha: 0.68),
    );

    canvas.drawRRect(
      RRect.fromRectAndRadius(rect, const Radius.circular(_radius)),
      Paint()..blendMode = BlendMode.clear,
    );

    canvas.restore();

    // ── Animated scan line (hidden while processing) ──────────────────────
    if (!isProcessing) {
      final lineY = rect.top + scanLineProgress * rect.height;
      final shader = LinearGradient(
        colors: [Colors.transparent, primaryColor, Colors.transparent],
      ).createShader(Rect.fromLTWH(rect.left, lineY - 1, rect.width, 2));

      canvas.drawLine(
        Offset(rect.left + 12, lineY),
        Offset(rect.right - 12, lineY),
        Paint()
          ..shader = shader
          ..strokeWidth = 2.5
          ..style = PaintingStyle.stroke,
      );
    }

    // ── Corner brackets ───────────────────────────────────────────────────
    final bracketColor = isProcessing ? successColor : primaryColor;

    final paint = Paint()
      ..color = bracketColor
      ..style = PaintingStyle.stroke
      ..strokeWidth = _bracketStroke
      ..strokeCap = StrokeCap.round;

    _corner(canvas, paint, rect.left, rect.top, 1, 1);
    _corner(canvas, paint, rect.right, rect.top, -1, 1);
    _corner(canvas, paint, rect.left, rect.bottom, 1, -1);
    _corner(canvas, paint, rect.right, rect.bottom, -1, -1);
  }

  /// Draws an L-shaped corner bracket at ([x], [y]).
  /// [hd] and [vd] are ±1 direction multipliers.
  void _corner(Canvas c, Paint p, double x, double y, double hd, double vd) {
    c.drawLine(Offset(x, y), Offset(x + hd * _bracketLen, y), p);
    c.drawLine(Offset(x, y), Offset(x, y + vd * _bracketLen), p);
  }

  @override
  bool shouldRepaint(_ScanOverlayPainter old) =>
      old.scanLineProgress != scanLineProgress ||
      old.isProcessing != isProcessing;
}

// ── Shared button widget ──────────────────────────────────────────────────────

class _CircleIconButton extends StatelessWidget {
  const _CircleIconButton({
    required this.icon,
    required this.onTap,
    required this.tooltip,
  });

  final IconData icon;
  final VoidCallback onTap;
  final String tooltip;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: tooltip,
      button: true,
      child: Tooltip(
        message: tooltip,
        child: Material(
          color: Colors.black54,
          shape: const CircleBorder(),
          child: InkWell(
            customBorder: const CircleBorder(),
            onTap: onTap,
            child: Padding(
              padding: const EdgeInsets.all(10),
              child: Icon(icon, color: Colors.white, size: 22),
            ),
          ),
        ),
      ),
    );
  }
}
