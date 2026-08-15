import 'dart:convert';
import 'dart:io';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:path_provider/path_provider.dart';
import 'google_drive_service.dart';

class BackupService {
  BackupService({FirebaseFirestore? firestore})
    : _db = firestore ?? FirebaseFirestore.instance;

  final FirebaseFirestore _db;
  final GoogleDriveService _drive = GoogleDriveService();

  Future<List<DriveBackupFile>> listBackups() => _drive.listBackups();

  Future<String> exportToDrive(String userId) async {
    final collections = <String>['vehicles', 'expenses', 'reminders'];
    final data = <String, dynamic>{
      'version': 1,
      'exportedAt': DateTime.now().toIso8601String(),
      'userId': userId,
    };
    for (final collection in collections) {
      final snapshot = await _db
          .collection(collection)
          .where('userId', isEqualTo: userId)
          .get();
      data[collection] = snapshot.docs
          .map(
            (document) => <String, dynamic>{
              'id': document.id,
              'data': _jsonSafe(document.data()),
            },
          )
          .toList();
    }
    final directory = await getTemporaryDirectory();
    final stamp = DateTime.now().toIso8601String().replaceAll(':', '-');
    final backupName = '${GoogleDriveService.backupPrefix}$stamp.json';
    final file = File('${directory.path}/$backupName');
    await file.writeAsString(jsonEncode(data), flush: true);
    return _drive.upload(
      localPath: file.path,
      name: backupName,
      mimeType: 'application/json',
    );
  }

  Future<void> importFromDrive({
    required String userId,
    required String driveFileId,
  }) async {
    final directory = await getTemporaryDirectory();
    final file = File('${directory.path}/arac_gider_geri_yukle.json');
    await _drive.download(driveFileId, file.path);
    final backup =
        jsonDecode(await file.readAsString()) as Map<String, dynamic>;
    if (backup['userId'] != userId) {
      throw StateError('Bu yedek farklı bir kullanıcıya ait.');
    }
    for (final collection in <String>['vehicles', 'expenses', 'reminders']) {
      final records = (backup[collection] as List<dynamic>? ?? const []);
      for (final record in records.cast<Map<String, dynamic>>()) {
        final raw =
            _restoreTypes(Map<String, dynamic>.from(record['data'] as Map))
                as Map<String, dynamic>;
        raw['userId'] = userId;
        raw['restoredAt'] = FieldValue.serverTimestamp();
        await _db
            .collection(collection)
            .doc(record['id'] as String)
            .set(raw, SetOptions(merge: true));
      }
    }
  }

  dynamic _restoreTypes(dynamic value) {
    if (value is String) {
      final parsed = DateTime.tryParse(value);
      if (parsed != null && value.contains('T')) {
        return Timestamp.fromDate(parsed);
      }
      return value;
    }
    if (value is Map) {
      return value.map(
        (key, item) => MapEntry(key.toString(), _restoreTypes(item)),
      );
    }
    if (value is Iterable) return value.map(_restoreTypes).toList();
    return value;
  }

  dynamic _jsonSafe(dynamic value) {
    if (value is Timestamp) return value.toDate().toIso8601String();
    if (value is Map) {
      return value.map(
        (key, item) => MapEntry(key.toString(), _jsonSafe(item)),
      );
    }
    if (value is Iterable) return value.map(_jsonSafe).toList();
    return value;
  }
}
