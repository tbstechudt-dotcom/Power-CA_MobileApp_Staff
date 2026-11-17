import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../../core/services/tab_data_cache.dart';
import '../../../core/utils/error_messages.dart';
import '../../../shared/widgets/soft_page.dart';
import '../../auth/domain/entities/staff.dart';
import '../data/appointment_store.dart';
import '../domain/appointment.dart';
import 'meeting_page.dart';

/// Home "Appointments" card: open meetings (upcoming, or past and waiting
/// for an outcome) plus an "Add meeting" button. Reloads from
/// `j_appointments` whenever [AppointmentStore] writes.
class AppointmentsCard extends StatefulWidget {
  final Staff currentStaff;
  final int maxItems;

  const AppointmentsCard({super.key, required this.currentStaff, this.maxItems = 3});

  @override
  State<AppointmentsCard> createState() => _AppointmentsCardState();
}

class _AppointmentsCardState extends State<AppointmentsCard> {
  final _store = AppointmentStore.instance;
  List<Appointment> _items = [];
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    // Show the last loaded meetings instantly; _load refreshes quietly.
    final cached = TabDataCache.read<List<Appointment>>(_cacheKey);
    if (cached != null) {
      _items = cached;
      _loading = false;
    }
    _store.addListener(_load);
    _load();
  }

  String get _cacheKey => 'appointments:${widget.currentStaff.staffId}';

  @override
  void dispose() {
    _store.removeListener(_load);
    super.dispose();
  }

  Future<void> _load() async {
    try {
      final items = await _store.open(widget.currentStaff.staffId);
      TabDataCache.write(_cacheKey, items);
      if (!mounted) return;
      setState(() {
        _items = items;
        _loading = false;
        _error = null;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = ErrorMessages.friendly(e);
      });
    }
  }

  void _open({Appointment? appointment, int tab = 0}) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => MeetingPage(
          currentStaff: widget.currentStaff,
          appointment: appointment,
          initialTab: tab,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final p = SoftPalette.of(context);
    final shown = _items.take(widget.maxItems).toList();
    final now = DateTime.now();
    final upcoming = _items.where((a) => a.end.isAfter(now)).length;
    final due = _items.length - upcoming;

    String subtitle;
    if (_items.isEmpty) {
      subtitle = 'Client meetings booked by you';
    } else {
      subtitle = [
        if (upcoming > 0) '$upcoming upcoming',
        if (due > 0) '$due outcome due',
      ].join(' - ');
    }

    return SoftCard(
      radius: 26,
      padding: const EdgeInsets.fromLTRB(20, 18, 20, 18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Appointments', style: SoftText.heading(p, size: 17.5)),
                    const SizedBox(height: 3),
                    Text(subtitle, style: SoftText.caption(p, size: 12.5)),
                  ],
                ),
              ),
              _AddMeetingButton(onTap: () => _open()),
            ],
          ),
          const SizedBox(height: 16),
          if (_loading)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 22),
              child: Center(child: CircularProgressIndicator()),
            )
          else if (_error != null)
            _EmptyBox(
              icon: Icons.wifi_off_rounded,
              title: "Couldn't load appointments",
              message: _error!,
              onTap: () {
                setState(() => _loading = true);
                _load();
              },
            )
          else if (shown.isEmpty)
            const _EmptyBox(
              icon: Icons.calendar_month_outlined,
              title: 'No upcoming appointments',
              message: 'Tap Add meeting to schedule a meeting with a client.',
            )
          else
            for (int i = 0; i < shown.length; i++) ...[
              if (i > 0) Divider(color: p.border, height: 1),
              AppointmentRow(
                appointment: shown[i],
                onTap: () => _open(
                  appointment: shown[i],
                  tab: shown[i].end.isAfter(now) ? 0 : 1,
                ),
              ),
            ],
          if (_items.length > shown.length)
            Padding(
              padding: const EdgeInsets.only(top: 4, bottom: 6),
              child: Text('+${_items.length - shown.length} more', style: SoftText.caption(p)),
            ),
        ],
      ),
    );
  }
}

class _EmptyBox extends StatelessWidget {
  final IconData icon;
  final String title;
  final String message;
  final VoidCallback? onTap;

  const _EmptyBox({required this.icon, required this.title, required this.message, this.onTap});

  @override
  Widget build(BuildContext context) {
    final p = SoftPalette.of(context);
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(18),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 22),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: p.border),
        ),
        child: Column(
          children: [
            Icon(icon, size: 26, color: p.muted),
            const SizedBox(height: 10),
            Text(title, style: SoftText.heading(p, size: 14.5)),
            const SizedBox(height: 4),
            Text(
              onTap == null ? message : '$message\nTap to retry.',
              textAlign: TextAlign.center,
              style: SoftText.caption(p, size: 12.5),
            ),
          ],
        ),
      ),
    );
  }
}

/// Deep-blue "+ Add meeting" pill.
class _AddMeetingButton extends StatelessWidget {
  final VoidCallback onTap;
  const _AddMeetingButton({required this.onTap});

  @override
  Widget build(BuildContext context) {
    final p = SoftPalette.of(context);
    final bg = p.isDark ? p.accent : const Color(0xFF1E3A8A);
    final fg = p.isDark ? p.background : Colors.white;
    return Material(
      color: bg,
      shape: const StadiumBorder(),
      child: InkWell(
        customBorder: const StadiumBorder(),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.add_rounded, size: 18, color: fg),
              const SizedBox(width: 6),
              Text('Add meeting', style: SoftText.heading(p, size: 14).copyWith(color: fg)),
            ],
          ),
        ),
      ),
    );
  }
}

/// One appointment in a list: date block, client/contact, time and mode.
class AppointmentRow extends StatelessWidget {
  final Appointment appointment;
  final VoidCallback onTap;

  const AppointmentRow({super.key, required this.appointment, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final p = SoftPalette.of(context);
    final a = appointment;
    final due = !a.end.isAfter(DateTime.now());
    final time = a.meetingTime == null
        ? 'No time set'
        : '${DateFormat('h:mm a').format(a.start)} - ${DateFormat('h:mm a').format(a.end)}';
    return InkWell(
      borderRadius: BorderRadius.circular(12),
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 12),
        child: Row(
          children: [
            Container(
              width: 46,
              padding: const EdgeInsets.symmetric(vertical: 6),
              decoration: BoxDecoration(
                color: p.surfaceAlt,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Column(
                children: [
                  Text(
                    DateFormat('MMM').format(a.meetingDate).toUpperCase(),
                    style: SoftText.overline(p).copyWith(fontSize: 9.5),
                  ),
                  Text('${a.meetingDate.day}', style: SoftText.heading(p, size: 17)),
                ],
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    a.partyName,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: SoftText.heading(p, size: 14.5),
                  ),
                  const SizedBox(height: 3),
                  Row(
                    children: [
                      Icon(a.mode.icon, size: 13, color: p.muted),
                      const SizedBox(width: 4),
                      Flexible(
                        child: Text(
                          time,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: SoftText.caption(p),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            if (due) ...[
              SoftStatusPill(label: 'Outcome due', color: p.warning),
              const SizedBox(width: 4),
            ],
            Icon(Icons.chevron_right_rounded, color: p.muted),
          ],
        ),
      ),
    );
  }
}
