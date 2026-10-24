import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/api/api_error.dart';
import '../../core/api/upload.dart';
import '../../core/auth/auth.dart';
import '../../core/format.dart';
import '../../core/query.dart';
import '../../models/classroom.dart';
import '../../theme/tokens.dart';
import '../../ui/asset_icon.dart';
import '../../ui/drop_zone.dart';
import '../../ui/layout.dart';
import '../../ui/link_box.dart';
import '../../ui/page_bits.dart';
import '../../ui/states.dart';
import '../../ui/text_field.dart';
import '../../ui/toast.dart';
import '../../ui/user_image.dart';
import 'lesson_form.dart';
import 'lessons.dart';

const _steps = ['Identity', 'Curriculum', 'Publish'];
const _skillLevels = [('BEGINNER', 'Beginner'), ('INTERMEDIATE', 'Intermediate'), ('ADVANCED', 'Advanced')];
const _categories = ['Structural Engineering', 'Electrical Systems', 'Mechanical Design', 'Tiling & Flooring', 'Architecture', 'HVAC'];
const _audience = {'BEGINNER': 'Apprentice / New', 'INTERMEDIATE': 'Practising Trade', 'ADVANCED': 'Senior / Grad'};

const _startOver = EmptyState(title: 'Start with the course identity', actionLabel: 'Create a classroom', actionHref: '/classrooms/create');

/// Page frame shared by the creation steps: width cap, back link, title and subtitle.
class _StepPage extends StatelessWidget {
  const _StepPage({required this.back, required this.title, required this.subtitle, required this.children, this.bold = false});

  final String back;
  final String title;
  final String subtitle;
  final List<Widget> children;
  final bool bold;

  @override
  Widget build(BuildContext context) {
    final dark = context.isDark;
    return Align(
      alignment: Alignment.topLeft,
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 929),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            BackLink(href: back),
            const SizedBox(height: 24),
            Text(
              title,
              style: TextStyle(
                fontSize: context.isSm ? 32 : 24,
                fontWeight: bold ? FontWeight.w700 : FontWeight.w600,
                letterSpacing: -.32,
                color: dark ? Dak.heading : Auth.navy,
              ),
            ),
            const SizedBox(height: 8),
            Text(subtitle, style: TextStyle(fontSize: 16, color: dark ? Dak.body : Auth.navy)),
            for (final c in children) ...[const SizedBox(height: 24), c],
          ],
        ),
      ),
    );
  }
}

BoxDecoration _panel(BuildContext context, {Color? lightBorder}) => BoxDecoration(
  color: context.pick(Colors.white, Dak.surface),
  borderRadius: BorderRadius.circular(8),
  border: Border.all(color: context.pick(lightBorder ?? Light.border, Dak.heading.withValues(alpha: .15))),
);

Widget _panelTitle(BuildContext context, String title, String subtitle) => Column(
  crossAxisAlignment: CrossAxisAlignment.start,
  children: [
    Text(
      title,
      style: TextStyle(fontSize: 24, fontWeight: FontWeight.w600, color: context.pick(Auth.navy, Dak.heading)),
    ),
    const SizedBox(height: 4),
    Text(subtitle, style: TextStyle(fontSize: 14, color: context.pick(Auth.navy, Dak.body))),
  ],
);

/// Bordered rectangular button used for Cancel / Next in the step footers.
class _FooterButton extends StatelessWidget {
  const _FooterButton({required this.label, required this.onTap, this.primary = false, this.radius = 4});

  final String label;
  final VoidCallback? onTap;
  final bool primary;
  final double radius;

  @override
  Widget build(BuildContext context) {
    final dark = context.isDark;
    return Opacity(
      opacity: onTap == null && primary ? .6 : 1,
      child: DecoratedBox(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(radius),
          boxShadow: primary ? [BoxShadow(color: Dak.cta.withValues(alpha: .4), offset: const Offset(0, 8), blurRadius: 16)] : null,
        ),
        child: Material(
          color: primary ? Dak.cta : Colors.transparent,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(radius),
            side: primary ? BorderSide.none : BorderSide(color: dark ? Dak.body : Auth.navy),
          ),
          child: InkWell(
            borderRadius: BorderRadius.circular(radius),
            onTap: onTap,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 16),
              child: Text(
                label,
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.w500, color: primary ? Colors.white : (dark ? Dak.body : Auth.navy)),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

Widget _footer(BuildContext context, List<Widget> children) => Container(
  padding: const EdgeInsets.only(top: 24),
  decoration: BoxDecoration(
    border: Border(top: BorderSide(color: context.pick(Light.border, Hex.text.withValues(alpha: .6)))),
  ),
  child: Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: children),
);

/// Step 1: course identity. With `?id=` it edits an existing classroom.
class CreateClassroomPage extends ConsumerWidget {
  const CreateClassroomPage({super.key, this.id});

  final String? id;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (id == null) return const _IdentityForm(existing: null);
    // Editing waits for the classroom so the form starts with its values.
    final existing = oneOf(ref, '/classrooms/$id', ClassroomDetail.fromJson);
    if (existing == null) return const SizedBox.shrink();
    return _IdentityForm(key: ValueKey(existing.id), existing: existing);
  }
}

class _IdentityForm extends ConsumerStatefulWidget {
  const _IdentityForm({super.key, required this.existing});

