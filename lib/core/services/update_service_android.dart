import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:open_file/open_file.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:path_provider/path_provider.dart';
import 'package:permission_handler/permission_handler.dart';

import 'package:game_forge/core/config/update_config.dart';
import 'package:game_forge/core/services/update_models.dart';

/// Android implementation — fetches [version.json] and manages APK download/install.
class UpdateService {
  UpdateService._();
  static final UpdateService instance = UpdateService._();

  static int compareSemver(String a, String b) {
    return _AppVersion.parse(a).compareTo(_AppVersion.parse(b));
  }

  Future<UpdateInfo> checkForUpdate() async {
    try {
      final pkg = await PackageInfo.fromPlatform();
      final current = '${pkg.version}+${pkg.buildNumber}';

      if (kIsWeb || !Platform.isAndroid) {
        return UpdateInfo.none(current);
      }

      final uri = Uri.parse(UpdateConfig.versionJsonUrl);
      final res = await http.get(uri).timeout(const Duration(seconds: 15));
      if (res.statusCode < 200 || res.statusCode >= 300) {
        return UpdateInfo.none(current);
      }

      final decoded = json.decode(res.body);
      if (decoded is! Map) {
        return UpdateInfo.none(current);
      }

      final remoteVersion = decoded['version']?.toString() ?? '';
      final minVersion = decoded['min_version']?.toString() ?? '0.0.0';
      final downloadUrl = decoded['download_url']?.toString() ?? '';
      final changelog = decoded['changelog']?.toString() ?? '';
      final forceFlag = decoded['force_update'] == true;

      if (remoteVersion.isEmpty || downloadUrl.isEmpty) {
        return UpdateInfo.none(current);
      }

      final belowMin = compareSemver(current, minVersion) < 0;
      final hasUpdate = compareSemver(current, remoteVersion) < 0;
      final isForced = forceFlag || belowMin;

      if (!hasUpdate) {
        return UpdateInfo.none(current);
      }

      return UpdateInfo(
        hasUpdate: true,
        isForced: isForced,
        currentVersion: current,
        remoteVersion: remoteVersion,
        downloadUrl: downloadUrl,
        changelog: changelog,
      );
    } catch (e, st) {
      debugPrint('UpdateService.checkForUpdate failed: $e\n$st');
      return UpdateInfo.none('0.0.0');
    }
  }

  Future<File> _resolveApkDestination() async {
    if (!Platform.isAndroid) {
      final dir = await getTemporaryDirectory();
      return File('${dir.path}/${UpdateConfig.apkFileName}');
    }

    final publicFile =
        File('/storage/emulated/0/Download/${UpdateConfig.apkFileName}');
    try {
      if (await _canUsePublicDownload()) {
        final parent = publicFile.parent;
        if (!await parent.exists()) {
          await parent.create(recursive: true);
        }
        return publicFile;
      }
    } catch (e) {
      debugPrint('Public Download path unavailable: $e');
    }

    final dir = await getTemporaryDirectory();
    return File('${dir.path}/${UpdateConfig.apkFileName}');
  }

  Future<bool> _canUsePublicDownload() async {
    if (!Platform.isAndroid) return false;
    final status = await Permission.storage.request();
    return status.isGranted || status.isLimited;
  }

  Future<String> downloadApk({
    required String url,
    required void Function(double? progress) onProgress,
  }) async {
    final uri = Uri.parse(url);
    final client = http.Client();
    try {
      final request = http.Request('GET', uri);
      final response =
          await client.send(request).timeout(const Duration(minutes: 30));

      if (response.statusCode < 200 || response.statusCode >= 300) {
        throw HttpException('Download failed: HTTP ${response.statusCode}');
      }

      final dest = await _resolveApkDestination();
      if (await dest.exists()) {
        await dest.delete();
      }
      await dest.parent.create(recursive: true);

      final total = response.contentLength;
      var received = 0;
      final sink = dest.openWrite();

      await for (final chunk in response.stream) {
        sink.add(chunk);
        received += chunk.length;
        if (total != null && total > 0) {
          onProgress((received / total).clamp(0.0, 1.0));
        } else {
          onProgress(null);
        }
      }

      await sink.close();
      onProgress(1.0);
      return dest.path;
    } finally {
      client.close();
    }
  }

  Future<OpenResult> openDownloadedApk(String path) async {
    if (Platform.isAndroid) {
      await Permission.requestInstallPackages.request();
    }
    return OpenFile.open(path);
  }
}

class _AppVersion implements Comparable<_AppVersion> {
  final List<int> semverParts;
  final int buildNumber;

  _AppVersion(this.semverParts, this.buildNumber);

  factory _AppVersion.parse(String v) {
    final clean = v.trim();
    if (clean.isEmpty) {
      return _AppVersion([0, 0, 0], 0);
    }

    final parts = clean.split('+');
    // Strip pre-release tag like -beta from the semver part
    final semverStr = parts[0].split('-').first;
    final buildStr = parts.length > 1 ? parts[1] : '';

    final semverList = semverStr
        .split('.')
        .map((e) => int.tryParse(e.trim()) ?? 0)
        .toList();

    final buildNum = int.tryParse(buildStr.trim()) ?? 0;
    return _AppVersion(semverList, buildNum);
  }

  @override
  int compareTo(_AppVersion other) {
    final len = semverParts.length > other.semverParts.length
        ? semverParts.length
        : other.semverParts.length;

    for (var i = 0; i < len; i++) {
      final x = i < semverParts.length ? semverParts[i] : 0;
      final y = i < other.semverParts.length ? other.semverParts[i] : 0;
      if (x != y) return x.compareTo(y);
    }

    return buildNumber.compareTo(other.buildNumber);
  }
}
