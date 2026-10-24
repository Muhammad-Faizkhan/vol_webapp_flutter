import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/api/api_error.dart';
import '../../core/auth/auth.dart';
import '../../core/format.dart';
import '../../core/query.dart';
import '../../models/classroom.dart';
import '../../theme/tokens.dart';
import '../../ui/asset_icon.dart';
import '../../ui/auto_grid.dart';
import '../../ui/card_box.dart';
import '../../ui/layout.dart';
import '../../ui/link_box.dart';
import '../../ui/page_bits.dart';
import '../../ui/progress_bar.dart';
import '../../ui/states.dart';
import '../../ui/toast.dart';
import '../../ui/user_image.dart';
import '../shared/workspace_card.dart';
import 'discussions.dart';
import 'lessons.dart';

typedef _Located = ({Lesson lesson, int moduleIndex});

class ClassroomPage extends ConsumerStatefulWidget {
  const ClassroomPage({super.key, required this.classroomId, this.tab});

  final String classroomId;
  final String? tab;

  @override
  ConsumerState<ClassroomPage> createState() => _ClassroomPageState();
}

class _ClassroomPageState extends ConsumerState<ClassroomPage> {
  late String _tab = widget.tab == 'discussions' ? 'discussions' : 'curriculum';
  final _open = <String, bool>{};
  bool _copied = false;

  String get _path => '/classrooms/${widget.classroomId}';

  Future<Lesson?> _toggleComplete(Lesson lesson) async {
    final api = ref.read(apiProvider);
    try {
      final json = lesson.completed
          ? await api.delete<Map<String, dynamic>>('/lessons/${lesson.id}/complete')
          : await api.post<Map<String, dynamic>>('/lessons/${lesson.id}/complete');
      final updated = ClassroomDetail.fromJson(json);
      invalidateQueries(ref);
      return updated.modules.expand((m) => m.lessons).where((l) => l.id == lesson.id).firstOrNull;
    } catch (e) {
      ref.read(toastProvider.notifier).error(errorMessage(e));
      return null;
    }
  }

  Future<void> _copyJoinCode(String code) async {
    await Clipboard.setData(ClipboardData(text: formatJoinCode(code)));
    setState(() => _copied = true);
    Timer(const Duration(milliseconds: 1500), () {
      if (mounted) setState(() => _copied = false);
    });
  }

  Future<void> _act(ClassroomDetail c, String action) async {
    final text = switch (action) {
      'leave' => 'Leave "${c.title}"?',
      'archive' => 'Archive "${c.title}"? Students keep access to finished work but it disappears from lists.',
      _ => 'Delete "${c.title}" for everyone? This can\'t be undone.',
    };
    if (!await confirmAction(context, text)) return;
    final api = ref.read(apiProvider);
    final toast = ref.read(toastProvider.notifier);
    try {
      if (action == 'delete') {
        await api.delete<dynamic>('/classrooms/${c.id}');
      } else {
        await api.post<dynamic>('/classrooms/${c.id}/$action');
      }
      invalidateQueries(ref);
      toast.show(switch (action) {
        'leave' => 'You left the classroom',
        'archive' => 'Classroom archived',
        _ => 'Classroom deleted',
      });
      if (mounted) context.go(c.isInstructor ? '/classrooms/manage' : '/classrooms');
    } catch (e) {
      toast.error(errorMessage(e));
    }
  }

  void _view(ClassroomDetail c, Lesson lesson) =>
      showLesson(context, lesson: lesson, canTrack: c.isEnrolled, onToggleComplete: _toggleComplete);

