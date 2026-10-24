import 'package:flutter/material.dart';

import '../../theme/tokens.dart';
import '../../ui/layout.dart';
import 'app_header.dart';
import 'sidebar.dart';

/// The signed-in layout from app/(app)/layout.tsx: fixed sidebar (a drawer below lg), fixed header,
/// and the page scrolling underneath. Past 1920px the whole shell is centred.
class AppShell extends StatefulWidget {
  const AppShell({super.key, required this.location, required this.child});

  final String location;
  final Widget child;

  @override
  State<AppShell> createState() => _AppShellState();
}

class _AppShellState extends State<AppShell> {
  bool _menuOpen = false;

  @override
  void didUpdateWidget(covariant AppShell oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.location != widget.location) _menuOpen = false;
  }

  @override
  Widget build(BuildContext context) {
    final wide = context.isLg;
    final width = context.screenWidth;
    final gutter = width > 1920 ? (width - 1920) / 2 : 0.0;
    final sidebarWidth = (width * .208333).clamp(240.0, 400.0);
    final headerHeight = wide ? 100.0 : 80.0;
    final left = wide ? gutter + sidebarWidth : 0.0;

    final hPad = wide ? 50.0 : (context.isSm ? 24.0 : 16.0);
    final top = wide ? context.dvh(112, 14, 140) : 96.0;

    return Scaffold(
      backgroundColor: context.pick(Light.appBg, Dak.bg),
      body: Stack(
        children: [
          Positioned(
            left: left,
            right: gutter,
            top: 0,
            bottom: 0,
            child: SingleChildScrollView(
              key: PageStorageKey(widget.location),
              padding: EdgeInsets.fromLTRB(hPad, top, hPad, wide ? 40 : 32),
              child: widget.child,
            ),
          ),
          Positioned(
            left: left,
            right: gutter,
            top: 0,
            height: headerHeight,
            child: AppHeader(onMenu: () => setState(() => _menuOpen = true)),
          ),
          if (wide)
            Positioned(
              left: gutter,
              top: 0,
              bottom: 0,
              width: sidebarWidth,
              child: Sidebar(location: widget.location),
            )
          else ...[
            if (_menuOpen)
              Positioned.fill(
                child: GestureDetector(
                  onTap: () => setState(() => _menuOpen = false),
                  child: const ColoredBox(color: Color(0x80000000)),
                ),
              ),
            AnimatedPositioned(
              duration: const Duration(milliseconds: 200),
              curve: Curves.easeOut,
              top: 0,
              bottom: 0,
              left: _menuOpen ? 0 : -(width * .85).clamp(0.0, 280.0),
              width: (width * .85).clamp(0.0, 280.0),
              child: Sidebar(location: widget.location, onClose: () => setState(() => _menuOpen = false)),
            ),
          ],
        ],
      ),
    );
  }
}
