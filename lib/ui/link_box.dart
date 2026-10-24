import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

/// Makes any widget behave like a `<Link>`: pointer cursor, click navigates.
class LinkBox extends StatelessWidget {
  const LinkBox({super.key, required this.href, required this.child, this.onTap});

  final String href;
  final Widget child;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      cursor: SystemMouseCursors.click,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: () {
          onTap?.call();
          context.go(href);
        },
        child: child,
      ),
    );
  }
}

/// A plain text link, e.g. "View All Workspaces".
class TextLink extends StatelessWidget {
  const TextLink(this.label, {super.key, required this.href, required this.style});

  final String label;
  final String href;
  final TextStyle style;

  @override
  Widget build(BuildContext context) => LinkBox(
    href: href,
    child: Text(label, style: style),
  );
}
