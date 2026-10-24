import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../theme/tokens.dart';
import 'asset_icon.dart';
import 'layout.dart';

/// Removable tag chips plus an "+ Add Tag" button that turns into an inline input.
class TagInput extends StatefulWidget {
  const TagInput({super.key, required this.tags, required this.onChanged, this.max = 20});

  final List<String> tags;
  final ValueChanged<List<String>> onChanged;
  final int max;

  @override
  State<TagInput> createState() => _TagInputState();
}

class _TagInputState extends State<TagInput> {
  final _draft = TextEditingController();
  final _focus = FocusNode();
  bool _adding = false;

  @override
  void initState() {
    super.initState();
    _focus.addListener(() {
      if (!_focus.hasFocus && _adding) _commit();
    });
  }

  @override
  void dispose() {
    _draft.dispose();
    _focus.dispose();
    super.dispose();
  }

  void _commit() {
    var tag = _draft.text.trim();
    if (tag.length > 60) tag = tag.substring(0, 60);
    final tags = widget.tags;
    if (tag.isNotEmpty && !tags.any((t) => t.toLowerCase() == tag.toLowerCase()) && tags.length < widget.max) {
      widget.onChanged([...tags, tag]);
    }
    _draft.clear();
    setState(() => _adding = false);
  }

  @override
  Widget build(BuildContext context) {
    final dark = context.isDark;
    const chipText = TextStyle(fontSize: 12, fontWeight: FontWeight.w600);

    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: [
        for (final tag in widget.tags)
          Container(
            height: 32,
            padding: const EdgeInsets.only(left: 13, right: 9),
            decoration: BoxDecoration(
              color: dark ? Colors.transparent : Hex.black,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: dark ? Dak.cta : Colors.white),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(tag, style: chipText.copyWith(color: dark ? Dak.heading : Colors.white)),
                const SizedBox(width: 4),
                Semantics(
                  label: 'Remove $tag',
                  button: true,
                  child: InkWell(
                    onTap: () => widget.onChanged(widget.tags.where((t) => t != tag).toList()),
                    child: SizedBox.square(
                      dimension: 16,
                      child: Center(child: AssetIcon('icons/tag-close.svg', width: 8, height: 8, color: dark ? null : Colors.white)),
                    ),
                  ),
                ),
              ],
            ),
          ),
        if (_adding)
          SizedBox(
            width: 160,
            height: 32,
            child: KeyboardListener(
              focusNode: FocusNode(skipTraversal: true),
              onKeyEvent: (e) {
                if (e is KeyDownEvent && e.logicalKey == LogicalKeyboardKey.escape) {
                  _draft.clear();
                  setState(() => _adding = false);
                }
              },
              child: TextField(
                controller: _draft,
                focusNode: _focus,
                autofocus: true,
                onSubmitted: (_) => _commit(),
                onChanged: (v) {
                  if (v.endsWith(',')) {
                    _draft.text = v.substring(0, v.length - 1);
                    _commit();
                  }
                },
                style: TextStyle(fontSize: 12, color: dark ? Dak.heading : Hex.black),
                decoration: InputDecoration(
                  hintText: 'Type and press Enter',
                  hintStyle: TextStyle(fontSize: 12, color: dark ? Dak.muted : Hex.text.withValues(alpha: .6)),
                  isDense: true,
                  contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
                  enabledBorder: _outline(dark ? Dak.border : Dak.cta),
                  focusedBorder: _outline(dark ? Dak.border : Dak.cta),
                ),
              ),
            ),
          )
        else if (widget.tags.length < widget.max)
          InkWell(
            onTap: () => setState(() => _adding = true),
            borderRadius: BorderRadius.circular(12),
            child: Container(
              height: 32,
              padding: const EdgeInsets.symmetric(horizontal: 13),
              decoration: BoxDecoration(
                color: dark ? Colors.transparent : Dak.cta.withValues(alpha: .2),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: dark ? Dak.border : Dak.cta),
              ),
              child: Center(
                widthFactor: 1,
                child: Text('+ Add Tag', style: chipText.copyWith(color: dark ? Dak.heading : Dak.cta)),
              ),
            ),
          ),
      ],
    );
  }

  OutlineInputBorder _outline(Color c) => OutlineInputBorder(
    borderRadius: BorderRadius.circular(12),
    borderSide: BorderSide(color: c),
  );
}
