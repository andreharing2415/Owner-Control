import "dart:typed_data";

class PickedFile {
  final String name;
  final Uint8List bytes;
  PickedFile({required this.name, required this.bytes});
}

Future<PickedFile?> pickPdfFile() async {
  throw UnsupportedError("Web file picker is not available on this platform.");
}
