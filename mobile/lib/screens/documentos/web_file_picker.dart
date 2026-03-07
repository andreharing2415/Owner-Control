import "dart:async";
import "dart:html" as html;
import "dart:typed_data";

class PickedFile {
  final String name;
  final Uint8List bytes;
  PickedFile({required this.name, required this.bytes});
}

Future<PickedFile?> pickPdfFile() async {
  final completer = Completer<PickedFile?>();
  final input = html.FileUploadInputElement()..accept = ".pdf";
  input.click();

  input.onChange.listen((event) {
    final files = input.files;
    if (files == null || files.isEmpty) {
      completer.complete(null);
      return;
    }
    final file = files.first;
    final reader = html.FileReader();
    reader.readAsArrayBuffer(file);
    reader.onLoadEnd.listen((_) {
      final data = reader.result as Uint8List;
      completer.complete(PickedFile(name: file.name, bytes: data));
    });
    reader.onError.listen((_) {
      completer.complete(null);
    });
  });

  // Handle cancel (user closes dialog without selecting)
  // There's no reliable cancel event, so we use a focus listener
  html.document.body?.onFocus.first.then((_) {
    Future.delayed(const Duration(milliseconds: 500), () {
      if (!completer.isCompleted) {
        completer.complete(null);
      }
    });
  });

  return completer.future;
}
