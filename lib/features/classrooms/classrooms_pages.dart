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
import '../../ui/route_modal.dart';
import '../../ui/states.dart';
import '../../ui/toast.dart';
import '../shared/cards.dart';

/// Small rectangular buttons in the classroom headers ("Teaching", "Join Classroom").
class _HeaderLink extends StatelessWidget {
  const _HeaderLink({required this.label, required this.href, this.primary = false, this.icon});

  final String label;
  final String href;
  final bool primary;
  final Widget? icon;

  @override
  Widget build(BuildContext context) {
    final dark = context.isDark;
    return Material(
      color: primary ? Dak.cta : Colors.transparent,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(4),
        side: primary ? BorderSide.none : BorderSide(color: dark ? Dak.border : Hex.text),
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(4),
        onTap: () => context.go(href),
        child: Container(
          padding: const EdgeInsets.fromLTRB(24, 13, 24, 12),
          decoration: primary
              ? BoxDecoration(
                  border: Border(top: BorderSide(color: Colors.white.withValues(alpha: .2))),
                )
              : null,
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (icon != null) ...[icon!, const SizedBox(width: 8)],
              Text(
                label,
                style: TextStyle(
                  fontSize: 14,
                  height: 1,
                  fontWeight: FontWeight.w500,
                  letterSpacing: .28,
                  color: primary ? Colors.white : context.ink,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

Widget _header(BuildContext context, List<Widget> actions) {
  final title = Text('Classrooms', style: context.pageTitle);
  return context.isSm
      ? Row(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Expanded(child: title),
            Wrap(spacing: 12, runSpacing: 12, children: actions),
          ],
        )
      : Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            title,
            const SizedBox(height: 16),
            Wrap(spacing: 12, runSpacing: 12, children: actions),
          ],
        );
}

class ClassroomsPage extends ConsumerStatefulWidget {
  const ClassroomsPage({super.key});

  @override
  ConsumerState<ClassroomsPage> createState() => _ClassroomsPageState();
}

class _ClassroomsPageState extends ConsumerState<ClassroomsPage> {
  String _tab = 'enrolled';
  int _page = 1;

  @override
  Widget build(BuildContext context) {
    final dark = context.isDark;
    final data = pagedOf(ref, withQuery('/classrooms', {'scope': _tab, 'page': _page, 'limit': 12}), ClassroomCard.fromJson);
    final active = _tab == 'active';

    Widget tab(String id, String label, double width) {
      final on = _tab == id;
      return InkWell(
        onTap: () => setState(() {
          _tab = id;
          _page = 1;
        }),
        child: SizedBox(
          width: context.isSm ? width : null,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                label,
                softWrap: false,
                style: TextStyle(
                  fontSize: 18,
                  height: 1,
                  letterSpacing: .28,
                  fontWeight: on ? FontWeight.w600 : FontWeight.w500,
                  color: on ? context.ink : context.mutedText,
                ),
              ),
              const SizedBox(height: 8),
              Container(
                height: 4,
                width: context.isSm ? width : 120,
                decoration: BoxDecoration(
                  color: on ? (dark ? Dak.cta : Hex.black) : Colors.transparent,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ],
          ),
        ),
      );
    }

    final Widget body;
    if (data == null) {
      body = const LoadingGrid(minWidth: 300);
    } else if (data.items.isEmpty) {
      body = _tab == 'enrolled'
          ? const EmptyState(
              title: "You haven't joined a classroom yet",
              body: 'Ask your instructor for a 6-character code, or browse public classrooms.',
              actionLabel: 'Browse classrooms',
              actionHref: '/explore?tab=classrooms',
            )
          : const EmptyState(title: 'Nothing in progress', body: "Classes you've started but not finished appear here.");
    } else {
      body = AutoGrid(
        minItemWidth: 300,
        gap: 20,
        rowGap: 16,
        fill: true,
        children: [
          for (final c in data.items)
            ClassCard(
              href: '/classrooms/${c.id}',
              title: c.title,
              subtitle: c.instructor.name,
              modules: plural(c.moduleCount, 'module'),
              badge: active ? '${c.completedLessons}/${c.lessonCount} lessons' : null,
              progress: active ? (c.progress ?? 0) : null,
              imageSrc: c.imageUrl,
            ),
        ],
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _header(context, [
          const _HeaderLink(label: 'Teaching', href: '/classrooms/manage'),
          const _HeaderLink(
            label: 'Join Classroom',
            href: '/classrooms/join',
            primary: true,
            icon: AssetIcon('icons/plus.svg', width: 14, height: 14),
          ),
        ]),
        const SizedBox(height: 32),
        Container(
          decoration: BoxDecoration(
            border: Border(bottom: BorderSide(color: dark ? Dak.border : Dak.line)),
          ),
          child: SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(children: [tab('enrolled', 'Classrooms', 160), const SizedBox(width: 24), tab('active', 'Active Classroom', 161)]),
          ),
        ),
        const SizedBox(height: 32),
        body,
        if (data != null) ...[
          const SizedBox(height: 32),
          Pager(page: data.page, pages: data.pages, onPage: (p) => setState(() => _page = p)),
        ],
      ],
    );
  }
}

class ManageClassroomsPage extends ConsumerWidget {
  const ManageClassroomsPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final data = pagedOf(ref, '/classrooms?scope=teaching&limit=100', ClassroomCard.fromJson);

