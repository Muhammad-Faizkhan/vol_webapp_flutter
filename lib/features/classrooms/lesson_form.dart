import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/api/api_error.dart';
import '../../core/api/upload.dart';
import '../../core/auth/auth.dart';
import '../../models/classroom.dart';
import '../../theme/tokens.dart';
import '../../ui/asset_icon.dart';
import '../../ui/layout.dart';
import '../shared/canvas_picker.dart';
import 'lessons.dart';

/// A lesson being written in the curriculum builder, before the API has it.
class LessonInput {
  const LessonInput({
    required this.title,
    required this.kind,
    this.durationMinutes,
    this.resourceUrl,
    this.canvasId,
    this.canvasTitle,
    this.body,
  });

  final String title;
  final String kind;
  final int? durationMinutes;
  final String? resourceUrl;
  final String? canvasId;
  // Display only: the linked canvas's title.
  final String? canvasTitle;
  final String? body;

  Map<String, dynamic> toBody() => {
    'title': title,
    'kind': kind,
    'durationMinutes': ?durationMinutes,
    'resourceUrl': resourceUrl,
    'canvasId': canvasId,
    'body': ?body,
  };
}

/// One lesson in the builder lists, with an optional delete button.
class LessonRow extends StatelessWidget {
  const LessonRow({super.key, required this.title, required this.kind, required this.meta, this.onDelete});

  LessonRow.lesson(Lesson l, {Key? key, VoidCallback? onDelete})
    : this(key: key, title: l.title, kind: l.kind, meta: metaOf(l), onDelete: onDelete);

  final String title;
  final String kind;
  final String meta;
  final VoidCallback? onDelete;