  final ClassroomDetail? existing;

  @override
  ConsumerState<_IdentityForm> createState() => _IdentityFormState();
}

class _IdentityFormState extends ConsumerState<_IdentityForm> {
  late final _title = TextEditingController(text: widget.existing?.title ?? '');
  late final _description = TextEditingController(text: widget.existing?.description ?? '');
  late String? _category = widget.existing?.category;
  late String _skill = widget.existing?.skillLevel ?? 'INTERMEDIATE';
  late String? _imageUrl = widget.existing?.imageUrl;
  String? _error;
  bool _saving = false;
  bool _uploading = false;

  @override
  void dispose() {
    _title.dispose();
    _description.dispose();
    super.dispose();
  }

  Future<void> _pick([PickedFile? dropped]) async {
    final file = dropped ?? await pickFile(UploadKind.image);
    if (file == null) return;
    setState(() => _uploading = true);
    try {
      final url = await uploadFile(ref.read(apiProvider), file);
      setState(() => _imageUrl = url);
    } catch (e) {
      setState(() => _error = errorMessage(e));
    } finally {
      if (mounted) setState(() => _uploading = false);
    }
  }

  Future<void> _next() async {
    if (_title.text.trim().isEmpty || _category == null || _description.text.trim().isEmpty) {
      return setState(() => _error = 'Fill in the course title, trade category and description.');
    }
    setState(() {
      _error = null;
      _saving = true;
    });
    final api = ref.read(apiProvider);
    final body = {
      'title': _title.text.trim(),
      'category': _category,
      'skillLevel': _skill,
      'description': _description.text.trim(),
      'imageUrl': _imageUrl,
    };
    try {
      final existing = widget.existing;
      final json = existing != null
          ? await api.patch<Map<String, dynamic>>('/classrooms/${existing.id}', body)
          : await api.post<Map<String, dynamic>>('/classrooms', body);
      invalidateQueries(ref);
      if (mounted) context.go('/classrooms/create/curriculum?id=${json['id']}');
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
    final navy = dark ? Dak.heading : Auth.navy;
    final label = TextStyle(fontSize: 14, fontWeight: FontWeight.w500, color: dark ? Dak.body : Auth.navy);
    final grey = dark ? Dak.muted : const Color(0xFF929292);
    final inputBorder = dark ? Dak.heading.withValues(alpha: .15) : Light.border;

    BoxDecoration box({bool darkFill = false}) => BoxDecoration(
      color: dark ? (darkFill ? Dak.border : Colors.transparent) : const Color(0xFFF8F9FF),
      borderRadius: BorderRadius.circular(8),
      border: Border.all(color: darkFill && dark ? Dak.border : inputBorder),
    );

    final primary = Container(
      padding: const EdgeInsets.all(24),
      decoration: _panel(context),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _panelTitle(context, 'Primary Definition', 'The public-facing name and trade categorization.'),
          const SizedBox(height: 16),
          Text('Course Title *', style: label),
          const SizedBox(height: 8),
          Container(
            height: 56,
            padding: const EdgeInsets.symmetric(horizontal: 16),
            alignment: Alignment.centerLeft,
            decoration: box(),
            child: TextField(
              controller: _title,
              style: TextStyle(fontSize: 16, color: navy),
              decoration: InputDecoration.collapsed(
                hintText: 'e.g., Advanced Commercial Wiring Diagnostics',
                hintStyle: TextStyle(fontSize: 16, color: grey),
              ),
            ),
          ),
          const SizedBox(height: 16),
          Text('Trade Category *', style: label),
          const SizedBox(height: 8),
          Container(
            height: 56,
            padding: const EdgeInsets.symmetric(horizontal: 16),
            decoration: box(),
            child: DropdownButtonHideUnderline(
              child: DropdownButton<String>(
                value: _category,
                isExpanded: true,
                hint: Text('Select primary discipline...', style: TextStyle(fontSize: 16, color: grey)),
                icon: AssetIcon('icons/dropdown-arrow.svg', width: 20, height: 20, color: dark ? Colors.white : null),
                dropdownColor: dark ? Dak.surface : Colors.white,
                style: TextStyle(fontSize: 16, color: navy),
                items: [for (final c in _categories) DropdownMenuItem(value: c, child: Text(c))],
                onChanged: (v) => setState(() => _category = v),
              ),
            ),
          ),
        ],
      ),
    );

