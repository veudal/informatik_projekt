import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:mobile_scanner/mobile_scanner.dart';

/// Accent color for the scanner overlay
const Color _accentColor = Color(0xFFA5B4FC);

/// Success color shown when a valid family code was detected.
const Color _successColor = Color(0xFF4ADE80);

/// Full-screen QR scanner that only accepts family invite codes.
///
/// A valid family QR code stores nothing but the family's UUID. When such a
/// code is scanned, this screen pops and returns the UUID to the caller.
/// Popping without a result means the user closed the scanner.
class QrScannerScreen extends StatefulWidget {
  const QrScannerScreen({super.key});

  @override
  State<QrScannerScreen> createState() => _QrScannerScreenState();
}

class _QrScannerScreenState extends State<QrScannerScreen>
    with SingleTickerProviderStateMixin {
  /// A QR code is only accepted when it stores exactly a family UUID.
  static final RegExp _familyCodePattern = RegExp(
    r'^[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{12}$',
  );

  final MobileScannerController _controller = MobileScannerController(
    autoStart: false,
    formats: const <BarcodeFormat>[BarcodeFormat.qrCode],
    facing: CameraFacing.back,
  );

  StreamSubscription<BarcodeCapture>? _subscription;

  late final AnimationController _scanLineController = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 2400),
  )..repeat(reverse: true);

  Timer? _invalidCodeTimer;
  bool _hasResult = false;
  bool _isTorchOn = false;
  String? _invalidCodeMessage;
  String? _scannedFamilyId;

  @override
  void initState() {
    super.initState();
    _subscription = _controller.barcodes.listen(_handleBarcode);
    unawaited(_controller.start());
  }

  @override
  Future<void> dispose() async {
    _invalidCodeTimer?.cancel();
    _scanLineController.dispose();
    unawaited(_subscription?.cancel());
    _subscription = null;
    super.dispose();
    await _controller.dispose();
  }

  /// Scan window: a centered square in the upper half of the screen.
  Rect _scanWindowFor(Size size) {
    final double side = size.width * 0.72;

    return Rect.fromCenter(
      center: Offset(size.width / 2, size.height * 0.42),
      width: side,
      height: side,
    );
  }

  void _handleBarcode(BarcodeCapture capture) {
    if (_hasResult) {
      return;
    }

    for (final Barcode barcode in capture.barcodes) {
      final String? rawValue = barcode.rawValue?.trim();
      if (rawValue == null || rawValue.isEmpty) {
        continue;
      }

      if (_familyCodePattern.hasMatch(rawValue)) {
        unawaited(_onValidFamilyCode(rawValue));
      } else {
        _showInvalidCodeHint();
      }
      return;
    }
  }

  /// Freezes the preview, shows success feedback and pops with the UUID.
  Future<void> _onValidFamilyCode(String familyId) async {
    if (_hasResult) {
      return;
    }

    setState(() {
      _hasResult = true;
      _scannedFamilyId = familyId;
      _invalidCodeMessage = null;
    });
    _scanLineController.stop();
    HapticFeedback.mediumImpact();

    await _controller.stop();

    if (!mounted) {
      return;
    }

    await Future<void>.delayed(const Duration(milliseconds: 900));

    if (!mounted) {
      return;
    }

    Navigator.of(context).pop(familyId);
  }

  /// Shows a short-lived hint that the scanned code was not a family code.
  void _showInvalidCodeHint() {
    if (_hasResult) {
      return;
    }

    _invalidCodeTimer?.cancel();
    _invalidCodeTimer = Timer(const Duration(seconds: 3), () {
      if (mounted) {
        setState(() => _invalidCodeMessage = null);
      }
    });

    if (_invalidCodeMessage == null) {
      setState(() {
        _invalidCodeMessage = 'This QR code is not a family invite code.';
      });
    }
  }

  Future<void> _toggleTorch() async {
    try {
      await _controller.toggleTorch();
      if (!mounted) {
        return;
      }
      setState(() {
        _isTorchOn = _controller.value.torchState == TorchState.on;
      });
    } on Exception {
      // The torch is not available on this device — nothing to do.
    }
  }

  @override
  Widget build(BuildContext context) {
    final Size mediaSize = MediaQuery.sizeOf(context);
    final double bottomPadding = MediaQuery.paddingOf(context).bottom;

    return Scaffold(
      backgroundColor: Colors.black,
      body: MobileScanner(
        controller: _controller,
        fit: BoxFit.cover,
        scanWindow: _scanWindowFor(mediaSize),
        placeholderBuilder: (BuildContext context) => const ColoredBox(
          color: Colors.black,
          child: Center(
            child: CircularProgressIndicator(color: Colors.white70),
          ),
        ),
        errorBuilder: (BuildContext context, MobileScannerException error) {
          return _ScannerErrorView(
            message: error.errorCode.message,
            details: error.errorDetails?.message,
            onRetry: () => unawaited(_controller.start()),
          );
        },
        overlayBuilder: (BuildContext context, BoxConstraints constraints) {
          final Rect window = _scanWindowFor(constraints.biggest);

          return Stack(
            fit: StackFit.expand,
            children: [
              AnimatedBuilder(
                animation: _scanLineController,
                builder: (BuildContext context, Widget? child) => CustomPaint(
                  painter: _ScannerOverlayPainter(
                    scanWindow: window,
                    scanLineProgress: _hasResult
                        ? null
                        : _scanLineController.value,
                    success: _hasResult,
                  ),
                ),
              ),
              SafeArea(
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 8,
                  ),
                  child: Row(
                    children: [
                      _ScannerIconButton(
                        icon: Icons.arrow_back_ios_new_rounded,
                        tooltip: 'Back',
                        onPressed: () => Navigator.of(context).maybePop(),
                      ),
                      const Spacer(),
                      _ScannerIconButton(
                        icon: _isTorchOn
                            ? Icons.flash_on_rounded
                            : Icons.flash_off_rounded,
                        tooltip: 'Toggle flash',
                        onPressed: _toggleTorch,
                      ),
                    ],
                  ),
                ),
              ),
              Positioned(
                left: 32,
                right: 32,
                bottom: bottomPadding + 36,
                child: AnimatedSwitcher(
                  duration: const Duration(milliseconds: 250),
                  child: _hasResult
                      ? _SuccessCard(
                          key: const ValueKey<String>('success'),
                          familyId: _scannedFamilyId!,
                        )
                      : _HintColumn(
                          key: const ValueKey<String>('hint'),
                          message: _invalidCodeMessage,
                        ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}

/// Small round translucent button used for the back and torch controls.
class _ScannerIconButton extends StatelessWidget {
  const _ScannerIconButton({
    required this.icon,
    required this.tooltip,
    required this.onPressed,
  });

  final IconData icon;
  final String tooltip;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: tooltip,
      child: Material(
        color: Colors.black.withValues(alpha: 0.45),
        shape: const CircleBorder(),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onPressed,
          child: SizedBox(
            width: 44,
            height: 44,
            child: Icon(icon, color: Colors.white, size: 22),
          ),
        ),
      ),
    );
  }
}

/// Friendly full-screen error view shown when the camera cannot start.
class _ScannerErrorView extends StatelessWidget {
  const _ScannerErrorView({
    required this.message,
    required this.onRetry,
    this.details,
  });

  final String message;
  final String? details;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return ColoredBox(
      color: Colors.black,
      child: Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.videocam_off, color: Colors.white54, size: 48),
              const SizedBox(height: 16),
              Text(
                message,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                ),
              ),
              if (details != null) ...[
                const SizedBox(height: 8),
                Text(
                  details!,
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.7),
                    fontSize: 13,
                  ),
                ),
              ],
              const SizedBox(height: 24),
              FilledButton.tonalIcon(
                onPressed: onRetry,
                icon: const Icon(Icons.refresh_rounded),
                label: const Text('Try again'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Instruction text plus an optional warning pill for invalid codes.
class _HintColumn extends StatelessWidget {
  const _HintColumn({super.key, required this.message});

  final String? message;

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        if (message != null) ...[
          _StatusPill(
            icon: Icons.error_outline_rounded,
            iconColor: const Color(0xFFFCA5A5),
            borderColor: const Color(0x66EF4444),
            label: message!,
          ),
          const SizedBox(height: 12),
        ],
        Text(
          'Align the family QR code inside the frame',
          textAlign: TextAlign.center,
          style: TextStyle(
            color: Colors.white.withValues(alpha: 0.85),
            fontSize: 14,
            fontWeight: FontWeight.w500,
            letterSpacing: 0.2,
            shadows: const [Shadow(blurRadius: 8, color: Colors.black54)],
          ),
        ),
      ],
    );
  }
}

