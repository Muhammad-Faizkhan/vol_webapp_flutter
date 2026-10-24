import 'dart:async';

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/api/api_error.dart';
import '../../core/api/upload.dart';
import '../../core/auth/auth.dart';
import '../../core/query.dart';
import '../../core/unload/unload_guard.dart';
import '../../models/canvas.dart';
import '../../models/product.dart';
import '../../models/user.dart';
import '../../models/workspace.dart';
import '../../theme/tokens.dart';
import '../../ui/asset_icon.dart';
import '../../ui/layout.dart';
import '../../ui/link_box.dart';
import '../../ui/page_bits.dart';
import '../../ui/popover.dart';
import '../../ui/toast.dart';
import '../../ui/user_image.dart';
import 'canvas_document.dart';
import 'canvas_editor.dart';

enum _Save { saved, saving, unsaved, error }

const _saveLabel = {_Save.saved: 'Synced', _Save.saving: 'Saving…', _Save.unsaved: 'Unsaved changes', _Save.error: 'Not saved'};
const _thumbnailEvery = Duration(seconds: 30);

/// Shown when a canvas can't be opened.
class CanvasMissing extends StatelessWidget {
  const CanvasMissing({super.key, required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    final dark = context.isDark;
    return Scaffold(
      backgroundColor: dark ? Dak.bg : Light.appBg,
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                message,
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 20, fontWeight: FontWeight.w600, color: dark ? Dak.heading : Auth.navy),
              ),
              const SizedBox(height: 16),
              Material(
                color: Dak.cta,
                borderRadius: BorderRadius.circular(12),
                child: InkWell(
                  borderRadius: BorderRadius.circular(12),
                  onTap: () => context.go('/workspaces'),
                  child: const Padding(
                    padding: EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                    child: Text('Back to workspaces', style: TextStyle(color: Colors.white)),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _Spinner extends StatelessWidget {
  const _Spinner();

  @override
  Widget build(BuildContext context) => Scaffold(
    backgroundColor: context.pick(Colors.white, Dak.bg),
    body: Center(
      child: SizedBox.square(
        dimension: 40,
        child: CircularProgressIndicator(strokeWidth: 4, color: Dak.cta, backgroundColor: Dak.cta.withValues(alpha: .3)),
      ),
    ),
  );
}

class CanvasPage extends ConsumerWidget {
  const CanvasPage({super.key, required this.canvasId, this.addProduct});

  final String canvasId;
  final String? addProduct;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final result = ref.watch(query('/canvases/$canvasId'));
    if (result.hasError) return CanvasMissing(message: errorMessage(result.error!));
    final json = result.value as Map<String, dynamic>?;
    if (json == null) return const _Spinner();
    // Keyed by id only, so refetches (product links) don't reset the editor.
    return _Editor(key: ValueKey(canvasId), canvas: CanvasDetail.fromJson(json), addProduct: addProduct);
  }
}

class _Editor extends ConsumerStatefulWidget {
  const _Editor({super.key, required this.canvas, this.addProduct});

  final CanvasDetail canvas;
  final String? addProduct;

  @override
  ConsumerState<_Editor> createState() => _EditorState();
}

class _EditorState extends ConsumerState<_Editor> {
  final _handle = CanvasEditorController();
  late final CanvasDetail _initial = widget.canvas;
  late CanvasDocument _doc = CanvasDocument.fromJson(_initial.data);
  _Save _saveState = _Save.saved;
  CanvasDocument? _pending;
  DateTime _lastSave = DateTime.now();
  DateTime _lastThumb = DateTime(0);
  late Set<String> _linked = {for (final p in _initial.products) p.id};
  Timer? _quiet;
  Timer? _forced;
  late void Function() _unguard;

  late final _title = TextEditingController(text: _initial.card.title);
  late Access _visibility = _initial.card.visibility;
  bool _menu = false;
  CanvasObject? _selected;
  String _search = '';

  CanvasDetail get canvas => widget.canvas;
  bool get _readOnly => !_initial.canEdit;

  @override
  void initState() {
    super.initState();
    _unguard = guardUnload(() => _pending != null);
    if (widget.addProduct != null && !_readOnly) _placeRequestedProduct(widget.addProduct!);
  }

  @override
  void dispose() {
    _unguard();
    _quiet?.cancel();
    _forced?.cancel();
    // Don't lose the last edits when leaving the page.
    unawaited(_flush());
    _title.dispose();
    super.dispose();
  }

  /// "Add to a canvas" on a product page lands here with ?addProduct=productId.
  Future<void> _placeRequestedProduct(String productId) async {
    final toast = ref.read(toastProvider.notifier);
    try {
      final product = Product.fromJson(await ref.read(apiProvider).get<Map<String, dynamic>>('/products/$productId'));
      // The editor attaches its handle on first build; give it a moment if it isn't there yet.
      for (var i = 0; i < 20 && !_handle.attached; i++) {
        await Future<void>.delayed(const Duration(milliseconds: 50));
      }
      _handle.addProduct(product);
      toast.show('Added ${product.name}');
    } catch (e) {
      toast.error(errorMessage(e));
    } finally {
      if (mounted) context.go('/canvas/${_initial.card.id}');
    }
  }

  /// Keeps the canvas's product links (the "4 Products" counts) in step with what's on the canvas.
  Future<void> _syncProducts(CanvasDocument next) async {
    final api = ref.read(apiProvider);
    final onCanvas = {
      for (final o in next.objects)
        if (o.type == 'product' && o.productId != null) o.productId!,
    };
    final added = onCanvas.difference(_linked);
    final removed = _linked.difference(onCanvas);
    for (final id in added) {
      await api.post<dynamic>('/canvases/${_initial.card.id}/products', {'productId': id}).catchError((_) => null);
    }
    for (final id in removed) {
      await api.delete<dynamic>('/canvases/${_initial.card.id}/products/$id').catchError((_) => null);
    }
    if (added.isNotEmpty || removed.isNotEmpty) {
      _linked = onCanvas;
      ref.invalidate(query('/canvases/${_initial.card.id}'));
    }
  }

  Future<void> _saveThumbnail() async {
    _lastThumb = DateTime.now();
    final png = await _handle.thumbnail();
    if (png == null) return;
    try {
      final api = ref.read(apiProvider);
      final form = FormData.fromMap({
        'file': MultipartFile.fromBytes(png, filename: 'thumbnail.png', contentType: DioMediaType('image', 'png')),
      });
      final res = await api.post<Map<String, dynamic>>('/uploads', form);
      await api.patch<dynamic>('/canvases/${_initial.card.id}', {'thumbnailUrl': res['url']});
    } catch (_) {
      // A missing thumbnail isn't worth interrupting the user for.
    }
  }

  Future<void> _flush() async {
    final next = _pending;
    if (next == null || _readOnly) return;
    _pending = null;
    if (mounted) setState(() => _saveState = _Save.saving);
    try {
      await ref.read(apiProvider).put<dynamic>('/canvases/${_initial.card.id}/data', {'data': next.toJson()});
      _lastSave = DateTime.now();
      if (mounted) setState(() => _saveState = _pending != null ? _Save.unsaved : _Save.saved);
      await _syncProducts(next);
      if (DateTime.now().difference(_lastThumb) > _thumbnailEvery && mounted) unawaited(_saveThumbnail());
    } catch (e) {
      _pending ??= next;
      if (mounted) setState(() => _saveState = _Save.error);
      ref.read(toastProvider.notifier).error(errorMessage(e));
    }
  }

  // Save shortly after edits stop, and at least every `autosaveSeconds` while editing continuously.
  void _schedule() {
    _quiet?.cancel();
    _quiet = Timer(const Duration(milliseconds: 1500), _flush);
    if (_forced?.isActive != true) {
      final due = _lastSave.add(Duration(seconds: _initial.autosaveSeconds)).difference(DateTime.now());
      _forced = Timer(due.isNegative ? Duration.zero : due, _flush);
    }
  }

  void _onChange(CanvasDocument next) {
    _pending = next;
    setState(() {
      _doc = next;
      _saveState = _Save.unsaved;
    });
    _schedule();
  }

  Future<void> _rename() async {
    final next = _title.text.trim();
    if (next.isEmpty || next == canvas.card.title) {
      _title.text = canvas.card.title;
      return;
    }
    try {
      await ref.read(apiProvider).patch<dynamic>('/canvases/${_initial.card.id}', {'title': next});
      invalidateQueries(ref);
    } catch (e) {
      _title.text = canvas.card.title;
      ref.read(toastProvider.notifier).error(errorMessage(e));
    }
  }

  Future<void> _toggleVisibility() async {
    final next = _visibility == Access.public ? Access.private : Access.public;
    final toast = ref.read(toastProvider.notifier);
    try {
      await ref.read(apiProvider).patch<dynamic>('/canvases/${_initial.card.id}', {'visibility': accessJson(next)});
      setState(() => _visibility = next);
      toast.show(next == Access.public ? 'Canvas is now public' : 'Canvas is now private');
    } catch (e) {
      toast.error(errorMessage(e));
    }
  }

  Future<void> _delete() async {
    setState(() => _menu = false);
    if (!await confirmAction(context, 'Delete "${canvas.card.title}"? This can\'t be undone.')) return;
    try {
      await ref.read(apiProvider).delete<dynamic>('/canvases/${_initial.card.id}');
      _pending = null;
      invalidateQueries(ref);
      if (mounted) context.go('/workspaces/${canvas.card.workspaceId}/canvases');
    } catch (e) {
      ref.read(toastProvider.notifier).error(errorMessage(e));
    }
  }

  Future<void> _insertImage() async {
    final file = await pickFile(UploadKind.image);
    if (file == null) return;
    try {
      _handle.addImage(await uploadFile(ref.read(apiProvider), file));
    } catch (e) {
      ref.read(toastProvider.notifier).error(errorMessage(e));
    }
  }

  @override
  Widget build(BuildContext context) {
    final dark = context.isDark;
    final user = ref.watch(authProvider);
    final c = canvas.card;
    final navy = dark ? Dak.heading : Auth.navy;
    final border = dark ? Dak.border : Light.border;
    final grey = dark ? Dak.muted : const Color(0xFF929292);
    final readOnly = _readOnly;

    final selectedProductId = _selected?.type == 'product' ? _selected!.productId : null;
    final selectedProduct = selectedProductId == null ? null : oneOf(ref, '/products/$selectedProductId', Product.fromJson);
    final quantities = <String, int>{};
    for (final o in _doc.objects) {
      if (o.type == 'product' && o.productId != null) quantities[o.productId!] = (quantities[o.productId!] ?? 0) + 1;
    }
    final onCanvas = canvas.products.where((p) => quantities.containsKey(p.id)).toList();
    final found = readOnly ? null : pagedOf(ref, withQuery('/products', {'q': _search.trim(), 'limit': 6}), Product.fromJson);
    final canDelete = canvas.myRole == WorkspaceRole.owner || canvas.myRole == WorkspaceRole.admin || c.createdBy.id == user?.id;

    Widget sideCard(String title, Widget child) => Container(
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        color: dark ? Dak.surface : Colors.white,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Container(
            color: dark ? Dak.bg : const Color(0xFFCDCED0),
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            child: Text(
              title,
              style: TextStyle(fontSize: 14, fontWeight: FontWeight.w500, color: navy),
            ),
          ),
          Padding(padding: const EdgeInsets.all(16), child: child),
        ],
      ),
    );
    Widget thumb(String? src) => Container(
      width: 32,
      height: 32,
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(color: dark ? Dak.cta : Auth.navy, borderRadius: BorderRadius.circular(2)),
      child: UserImage(src: src, fallback: 'illustrations/auth-placeholder.svg'),
    );

    final aside = Container(
      decoration: BoxDecoration(
        color: dark ? Dak.bg : const Color(0xFFD9D9D9),
        border: context.screenWidth >= 768 ? Border(right: BorderSide(color: border)) : Border(top: BorderSide(color: border)),
      ),
      child: ListView(
        padding: const EdgeInsets.all(24),
        children: [
          if (selectedProduct != null) ...[
            Text(
              'Selected Product',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600, color: navy),
            ),
            const SizedBox(height: 12),
            Container(
              clipBehavior: Clip.antiAlias,
              decoration: BoxDecoration(
                color: dark ? Dak.surface : const Color(0xFFF8F9FF),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: border),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  SizedBox(
                    height: 130,
                    child: ColoredBox(
                      color: dark ? Dak.surface : Auth.navy,
                      child: UserImage(src: selectedProduct.images.firstOrNull, fallback: 'illustrations/auth-placeholder.svg'),
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          selectedProduct.name,
                          style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600, color: navy),
                        ),
                        Text('By ${selectedProduct.business.name}', style: TextStyle(fontSize: 14, color: grey)),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(color: dark ? Dak.surface : const Color(0xFFF8F9FF), borderRadius: BorderRadius.circular(16)),
              child: Column(
                children: [
                  for (final (i, (label, value)) in [
                    ('True Size', selectedProduct.size ?? '—'),
                    ('Thickness', selectedProduct.heightMm != null ? '${selectedProduct.heightMm} mm' : '—'),
                    ('Weight', selectedProduct.weightKg != null ? '${selectedProduct.weightKg} kg' : '—'),
                    ('Brand', selectedProduct.brand ?? '—'),
                  ].indexed)
                    Container(
                      padding: const EdgeInsets.symmetric(vertical: 10),
                      decoration: i != 3
                          ? BoxDecoration(
                              border: Border(bottom: BorderSide(color: border)),
                            )
                          : null,
                      child: Row(
                        children: [
                          Text(label, style: TextStyle(fontSize: 14, color: dark ? Dak.body : Auth.navy)),
                          const Spacer(),
                          Text(
                            value,
                            style: TextStyle(fontSize: 14, fontWeight: FontWeight.w500, color: navy),
                          ),
                        ],
                      ),
                    ),
                ],
              ),
            ),
            const SizedBox(height: 24),
          ],
          if (!readOnly) ...[
            sideCard(
              'Add products',
              Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Container(
                    height: 40,
                    padding: const EdgeInsets.symmetric(horizontal: 12),
                    alignment: Alignment.centerLeft,
                    decoration: BoxDecoration(
                      color: dark ? Dak.bg : const Color(0xFFF8F9FF),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: border),
                    ),
                    child: TextField(
                      onChanged: (v) => setState(() => _search = v),
                      style: TextStyle(fontSize: 14, color: navy),
                      decoration: InputDecoration.collapsed(
                        hintText: 'Search the catalog…',
                        hintStyle: TextStyle(fontSize: 14, color: grey),
                      ),
                    ),
                  ),
                  if (found?.items.isEmpty == true) ...[
                    const SizedBox(height: 12),
                    Text('No products found.', style: TextStyle(fontSize: 14, color: grey)),
                  ],
                  for (final p in found?.items ?? const <Product>[]) ...[
                    const SizedBox(height: 12),
                    _HoverOutline(
                      onTap: () => _handle.addProduct(p),
                      child: Row(
                        children: [
                          thumb(p.images.firstOrNull),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  p.name,
                                  overflow: TextOverflow.ellipsis,
                                  style: TextStyle(fontSize: 14, fontWeight: FontWeight.w500, color: navy),
                                ),
                                Text(
                                  'By ${p.business.name}',
                                  overflow: TextOverflow.ellipsis,
                                  style: TextStyle(fontSize: 12, color: grey),
                                ),
                              ],
                            ),
                          ),
                          const Text('+', style: TextStyle(fontSize: 18, color: Dak.cta)),
                        ],
                      ),
                    ),
                  ],
                ],
              ),
            ),
            const SizedBox(height: 24),
          ],
          sideCard(
            'Products on this canvas · ${quantities.values.fold(0, (a, b) => a + b)}',
            Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                if (onCanvas.isEmpty)
                  Text(
                    readOnly ? 'No products placed yet.' : 'Search the catalog above to place products.',
                    style: TextStyle(fontSize: 14, color: grey),
                  ),
                for (final (i, p) in onCanvas.indexed) ...[
                  if (i > 0) const SizedBox(height: 16),
                  LinkBox(
                    href: '/products/${p.id}',
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                      decoration: BoxDecoration(
                        color: dark ? Dak.bg : const Color(0xFFF8F9FF),
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: border),
                      ),
                      child: Row(
                        children: [
                          thumb(p.image),
                          const SizedBox(width: 16),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  p.name,
                                  overflow: TextOverflow.ellipsis,
                                  style: TextStyle(fontSize: 14, fontWeight: FontWeight.w500, color: navy),
                                ),
                                Text(
                                  'By ${p.business.name}',
                                  overflow: TextOverflow.ellipsis,
                                  style: TextStyle(fontSize: 12, color: grey),
                                ),
                              ],
                            ),
                          ),
                          Text('x${quantities[p.id]}', style: TextStyle(fontSize: 14, color: dark ? Dak.body : Auth.navy)),
                        ],
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );

    final editor = CanvasEditor(
      doc: CanvasDocument.fromJson(_initial.data),
      readOnly: readOnly,
      authorName: user?.name ?? 'Me',
      onChange: _onChange,
      onSelect: (o) => WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        if (o?.id != _selected?.id || o?.productId != _selected?.productId) setState(() => _selected = o);
      }),
      controller: _handle,
      onRequestImage: _insertImage,
      overlay: Positioned(
        right: 24,
        bottom: 24,
        child: IgnorePointer(
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            decoration: BoxDecoration(color: dark ? Dak.cta : Auth.navy, borderRadius: BorderRadius.circular(8)),
            child: Row(
              children: [
                Container(
                  width: 8,
                  height: 8,
                  decoration: const BoxDecoration(color: Color(0xFF22C55E), shape: BoxShape.circle),
                ),
                const SizedBox(width: 8),
                Text(
                  '${c.collaboratorCount} ${c.collaboratorCount == 1 ? 'Collaborator' : 'Collaborators'}',
                  style: const TextStyle(fontSize: 14, color: Colors.white),
                ),
              ],
            ),
          ),
        ),
      ),
    );

    final header = _CanvasHeader(
      leading: [
        Tooltip(
          message: 'Back',
          child: Material(
            color: dark ? Dak.cta : const Color(0xFFF2F2F3),
            borderRadius: BorderRadius.circular(8),
            child: InkWell(
              borderRadius: BorderRadius.circular(8),
              onTap: () => context.go(canvas.myRole != null ? '/workspaces/${c.workspaceId}/canvases' : '/explore'),
              child: SizedBox.square(
                dimension: 36,
                child: Center(
                  child: Transform.flip(
                    flipX: true,
                    child: AssetIcon('icons/arrow-narrow-right.svg', width: 18, height: 18, color: dark ? Colors.white : null),
                  ),
                ),
              ),
            ),
          ),
        ),
        if (context.isSm)
          Flexible(
            child: Text(
              c.workspaceName,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(fontSize: 16, color: navy),
            ),
          ),
        Text('/', style: TextStyle(fontSize: 16, color: navy)),
        if (readOnly)
          Flexible(
            child: Text(
              c.title,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.w500, color: navy),
            ),
          )
        else
          Flexible(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 260),
              child: Focus(
                onFocusChange: (focused) {
                  if (!focused) _rename();
                },
                child: TextField(
                  controller: _title,
                  onSubmitted: (_) => FocusScope.of(context).unfocus(),
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.w500, color: navy),
                  decoration: InputDecoration(
                    isDense: true,
                    border: InputBorder.none,
                    contentPadding: const EdgeInsets.symmetric(horizontal: 4, vertical: 4),
                    hoverColor: Auth.navy.withValues(alpha: .05),
                    filled: true,
                    fillColor: Colors.transparent,
                  ),
                ),
              ),
            ),
          ),
      ],
      middle: Row(
        children: [
          Avatar(src: c.createdBy.avatarUrl, name: c.createdBy.name, size: 32),
          const SizedBox(width: 8),
          Text(
            readOnly ? 'Shared by ${c.createdBy.name}' : 'Created by ${c.createdBy.name}',
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.w500, color: dark ? Dak.body : Auth.navy),
          ),
        ],
      ),
      trailing: [
        _Badge(label: readOnly ? 'View only' : _saveLabel[_saveState]!),
        if (!readOnly)
          Tooltip(
            message: 'Toggle who can see this canvas',
            child: Material(
              color: _visibility == Access.public
                  ? Hex.google.withValues(alpha: .15)
                  : (dark ? Dak.cta.withValues(alpha: .1) : Hex.black.withValues(alpha: .1)),
              borderRadius: BorderRadius.circular(8),
              child: InkWell(
                borderRadius: BorderRadius.circular(8),
                onTap: _toggleVisibility,
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  child: Text(
                    _visibility == Access.public ? 'Public' : 'Private',
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w500,
                      color: _visibility == Access.public ? Hex.google : (dark ? Dak.heading : Hex.black),
                    ),
                  ),
                ),
              ),
            ),
          ),
        if (canDelete)
          Popover(
            open: _menu,
            onClose: () => setState(() => _menu = false),
            width: 176,
            panel: MenuCard(
              child: InkWell(
                onTap: _delete,
                child: Container(
                  constraints: const BoxConstraints(minHeight: 44),
                  alignment: Alignment.centerLeft,
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: const Text(
                    'Delete canvas',
                    style: TextStyle(fontSize: 14, fontWeight: FontWeight.w500, color: Hex.error),
                  ),
                ),
              ),
            ),
            child: Tooltip(
              message: 'Canvas options',
              child: InkWell(
                borderRadius: BorderRadius.circular(8),
                onTap: () => setState(() => _menu = !_menu),
                child: SizedBox.square(
                  dimension: 36,
                  child: Center(
                    child: Text('⋯', style: TextStyle(fontSize: 20, color: navy)),
                  ),
                ),
              ),
            ),
          ),
      ],
    );

    final wide = context.screenWidth >= 768;
    return Scaffold(
      backgroundColor: dark ? Dak.bg : Colors.white,
      body: Column(
        children: [
          header,
          Expanded(
            child: wide
                ? Row(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      SizedBox(width: 400, child: aside),
                      Expanded(child: editor),
                    ],
                  )
                : Column(
                    children: [
                      Expanded(child: editor),
                      SizedBox(height: context.screenHeight * .45, child: aside),
                    ],
                  ),
          ),
        ],
      ),
    );
  }
}

