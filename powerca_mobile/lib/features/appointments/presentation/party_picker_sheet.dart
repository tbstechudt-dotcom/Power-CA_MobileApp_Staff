import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/utils/error_messages.dart';
import '../../../shared/widgets/soft_page.dart';
import '../../../shared/widgets/soft_ui.dart';
import '../../auth/domain/entities/staff.dart';
import '../domain/appointment.dart';
import 'create_contact_person_page.dart';

/// A picked client or contact.
class PickedParty {
  final int id;
  final String name;
  const PickedParty(this.id, this.name);
}

class _Row {
  final int id;
  final String name;
  final String? subtitle;
  const _Row(this.id, this.name, this.subtitle);
}

/// Opens a searchable list of clients (`climaster`) or contact persons
/// (`contactperson`) for the staff's org. In contact mode the sheet also
/// offers "Create new contact", which opens the contact person master.
Future<PickedParty?> showPartyPicker(
  BuildContext context, {
  required MeetWith kind,
  required Staff staff,
}) {
  return showModalBottomSheet<PickedParty>(
    context: context,
    isScrollControlled: true,
    builder: (_) => _PartyPickerSheet(kind: kind, staff: staff),
  );
}

/// Opens the contact person master directly.
Future<PickedParty?> openCreateContactPerson(
  BuildContext context, {
  required Staff staff,
  String? initialName,
}) {
  return Navigator.push<PickedParty>(
    context,
    MaterialPageRoute(
      builder: (_) => CreateContactPersonPage(currentStaff: staff, initialName: initialName),
    ),
  );
}

class _PartyPickerSheet extends StatefulWidget {
  final MeetWith kind;
  final Staff staff;
  const _PartyPickerSheet({required this.kind, required this.staff});

  @override
  State<_PartyPickerSheet> createState() => _PartyPickerSheetState();
}

class _PartyPickerSheetState extends State<_PartyPickerSheet> {
  List<_Row> _items = [];
  String _query = '';
  bool _loading = true;
  String? _error;

  bool get _isClient => widget.kind == MeetWith.existingClient;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final db = Supabase.instance.client;
      final List<_Row> items;
      if (_isClient) {
        final rows = await db
            .from('climaster')
            .select('client_id, clientname')
            .eq('org_id', widget.staff.orgId)
            .order('clientname');
        items = [
          for (final r in rows)
            if (r['client_id'] != null)
              _Row(
                (r['client_id'] as num).toInt(),
                (r['clientname'] ?? '').toString().trim(),
                null,
              ),
        ];
      } else {
        final rows = await db
            .from('contactperson')
            .select('con_id, conname, congroup, conmobno')
            .eq('org_id', widget.staff.orgId)
            .order('conname');
        items = [
          for (final r in rows)
            _Row(
              (r['con_id'] as num).toInt(),
              (r['conname'] ?? '').toString().trim(),
              [
                if (r['conmobno'] != null) '+91 ${(r['conmobno'] as num).toInt()}',
                if ((r['congroup'] ?? '').toString().trim().isNotEmpty)
                  (r['congroup'] as String).trim(),
              ].join('  ·  '),
            ),
        ];
      }
      if (!mounted) return;
      setState(() {
        _items = items;
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = ErrorMessages.friendly(e);
        _loading = false;
      });
    }
  }

  Future<void> _createContact() async {
    final created = await openCreateContactPerson(
      context,
      staff: widget.staff,
      initialName: _query,
    );
    if (created != null && mounted) Navigator.pop(context, created);
  }

  @override
  Widget build(BuildContext context) {
    final p = SoftPalette.of(context);
    final q = _query.toLowerCase();
    final filtered = q.isEmpty
        ? _items
        : _items
            .where(
              (c) =>
                  c.name.toLowerCase().contains(q) || (c.subtitle ?? '').toLowerCase().contains(q),
            )
            .toList();
    final noun = _isClient ? 'client' : 'contact';

    return SizedBox(
      height: MediaQuery.of(context).size.height * 0.8,
      child: Padding(
        padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 0, 20, 12),
              child: Text('Select $noun', style: SoftText.title(p, size: 20)),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: TextField(
                style: softInputTextStyle(context),
                decoration: softInputDecoration(
                  context,
                  hint: _isClient ? 'Search clients' : 'Search by name or mobile',
                  icon: Icons.search_rounded,
                  pill: true,
                  dense: true,
                ),
                onChanged: (v) => setState(() => _query = v),
              ),
            ),
            if (!_isClient)
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 12, 20, 4),
                child: SoftPillButton(
                  label: 'Create new contact',
                  icon: Icons.person_add_alt_1_rounded,
                  onPressed: _createContact,
                ),
              ),
            const SizedBox(height: 8),
            Expanded(
              child: _loading
                  ? const Center(child: CircularProgressIndicator())
                  : _error != null
                      ? SoftMessage(
                          icon: Icons.wifi_off_rounded,
                          title: "Couldn't load ${noun}s",
                          message: _error,
                          actionLabel: 'Retry',
                          onAction: _load,
                        )
                      : filtered.isEmpty
                          ? SoftMessage(
                              icon: _isClient
                                  ? Icons.search_off_rounded
                                  : Icons.person_search_outlined,
                              title: 'No ${noun}s found',
                              message:
                                  _isClient ? null : 'Tap Create new contact to add this person.',
                            )
                          : ListView.separated(
                              padding: const EdgeInsets.fromLTRB(12, 4, 12, 16),
                              itemCount: filtered.length,
                              separatorBuilder: (_, __) => Divider(indent: 64, color: p.border),
                              itemBuilder: (context, i) {
                                final c = filtered[i];
                                final name = c.name.isEmpty ? noun : c.name;
                                return ListTile(
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(14),
                                  ),
                                  leading: CircleAvatar(
                                    backgroundColor: p.accentSoft,
                                    child: Text(
                                      name[0].toUpperCase(),
                                      style:
                                          SoftText.heading(p, size: 15).copyWith(color: p.accent),
                                    ),
                                  ),
                                  title: Text(name, style: SoftText.heading(p, size: 14.5)),
                                  subtitle: (c.subtitle ?? '').isEmpty
                                      ? null
                                      : Text(c.subtitle!, style: SoftText.caption(p)),
                                  onTap: () => Navigator.pop(context, PickedParty(c.id, name)),
                                );
                              },
                            ),
            ),
          ],
        ),
      ),
    );
  }
}
