import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'package:supabase_flutter/supabase_flutter.dart';

import '../../app/theme.dart';
import '../../core/config/injection.dart';
import '../../core/services/company_name_cache.dart';
import '../../features/device_security/data/datasources/device_security_local_datasource.dart';
import 'soft_page.dart';

/// Shared layout for the splash, sign-in, workspace, phone and OTP screens.
///
/// A soft blue gradient hero with the Power CA logo fills the top of the
/// screen. A rounded white sheet hugs the bottom and holds, in order:
/// a drag handle, an outlined [icon] badge, the centered [title] and
/// [subtitle] (plus optional [subtitleExtra]), a hairline divider, the
/// screen's [children] and an optional small [note] / [footer].
///
/// The sheet scrolls when its content is taller than the screen (e.g. with
/// the keyboard open); the hero then shrinks and hides the logo.
class AuthSheet extends StatelessWidget {
  final String title;
  final String? subtitle;
  final Widget? subtitleExtra;
  final IconData icon;
  final List<Widget> children;
  final bool showBack;
  final VoidCallback? onBack;
  final Widget? footer;

  /// Small muted line at the bottom of the sheet ("Version 2.0.1").
  final String? note;

  const AuthSheet({
    super.key,
    required this.title,
    required this.children,
    this.icon = Icons.lock_outline_rounded,
    this.subtitle,
    this.subtitleExtra,
    this.showBack = false,
    this.onBack,
    this.footer,
    this.note,
  });

  @override
  Widget build(BuildContext context) {
    final p = SoftPalette.of(context);
    final media = MediaQuery.of(context);

    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle.light.copyWith(
        statusBarColor: Colors.transparent,
        systemNavigationBarColor: p.surface,
      ),
      child: Scaffold(
        backgroundColor: const Color(0xFF2F68E0),
        resizeToAvoidBottomInset: true,
        body: Stack(
          children: [
            const Positioned.fill(child: AuthHero()),
            Column(
              children: [
                // Hero area: logo centered in the space above the sheet.
                Expanded(
                  child: SafeArea(
                    bottom: false,
                    child: Stack(
                      children: [
                        // Full logo when there is room; otherwise just the
                        // company pill so the firm name is always visible.
                        LayoutBuilder(
                          builder: (context, c) => c.maxHeight >= 160
                              ? const Center(child: AuthLogo())
                              : c.maxHeight >= 44
                                  ? const Center(child: AuthLogo(compact: true))
                                  : const SizedBox.expand(),
                        ),
                        if (showBack)
                          Positioned(
                            left: 8,
                            top: 4,
                            child: IconButton(
                              tooltip: 'Back',
                              onPressed: onBack ??
                                  () => Navigator.of(context).maybePop(),
                              icon: const Icon(
                                Icons.arrow_back_rounded,
                                color: Colors.white,
                              ),
                            ),
                          ),
                      ],
                    ),
                  ),
                ),
                // Sheet: sized to its content, never taller than ~88% of the screen.
                ConstrainedBox(
                  constraints: BoxConstraints(
                    maxHeight:
                        (media.size.height - media.viewInsets.bottom) * 0.88,
                  ),
                  child: Container(
                    width: double.infinity,
                    decoration: BoxDecoration(
                      color: p.surface,
                      borderRadius:
                          const BorderRadius.vertical(top: Radius.circular(28)),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.08),
                          blurRadius: 24,
                          offset: const Offset(0, -4),
                        ),
                      ],
                    ),
                    child: SingleChildScrollView(
                      padding:
                          EdgeInsets.only(bottom: media.padding.bottom + 16),
                      child: _SheetContent(sheet: this),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _SheetContent extends StatelessWidget {
  final AuthSheet sheet;
  const _SheetContent({required this.sheet});

  @override
  Widget build(BuildContext context) {
    final p = SoftPalette.of(context);
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const SizedBox(height: 10),
        Center(
          child: Container(
            width: 36,
            height: 4,
            decoration: BoxDecoration(
              color: p.border,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
        ),
        const SizedBox(height: 18),
        Center(child: AuthIconBadge(icon: sheet.icon)),
        const SizedBox(height: 14),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24),
          child: Text(
            sheet.title,
            textAlign: TextAlign.center,
            style: SoftText.title(p, size: 21)
                .copyWith(fontWeight: FontWeight.w700),
          ),
        ),
        if (sheet.subtitle != null) ...[
          const SizedBox(height: 8),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 28),
            child: Text(
              sheet.subtitle!,
              textAlign: TextAlign.center,
              style: SoftText.body(p, size: 13, color: p.muted),
            ),
          ),
        ],
        if (sheet.subtitleExtra != null) ...[
          const SizedBox(height: 4),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 28),
            child: DefaultTextStyle.merge(
              textAlign: TextAlign.center,
              style: SoftText.heading(p, size: 13.5),
              child: Center(child: sheet.subtitleExtra!),
            ),
          ),
        ],
        const SizedBox(height: 20),
        Divider(height: 1, color: p.border),
        Padding(
          padding: const EdgeInsets.fromLTRB(22, 22, 22, 0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: sheet.children,
          ),
        ),
        if (sheet.footer != null)
          Padding(
            padding: const EdgeInsets.fromLTRB(22, 16, 22, 0),
            child: sheet.footer,
          ),
        if (sheet.note != null)
          Padding(
            padding: const EdgeInsets.fromLTRB(22, 16, 22, 0),
            child: Text(
              sheet.note!,
              textAlign: TextAlign.center,
              style: SoftText.caption(p, size: 12),
            ),
          ),
      ],
    );
  }
}

/// Small outlined square badge with a blue icon, shown above sheet titles.
class AuthIconBadge extends StatelessWidget {
  final IconData icon;
  const AuthIconBadge({super.key, required this.icon});

