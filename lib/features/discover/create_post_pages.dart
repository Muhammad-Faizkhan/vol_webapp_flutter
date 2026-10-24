import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/api/api_error.dart';
import '../../core/auth/auth.dart';
import '../../core/format.dart';
import '../../core/query.dart';
import '../../models/canvas.dart';
import '../../theme/tokens.dart';
import '../../ui/asset_icon.dart';
import '../../ui/auto_grid.dart';
import '../../ui/layout.dart';
import '../../ui/route_modal.dart';
import '../../ui/toast.dart';
import '../../ui/user_image.dart';
import '../shared/rich_text.dart';
import 'discover_page.dart';

const _categories = ['Structural', 'Mechanical', 'Electrical', 'Civil', 'HVAC'];

class PostDraft {
  PostDraft({required this.title, required this.category, required this.description, required this.tags, required this.private});

  final String title;
  final String category;
  final String description;
  final List<String> tags;
  final bool private;
}

/// Carries the draft from "Add Post Details" to "Select a Canvas" (sessionStorage in apps/web).
final postDraftProvider = Provider((ref) => PostDraftSlot());

class PostDraftSlot {
  PostDraft? draft;
}

class CreatePostPage extends ConsumerStatefulWidget {
  const CreatePostPage({super.key});

  @override
  ConsumerState<CreatePostPage> createState() => _CreatePostPageState();
}

class _CreatePostPageState extends ConsumerState<CreatePostPage> {
  // Returning from the canvas step restores the draft.
  late final PostDraft? _saved = ref.read(postDraftProvider).draft;
  late final _title = TextEditingController(text: _saved?.title ?? '');
  late final _body = TextEditingController(text: _saved?.description ?? '');
  final _tagInput = TextEditingController();
  final _bodyFocus = FocusNode();
  final _tagFocus = FocusNode();
  late String? _category = _saved?.category;
  late List<String> _tags = [...?_saved?.tags];
  late bool _private = _saved?.private ?? false;
  String? _titleError;
  String? _categoryError;

  @override
  void initState() {
    super.initState();
    _tagFocus.addListener(() {
      if (!_tagFocus.hasFocus) _addTag();
    });
  }

  @override
  void dispose() {
    _title.dispose();
    _body.dispose();
    _tagInput.dispose();
    _bodyFocus.dispose();
    _tagFocus.dispose();
    super.dispose();
  }

  void _format(Format kind) {
    _body.value = applyFormat(_body.value, kind);
    _bodyFocus.requestFocus();
  }

  void _addTag() {
    final value = _tagInput.text.trim().replaceAll(',', '');
    if (value.isNotEmpty && !_tags.contains(value)) setState(() => _tags = [..._tags, value]);
    _tagInput.clear();
  }

  void _submit() {
    setState(() {
      _titleError = _title.text.trim().isEmpty ? 'Discussion title is required.' : null;
      _categoryError = _category == null ? 'Please select a category.' : null;
    });
    if (_titleError != null || _categoryError != null) return;
    ref.read(postDraftProvider).draft = PostDraft(
      title: _title.text,
      category: _category!,
      description: _body.text,
      tags: _tags,
      private: _private,
    );
    context.go('/discover/select-canvas');
  }

