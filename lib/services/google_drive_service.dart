import 'dart:io';

import 'package:google_sign_in/google_sign_in.dart';
import 'package:googleapis/drive/v3.dart' as drive;
import 'package:http/http.dart' as http;

class DriveBackupFile {
  const DriveBackupFile({
    required this.id,
    required this.name,
    this.createdTime,
    this.modifiedTime,
    this.size,
  });

  final String id;
  final String name;
  final DateTime? createdTime;
  final DateTime? modifiedTime;
  final int? size;
}

class GoogleDriveService {
  static const scope = 'https://www.googleapis.com/auth/drive.appdata';
  static const backupPrefix = 'arac_gider_yedek_';

  static GoogleSignInAccount? _cachedAccount;
  static GoogleSignInClientAuthorization? _cachedAuthorization;
  static Future<drive.DriveApi>? _pendingApi;

  static void cacheAccount(GoogleSignInAccount account) {
    if (_cachedAccount?.id != account.id) {
      _cachedAuthorization = null;
    }
    _cachedAccount = account;
  }

  static void clearSession() {
    _cachedAccount = null;
    _cachedAuthorization = null;
    _pendingApi = null;
  }

  Future<drive.DriveApi> _api() {
    final active = _pendingApi;
    if (active != null) return active;
    final request = _createApi();
    _pendingApi = request;
    return request.whenComplete(() => _pendingApi = null);
  }

  Future<drive.DriveApi> _createApi() async {
    final signIn = GoogleSignIn.instance;
    var account = _cachedAccount;

    // Uygulama girisinde cacheAccount ile hesap aktarilir. Yalnizca oturum
    // yoksa veya uygulama bagimsiz Drive islemi baslatilmissa hesap sorulur.
    account ??= await signIn.authenticate();
    cacheAccount(account);

    var authorization = _cachedAuthorization;
    authorization ??= await account.authorizationClient.authorizationForScopes(
      const [scope],
    );
    authorization ??= await account.authorizationClient.authorizeScopes(const [
      scope,
    ]);
    _cachedAuthorization = authorization;

    return drive.DriveApi(_AccessTokenClient(authorization.accessToken));
  }

  Future<String> upload({
    required String localPath,
    required String name,
    required String mimeType,
  }) async {
    final file = File(localPath);
    final api = await _api();
    final metadata = drive.File()
      ..name = name
      ..parents = const ['appDataFolder'];
    final media = drive.Media(
      file.openRead(),
      await file.length(),
      contentType: mimeType,
    );
    final result = await api.files.create(
      metadata,
      uploadMedia: media,
      $fields: 'id,name',
    );
    if (result.id == null) throw StateError('Drive dosya kimligi alinamadi.');
    return result.id!;
  }

  Future<List<DriveBackupFile>> listBackups() async {
    final api = await _api();
    final response = await api.files.list(
      spaces: 'appDataFolder',
      q: "name contains '$backupPrefix' and trashed = false",
      orderBy: 'modifiedTime desc',
      $fields: 'files(id,name,createdTime,modifiedTime,size)',
      pageSize: 50,
    );
    return (response.files ?? const <drive.File>[])
        .where((file) => file.id != null && file.name != null)
        .map(
          (file) => DriveBackupFile(
            id: file.id!,
            name: file.name!,
            createdTime: file.createdTime,
            modifiedTime: file.modifiedTime,
            size: int.tryParse(file.size ?? ''),
          ),
        )
        .toList();
  }

  Future<void> delete(String id) async {
    final api = await _api();
    await api.files.delete(id);
  }

  Future<void> download(String id, String targetPath) async {
    final api = await _api();
    final response = await api.files.get(
      id,
      downloadOptions: drive.DownloadOptions.fullMedia,
    );
    if (response is! drive.Media) throw StateError('Dosya indirilemedi.');
    final output = File(targetPath);
    await output.parent.create(recursive: true);
    final sink = output.openWrite();
    await response.stream.pipe(sink);
    await sink.close();
  }
}

class _AccessTokenClient extends http.BaseClient {
  _AccessTokenClient(this.token);
  final String token;
  final http.Client _client = http.Client();

  @override
  Future<http.StreamedResponse> send(http.BaseRequest request) {
    request.headers['Authorization'] = 'Bearer $token';
    return _client.send(request);
  }

  @override
  void close() {
    _client.close();
    super.close();
  }
}
