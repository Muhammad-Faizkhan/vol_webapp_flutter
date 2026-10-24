import 'package:flutter/material.dart';

/// CSS `grid-template-columns: repeat(auto-fit | auto-fill, minmax(min, 1fr))`. Rows stretch to their
/// tallest item, as grid rows do. With [fill] (auto-fill) empty columns keep their space.
class AutoGrid extends StatelessWidget {
  const AutoGrid({
    super.key,
    required this.minItemWidth,
    required this.children,
    this.gap = 16,
    this.rowGap,
    this.fill = false,
    this.maxColumns,
  });

  final double minItemWidth;
  final List<Widget> children;
  final double gap;
  final double? rowGap;
  final bool fill;
  final int? maxColumns;

  @override
  Widget build(BuildContext context) {
    if (children.isEmpty) return const SizedBox.shrink();
    return LayoutBuilder(
      builder: (context, constraints) {
        final width = constraints.maxWidth;
        var columns = ((width + gap) / (minItemWidth + gap)).floor().clamp(1, 1000);
        if (maxColumns != null) columns = columns.clamp(1, maxColumns!);
        if (!fill) columns = columns.clamp(1, children.length);

        final rows = <Widget>[];
        for (var i = 0; i < children.length; i += columns) {
          final slice = children.sublist(i, (i + columns).clamp(0, children.length));
          rows.add(
            IntrinsicHeight(
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  for (var j = 0; j < columns; j++) ...[
                    if (j > 0) SizedBox(width: gap),
                    Expanded(child: j < slice.length ? slice[j] : const SizedBox.shrink()),
                  ],
                ],
              ),
            ),
          );
        }
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            for (var i = 0; i < rows.length; i++) ...[if (i > 0) SizedBox(height: rowGap ?? gap), rows[i]],
          ],
        );
      },
    );
  }
}
