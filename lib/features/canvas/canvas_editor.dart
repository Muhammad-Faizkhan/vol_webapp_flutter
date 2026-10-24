import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_svg/flutter_svg.dart';

import '../../models/product.dart';
import '../../theme/tokens.dart';
import '../../ui/layout.dart';
import 'canvas_document.dart';

// A small vector editor, ported from components/canvas/CanvasEditor.tsx. Objects live in "world"
// coordinates; the view applies pan + zoom on top.

enum Tool { select, hand, pen, rect, ellipse, text, comment, image }

const _minZoom = .25;
const _maxZoom = 2.0;
const _grid = 68.0;
const _colors = ['#2b2b31', '#9436fb', '#34a853', '#ea4335', '#fbbc05', '#4285f4'];
const _maxObjects = 2000;

final _random = math.Random();
String _uid() => List.generate(8, (_) => '0123456789abcdefghijklmnopqrstuvwxyz'[_random.nextInt(36)]).join();

/// Lets the page add products and images and grab a thumbnail from outside the editor.
class CanvasEditorController {
  void Function(Product product)? _addProduct;
  void Function(String src)? _addImage;
  Future<Uint8List?> Function()? _thumbnail;

  void addProduct(Product product) => _addProduct?.call(product);
  void addImage(String src) => _addImage?.call(src);
  Future<Uint8List?> thumbnail() async => _thumbnail?.call();
  bool get attached => _addProduct != null;
}

sealed class _Drag {}

class _Pan extends _Drag {
  _Pan(this.start, this.view);
  final Offset start;
  final CanvasView view;
}

class _Move extends _Drag {
  _Move(this.id, this.start, this.orig);
  final String id;
  final Offset start;
  final CanvasObject orig;
}

class _Resize extends _Drag {
  _Resize(this.id, this.start, this.orig);
  final String id;
  final Offset start;
  final CanvasObject orig;
}

class _Draw extends _Drag {
  _Draw(this.id, this.start);
  final String id;
  final Offset start;
}

class CanvasEditor extends StatefulWidget {
  const CanvasEditor({
    super.key,
    required this.doc,
    required this.readOnly,
    required this.authorName,
    required this.onChange,
    this.onSelect,
    this.controller,
    this.onRequestImage,
    this.overlay,
  });

  final CanvasDocument doc;
  final bool readOnly;
  final String authorName;
  final ValueChanged<CanvasDocument> onChange;
  final ValueChanged<CanvasObject?>? onSelect;
  final CanvasEditorController? controller;
  final VoidCallback? onRequestImage;
  final Widget? overlay;

  @override
  State<CanvasEditor> createState() => _CanvasEditorState();
}

class _CanvasEditorState extends State<CanvasEditor> {
  final _boundary = GlobalKey();
  late List<CanvasObject> _objects = widget.doc.objects;
  late CanvasView _view = widget.doc.viewport ?? const CanvasView(80, 80, .8);
  late Tool _tool = widget.readOnly ? Tool.hand : Tool.select;
  String? _selectedId;
  String? _editingId;
  String _color = _colors.first;
  _Drag? _drag;
  final _past = <List<CanvasObject>>[];
  final _future = <List<CanvasObject>>[];
  Size _size = const Size(800, 600);
  DateTime _lastDown = DateTime(0);
  Offset _lastDownAt = Offset.zero;

  CanvasObject? get _selected => _objects.where((o) => o.id == _selectedId).firstOrNull;

  @override
  void initState() {
    super.initState();
    final c = widget.controller;
    if (c != null) {
      c._addProduct = _addProduct;
      c._addImage = _addImage;
      c._thumbnail = _renderThumbnail;
    }
    HardwareKeyboard.instance.addHandler(_onKey);
  }

  @override
  void dispose() {
    HardwareKeyboard.instance.removeHandler(_onKey);
    super.dispose();
  }

  void _select(String? id) {
    if (id == _selectedId) return;
    _selectedId = id;
    widget.onSelect?.call(_selected);
  }

  void _emit(List<CanvasObject> objects) => widget.onChange(CanvasDocument(objects, _view));

  /// Applies a change, records it for undo, and reports the new document.
  void _commit(List<CanvasObject> next, {bool record = true}) {
    if (next.length > _maxObjects) return;
    if (record) {
      _past.add(_objects);
      if (_past.length > 100) _past.removeAt(0);
      _future.clear();
    }
    setState(() => _objects = next);
    _emit(next);
    widget.onSelect?.call(_selected);
  }

  void _update(String id, CanvasObject Function(CanvasObject o) change) => _commit([for (final o in _objects) o.id == id ? change(o) : o]);

  void _remove(String id) {
    _commit(_objects.where((o) => o.id != id).toList());
    setState(() {
      _select(null);
      _editingId = null;
    });
  }

