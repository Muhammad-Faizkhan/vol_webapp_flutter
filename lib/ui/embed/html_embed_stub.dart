import 'package:flutter/widgets.dart';

/// Outside the browser there is no <video>/<iframe>; the lesson viewer links out instead.
Widget htmlVideo(String url) => const SizedBox.shrink();

Widget htmlFrame(String url, String title) => const SizedBox.shrink();