  @override
  Widget build(BuildContext context) {
    final result = ref.watch(query(_path));
    if (result.hasError) return ErrorState(error: result.error!);
    final json = result.value as Map<String, dynamic>?;
    if (json == null) return const SizedBox.shrink();
    final c = ClassroomDetail.fromJson(json);

    final dark = context.isDark;
    final member = c.isInstructor || c.isEnrolled;
    final students = c.isInstructor ? listOf(ref, '$_path/students', Student.fromJson) : null;
    final all = <_Located>[
      for (final m in c.modules)
        for (final l in m.lessons) (lesson: l, moduleIndex: m.position),
    ];
    final nextUp = c.isEnrolled ? all.where((l) => !l.lesson.completed).firstOrNull : null;
    final canvasLessons = all.where((l) => l.lesson.kind == 'CANVAS' && l.lesson.canvas != null).toList();
    final documents = all.where((l) => (l.lesson.kind == 'DOCUMENT' || l.lesson.kind == 'VIDEO') && l.lesson.resourceUrl != null);
    final resources = [...documents, ...canvasLessons].map((l) => l.lesson).toList();
    final tabs = [
      ('curriculum', 'Curriculum', 0),
      ('canvas', 'Shared Canvas', 0),
      ('resources', 'Resources', 0),
      if (member) ('discussions', 'Discussions', c.discussionCount),
    ];
    // Open the module the student is working on by default.
    bool isOpen(String id, int index) => _open[id] ?? (c.currentModuleId != null ? c.currentModuleId == id : index == 0);

    final statusLabel = switch (c.status) {
      'DRAFT' => 'Draft',
      'ARCHIVED' => 'Archived',
      _ => member ? 'Active Course' : 'Public Preview',
    };
    final navy = dark ? Dak.heading : Auth.navy;
    final ink = context.ink;
    final body = context.body;
    final grey = dark ? Dak.muted : const Color(0xFF929292);
    final tabLabel = _tab == 'discussions' ? 'Community Discussion' : tabs.firstWhere((t) => t.$1 == _tab).$2;

    Widget pill(String label, String href, {bool filled = false, Color? outline}) => LinkBox(
      href: href,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        decoration: BoxDecoration(
          color: filled ? (dark ? Dak.cta : Hex.black) : null,
          borderRadius: BorderRadius.circular(4),
          border: filled ? null : Border.all(color: outline ?? (dark ? Dak.border : Hex.black)),
        ),
        child: Text(
          label,
          style: TextStyle(fontSize: 14, fontWeight: FontWeight.w500, color: filled ? Colors.white : (outline ?? ink)),
        ),
      ),
    );