  void _undo() {
    if (_past.isEmpty) return;
    _future.add(_objects);
    setState(() => _objects = _past.removeLast());
    _emit(_objects);
  }

  void _redo() {
    if (_future.isEmpty) return;
    _past.add(_objects);
    setState(() => _objects = _future.removeLast());
    _emit(_objects);
  }

  /// Centre of the visible area in world coordinates (where new things are placed).
  Offset _viewCenter() => Offset((_size.width / 2 - _view.x) / _view.zoom, (_size.height / 2 - _view.y) / _view.zoom);

  void _addProduct(Product product) {
    final c = _viewCenter();
    // True scale: 1 world unit = 1 mm / 2 so typical tiles fit on screen.
    final w = ((product.widthMm ?? 300) / 2).clamp(80, 600).toDouble();
    final h = ((product.lengthMm ?? 300) / 2).clamp(80, 600).toDouble();
    final object = CanvasObject(
      id: _uid(),
      type: 'product',
      x: c.dx - w / 2,
      y: c.dy - h / 2,
      w: w,
      h: h,
      productId: product.id,
      text: product.size != null ? '${product.name} · ${product.size}' : product.name,
      src: product.images.firstOrNull,
    );
    _commit([..._objects, object]);
    setState(() {
      _select(object.id);
      _tool = Tool.select;
    });
  }

  void _addImage(String src) {
    final c = _viewCenter();
    final object = CanvasObject(id: _uid(), type: 'image', x: c.dx - 150, y: c.dy - 100, w: 300, h: 200, src: src);
    _commit([..._objects, object]);
    setState(() {
      _select(object.id);
      _tool = Tool.select;
    });
  }

  Offset _toWorld(Offset local) => Offset((local.dx - _view.x) / _view.zoom, (local.dy - _view.y) / _view.zoom);

  String? _hit(Offset p) {
    for (final o in _objects.reversed) {
      if (_hits(o, p)) return o.id;
    }
    return null;
  }

  bool _hits(CanvasObject o, Offset p) {
    switch (o.type) {
      case 'path':
        final pts = o.points ?? const <Offset>[];
        final reach = (o.strokeWidth ?? 3) / 2 + 4 / _view.zoom;
        for (var i = 0; i < pts.length; i++) {
          final a = pts[i];
          final b = i + 1 < pts.length ? pts[i + 1] : a;
          if (_distanceToSegment(p, a, b) <= reach) return true;
        }
        return false;
      case 'ellipse':
        final rx = (o.w ?? 0) / 2;
        final ry = (o.h ?? 0) / 2;
        if (rx <= 0 || ry <= 0) return false;
        final dx = (p.dx - (o.x + rx)) / rx;
        final dy = (p.dy - (o.y + ry)) / ry;
        return dx * dx + dy * dy <= 1;
      case 'comment':
        return Rect.fromLTWH(o.x, o.y, o.w ?? 180, o.h ?? 110).contains(p);
      default:
        return o.bounds.contains(p);
    }
  }

  static double _distanceToSegment(Offset p, Offset a, Offset b) {
    final ab = b - a;
    final len = ab.distanceSquared;
    if (len == 0) return (p - a).distance;
    final t = (((p - a).dx * ab.dx + (p - a).dy * ab.dy) / len).clamp(0.0, 1.0);
    return (p - (a + ab * t)).distance;
  }

  bool _onHandle(Offset p) {
    final s = _selected;
    if (s == null || s.type == 'path' || s.type == 'text') return false;
    final b = s.bounds;
    final pad = 4 / _view.zoom;
    final size = 10 / _view.zoom;
    final corner = Offset(b.right + pad, b.bottom + pad);
    return Rect.fromCenter(center: corner, width: size, height: size).inflate(2 / _view.zoom).contains(p);
  }

