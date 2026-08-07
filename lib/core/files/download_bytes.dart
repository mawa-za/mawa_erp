import 'dart:typed_data';

import 'download_bytes_stub.dart'
    if (dart.library.html) 'download_bytes_web.dart' as implementation;

Future<void> downloadBytes({
  required Uint8List bytes,
  required String fileName,
  String mimeType = 'application/octet-stream',
}) =>
    implementation.downloadBytes(
      bytes: bytes,
      fileName: fileName,
      mimeType: mimeType,
    );
