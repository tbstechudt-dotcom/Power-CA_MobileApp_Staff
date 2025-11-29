import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:flutter_svg/flutter_svg.dart';

/// PowerCA Logo Widget
///
/// Displays the official PowerCA logo from Figma design.
/// The logo features the "CA" branding with white and green accent colors.
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
    return SvgPicture.asset(
      'assets/images/splash/powerca_logo.svg',
      width: width,
      height: height,
      colorFilter: color != null
          ? ColorFilter.mode(color!, BlendMode.srcIn)
          : null,
      fit: BoxFit.contain,
    );
  }
}
