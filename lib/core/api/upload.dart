import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:file_picker/file_picker.dart';

import 'api_client.dart';
import 'api_error.dart';

enum UploadKind { image, document, media }

class PickedFile {
  const PickedFile({required this.name, required this.bytes, this.mimeType});

  final String name;
  final Uint8List bytes;
  final String? mimeType;

  String get type => mimeType ?? _mimeFromName(name);
}

Future<PickedFile?> pickFile(UploadKind kind) async => (await pickFiles(kind)).firstOrNull;

Future<List<PickedFile>> pickFiles(UploadKind kind, {bool multiple = false}) async {
  final result = await FilePicker.pickFiles(
    type: kind == UploadKind.image ? FileType.image : FileType.custom,
    allowedExtensions: switch (kind) {
      UploadKind.image => null,
      UploadKind.document => const ['pdf', 'png', 'jpg', 'jpeg', 'webp', 'gif'],
      UploadKind.media => const ['pdf', 'png', 'jpg', 'jpeg', 'webp', 'gif', 'mp4', 'webm', 'mov'],
    },
    allowMultiple: multiple,
    withData: true,
  );
  return [
    for (final f in result?.files ?? const <PlatformFile>[])
      if (f.bytes != null) PickedFile(name: f.name, bytes: f.bytes!),
  ];
}

const _maxMb = 10;

/// Same checks as useUpload() in apps/web. Throws [ApiError] with a readable message.
Future<String> uploadFile(ApiClient api, PickedFile file, [UploadKind kind = UploadKind.image]) async {
  final type = file.type;
  final image = type.startsWith('image/');
  final ok = switch (kind) {
    UploadKind.image => image,
    UploadKind.document => image || type == 'application/pdf',
    UploadKind.media => image || type.startsWith('video/') || type == 'application/pdf',
  };
  if (!ok) {
    throw ApiError(0, kind == UploadKind.image ? 'Choose an image file (PNG, JPG, WEBP or GIF).' : 'Choose a PDF or image file.');
  }
  if (file.bytes.length > _maxMb * 1024 * 1024 && kind != UploadKind.media) {
    throw ApiError(0, 'Files must be ${_maxMb}MB or smaller.');
  }

  final form = FormData.fromMap({'file': MultipartFile.fromBytes(file.bytes, filename: file.name, contentType: DioMediaType.parse(type))});
  final res = await api.post<Map<String, dynamic>>('/uploads', form);
  return res['url'] as String;
}

String _mimeFromName(String name) {
  final ext = name.split('.').last.toLowerCase();
  return switch (ext) {
    'png' => 'image/png',
    'jpg' || 'jpeg' => 'image/jpeg',
    'webp' => 'image/webp',
    'gif' => 'image/gif',
    'svg' => 'image/svg+xml',
    'pdf' => 'application/pdf',
    'mp4' => 'video/mp4',
    'webm' => 'video/webm',
    'mov' => 'video/quicktime',
    _ => 'application/octet-stream',
  };
}