    final parameters = Container(
      padding: const EdgeInsets.all(24),
      decoration: _panel(context),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _panelTitle(context, 'Parameters', 'Difficulty and Levels'),
          const SizedBox(height: 16),
          Text('Skill Level', style: label),
          for (final (value, text) in _skillLevels) ...[
            const SizedBox(height: 12),
            Material(
              color: _skill == value ? Dak.cta : Colors.transparent,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(6),
                side: _skill == value ? BorderSide.none : BorderSide(color: dark ? Dak.heading.withValues(alpha: .3) : Light.border),
              ),
              child: InkWell(
                borderRadius: BorderRadius.circular(6),
                onTap: () => setState(() => _skill = value),
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  child: Text(
                    text,
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w500,
                      color: _skill == value ? Colors.white : (dark ? Dak.body : Auth.navy),
                    ),
                  ),
                ),
              ),
            ),
          ],
        ],
      ),
    );

    return _StepPage(
      back: '/classrooms/manage',
      title: 'Course Identity & Structure',
      subtitle: 'Define the foundational details of your new training module.',
      children: [
        const StepTrack(steps: _steps, current: 0),
        DropZone(
          onTap: _pick,
          onFile: _pick,
          decoration: BoxDecoration(
            color: dark ? Dak.surface : const Color(0xFFDCDCDC),
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: dark ? Dak.border : Light.border, width: 2),
          ),
          child: SizedBox(
            height: 130,
            child: Stack(
              fit: StackFit.expand,
              children: [
                if (_imageUrl != null) UserImage(src: _imageUrl, opacity: .5),
                Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    AssetIcon('icons/new-canvas.svg', width: 24, height: 24, color: dark ? Colors.white : null),
                    const SizedBox(height: 4),
                    Text.rich(
                      TextSpan(
                        style: TextStyle(fontSize: 14, color: navy),
                        children: [
                          TextSpan(
                            text: _uploading ? 'Uploading…' : (_imageUrl != null ? 'Change image' : 'Upload image'),
                            style: const TextStyle(fontWeight: FontWeight.w600),
                          ),
                          TextSpan(
                            text: ' or drag and drop',
                            style: TextStyle(color: grey),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text('PNG, JPG up to 10MB', style: TextStyle(fontSize: 12, color: grey)),
                  ],
                ),
              ],
            ),
          ),
        ),
        if (context.isSm)
          IntrinsicHeight(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Expanded(flex: 2, child: primary),
                const SizedBox(width: 24),
                Expanded(child: parameters),
              ],
            ),
          )
        else ...[
          primary,
          const SizedBox(height: 24),
          parameters,
        ],
        Container(
          padding: const EdgeInsets.all(24),
          decoration: _panel(context),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _panelTitle(context, 'Context & Narrative', 'Provide detailed context about the course material and your expertise.'),
              const SizedBox(height: 16),
              Text('Course Description *', style: label),
              const SizedBox(height: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                decoration: box(darkFill: true),
                child: TextField(
                  controller: _description,
                  minLines: 4,
                  maxLines: 4,
                  style: TextStyle(fontSize: 16, color: navy),
                  decoration: InputDecoration.collapsed(
                    hintText: 'Detail the learning objectives, practical applications, and core syllabus components...',
                    hintStyle: TextStyle(fontSize: 16, color: grey),
                  ),
                ),
              ),
            ],
          ),
        ),
        if (_error != null) ErrorText(_error!),
        _footer(context, [
          _FooterButton(label: 'Cancel', onTap: () => context.go('/classrooms/manage')),
          _FooterButton(label: _saving ? 'Saving…' : 'Next: Build Curriculum', primary: true, onTap: _saving ? null : _next),
        ]),
      ],
    );
  }
}

/// Step 2: modules and lessons.
class CurriculumBuilderPage extends ConsumerStatefulWidget {
  const CurriculumBuilderPage({super.key, this.id});

  final String? id;

  @override
  ConsumerState<CurriculumBuilderPage> createState() => _CurriculumBuilderPageState();
}

class _CurriculumBuilderPageState extends ConsumerState<CurriculumBuilderPage> {
  final _open = <String, bool>{};
  String? _adding;

  /// Every curriculum endpoint answers with the updated classroom; refresh from the server.
  Future<void> _run(Future<Object?> Function() action, [String? done]) async {
    final toast = ref.read(toastProvider.notifier);
    try {
      await action();
      invalidateQueries(ref);
      if (done != null) toast.show(done);
    } catch (e) {
      toast.error(errorMessage(e));
      rethrow;
    }
  }

