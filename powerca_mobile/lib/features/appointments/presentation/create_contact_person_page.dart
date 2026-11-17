import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/utils/error_messages.dart';
import '../../../shared/widgets/soft_page.dart';
import '../../../shared/widgets/soft_ui.dart';
import '../../auth/domain/entities/staff.dart';
import 'party_picker_sheet.dart';

/// Contact person master: creates a row in `contactperson`.
///
/// Opened from the Add meeting screen when the meeting is with a new
/// contact. Pops with the created [PickedParty] (con_id + name).
class CreateContactPersonPage extends StatefulWidget {
  final Staff currentStaff;

  /// Prefills the name, e.g. with what was typed in the search box.
  final String? initialName;

  const CreateContactPersonPage({super.key, required this.currentStaff, this.initialName});

  @override
  State<CreateContactPersonPage> createState() => _CreateContactPersonPageState();
}

class _CreateContactPersonPageState extends State<CreateContactPersonPage> {
  static final _emailRe = RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$');

  final _nameController = TextEditingController();
  final _groupController = TextEditingController();
  final _mobileController = TextEditingController();
  final _emailController = TextEditingController();

  List<String> _groups = [];
  bool _saving = false;
  bool _submitted = false;
  String? _formError;

  SupabaseClient get _db => Supabase.instance.client;

  @override
  void initState() {
    super.initState();
    _nameController.text = widget.initialName?.trim() ?? '';
    _loadGroups();
  }

  @override
  void dispose() {
    _nameController.dispose();
    _groupController.dispose();
    _mobileController.dispose();
    _emailController.dispose();
    super.dispose();
  }

  /// Existing groups of this org, offered as quick picks.
  Future<void> _loadGroups() async {
    try {
      final rows = await _db
          .from('contactperson')
          .select('congroup')
          .eq('org_id', widget.currentStaff.orgId);
      final set = <String>{
        for (final r in rows)
          if ((r['congroup'] ?? '').toString().trim().isNotEmpty) (r['congroup'] as String).trim(),
      };
      if (mounted) setState(() => _groups = set.toList()..sort());
    } catch (_) {
      // Suggestions are optional; the field still accepts free text.
    }
  }

  String? get _nameError => _nameController.text.trim().isEmpty ? 'Enter the contact name' : null;

  String? get _groupError => _groupController.text.trim().isEmpty ? 'Enter a group' : null;

  String? get _mobileError {
    final m = _mobileController.text.trim();
    if (m.isEmpty) return null;
    return RegExp(r'^[6-9]\d{9}$').hasMatch(m) ? null : 'Enter a valid 10-digit mobile number';
  }

  String? get _emailError {
    final e = _emailController.text.trim();
    if (e.isEmpty) return null;
    return _emailRe.hasMatch(e) ? null : 'Enter a valid email address';
  }