/// Translucent status pill (used for the invalid-code warning).
class _StatusPill extends StatelessWidget {
  const _StatusPill({
    required this.icon,
    required this.iconColor,
    required this.borderColor,
    required this.label,
  });

  final IconData icon;
  final Color iconColor;
  final Color borderColor;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.72),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: borderColor),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: iconColor, size: 18),
          const SizedBox(width: 8),
          Flexible(
            child: Text(
              label,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 13,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Green confirmation card shown after a valid family code was scanned.
class _SuccessCard extends StatelessWidget {
  const _SuccessCard({super.key, required this.familyId});

  final String familyId;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: const Color(0xCC14532D),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: _successColor.withValues(alpha: 0.6)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(
                Icons.check_circle_rounded,
                color: _successColor,
                size: 20,
              ),
              const SizedBox(width: 8),
              const Text(
                'Family code detected',
                style: TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                  fontSize: 14,
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            familyId,
            textAlign: TextAlign.center,
            style: TextStyle(
              color: Colors.white.withValues(alpha: 0.9),
              fontSize: 12,
              fontFamily: 'monospace',
              letterSpacing: 0.5,
            ),
          ),
        ],
      ),
    );
  }
}

/// Draws the dimmed surround, the cut-out for the scan window, corner
/// brackets and the animated scan line.
class _ScannerOverlayPainter extends CustomPainter {
  _ScannerOverlayPainter({
    required this.scanWindow,
    required this.success,
    this.scanLineProgress,
  });

