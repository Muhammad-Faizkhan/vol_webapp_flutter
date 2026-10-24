import 'package:desktop_drop/desktop_drop.dart';
import 'package:flutter/material.dart';

import '../core/api/upload.dart';
import '../theme/tokens.dart';

/// Opens a file picker on click and also accepts a dropped file, like components/ui/DropZone.tsx.
class DropZone extends StatefulWidget {
  const DropZone({
    super.key,
    required this.onFile,
    required this.onTap,
    required this.decoration,
    required this.child,
    this.padding,
    this.minHeight = 0,
  });

  final ValueChanged<PickedFile> onFile;
  final VoidCallback onTap;
  final BoxDecoration decoration;
  final Widget child;
  final EdgeInsets? padding;
  final double minHeight;

  @override
  State<DropZone> createState() => _DropZoneState();
}

class _DropZoneState extends State<DropZone> {
  bool _dragging = false;

  @override
  Widget build(BuildContext context) {
    final radius = widget.decoration.borderRadius;
    return DropTarget(
      onDragEntered: (_) => setState(() => _dragging = true),
      onDragExited: (_) => setState(() => _dragging = false),
      onDragDone: (details) async {
        setState(() => _dragging = false);
        final item = details.files.firstOrNull;
        if (item == null) return;
        widget.onFile(PickedFile(name: item.name, bytes: await item.readAsBytes(), mimeType: item.mimeType));
      },
      child: Container(
        constraints: BoxConstraints(minHeight: widget.minHeight),
        clipBehavior: Clip.antiAlias,
        decoration: widget.decoration.copyWith(boxShadow: _dragging ? const [BoxShadow(color: Dak.cta, spreadRadius: 2)] : null),
        child: Material(
          type: MaterialType.transparency,
          child: InkWell(
            onTap: widget.onTap,
            borderRadius: radius is BorderRadius ? radius : null,
            child: Padding(padding: widget.padding ?? EdgeInsets.zero, child: widget.child),
          ),
        ),
      ),
    );
  }
}
