import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../core/api/api_error.dart';
import '../theme/tokens.dart';
import 'auto_grid.dart';
import 'layout.dart';

/// Placeholder cards while a grid loads.
class LoadingGrid extends StatefulWidget {
  const LoadingGrid({super.key, this.count = 4, this.height = 220, this.minWidth = 260});

  final int count;
  final double height;
  final double minWidth;

  @override
  State<LoadingGrid> createState() => _LoadingGridState();
}

class _LoadingGridState extends State<LoadingGrid> with SingleTickerProviderStateMixin {
  late final _pulse = AnimationController(vsync: this, duration: const Duration(seconds: 1))..repeat(reverse: true);

  @override
  void dispose() {
    _pulse.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final color = context.pick(const Color(0xFFE9E6F0), Dak.surface);
    return FadeTransition(
      opacity: Tween(begin: 1.0, end: .5).animate(_pulse),
      child: AutoGrid(
        minItemWidth: widget.minWidth,
        gap: 24,
        fill: true,
        children: [
          for (var i = 0; i < widget.count; i++)
            Container(
              height: widget.height,
              decoration: BoxDecoration(color: color, borderRadius: BorderRadius.circular(8)),
            ),
        ],
      ),
    );
  }
}

class EmptyState extends StatelessWidget {
  const EmptyState({super.key, required this.title, this.body, this.actionLabel, this.actionHref, this.action});

  final String title;
  final String? body;
  final String? actionLabel;
  final String? actionHref;
  final Widget? action;

  @override
  Widget build(BuildContext context) {
    final dark = context.isDark;
    return CustomPaint(
      painter: DashedBorder(color: dark ? Dak.border : Hex.text.withValues(alpha: .3), radius: 16),
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 48),
        child: Column(
          children: [
            Text(
              title,
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600, color: dark ? Dak.heading : Hex.black),
            ),
            if (body != null) ...[
              const SizedBox(height: 12),
              ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 448),
                child: Text(
                  body!,
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 14, color: dark ? Dak.body : Hex.text),
                ),
              ),
            ],
            if (actionLabel != null && actionHref != null) ...[
              const SizedBox(height: 20),
              Material(
                color: Dak.cta,
                borderRadius: BorderRadius.circular(12),
                child: InkWell(
                  borderRadius: BorderRadius.circular(12),
                  onTap: () => context.go(actionHref!),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                    child: Text(
                      actionLabel!,
                      style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w500, color: Colors.white),
                    ),
                  ),
                ),
              ),
            ],
            if (action != null) ...[const SizedBox(height: 20), action!],
          ],
        ),
      ),
    );
  }
}

class ErrorState extends StatelessWidget {
  const ErrorState({super.key, required this.error, this.onRetry});

  final Object error;
  final VoidCallback? onRetry;

  @override
  Widget build(BuildContext context) {
    final dark = context.isDark;
    final red = dark ? const Color(0xFFFCA5A5) : const Color(0xFFDC2626);
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 32),
      decoration: BoxDecoration(
        color: dark ? const Color(0x1AEF4444) : const Color(0xFFFEF2F2),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: dark ? const Color(0x4DEF4444) : const Color(0xFFFECACA)),
      ),
      child: Column(
        children: [
          Text(
            errorMessage(error),
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 14, fontWeight: FontWeight.w500, color: red),
          ),
          if (onRetry != null) ...[
            const SizedBox(height: 12),
            OutlinedButton(
              onPressed: onRetry,
              style: OutlinedButton.styleFrom(
                foregroundColor: red,
                side: BorderSide(color: dark ? const Color(0xFFFCA5A5) : const Color(0xFFFCA5A5)),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
              ),
              child: const Text('Try again', style: TextStyle(fontSize: 14)),
            ),
          ],
        ],
      ),
    );
  }
}

/// Previous / Next pager for paged lists.
class Pager extends StatelessWidget {
  const Pager({super.key, required this.page, required this.pages, required this.onPage});

  final int page;
  final int pages;
  final ValueChanged<int> onPage;

  @override
  Widget build(BuildContext context) {
    if (pages <= 1) return const SizedBox.shrink();
    final dark = context.isDark;

    Widget button(String label, bool enabled, int target) => Opacity(
      opacity: enabled ? 1 : .4,
      child: OutlinedButton(
        onPressed: enabled ? () => onPage(target) : null,
        style: OutlinedButton.styleFrom(
          foregroundColor: dark ? Dak.heading : Auth.navy,
          disabledForegroundColor: dark ? Dak.heading : Auth.navy,
          side: BorderSide(color: dark ? Dak.border : Light.border),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        ),
        child: Text(label, style: const TextStyle(fontSize: 14)),
      ),
    );

    return Padding(
      padding: const EdgeInsets.only(top: 8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          button('Previous', page > 1, page - 1),
          const SizedBox(width: 12),
          Text('Page $page of $pages', style: TextStyle(fontSize: 14, color: dark ? Dak.body : Hex.text)),
          const SizedBox(width: 12),
          button('Next', page < pages, page + 1),
        ],
      ),
    );
  }
}

/// Draws a dashed rounded rectangle, for `border-dashed` boxes.
class DashedBorder extends CustomPainter {
  DashedBorder({required this.color, this.radius = 12, this.dash = 4, this.gap = 3, this.strokeWidth = 1});

  final Color color;
  final double radius;
  final double dash;
  final double gap;
  final double strokeWidth;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth;
    final half = strokeWidth / 2;
    final path = Path()
      ..addRRect(
        RRect.fromRectAndRadius(Rect.fromLTWH(half, half, size.width - strokeWidth, size.height - strokeWidth), Radius.circular(radius)),
      );
    for (final metric in path.computeMetrics()) {
      var d = 0.0;
      while (d < metric.length) {
        canvas.drawPath(metric.extractPath(d, d + dash), paint);
        d += dash + gap;
      }
    }
  }

  @override
  bool shouldRepaint(covariant DashedBorder old) => old.color != color || old.radius != radius;
}