    final hero = Container(
      clipBehavior: Clip.antiAlias,
      decoration: cardDecoration(context),
      child: Stack(
        children: [
          if (context.isLg)
            Positioned(
              top: 0,
              bottom: 0,
              right: 0,
              width: context.screenWidth / 3,
              child: DecoratedBox(
                decoration: BoxDecoration(gradient: LinearGradient(colors: [Colors.transparent, Dak.line.withValues(alpha: .5)])),
              ),
            ),
          Padding(
            padding: EdgeInsets.all(context.isSm ? 32 : 20),
            child: Flex(
              direction: context.isLg ? Axis.horizontal : Axis.vertical,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Flexible(
                  fit: FlexFit.loose,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Wrap(
                        spacing: 12,
                        runSpacing: 8,
                        crossAxisAlignment: WrapCrossAlignment.center,
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                            decoration: BoxDecoration(color: Dak.cta.withValues(alpha: .1), borderRadius: BorderRadius.circular(2)),
                            child: Text(
                              statusLabel.toUpperCase(),
                              style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, letterSpacing: .4, color: Dak.cta),
                            ),
                          ),
                          Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              if (c.instructor.verified) ...[
                                AssetIcon('icons/verified-check-small.svg', width: 14.667, height: 14, color: dark ? Colors.white : null),
                                const SizedBox(width: 6),
                              ],
                              Text(c.instructor.name, style: TextStyle(fontSize: 14, color: body)),
                            ],
                          ),
                          if (c.category != null) Text('· ${c.category}', style: TextStyle(fontSize: 14, color: grey)),
                        ],
                      ),
                      const SizedBox(height: 12),
                      Text(
                        c.title,
                        style: TextStyle(
                          fontSize: context.isSm ? 48 : 24,
                          height: context.isSm ? 56 / 48 : null,
                          fontWeight: FontWeight.w700,
                          color: ink,
                        ),
                      ),
                      if (c.description != null) ...[
                        const SizedBox(height: 12),
                        ConstrainedBox(
                          constraints: const BoxConstraints(maxWidth: 600),
                          child: Text(
                            c.description!,
                            style: TextStyle(fontSize: context.isSm ? 18 : 16, color: body),
                          ),
                        ),
                      ],
                      if (c.isInstructor) ...[
                        const SizedBox(height: 20),
                        Wrap(
                          spacing: 12,
                          runSpacing: 12,
                          children: [
                            pill('Edit curriculum', '/classrooms/create/curriculum?id=${c.id}', filled: true),
                            pill('Edit details', '/classrooms/create?id=${c.id}'),
                            if (c.status == 'DRAFT') pill('Review & publish', '/classrooms/create/review?id=${c.id}', outline: Dak.cta),
                          ],
                        ),
                      ],
                    ],
                  ),
                ),
                const SizedBox(width: 24, height: 24),
                if (c.joinCode != null)
                  Container(
                    constraints: const BoxConstraints(minWidth: 200),
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(4),
                      border: Border.all(color: dark ? Dak.border : Hex.text.withValues(alpha: .4)),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'JOIN CODE',
                                  style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: ink),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  formatJoinCode(c.joinCode!),
                                  style: TextStyle(fontSize: 24, fontWeight: FontWeight.w600, letterSpacing: 2.4, color: ink),
                                ),
                              ],
                            ),
                            const SizedBox(width: 16),
                            Tooltip(
                              message: 'Copy join code',
                              child: InkWell(
                                onTap: () => _copyJoinCode(c.joinCode!),
                                child: AssetIcon('icons/copy.svg', width: 17, height: 20, color: dark ? Colors.white : null),
                              ),
                            ),
                          ],
                        ),
                        if (_copied)
                          const Text(
                            'Copied!',
                            style: TextStyle(fontSize: 12, fontWeight: FontWeight.w500, color: Dak.cta),
                          ),
                      ],
                    ),
                  )
                else
                  LinkBox(
                    href: '/classrooms/join',
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                      decoration: BoxDecoration(color: Dak.cta, borderRadius: BorderRadius.circular(4)),
                      child: const Text(
                        'Have a code? Join this class',
                        style: TextStyle(fontSize: 14, fontWeight: FontWeight.w500, color: Colors.white),
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
    );

    final tabStrip = Container(
      decoration: BoxDecoration(
        border: Border(bottom: BorderSide(color: dark ? Dak.border : Dak.line)),
      ),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            for (final (i, (id, label, badge)) in tabs.indexed) ...[
              if (i > 0) const SizedBox(width: 32),
              InkWell(
                onTap: () => setState(() => _tab = id),
                child: Container(
                  padding: const EdgeInsets.only(bottom: 15),
                  decoration: BoxDecoration(
                    border: Border(bottom: BorderSide(color: _tab == id ? (dark ? Dak.cta : Hex.black) : Colors.transparent, width: 2)),
                  ),
                  child: Row(
                    children: [
                      Text(
                        label,
                        style: TextStyle(
                          fontSize: 14,
                          letterSpacing: .28,
                          fontWeight: _tab == id ? FontWeight.w600 : FontWeight.w400,
                          color: _tab == id ? ink : context.mutedText,
                        ),
                      ),
                      if (badge > 0) ...[
                        const SizedBox(width: 8),
                        Container(
                          width: 20,
                          height: 20,
                          alignment: Alignment.center,
                          decoration: BoxDecoration(color: dark ? Dak.cta : Hex.text, shape: BoxShape.circle),
                          child: Text(
                            '$badge',
                            style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w700, color: Color(0xFFF4F4F4)),
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );

    final Widget tabBody = switch (_tab) {
      'canvas' =>
        canvasLessons.isEmpty
            ? Text('No canvases are linked to this course.', style: TextStyle(fontSize: 14, color: body))
            : AutoGrid(
                minItemWidth: 280,
                gap: 24,
                children: [
                  for (final l in canvasLessons)
                    WorkspaceCard(
                      href: member ? '/canvas/${l.lesson.canvas!.id}' : '/classrooms/${c.id}',
                      title: l.lesson.canvas!.title,
                      workspace: 'Lesson: ${l.lesson.title}',
                      editedAgo: 'Module ${l.moduleIndex}',
                      updatedTag: 'Shared',
                      imageSrc: l.lesson.canvas!.thumbnailUrl,
                    ),
                ],
              ),
      'resources' => Container(
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          color: dark ? Dak.surface : Colors.white,
          borderRadius: BorderRadius.circular(4),
          border: Border.all(color: dark ? Dak.border : Hex.text.withValues(alpha: .4)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (resources.isEmpty)
              Text(
                member ? 'No resources attached yet.' : 'Join the classroom to see its resources.',
                style: TextStyle(fontSize: 14, color: body),
              ),
            for (final (i, r) in resources.indexed) ...[
              if (i > 0) const SizedBox(height: 16),
              ResourceRow(lesson: r, onOpen: () => _view(c, r)),
            ],
          ],
        ),
      ),
      'discussions' => member ? Discussions(classroomId: c.id) : const SizedBox.shrink(),
      _ => Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (c.modules.isEmpty) Text("The curriculum hasn't been published yet.", style: TextStyle(fontSize: 14, color: body)),
          for (final (index, m) in c.modules.indexed) ...[
            if (index > 0) const SizedBox(height: 16),
            _ModuleCard(
              module: m,
              index: index,
              expanded: isOpen(m.id, index),
              member: member,
              nextUpId: nextUp?.lesson.id,
              onToggle: () => setState(() => _open[m.id] = !isOpen(m.id, index)),
              onLesson: (l) => member ? _view(c, l) : ref.read(toastProvider.notifier).error('Join the classroom to open lessons'),
            ),
          ],
        ],
      ),
    };

    Widget panel(List<Widget> children) => Container(
      padding: const EdgeInsets.all(24),
      decoration: cardDecoration(context, blur: 4),
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: children),
    );
    final h3 = TextStyle(fontSize: 24, fontWeight: FontWeight.w600, color: ink);

    final side = Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (c.isEnrolled) ...[
          panel([
            Text('Your Progress', style: h3),
            const SizedBox(height: 16),
            Row(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(
                  '${c.progress ?? 0}%',
                  style: TextStyle(fontSize: 32, height: 1, fontWeight: FontWeight.w700, color: ink),
                ),
                const Spacer(),
                Text('${c.completedLessons} of ${c.lessonCount} lessons', style: TextStyle(fontSize: 14, color: context.mutedText)),
              ],
            ),
            const SizedBox(height: 16),
            ProgressBar(
              value: (c.progress ?? 0) / 100,
              height: 8,
              track: dark ? Dak.border : const Color(0xFFF2F2F2),
              fill: dark ? Dak.cta : Hex.black,
            ),
            const SizedBox(height: 16),
            if (nextUp != null) ...[
              Text(
                'NEXT UP',
                style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, letterSpacing: .4, color: context.mutedText),
              ),
              const SizedBox(height: 12),
              InkWell(
                onTap: () => _view(c, nextUp.lesson),
                child: Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Hex.text,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: dark ? Dak.border : Light.border),
                  ),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const AssetIcon('icons/play-circle-white.svg', width: 20, height: 22),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              nextUp.lesson.title,
                              style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w500, letterSpacing: .28, color: Colors.white),
                            ),
                            Text(
                              'Module ${nextUp.moduleIndex} • ${nextUp.lesson.kind.toLowerCase()}',
                              style: const TextStyle(fontSize: 14, color: Light.border),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ] else if (c.lessonCount > 0)
              const Text(
                'Course complete — nice work!',
                style: TextStyle(fontSize: 14, fontWeight: FontWeight.w500, color: Hex.google),
              ),
          ]),
          const SizedBox(height: 24),
        ],
        if (c.isInstructor) ...[
          panel([
            Text('Students (${c.enrolledCount})', style: h3),
            const SizedBox(height: 16),
            if (students?.isEmpty == true) Text('Share the join code to enrol students.', style: TextStyle(fontSize: 14, color: body)),
            ConstrainedBox(
              constraints: const BoxConstraints(maxHeight: 360),
              child: SingleChildScrollView(
                child: Column(
                  children: [
                    for (final (i, s) in (students ?? const <Student>[]).indexed) ...[
                      if (i > 0) const SizedBox(height: 12),
                      Row(
                        children: [
                          Avatar(src: s.avatarUrl, name: s.name, size: 32),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.stretch,
                              children: [
                                Text(
                                  s.name,
                                  overflow: TextOverflow.ellipsis,
                                  style: TextStyle(fontSize: 14, fontWeight: FontWeight.w500, color: ink),
                                ),
                                const SizedBox(height: 4),
                                ProgressBar(value: s.progress / 100, track: dark ? Dak.border : const Color(0xFFF2F2F2)),
                              ],
                            ),
                          ),
                          const SizedBox(width: 12),
                          Text(s.status == 'ACTIVE' ? '${s.progress}%' : 'Left', style: TextStyle(fontSize: 12, color: context.mutedText)),
                        ],
                      ),
                    ],
                  ],
                ),
              ),
            ),
          ]),
          const SizedBox(height: 24),
        ],
        panel([
          Row(
            children: [
              Expanded(child: Text('Resources', style: h3)),
              AssetIcon('icons/folder.svg', width: 21.5, height: 16, color: dark ? Colors.white : null),
            ],
          ),
          const SizedBox(height: 16),
          if (resources.isEmpty) Text('Nothing attached yet.', style: TextStyle(fontSize: 14, color: body)),
          for (final (i, r) in resources.take(4).indexed) ...[
            if (i > 0) const SizedBox(height: 16),
            ResourceRow(
              lesson: r,
              onOpen: () {
                if (member) _view(c, r);
              },
            ),
          ],
        ]),
        const SizedBox(height: 24),
        Wrap(
          spacing: 12,
          children: [
            if (c.isEnrolled) _QuietAction(label: 'Leave classroom', danger: true, onTap: () => _act(c, 'leave')),
            if (c.isInstructor && c.status == 'PUBLISHED') _QuietAction(label: 'Archive', onTap: () => _act(c, 'archive')),
            if (c.isInstructor) _QuietAction(label: 'Delete classroom', danger: true, onTap: () => _act(c, 'delete')),
          ],
        ),
      ],
    );

    final main = Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [tabStrip, const SizedBox(height: 24), tabBody]);
    final showSide = _tab != 'discussions';

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text('Classroom  ›  ${c.title}  ›  $tabLabel', style: TextStyle(fontSize: 14, color: dark ? Dak.body : Auth.navy)),
        const SizedBox(height: 16),
        Align(
          alignment: Alignment.centerLeft,
          child: InkWell(
            onTap: () => context.go(c.isInstructor ? '/classrooms/manage' : '/classrooms'),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Transform.flip(
                  flipX: true,
                  child: AssetIcon(
                    context.pick('icons/arrow-narrow-right.svg', 'icons/arrow-narrow-right-light.svg'),
                    width: 20,
                    height: 20,
                  ),
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
        if (showSide) ...[const SizedBox(height: 16), hero],
        const SizedBox(height: 16),
        if (showSide && context.screenWidth >= 1280)
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(child: main),
              const SizedBox(width: 32),
              SizedBox(width: 380, child: side),
            ],
          )
        else ...[
          main,
          if (showSide) ...[const SizedBox(height: 32), side],
        ],
      ],
    );
  }
}

