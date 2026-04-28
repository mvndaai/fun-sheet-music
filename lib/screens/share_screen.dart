import 'package:flutter/foundation.dart' show defaultTargetPlatform, kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:url_launcher/url_launcher.dart';
import '../config/app_links.dart';
import '../config/app_config.dart';

/// Share / download screen.
///
/// Shows platform-specific QR codes and action buttons so users can:
/// - Download the Android APK for sideloading (or open the Play Store once published).
/// - Open the web version on iOS (or go to the App Store once published).
/// - Share the web URL from inside any platform.
class ShareScreen extends StatelessWidget {
  const ShareScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Get the App'),
      ),
      body: SingleChildScrollView(
        primary: true,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              'Share ${AppConfig.appName}',
              style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 6),
            Text(
              'Scan a QR code or tap a button to get the app on any device.',
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: Colors.grey.shade600,
                  ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 24),

            // Android card
            _PlatformCard(
              platform: _Platform.android,
              url: AppLinks.androidDownloadUrl,
              title: 'Android',
              icon: Icons.android,
              iconColor: const Color(0xFF3DDC84),
              buttonLabel: AppLinks.androidButtonLabel,
              description: AppLinks.androidQrDescription,
              badge: AppLinks.androidOnPlayStore ? null : 'Sideload',
              isCurrentPlatform: !kIsWeb && _isAndroid,
            ),
            const SizedBox(height: 12),

            // iOS card
            _PlatformCard(
              platform: _Platform.ios,
              url: AppLinks.iosDownloadUrl,
              title: 'iPhone / iPad',
              icon: Icons.phone_iphone,
              iconColor: Colors.grey.shade700,
              buttonLabel: AppLinks.iosButtonLabel,
              description: AppLinks.iosQrDescription,
              badge: AppLinks.iosOnAppStore ? null : 'Web',
              isCurrentPlatform: !kIsWeb && _isIOS,
            ),
            const SizedBox(height: 12),

            // Web card
            const _PlatformCard(
              platform: _Platform.web,
              url: AppLinks.webUrl,
              title: 'Web Browser',
              icon: Icons.language,
              iconColor: Colors.blue,
              buttonLabel: 'Open Web Version',
              description: 'Works on any device with a modern browser.\n'
                  'No installation needed.',
              isCurrentPlatform: kIsWeb,
            ),

            const SizedBox(height: 28),
            const Divider(),
            const SizedBox(height: 12),

            // "Open web version" shortcut (only shown on native platforms)
            if (!kIsWeb) ...[
              _OpenWebBanner(),
              const SizedBox(height: 12),
            ],

            // Copy web link
            const _CopyLinkRow(url: AppLinks.webUrl),
          ],
        ),
      ),
    );
  }

  // Platform detection helpers (safe to call even on web because they are
  // always guarded by `!kIsWeb`).
  static bool get _isAndroid =>
      !kIsWeb && defaultTargetPlatform == TargetPlatform.android;

  static bool get _isIOS =>
      !kIsWeb && defaultTargetPlatform == TargetPlatform.iOS;
}

// ── Platform enum ─────────────────────────────────────────────────────────

enum _Platform { android, ios, web }

// ── Platform card ─────────────────────────────────────────────────────────

class _PlatformCard extends StatelessWidget {
  final _Platform platform;
  final String url;
  final String title;
  final IconData icon;
  final Color iconColor;
  final String buttonLabel;
  final String description;
  final String? badge;
  final bool isCurrentPlatform;

  const _PlatformCard({
    required this.platform,
    required this.url,
    required this.title,
    required this.icon,
    required this.iconColor,
    required this.buttonLabel,
    required this.description,
    this.badge,
    this.isCurrentPlatform = false,
  });

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Card(
      elevation: isCurrentPlatform ? 4 : 1,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: isCurrentPlatform
            ? BorderSide(color: colorScheme.primary, width: 2)
            : BorderSide.none,
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header row
            Row(
              children: [
                Icon(icon, color: iconColor, size: 28),
                const SizedBox(width: 10),
                Text(
                  title,
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                ),
                if (isCurrentPlatform) ...[
                  const SizedBox(width: 8),
                  Chip(
                    label: const Text('This device'),
                    padding: EdgeInsets.zero,
                    labelStyle: TextStyle(
                        fontSize: 11, color: colorScheme.onPrimary),
                    backgroundColor: colorScheme.primary,
                    visualDensity: VisualDensity.compact,
                  ),
                ],
                if (badge != null && !isCurrentPlatform) ...[
                  const SizedBox(width: 8),
                  Chip(
                    label: Text(badge!),
                    padding: EdgeInsets.zero,
                    labelStyle: const TextStyle(fontSize: 11),
                    visualDensity: VisualDensity.compact,
                  ),
                ],
              ],
            ),
            const SizedBox(height: 12),

            // QR code + description side-by-side on wide screens
            LayoutBuilder(builder: (context, constraints) {
              final wide = constraints.maxWidth > 400;
              final qr = _QrBox(url: url, size: 140);
              final desc = Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(description,
                      style: const TextStyle(fontSize: 13, height: 1.4)),
                  const SizedBox(height: 12),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton.icon(
                      icon: Icon(_buttonIcon),
                      label: Text(buttonLabel),
                      onPressed: () => _launch(context, url),
                    ),
                  ),
                ],
              );

