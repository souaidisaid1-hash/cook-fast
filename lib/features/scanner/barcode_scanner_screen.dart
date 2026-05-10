import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../../core/theme/app_theme.dart';
import '../../shared/models/shopping_item.dart';
import '../../shared/providers/app_providers.dart';
import '../../shared/services/openfoodfacts_service.dart';

class BarcodeScannerScreen extends ConsumerStatefulWidget {
  const BarcodeScannerScreen({super.key});

  @override
  ConsumerState<BarcodeScannerScreen> createState() => _BarcodeScannerScreenState();
}

class _BarcodeScannerScreenState extends ConsumerState<BarcodeScannerScreen> {
  final _controller = MobileScannerController(
    detectionSpeed: DetectionSpeed.noDuplicates,
  );
  bool _processing = false;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _onDetect(BarcodeCapture capture) async {
    if (_processing) return;
    final rawValue = capture.barcodes.firstOrNull?.rawValue;
    if (rawValue == null) return;

    setState(() => _processing = true);
    await _controller.stop();

    final product = await OpenFoodFactsService.lookup(rawValue);

    if (!mounted) return;

    if (product == null) {
      _showNotFound(rawValue);
    } else {
      _showResult(product);
    }
  }

  void _showNotFound(String barcode) {
    final navBar = MediaQuery.of(context).viewPadding.bottom;
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      barrierColor: Colors.transparent,
      builder: (_) => _NotFoundSheet(
        barcode: barcode,
        navBar: navBar,
        onResume: _resume,
        onAddManual: (name) {
          ref.read(fridgeProvider.notifier).add(name);
          _resume();
          _snack('$name ajouté au frigo 🧊');
        },
      ),
    );
  }

  void _showResult(OFFProduct product) {
    final navBar = MediaQuery.of(context).viewPadding.bottom;
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      barrierColor: Colors.transparent,
      isScrollControlled: true,
      builder: (_) => _ResultSheet(
        product: product,
        navBar: navBar,
        onAddFridge: () {
          ref.read(fridgeProvider.notifier).add(product.name);
          _resume();
          _snack('${product.name} ajouté au frigo 🧊');
        },
        onAddShopping: () {
          ref.read(shoppingProvider.notifier).add(
                product.name,
                measure: '',
              );
          _resume();
          _snack('${product.name} ajouté aux courses 🛒');
        },
        onCancel: _resume,
      ),
    );
  }

  void _resume() {
    if (mounted) {
      setState(() => _processing = false);
      _controller.start();
    }
  }

  void _snack(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(msg),
      behavior: SnackBarBehavior.floating,
      backgroundColor: const Color(0xFF323232),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      duration: const Duration(seconds: 2),
    ));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        children: [
          // Caméra plein écran
          MobileScanner(
            controller: _controller,
            onDetect: _onDetect,
          ),

          // Overlay sombre avec fenêtre de scan
          CustomPaint(
            size: MediaQuery.of(context).size,
            painter: _ScanOverlayPainter(),
          ),

          // Header
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              child: Row(
                children: [
                  GestureDetector(
                    onTap: () => Navigator.of(context).pop(),
                    child: Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: Colors.black45,
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(Icons.close, color: Colors.white, size: 22),
                    ),
                  ),
                  const Spacer(),
                  // Torche
                  GestureDetector(
                    onTap: () => _controller.toggleTorch(),
                    child: Container(
                      padding: const EdgeInsets.all(10),
                      decoration: const BoxDecoration(
                        color: Colors.black45,
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(Icons.flash_on_rounded, color: Colors.white, size: 22),
                    ),
                  ),
                ],
              ),
            ),
          ),

          // Label centré
          Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const SizedBox(height: 180),
                if (_processing)
                  const SizedBox(
                    width: 32,
                    height: 32,
                    child: CircularProgressIndicator(
                        color: AppColors.primary, strokeWidth: 3),
                  )
                else
                  const Text(
                    'Pointez vers un code-barres',
                    style: TextStyle(
                        color: Colors.white70,
                        fontSize: 14,
                        fontWeight: FontWeight.w500),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ── Overlay painter ────────────────────────────────────────────────────────────

class _ScanOverlayPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    const boxW = 260.0;
    const boxH = 180.0;
    final cx = size.width / 2;
    final cy = size.height / 2 - 30;

    final rect = Rect.fromCenter(
        center: Offset(cx, cy), width: boxW, height: boxH);

    final fill = Paint()..color = Colors.black54;
    final full = Rect.fromLTWH(0, 0, size.width, size.height);

    final path = Path()
      ..addRect(full)
      ..addRRect(RRect.fromRectAndRadius(rect, const Radius.circular(12)))
      ..fillType = PathFillType.evenOdd;

    canvas.drawPath(path, fill);

    // Coins colorés
    const corner = 24.0;
    const thick = 3.0;
    final paint = Paint()
      ..color = AppColors.primary
      ..strokeWidth = thick
      ..strokeCap = StrokeCap.round
      ..style = PaintingStyle.stroke;

    final corners = [
      [rect.topLeft, Offset(rect.left + corner, rect.top), Offset(rect.left, rect.top + corner)],
      [rect.topRight, Offset(rect.right - corner, rect.top), Offset(rect.right, rect.top + corner)],
      [rect.bottomLeft, Offset(rect.left + corner, rect.bottom), Offset(rect.left, rect.bottom - corner)],
      [rect.bottomRight, Offset(rect.right - corner, rect.bottom), Offset(rect.right, rect.bottom - corner)],
    ];

    for (final c in corners) {
      canvas.drawLine(c[1], c[0], paint);
      canvas.drawLine(c[0], c[2], paint);
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

// ── Result sheet ───────────────────────────────────────────────────────────────

class _ResultSheet extends StatelessWidget {
  final OFFProduct product;
  final double navBar;
  final VoidCallback onAddFridge;
  final VoidCallback onAddShopping;
  final VoidCallback onCancel;

  const _ResultSheet({
    required this.product,
    required this.navBar,
    required this.onAddFridge,
    required this.onAddShopping,
    required this.onCancel,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () {
        Navigator.pop(context);
        onCancel();
      },
      behavior: HitTestBehavior.opaque,
      child: Align(
        alignment: Alignment.bottomCenter,
        child: GestureDetector(
          onTap: () {},
          child: Container(
            margin: const EdgeInsets.fromLTRB(16, 0, 16, 16),
            padding: EdgeInsets.fromLTRB(20, 20, 20, 20 + navBar),
            decoration: BoxDecoration(
              color: AppColors.darkCard,
              borderRadius: BorderRadius.circular(24),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Handle
                Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: AppColors.darkBorder,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
                const SizedBox(height: 16),

                Row(
                  children: [
                    // Image produit
                    ClipRRect(
                      borderRadius: BorderRadius.circular(12),
                      child: product.imageUrl != null
                          ? CachedNetworkImage(
                              imageUrl: product.imageUrl!,
                              width: 72,
                              height: 72,
                              fit: BoxFit.cover,
                              errorWidget: (_, __, ___) =>
                                  _placeholderBox(),
                            )
                          : _placeholderBox(),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            product.name,
                            style: const TextStyle(
                                color: AppColors.textDark,
                                fontSize: 16,
                                fontWeight: FontWeight.w700),
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                          ),
                          if (product.brand.isNotEmpty) ...[
                            const SizedBox(height: 3),
                            Text(product.brand,
                                style: const TextStyle(
                                    color: AppColors.textDarkSecondary,
                                    fontSize: 13)),
                          ],
                          const SizedBox(height: 6),
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 8, vertical: 3),
                            decoration: BoxDecoration(
                              color: AppColors.primary.withValues(alpha: 0.15),
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: Text(
                              product.category,
                              style: const TextStyle(
                                  color: AppColors.primary,
                                  fontSize: 11,
                                  fontWeight: FontWeight.w600),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),

                const SizedBox(height: 20),

                Row(
                  children: [
                    Expanded(
                      child: _ActionBtn(
                        emoji: '🧊',
                        label: 'Ajouter au frigo',
                        color: AppColors.blue,
                        onTap: () {
                          Navigator.pop(context);
                          onAddFridge();
                        },
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: _ActionBtn(
                        emoji: '🛒',
                        label: 'Ajouter aux courses',
                        color: AppColors.green,
                        onTap: () {
                          Navigator.pop(context);
                          onAddShopping();
                        },
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _placeholderBox() => Container(
        width: 72,
        height: 72,
        color: AppColors.darkBg,
        child: const Center(
          child: Text('📦', style: TextStyle(fontSize: 28)),
        ),
      );
}

// ── Not found sheet ────────────────────────────────────────────────────────────

class _NotFoundSheet extends StatefulWidget {
  final String barcode;
  final double navBar;
  final VoidCallback onResume;
  final void Function(String name) onAddManual;

  const _NotFoundSheet({
    required this.barcode,
    required this.navBar,
    required this.onResume,
    required this.onAddManual,
  });

  @override
  State<_NotFoundSheet> createState() => _NotFoundSheetState();
}

class _NotFoundSheetState extends State<_NotFoundSheet> {
  final _ctrl = TextEditingController();

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () {
        Navigator.pop(context);
        widget.onResume();
      },
      behavior: HitTestBehavior.opaque,
      child: Align(
        alignment: Alignment.bottomCenter,
        child: GestureDetector(
          onTap: () {},
          child: Container(
            margin: const EdgeInsets.fromLTRB(16, 0, 16, 16),
            padding: EdgeInsets.fromLTRB(
                20, 20, 20, 20 + widget.navBar + MediaQuery.of(context).viewInsets.bottom),
            decoration: BoxDecoration(
              color: AppColors.darkCard,
              borderRadius: BorderRadius.circular(24),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Center(
                  child: Container(
                    width: 40,
                    height: 4,
                    decoration: BoxDecoration(
                      color: AppColors.darkBorder,
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                const Text('Produit non trouvé',
                    style: TextStyle(
                        color: AppColors.textDark,
                        fontSize: 16,
                        fontWeight: FontWeight.w700)),
                const SizedBox(height: 4),
                Text('Code : ${widget.barcode}',
                    style: const TextStyle(
                        color: AppColors.textDarkSecondary, fontSize: 12)),
                const SizedBox(height: 14),
                TextField(
                  controller: _ctrl,
                  autofocus: false,
                  style: const TextStyle(color: AppColors.textDark),
                  decoration: InputDecoration(
                    hintText: 'Nom du produit',
                    hintStyle: const TextStyle(
                        color: AppColors.textDarkSecondary),
                    filled: true,
                    fillColor: AppColors.darkBg,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide.none,
                    ),
                    prefixIcon: const Icon(Icons.edit_outlined,
                        color: AppColors.textDarkSecondary),
                  ),
                ),
                const SizedBox(height: 12),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: () {
                      final name = _ctrl.text.trim();
                      if (name.isEmpty) return;
                      Navigator.pop(context);
                      widget.onAddManual(name);
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.primary,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12)),
                    ),
                    child: const Text('Ajouter au frigo',
                        style: TextStyle(
                            fontSize: 15, fontWeight: FontWeight.w600)),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// ── Action button ──────────────────────────────────────────────────────────────

class _ActionBtn extends StatelessWidget {
  final String emoji;
  final String label;
  final Color color;
  final VoidCallback onTap;

  const _ActionBtn({
    required this.emoji,
    required this.label,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 14),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.15),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: color.withValues(alpha: 0.4)),
        ),
        child: Column(
          children: [
            Text(emoji, style: const TextStyle(fontSize: 22)),
            const SizedBox(height: 4),
            Text(
              label,
              style: TextStyle(
                  color: color,
                  fontSize: 12,
                  fontWeight: FontWeight.w700),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}