class _Badge extends StatelessWidget {
  const _Badge({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    final dark = context.isDark;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(color: dark ? Dak.surface : const Color(0xFFEFEFEF), borderRadius: BorderRadius.circular(8)),
      child: Text(
        label,
        style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: dark ? Dak.heading : Auth.navy),
      ),
    );
  }
}

/// The 64px bar above the canvas: back + title, author in the middle (md and up), status on the right.
class _CanvasHeader extends StatelessWidget {
  const _CanvasHeader({required this.leading, required this.middle, required this.trailing, this.surface});

  final List<Widget> leading;
  final Widget middle;
  final List<Widget> trailing;
  final Color? surface;

  @override
  Widget build(BuildContext context) {
    final dark = context.isDark;
    Widget row(List<Widget> items, double gap) => Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        for (final (i, w) in items.indexed) ...[if (i > 0) SizedBox(width: gap), w],
      ],
    );
    return Container(
      constraints: const BoxConstraints(minHeight: 64),
      padding: EdgeInsets.symmetric(horizontal: context.isSm ? 24 : 16, vertical: context.isSm ? 0 : 8),
      decoration: BoxDecoration(
        color: surface ?? (dark ? Dak.bg : Colors.white),
        border: Border(bottom: BorderSide(color: dark ? Dak.border : Light.border)),
      ),
      child: context.isSm
          ? Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Flexible(
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      for (final (i, w) in leading.indexed) ...[if (i > 0) const SizedBox(width: 12), w],
                    ],
                  ),
                ),
                if (context.screenWidth >= 768) ...[const SizedBox(width: 16), middle, const SizedBox(width: 16)],
                row(trailing, 12),
              ],
            )
          : Wrap(
              alignment: WrapAlignment.spaceBetween,
              crossAxisAlignment: WrapCrossAlignment.center,
              runSpacing: 8,
              spacing: 16,
              children: [row(leading, 12), row(trailing, 12)],
            ),
    );
  }
}

