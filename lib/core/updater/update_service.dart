// lib/core/updater/update_service.dart

import 'dart:io';
import 'package:dio/dio.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:path_provider/path_provider.dart';
import 'package:open_filex/open_filex.dart';
import 'package:permission_handler/permission_handler.dart';
import '../database/database_helper.dart';

class UpdateInfo {
  final bool hasUpdate;
  final String latestVersion;
  final String changelog;
  final String downloadUrl;

  UpdateInfo({
    required this.hasUpdate,
    required this.latestVersion,
    required this.changelog,
    required this.downloadUrl,
  });
}

class UpdateService {
  static final UpdateService instance = UpdateService._init();
  final Dio _dio = Dio(BaseOptions(followRedirects: true, maxRedirects: 5));

  UpdateService._init();

  Future<UpdateInfo> checkForUpdate() async {
    final db = await DatabaseHelper.instance.database;
    final profiles = await db.query('profile', limit: 1);
    if (profiles.isEmpty) throw Exception("Profil introuvable");

    final url = profiles.first['sheets_web_app_url'] as String;
    if (url.isEmpty) throw Exception("URL Google Sheets non configurée");

    final packageInfo = await PackageInfo.fromPlatform();
    final currentCode = int.tryParse(packageInfo.buildNumber) ?? 1;

    final response = await _dio.get('$url?action=CHECK_UPDATE');
    if (response.statusCode == 200) {
      final data = response.data;
      final serverCode = data['version_code'] as int;
      final versionName = data['version_name'] as String;
      final downloadUrl = data['apk_url'] as String;
      final changelog = data['changelog'] as String;

      return UpdateInfo(
        hasUpdate: serverCode > currentCode && downloadUrl.isNotEmpty,
        latestVersion: versionName,
        changelog: changelog,
        downloadUrl: downloadUrl,
      );
    }
    return UpdateInfo(hasUpdate: false, latestVersion: '', changelog: '', downloadUrl: '');
  }

  Future<void> downloadAndInstall({
    required String downloadUrl,
    required Function(double progress) onProgress,
  }) async {
    if (Platform.isAndroid) {
      final status = await Permission.requestInstallPackages.status;
      if (status.isDenied) {
        await Permission.requestInstallPackages.request();
      }
    }

    final dir = await getExternalStorageDirectory() ?? await getTemporaryDirectory();
    final savePath = '${dir.path}/teachpoint_update.apk';

    final file = File(savePath);
    if (await file.exists()) {
      await file.delete();
    }

    await _dio.download(
      downloadUrl,
      savePath,
      onReceiveProgress: (received, total) {
        if (total != -1) {
          onProgress(received / total);
        }
      },
    );

    final result = await OpenFilex.open(savePath, type: 'application/vnd.android.package-archive');
    if (result.type != ResultType.done) {
      throw Exception("Erreur de lancement de l'installeur : ${result.message}");
    }
  }
}