  Future<void> _rename(ClassroomModule m) async {
    final title = (await promptText(context, 'Module title', initial: m.title))?.trim();
    if (title == null || title.isEmpty || title == m.title) return;
    await _run(() => ref.read(apiProvider).patch<dynamic>('/modules/${m.id}', {'title': title})).catchError((_) {});
  }

  Future<void> _move(ClassroomModule m, int by) =>
      _run(() => ref.read(apiProvider).patch<dynamic>('/modules/${m.id}', {'position': m.position + by})).catchError((_) {});

  Future<void> _delete(ClassroomModule m) async {
    if (!await confirmAction(context, 'Delete "${m.title}" and its ${m.lessons.length} lessons?')) return;
    await _run(() => ref.read(apiProvider).delete<dynamic>('/modules/${m.id}'), 'Module deleted').catchError((_) {});
  }

  @override
  Widget build(BuildContext context) {
    final id = widget.id;
    if (id == null) return _startOver;
    final result = ref.watch(query('/classrooms/$id'));
    if (result.hasError) return ErrorState(error: result.error!);
    if (result.value == null) return const SizedBox.shrink();
    final classroom = ClassroomDetail.fromJson(result.value as Map<String, dynamic>);

    final dark = context.isDark;
    final navy = dark ? Dak.heading : Auth.navy;
    final api = ref.read(apiProvider);
    bool isOpen(ClassroomModule m) => _open[m.id] ?? true;

    Widget headerButton(String label, VoidCallback? onTap, {Color? color}) => InkWell(
      onTap: onTap,
      child: Opacity(
        opacity: onTap == null ? .3 : 1,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
          child: Text(label, style: TextStyle(fontSize: 14, color: color ?? navy)),
        ),
      ),
    );

    return _StepPage(
      back: '/classrooms/create?id=$id',
      title: 'Curriculum Builder',
      subtitle:
          'Arrange your syllabus into modules and lessons. Link Engineering Canvases to interactive lessons to provide students with hands-on drafting tools.',
      children: [
        const StepTrack(steps: _steps, current: 1),
        if (classroom.modules.isEmpty)
          Text('No modules yet — add the first one below.', style: TextStyle(fontSize: 14, color: dark ? Dak.body : Auth.navy)),
        for (final (index, m) in classroom.modules.indexed)
          Container(
            clipBehavior: Clip.antiAlias,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: dark ? Dak.heading.withValues(alpha: .15) : Light.border),
              boxShadow: const [BoxShadow(color: Color(0x0D000000), offset: Offset(0, 1), blurRadius: 2)],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: dark ? Dak.border : const Color(0xFFF8F9FF),
                    border: Border(bottom: BorderSide(color: dark ? Hex.text.withValues(alpha: .6) : Light.border.withValues(alpha: .4))),
                  ),
                  child: Row(
                    children: [
                      Expanded(
                        child: InkWell(
                          onTap: () => setState(() => _open[m.id] = !isOpen(m)),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'MODULE ${m.position}',
                                style: TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w600,
                                  letterSpacing: .6,
                                  color: dark ? Dak.body : Auth.navy,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                m.title,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(fontSize: context.isSm ? 24 : 20, fontWeight: FontWeight.w600, color: navy),
                              ),
                            ],
                          ),
                        ),
                      ),
                      Tooltip(message: 'Move up', child: headerButton('↑', index == 0 ? null : () => _move(m, -1))),
                      Tooltip(
                        message: 'Move down',
                        child: headerButton('↓', index == classroom.modules.length - 1 ? null : () => _move(m, 1)),
                      ),
                      headerButton('Rename', () => _rename(m)),
                      headerButton('Delete', () => _delete(m), color: Hex.error),
                      Tooltip(
                        message: isOpen(m) ? 'Collapse' : 'Expand',
                        child: InkWell(
                          onTap: () => setState(() => _open[m.id] = !isOpen(m)),
                          child: Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                            child: Transform.rotate(
                              angle: isOpen(m) ? 3.14159 : 0,
                              child: AssetIcon('icons/chevron-down-small.svg', width: 12, height: 12, color: dark ? Colors.white : null),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                if (isOpen(m))
                  Container(
                    color: dark ? Dak.surface : Colors.white,
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        for (final lesson in m.lessons) ...[
                          LessonRow.lesson(
                            lesson,
                            onDelete: () async {
                              if (await confirmAction(context, 'Delete "${lesson.title}"?')) {
                                await _run(() => api.delete<dynamic>('/lessons/${lesson.id}')).catchError((_) {});
                              }
                            },
                          ),
                          const SizedBox(height: 12),
                        ],
                        if (_adding == m.id)
                          LessonForm(
                            onSubmit: (l) async {
                              await _run(() => api.post<dynamic>('/modules/${m.id}/lessons', l.toBody()), 'Lesson added');
                              if (mounted) setState(() => _adding = null);
                            },
                            onCancel: () => setState(() => _adding = null),
                          )
                        else
                          InkWell(
                            onTap: () => setState(() => _adding = m.id),
                            child: CustomPaint(
                              foregroundPainter: DashedBorder(color: dark ? Dak.heading : Auth.navy, radius: 4),
                              child: SizedBox(
                                height: 48,
                                child: Row(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    AssetIcon('icons/plus-small.svg', width: 11, height: 11, color: dark ? Colors.white : null),
                                    const SizedBox(width: 8),
                                    Text(
                                      'Add Lesson',
                                      style: TextStyle(fontSize: 14, fontWeight: FontWeight.w500, color: navy),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ),
                      ],
                    ),
                  ),
              ],
            ),
          ),
        LinkBox(
          href: '/classrooms/create/module?id=$id',
          child: Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: dark ? Dak.border : const Color(0xFFDCDCDC),
              borderRadius: BorderRadius.circular(8),
              boxShadow: const [BoxShadow(color: Color(0x0D000000), offset: Offset(0, 1), blurRadius: 2)],
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                AssetIcon('icons/plus-small.svg', width: 23, height: 23, color: dark ? Colors.white : null),
                const SizedBox(width: 8),
                Text(
                  'Add Module',
                  style: TextStyle(fontSize: 20, fontWeight: FontWeight.w600, color: navy),
                ),
              ],
            ),
          ),
        ),
        _footer(context, [
          _FooterButton(label: 'Save & exit', onTap: () => context.go('/classrooms/manage')),
          _FooterButton(label: 'Review & Publish', primary: true, onTap: () => context.go('/classrooms/create/review?id=$id')),
        ]),
      ],
    );
  }
}

