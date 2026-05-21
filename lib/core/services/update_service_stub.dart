import 'package:open_file/open_file.dart';
import 'package:package_info_plus/package_info_plus.dart';

import 'package:game_forge/core/services/update_models.dart';

/// Web / non-IO fallback — no remote update checks.
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
      return UpdateInfo.none(current);
    } catch (_) {
      return UpdateInfo.none('0.0.0');
    }
  }

  Future<String> downloadApk({
    required String url,
    required void Function(double? progress) onProgress,
  }) async {
    throw UnsupportedError(
      'In-app APK updates are only supported on Android.',
    );
  }

  Future<OpenResult> openDownloadedApk(String path) async {
    throw UnsupportedError(
      'In-app APK updates are only supported on Android.',
    );
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
