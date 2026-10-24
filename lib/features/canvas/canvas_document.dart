import 'dart:math' as math;
import 'dart:ui';

/// One drawable thing on a canvas, stored exactly as apps/web stores it (CanvasObject in types.ts).
class CanvasObject {
  const CanvasObject({
    required this.id,
    required this.type,
    required this.x,
    required this.y,
    this.w,
    this.h,
    this.points,
    this.text,
    this.color,
    this.fill,
    this.strokeWidth,
    this.fontSize,
    this.productId,
    this.src,
    this.author,
  });

  final String id;
  final String type;
  final double x;
  final double y;
  final double? w;
  final double? h;
  final List<Offset>? points;
  final String? text;
  final String? color;
  final String? fill;
  final double? strokeWidth;
  final double? fontSize;
  final String? productId;
  final String? src;
  final String? author;

  CanvasObject copyWith({double? x, double? y, double? w, double? h, List<Offset>? points, String? text, String? color}) => CanvasObject(
    id: id,
    type: type,
    x: x ?? this.x,
    y: y ?? this.y,
    w: w ?? this.w,
    h: h ?? this.h,
    points: points ?? this.points,
    text: text ?? this.text,
    color: color ?? this.color,
    fill: fill,
    strokeWidth: strokeWidth,
    fontSize: fontSize,
    productId: productId,
    src: src,
    author: author,
  );

  factory CanvasObject.fromJson(Map<String, dynamic> json) {
    double? n(Object? v) => (v as num?)?.toDouble();
    return CanvasObject(
      id: json['id'] as String,
      type: json['type'] as String,
      x: n(json['x']) ?? 0,
      y: n(json['y']) ?? 0,
      w: n(json['w']),
      h: n(json['h']),
      points: (json['points'] as List?)?.map((p) => Offset((p[0] as num).toDouble(), (p[1] as num).toDouble())).toList(),
      text: json['text'] as String?,
      color: json['color'] as String?,
      fill: json['fill'] as String?,
      strokeWidth: n(json['strokeWidth']),
      fontSize: n(json['fontSize']),
      productId: json['productId'] as String?,
      src: json['src'] as String?,
      author: json['author'] as String?,
    );
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'type': type,
    'x': x,
    'y': y,
    'w': ?w,
    'h': ?h,
    if (points != null)
      'points': [
        for (final p in points!) [p.dx, p.dy],
      ],
    'text': ?text,
    'color': ?color,
    'fill': ?fill,
    'strokeWidth': ?strokeWidth,
    'fontSize': ?fontSize,
    'productId': ?productId,
    'src': ?src,
    'author': ?author,
  };

  /// The box the selection outline is drawn around, from SelectionBox in CanvasEditor.tsx.
  Rect get bounds {
    if (type == 'path' && (points?.isNotEmpty ?? false)) {
      final xs = points!.map((p) => p.dx);
      final ys = points!.map((p) => p.dy);
      final left = xs.reduce(math.min);
      final top = ys.reduce(math.min);
      return Rect.fromLTRB(left, top, xs.reduce(math.max), ys.reduce(math.max));
    }
    if (type == 'text') {
      final size = fontSize ?? 24;
      final lines = math.max(1, text?.split('\n').length ?? 1);
      return Rect.fromLTWH(x, y, math.max(40, (text?.length ?? 4) * size * .55), size * 1.3 * lines);
    }
    return Rect.fromLTWH(x, y, w ?? 0, h ?? 0);
  }
}

class CanvasView {
  const CanvasView(this.x, this.y, this.zoom);

  final double x;
  final double y;
  final double zoom;

  Map<String, dynamic> toJson() => {'x': x, 'y': y, 'zoom': zoom};

  static CanvasView? fromJson(Object? json) {
    if (json is! Map) return null;
    return CanvasView((json['x'] as num).toDouble(), (json['y'] as num).toDouble(), (json['zoom'] as num).toDouble());
  }
}

class CanvasDocument {
  const CanvasDocument(this.objects, [this.viewport]);

  final List<CanvasObject> objects;
  final CanvasView? viewport;

  factory CanvasDocument.fromJson(Map<String, dynamic>? json) => CanvasDocument([
    for (final o in (json?['objects'] as List? ?? const [])) CanvasObject.fromJson(o as Map<String, dynamic>),
  ], CanvasView.fromJson(json?['viewport']));

  Map<String, dynamic> toJson() => {
    'objects': [for (final o in objects) o.toJson()],
    if (viewport != null) 'viewport': viewport!.toJson(),
  };
}

/// "#9436fb" -> Color; "transparent" -> transparent; anything unparseable -> [fallback].
Color parseColor(String? hex, [Color fallback = const Color(0xFF2B2B31)]) {
  if (hex == null) return fallback;
  if (hex == 'transparent') return const Color(0x00000000);
  final v = int.tryParse(hex.replaceFirst('#', ''), radix: 16);
  if (v == null) return fallback;
  return Color(0xFF000000 | v);
}
