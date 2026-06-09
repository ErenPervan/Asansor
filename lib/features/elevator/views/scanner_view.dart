import 'package:asansor/core/constants/app_durations.dart';
import 'package:asansor/core/theme/app_colors.dart';
import 'package:asansor/core/theme/app_spacing.dart';
import 'package:asansor/core/widgets/error_state.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';
import 'package:mobile_scanner/mobile_scanner.dart';

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
  bool _torchOn = false;

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
    _lineAnim = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2200),
    )..repeat();
  }

  @override
  void dispose() {
    _lineAnim.dispose();
    _controller.dispose();
    super.dispose();
  }

  Future<void> _onDetect(BarcodeCapture capture) async {
    if (_isProcessing) return;

    final rawValue = capture.barcodes.firstOrNull?.rawValue?.trim();
    if (rawValue == null || rawValue.isEmpty) return;

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
      await context.push('/elevator/$rawValue/maintenance/new');
      if (mounted) {
        setState(() => _isProcessing = false);
        await _controller.start();
      }
    } else {
      await _showInvalidQr('Geçersiz QR kod. Lütfen bir asansör QR kodu tarayın.');
      if (!mounted) return;
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
      await _showInvalidQr('Bu görselde QR kod bulunamadı.');
      if (mounted) setState(() => _isProcessing = false);
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
      await _showInvalidQr('Geçersiz QR kod. Lütfen bir asansör QR kodu seçin.');
      if (mounted) setState(() => _isProcessing = false);
    }
  }

  Future<void> _showInvalidQr(String message) async {
    await HapticFeedback.heavyImpact();
    if (!mounted) return;
    final colors = AppThemeColors.of(context);
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          content: Text(message),
          behavior: SnackBarBehavior.floating,
          backgroundColor: colors.error,
          duration: AppDurations.snackBarError,
        ),
      );
  }

  Future<void> _toggleTorch() async {
    await _controller.toggleTorch();
    if (!mounted) return;
    setState(() => _torchOn = !_torchOn);
  }

  @override
  Widget build(BuildContext context) {
    final disableAnims = MediaQuery.disableAnimationsOf(context);
    final colors = AppThemeColors.of(context);

    if (disableAnims && _lineAnim.isAnimating) {
      _lineAnim.stop();
    } else if (!disableAnims && !_lineAnim.isAnimating && !_isProcessing) {
      _lineAnim.repeat();
    }

    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        fit: StackFit.expand,
        children: [
          MobileScanner(
            controller: _controller,
            onDetect: _onDetect,
            errorBuilder: (context, error) {
              return Scaffold(
                backgroundColor: Colors.black,
                body: ErrorState(
                  message:
                      error.errorCode == MobileScannerErrorCode.permissionDenied
                          ? "Kamera izni gerekli. Ayarlar'dan izin verin."
                          : 'Kamera başlatılamadı: ${error.errorCode.name}',
                ),
              );
            },
          ),
          AnimatedBuilder(
            animation: _lineAnim,
            builder: (context, child) => RepaintBoundary(
              child: CustomPaint(
                painter: _ScanOverlayPainter(
                  scanLineProgress: _lineAnim.value,
                  isProcessing: _isProcessing,
                  primaryColor: colors.primary,
                  successColor: colors.success,
                  showScanLine: !disableAnims,
                ),
              ),
            ),
          ),
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(
                AppSpacing.md,
                AppSpacing.sm,
                AppSpacing.md,
                0,
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  _GlassCircleButton(
                    icon: Icons.arrow_back_rounded,
                    tooltip: 'Geri',
                    onTap: () => context.pop(),
                  ),
                  _GlassCircleButton(
                    icon: _torchOn
                        ? Icons.flashlight_on_rounded
                        : Icons.flashlight_off_rounded,
                    tooltip: 'Fener',
                    accent: _torchOn ? AppColors.accentGold : null,
                    onTap: _toggleTorch,
                  ),
                ],
              ),
            ),
          ),
          Align(
            alignment: Alignment.bottomCenter,
            child: _ScannerBottomPanel(
              isProcessing: _isProcessing,
              onPickImage: _pickImage,
            ),
          ),
        ],
      ),
    );
  }
}

class _ScannerBottomPanel extends StatelessWidget {
  const _ScannerBottomPanel({
    required this.isProcessing,
    required this.onPickImage,
  });

