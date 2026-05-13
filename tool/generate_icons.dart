import 'dart:io';
import 'package:image/image.dart' as img;

/// A script to generate app icons and favicons from a single source image.
/// Place your source image at assets/images/icon_source.png before running.
void main() async {
  final sourcePath = 'assets/dev_images/icon_source.png';
  final sourceFile = File(sourcePath);

  if (!sourceFile.existsSync()) {
    print('Error: Source image not found at $sourcePath');
    print('Please save your screenshot to that location and try again.');
    return;
  }

  final bytes = sourceFile.readAsBytesSync();
  img.Image? image = img.decodeImage(bytes);

  if (image == null) {
    print('Error: Could not decode image at $sourcePath');
    return;
  }

  print('Source image loaded: ${image.width}x${image.height}');

  // 1. Crop to square (centered)
  final size = image.width < image.height ? image.width : image.height;
  final x = (image.width - size) ~/ 2;
  final y = (image.height - size) ~/ 2;
  image = img.copyCrop(image, x: x, y: y, width: size, height: size);
  print('Cropped to square: ${image.width}x${image.height}');

  // 2. Define standard icon targets
  final targets = [
    // Web
    (path: 'web/favicon.png', size: 32),
    (path: 'web/icons/favicon.png', size: 32), // Secondary location fallback
    (path: 'web/icons/Icon-192.png', size: 192),
    (path: 'web/icons/Icon-512.png', size: 512),
    (path: 'web/icons/Icon-maskable-192.png', size: 192),
    (path: 'web/icons/Icon-maskable-512.png', size: 512),

    // Android (Standard mipmap sizes)
    (path: 'android/app/src/main/res/mipmap-mdpi/ic_launcher.png', size: 48),
    (path: 'android/app/src/main/res/mipmap-hdpi/ic_launcher.png', size: 72),
    (path: 'android/app/src/main/res/mipmap-xhdpi/ic_launcher.png', size: 96),
    (path: 'android/app/src/main/res/mipmap-xxhdpi/ic_launcher.png', size: 144),
    (path: 'android/app/src/main/res/mipmap-xxxhdpi/ic_launcher.png', size: 192),

    // Play Store / App Store
    (path: 'assets/images/store_icon.png', size: 1024),
  ];

  for (final target in targets) {
    final resized = img.copyResize(image, width: target.size, height: target.size, interpolation: img.Interpolation.linear);
    final outFile = File(target.path);
    if (!outFile.parent.existsSync()) {
      outFile.parent.createSync(recursive: true);
    }
    outFile.writeAsBytesSync(img.encodePng(resized));
    print('Generated: ${target.path} (${target.size}x${target.size})');
  }

  print('\nSuccess! App icons and favicon have been generated.');
  print('Note: iOS icons usually require updating Runner.xcassets via Xcode or flutter_launcher_icons for best results.');
}