/// Adds a module (with optional lessons) at a chosen position.
class CreateModulePage extends ConsumerStatefulWidget {
  const CreateModulePage({super.key, this.id});

  final String? id;

  @override
  ConsumerState<CreateModulePage> createState() => _CreateModulePageState();
}

class _CreateModulePageState extends ConsumerState<CreateModulePage> {
  final _title = TextEditingController();
  final _duration = TextEditingController();
  final _description = TextEditingController();
  final _items = <LessonInput>[];
  int? _position;
  bool _adding = false;
  String? _error;
  bool _saving = false;

  @override
  void dispose() {
    _title.dispose();
    _duration.dispose();
    _description.dispose();
    super.dispose();
  }

  Future<void> _submit(int placement) async {
    if (_title.text.trim().isEmpty) return setState(() => _error = 'Give the module a name.');
    setState(() {
      _error = null;
      _saving = true;
    });
    final api = ref.read(apiProvider);
    try {
      final minutes = num.tryParse(_duration.text.replaceAll(RegExp(r'[^\d.]'), ''));
      final json = await api.post<Map<String, dynamic>>('/classrooms/${widget.id}/modules', {
        'title': _title.text.trim(),
        if (_description.text.trim().isNotEmpty) 'description': _description.text.trim(),
        if (minutes != null && minutes > 0) 'durationMinutes': minutes.round(),
        'position': placement,
      });
      final created = ClassroomDetail.fromJson(json).modules.where((m) => m.position == placement).firstOrNull;
      if (created != null) {
        for (final lesson in _items) {
          await api.post<dynamic>('/modules/${created.id}/lessons', lesson.toBody());
        }
      }
      invalidateQueries(ref);
      if (mounted) context.go('/classrooms/create/curriculum?id=${widget.id}');
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
    final id = widget.id;
    if (id == null) return _startOver;
    final classroom = oneOf(ref, '/classrooms/$id', ClassroomDetail.fromJson);
    if (classroom == null) return const SizedBox.shrink();

    final dark = context.isDark;
    final navy = dark ? Dak.heading : Auth.navy;
    final grey = dark ? Dak.muted : const Color(0xFF929292);
    final slots = classroom.modules.length + 1;
    final placement = _position ?? slots;
    final label = TextStyle(fontSize: 14, fontWeight: FontWeight.w500, color: navy);
    final boxBorder = dark ? Dak.heading : Light.border;

    Widget input(TextEditingController c, String hint, {bool number = false, int lines = 1}) => Container(
      height: lines == 1 ? 48 : null,
      padding: EdgeInsets.symmetric(horizontal: 16, vertical: lines == 1 ? 0 : 12),
      alignment: Alignment.centerLeft,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(4),
        border: Border.all(color: boxBorder),
      ),
      child: TextField(
        controller: c,
        minLines: lines,
        maxLines: lines,
        keyboardType: number ? TextInputType.number : null,
        inputFormatters: number ? [FilteringTextInputFormatter.digitsOnly] : null,
        style: TextStyle(fontSize: lines == 1 ? 14 : 16, color: navy),
        decoration: InputDecoration.collapsed(
          hintText: hint,
          hintStyle: TextStyle(fontSize: lines == 1 ? 14 : 16, color: grey),
        ),
      ),
    );

    final placementField = Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text('Placement', style: label),
        const SizedBox(height: 8),
        Container(
          height: 48,
          padding: const EdgeInsets.symmetric(horizontal: 16),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(4),
            border: Border.all(color: boxBorder),
          ),
          child: DropdownButtonHideUnderline(
            child: DropdownButton<int>(
              value: placement,
              isExpanded: true,
              icon: AssetIcon('icons/dropdown-arrow.svg', width: 16, height: 16, color: dark ? Colors.white : null),
              dropdownColor: dark ? Dak.surface : Colors.white,
              style: TextStyle(fontSize: 14, color: navy),
              items: [for (var n = slots; n >= 1; n--) DropdownMenuItem(value: n, child: Text('Module $n${n == slots ? ' (last)' : ''}'))],
              onChanged: (v) => setState(() => _position = v),
            ),
          ),
        ),
      ],
    );
    final durationField = Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text('Estimate Duration (minutes)', style: label),
        const SizedBox(height: 8),
        input(_duration, '45', number: true),
      ],
    );

    return _StepPage(
      back: '/classrooms/create/curriculum?id=$id',
      title: 'Create New Module',
      subtitle: 'Add a new curriculum item and place it within your course structure.',
      children: [
        Container(
          padding: const EdgeInsets.all(24),
          decoration: _panel(context, lightBorder: Light.border),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                'Module Identity',
                style: TextStyle(fontSize: 24, fontWeight: FontWeight.w600, color: navy),
              ),
              const SizedBox(height: 24),
              Text('Module Title', style: label),
              const SizedBox(height: 8),
              input(_title, 'e.g., Foundations of Structural Analysis'),
              const SizedBox(height: 24),
              if (_adding)
                LessonForm(
                  onSubmit: (lesson) async => setState(() {
                    _items.add(lesson);
                    _adding = false;
                  }),
                  onCancel: () => setState(() => _adding = false),
                )
              else
                InkWell(
                  onTap: () => setState(() => _adding = true),
                  child: CustomPaint(
                    foregroundPainter: DashedBorder(
                      color: dark ? Light.border.withValues(alpha: .4) : Light.border,
                      radius: 4,
                      strokeWidth: 2,
                    ),
                    child: Padding(
                      padding: const EdgeInsets.all(24),
                      child: Column(
                        children: [
                          Container(
                            width: 48,
                            height: 48,
                            alignment: Alignment.center,
                            decoration: BoxDecoration(color: const Color(0xFFF8F9FF), borderRadius: BorderRadius.circular(12)),
                            child: const AssetIcon('icons/plus-small.svg', width: 14, height: 14),
                          ),
                          const SizedBox(height: 8),
                          Text('Add Curriculum Item', style: label),
                          const SizedBox(height: 4),
                          Text(
                            'Video, Document, Diagram, or Assessment',
                            style: TextStyle(fontSize: 14, color: dark ? Dak.body : Auth.navy),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              const SizedBox(height: 24),
              if (context.isSm)
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(child: placementField),
                    const SizedBox(width: 16),
                    Expanded(child: durationField),
                  ],
                )
              else ...[
                placementField,
                const SizedBox(height: 16),
                durationField,
              ],
              const SizedBox(height: 24),
              Text('Description', style: label),
              const SizedBox(height: 8),
              input(_description, 'Provide a brief overview of the module content...', lines: 3),
            ],
          ),
        ),
        Container(
          padding: const EdgeInsets.all(24),
          decoration: _panel(context),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                'Curriculum Planner',
                style: TextStyle(fontSize: 24, fontWeight: FontWeight.w600, color: navy),
              ),
              const SizedBox(height: 24),
              if (_items.isEmpty)
                Text(
                  'Items you add appear here. You can also add lessons later.',
                  style: TextStyle(fontSize: 14, color: dark ? Dak.body : Auth.navy),
                ),
              for (final (i, item) in _items.indexed) ...[
                if (i > 0) const SizedBox(height: 12),
                LessonRow(
                  title: '${i + 1}. ${item.title}',
                  kind: item.kind,
                  meta: lessonMeta(
                    kind: item.kind,
                    durationMinutes: item.durationMinutes,
                    resourceUrl: item.resourceUrl,
                    canvasTitle: item.canvasTitle,
                  ),
                  onDelete: () => setState(() => _items.removeAt(i)),
                ),
              ],
            ],
          ),
        ),
        if (_error != null) ErrorText(_error!),
        _FooterButton(
          label: _saving ? 'Adding…' : 'Add Module',
          primary: true,
          radius: 8,
          onTap: _saving ? null : () => _submit(placement),
        ),
      ],
    );
  }
}

