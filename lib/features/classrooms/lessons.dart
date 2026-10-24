import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../core/format.dart';
import '../../models/classroom.dart';
import '../../theme/tokens.dart';
import '../../ui/asset_icon.dart';
import '../../ui/embed/html_embed.dart';
import '../../ui/layout.dart';
import '../../ui/modal.dart';

const lessonIcon = {
  'VIDEO': 'icons/play.svg',
  'DOCUMENT': 'icons/document.svg',
  'CANVAS': 'icons/new-canvas.svg',
  'QUIZ': 'icons/checkmark-circle.svg',
};

const lessonKindLabel = {'VIDEO': 'Video', 'DOCUMENT': 'Document', 'CANVAS': 'Canvas', 'QUIZ': 'Quiz'};

/// "Video • 12 mins", "Canvas Linked: 'Standard Truss Setup A'"…
String lessonMeta({required String kind, int? durationMinutes, String? resourceUrl, String? canvasTitle}) {
  final parts = [lessonKindLabel[kind] ?? kind];
  final minutes = formatMinutes(durationMinutes);
  if (minutes != null) parts.add(minutes);
  if (kind == 'CANVAS' && canvasTitle != null) return "Canvas Linked: '$canvasTitle'";
  if (kind == 'DOCUMENT' && resourceUrl != null) parts.add('File attached');
  return parts.join(' • ');
}

String metaOf(Lesson l) =>
    lessonMeta(kind: l.kind, durationMinutes: l.durationMinutes, resourceUrl: l.resourceUrl, canvasTitle: l.canvas?.title);

bool _isVideoFile(String url) => RegExp(r'\.(mp4|webm)(\?|$)', caseSensitive: false).hasMatch(url);
bool isPdf(String url) => RegExp(r'\.pdf(\?|$)', caseSensitive: false).hasMatch(url);

/// Opens a lesson: plays the video, shows the document or canvas link, lists quiz questions.
/// [onToggleComplete] returns the lesson as it is after the change, so the dialog can update.
Future<void> showLesson(
  BuildContext context, {
  required Lesson lesson,
  required bool canTrack,
  required Future<Lesson?> Function(Lesson) onToggleComplete,
}) {
  return showModal<void>(
    context,
    maxWidth: 860,
    builder: (_) => _LessonViewer(lesson: lesson, canTrack: canTrack, onToggleComplete: onToggleComplete),
  );
}

class _LessonViewer extends StatefulWidget {
  const _LessonViewer({required this.lesson, required this.canTrack, required this.onToggleComplete});

  final Lesson lesson;
  final bool canTrack;
  final Future<Lesson?> Function(Lesson) onToggleComplete;

  @override
  State<_LessonViewer> createState() => _LessonViewerState();
}

class _LessonViewerState extends State<_LessonViewer> {
  late Lesson _lesson = widget.lesson;
  bool _busy = false;

  @override
  Widget build(BuildContext context) {
    final dark = context.isDark;
    final l = _lesson;
    final minutes = formatMinutes(l.durationMinutes);
    final url = l.resourceUrl;
    final ink = dark ? Dak.heading : Hex.black;
    final body = dark ? Dak.body : Hex.text;

    Widget linkOut(String label, String href) => Material(
      color: Hex.text,
      borderRadius: BorderRadius.circular(8),
      child: InkWell(
        borderRadius: BorderRadius.circular(8),
        onTap: () => launchUrl(Uri.parse(href), webOnlyWindowName: '_blank'),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          child: Text(
            label,
            textAlign: TextAlign.center,
            style: const TextStyle(fontSize: 16, color: Colors.white),
          ),
        ),
      ),
    );