  @override
  Widget build(BuildContext context) {
    final p = SoftPalette.of(context);
    return Container(
      width: 46,
      height: 46,
      decoration: BoxDecoration(
        color: p.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: p.border),
        boxShadow: p.shadow,
      ),
      child: Icon(icon, size: 22, color: p.accent),
    );
  }
}

/// Feature row used on the splash sheet: tinted icon tile + title + caption.
class AuthFeatureRow extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;

  const AuthFeatureRow({
    super.key,
    required this.icon,
    required this.title,
    required this.subtitle,
  });

  @override
  Widget build(BuildContext context) {
    final p = SoftPalette.of(context);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 7),
      child: Row(
        children: [
          Container(
            width: 38,
            height: 38,
            decoration: BoxDecoration(
              color: p.accentSoft,
              borderRadius: BorderRadius.circular(11),
            ),
            child: Icon(icon, size: 19, color: p.accent),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: SoftText.heading(p, size: 14.5)),
                const SizedBox(height: 1),
                Text(subtitle, style: SoftText.caption(p, size: 12)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// Soft blue gradient with a diagonal light sheen.
class AuthHero extends StatelessWidget {
  const AuthHero({super.key});

  @override
  Widget build(BuildContext context) {
    // Three layers: a diagonal blue base (light top-left, deep middle,
    // lighter bottom-right), a soft white glow in the top-left corner and a
    // faint diagonal light band across the lower right.
    return Stack(
      fit: StackFit.expand,
      children: [
        const DecoratedBox(
          decoration: BoxDecoration(
            // Ends around the middle of the screen so the whole sweep
            // (light -> deep -> light) is visible above the sheet.
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment(1.0, 0.15),
              colors: [
                Color(0xFF8FB3F6),
                Color(0xFF4A7EEA),
                Color(0xFF2C63DD),
                Color(0xFF3A72E6),
                Color(0xFF79A2F1),
              ],
              stops: [0.0, 0.3, 0.55, 0.78, 1.0],
            ),
          ),
        ),
        DecoratedBox(
          decoration: BoxDecoration(
            gradient: RadialGradient(
              center: const Alignment(-1.0, -1.0),
              radius: 1.1,
              colors: [
                Colors.white.withValues(alpha: 0.32),
                Colors.white.withValues(alpha: 0.0),
              ],
            ),
          ),
        ),
        DecoratedBox(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: const Alignment(-1.0, -0.9),
              end: const Alignment(1.0, 0.25),
              colors: [
                Colors.white.withValues(alpha: 0.0),
                Colors.white.withValues(alpha: 0.0),
                Colors.white.withValues(alpha: 0.22),
                Colors.white.withValues(alpha: 0.0),
              ],
              stops: const [0.0, 0.48, 0.66, 0.84],
            ),
          ),
        ),
      ],
    );
  }
}