class _QuietAction extends StatefulWidget {
  const _QuietAction({required this.label, required this.onTap, this.danger = false});

  final String label;
  final VoidCallback onTap;
  final bool danger;

  @override
  State<_QuietAction> createState() => _QuietActionState();
}

class _QuietActionState extends State<_QuietAction> {
  bool _hover = false;

  @override
  Widget build(BuildContext context) {
    final hoverColor = widget.danger ? Hex.error : context.ink;
    return MouseRegion(
      cursor: SystemMouseCursors.click,
      onEnter: (_) => setState(() => _hover = true),
      onExit: (_) => setState(() => _hover = false),
      child: GestureDetector(
        onTap: widget.onTap,
        child: Text(widget.label, style: TextStyle(fontSize: 14, color: _hover ? hoverColor : const Color(0xFF929292))),
      ),
    );
  }
}

class _ModuleCard extends StatelessWidget {
  const _ModuleCard({
    required this.module,
    required this.index,
    required this.expanded,
    required this.member,
    required this.nextUpId,
    required this.onToggle,
    required this.onLesson,
  });

  final ClassroomModule module;
  final int index;
  final bool expanded;
  final bool member;
  final String? nextUpId;
  final VoidCallback onToggle;
  final ValueChanged<Lesson> onLesson;

