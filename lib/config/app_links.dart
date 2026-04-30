/// Central location for all external URLs used by the app.
///
/// **Update these constants before deploying:**
/// 1. Set [webUrl] to your hosted web-app URL.
/// 2. Set [androidApkUrl] to the hosted release APK URL for sideloading.
/// 3. When you publish to the Play Store, set [playStoreUrl] and flip
///    [androidOnPlayStore] to `true` – the Android QR code will then point
///    there automatically.
/// 4. When you publish to the App Store, set [appStoreUrl] and flip
///    [iosOnAppStore] to `true`.
class AppLinks {
  AppLinks._();

  // ── Web ───────────────────────────────────────────────────────────────────

  /// Public URL of the hosted web version.
  static const String webUrl = 'https://funsheetmusic.com/';

  // ── Android ───────────────────────────────────────────────────────────────

  /// Direct APK download URL for Android sideloading.
  ///
  /// This URL is served by the GitHub Release named "latest" which is
  /// automatically created (or updated) by the `Build Android` CI workflow
  /// on every merge to `main`.  The APK is signed with the debug key and
  /// is suitable for personal use / sideloading.
  ///
  // repository path if you fork or rename the repo.
  ///
  /// Once you publish to the Play Store, set [androidOnPlayStore] to `true`
  /// and update [playStoreUrl] — the QR code will switch automatically.
  static const String androidApkUrl =
      'https://github.com/mvndaai/flutter-music/releases/latest/download/flutter-music.apk';

  /// Google Play Store listing URL.
  /// Update when the app is published.
  static const String playStoreUrl =
      'https://play.google.com/store/apps/details?id=com.example.fun_sheet_music';

  /// Set to `true` once the app is live on the Play Store.
  static const bool androidOnPlayStore = false;

  // ── iOS ───────────────────────────────────────────────────────────────────

  /// Apple App Store listing URL.
  /// Update when the app is published (replace the placeholder ID).
  static const String appStoreUrl =
      'https://apps.apple.com/app/flutter-music/id0000000000';

  /// Set to `true` once the app is live on the App Store.
  static const bool iosOnAppStore = false;

  // ── Computed helpers ──────────────────────────────────────────────────────

  /// URL that the Android QR code / button should target.
  /// Points to [playStoreUrl] when published, otherwise [androidApkUrl].
  static String get androidDownloadUrl =>
      androidOnPlayStore ? playStoreUrl : androidApkUrl;

  /// URL that the iOS QR code / button should target.
  /// Points to [appStoreUrl] when published, otherwise the [webUrl].
  static String get iosDownloadUrl =>
      iosOnAppStore ? appStoreUrl : webUrl;

  /// Label shown on the Android download button.
  static String get androidButtonLabel =>
      androidOnPlayStore ? 'Open in Play Store' : 'Download APK';

  /// Label shown on the iOS button.
  static String get iosButtonLabel =>
      iosOnAppStore ? 'Open in App Store' : 'Open Web Version';

  /// Description shown under the Android QR code.
  static String get androidQrDescription => androidOnPlayStore
      ? 'Scan to open the Play Store listing.'
      : 'Scan to download the Android APK for sideloading.\n'
          'Enable "Install unknown apps" in Android settings first.';

  /// Description shown under the iOS QR code.
  static String get iosQrDescription => iosOnAppStore
      ? 'Scan to open the App Store listing.'
      : 'Scan to open the web version on your iPhone or iPad.\n'
          'App Store release coming soon.';
}
