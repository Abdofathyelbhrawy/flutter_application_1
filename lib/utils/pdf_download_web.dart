// utils/pdf_download_web.dart
// Web-only: triggers a browser download of a PDF file
// ignore: avoid_web_libraries_in_flutter
import 'dart:js_interop';
import 'dart:typed_data';
import 'package:web/web.dart' as web;

void downloadPdfWeb(Uint8List bytes, String filename) {
  // Create a Blob from the PDF bytes
  final jsArray = bytes.toJS;
  final parts = [jsArray].toJS;
  final blob = web.Blob(parts, web.BlobPropertyBag(type: 'application/pdf'));

  // Create a download URL
  final url = web.URL.createObjectURL(blob);

  // Create a temporary link and trigger download
  final anchor = web.document.createElement('a') as web.HTMLAnchorElement;
  anchor.href = url;
  anchor.download = filename;
  anchor.style.display = 'none';
  web.document.body?.appendChild(anchor);
  anchor.click();

  // Clean up
  web.document.body?.removeChild(anchor);
  web.URL.revokeObjectURL(url);
}
