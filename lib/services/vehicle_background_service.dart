import 'dart:io';
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:image/image.dart' as img;
import 'package:image_background_remover/image_background_remover.dart';
import 'package:path/path.dart' as path;
import 'package:path_provider/path_provider.dart';

class VehicleBackgroundService {
  VehicleBackgroundService._();
  static final VehicleBackgroundService instance = VehicleBackgroundService._();

  bool _initialized = false;

  Future<void> initialize() async {
    if (_initialized) return;
    await BackgroundRemover.instance.initializeOrt();
    _initialized = true;
  }

  Future<String> removeBackground(String originalPath) async {
    await initialize();
    final original = File(originalPath);
    if (!await original.exists()) {
      throw StateError('Araç fotoğrafı bulunamadı.');
    }

    final Uint8List input = await original.readAsBytes();
    final ui.Image result = await BackgroundRemover.instance.removeBg(input);
    final ByteData? png = await result.toByteData(
      format: ui.ImageByteFormat.png,
    );
    if (png == null) {
      throw StateError('Şeffaf PNG oluşturulamadı.');
    }

    final normalized = _normalizeTransparentVehicle(png.buffer.asUint8List());
    final appDirectory = await getApplicationDocumentsDirectory();
    final directory = Directory(
      path.join(appDirectory.path, 'vehicle_stickers'),
    );
    await directory.create(recursive: true);
    final target = path.join(
      directory.path,
      'vehicle_sticker_${DateTime.now().microsecondsSinceEpoch}.png',
    );
    await File(target).writeAsBytes(normalized, flush: true);
    return target;
  }

  Uint8List _normalizeTransparentVehicle(Uint8List bytes) {
    final source = img.decodePng(bytes);
    if (source == null) return bytes;

    var minX = source.width;
    var minY = source.height;
    var maxX = -1;
    var maxY = -1;

    // Çok düşük alfa değerleri model artığı olabileceğinden içerik sayılmaz.
    const alphaThreshold = 12;
    for (var y = 0; y < source.height; y++) {
      for (var x = 0; x < source.width; x++) {
        if (source.getPixel(x, y).a > alphaThreshold) {
          if (x < minX) minX = x;
          if (y < minY) minY = y;
          if (x > maxX) maxX = x;
          if (y > maxY) maxY = y;
        }
      }
    }

    if (maxX < minX || maxY < minY) return bytes;
    final cropped = img.copyCrop(
      source,
      x: minX,
      y: minY,
      width: maxX - minX + 1,
      height: maxY - minY + 1,
    );

    const canvasWidth = 1200;
    const canvasHeight = 700;
    const maxVehicleWidth = 1080;
    const maxVehicleHeight = 560;
    final scale = [
      maxVehicleWidth / cropped.width,
      maxVehicleHeight / cropped.height,
    ].reduce((a, b) => a < b ? a : b);
    final scaledWidth = (cropped.width * scale).round();
    final scaledHeight = (cropped.height * scale).round();
    final resized = img.copyResize(
      cropped,
      width: scaledWidth,
      height: scaledHeight,
      interpolation: img.Interpolation.cubic,
    );

    final canvas = img.Image(
      width: canvasWidth,
      height: canvasHeight,
      numChannels: 4,
    );
    img.fill(canvas, color: img.ColorRgba8(0, 0, 0, 0));
    final x = ((canvasWidth - scaledWidth) / 2).round();
    const bottomPadding = 42;
    final y = canvasHeight - bottomPadding - scaledHeight;
    img.compositeImage(canvas, resized, dstX: x, dstY: y);
    return Uint8List.fromList(img.encodePng(canvas, level: 6));
  }
}
