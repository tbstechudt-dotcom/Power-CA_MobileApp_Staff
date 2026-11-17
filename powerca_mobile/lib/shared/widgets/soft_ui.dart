import 'package:flutter/material.dart';

import '../../app/theme.dart';
import 'soft_page.dart';

/// Soft UI form kit: input decoration and field labels.

/// Fill color of [filled] form fields (grey well inside white cards).
Color softFieldFill(SoftPalette p) => p.isDark ? p.surfaceAlt : const Color(0xFFF1F3F6);

/// Input decoration for soft forms. Use with TextField / TextFormField /
/// DropdownButtonFormField:
///
/// ```dart
/// TextFormField(decoration: softInputDecoration(context, hint: 'Notes'))
/// ```
///
/// [filled] draws a borderless grey field (for forms laid out in white
/// cards); it gets a blue border while focused.
///
/// [pill] gives a fully rounded (stadium) field. All search fields use it.
InputDecoration softInputDecoration(
  BuildContext context, {
  String? hint,
  IconData? icon,
  Widget? suffix,
  String? prefixText,
  String? errorText,
  String? counterText,
  bool dense = false,
  bool filled = false,
  bool pill = false,
}) {
  final p = SoftPalette.of(context);
  final radius = pill ? 999.0 : (filled ? 14.0 : 16.0);
  OutlineInputBorder border(Color c, [double w = 1]) => OutlineInputBorder(
        borderRadius: BorderRadius.circular(radius),
        borderSide: BorderSide(color: c, width: w),
      );
  final none = OutlineInputBorder(
    borderRadius: BorderRadius.circular(radius),
    borderSide: BorderSide.none,
  );
  return InputDecoration(
    hintText: hint,
    hintStyle: SoftText.body(p, color: p.muted),
    // A text prefix (e.g. "+91") is drawn with a hairline divider after it.
    prefixIcon: prefixText != null
        ? Padding(
            padding: const EdgeInsets.only(left: 16, right: 12),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(prefixText.trim(), style: softInputTextStyle(context)),
                const SizedBox(width: 12),
                Container(width: 1, height: 22, color: p.border),
              ],
            ),
          )
        : (icon == null
            ? null
            : Padding(
                // Keep the icon clear of a pill field's rounded end.
                padding: EdgeInsets.only(left: pill ? 6 : 0),
                child: Icon(icon, size: 20, color: p.muted),
              )),
    prefixIconConstraints:
        prefixText != null ? const BoxConstraints(minWidth: 0, minHeight: 0) : null,
    suffixIcon: suffix,
    errorText: errorText,
    counterText: counterText,
    filled: true,
    fillColor: filled ? softFieldFill(p) : p.surface,
    isDense: dense,
    contentPadding: EdgeInsets.symmetric(horizontal: pill ? 20 : 18, vertical: dense ? 12 : 16),
    border: filled ? none : border(p.border),
    enabledBorder: filled ? none : border(p.border),
    focusedBorder: filled ? border(p.accent, 1.4) : border(p.ink, 1.4),
    errorBorder: border(p.danger),
    focusedErrorBorder: border(p.danger, 1.4),
    disabledBorder: filled ? none : border(p.border.withValues(alpha: 0.6)),
  );
}

/// Text style for values typed into soft inputs.
TextStyle softInputTextStyle(BuildContext context) {
  final p = SoftPalette.of(context);
  return TextStyle(
    fontFamily: AppTheme.fontFamily,
    fontSize: 15,
    fontWeight: FontWeight.w500,
    color: p.ink,
  );
}

/// Small label shown above a form field. [enabled] false fades it to match
/// a disabled field.
class SoftFieldLabel extends StatelessWidget {
  final String text;
  final bool required;
  final String? hint;
  final bool enabled;

  const SoftFieldLabel(
    this.text, {
    super.key,
    this.required = false,
    this.hint,
    this.enabled = true,
  });

  @override
  Widget build(BuildContext context) {
    final p = SoftPalette.of(context);
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        children: [
          Text(
            text,
            style: TextStyle(
              fontFamily: AppTheme.fontFamily,
              fontSize: 13.5,
              fontWeight: FontWeight.w500,
              color: enabled ? p.ink : p.muted,
            ),
          ),
          if (required)
            Text(
              ' *',
              style: TextStyle(
                color: enabled ? p.danger : p.danger.withValues(alpha: 0.6),
                fontWeight: FontWeight.w600,
              ),
            ),
          if (hint != null) ...[
            const Spacer(),
            Text(hint!, style: SoftText.caption(p)),
          ],
        ],
      ),
    );
  }
}

/// Tappable field that looks like an input (date / time / picker triggers).
///
/// [filled] draws the borderless grey style; [enabled] false greys it out
/// and ignores taps; [trailing] false hides the chevron.
class SoftPickerField extends StatelessWidget {
  final String? value;
  final String placeholder;
  final IconData icon;
  final VoidCallback? onTap;
  final bool hasError;
  final bool filled;
  final bool enabled;
  final bool trailing;

  const SoftPickerField({
    super.key,
    required this.value,
    required this.placeholder,
    required this.icon,
    this.onTap,
    this.hasError = false,
    this.filled = false,
    this.enabled = true,
    this.trailing = true,
  });

  @override
  Widget build(BuildContext context) {
    final p = SoftPalette.of(context);
    final empty = value == null || value!.isEmpty;
    final radius = filled ? 14.0 : 16.0;
    final fill =
        filled ? (enabled ? softFieldFill(p) : softFieldFill(p).withValues(alpha: 0.6)) : p.surface;
    final iconColor = enabled ? p.muted : p.muted.withValues(alpha: 0.5);
    return Material(
      color: fill,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(radius),
        side: hasError
            ? BorderSide(color: p.danger)
            : (filled ? BorderSide.none : BorderSide(color: p.border)),
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(radius),
        onTap: enabled ? onTap : null,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 15),
          child: Row(
            children: [
              Icon(icon, size: 20, color: iconColor),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  empty ? placeholder : value!,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: empty
                      ? SoftText.body(p, color: enabled ? p.muted : p.muted.withValues(alpha: 0.6))
                      : softInputTextStyle(context),
                ),
              ),
              if (trailing) Icon(Icons.expand_more_rounded, size: 20, color: iconColor),
            ],
          ),
        ),
      ),
    );
  }
}