  void _onPointerDown(PointerDownEvent e) {
    if (e.buttons != kPrimaryButton) return;
    final now = DateTime.now();
    final isDouble = now.difference(_lastDown) < const Duration(milliseconds: 350) && (e.localPosition - _lastDownAt).distance < 6;
    _lastDown = now;
    _lastDownAt = e.localPosition;

    final p = _toWorld(e.localPosition);
    final targetId = _hit(p);

    if (isDouble && !widget.readOnly && targetId != null) {
      final o = _objects.firstWhere((x) => x.id == targetId);
      if (o.type == 'text' || o.type == 'comment') {
        setState(() => _editingId = o.id);
        return;
      }
    }

    if (widget.readOnly) {
      // Viewers can pan and inspect (e.g. select a product to see its details), not edit.
      setState(() => _select(targetId));
      _drag = _Pan(e.localPosition, _view);
      return;
    }
    switch (_tool) {
      case Tool.hand:
        _drag = _Pan(e.localPosition, _view);
      case Tool.select:
        setState(() => _editingId = null);
        final s = _selected;
        if (s != null && _onHandle(p)) {
          _drag = _Resize(s.id, p, s);
          _past.add(_objects);
        } else if (targetId != null) {
          setState(() => _select(targetId));
          _drag = _Move(targetId, p, _objects.firstWhere((o) => o.id == targetId));
          _past.add(_objects);
        } else {
          setState(() => _select(null));
          _drag = _Pan(e.localPosition, _view);
        }
      case Tool.image:
        widget.onRequestImage?.call();
      case Tool.text || Tool.comment:
        final object = _tool == Tool.text
            ? CanvasObject(id: _uid(), type: 'text', x: p.dx, y: p.dy, text: 'Text', color: _color, fontSize: 24)
            : CanvasObject(id: _uid(), type: 'comment', x: p.dx, y: p.dy, w: 180, h: 110, text: '', author: widget.authorName);
        _commit([..._objects, object]);
        setState(() {
          _select(object.id);
          _editingId = object.id;
          _tool = Tool.select;
        });
      case Tool.pen || Tool.rect || Tool.ellipse:
        // Drawing tools create the object now and grow it while dragging.
        final id = _uid();
        final object = _tool == Tool.pen
            ? CanvasObject(id: id, type: 'path', x: 0, y: 0, points: [p], color: _color, strokeWidth: 3)
            : CanvasObject(id: id, type: _tool.name, x: p.dx, y: p.dy, w: 1, h: 1, color: _color, fill: 'transparent', strokeWidth: 2);
        _past.add(_objects);
        _future.clear();
        setState(() => _objects = [..._objects, object]);
        _drag = _Draw(id, p);
    }
  }

  void _onPointerMove(PointerMoveEvent e) {
    final d = _drag;
    if (d == null) return;
    if (d is _Pan) {
      final delta = e.localPosition - d.start;
      setState(() => _view = CanvasView(d.view.x + delta.dx, d.view.y + delta.dy, _view.zoom));
      return;
    }
    final p = _toWorld(e.localPosition);
    setState(() {
      _objects = [
        for (final o in _objects)
          if (o.id !=
              switch (d) {
                _Move(:final id) || _Resize(:final id) || _Draw(:final id) => id,
                _ => '',
              })
            o
          else
            switch (d) {
              _Move(:final start, :final orig) =>
                orig.type == 'path'
                    ? o.copyWith(points: [for (final pt in orig.points!) pt + (p - start)])
                    : o.copyWith(x: orig.x + p.dx - start.dx, y: orig.y + p.dy - start.dy),
              _Resize(:final start, :final orig) => o.copyWith(
                w: math.max(10, (orig.w ?? 0) + p.dx - start.dx),
                h: math.max(10, (orig.h ?? 0) + p.dy - start.dy),
              ),
              _Draw(:final start) =>
                o.type == 'path'
                    ? o.copyWith(points: [...?o.points, p])
                    : o.copyWith(
                        x: math.min(start.dx, p.dx),
                        y: math.min(start.dy, p.dy),
                        w: (p.dx - start.dx).abs(),
                        h: (p.dy - start.dy).abs(),
                      ),
              _ => o,
            },
      ];
    });
    widget.onSelect?.call(_selected);
  }

  void _onPointerUp() {
    final d = _drag;
    _drag = null;
    if (d == null) return;
    if (d is _Pan) {
      _emit(_objects);
      return;
    }
    var next = _objects;
    if (d is _Draw) {
      final o = _objects.where((x) => x.id == d.id).firstOrNull;
      // A click without a drag makes a default-sized shape instead of a 1px one.
      if (o != null && o.type != 'path' && (o.w ?? 0) < 4 && (o.h ?? 0) < 4) {
        next = [for (final x in _objects) x.id == d.id ? x.copyWith(w: 160, h: 110) : x];
      }
      setState(() => _select(d.id));
    }
    if (d is _Move) {
      final now = _objects.where((o) => o.id == d.id).firstOrNull;
      if (now != null && now.x == d.orig.x && now.y == d.orig.y && d.orig.type != 'path') {
        _past.removeLast(); // a plain click, nothing moved
        return;
      }
    }
    _commit(next, record: false);
  }

  void _zoomAt(double factor, Offset at) {
    setState(() {
      final zoom = (_view.zoom * factor).clamp(_minZoom, _maxZoom);
      _view = CanvasView(at.dx - (at.dx - _view.x) * zoom / _view.zoom, at.dy - (at.dy - _view.y) * zoom / _view.zoom, zoom);
    });
  }

