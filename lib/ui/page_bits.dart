import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../theme/tokens.dart';
import 'asset_icon.dart';
import 'layout.dart';

/// "← Back" link at the top of the form pages.
class BackLink extends StatelessWidget {
  const BackLink({super.key, required this.href, this.label = 'Back'});

  final String href;
  final String label;

  @override
  Widget build(BuildContext context) {
    final dark = context.isDark;
    return Align(
      alignment: Alignment.centerLeft,
      child: InkWell(
        onTap: () => context.go(href),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Transform.flip(
              flipX: true,
              child: AssetIcon('icons/arrow-narrow-right.svg', width: 20, height: 20, color: dark ? Colors.white : null),
            ),
            const SizedBox(width: 6),
            Text(
              label,
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.w500, color: dark ? Dak.heading : Auth.navy),
            ),
          ],
        ),
      ),
    );
  }
}

/// Numbered steps joined by a progress line, from components/ui/Stepper.tsx.
class StepTrack extends StatelessWidget {
  const StepTrack({super.key, required this.steps, required this.current});

  final List<String> steps;
  final int current;

  @override
  Widget build(BuildContext context) {
    final dark = context.isDark;
    final fill = steps.length > 1 ? current / (steps.length - 1) : 0.0;

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 24),
      child: LayoutBuilder(
        builder: (context, c) {
          return Stack(
            children: [
              Positioned(left: 16, right: 16, top: 15, child: Container(height: 2, color: dark ? Dak.border : Light.border)),
              Positioned(
                left: 16,
                top: 15,
                child: Container(height: 2, width: (c.maxWidth - 32) * fill, color: dark ? Dak.cta : Auth.navy),
              ),
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  for (final (i, label) in steps.indexed)
                    Expanded(
                      child: Column(
                        children: [
                          _Dot(index: i, done: i < current, active: i == current),
                          const SizedBox(height: 8),
                          Text(label, style: TextStyle(fontSize: 12, color: dark ? Dak.heading : Auth.navy)),
                        ],
                      ),
                    ),
                ],
              ),
            ],
          );
        },
      ),
    );
  }
}

class _Dot extends StatelessWidget {
  const _Dot({required this.index, required this.done, required this.active});

  final int index;
  final bool done;
  final bool active;

  @override
  Widget build(BuildContext context) {
    final dark = context.isDark;
    final accent = dark ? Dak.cta : Auth.navy;
    final (Color bg, Color border, Color fg) = done
        ? (accent, accent, Colors.white)
        : active
        ? (dark ? Dak.bg : Colors.white, accent, accent)
        : (dark ? Dak.surface : Colors.white, dark ? Dak.border : Light.border, dark ? Dak.muted : const Color(0xFF929292));
    return Container(
      width: 32,
      height: 32,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: bg,
        shape: BoxShape.circle,
        border: Border.all(color: border, width: 2),
      ),
      child: Text(
        done ? '✓' : '${index + 1}',
        style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: fg),
      ),
    );
  }
}

/// The browser's confirm(), as a dialog. Resolves to true when the user agrees.
Future<bool> confirmAction(BuildContext context, String message, {String confirmLabel = 'OK'}) async {
  final dark = context.isDark;
  final ok = await showDialog<bool>(
    context: context,
    builder: (context) => AlertDialog(
      backgroundColor: dark ? Dak.surface : Colors.white,
      content: Text(message, style: TextStyle(fontSize: 16, color: dark ? Dak.heading : Hex.black)),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel')),
        FilledButton(
          style: FilledButton.styleFrom(backgroundColor: Dak.cta, minimumSize: const Size(80, 40)),
          onPressed: () => Navigator.pop(context, true),
          child: Text(confirmLabel),
        ),
      ],
    ),
  );
  return ok ?? false;
}

/// window.prompt(): asks for one line of text.
Future<String?> promptText(BuildContext context, String message, {String initial = ''}) async {
  final controller = TextEditingController(text: initial);
  final dark = context.isDark;
  final result = await showDialog<String>(
    context: context,
    builder: (context) => AlertDialog(
      backgroundColor: dark ? Dak.surface : Colors.white,
      title: Text(message, style: TextStyle(fontSize: 16, color: dark ? Dak.heading : Hex.black)),
      content: TextField(
        controller: controller,
        autofocus: true,
        onSubmitted: (v) => Navigator.pop(context, v),
        style: TextStyle(color: dark ? Dak.heading : Hex.black),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
        FilledButton(
          style: FilledButton.styleFrom(backgroundColor: Dak.cta, minimumSize: const Size(80, 40)),
          onPressed: () => Navigator.pop(context, controller.text),
          child: const Text('OK'),
        ),
      ],
    ),
  );
  controller.dispose();
  return result;
}
