import 'package:flutter/material.dart';

import '../theme/tokens.dart';
import 'layout.dart';

/// A panel anchored under [child] that closes when the user clicks anywhere else,
/// like the header menus in apps/web (a fixed invisible button behind an absolute panel).
class Popover extends StatefulWidget {
  const Popover({
    super.key,
    required this.open,
    required this.onClose,
    required this.panel,
    required this.child,
    this.alignRight = true,
    this.width,
    this.matchWidth = false,
  });

  final bool open;
  final VoidCallback onClose;
  final Widget panel;
  final Widget child;
  final bool alignRight;
  final double? width;
  final bool matchWidth;

  @override
  State<Popover> createState() => _PopoverState();
}

class _PopoverState extends State<Popover> {
  final _link = LayerLink();
  final _portal = OverlayPortalController();
  final _key = GlobalKey();

  @override
  void didUpdateWidget(covariant Popover oldWidget) {
    super.didUpdateWidget(oldWidget);
    WidgetsBinding.instance.addPostFrameCallback((_) => _sync());
  }

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _sync());
  }

  void _sync() {
    if (!mounted) return;
    if (widget.open && !_portal.isShowing) _portal.show();
    if (!widget.open && _portal.isShowing) _portal.hide();
  }

  @override
  Widget build(BuildContext context) {
    return OverlayPortal(
      controller: _portal,
      overlayChildBuilder: (context) {
        final box = _key.currentContext?.findRenderObject() as RenderBox?;
        final width = widget.matchWidth ? box?.size.width : widget.width;
        return Stack(
          children: [
            Positioned.fill(
              child: GestureDetector(behavior: HitTestBehavior.opaque, onTap: widget.onClose),
            ),
            CompositedTransformFollower(
              link: _link,
              targetAnchor: widget.alignRight ? Alignment.bottomRight : Alignment.bottomLeft,
              followerAnchor: widget.alignRight ? Alignment.topRight : Alignment.topLeft,
              offset: const Offset(0, 8),
              child: Align(
                alignment: widget.alignRight ? Alignment.topRight : Alignment.topLeft,
                child: SizedBox(width: width, child: widget.panel),
              ),
            ),
          ],
        );
      },
      child: CompositedTransformTarget(
        link: _link,
        child: KeyedSubtree(key: _key, child: widget.child),
      ),
    );
  }
}

/// The white / surface card with a soft shadow used for menus and dropdowns.
class MenuCard extends StatelessWidget {
  const MenuCard({super.key, required this.child, this.maxHeight});

  final Widget child;
  final double? maxHeight;

  @override
  Widget build(BuildContext context) {
    final dark = context.isDark;
    return Material(
      color: dark ? Dak.surface : Colors.white,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: dark ? Dak.border : Light.border),
      ),
      clipBehavior: Clip.antiAlias,
      shadowColor: Colors.black.withValues(alpha: .12),
      elevation: 8,
      child: ConstrainedBox(
        constraints: BoxConstraints(maxHeight: maxHeight ?? double.infinity),
        child: child,
      ),
    );
  }
}
