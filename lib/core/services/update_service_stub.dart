import 'package:open_file/open_file.dart';
import 'package:package_info_plus/package_info_plus.dart';

import 'package:game_forge/core/services/update_models.dart';

/// Web / non-IO fallback — no remote update checks.
class UpdateService {
  UpdateService._();
  static final UpdateService instance = UpdateService._();

  static int compareSemver(String a, String b) {
    List<int> parts(String v) {
      return v
          .trim()
          .split('.')
          .map((e) => int.tryParse(e.trim()) ?? 0)
          .toList();
    }

    final pa = parts(a);
    final pb = parts(b);
    final len = pa.length > pb.length ? pa.length : pb.length;
    for (var i = 0; i < len; i++) {
      final x = i < pa.length ? pa[i] : 0;
      final y = i < pb.length ? pb[i] : 0;
      if (x != y) return x.compareTo(y);
    }
    return 0;
  }

  Future<UpdateInfo> checkForUpdate() async {
    final v = (await PackageInfo.fromPlatform()).version;
    return UpdateInfo.none(v);
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