  void _onSignal(PointerSignalEvent e) {
    if (e is PointerScrollEvent) {
      final keys = HardwareKeyboard.instance;
      if (keys.isControlPressed || keys.isMetaPressed) {
        _zoomAt(math.exp(-e.scrollDelta.dy * .002), e.localPosition);
      } else {
        setState(() => _view = CanvasView(_view.x - e.scrollDelta.dx, _view.y - e.scrollDelta.dy, _view.zoom));
      }
    } else if (e is PointerScaleEvent) {
      _zoomAt(e.scale, e.localPosition);
    }
  }

  // Keyboard shortcuts, ignored while typing in a field.
  bool _onKey(KeyEvent e) {
    if (e is! KeyDownEvent || !mounted) return false;
    final focus = FocusManager.instance.primaryFocus?.context;
    if (focus != null && focus.findAncestorWidgetOfExactType<EditableText>() != null) return false;
    if (focus?.widget is EditableText) return false;

    final keys = HardwareKeyboard.instance;
    final mod = keys.isControlPressed || keys.isMetaPressed;
    final key = e.logicalKey;
    final readOnly = widget.readOnly;

    if (mod && key == LogicalKeyboardKey.keyZ) {
      if (!readOnly) keys.isShiftPressed ? _redo() : _undo();
      return true;
    }
    if (mod && key == LogicalKeyboardKey.keyY) {
      if (!readOnly) _redo();
      return true;
    }
    if ((key == LogicalKeyboardKey.delete || key == LogicalKeyboardKey.backspace) && _selectedId != null && !readOnly) {
      _remove(_selectedId!);
      return true;
    }
    if (key == LogicalKeyboardKey.escape) {
      setState(() {
        _select(null);
        _editingId = null;
      });
      return false;
    }
    if (!mod && !readOnly) {
      final tool = {
        LogicalKeyboardKey.keyV: Tool.select,
        LogicalKeyboardKey.keyH: Tool.hand,
        LogicalKeyboardKey.keyP: Tool.pen,
        LogicalKeyboardKey.keyR: Tool.rect,
        LogicalKeyboardKey.keyO: Tool.ellipse,
        LogicalKeyboardKey.keyT: Tool.text,
        LogicalKeyboardKey.keyC: Tool.comment,
      }[key];
      if (tool != null) {
        setState(() => _tool = tool);
        return false;
      }
    }
    return false;
  }

  void _zoomBy(double factor) => _zoomAt(factor, Offset(_size.width / 2, _size.height / 2));

  /// Zooms so every object is visible.
  void _fit() {
    if (_objects.isEmpty) return setState(() => _view = const CanvasView(80, 80, .8));
    final xs = <double>[];
    final ys = <double>[];
    for (final o in _objects) {
      if (o.points != null) {
        for (final p in o.points!) {
          xs.add(p.dx);
          ys.add(p.dy);
        }
      } else {
        xs.addAll([o.x, o.x + (o.w ?? 120)]);
        ys.addAll([o.y, o.y + (o.h ?? 30)]);
      }
    }
    final minX = xs.reduce(math.min), maxX = xs.reduce(math.max);
    final minY = ys.reduce(math.min), maxY = ys.reduce(math.max);
    final zoom = math
        .min((_size.width - 120) / (maxX - minX == 0 ? 1 : maxX - minX), (_size.height - 120) / (maxY - minY == 0 ? 1 : maxY - minY))
        .clamp(_minZoom, _maxZoom);
    setState(
      () => _view = CanvasView(
        (_size.width - (maxX - minX) * zoom) / 2 - minX * zoom,
        (_size.height - (maxY - minY) * zoom) / 2 - minY * zoom,
        zoom,
      ),
    );
  }

  /// Renders the canvas to a 640x400 PNG for the card thumbnails.
  Future<Uint8List?> _renderThumbnail() async {
    final boundary = _boundary.currentContext?.findRenderObject() as RenderRepaintBoundary?;
    if (boundary == null) return null;
    final shot = await boundary.toImage();
    const width = 640.0, height = 400.0;
    final recorder = ui.PictureRecorder();
    final canvas = Canvas(recorder);
    canvas.drawRect(const Rect.fromLTWH(0, 0, width, height), Paint()..color = const Color(0xFFF2F0EC));
    final scale = math.max(width / shot.width, height / shot.height);
    final dst = Rect.fromCenter(center: const Offset(width / 2, height / 2), width: shot.width * scale, height: shot.height * scale);
    canvas.drawImageRect(shot, Rect.fromLTWH(0, 0, shot.width.toDouble(), shot.height.toDouble()), dst, Paint());
    final image = await recorder.endRecording().toImage(width.toInt(), height.toInt());
    final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
    return bytes?.buffer.asUint8List();
  }

  MouseCursor get _cursor => widget.readOnly || _tool == Tool.hand
      ? (_drag is _Pan ? SystemMouseCursors.grabbing : SystemMouseCursors.grab)
      : _tool == Tool.select
      ? SystemMouseCursors.basic
      : SystemMouseCursors.precise;

