/// Result of comparing [version.json] with the installed app.
class UpdateInfo {
  final bool hasUpdate;
  final bool isForced;
  final String currentVersion;
  final String remoteVersion;
  final String downloadUrl;
  final String changelog;

  const UpdateInfo({
    required this.hasUpdate,
    required this.isForced,
    required this.currentVersion,
    required this.remoteVersion,
    required this.downloadUrl,
    required this.changelog,
  });

  static UpdateInfo none(String current) => UpdateInfo(
        hasUpdate: false,
        isForced: false,
        currentVersion: current,
        remoteVersion: current,
        downloadUrl: '',
        changelog: '',
      );
}
