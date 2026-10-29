import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/query.dart';
import '../../theme/tokens.dart';
import '../../ui/asset_icon.dart';
import '../../ui/layout.dart';
import '../../ui/states.dart';

/// Public Terms / Privacy page, showing the version admins last published.
class PolicyPage extends ConsumerWidget {
  const PolicyPage({super.key, required this.type, required this.title});

  final String type;
  final String title;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final dark = context.isDark;
    final result = ref.watch(query('/policies/$type'));
    final data = result.value as Map<String, dynamic>?;
    final navy = dark ? Dak.heading : Auth.navy;
    final published = data == null ? null : DateTime.parse(data['publishedAt'] as String).toLocal();

    return Title(
      title: '$title · VÔL',
      color: Dak.cta,
      child: Scaffold(
        backgroundColor: context.pick(Colors.white, Dak.bg),
        body: SingleChildScrollView(
          padding: EdgeInsets.symmetric(horizontal: context.isSm ? 24 : 16, vertical: 40),
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 860),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Align(
                    alignment: Alignment.centerLeft,
                    child: InkWell(
                      onTap: () => context.canPop() ? context.pop() : context.go('/'),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Transform.flip(
                            flipX: true,
                            child: AssetIcon('icons/arrow-narrow-right.svg', width: 20, height: 20, color: dark ? Colors.white : null),
                          ),
                          const SizedBox(width: 6),
                          Text(
                            'Back',
                            style: TextStyle(fontSize: 16, fontWeight: FontWeight.w500, color: navy),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 24),
                  Row(
                    children: [
                      const AssetIcon('illustrations/vol-logo.png', height: 72),
                      const SizedBox(width: 16),
                      Text(
                        title,
                        style: TextStyle(fontSize: 30, fontWeight: FontWeight.w700, color: navy),
                      ),
                    ],
                  ),
                  if (result.hasError) ...[const SizedBox(height: 24), ErrorState(error: result.error!)],
                  if (data != null) ...[
                    const SizedBox(height: 24),
                    Text(
                      'Version ${data['version']} · Last updated ${published!.month}/${published.day}/${published.year}',
                      style: TextStyle(fontSize: 14, color: dark ? Dak.muted : const Color(0xFF929292)),
                    ),
                    const SizedBox(height: 24),
                    Container(
                      padding: const EdgeInsets.all(24),
                      decoration: BoxDecoration(
                        color: dark ? Dak.surface : Colors.white,
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: dark ? Dak.border : Light.border),
                      ),
                      child: SelectableText(
                        data['content'] as String,
                        style: TextStyle(fontSize: 16, height: 28 / 16, color: dark ? Dak.body : Hex.text),
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