    final Widget body;
    if (data == null) {
      body = const LoadingGrid(minWidth: 300);
    } else if (data.items.isEmpty) {
      body = const EmptyState(
        title: "You aren't teaching any classrooms yet",
        body: 'Create a course, build its curriculum and share the join code with your students.',
        actionLabel: '+ Create Classroom',
        actionHref: '/classrooms/create',
      );
    } else {
      body = AutoGrid(
        minItemWidth: 300,
        gap: 20,
        rowGap: 16,
        fill: true,
        children: [
          for (final c in data.items)
            ClassCard(
              href: c.status == 'DRAFT' ? '/classrooms/create/curriculum?id=${c.id}' : '/classrooms/${c.id}',
              title: c.title,
              subtitle: c.category ?? c.instructor.name,
              modules: plural(c.moduleCount, 'module'),
              tag: c.status == 'DRAFT' ? 'Draft' : '${c.enrolledCount} Enrolled',
              imageSrc: c.imageUrl,
            ),
        ],
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _header(context, [const _HeaderLink(label: '+ Create Classroom', href: '/classrooms/create', primary: true)]),
        const SizedBox(height: 32),
        body,
      ],
    );
  }
}

class JoinClassroomPage extends ConsumerStatefulWidget {
  const JoinClassroomPage({super.key});

  @override
  ConsumerState<JoinClassroomPage> createState() => _JoinClassroomPageState();
}

class _JoinClassroomPageState extends ConsumerState<JoinClassroomPage> {
  static const _length = 6;
  final _controllers = List.generate(_length, (_) => TextEditingController());
  final _nodes = List.generate(_length, (_) => FocusNode());
  bool _joining = false;

  @override
  void initState() {
    super.initState();
    for (var i = 0; i < _length; i++) {
      _nodes[i].onKeyEvent = (_, e) {
        if (e is KeyDownEvent && e.logicalKey == LogicalKeyboardKey.backspace && _controllers[i].text.isEmpty && i > 0) {
          _nodes[i - 1].requestFocus();
          return KeyEventResult.handled;
        }
        return KeyEventResult.ignored;
      };
    }
  }

  @override
  void dispose() {
    for (final c in _controllers) {
      c.dispose();
    }
    for (final n in _nodes) {
      n.dispose();
    }
    super.dispose();
  }

  String get _code => _controllers.map((c) => c.text).join();
  bool get _complete => _controllers.every((c) => c.text.isNotEmpty);

  void _onChanged(int i, String value) {
    final chars = value.replaceAll(RegExp(r'[^a-zA-Z0-9]'), '').toUpperCase();
    // A pasted code spreads across the boxes.
    if (chars.length > 1) {
      for (var j = 0; j < _length; j++) {
        _controllers[j].text = j < chars.length ? chars[j] : '';
      }
      _nodes[chars.length.clamp(0, _length - 1)].requestFocus();
    } else {
      _controllers[i].text = chars;
      if (chars.isNotEmpty && i < _length - 1) _nodes[i + 1].requestFocus();
    }
    setState(() {});
  }

