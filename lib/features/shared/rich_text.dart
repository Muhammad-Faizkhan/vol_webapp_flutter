import 'package:flutter/material.dart';

// Posts support a tiny markdown subset written by the create-post toolbar:
// **bold**, *italic*, "1. " numbered lines and "- " bulleted lines.

enum Format { bold, italic, numbered, bulleted }

/// Applies a toolbar format to the selection in [value].
TextEditingValue applyFormat(TextEditingValue value, Format kind) {
  final text = value.text;
  final start = value.selection.isValid ? value.selection.start : text.length;
  final end = value.selection.isValid ? value.selection.end : text.length;

  if (kind == Format.bold || kind == Format.italic) {
    final mark = kind == Format.bold ? '**' : '*';
    var selected = text.substring(start, end);
    if (selected.isEmpty) selected = kind == Format.bold ? 'bold text' : 'italic text';
    return TextEditingValue(
      text: text.substring(0, start) + mark + selected + mark + text.substring(end),
      selection: TextSelection(baseOffset: start + mark.length, extentOffset: start + mark.length + selected.length),
    );
  }

  // Lists: prefix every selected line (or the current line).
  final lineStart = start == 0 ? 0 : text.lastIndexOf('\n', start - 1) + 1;
  final nextBreak = text.indexOf('\n', end);
  final lineEnd = nextBreak == -1 ? text.length : nextBreak;
  final lines = text.substring(lineStart, lineEnd).split('\n');
  final prefixed = [
    for (final (i, line) in lines.indexed)
      (kind == Format.numbered ? '${i + 1}. ' : '- ') + line.replaceFirst(RegExp(r'^(\d+\.\s|-\s)'), ''),
  ].join('\n');
  return TextEditingValue(
    text: text.substring(0, lineStart) + prefixed + text.substring(lineEnd),
    selection: TextSelection(baseOffset: lineStart, extentOffset: lineStart + prefixed.length),
  );
}

List<InlineSpan> _inline(String text) {
  final out = <InlineSpan>[];
  var last = 0;
  for (final m in RegExp(r'\*\*(.+?)\*\*|\*(.+?)\*').allMatches(text)) {
    if (m.start > last) out.add(TextSpan(text: text.substring(last, m.start)));
    out.add(
      m.group(1) != null
          ? TextSpan(
              text: m.group(1),
              style: const TextStyle(fontWeight: FontWeight.w700),
            )
          : TextSpan(
              text: m.group(2),
              style: const TextStyle(fontStyle: FontStyle.italic),
            ),
    );
    last = m.end;
  }
  if (last < text.length) out.add(TextSpan(text: text.substring(last)));
  return out;
}

/// Renders post text. Never parses HTML, so user text can't inject markup.
class PostText extends StatelessWidget {
  const PostText(this.text, {super.key, required this.style});

  final String text;
  final TextStyle style;

  @override
  Widget build(BuildContext context) {
    final blocks = <Widget>[];
    List<String>? items;
    var ordered = false;

    void flush() {
      if (items == null) return;
      final list = items!;
      blocks.add(
        Padding(
          padding: const EdgeInsets.only(left: 24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              for (final (i, item) in list.indexed)
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    SizedBox(
                      width: ordered ? 20 : 14,
                      child: Text(ordered ? '${i + 1}.' : '•', style: style),
                    ),
                    Expanded(
                      child: Text.rich(TextSpan(children: _inline(item)), style: style),
                    ),
                  ],
                ),
            ],
          ),
        ),
      );
      items = null;
    }

    for (final line in text.split('\n')) {
      final numbered = RegExp(r'^\d+\.\s+(.*)$').firstMatch(line);
      final bullet = RegExp(r'^[-*]\s+(.*)$').firstMatch(line);
      if (numbered != null || bullet != null) {
        final isOrdered = numbered != null;
        if (items == null || ordered != isOrdered) {
          flush();
          items = [];
          ordered = isOrdered;
        }
        items!.add((numbered ?? bullet)!.group(1)!);
      } else {
        flush();
        blocks.add(line.isEmpty ? SizedBox(height: style.fontSize ?? 16) : Text.rich(TextSpan(children: _inline(line)), style: style));
      }
    }
    flush();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        for (final (i, b) in blocks.indexed) ...[if (i > 0) const SizedBox(height: 4), b],
      ],
    );
  }
}