/// Step 3: overview and publish.
class ReviewClassroomPage extends ConsumerStatefulWidget {
  const ReviewClassroomPage({super.key, this.id});

  final String? id;

  @override
  ConsumerState<ReviewClassroomPage> createState() => _ReviewClassroomPageState();
}

class _ReviewClassroomPageState extends ConsumerState<ReviewClassroomPage> {
  String? _open;
  bool _publishing = false;

  Future<void> _publish(bool published) async {
    setState(() => _publishing = true);
    final toast = ref.read(toastProvider.notifier);
    try {
      await ref.read(apiProvider).post<dynamic>('/classrooms/${widget.id}/publish');
      invalidateQueries(ref);
      toast.show(published ? 'Classroom updated' : 'Course published');
      if (mounted) context.go('/classrooms/${widget.id}');
    } catch (e) {
      toast.error(errorMessage(e));
      if (mounted) setState(() => _publishing = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final id = widget.id;
    if (id == null) return _startOver;
    final result = ref.watch(query('/classrooms/$id'));
    if (result.hasError) return ErrorState(error: result.error!);
    if (result.value == null) return const SizedBox.shrink();
    final c = ClassroomDetail.fromJson(result.value as Map<String, dynamic>);

    final dark = context.isDark;
    final navy = dark ? Dak.heading : Auth.navy;
    final sub = dark ? Dak.body : Auth.navy;
    final published = c.status == 'PUBLISHED';
    final totalMinutes = c.modules.fold<int>(
      0,
      (sum, m) => sum + (m.durationMinutes ?? m.lessons.fold<int>(0, (s, l) => s + (l.durationMinutes ?? 0))),
    );
    final divider = dark ? Hex.text.withValues(alpha: .6) : Light.border;
    final caption = TextStyle(fontSize: 12, fontWeight: FontWeight.w600, letterSpacing: .6, color: sub);

    Widget fact(String label, Widget value) => Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label.toUpperCase(), style: caption),
        const SizedBox(height: 4),
        value,
      ],
    );

