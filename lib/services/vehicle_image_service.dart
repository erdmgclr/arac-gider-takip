import 'dart:io';

import 'package:image_picker/image_picker.dart';
import 'package:path/path.dart' as path;
import 'package:path_provider/path_provider.dart';

import '../models/vehicle.dart';
import 'google_drive_service.dart';

class RestoredVehicleImages {
  const RestoredVehicleImages({this.originalPath, this.stickerPath});
  final String? originalPath;
  final String? stickerPath;
  bool get hasChanges => originalPath != null || stickerPath != null;
}

class VehicleImageService {
  final ImagePicker _picker = ImagePicker();
  final GoogleDriveService _drive = GoogleDriveService();
  static final Map<String, Future<RestoredVehicleImages>> _pendingRestores = {};

  Future<String?> pickAndSave(ImageSource source) async {
    final image = await _picker.pickImage(
      source: source,
      imageQuality: 85,
      maxWidth: 1920,
    );
    if (image == null) return null;
    final directory = await _imageDirectory();
    final extension = path.extension(image.path).isEmpty
        ? '.jpg'
        : path.extension(image.path).toLowerCase();
    final destination = path.join(
      directory.path,
      'vehicle_${DateTime.now().microsecondsSinceEpoch}$extension',
    );
    await File(image.path).copy(destination);
    return destination;
  }

  Future<String> uploadToDrive({
    required String localPath,
    required String userId,
  }) {
    final extension = path.extension(localPath).toLowerCase();
    return _drive.upload(
      localPath: localPath,
      name:
          'vehicle_${userId}_${DateTime.now().microsecondsSinceEpoch}$extension',
      mimeType: extension == '.png' ? 'image/png' : 'image/jpeg',
    );
  }

  Future<RestoredVehicleImages> restoreMissingImages(Vehicle vehicle) {
    final active = _pendingRestores[vehicle.id];
    if (active != null) return active;
    final future = _restoreMissingImages(vehicle);
    _pendingRestores[vehicle.id] = future;
    return future.whenComplete(() => _pendingRestores.remove(vehicle.id));
  }

  Future<RestoredVehicleImages> _restoreMissingImages(Vehicle vehicle) async {
    String? originalPath;
    String? stickerPath;
    final localStickerExists =
        vehicle.localStickerPath != null &&
        await File(vehicle.localStickerPath!).exists();
    final localOriginalExists =
        vehicle.localImagePath != null &&
        await File(vehicle.localImagePath!).exists();
    final directory = await _imageDirectory();

    if (!localStickerExists &&
        vehicle.stickerImageDriveId?.isNotEmpty == true) {
      stickerPath = path.join(
        directory.path,
        'vehicle_${vehicle.id}_sticker.png',
      );
      await _drive.download(vehicle.stickerImageDriveId!, stickerPath);
    }
    if (!localOriginalExists &&
        vehicle.originalImageDriveId?.isNotEmpty == true) {
      originalPath = path.join(
        directory.path,
        'vehicle_${vehicle.id}_original.jpg',
      );
      await _drive.download(vehicle.originalImageDriveId!, originalPath);
    }
    return RestoredVehicleImages(
      originalPath: originalPath,
      stickerPath: stickerPath,
    );
  }

  Future<String> restoreFromDrive({
    required String driveFileId,
    required String vehicleId,
  }) async {
    final directory = await _imageDirectory();
    final destination = path.join(
      directory.path,
      'vehicle_${vehicleId}_original.jpg',
    );
    await _drive.download(driveFileId, destination);
    return destination;
  }

  Future<Directory> _imageDirectory() async {
    final appDirectory = await getApplicationDocumentsDirectory();
    final directory = Directory(path.join(appDirectory.path, 'vehicle_images'));
    await directory.create(recursive: true);
    return directory;
  }
}