/// White rounded logo tile with the "Power CA" label underneath and the
/// company (concern) name below it in a soft glass pill.
///
/// [compact] shows only the company pill, for when the hero is too short
/// for the full logo (e.g. a tall sheet or the keyboard is open).
///
/// The company comes from [CompanyNameCache] (saved after a staff member
/// signs in on the device). Before that it is looked up from the staff
/// member this device was phone-verified for, or, failing that, the only
/// non-demo company in orgmaster. If none is found only "Power CA" shows.
class AuthLogo extends StatefulWidget {
  final bool compact;
  const AuthLogo({super.key, this.compact = false});

  @override
  State<AuthLogo> createState() => _AuthLogoState();
}

class _AuthLogoState extends State<AuthLogo> {
  /// Last name shown, so the next auth screen paints it without a flicker.
  static String? _memo;

  String? _company = _memo;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    // The cache is re-read every time so a later sign-in with a different
    // company is picked up; the network lookup only runs when it is empty.
    var name = await CompanyNameCache.read();
    name ??= _memo ?? await _fetchCompany();
    if (name == null) return;
    _memo = name;
    if (mounted && name != _company) setState(() => _company = name);
  }

  /// Works out the company before anyone has signed in:
  /// 1. the staff member this device was phone-verified for -> their org;
  /// 2. otherwise orgmaster, ignoring demo companies, when exactly one
  ///    real company remains.
  static Future<String?> _fetchCompany() async {
    try {
      final db = Supabase.instance.client;
      String? name;

      int? staffId;
      try {
        staffId =
            await getIt<DeviceSecurityLocalDataSource>().getVerifiedStaffId();
      } catch (_) {}
      if (staffId != null) {
        final staff = await db
            .from('mbstaff')
            .select('org_id')
            .eq('staff_id', staffId)
            .maybeSingle();
        final orgId = staff?['org_id'];
        if (orgId != null) {
          final org = await db
              .from('orgmaster')
              .select('orgname')
              .eq('org_id', orgId)
              .maybeSingle();
          name = org?['orgname']?.toString().trim();
        }
      }

      if (name == null || name.isEmpty) {
        final rows = await db.from('orgmaster').select('orgname');
        final real = rows
            .map((r) => r['orgname']?.toString().trim() ?? '')
            .where((n) => n.isNotEmpty && !n.toUpperCase().contains('DEMO'))
            .toList();
        name = real.length == 1 ? real.first : null;
      }

      if (name == null || name.isEmpty) return null;
      await CompanyNameCache.save(name);
      return name;
    } catch (e) {
      debugPrint('AuthLogo: company lookup failed: $e');
      return null;
    }
  }

  Widget _pill() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.16),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: Colors.white.withValues(alpha: 0.30)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.apartment_rounded, size: 15, color: Colors.white),
          const SizedBox(width: 8),
          Flexible(
            child: Text(
              _company!.toUpperCase(),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                fontFamily: AppTheme.fontFamily,
                fontSize: 12.5,
                fontWeight: FontWeight.w600,
                letterSpacing: 0.6,
                color: Colors.white,
              ),
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (widget.compact) {
      // Side padding keeps the pill clear of the back button.
      return AnimatedSwitcher(
        duration: const Duration(milliseconds: 250),
        child: _company == null
            ? const SizedBox.shrink()
            : Padding(
                key: ValueKey(_company),
                padding: const EdgeInsets.symmetric(horizontal: 60),
                child: _pill(),
              ),
      );
    }

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 76,
          height: 76,
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(20),
            boxShadow: [
              BoxShadow(
                color: const Color(0xFF0B1A30).withValues(alpha: 0.18),
                blurRadius: 22,
                offset: const Offset(0, 10),
              ),
            ],
          ),
          child: Image.asset(
            'assets/images/Logo/Power CA Logo Only-04.png',
            fit: BoxFit.contain,
          ),
        ),
        const SizedBox(height: 12),
        const Text(
          'Power CA',
          style: TextStyle(
            fontFamily: AppTheme.fontFamily,
            fontSize: 16,
            fontWeight: FontWeight.w600,
            color: Colors.white,
          ),
        ),
        AnimatedSwitcher(
          duration: const Duration(milliseconds: 250),
          child: _company == null
              ? const SizedBox.shrink()
              : Padding(
                  key: ValueKey(_company),
                  padding: const EdgeInsets.only(top: 12, left: 24, right: 24),
                  child: _pill(),
                ),
        ),
      ],
    );
  }
}