  @override
  Widget build(BuildContext context) {
    final dark = context.isDark;
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: dark ? Dak.border : const Color(0xFFF8F9FF),
        borderRadius: BorderRadius.circular(4),
        border: Border.all(color: dark ? Light.border.withValues(alpha: .2) : Light.border),
      ),
      child: Row(
        children: [
          Container(
            width: 40,
            height: 40,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: dark ? Dak.heading.withValues(alpha: .1) : Auth.navy.withValues(alpha: .1),
              borderRadius: BorderRadius.circular(4),
            ),
            child: AssetIcon(lessonIcon[kind]!, width: 20, height: 20, color: dark ? Colors.white : null),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(fontSize: 14, fontWeight: FontWeight.w500, color: dark ? Dak.heading : Auth.navy),
                ),
                const SizedBox(height: 4),
                Text(
                  meta,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(fontSize: 12, color: dark ? Dak.body : Auth.navy),
                ),
              ],
            ),
          ),
          if (onDelete != null)
            Tooltip(
              message: 'Delete $title',
              child: InkWell(
                onTap: onDelete,
                child: const Padding(
                  padding: EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  child: Text('✕', style: TextStyle(fontSize: 14, color: Color(0xFF929292))),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

/// Inline "Add Lesson" form.
class LessonForm extends ConsumerStatefulWidget {
  const LessonForm({super.key, required this.onSubmit, required this.onCancel});

  final Future<void> Function(LessonInput lesson) onSubmit;
  final VoidCallback onCancel;

  @override
  ConsumerState<LessonForm> createState() => _LessonFormState();
}

class _LessonFormState extends ConsumerState<LessonForm> {
  final _title = TextEditingController();
  final _duration = TextEditingController();
  final _url = TextEditingController();
  final _body = TextEditingController();
  String _kind = 'VIDEO';
  ({String id, String title})? _canvas;
  String? _error;
  bool _saving = false;
  bool _uploading = false;

  @override
  void dispose() {
    for (final c in [_title, _duration, _url, _body]) {
      c.dispose();
    }
    super.dispose();
  }

  Future<void> _upload() async {
    final kind = _kind == 'VIDEO' ? UploadKind.media : UploadKind.document;
    final file = await pickFile(kind);
    if (file == null) return;
    setState(() => _uploading = true);
    try {
      final url = await uploadFile(ref.read(apiProvider), file, kind);
      setState(() => _url.text = url);
    } catch (e) {
      setState(() => _error = errorMessage(e));
    } finally {
      if (mounted) setState(() => _uploading = false);
    }
  }

  Future<void> _submit() async {
    if (_title.text.trim().isEmpty) return setState(() => _error = 'Give the lesson a title.');
    if (_kind == 'CANVAS' && _canvas == null) return setState(() => _error = 'Pick a canvas to link.');
    setState(() {
      _error = null;
      _saving = true;
    });
    final minutes = num.tryParse(_duration.text);
    final resource = _kind == 'VIDEO' || _kind == 'DOCUMENT' ? _url.text.trim() : '';
    try {
      await widget.onSubmit(
        LessonInput(
          title: _title.text.trim(),
          kind: _kind,
          durationMinutes: minutes?.round().clamp(0, 1 << 31),
          resourceUrl: resource.isEmpty ? null : resource,
          canvasId: _kind == 'CANVAS' ? _canvas?.id : null,
          canvasTitle: _canvas?.title,
          body: _body.text.trim().isEmpty ? null : _body.text.trim(),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e is ApiError ? e.message : "Couldn't add the lesson";
        _saving = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final dark = context.isDark;
    final navy = dark ? Dak.heading : Auth.navy;
    final border = dark ? Dak.border : Light.border;
    final grey = dark ? Dak.muted : const Color(0xFF929292);

    Widget field(TextEditingController c, String hint, {bool number = false, int lines = 1, bool autofocus = false}) => Container(
      height: lines == 1 ? 44 : null,
      padding: EdgeInsets.symmetric(horizontal: 12, vertical: lines == 1 ? 0 : 12),
      alignment: Alignment.centerLeft,
      decoration: BoxDecoration(
        color: dark ? Dak.bg : Colors.white,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: border),
      ),
      child: TextField(
        controller: c,
        autofocus: autofocus,
        minLines: lines,
        maxLines: lines,
        keyboardType: number ? TextInputType.number : null,
        inputFormatters: number ? [FilteringTextInputFormatter.digitsOnly] : null,
        style: TextStyle(fontSize: 14, color: navy),
        decoration: InputDecoration.collapsed(
          hintText: hint,
          hintStyle: TextStyle(fontSize: 14, color: grey),
        ),
      ),
    );

    final kind = Container(
      height: 44,
      padding: const EdgeInsets.symmetric(horizontal: 12),
      decoration: BoxDecoration(
        color: dark ? Dak.bg : Colors.white,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: border),
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<String>(
          value: _kind,
          isExpanded: true,
          dropdownColor: dark ? Dak.surface : Colors.white,
          style: TextStyle(fontSize: 14, color: navy),
          items: [for (final e in lessonKindLabel.entries) DropdownMenuItem(value: e.key, child: Text(e.value))],
          onChanged: (v) => setState(() => _kind = v ?? _kind),
        ),
      ),
    );

    final hasResource = _kind == 'VIDEO' || _kind == 'DOCUMENT';

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: dark ? Dak.surface : Colors.white,
        borderRadius: BorderRadius.circular(4),
        border: Border.all(color: Dak.cta),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (context.isSm)
            Row(
              children: [
                Expanded(flex: 2, child: field(_title, 'Lesson title', autofocus: true)),
                const SizedBox(width: 12),
                Expanded(child: kind),
                const SizedBox(width: 12),
                Expanded(child: field(_duration, 'Minutes', number: true)),
              ],
            )
          else ...[
            field(_title, 'Lesson title', autofocus: true),
            const SizedBox(height: 12),
            kind,
            const SizedBox(height: 12),
            field(_duration, 'Minutes', number: true),
          ],
          if (hasResource) ...[
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(child: field(_url, _kind == 'VIDEO' ? 'Video URL (or upload an MP4)' : 'Document URL (or upload a PDF)')),
                const SizedBox(width: 8),
                Opacity(
                  opacity: _uploading ? .6 : 1,
                  child: OutlinedButton(
                    onPressed: _uploading ? null : _upload,
                    style: OutlinedButton.styleFrom(
                      foregroundColor: navy,
                      side: BorderSide(color: border),
                      minimumSize: const Size(0, 44),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                    ),
                    child: Text(_uploading ? 'Uploading…' : 'Upload', style: const TextStyle(fontSize: 14)),
                  ),
                ),
              ],
            ),
          ],
          if (_kind == 'CANVAS') ...[
            const SizedBox(height: 12),
            InkWell(
              borderRadius: BorderRadius.circular(8),
              onTap: () async {
                final c = await pickCanvas(context, 'Link a canvas');
                if (c != null) setState(() => _canvas = (id: c.id, title: c.title));
              },
              child: Container(
                height: 44,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Dak.cta),
                ),
                child: Text(
                  _canvas != null ? 'Linked: ${_canvas!.title} (change)' : 'Link a canvas…',
                  style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w500, color: Dak.cta),
                ),
              ),
            ),
          ],
          if (_kind != 'CANVAS') ...[
            const SizedBox(height: 12),
            field(_body, _kind == 'QUIZ' ? 'Questions, one per line…' : 'Notes for students (optional)', lines: _kind == 'QUIZ' ? 4 : 2),
          ],
          if (_error != null) ...[const SizedBox(height: 12), Text(_error!, style: const TextStyle(fontSize: 14, color: Hex.error))],
          const SizedBox(height: 12),
          Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              TextButton(
                onPressed: widget.onCancel,
                child: Text('Cancel', style: TextStyle(fontSize: 14, color: navy)),
              ),
              const SizedBox(width: 8),
              Opacity(
                opacity: _saving ? .6 : 1,
                child: Material(
                  color: Dak.cta,
                  borderRadius: BorderRadius.circular(8),
                  child: InkWell(
                    borderRadius: BorderRadius.circular(8),
                    onTap: _saving ? null : _submit,
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                      child: Text(
                        _saving ? 'Adding…' : 'Add Lesson',
                        style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w500, color: Colors.white),
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