  @override
  Widget build(BuildContext context) {
    final dark = context.isDark;
    final ink = dark ? Dak.heading : Hex.black;
    final grey = dark ? Dak.muted : const Color(0xFF929292);
    final border = dark ? Dak.border : Hex.text;

    BoxDecoration box() => BoxDecoration(
      color: dark ? Dak.bg : Colors.white,
      borderRadius: BorderRadius.circular(12),
      border: Border.all(color: border),
    );
    Widget error(String? e) => e == null
        ? const SizedBox.shrink()
        : Padding(
            padding: const EdgeInsets.only(top: 8),
            child: Text(e, style: const TextStyle(fontSize: 12, color: Hex.error)),
          );
    Widget tool(String icon, String label, Format kind, double w, double h) => Tooltip(
      message: label,
      child: InkWell(
        borderRadius: BorderRadius.circular(4),
        onTap: () => _format(kind),
        child: Padding(
          padding: const EdgeInsets.all(6),
          child: AssetIcon(icon, width: w, height: h, color: dark ? Colors.white : null),
        ),
      ),
    );
    Widget radio(bool private, String title, String body) {
      final on = _private == private;
      return InkWell(
        onTap: () => setState(() => _private = private),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              margin: const EdgeInsets.only(top: 2),
              width: 16,
              height: 16,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(color: on ? Dak.cta : (dark ? Dak.border : Hex.black), width: on ? 4 : 1),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: TextStyle(fontSize: 14, fontWeight: FontWeight.w500, color: ink),
                  ),
                  Text(body, style: TextStyle(fontSize: 14, color: dark ? Dak.muted : Hex.text)),
                ],
              ),
            ),
          ],
        ),
      );
    }

    final form = Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Container(
          color: dark ? Dak.bg : Colors.white,
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Add Post Details',
                      style: TextStyle(fontSize: 24, fontWeight: FontWeight.w600, color: ink),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Provide context and data for your structural design canvas.',
                      style: TextStyle(fontSize: 14, color: dark ? Dak.body : Hex.text),
                    ),
                  ],
                ),
              ),
              Tooltip(
                message: 'Close',
                child: InkWell(
                  borderRadius: BorderRadius.circular(12),
                  onTap: () => context.go('/discover'),
                  child: SizedBox.square(
                    dimension: 32,
                    child: Center(child: AssetIcon('icons/close-x.svg', width: 14, height: 14, color: dark ? Colors.white : null)),
                  ),
                ),
              ),
            ],
          ),
        ),
        Container(
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            color: dark ? Dak.surface : null,
            gradient: dark
                ? null
                : const LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [Color(0x00EEEEEE), Color(0xFFFAF5FF)],
                  ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                'Discussion Title *',
                style: TextStyle(fontSize: 14, fontWeight: FontWeight.w500, color: ink),
              ),
              const SizedBox(height: 8),
              Container(
                height: 56,
                padding: const EdgeInsets.symmetric(horizontal: 17),
                alignment: Alignment.centerLeft,
                decoration: box(),
                child: TextField(
                  controller: _title,
                  style: TextStyle(fontSize: 16, color: ink),
                  decoration: InputDecoration.collapsed(
                    hintText: 'e.g., Clarification on load-bearing span requirements...',
                    hintStyle: TextStyle(fontSize: 16, color: grey),
                  ),
                ),
              ),
              error(_titleError),
              const SizedBox(height: 24),
              Text('Category *', style: TextStyle(fontSize: 14, color: ink)),
              const SizedBox(height: 8),
              Container(
                height: 56,
                padding: const EdgeInsets.symmetric(horizontal: 17),
                decoration: box(),
                child: DropdownButtonHideUnderline(
                  child: DropdownButton<String>(
                    value: _category,
                    isExpanded: true,
                    hint: Text('Select a Category...', style: TextStyle(fontSize: 16, color: dark ? Dak.heading : Hex.text)),
                    icon: AssetIcon('icons/chevron-down-small.svg', width: 12, height: 7.4, color: dark ? Colors.white : null),
                    dropdownColor: dark ? Dak.surface : Colors.white,
                    style: TextStyle(fontSize: 16, color: dark ? Dak.heading : Hex.text),
                    items: [for (final c in _categories) DropdownMenuItem(value: c, child: Text(c))],
                    onChanged: (v) => setState(() => _category = v),
                  ),
                ),
              ),
              error(_categoryError),
              const SizedBox(height: 24),
              Row(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Expanded(
                    child: Text(
                      'Description & Details',
                      style: TextStyle(fontSize: 14, fontWeight: FontWeight.w500, color: ink),
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(4),
                      border: Border.all(color: border),
                    ),
                    child: Row(
                      children: [
                        tool('icons/format-bold.svg', 'Bold', Format.bold, 7.8, 10.5),
                        const SizedBox(width: 4),
                        tool('icons/format-italic.svg', 'Italic', Format.italic, 9.75, 10.5),
                        Container(width: 1, height: 20, margin: const EdgeInsets.symmetric(horizontal: 6), color: border),
                        tool('icons/format-list-numbered.svg', 'Numbered list', Format.numbered, 13.5, 15),
                        const SizedBox(width: 4),
                        tool('icons/format-list-bulleted.svg', 'Bulleted list', Format.bulleted, 13.5, 12),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 17, vertical: 13),
                decoration: box(),
                child: TextField(
                  controller: _body,
                  focusNode: _bodyFocus,
                  minLines: 4,
                  maxLines: 4,
                  style: TextStyle(fontSize: 16, color: ink),
                  decoration: InputDecoration.collapsed(
                    hintText: 'Provide context, detailed questions, or instructions here...',
                    hintStyle: TextStyle(fontSize: 16, color: grey),
                  ),
                ),
              ),
              const SizedBox(height: 24),
              Text('Tags', style: TextStyle(fontSize: 12, color: ink)),
              const SizedBox(height: 6),
              GestureDetector(
                onTap: _tagFocus.requestFocus,
                child: Container(
                  constraints: const BoxConstraints(minHeight: 44),
                  padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 10),
                  decoration: box(),
                  child: Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    crossAxisAlignment: WrapCrossAlignment.center,
                    children: [
                      for (final tag in _tags)
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                          decoration: BoxDecoration(color: Hex.text, borderRadius: BorderRadius.circular(2)),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text(
                                tag,
                                style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: Colors.white),
                              ),
                              const SizedBox(width: 6),
                              Tooltip(
                                message: 'Remove $tag',
                                child: InkWell(
                                  onTap: () => setState(() => _tags = _tags.where((t) => t != tag).toList()),
                                  child: const AssetIcon('icons/tag-remove.svg', width: 8, height: 8),
                                ),
                              ),
                            ],
                          ),
                        ),
                      SizedBox(
                        width: 100,
                        child: KeyboardListener(
                          focusNode: FocusNode(skipTraversal: true),
                          onKeyEvent: (e) {
                            if (e is KeyDownEvent &&
                                e.logicalKey == LogicalKeyboardKey.backspace &&
                                _tagInput.text.isEmpty &&
                                _tags.isNotEmpty) {
                              setState(() => _tags = _tags.sublist(0, _tags.length - 1));
                            }
                          },
                          child: TextField(
                            controller: _tagInput,
                            focusNode: _tagFocus,
                            onSubmitted: (_) {
                              _addTag();
                              _tagFocus.requestFocus();
                            },
                            onChanged: (v) {
                              if (v.endsWith(',')) _addTag();
                            },
                            style: TextStyle(fontSize: 14, color: ink),
                            decoration: InputDecoration.collapsed(
                              hintText: 'Add a tag...',
                              hintStyle: TextStyle(fontSize: 14, color: grey),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 24),
              Text('Visibility Settings', style: TextStyle(fontSize: 12, color: ink)),
              const SizedBox(height: 12),
              radio(false, 'Public', 'Visible to anyone on the network.'),
              const SizedBox(height: 12),
              radio(true, 'Private', 'Visible only to you and invited collaborators.'),
            ],
          ),
        ),
        Container(
          color: dark ? Dak.surface : Colors.white,
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
          alignment: Alignment.centerRight,
          child: DecoratedBox(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(16),
              boxShadow: [BoxShadow(color: Dak.cta.withValues(alpha: .4), offset: const Offset(0, 8), blurRadius: 6)],
            ),
            child: Material(
              color: Dak.cta,
              borderRadius: BorderRadius.circular(16),
              child: InkWell(
                borderRadius: BorderRadius.circular(16),
                onTap: _submit,
                child: const SizedBox(
                  width: 166,
                  height: 48,
                  child: Center(
                    child: Text(
                      'Post on Feed',
                      style: TextStyle(fontSize: 14, fontWeight: FontWeight.w500, color: Colors.white),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ],
    );

    return RouteModal(background: const DiscoverPage(), child: form);
  }
}

class SelectCanvasPage extends ConsumerStatefulWidget {
  const SelectCanvasPage({super.key});

  @override
  ConsumerState<SelectCanvasPage> createState() => _SelectCanvasPageState();
}

class _SelectCanvasPageState extends ConsumerState<SelectCanvasPage> {
  String _q = '';
  String? _selected;
  bool _posting = false;

  @override
  void initState() {
    super.initState();
    if (ref.read(postDraftProvider).draft == null) {
      WidgetsBinding.instance.addPostFrameCallback((_) => context.go('/discover/create-post'));
    }
  }

  Future<void> _publish(String? canvasId) async {
    final draft = ref.read(postDraftProvider).draft;
    if (draft == null) return;
    setState(() => _posting = true);
    final toast = ref.read(toastProvider.notifier);
    try {
      final post = await ref.read(apiProvider).post<Map<String, dynamic>>('/posts', {
        'title': draft.title,
        'body': draft.description,
        if (draft.category.isNotEmpty) 'category': draft.category,
        'tags': draft.tags,
        'visibility': draft.private ? 'PRIVATE' : 'PUBLIC',
        'canvasId': canvasId,
      });
      ref.read(postDraftProvider).draft = null;
      invalidateQueries(ref);
      toast.show('Posted to the feed');
      if (mounted) context.go('/discover/post/${post['id']}');
    } catch (e) {
      toast.error(errorMessage(e));
      if (mounted) setState(() => _posting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final dark = context.isDark;
    final navy = dark ? Dak.heading : Auth.navy;
    final border = dark ? Dak.border : Light.border;
    final hasDraft = ref.read(postDraftProvider).draft != null;
    final data = pagedOf(ref, withQuery('/canvases/recent', {'q': _q.trim(), 'limit': 24}), CanvasCard.fromJson);
    final wide = context.isSm;
    final grey = dark ? Dak.muted : const Color(0xFF929292);

    final skip = Opacity(
      opacity: _posting || !hasDraft ? .6 : 1,
      child: Material(
        color: dark ? Dak.bg : const Color(0xFFF2F2F3),
        borderRadius: BorderRadius.circular(8),
        child: InkWell(
          borderRadius: BorderRadius.circular(8),
          onTap: _posting || !hasDraft ? null : () => _publish(null),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
            child: Text(
              'Skip & Post',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.w500, color: navy),
            ),
          ),
        ),
      ),
    );
    final go = Opacity(
      opacity: _posting || !hasDraft || _selected == null ? .6 : 1,
      child: Material(
        color: dark ? Dak.cta : Auth.navy,
        borderRadius: BorderRadius.circular(8),
        child: InkWell(
          borderRadius: BorderRadius.circular(8),
          onTap: _posting || !hasDraft || _selected == null ? null : () => _publish(_selected),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
            child: Text(
              _posting ? 'Posting…' : 'Continue →',
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w500, color: Colors.white),
            ),
          ),
        ),
      ),
    );

    final modal = Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Container(
          padding: EdgeInsets.symmetric(horizontal: wide ? 50 : 16, vertical: wide ? 24 : 16),
          decoration: BoxDecoration(
            border: Border(bottom: BorderSide(color: border)),
          ),
          child: Row(
            children: [
              InkWell(
                onTap: () => context.go('/discover/create-post'),
                child: Text('✕ Cancel', style: TextStyle(fontSize: 18, color: navy)),
              ),
              Expanded(
                child: Text(
                  'Select a Canvas',
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: wide ? 24 : 20, fontWeight: FontWeight.w600, color: navy),
                ),
              ),
              SizedBox(width: wide ? 80 : 60),
            ],
          ),
        ),
        Container(
          color: dark ? Dak.bg : const Color(0xFFF4F4F4),
          padding: EdgeInsets.symmetric(horizontal: context.isLg ? 120 : (wide ? 40 : 16), vertical: wide ? 24 : 16),
          child: Container(
            height: 44,
            padding: const EdgeInsets.symmetric(horizontal: 16),
            alignment: Alignment.centerLeft,
            decoration: BoxDecoration(
              color: dark ? Dak.surface : Colors.white,
              borderRadius: BorderRadius.circular(4),
              border: Border.all(color: border),
            ),
            child: TextField(
              onChanged: (v) => setState(() => _q = v),
              style: TextStyle(fontSize: 14, color: dark ? Dak.heading : const Color(0xFF45464D)),
              decoration: InputDecoration.collapsed(
                hintText: 'Search canvases by name or project...',
                hintStyle: TextStyle(fontSize: 14, color: dark ? Dak.muted : const Color(0xFF757575)),
              ),
            ),
          ),
        ),
        Container(
          color: dark ? Dak.surface : null,
          constraints: BoxConstraints(maxHeight: context.screenHeight * .55),
          child: SingleChildScrollView(
            padding: EdgeInsets.symmetric(horizontal: context.isLg ? 100 : (wide ? 40 : 16), vertical: wide ? 24 : 16),
            child: data?.items.isEmpty == true
                ? Padding(
                    padding: const EdgeInsets.symmetric(vertical: 32),
                    child: Text(
                      'No canvases to attach — you can skip and post without one.',
                      textAlign: TextAlign.center,
                      style: TextStyle(fontSize: 14, color: grey),
                    ),
                  )
                : AutoGrid(
                    minItemWidth: 220,
                    fill: true,
                    children: [
                      for (final c in data?.items ?? const <CanvasCard>[])
                        _CanvasChoice(
                          canvas: c,
                          selected: _selected == c.id,
                          onTap: () => setState(() => _selected = _selected == c.id ? null : c.id),
                        ),
                    ],
                  ),
          ),
        ),
        Container(
          padding: EdgeInsets.symmetric(horizontal: wide ? 32 : 16, vertical: wide ? 20 : 16),
          decoration: BoxDecoration(
            border: Border(top: BorderSide(color: border)),
          ),
          child: wide
              ? Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [skip, go])
              : Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [go, const SizedBox(height: 12), skip]),
        ),
      ],
    );

    return RouteModal(background: const DiscoverPage(), maxWidth: 1420, child: modal);
  }
}