    BoxDecoration card() => BoxDecoration(
      color: dark ? Dak.surface : Colors.white,
      borderRadius: BorderRadius.circular(8),
      border: dark ? null : Border.all(color: Light.border),
    );

    final image = Container(
      width: context.isSm ? 154 : double.infinity,
      height: 179,
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        color: dark ? Dak.heading.withValues(alpha: .06) : const Color(0xFFEAEAEA),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: dark ? Light.border.withValues(alpha: .2) : Light.border),
      ),
      child: c.imageUrl != null
          ? UserImage(src: c.imageUrl)
          : Center(
              child: Opacity(
                opacity: .6,
                child: AssetIcon('icons/image-insert.svg', width: 40, height: 40, color: dark ? Colors.white : null),
              ),
            ),
    );
    final details = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(c.title, style: TextStyle(fontSize: 24, color: navy)),
        const SizedBox(height: 8),
        Text(c.description ?? '', style: TextStyle(fontSize: 14, color: sub)),
        const SizedBox(height: 16),
        Wrap(
          spacing: 24,
          runSpacing: 12,
          children: [
            fact(
              'Target Audience',
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    width: 8,
                    height: 8,
                    decoration: BoxDecoration(shape: BoxShape.circle, color: dark ? Colors.white : Auth.navy),
                  ),
                  const SizedBox(width: 6),
                  Text(
                    c.targetAudience ?? (c.skillLevel != null ? _audience[c.skillLevel]! : 'Everyone'),
                    style: TextStyle(fontSize: 14, color: navy),
                  ),
                ],
              ),
            ),
            fact(
              'Est. Duration',
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const AssetIcon('icons/clock-small.svg', width: 13, height: 13),
                  const SizedBox(width: 6),
                  Text(c.durationLabel ?? formatMinutes(totalMinutes) ?? 'Not set', style: TextStyle(fontSize: 14, color: navy)),
                ],
              ),
            ),
            fact('Category', Text(c.category ?? '—', style: TextStyle(fontSize: 14, color: navy))),
          ],
        ),
      ],
    );

    return _StepPage(
      back: '/classrooms/create/curriculum?id=$id',
      title: 'Review & Publish',
      bold: true,
      subtitle: 'Final structural overview before deployment to the student portal. Verify all components and technical requirements.',
      children: [
        const StepTrack(steps: _steps, current: 2),
        Container(
          padding: const EdgeInsets.all(24),
          decoration: card(),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Container(
                padding: const EdgeInsets.only(bottom: 16),
                decoration: BoxDecoration(
                  border: Border(bottom: BorderSide(color: divider)),
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: Text(
                        'Course Identity',
                        style: TextStyle(fontSize: 24, fontWeight: FontWeight.w500, color: navy),
                      ),
                    ),
                    TextLink(
                      'Edit',
                      href: '/classrooms/create?id=$id',
                      style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: Dak.cta),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 24),
              if (context.isSm)
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    image,
                    const SizedBox(width: 16),
                    Expanded(child: details),
                  ],
                )
              else ...[
                image,
                const SizedBox(height: 16),
                details,
              ],
            ],
          ),
        ),
        Container(
          padding: const EdgeInsets.all(24),
          decoration: card(),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Container(
                padding: const EdgeInsets.only(bottom: 16),
                decoration: BoxDecoration(
                  border: Border(bottom: BorderSide(color: divider)),
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('Curriculum Topology', style: TextStyle(fontSize: 24, color: navy)),
                          const SizedBox(height: 4),
                          Text('Structural hierarchy of modules and lessons.', style: TextStyle(fontSize: 14, color: sub)),
                        ],
                      ),
                    ),
                    for (final (i, (n, l)) in [(c.modules.length, 'MODULES'), (c.lessonCount, 'LESSONS')].indexed) ...[
                      if (i > 0)
                        Container(
                          width: 1,
                          height: 32,
                          margin: const EdgeInsets.symmetric(horizontal: 16),
                          color: Hex.text.withValues(alpha: .4),
                        ),
                      Column(
                        children: [
                          Text(
                            '$n',
                            style: TextStyle(fontSize: 24, fontWeight: FontWeight.w600, color: navy),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            l,
                            style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: sub),
                          ),
                        ],
                      ),
                    ],
                  ],
                ),
              ),
              const SizedBox(height: 24),
              if (c.modules.isEmpty)
                Wrap(
                  children: [
                    const Text(
                      'Add at least one module with a lesson before publishing. ',
                      style: TextStyle(fontSize: 14, color: Hex.error),
                    ),
                    TextLink(
                      'Build curriculum',
                      href: '/classrooms/create/curriculum?id=$id',
                      style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w500,
                        color: Hex.error,
                        decoration: TextDecoration.underline,
                      ),
                    ),
                  ],
                ),
              for (final (i, m) in c.modules.indexed) ...[
                if (i > 0) const SizedBox(height: 12),
                Builder(
                  builder: (context) {
                    final open = _open == m.id || (_open == null && i == 0);
                    return Container(
                      clipBehavior: Clip.antiAlias,
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(4),
                        border: Border.all(color: dark ? Dak.heading.withValues(alpha: .15) : Light.border),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          InkWell(
                            onTap: () => setState(() => _open = open ? '' : m.id),
                            child: Container(
                              color: dark ? Dak.border : const Color(0xFFF8F9FF),
                              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                              child: Row(
                                children: [
                                  Transform.rotate(
                                    angle: open ? 0 : -1.5708,
                                    child: AssetIcon(
                                      'icons/chevron-down-small.svg',
                                      width: 12,
                                      height: 12,
                                      color: dark ? Colors.white : null,
                                    ),
                                  ),
                                  const SizedBox(width: 12),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Text('MODULE ${i + 1}', style: caption),
                                        const SizedBox(height: 2),
                                        Text(
                                          m.title,
                                          style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: navy),
                                        ),
                                      ],
                                    ),
                                  ),
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                    decoration: BoxDecoration(
                                      color: dark ? const Color(0xFF45464D) : const Color(0xFFDCDCDC),
                                      borderRadius: BorderRadius.circular(4),
                                    ),
                                    child: Text(
                                      '${m.lessons.length} Lessons',
                                      style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: navy),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                          if (open)
                            Container(
                              color: dark ? Dak.border : Colors.white,
                              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  if (m.lessons.isEmpty)
                                    Text(
                                      'No lessons yet',
                                      style: TextStyle(fontSize: 14, fontStyle: FontStyle.italic, color: sub),
                                    ),
                                  for (final (j, l) in m.lessons.indexed) ...[
                                    if (j > 0) const SizedBox(height: 8),
                                    Text('${i + 1}.${j + 1} ${l.title}', style: TextStyle(fontSize: 14, color: sub)),
                                  ],
                                ],
                              ),
                            ),
                        ],
                      ),
                    );
                  },
                ),
              ],
            ],
          ),
        ),
        Opacity(
          opacity: _publishing || c.lessonCount == 0 ? .5 : 1,
          child: _FooterButton(
            label: _publishing ? 'Publishing…' : (published ? 'Save & View Course' : 'Publish Course'),
            primary: true,
            radius: 8,
            onTap: _publishing || c.lessonCount == 0 ? null : () => _publish(published),
          ),
        ),
      ],
    );
  }
}
