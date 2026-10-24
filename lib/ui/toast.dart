import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../theme/tokens.dart';
import 'layout.dart';

enum ToastTone { success, error }

class ToastItem {
  ToastItem(this.id, this.message, this.tone);

  final int id;
  final String message;
  final ToastTone tone;
}

/// `ref.read(toastProvider.notifier).show('Saved')`, like useToast() in apps/web.
final toastProvider = NotifierProvider<ToastNotifier, List<ToastItem>>(ToastNotifier.new);

class ToastNotifier extends Notifier<List<ToastItem>> {
  var _nextId = 0;

  @override
  List<ToastItem> build() => const [];

  void show(String message, [ToastTone tone = ToastTone.success]) {
    final id = ++_nextId;
    final kept = state.length > 2 ? state.sublist(state.length - 2) : state;
    state = [...kept, ToastItem(id, message, tone)];
    Timer(const Duration(seconds: 4), () => state = state.where((t) => t.id != id).toList());
  }

  void error(String message) => show(message, ToastTone.error);
}

/// Shows the toasts bottom-right (bottom-centre on phones) above everything else.
class ToastHost extends ConsumerWidget {
  const ToastHost({super.key, required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final items = ref.watch(toastProvider);
    final dark = context.isDark;
    final wide = context.isSm;

    return Stack(
      children: [
        child,
        Positioned(
          left: wide ? null : 16,
          right: wide ? 24 : 16,
          bottom: 16,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              for (final t in items)
                Padding(
                  padding: const EdgeInsets.only(top: 8),
                  child: Material(
                    color: t.tone == ToastTone.error ? const Color(0xFFDC2626) : (dark ? Dak.cta : Hex.black),
                    borderRadius: BorderRadius.circular(12),
                    elevation: 6,
                    child: ConstrainedBox(
                      constraints: const BoxConstraints(maxWidth: 384),
                      child: SizedBox(
                        width: wide ? 384 : double.infinity,
                        child: Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                          child: Text(
                            t.message,
                            style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w500, color: Colors.white),
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
            ],
          ),
        ),
      ],
    );
  }
}
