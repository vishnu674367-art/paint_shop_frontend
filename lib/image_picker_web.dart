// ignore_for_file: avoid_web_libraries_in_flutter, deprecated_member_use
import 'dart:async';
import 'dart:html' as html;

Future<String?> pickProductImageAsDataUrl() async {
  final completer = Completer<String?>();
  final input = html.FileUploadInputElement()..accept = 'image/*';
  input.click();

  input.onChange.listen((event) {
    final files = input.files;
    if (files == null || files.isEmpty) {
      if (!completer.isCompleted) completer.complete(null);
      return;
    }
    final file = files[0];
    final reader = html.FileReader();
    reader.readAsDataUrl(file);
    reader.onLoadEnd.listen((event) {
      if (!completer.isCompleted) {
        completer.complete(reader.result as String?);
      }
    });
    reader.onError.listen((event) {
      if (!completer.isCompleted) completer.complete(null);
    });
  });

  return completer.future;
}