  Future<void> _join(ClassroomCard preview) async {
    setState(() => _joining = true);
    final toast = ref.read(toastProvider.notifier);
    try {
      final res = await ref.read(apiProvider).post<Map<String, dynamic>>('/classrooms/join', {'code': _code});
      invalidateQueries(ref);
      toast.show('You joined ${preview.title}');
      if (mounted) context.go('/classrooms/${res['classroomId']}');
    } catch (e) {
      toast.error(errorMessage(e));
      if (mounted) setState(() => _joining = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final dark = context.isDark;
    final lookup = _complete ? ref.watch(query('/classrooms/code/$_code')) : null;
    final preview = lookup?.value == null ? null : ClassroomCard.fromJson(lookup!.value as Map<String, dynamic>);

    Widget box(int i) {
      final filled = _controllers[i].text.isNotEmpty;
      return SizedBox(
        width: 48,
        height: 56,
        child: TextField(
          controller: _controllers[i],
          focusNode: _nodes[i],
          textAlign: TextAlign.center,
          textCapitalization: TextCapitalization.characters,
          onChanged: (v) => _onChanged(i, v),
          style: TextStyle(
            fontSize: 32,
            fontWeight: FontWeight.w600,
            letterSpacing: -.32,
            color: dark ? Dak.heading : (filled ? Hex.black : Hex.text),
          ),
          decoration: InputDecoration(
            filled: true,
            fillColor: dark ? Dak.bg : Colors.white,
            contentPadding: EdgeInsets.zero,
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(4),
              borderSide: BorderSide(color: filled ? Dak.cta : (dark ? Dak.border : Hex.text)),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(4),
              borderSide: const BorderSide(color: Dak.cta),
            ),
          ),
        ),
      );
    }

    final modal = Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Container(
          color: Hex.text,
          padding: const EdgeInsets.all(24),
          child: Row(
            children: [
              const Expanded(
                child: Text(
                  'Join a New Classroom',
                  style: TextStyle(fontSize: 24, fontWeight: FontWeight.w500, color: Colors.white),
                ),
              ),
              Tooltip(
                message: 'Close',
                child: InkWell(
                  onTap: () => context.go('/classrooms'),
                  child: const AssetIcon('icons/close-x-white.svg', width: 14, height: 14),
                ),
              ),
            ],
          ),
        ),
        Container(
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: dark ? const [Dak.surface, Dak.surface] : const [Colors.white, Color(0xFFF3E8FF)],
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                'Enter 6-digit classroom code',
                style: TextStyle(fontSize: 14, letterSpacing: .28, color: dark ? Dak.heading : Hex.text),
              ),
              const SizedBox(height: 16),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  for (var i = 0; i < _length; i++)
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        box(i),
                        if (i == 2) ...[const SizedBox(width: 8), const Text('-', style: TextStyle(fontSize: 16, color: Dak.cta))],
                      ],
                    ),
                ],
              ),
              const SizedBox(height: 16),
              Text('Ask your instructor for the unique joining code.', style: TextStyle(fontSize: 14, color: context.body)),
              if (_complete && lookup?.hasError == true) ...[
                const SizedBox(height: 32),
                Text(
                  errorMessage(lookup!.error!),
                  style: TextStyle(fontSize: 14, fontWeight: FontWeight.w500, color: dark ? Hex.errorDark : Hex.error),
                ),
              ],
              if (preview != null) ...[
                const SizedBox(height: 32),
                Container(
                  clipBehavior: Clip.antiAlias,
                  padding: const EdgeInsets.all(17),
                  decoration: BoxDecoration(
                    color: Hex.black,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: const Color(0xFFCACACA)),
                  ),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Container(
                        width: 48,
                        height: 48,
                        alignment: Alignment.center,
                        decoration: BoxDecoration(color: const Color(0x4DE6E6E6), borderRadius: BorderRadius.circular(4)),
                        child: const AssetIcon('icons/compass.svg', width: 11, height: 18),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                              decoration: BoxDecoration(color: Dak.cta.withValues(alpha: .3), borderRadius: BorderRadius.circular(12)),
                              child: Text(
                                preview.instructor.verified ? 'Verified Class' : (preview.category ?? 'Classroom'),
                                style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: Dak.cta),
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              preview.title,
                              style: const TextStyle(fontSize: 24, fontWeight: FontWeight.w500, color: Colors.white),
                            ),
                            const SizedBox(height: 8),
                            Row(
                              children: [
                                const AssetIcon('icons/instructor.svg', width: 9, height: 9),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: Text(
                                    'Instructor: ${preview.instructor.name} · ${preview.moduleCount} modules · ${preview.enrolledCount} enrolled',
                                    style: const TextStyle(fontSize: 14, color: Colors.white),
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ],
          ),
        ),
        Padding(
          padding: const EdgeInsets.all(24),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              InkWell(
                onTap: () => context.go('/classrooms'),
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 10),
                  child: Text(
                    'Cancel',
                    style: TextStyle(fontSize: 14, fontWeight: FontWeight.w500, color: context.ink),
                  ),
                ),
              ),
              const SizedBox(width: 16),
              Opacity(
                opacity: preview == null || _joining ? .4 : 1,
                child: Material(
                  color: Dak.cta,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(4),
                    side: BorderSide(color: Colors.white.withValues(alpha: .2)),
                  ),
                  child: InkWell(
                    borderRadius: BorderRadius.circular(4),
                    onTap: preview == null || _joining ? null : () => _join(preview),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 10),
                      child: Text(
                        _joining ? 'Joining…' : 'Join Classroom',
                        style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w500, color: Colors.white),
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

    return RouteModal(background: const ClassroomsPage(), maxWidth: 531, child: modal);
  }
}