  final Rect scanWindow;
  final bool success;

  /// Progress (0..1) of the animated scan line; null hides the line.
  final double? scanLineProgress;

  static const double _cornerRadius = 20;
  static const double _cornerLength = 30;

  @override
  void paint(Canvas canvas, Size size) {
    final RRect hole = RRect.fromRectAndRadius(
      scanWindow,
      const Radius.circular(_cornerRadius),
    );

    // Dim everything outside of the scan window.
    final Path dim = Path()
      ..fillType = PathFillType.evenOdd
      ..addRect(Rect.fromLTWH(0, 0, size.width, size.height))
      ..addRRect(hole);
    canvas.drawPath(dim, Paint()..color = Colors.black.withValues(alpha: 0.55));

    // Thin frame around the scan window.
    canvas.drawRRect(
      hole,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.5
        ..color = Colors.white.withValues(alpha: 0.35),
    );

    // Corner brackets.
    final Color bracketColor = success ? _successColor : _accentColor;
    final Paint bracketPaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 5
      ..strokeCap = StrokeCap.round
      ..color = bracketColor;

    canvas.drawPath(_bracketPath(hole, _Corner.topLeft), bracketPaint);
    canvas.drawPath(_bracketPath(hole, _Corner.topRight), bracketPaint);
    canvas.drawPath(_bracketPath(hole, _Corner.bottomLeft), bracketPaint);
    canvas.drawPath(_bracketPath(hole, _Corner.bottomRight), bracketPaint);

    // Animated scan line while searching for a code.
    final double? progress = scanLineProgress;
    if (progress != null && !success) {
      const double inset = 18;
      final double y =
          scanWindow.top + inset + progress * (scanWindow.height - inset * 2);
      final RRect line = RRect.fromRectAndRadius(
        Rect.fromLTWH(
          scanWindow.left + inset,
          y - 1.5,
          scanWindow.width - inset * 2,
          3,
        ),
        const Radius.circular(3),
      );
      canvas.drawRRect(
        line,
        Paint()..color = _accentColor.withValues(alpha: 0.9),
      );
    }
  }

  Path _bracketPath(RRect hole, _Corner corner) {
    const double r = _cornerRadius;
    const double l = _cornerLength;

    switch (corner) {
      case _Corner.topLeft:
        return Path()
          ..moveTo(hole.left, hole.top + r + l)
          ..lineTo(hole.left, hole.top + r)
          ..arcToPoint(
            Offset(hole.left + r, hole.top),
            radius: const Radius.circular(r),
          )
          ..lineTo(hole.left + r + l, hole.top);
      case _Corner.topRight:
        return Path()
          ..moveTo(hole.right - r - l, hole.top)
          ..lineTo(hole.right - r, hole.top)
          ..arcToPoint(
            Offset(hole.right, hole.top + r),
            radius: const Radius.circular(r),
          )
          ..lineTo(hole.right, hole.top + r + l);
      case _Corner.bottomRight:
        return Path()
          ..moveTo(hole.right, hole.bottom - r - l)
          ..lineTo(hole.right, hole.bottom - r)
          ..arcToPoint(
            Offset(hole.right - r, hole.bottom),
            radius: const Radius.circular(r),
          )
          ..lineTo(hole.right - r - l, hole.bottom);
      case _Corner.bottomLeft:
        return Path()
          ..moveTo(hole.left + r + l, hole.bottom)
          ..lineTo(hole.left + r, hole.bottom)
          ..arcToPoint(
            Offset(hole.left, hole.bottom - r),
            radius: const Radius.circular(r),
          )
          ..lineTo(hole.left, hole.bottom - r - l);
    }
  }

  @override
  bool shouldRepaint(_ScannerOverlayPainter oldDelegate) {
    return oldDelegate.scanWindow != scanWindow ||
        oldDelegate.success != success ||
        oldDelegate.scanLineProgress != scanLineProgress;
  }
}

enum _Corner { topLeft, topRight, bottomLeft, bottomRight }
