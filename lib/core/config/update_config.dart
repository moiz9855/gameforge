/// Raw URL to [version.json] on GitHub (or any static host).
///
/// Replace `YOUR_USERNAME` / `gameforge` / branch with your repo details.
/// Example:
/// `https://raw.githubusercontent.com/myorg/gameforge/main/version.json`
class UpdateConfig {
  UpdateConfig._();

  static const String versionJsonUrl =
      'https://raw.githubusercontent.com/moiz9855/gameforge/main/version.json';

  /// APK filename when saving to the public Download folder (Android).
  static const String apkFileName = 'gameforge.apk';
}
