import 'dart:io';
import 'package:image/image.dart' as img;

void main() async {
  // Read the original logo
  final logoFile = File('assets/images/Logo/Power CA Logo Only-04.png');
  final logoBytes = await logoFile.readAsBytes();
  final logo = img.decodeImage(logoBytes);

  if (logo == null) {
    print('Failed to decode logo image');
    return;
  }

  // Create a 1024x1024 canvas with white background for the main icon
  final mainIcon = img.Image(width: 1024, height: 1024);
  img.fill(mainIcon, color: img.ColorRgba8(255, 255, 255, 255));

  // Resize logo to fit with padding (70% of canvas size)
  final logoSize = (1024 * 0.70).toInt();
  final resizedLogo = img.copyResize(logo, width: logoSize, height: logoSize);

  // Center the logo
  final offsetX = (1024 - logoSize) ~/ 2;
  final offsetY = (1024 - logoSize) ~/ 2;

  img.compositeImage(mainIcon, resizedLogo, dstX: offsetX, dstY: offsetY);

  // Save the padded icon
  final outputFile = File('assets/images/Logo/power_ca_icon_padded.png');
  await outputFile.writeAsBytes(img.encodePng(mainIcon));

  print('Created padded icon: ${outputFile.path}');

  // Create adaptive foreground (432x432 with logo at ~65% for safe zone)
  final adaptiveIcon = img.Image(width: 432, height: 432);
  img.fill(adaptiveIcon, color: img.ColorRgba8(255, 255, 255, 0)); // Transparent

  final adaptiveLogoSize = (432 * 0.65).toInt();
  final adaptiveResizedLogo = img.copyResize(logo, width: adaptiveLogoSize, height: adaptiveLogoSize);

  final adaptiveOffsetX = (432 - adaptiveLogoSize) ~/ 2;
  final adaptiveOffsetY = (432 - adaptiveLogoSize) ~/ 2;

  img.compositeImage(adaptiveIcon, adaptiveResizedLogo, dstX: adaptiveOffsetX, dstY: adaptiveOffsetY);

  final adaptiveFile = File('assets/images/Logo/power_ca_adaptive_foreground.png');
  await adaptiveFile.writeAsBytes(img.encodePng(adaptiveIcon));

  print('Created adaptive foreground: ${adaptiveFile.path}');
}
