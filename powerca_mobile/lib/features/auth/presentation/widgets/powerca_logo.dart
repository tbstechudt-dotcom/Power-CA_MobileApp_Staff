import 'package:flutter/material.dart';

/// PowerCA Logo Widget
///
/// Displays the official PowerCA logo.
/// The logo features the "CA" branding with white background.
class PowerCALogo extends StatelessWidget {
  final double width;
  final double height;
  final Color? color;

  const PowerCALogo({
    super.key,
    required this.width,
    required this.height,
    this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Image.asset(
      'assets/images/Logo/Power CA Logo Only-04.png',
      width: width,
      height: height,
      fit: BoxFit.contain,
    );
  }
}