              if (wide) {
                return Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    qr,
                    const SizedBox(width: 16),
                    Expanded(child: desc),
                  ],
                );
              }
              return Column(
                children: [
                  Center(child: qr),
                  const SizedBox(height: 12),
                  desc,
                ],
              );
            }),
          ],
        ),
      ),
    );
  }

  IconData get _buttonIcon {
    switch (platform) {
      case _Platform.android:
        return AppLinks.androidOnPlayStore ? Icons.shop : Icons.download;
      case _Platform.ios:
        return AppLinks.iosOnAppStore ? Icons.apple : Icons.language;
      case _Platform.web:
        return Icons.open_in_browser;
    }
  }

  Future<void> _launch(BuildContext context, String url) async {
    final uri = Uri.parse(url);
    if (!await launchUrl(uri, mode: LaunchMode.externalApplication)) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Could not open: $url')),
        );
      }
    }
  }
}

// ── QR box ────────────────────────────────────────────────────────────────

class _QrBox extends StatelessWidget {
  final String url;
  final double size;

  const _QrBox({required this.url, this.size = 140});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      padding: const EdgeInsets.all(6),
      decoration: BoxDecoration(
        color: Colors.white, // always white for QR readability
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.grey.shade300),
      ),
      child: QrImageView(
        data: url,
        version: QrVersions.auto,
        eyeStyle: const QrEyeStyle(
          eyeShape: QrEyeShape.square,
          color: Colors.black, // always black for QR readability
        ),
        dataModuleStyle: const QrDataModuleStyle(
          dataModuleShape: QrDataModuleShape.square,
          color: Colors.black,
        ),
      ),
    );
  }
}

// ── "Open web version" banner for native platforms ────────────────────────

class _OpenWebBanner extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Card(
      color: Theme.of(context).colorScheme.primaryContainer,
      child: ListTile(
        leading: Icon(
          Icons.open_in_browser,
          color: Theme.of(context).colorScheme.onPrimaryContainer,
        ),
        title: Text(
          'Open Web Version',
          style: TextStyle(
            fontWeight: FontWeight.w600,
            color: Theme.of(context).colorScheme.onPrimaryContainer,
          ),
        ),
        subtitle: Text(
          AppLinks.webUrl,
          style: TextStyle(
            fontSize: 12,
            color: Theme.of(context).colorScheme.onPrimaryContainer.withValues(alpha: 0.8),
          ),
          overflow: TextOverflow.ellipsis,
        ),
        trailing: Icon(
          Icons.arrow_forward_ios,
          size: 16,
          color: Theme.of(context).colorScheme.onPrimaryContainer,
        ),
        onTap: () async {
          final uri = Uri.parse(AppLinks.webUrl);
          if (!await launchUrl(uri, mode: LaunchMode.externalApplication)) {
            if (context.mounted) {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Could not open web version')),
              );
            }
          }
        },
      ),
    );
  }
}

// ── Copy link row ─────────────────────────────────────────────────────────

class _CopyLinkRow extends StatelessWidget {
  final String url;
  const _CopyLinkRow({required this.url});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.surfaceContainerHighest,
              borderRadius: BorderRadius.circular(8),
            ),
            child: Text(
              url,
              style: const TextStyle(fontSize: 13),
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ),
        const SizedBox(width: 8),
        IconButton.filled(
          icon: const Icon(Icons.copy, size: 18),
          tooltip: 'Copy link',
          onPressed: () {
            Clipboard.setData(ClipboardData(text: url));
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('Link copied to clipboard'),
                duration: Duration(seconds: 2),
              ),
            );
          },
        ),
      ],
    );
  }
}