class _HoverOutline extends StatefulWidget {
  const _HoverOutline({required this.onTap, required this.child});

  final VoidCallback onTap;
  final Widget child;

  @override
  State<_HoverOutline> createState() => _HoverOutlineState();
}

class _HoverOutlineState extends State<_HoverOutline> {
  bool _hover = false;

  @override
  Widget build(BuildContext context) {
    final dark = context.isDark;
    return MouseRegion(
      cursor: SystemMouseCursors.click,
      onEnter: (_) => setState(() => _hover = true),
      onExit: (_) => setState(() => _hover = false),
      child: GestureDetector(
        onTap: widget.onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          decoration: BoxDecoration(
            color: dark ? Dak.bg : const Color(0xFFF8F9FF),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: _hover ? Dak.cta : (dark ? Dak.border : Light.border)),
          ),
          child: widget.child,
        ),
      ),
    );
  }
}

/// Read-only view of the canvas a Discover post shares.
class DiscoverCanvasPage extends ConsumerWidget {
  const DiscoverCanvasPage({super.key, required this.postId});

  final String postId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final postResult = ref.watch(query('/posts/$postId'));
    final postJson = postResult.value as Map<String, dynamic>?;
    final canvasRef = postJson == null ? null : CanvasRef.fromJson(postJson['canvas']);
    final canvasResult = canvasRef == null ? null : ref.watch(query('/canvases/${canvasRef.id}'));

