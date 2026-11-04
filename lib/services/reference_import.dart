import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:file_picker/file_picker.dart';

import '../models/reference_image.dart';

/// Wider images are scaled down to this width to keep projects small
/// (they are stored inside the project).
const maxReferenceWidth = 1600;

/// Lets the user pick a picture (e.g. a screenshot of an app to clone)
/// and turns it into a [ReferenceImage]. null when cancelled.
Future<ReferenceImage?> pickReferenceImage() async {
  final file = await FilePicker.pickFile(type: FileType.image);
  if (file == null) return null;
  return referenceFromBytes(await file.readAsBytes());
}

/// Decodes [bytes] (throws if it isn't an image) and downsizes it when
/// it is wider than [maxReferenceWidth].
Future<ReferenceImage> referenceFromBytes(Uint8List bytes) async {
  final codec = await ui.instantiateImageCodec(bytes);
  var image = (await codec.getNextFrame()).image;
  var data = bytes;
  if (image.width > maxReferenceWidth) {
    image.dispose();
    final smaller = await ui.instantiateImageCodec(
      bytes,
      targetWidth: maxReferenceWidth,
    );
    image = (await smaller.getNextFrame()).image;
    final png = await image.toByteData(format: ui.ImageByteFormat.png);
    data = png!.buffer.asUint8List();
  }
  final size = ui.Size(image.width.toDouble(), image.height.toDouble());
  image.dispose();
  return ReferenceImage(bytes: data, pixelSize: size);
}
