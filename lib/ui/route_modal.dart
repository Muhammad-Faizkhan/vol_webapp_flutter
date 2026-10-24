import 'package:flutter/material.dart';

import '../theme/tokens.dart';
import 'layout.dart';

/// A page that is a modal over another page, like /discover/create-post drawing the feed underneath.
/// The modal covers the whole window (sidebar and header too) for as long as the route is shown.
class RouteModal extends StatefulWidget {
  const RouteModal({super.key, required this.background, required this.child, this.maxWidth = 768});

  final Widget background;
  final Widget child;
  final double maxWidth;

  @override
  State<RouteModal> createState() => _RouteModalState();
}

class _RouteModalState extends State<RouteModal> {
  final _portal = OverlayPortalController();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _portal.show();
    });
  }

  @override
  Widget build(BuildContext context) {
    return OverlayPortal(
      controller: _portal,
      overlayChildBuilder: (context) {
        final dark = context.isDark;
        return ColoredBox(
          color: const Color(0xB03A3A3A),
          child: SafeArea(
            child: Center(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: ConstrainedBox(
                  constraints: BoxConstraints(maxWidth: widget.maxWidth, maxHeight: context.screenHeight * .9),
                  child: Material(
                    color: dark ? Dak.surface : Colors.white,
                    clipBehavior: Clip.antiAlias,
                    elevation: 8,
                    shadowColor: Colors.black.withValues(alpha: .1),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                      side: BorderSide(color: dark ? Dak.border : Light.border),
                    ),
                    child: SingleChildScrollView(child: widget.child),
                  ),
                ),
              ),
            ),
          ),
        );
      },
      child: widget.background,
    );
  }
}