    if (postResult.hasError || canvasResult?.hasError == true) {
      return CanvasMissing(message: errorMessage(postResult.error ?? canvasResult!.error!));
    }
    if (postJson != null && canvasRef == null) return const CanvasMissing(message: "This post doesn't share a canvas.");
    if (postJson == null || canvasResult?.value == null) return const _Spinner();

    final dark = context.isDark;
    final author = UserSummary.fromJson(postJson['author'] as Map<String, dynamic>);
    final canvas = CanvasDetail.fromJson(canvasResult!.value as Map<String, dynamic>);
    final navy = dark ? Dak.heading : Auth.navy;

    return Scaffold(
      backgroundColor: dark ? Dak.bg : Colors.white,
      body: Column(
        children: [
          _CanvasHeader(
            surface: dark ? Dak.surface : Colors.white,
            leading: [
              Material(
                color: dark ? Dak.bg : const Color(0xFFF2F2F3),
                borderRadius: BorderRadius.circular(8),
                child: InkWell(
                  borderRadius: BorderRadius.circular(8),
                  onTap: () => context.go('/discover/post/$postId'),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    child: Row(
                      children: [
                        Transform.flip(
                          flipX: true,
                          child: AssetIcon(
                            context.pick('icons/arrow-narrow-right.svg', 'icons/arrow-narrow-right-light.svg'),
                            width: 16,
                            height: 16,
                          ),
                        ),
                        const SizedBox(width: 8),
                        Text(
                          'Back to post',
                          style: TextStyle(fontSize: 14, fontWeight: FontWeight.w500, color: navy),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              Flexible(
                child: Text(
                  '/ ${canvas.card.title}',
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.w500, color: navy),
                ),
              ),
            ],
            middle: Row(
              children: [
                Avatar(src: author.avatarUrl, name: author.name, size: 32),
                const SizedBox(width: 8),
                Text(
                  'Shared by ${author.name}',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.w500, color: navy),
                ),
              ],
            ),
            trailing: [
              if (canvas.canEdit)
                LinkBox(
                  href: '/canvas/${canvas.card.id}',
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    decoration: BoxDecoration(color: Dak.cta, borderRadius: BorderRadius.circular(8)),
                    child: const Text(
                      'Open in editor',
                      style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: Colors.white),
                    ),
                  ),
                )
              else
                const _Badge(label: 'View only'),
            ],
          ),
          Expanded(
            child: CanvasEditor(doc: CanvasDocument.fromJson(canvas.data), readOnly: true, authorName: '', onChange: (_) {}),
          ),
        ],
      ),
    );
  }
}