  Future<void> _save() async {
    FocusScope.of(context).unfocus();
    setState(() {
      _submitted = true;
      _formError = null;
    });
    if (_nameError != null || _groupError != null || _mobileError != null || _emailError != null) {
      return;
    }

    final staff = widget.currentStaff;
    final name = _nameController.text.trim();
    final mobile = _mobileController.text.trim();
    final email = _emailController.text.trim();

    setState(() => _saving = true);
    try {
      if (mobile.isNotEmpty) {
        final dup = await _db
            .from('contactperson')
            .select('con_id, conname')
            .eq('org_id', staff.orgId)
            .eq('conmobno', int.parse(mobile))
            .limit(1)
            .maybeSingle();
        if (dup != null) {
          setState(
            () => _formError =
                '${(dup['conname'] ?? 'A contact').toString().trim()} already has this mobile number. '
                    'Pick them from the contact list instead.',
          );
          return;
        }
      }

      final row = await _db
          .from('contactperson')
          .insert({
            'org_id': staff.orgId,
            'loc_id': staff.locId,
            'congroup': _groupController.text.trim(),
            'conname': name,
            'conmobno': mobile.isEmpty ? null : int.parse(mobile),
            'conemail': email.isEmpty ? null : email,
            'source': 'M',
          })
          .select('con_id, conname')
          .single();

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Contact $name created')));
      Navigator.pop(
        context,
        PickedParty((row['con_id'] as num).toInt(), (row['conname'] as String).trim()),
      );
    } catch (e) {
      if (mounted) setState(() => _formError = ErrorMessages.friendly(e));
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final p = SoftPalette.of(context);
    return SoftScaffold(
      title: 'New contact',
      subtitle: 'Contact person master',
      bottomBar: SoftPillButton(
        label: 'Save contact',
        icon: Icons.person_add_alt_1_rounded,
        loading: _saving,
        onPressed: _save,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            SoftCard(
              radius: 24,
              padding: const EdgeInsets.fromLTRB(18, 16, 18, 20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Row(
                    children: [
                      Icon(Icons.badge_outlined, size: 17, color: p.accent),
                      const SizedBox(width: 8),
                      Text('Contact details', style: SoftText.heading(p, size: 15)),
                    ],
                  ),
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    child: Divider(height: 1, thickness: 1, color: p.border),
                  ),
                  const SoftFieldLabel('Contact name', required: true),
                  TextField(
                    controller: _nameController,
                    maxLength: 50,
                    textCapitalization: TextCapitalization.words,
                    textInputAction: TextInputAction.next,
                    style: softInputTextStyle(context),
                    onChanged: (_) => setState(() {}),
                    decoration: softInputDecoration(
                      context,
                      hint: 'Full name',
                      icon: Icons.person_outline_rounded,
                      filled: true,
                      counterText: '',
                      errorText: _submitted ? _nameError : null,
                    ),
                  ),
                  const SizedBox(height: 16),
                  const SoftFieldLabel('Group', required: true),
                  TextField(
                    controller: _groupController,
                    maxLength: 20,
                    textCapitalization: TextCapitalization.words,
                    textInputAction: TextInputAction.next,
                    style: softInputTextStyle(context),
                    onChanged: (_) => setState(() {}),
                    decoration: softInputDecoration(
                      context,
                      hint: 'e.g. Prospect, Referral',
                      icon: Icons.folder_shared_outlined,
                      filled: true,
                      counterText: '',
                      errorText: _submitted ? _groupError : null,
                    ),
                  ),
                  if (_groups.isNotEmpty) ...[
                    const SizedBox(height: 10),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: [
                        for (final g in _groups)
                          _GroupChip(
                            label: g,
                            selected: _groupController.text.trim() == g,
                            onTap: () => setState(() => _groupController.text = g),
                          ),
                      ],
                    ),
                  ],
                  const SizedBox(height: 16),
                  const SoftFieldLabel('Mobile number'),
                  TextField(
                    controller: _mobileController,
                    keyboardType: TextInputType.phone,
                    maxLength: 10,
                    inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                    textInputAction: TextInputAction.next,
                    style: softInputTextStyle(context),
                    onChanged: (_) => setState(() {}),
                    decoration: softInputDecoration(
                      context,
                      hint: '10-digit mobile',
                      prefixText: '+91  ',
                      filled: true,
                      counterText: '',
                      errorText: _submitted ? _mobileError : null,
                    ),
                  ),
                  const SizedBox(height: 16),
                  const SoftFieldLabel('Email'),
                  TextField(
                    controller: _emailController,
                    keyboardType: TextInputType.emailAddress,
                    maxLength: 40,
                    textInputAction: TextInputAction.done,
                    style: softInputTextStyle(context),
                    onChanged: (_) => setState(() {}),
                    onSubmitted: (_) => _save(),
                    decoration: softInputDecoration(
                      context,
                      hint: 'name@example.com',
                      icon: Icons.alternate_email_rounded,
                      filled: true,
                      counterText: '',
                      errorText: _submitted ? _emailError : null,
                    ),
                  ),
                ],
              ),
            ),
            if (_formError != null) ...[
              const SizedBox(height: 14),
              Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: p.tint(p.danger),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Row(
                  children: [
                    Icon(Icons.error_outline_rounded, color: p.danger, size: 20),
                    const SizedBox(width: 10),
                    Expanded(child: Text(_formError!, style: SoftText.body(p, color: p.danger))),
                  ],
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _GroupChip extends StatelessWidget {
  final String label;
  final bool selected;
  final VoidCallback onTap;

  const _GroupChip({required this.label, required this.selected, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final p = SoftPalette.of(context);
    return Material(
      color: selected ? p.pill : p.surface,
      shape: StadiumBorder(side: BorderSide(color: selected ? p.pill : p.border)),
      child: InkWell(
        customBorder: const StadiumBorder(),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
          child: Text(
            label,
            style: SoftText.heading(p, size: 13).copyWith(color: selected ? p.onPill : p.inkSoft),
          ),
        ),
      ),
    );
  }
}