  @override
  Widget build(BuildContext context) {
    final dark = context.isDark;
    final editing = _objects.where((o) => o.id == _editingId).firstOrNull;
    final selected = _selected;

    return LayoutBuilder(
      builder: (context, constraints) {
        _size = constraints.biggest;
        return ClipRect(
          child: ColoredBox(
            color: dark ? const Color(0xFF1A1A1D) : const Color(0xFFF2F0EC),
            child: Stack(
              children: [
                Positioned.fill(
                  child: MouseRegion(
                    cursor: _cursor,
                    child: Listener(
                      behavior: HitTestBehavior.opaque,
                      onPointerDown: _onPointerDown,
                      onPointerMove: _onPointerMove,
                      onPointerUp: (_) => _onPointerUp(),
                      onPointerCancel: (_) => _onPointerUp(),
                      onPointerSignal: _onSignal,
                      child: RepaintBoundary(
                        key: _boundary,
                        child: Stack(
                          children: [
                            Positioned.fill(child: CustomPaint(painter: _GridPainter(_view, dark ? Dak.border : const Color(0xFFE3E0DA)))),
                            Positioned(
                              left: 0,
                              top: 0,
                              child: Transform(
                                transform: Matrix4.identity()
                                  ..translateByDouble(_view.x, _view.y, 0, 1)
                                  ..scaleByDouble(_view.zoom, _view.zoom, 1, 1),
                                child: SizedBox(
                                  width: 1,
                                  height: 1,
                                  child: Stack(
                                    clipBehavior: Clip.none,
                                    children: [
                                      for (final o in _objects) _ObjectView(key: ValueKey(o.id), o: o),
                                      if (selected != null && !widget.readOnly)
                                        Positioned(left: 0, top: 0, child: CustomPaint(painter: _SelectionPainter(selected, _view.zoom))),
                                    ],
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
                if (editing != null)
                  _TextEditor(
                    key: ValueKey('edit-${editing.id}'),
                    object: editing,
                    view: _view,
                    onDone: (text) {
                      setState(() => _editingId = null);
                      if (text.trim().isEmpty && editing.type == 'text') {
                        _remove(editing.id);
                      } else if (text != editing.text) {
                        _update(editing.id, (o) => o.copyWith(text: text));
                      }
                    },
                  ),
                if (!widget.readOnly)
                  _Toolbar(
                    tool: _tool,
                    color: _color,
                    onTool: (t) => t == Tool.image ? widget.onRequestImage?.call() : setState(() => _tool = t),
                    onColor: (c) {
                      setState(() => _color = c);
                      final s = _selected;
                      if (s != null && s.type != 'product' && s.type != 'image' && s.type != 'comment') {
                        _update(s.id, (o) => o.copyWith(color: c));
                      }
                    },
                    onUndo: _undo,
                    onRedo: _redo,
                  ),
                Positioned(
                  left: 24,
                  bottom: 24,
                  child: _ZoomControls(zoom: _view.zoom, onZoom: _zoomBy, onFit: _fit),
                ),
                ?widget.overlay,
              ],
            ),
          ),
        );
      },
    );
  }
}

class _GridPainter extends CustomPainter {
  _GridPainter(this.view, this.color);

  final CanvasView view;
  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..strokeWidth = view.zoom;
    final step = _grid * view.zoom;
    // The web grid covers -5000..5000 world units; outside that the background shows through.
    final worldMin = Offset(view.x - 5000 * view.zoom, view.y - 5000 * view.zoom);
    final worldMax = Offset(view.x + 5000 * view.zoom, view.y + 5000 * view.zoom);
    var x = view.x % step - step;
    for (; x <= size.width; x += step) {
      if (x < worldMin.dx || x > worldMax.dx) continue;
      canvas.drawLine(Offset(x, math.max(0, worldMin.dy)), Offset(x, math.min(size.height, worldMax.dy)), paint);
    }
    var y = view.y % step - step;
    for (; y <= size.height; y += step) {
      if (y < worldMin.dy || y > worldMax.dy) continue;
      canvas.drawLine(Offset(math.max(0, worldMin.dx), y), Offset(math.min(size.width, worldMax.dx), y), paint);
    }
  }

  @override
  bool shouldRepaint(_GridPainter old) => old.view != view || old.color != color;
}

/// One object, drawn in world coordinates inside the transformed stack.
class _ObjectView extends StatelessWidget {
  const _ObjectView({super.key, required this.o});

  final CanvasObject o;

  @override
  Widget build(BuildContext context) {
    final stroke = parseColor(o.color);
    switch (o.type) {
      case 'rect' || 'ellipse' || 'path':
        return Positioned(left: 0, top: 0, child: CustomPaint(painter: _ShapePainter(o)));
      case 'text':
        final size = o.fontSize ?? 24;
        return Positioned(
          left: o.x,
          top: o.y,
          child: Text(
            o.text ?? '',
            softWrap: false,
            style: TextStyle(fontSize: size, height: 1.25, color: stroke, fontFamily: 'Inter'),
          ),
        );
      case 'comment':
        return Positioned(
          left: o.x,
          top: o.y,
          width: o.w ?? 180,
          height: o.h ?? 110,
          child: Container(
            padding: const EdgeInsets.all(12),
            clipBehavior: Clip.hardEdge,
            decoration: BoxDecoration(
              color: const Color(0xFFF4F4F4),
              borderRadius: BorderRadius.circular(6),
              border: Border.all(color: const Color(0xFF80939E)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'NOTE - ${(o.author ?? 'Anonymous').toUpperCase()}',
                  style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600, letterSpacing: .4, color: Hex.text),
                ),
                const SizedBox(height: 4),
                Text(
                  (o.text ?? '').isEmpty ? 'Double-click to write a note' : o.text!,
                  style: const TextStyle(fontSize: 12, height: 1.375, color: Hex.text),
                ),
              ],
            ),
          ),
        );
      case 'image':
        return Positioned(
          left: o.x,
          top: o.y,
          width: o.w,
          height: o.h,
          child: o.src == null
              ? const SizedBox.shrink()
              : Image.network(o.src!, fit: BoxFit.cover, errorBuilder: (_, _, _) => const SizedBox.shrink()),
        );
      case 'product':
        final w = o.w ?? 0, h = o.h ?? 0;
        return Positioned(
          left: o.x,
          top: o.y,
          child: SizedBox(
            width: math.max(w, 200),
            height: h + 34,
            child: Stack(
              clipBehavior: Clip.none,
              children: [
                Positioned(
                  left: 0,
                  top: 0,
                  width: w,
                  height: h,
                  child: Container(
                    decoration: BoxDecoration(
                      color: const Color(0xFFE3E3E3),
                      border: Border.all(color: Hex.text, width: 1.5),
                    ),
                    child: o.src == null
                        ? null
                        : Opacity(
                            opacity: .9,
                            child: Image.network(o.src!, fit: BoxFit.cover, errorBuilder: (_, _, _) => const SizedBox.shrink()),
                          ),
                  ),
                ),
                Positioned(
                  left: 0,
                  top: h + 6,
                  child: ConstrainedBox(
                    constraints: BoxConstraints(maxWidth: math.max(w, 200)),
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(color: Hex.text, borderRadius: BorderRadius.circular(4)),
                      child: Text(
                        (o.text ?? '').toUpperCase(),
                        overflow: TextOverflow.ellipsis,
                        softWrap: false,
                        style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w600, letterSpacing: .4, color: Colors.white),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      default:
        return const SizedBox.shrink();
    }
  }
}

class _ShapePainter extends CustomPainter {
  _ShapePainter(this.o);

  final CanvasObject o;

  @override
  void paint(Canvas canvas, Size size) {
    final stroke = Paint()
      ..color = parseColor(o.color)
      ..style = PaintingStyle.stroke
      ..strokeWidth = o.strokeWidth ?? (o.type == 'path' ? 3 : 2)
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;
    final fill = Paint()..color = parseColor(o.fill, const Color(0x00000000));
    final rect = Rect.fromLTWH(o.x, o.y, o.w ?? 0, o.h ?? 0);
    switch (o.type) {
      case 'rect':
        final r = RRect.fromRectAndRadius(rect, const Radius.circular(4));
        canvas.drawRRect(r, fill);
        canvas.drawRRect(r, stroke);
      case 'ellipse':
        canvas.drawOval(rect, fill);
        canvas.drawOval(rect, stroke);
      case 'path':
        final pts = o.points ?? const <Offset>[];
        if (pts.isEmpty) return;
        if (pts.length == 1) {
          canvas.drawPoints(ui.PointMode.points, pts, stroke);
          return;
        }
        canvas.drawPath(Path()..addPolygon(pts, false), stroke);
    }
  }

  @override
  bool shouldRepaint(_ShapePainter old) => old.o != o;
}

class _SelectionPainter extends CustomPainter {
  _SelectionPainter(this.o, this.zoom);

  final CanvasObject o;
  final double zoom;

  @override
  void paint(Canvas canvas, Size size) {
    final b = o.bounds;
    final pad = 4 / zoom;
    final box = b.inflate(pad);
    final line = Paint()
      ..color = Dak.cta
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.5 / zoom;
    final dash = 4 / zoom, gap = 3 / zoom;
    final metric = (Path()..addRect(box)).computeMetrics();
    for (final m in metric) {
      for (var d = 0.0; d < m.length; d += dash + gap) {
        canvas.drawPath(m.extractPath(d, d + dash), line);
      }
    }
    if (o.type != 'path' && o.type != 'text') {
      final s = 10 / zoom;
      final handle = Rect.fromCenter(center: Offset(b.right + pad, b.bottom + pad), width: s, height: s);
      canvas.drawRect(handle, Paint()..color = Colors.white);
      canvas.drawRect(handle, line);
    }
  }

  @override
  bool shouldRepaint(_SelectionPainter old) => old.o != o || old.zoom != zoom;
}

class _TextEditor extends StatefulWidget {
  const _TextEditor({super.key, required this.object, required this.view, required this.onDone});

  final CanvasObject object;
  final CanvasView view;
  final ValueChanged<String> onDone;

  @override
  State<_TextEditor> createState() => _TextEditorState();
}

class _TextEditorState extends State<_TextEditor> {
  late final _controller = TextEditingController(text: widget.object.text ?? '');
  final _focus = FocusNode();
  bool _done = false;

  @override
  void initState() {
    super.initState();
    var focused = false;
    _focus.addListener(() {
      if (_focus.hasFocus) focused = true;
      if (focused && !_focus.hasFocus) _finish();
    });
    // Focus after the click that created the editor has finished, or its pointer-up steals it back.
    Future<void>.delayed(const Duration(milliseconds: 60), () {
      if (mounted) _focus.requestFocus();
    });
    _focus.onKeyEvent = (_, e) {
      final keys = HardwareKeyboard.instance;
      if (e is KeyDownEvent &&
          (e.logicalKey == LogicalKeyboardKey.escape ||
              (e.logicalKey == LogicalKeyboardKey.enter && (keys.isControlPressed || keys.isMetaPressed)))) {
        _finish();
        return KeyEventResult.handled;
      }
      return KeyEventResult.ignored;
    };
  }

  void _finish() {
    if (_done) return;
    _done = true;
    widget.onDone(_controller.text);
  }

  @override
  void dispose() {
    _controller.dispose();
    _focus.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final o = widget.object;
    final v = widget.view;
    final isComment = o.type == 'comment';
    return Positioned(
      left: v.x + o.x * v.zoom,
      top: v.y + (o.y + (isComment ? 24 : 0)) * v.zoom,
      width: math.max(160, (o.w ?? 240) * v.zoom),
      child: Material(
        color: Colors.white.withValues(alpha: .95),
        elevation: 8,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(4),
          side: const BorderSide(color: Dak.cta, width: 2),
        ),
        child: Padding(
          padding: const EdgeInsets.all(8),
          child: ConstrainedBox(
            constraints: const BoxConstraints(minHeight: 44),
            child: TextField(
              controller: _controller,
              focusNode: _focus,
              maxLines: null,
              style: TextStyle(fontSize: isComment ? 13 : math.max(12, (o.fontSize ?? 24) * v.zoom), color: Hex.text),
              decoration: InputDecoration.collapsed(hintText: isComment ? 'Write a note…' : 'Text'),
            ),
          ),
        ),
      ),
    );
  }
}

const _toolIcons = {
  Tool.select: ('Select (V)', '<path d="M5 3l14 8-6 2-2 6z"/>'),
  Tool.hand: (
    'Pan (H)',
    '<path d="M8 13V5a1.5 1.5 0 013 0v6m0-1V4a1.5 1.5 0 013 0v7m0-4a1.5 1.5 0 013 0v7a6 6 0 01-6 6h-1a6 6 0 01-5-3l-2-4a1.5 1.5 0 012.5-1.5L8 13"/>',
  ),
  Tool.pen: ('Pen (P)', '<path d="M4 20l4-1 11-11-3-3L5 16zM14 6l3 3"/>'),
  Tool.rect: ('Rectangle (R)', '<rect x="4" y="6" width="16" height="12" rx="1"/>'),
  Tool.ellipse: ('Ellipse (O)', '<ellipse cx="12" cy="12" rx="8" ry="6"/>'),
  Tool.text: ('Text (T)', '<path d="M5 6V4h14v2M12 4v16M9 20h6"/>'),
  Tool.comment: ('Comment (C)', '<path d="M4 5h16v11H9l-5 4z"/>'),
  Tool.image: ('Insert image', '<rect x="4" y="5" width="16" height="14" rx="1"/><path d="M4 16l5-5 4 4 2-2 5 5"/>'),
};

String _hex(Color c) => '#${(c.toARGB32() & 0xFFFFFF).toRadixString(16).padLeft(6, '0')}';

class _Toolbar extends StatelessWidget {
  const _Toolbar({
    required this.tool,
    required this.color,
    required this.onTool,
    required this.onColor,
    required this.onUndo,
    required this.onRedo,
  });

  final Tool tool;
  final String color;
  final ValueChanged<Tool> onTool;
  final ValueChanged<String> onColor;
  final VoidCallback onUndo;
  final VoidCallback onRedo;

  @override
  Widget build(BuildContext context) {
    final dark = context.isDark;
    final ink = dark ? Dak.heading : Auth.navy;
    final rule = Container(width: 32, height: 1, color: dark ? Dak.border : Light.border);

    return Positioned(
      left: context.isSm ? 40 : 16,
      top: 0,
      bottom: 0,
      child: Center(
        child: Container(
          width: context.isSm ? 64 : 56,
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: dark ? Dak.surface : const Color(0xFFF8F9FF),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: dark ? Dak.border : Light.border),
            boxShadow: const [BoxShadow(color: Color(0x1A000000), offset: Offset(0, 4), blurRadius: 6, spreadRadius: -1)],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              for (final (i, t) in Tool.values.indexed) ...[
                if (i > 0) const SizedBox(height: 6),
                Tooltip(
                  message: _toolIcons[t]!.$1,
                  child: Material(
                    color: tool == t ? (dark ? Dak.cta.withValues(alpha: .4) : Auth.navy.withValues(alpha: .2)) : Colors.transparent,
                    borderRadius: BorderRadius.circular(12),
                    child: InkWell(
                      borderRadius: BorderRadius.circular(12),
                      hoverColor: Auth.navy.withValues(alpha: .1),
                      onTap: () => onTool(t),
                      child: SizedBox.square(
                        dimension: 40,
                        child: Center(
                          child: SvgPicture.string(
                            '<svg width="20" height="20" viewBox="0 0 24 24" fill="none" stroke="${_hex(ink)}" stroke-width="1.8" '
                            'stroke-linecap="round" stroke-linejoin="round">${_toolIcons[t]!.$2}</svg>',
                            width: 20,
                            height: 20,
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
                if (i == 1 || i == 4) ...[const SizedBox(height: 6), rule],
              ],
              const SizedBox(height: 6),
              rule,
              const SizedBox(height: 6),
              Wrap(
                spacing: 4,
                runSpacing: 4,
                children: [
                  for (final c in _colors)
                    Tooltip(
                      message: 'Color $c',
                      child: GestureDetector(
                        onTap: () => onColor(c),
                        child: MouseRegion(
                          cursor: SystemMouseCursors.click,
                          child: Container(
                            width: 16,
                            height: 16,
                            decoration: BoxDecoration(
                              color: parseColor(c),
                              shape: BoxShape.circle,
                              boxShadow: color == c
                                  ? const [BoxShadow(color: Colors.white, spreadRadius: 1), BoxShadow(color: Dak.cta, spreadRadius: 3)]
                                  : null,
                            ),
                          ),
                        ),
                      ),
                    ),
                ],
              ),
              const SizedBox(height: 6),
              rule,
              const SizedBox(height: 6),
              for (final (label, glyph, action) in [('Undo (Ctrl+Z)', '↶', onUndo), ('Redo (Ctrl+Shift+Z)', '↷', onRedo)])
                Tooltip(
                  message: label,
                  child: InkWell(
                    borderRadius: BorderRadius.circular(8),
                    onTap: action,
                    child: SizedBox.square(
                      dimension: 32,
                      child: Center(
                        child: Text(glyph, style: TextStyle(fontSize: 16, color: ink)),
                      ),
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

class _ZoomControls extends StatelessWidget {
  const _ZoomControls({required this.zoom, required this.onZoom, required this.onFit});

  final double zoom;
  final ValueChanged<double> onZoom;
  final VoidCallback onFit;

  @override
  Widget build(BuildContext context) {
    final dark = context.isDark;
    final ink = dark ? Dak.heading : Auth.navy;
    Widget button(String label, String tooltip, VoidCallback onTap, {double? width}) => Tooltip(
      message: tooltip,
      child: InkWell(
        borderRadius: BorderRadius.circular(4),
        onTap: onTap,
        child: Container(
          width: width ?? 28,
          height: 28,
          alignment: Alignment.center,
          child: Text(label, style: TextStyle(fontSize: 14, color: ink)),
        ),
      ),
    );
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: dark ? Dak.surface : Colors.white,
        borderRadius: BorderRadius.circular(8),
        boxShadow: const [BoxShadow(color: Color(0x1A000000), offset: Offset(0, 1), blurRadius: 3)],
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          button('−', 'Zoom out', () => onZoom(1 / 1.2)),
          SizedBox(
            width: 48,
            child: Text(
              '${(zoom * 100).round()}%',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 14, color: ink, fontFeatures: const [FontFeature.tabularFigures()]),
            ),
          ),
          button('+', 'Zoom in', () => onZoom(1.2)),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 4),
            child: Text('|', style: TextStyle(fontSize: 14, color: dark ? Dak.border : Light.border)),
          ),
          button('Fit', 'Fit to content', onFit, width: 36),
        ],
      ),
    );
  }
}
