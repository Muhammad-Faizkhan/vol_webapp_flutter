import 'dart:ui_web' as ui_web;

import 'package:flutter/widgets.dart';
import 'package:web/web.dart' as web;

final _registered = <String>{};

Widget _view(String key, web.HTMLElement Function() create) {
  if (_registered.add(key)) ui_web.platformViewRegistry.registerViewFactory(key, (int _) => create());
  return HtmlElementView(viewType: key);
}

/// A native <video controls> for uploaded MP4/WebM lessons.
Widget htmlVideo(String url) => _view('video:$url', () {
  return web.HTMLVideoElement()
    ..src = url
    ..controls = true
    ..style.width = '100%'
    ..style.height = '100%'
    ..style.backgroundColor = 'black';
});

/// An <iframe>, used to show PDF lessons inline.
Widget htmlFrame(String url, String title) => _view('frame:$url', () {
  return web.HTMLIFrameElement()
    ..src = url
    ..title = title
    ..style.border = 'none'
    ..style.width = '100%'
    ..style.height = '100%';
});