  @override
  Widget build(BuildContext context) {
    final dark = context.isDark;
    final m = module;
    final done = m.lessons.isNotEmpty && m.lessons.every((l) => l.completed);
    final border = dark ? Dak.border : Light.border;
    final ink = context.ink;

    return Container(
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        color: dark ? Dak.surface : const Color(0xFFF8F9FF),
        borderRadius: BorderRadius.circular(4),
        border: Border.all(color: border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          InkWell(
            onTap: onToggle,
            child: Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: expanded ? const Color(0xFF45464D) : (dark ? Dak.surface : Colors.white),
                border: expanded ? Border(bottom: BorderSide(color: border)) : null,
              ),
              child: Row(
                children: [
                  Container(
                    width: 32,
                    height: 32,
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: expanded ? Dak.cta : (dark ? Dak.bg : const Color(0xFFF4F4F4)),
                      border: expanded ? null : Border.all(color: border),
                    ),
                    child: Text(
                      done ? '✓' : '${index + 1}',
                      style: TextStyle(fontSize: 14, fontWeight: FontWeight.w500, color: expanded ? Colors.white : ink),
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Text(
                      m.title,
                      style: TextStyle(fontSize: context.isSm ? 24 : 20, fontWeight: FontWeight.w600, color: expanded ? Colors.white : ink),
                    ),
                  ),
                  Transform.rotate(
                    angle: expanded ? 3.14159 : 0,
                    child: AssetIcon('icons/chevron-down-small.svg', width: 12, height: 7.4, color: expanded || dark ? Colors.white : null),
                  ),
                ],
              ),
            ),
          ),
          if (expanded)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
              decoration: BoxDecoration(
                color: dark ? Dak.surface : Colors.white,
                boxShadow: [BoxShadow(color: Hex.text.withValues(alpha: .2), offset: const Offset(0, 4), blurRadius: 4)],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  if (m.description != null)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 8),
                      child: Text(m.description!, style: TextStyle(fontSize: 14, color: context.body)),
                    ),
                  if (m.lessons.isEmpty)
                    const Text('No lessons in this module yet.', style: TextStyle(fontSize: 14, color: Color(0xFF929292))),
                  for (final (i, lesson) in m.lessons.indexed) ...[
                    if (i > 0) const SizedBox(height: 8),
                    _LessonButton(lesson: lesson, resume: nextUpId == lesson.id, member: member, onTap: () => onLesson(lesson)),
                  ],
                ],
              ),
            ),
        ],
      ),
    );
  }
}

