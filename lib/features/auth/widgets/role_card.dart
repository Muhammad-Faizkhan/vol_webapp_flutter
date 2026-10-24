import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/api/api_error.dart';
import '../../../core/auth/auth.dart';
import '../../../core/auth/me.dart';
import '../../../theme/tokens.dart';
import '../../../ui/asset_icon.dart';
import '../../../ui/layout.dart';

/// Port of components/auth/RoleCard.tsx. Signed-in users who haven't picked an account type yet
/// choose it here; everyone else follows the link to signup.
class RoleCard extends ConsumerStatefulWidget {
  const RoleCard({
    super.key,
    required this.icon,
    required this.title,
    required this.description,
    required this.buttonLabel,
    required this.persona,
    this.primary = true,
    this.roundIcon = true,
  });

  final String icon;
  final String title;
  final String description;
  final String buttonLabel;
  final String persona;
  final bool primary;
  final bool roundIcon;

  @override
  ConsumerState<RoleCard> createState() => _RoleCardState();
}

class _RoleCardState extends ConsumerState<RoleCard> {
  bool _saving = false;
  String? _error;

  bool get _business => widget.persona == 'business';

  Future<void> _choose() async {
    setState(() {
      _saving = true;
      _error = null;
    });
    final api = ref.read(apiProvider);
    try {
      final json = await api.patch<Map<String, dynamic>>('/users/me', {'accountType': _business ? 'BUSINESS' : 'INDIVIDUAL'});
      final updated = Me.fromJson(json);
      api.updateUser(updated);
      if (mounted) context.go(homeFor(updated));
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = errorMessage(e);
        _saving = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final dark = context.isDark;
    final user = ref.watch(authProvider);
    final choosing = user != null && !user.onboarded;
    final primary = widget.primary;

    final label = choosing ? (_saving ? 'Saving…' : 'Continue as ${_business ? 'Business' : 'Individual'}') : widget.buttonLabel;
    final VoidCallback? onTap = choosing
        ? (_saving ? null : _choose)
        : () => context.go(user != null ? homeFor(user) : '/signup?persona=${widget.persona}');

    final buttonColor = primary ? Dak.cta : const Color(0xFF020202);
    final radius = BorderRadius.circular(16);

    return Container(
      width: double.infinity,
      constraints: BoxConstraints(minHeight: context.dvh(120, 17, 280)),
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        color: primary ? (dark ? const Color(0xFF1E1E22) : Colors.white) : (dark ? Dak.surface : Colors.white),
        borderRadius: radius,
        border: Border.all(color: primary ? Dak.cta : (dark ? Dak.border : Light.border)),
      ),
      child: Stack(
        children: [
          Positioned(left: 0, right: 0, top: 0, height: 4, child: ColoredBox(color: primary ? Dak.cta : (dark ? Dak.body : Auth.navy))),
          Padding(
            padding: EdgeInsets.symmetric(horizontal: context.isSm ? 41 : 24, vertical: context.dvh(10, 1.6, 25)),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                ClipRRect(
                  borderRadius: BorderRadius.circular(widget.roundIcon ? 30 : 0),
                  child: AssetIcon(widget.icon, width: 60, height: 60, fit: BoxFit.cover),
                ),
                const SizedBox(height: 6),
                Text(
                  widget.title,
                  style: TextStyle(fontSize: 24, fontWeight: FontWeight.w600, color: dark ? Dak.heading : Auth.navy),
                ),
                const SizedBox(height: 6),
                Text(
                  widget.description,
                  style: TextStyle(fontSize: 16, height: 23 / 16, color: dark ? Dak.body : Auth.navy),
                ),
                if (_error != null) ...[
                  const SizedBox(height: 6),
                  Text(
                    _error!,
                    style: TextStyle(fontSize: 14, fontWeight: FontWeight.w500, color: dark ? Hex.errorDark : Hex.error),
                  ),
                ],
                const SizedBox(height: 6),
                Opacity(
                  opacity: onTap == null ? .6 : 1,
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      color: buttonColor,
                      borderRadius: radius,
                      boxShadow: [
                        BoxShadow(
                          color: buttonColor.withValues(alpha: .4),
                          offset: const Offset(0, 8),
                          blurRadius: primary && dark ? 6 : 16,
                        ),
                      ],
                    ),
                    child: Material(
                      type: MaterialType.transparency,
                      child: InkWell(
                        onTap: onTap,
                        borderRadius: radius,
                        child: SizedBox(
                          height: 56,
                          width: double.infinity,
                          child: Center(
                            child: Text(
                              label,
                              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w500, color: Colors.white),
                            ),
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
      ),
    );
  }
}
