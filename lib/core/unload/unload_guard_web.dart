import 'dart:js_interop';

import 'package:web/web.dart' as web;

/// Asks the browser to confirm leaving the page while [pending] is true. Returns a remover.
void Function() guardUnload(bool Function() pending) {
  final listener = ((web.Event e) {
    if (pending()) e.preventDefault();
  }).toJS;
  web.window.addEventListener('beforeunload', listener);
  return () => web.window.removeEventListener('beforeunload', listener);
}
