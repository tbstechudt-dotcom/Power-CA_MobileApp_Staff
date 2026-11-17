import 'package:flutter/material.dart';

import '../../app/theme.dart';
import 'soft_page.dart';

/// Custom Button Widget
/// Consistent soft (stadium) button styling across the app
class CustomButton extends StatelessWidget {
  final String text;
  final VoidCallback? onPressed;
  final bool isLoading;
  final bool isOutlined;
  final IconData? icon;
  final Color? backgroundColor;
  final Color? textColor;
  final double? width;
  final double height;
  final EdgeInsetsGeometry? padding;

  const CustomButton({
    super.key,
    required this.text,
    this.onPressed,
    this.isLoading = false,
    this.isOutlined = false,
    this.icon,
    this.backgroundColor,
    this.textColor,
    this.width,
    this.height = 52,
    this.padding,
  });

  @override
  Widget build(BuildContext context) {
    final p = SoftPalette.of(context);
    final enabled = onPressed != null && !isLoading;
    final bg = backgroundColor ?? (isOutlined ? p.surface : p.pill);
    final fg = textColor ?? (isOutlined ? p.ink : p.onPill);
    final side = isOutlined ? BorderSide(color: p.border) : BorderSide.none;

    return SizedBox(
      width: width ?? double.infinity,
      height: height,
      child: Opacity(
        opacity: enabled || isLoading ? 1 : 0.45,
        child: Material(
          color: bg,
          shape: StadiumBorder(side: side),
          child: InkWell(
            customBorder: const StadiumBorder(),
            onTap: enabled ? onPressed : null,
            child: Padding(
              padding: padding ?? const EdgeInsets.symmetric(horizontal: 22),
              child: Center(child: _buildChild(fg)),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildChild(Color fg) {
    if (isLoading) {
      return SizedBox(
        height: 20,
        width: 20,
        child: CircularProgressIndicator(
          strokeWidth: 2.2,
          valueColor: AlwaysStoppedAnimation<Color>(fg),
        ),
      );
    }

    final label = Text(
      text,
      maxLines: 1,
      overflow: TextOverflow.ellipsis,
      style: TextStyle(
        fontFamily: AppTheme.fontFamily,
        fontSize: 15,
        fontWeight: FontWeight.w600,
        color: fg,
      ),
    );

    if (icon != null) {
      return Row(
        mainAxisSize: MainAxisSize.min,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(icon, size: 18, color: fg),
          const SizedBox(width: 8),
          Flexible(child: label),
        ],
      );
    }

    return label;
  }
}