  final bool isProcessing;
  final VoidCallback onPickImage;

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      top: false,
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.fromLTRB(24, 84, 24, 26),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              Colors.transparent,
              Colors.black.withValues(alpha: 0.62),
              Colors.black.withValues(alpha: 0.9),
            ],
          ),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            AnimatedSwitcher(
              duration: const Duration(milliseconds: 250),
              child: Column(
                key: ValueKey(isProcessing),
                children: [
                  Text(
                    isProcessing ? 'QR İşleniyor' : 'QR Kodu Taratın',
                    style: Theme.of(context).textTheme.titleLarge?.copyWith(
                          color: Colors.white,
                          fontWeight: FontWeight.w900,
                        ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: AppSpacing.sm),
                  Text(
                    isProcessing
                        ? 'Asansör kaydı doğrulanıyor.'
                        : 'Asansör etiketindeki karekodu çerçevenin içine hizalayın.',
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          color: Colors.white.withValues(alpha: 0.72),
                          fontWeight: FontWeight.w600,
                          height: 1.35,
                        ),
                    textAlign: TextAlign.center,
                  ),
                ],
              ),
            ),
            const SizedBox(height: AppSpacing.lg),
            OutlinedButton.icon(
              onPressed: isProcessing ? null : onPickImage,
              icon: const Icon(Icons.photo_library_outlined),
              label: const Text('Galeriden Seç'),
              style: OutlinedButton.styleFrom(
                foregroundColor: Colors.white,
                disabledForegroundColor: Colors.white.withValues(alpha: 0.42),
                backgroundColor: Colors.white.withValues(alpha: 0.1),
                side: BorderSide(color: Colors.white.withValues(alpha: 0.18)),
                padding: const EdgeInsets.symmetric(
                  horizontal: AppSpacing.lg,
                  vertical: 14,
                ),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(AppSpacing.radiusFull),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ScanOverlayPainter extends CustomPainter {
  const _ScanOverlayPainter({
    required this.scanLineProgress,
    required this.isProcessing,
    required this.primaryColor,
    required this.successColor,
    this.showScanLine = true,
  });

  final double scanLineProgress;
  final bool isProcessing;
  final Color primaryColor;
  final Color successColor;
  final bool showScanLine;

  static const double _cutout = 260;
  static const double _radius = 18;
  static const double _bracketLen = 40;
  static const double _bracketStroke = 4;

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final rect = Rect.fromCenter(
      center: center,
      width: _cutout,
      height: _cutout,
    );

    canvas.saveLayer(Offset.zero & size, Paint());
    canvas.drawRect(
      Offset.zero & size,
      Paint()..color = Colors.black.withValues(alpha: 0.82),
    );
    canvas.drawRRect(
      RRect.fromRectAndRadius(rect, const Radius.circular(_radius)),
      Paint()..blendMode = BlendMode.clear,
    );
    canvas.restore();

    final activeColor = isProcessing ? successColor : primaryColor;
    final cornerPaint = Paint()
      ..color = activeColor
      ..style = PaintingStyle.stroke
      ..strokeWidth = _bracketStroke
      ..strokeCap = StrokeCap.round;

    _corner(canvas, cornerPaint, rect.left, rect.top, 1, 1);
    _corner(canvas, cornerPaint, rect.right, rect.top, -1, 1);
    _corner(canvas, cornerPaint, rect.left, rect.bottom, 1, -1);
    _corner(canvas, cornerPaint, rect.right, rect.bottom, -1, -1);

    if (!isProcessing && showScanLine) {
      final lineY = rect.top + scanLineProgress * rect.height;
      final shader = LinearGradient(
        colors: [
          Colors.transparent,
          activeColor.withValues(alpha: 0.92),
          Colors.transparent,
        ],
      ).createShader(Rect.fromLTWH(rect.left, lineY - 1, rect.width, 2));

      canvas.drawLine(
        Offset(rect.left + 14, lineY),
        Offset(rect.right - 14, lineY),
        Paint()
          ..shader = shader
          ..strokeWidth = 2.5
          ..style = PaintingStyle.stroke,
      );
    }

    final reticlePaint = Paint()
      ..color = activeColor.withValues(alpha: 0.26)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.5
      ..strokeCap = StrokeCap.round;
    canvas.drawLine(
      Offset(center.dx - 12, center.dy),
      Offset(center.dx + 12, center.dy),
      reticlePaint,
    );
    canvas.drawLine(
      Offset(center.dx, center.dy - 12),
      Offset(center.dx, center.dy + 12),
      reticlePaint,
    );
  }

  void _corner(Canvas c, Paint p, double x, double y, double hd, double vd) {
    c.drawLine(Offset(x, y), Offset(x + hd * _bracketLen, y), p);
    c.drawLine(Offset(x, y), Offset(x, y + vd * _bracketLen), p);
  }

  @override
  bool shouldRepaint(_ScanOverlayPainter old) =>
      old.scanLineProgress != scanLineProgress ||
      old.isProcessing != isProcessing ||
      old.showScanLine != showScanLine;
}

class _GlassCircleButton extends StatelessWidget {
  const _GlassCircleButton({
    required this.icon,
    required this.onTap,
    required this.tooltip,
    this.accent,
  });

  final IconData icon;
  final VoidCallback onTap;
  final String tooltip;
  final Color? accent;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: tooltip,
      button: true,
      child: Tooltip(
        message: tooltip,
        child: Material(
          color: Colors.white.withValues(alpha: 0.18),
          shape: const CircleBorder(),
          child: InkWell(
            customBorder: const CircleBorder(),
            onTap: onTap,
            child: Container(
              width: 50,
              height: 50,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(color: Colors.white.withValues(alpha: 0.28)),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.2),
                    blurRadius: 18,
                    offset: const Offset(0, 8),
                  ),
                ],
              ),
              child: Icon(icon, color: accent ?? Colors.white, size: 23),
            ),
          ),
        ),
      ),
    );
  }
}