class _CanvasChoice extends StatelessWidget {
  const _CanvasChoice({required this.canvas, required this.selected, required this.onTap});

  final CanvasCard canvas;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final dark = context.isDark;
    final c = canvas;
    return MouseRegion(
      cursor: SystemMouseCursors.click,
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          clipBehavior: Clip.antiAlias,
          decoration: BoxDecoration(
            color: dark ? Dak.surface : Colors.white,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: selected ? Dak.cta : Colors.transparent, width: 2),
            boxShadow: selected ? null : [BoxShadow(color: Hex.text.withValues(alpha: .2), offset: const Offset(0, 4), blurRadius: 8)],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              SizedBox(
                height: 130,
                child: ColoredBox(
                  color: dark ? Dak.bg : Auth.navy,
                  child: Stack(
                    fit: StackFit.expand,
                    children: [
                      UserImage(src: c.thumbnailUrl, fallback: 'illustrations/canvas-thumb-moodboard.png'),
                      if (selected)
                        Positioned(
                          right: 12,
                          top: 12,
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                            decoration: BoxDecoration(color: Dak.cta, borderRadius: BorderRadius.circular(999)),
                            child: const Text(
                              'Selected',
                              style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: Colors.white),
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
              ),
              Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      c.title,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(fontSize: 16, fontWeight: FontWeight.w500, color: dark ? Dak.heading : Hex.black),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      c.workspaceName,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(fontSize: 14, color: dark ? Dak.body : Auth.slate),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Edited ${timeAgo(c.updatedAt)} · ${plural(c.productCount, 'Product')}',
                      style: TextStyle(fontSize: 12, color: dark ? Dak.muted : const Color(0xFF929292)),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