class _LessonButton extends StatefulWidget {
  const _LessonButton({required this.lesson, required this.resume, required this.member, required this.onTap});

  final Lesson lesson;
  final bool resume;
  final bool member;
  final VoidCallback onTap;

  @override
  State<_LessonButton> createState() => _LessonButtonState();
}

class _LessonButtonState extends State<_LessonButton> {
  bool _hover = false;

  @override
  Widget build(BuildContext context) {
    final dark = context.isDark;
    final l = widget.lesson;
    final resume = widget.resume;
    final textColor = resume ? Colors.white : context.ink;

    return MouseRegion(
      cursor: SystemMouseCursors.click,
      onEnter: (_) => setState(() => _hover = true),
      onExit: (_) => setState(() => _hover = false),
      child: GestureDetector(
        onTap: widget.onTap,
        child: Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: resume ? Hex.text : (_hover ? (dark ? Dak.bg : const Color(0xFFF4F4F4)) : null),
            borderRadius: BorderRadius.circular(4),
            border: resume ? const Border(left: BorderSide(color: Auth.navy, width: 2)) : null,
          ),
          child: Row(
            children: [
              Container(
                width: 40,
                height: 40,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: resume ? Colors.white.withValues(alpha: .2) : Hex.black.withValues(alpha: .2),
                  borderRadius: BorderRadius.circular(2),
                ),
                child: AssetIcon(lessonIcon[l.kind]!, width: 20, height: 20, color: resume || dark ? Colors.white : null),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      l.title,
                      style: TextStyle(fontSize: 14, fontWeight: FontWeight.w500, letterSpacing: .28, color: textColor),
                    ),
                    Text(metaOf(l), style: TextStyle(fontSize: 14, color: resume ? Colors.white : context.body)),
                  ],
                ),
              ),
              if (l.completed)
                AssetIcon('icons/checkmark-circle.svg', width: 16.667, height: 16.667, color: dark ? Colors.white : null)
              else if (resume)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(4),
                    border: Border.all(color: Colors.white),
                  ),
                  child: const Text(
                    'Resume',
                    style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: Colors.white),
                  ),
                )
              else if (!widget.member)
                AssetIcon('icons/lock.svg', width: 10.667, height: 14, color: dark ? Colors.white : null),
            ],
          ),
        ),
      ),
    );
  }
}
