import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/api/api_error.dart';
import '../../core/auth/auth.dart';
import '../../theme/tokens.dart';
import '../../ui/layout.dart';
import '../../ui/modal.dart';
import '../../ui/toast.dart';

const _reasons = ['Spam', 'Harassment', 'Hate or abuse', 'Counterfeit goods', 'Misleading information', 'Intellectual property', 'Other'];

/// "Report" link that opens a small form; reports reach the admin panel's Cases list.
class ReportButton extends StatelessWidget {
  const ReportButton({super.key, required this.targetType, required this.targetId, this.label = 'Report', this.style});

  final String targetType;
  final String targetId;
  final String label;
  final TextStyle? style;

  @override
  Widget build(BuildContext context) {
    final grey = context.pick(const Color(0xFF929292), Dak.muted);
    return _HoverRed(
      builder: (hover) => GestureDetector(
        onTap: () => showModal<void>(
          context,
          maxWidth: 460,
          builder: (_) => _ReportForm(targetType: targetType, targetId: targetId),
        ),
        child: Text(
          label,
          style: (style ?? TextStyle(fontSize: 14, fontWeight: FontWeight.w500, color: grey)).copyWith(color: hover ? Hex.error : null),
        ),
      ),
    );
  }
}

class _HoverRed extends StatefulWidget {
  const _HoverRed({required this.builder});

  final Widget Function(bool hover) builder;

  @override
  State<_HoverRed> createState() => _HoverRedState();
}

class _HoverRedState extends State<_HoverRed> {
  bool _hover = false;

  @override
  Widget build(BuildContext context) => MouseRegion(
    cursor: SystemMouseCursors.click,
    onEnter: (_) => setState(() => _hover = true),
    onExit: (_) => setState(() => _hover = false),
    child: widget.builder(_hover),
  );
}

class _ReportForm extends ConsumerStatefulWidget {
  const _ReportForm({required this.targetType, required this.targetId});

  final String targetType;
  final String targetId;

  @override
  ConsumerState<_ReportForm> createState() => _ReportFormState();
}

class _ReportFormState extends ConsumerState<_ReportForm> {
  final _details = TextEditingController();
  String _reason = _reasons.first;
  bool _busy = false;

  @override
  void dispose() {
    _details.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    setState(() => _busy = true);
    final toast = ref.read(toastProvider.notifier);
    try {
      await ref.read(apiProvider).post<dynamic>('/reports', {
        'targetType': widget.targetType,
        'targetId': widget.targetId,
        'reason': _reason,
        if (_details.text.trim().isNotEmpty) 'details': _details.text.trim(),
      });
      toast.show('Thanks — our moderators will review this.');
      if (mounted) Navigator.pop(context);
    } catch (e) {
      toast.error(errorMessage(e));
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final dark = context.isDark;
    final navy = dark ? Dak.heading : Auth.navy;
    final label = TextStyle(fontSize: 14, fontWeight: FontWeight.w500, color: navy);

    return Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            'Report ${widget.targetType.toLowerCase()}',
            style: TextStyle(fontSize: 20, fontWeight: FontWeight.w600, color: navy),
          ),
          const SizedBox(height: 16),
          Text('Reason', style: label),
          const SizedBox(height: 8),
          Container(
            height: 44,
            padding: const EdgeInsets.symmetric(horizontal: 12),
            decoration: BoxDecoration(
              color: dark ? Dak.bg : Colors.white,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: dark ? Dak.border : Light.border),
            ),
            child: DropdownButtonHideUnderline(
              child: DropdownButton<String>(
                value: _reason,
                isExpanded: true,
                dropdownColor: dark ? Dak.surface : Colors.white,
                style: TextStyle(fontSize: 14, color: dark ? Dak.heading : Hex.black),
                items: [for (final r in _reasons) DropdownMenuItem(value: r, child: Text(r))],
                onChanged: (v) => setState(() => _reason = v ?? _reason),
              ),
            ),
          ),
          const SizedBox(height: 16),
          Text('Details (optional)', style: label),
          const SizedBox(height: 8),
          ModalField(controller: _details, lines: 3, maxLength: 2000),
          const SizedBox(height: 16),
          Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              ModalButton(label: 'Cancel', outline: true, onTap: () => Navigator.pop(context)),
              const SizedBox(width: 12),
              ModalButton(label: _busy ? 'Sending…' : 'Send report', color: Hex.error, onTap: _busy ? null : _submit),
            ],
          ),
        ],
      ),
    );
  }
}