    return Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '${l.kind}${minutes != null ? ' · ${minutes.toUpperCase()}' : ''}',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        letterSpacing: .4,
                        color: dark ? Dak.muted : const Color(0xFF929292),
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      l.title,
                      style: TextStyle(fontSize: 24, fontWeight: FontWeight.w600, color: ink),
                    ),
                  ],
                ),
              ),
              IconButton(
                tooltip: 'Close',
                onPressed: () => Navigator.pop(context),
                icon: Text('✕', style: TextStyle(fontSize: 20, color: ink)),
              ),
            ],
          ),
          if (l.kind == 'VIDEO' && url != null) ...[
            const SizedBox(height: 16),
            _isVideoFile(url)
                ? ClipRRect(
                    borderRadius: BorderRadius.circular(8),
                    child: AspectRatio(aspectRatio: 16 / 9, child: htmlVideo(url)),
                  )
                : linkOut('Watch video ↗', url),
          ],
          if (l.kind == 'DOCUMENT' && url != null) ...[
            const SizedBox(height: 16),
            isPdf(url)
                ? Container(
                    height: context.screenHeight * .6,
                    clipBehavior: Clip.antiAlias,
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: dark ? Dak.border : Light.border),
                    ),
                    child: htmlFrame(url, l.title),
                  )
                : linkOut('Open document ↗', url),
          ],
          if (l.kind == 'CANVAS' && l.canvas != null) ...[
            const SizedBox(height: 16),
            Material(
              color: Dak.cta,
              borderRadius: BorderRadius.circular(8),
              child: InkWell(
                borderRadius: BorderRadius.circular(8),
                onTap: () {
                  Navigator.pop(context);
                  context.go('/canvas/${l.canvas!.id}');
                },
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  child: Text(
                    'Open canvas: ${l.canvas!.title}',
                    textAlign: TextAlign.center,
                    style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w500, color: Colors.white),
                  ),
                ),
              ),
            ),
          ],
          if (l.body != null && l.body!.isNotEmpty) ...[
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(color: dark ? Dak.bg : const Color(0xFFF8F9FF), borderRadius: BorderRadius.circular(8)),
              child: l.kind == 'QUIZ'
                  ? Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        for (final (i, q) in l.body!.split('\n').where((q) => q.trim().isNotEmpty).indexed)
                          Padding(
                            padding: EdgeInsets.only(top: i == 0 ? 0 : 8),
                            child: Text(
                              '${i + 1}. ${q.replaceFirst(RegExp(r'^\d+[.)]\s*'), '')}',
                              style: TextStyle(fontSize: 16, color: body),
                            ),
                          ),
                      ],
                    )
                  : Text(l.body!, style: TextStyle(fontSize: 16, color: body)),
            ),
          ],
          if (url == null && l.canvas == null && (l.body == null || l.body!.isEmpty)) ...[
            const SizedBox(height: 16),
            Text(
              "The instructor hasn't attached content to this lesson yet.",
              style: TextStyle(fontSize: 14, color: dark ? Dak.muted : const Color(0xFF929292)),
            ),
          ],
          if (widget.canTrack) ...[
            const SizedBox(height: 16),
            Align(
              alignment: Alignment.centerRight,
              child: Opacity(
                opacity: _busy ? .6 : 1,
                child: Material(
                  color: l.completed ? Colors.transparent : (dark ? Dak.cta : Hex.black),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                    side: l.completed ? BorderSide(color: dark ? Dak.border : Light.border) : BorderSide.none,
                  ),
                  child: InkWell(
                    borderRadius: BorderRadius.circular(8),
                    onTap: _busy
                        ? null
                        : () async {
                            setState(() => _busy = true);
                            final fresh = await widget.onToggleComplete(_lesson);
                            if (!mounted) return;
                            setState(() {
                              _busy = false;
                              if (fresh != null) _lesson = fresh;
                            });
                          },
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                      child: Text(
                        l.completed ? 'Mark as not done' : 'Mark complete ✓',
                        style: TextStyle(fontSize: 14, fontWeight: FontWeight.w500, color: l.completed ? ink : Colors.white),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

/// Icon + title + meta row for a lesson resource.
class ResourceRow extends StatelessWidget {
  const ResourceRow({super.key, required this.lesson, required this.onOpen});

  final Lesson lesson;
  final VoidCallback onOpen;

  @override
  Widget build(BuildContext context) {
    final dark = context.isDark;
    final l = lesson;
    final icon = l.kind == 'CANVAS'
        ? 'icons/resource-canvas.svg'
        : (l.resourceUrl != null && isPdf(l.resourceUrl!) ? 'icons/pdf.svg' : lessonIcon[l.kind]!);
    return InkWell(
      onTap: onOpen,
      child: Row(
        children: [
          Container(
            width: 32,
            height: 32,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: Hex.black.withValues(alpha: .1),
              borderRadius: BorderRadius.circular(2),
              border: Border.all(color: dark ? Dak.border : Hex.text.withValues(alpha: .4)),
            ),
            child: AssetIcon(icon, width: 14, height: 14, color: dark ? Colors.white : null),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  l.kind == 'CANVAS' ? (l.canvas?.title ?? '') : l.title,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: dark ? Dak.heading : Hex.black),
                ),
                Text(metaOf(l), style: TextStyle(fontSize: 14, color: dark ? Dak.body : Hex.text)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
