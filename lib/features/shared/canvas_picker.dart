import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/format.dart';
import '../../core/query.dart';
import '../../models/canvas.dart';
import '../../theme/tokens.dart';
import '../../ui/layout.dart';
import '../../ui/modal.dart';
import '../../ui/user_image.dart';

/// Modal list of the user's canvases (search + pick). Resolves to the chosen canvas.
Future<CanvasCard?> pickCanvas(BuildContext context, String title) =>
    showModal<CanvasCard>(context, maxWidth: 560, builder: (_) => _CanvasPicker(title: title));

class _CanvasPicker extends ConsumerStatefulWidget {
  const _CanvasPicker({required this.title});

  final String title;

  @override
  ConsumerState<_CanvasPicker> createState() => _CanvasPickerState();
}

class _CanvasPickerState extends ConsumerState<_CanvasPicker> {
  final _q = TextEditingController();

  @override
  void dispose() {
    _q.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final dark = context.isDark;
    final navy = dark ? Dak.heading : Auth.navy;
    final grey = dark ? Dak.muted : const Color(0xFF929292);
    final data = pagedOf(ref, withQuery('/canvases/recent', {'q': _q.text.trim(), 'limit': 20}), CanvasCard.fromJson);

    return Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  widget.title,
                  style: TextStyle(fontSize: 20, fontWeight: FontWeight.w600, color: navy),
                ),
              ),
              IconButton(
                tooltip: 'Close',
                onPressed: () => Navigator.pop(context),
                icon: Text('✕', style: TextStyle(fontSize: 20, color: navy)),
              ),
            ],
          ),
          const SizedBox(height: 16),
          ModalField(controller: _q, hint: 'Search canvases by name…', autofocus: true, onChanged: (_) => setState(() {})),
          const SizedBox(height: 16),
          ConstrainedBox(
            constraints: BoxConstraints(maxHeight: context.screenHeight * .5),
            child: ListView(
              shrinkWrap: true,
              children: [
                if (data?.items.isEmpty == true)
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 24),
                    child: Text(
                      'No canvases found. Create one from a workspace first.',
                      textAlign: TextAlign.center,
                      style: TextStyle(fontSize: 14, color: grey),
                    ),
                  ),
                for (final c in data?.items ?? const <CanvasCard>[])
                  Padding(
                    padding: const EdgeInsets.only(bottom: 8),
                    child: _PickRow(
                      onTap: () => Navigator.pop(context, c),
                      child: Row(
                        children: [
                          Container(
                            width: 48,
                            height: 48,
                            clipBehavior: Clip.antiAlias,
                            decoration: BoxDecoration(color: dark ? Dak.cta : Auth.navy, borderRadius: BorderRadius.circular(8)),
                            child: UserImage(src: c.thumbnailUrl, fallback: 'illustrations/canvas-thumb-mortar-pattern.jpg'),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  c.title,
                                  overflow: TextOverflow.ellipsis,
                                  style: TextStyle(fontSize: 14, fontWeight: FontWeight.w500, color: navy),
                                ),
                                Text(
                                  '${c.workspaceName} · edited ${timeAgo(c.updatedAt)}',
                                  overflow: TextOverflow.ellipsis,
                                  style: TextStyle(fontSize: 12, color: grey),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// Bordered row that turns purple on hover.
class _PickRow extends StatefulWidget {
  const _PickRow({required this.onTap, required this.child});

  final VoidCallback onTap;
  final Widget child;

  @override
  State<_PickRow> createState() => _PickRowState();
}

class _PickRowState extends State<_PickRow> {
  bool _hover = false;

  @override
  Widget build(BuildContext context) {
    final dark = context.isDark;
    return MouseRegion(
      cursor: SystemMouseCursors.click,
      onEnter: (_) => setState(() => _hover = true),
      onExit: (_) => setState(() => _hover = false),
      child: GestureDetector(
        onTap: widget.onTap,
        child: Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: _hover ? Dak.cta : (dark ? Dak.border : Light.border)),
          ),
          child: widget.child,
        ),
      ),
    );
  }
}
