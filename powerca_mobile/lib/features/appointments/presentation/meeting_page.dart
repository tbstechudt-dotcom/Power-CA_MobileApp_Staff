import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../../core/utils/error_messages.dart';
import '../../../shared/widgets/soft_page.dart';
import '../../../shared/widgets/soft_ui.dart';
import '../../auth/domain/entities/staff.dart';
import '../data/appointment_store.dart';
import '../domain/appointment.dart';
import 'party_picker_sheet.dart';

/// "Add meeting" page with two tabs:
///  * Appointment - who, how, when, duration and purpose (`j_appointments`)
///  * Outcome     - actual time spent, key person met, optional reschedule
///
/// Opened empty from the Home "Add meeting" button, or with [appointment]
/// from the Home appointments list. The Outcome tab unlocks once the
/// appointment has been saved.
class MeetingPage extends StatefulWidget {
  final Staff currentStaff;
  final Appointment? appointment;
  final int initialTab;

  const MeetingPage({
    super.key,
    required this.currentStaff,
    this.appointment,
    this.initialTab = 0,
  });

  @override
  State<MeetingPage> createState() => _MeetingPageState();
}

class _MeetingPageState extends State<MeetingPage> with SingleTickerProviderStateMixin {
  static const _durations = [30, 60, 90, 120];

  final _store = AppointmentStore.instance;
  late final TabController _tabs;

  Appointment? _appointment;
  bool _saving = false;

  // Appointment tab
  MeetWith _meetWith = MeetWith.existingClient;
  MeetMode _mode = MeetMode.direct;
  int? _partyId;
  String? _partyName;
  late DateTime _date;
  TimeOfDay? _time;
  int _duration = 60;
  final _purposeController = TextEditingController();
  bool _apptSubmitted = false;
  String? _apptError;

  // Outcome tab
  Duration _timeSpent = Duration.zero;
  final _keyPersonController = TextEditingController();
  bool _reschedule = false;
  DateTime? _reschedDate;
  TimeOfDay? _reschedTime;
  bool _outcomeSubmitted = false;
  String? _outcomeError;

  @override
  void initState() {
    super.initState();
    final now = DateTime.now();
    _date = DateTime(now.year, now.month, now.day);
    final a = widget.appointment;
    if (a != null) _loadFrom(a);
    _tabs = TabController(
      length: 2,
      vsync: this,
      initialIndex: a == null ? 0 : widget.initialTab.clamp(0, 1),
    );
    _tabs.addListener(_onTabChanged);
  }

  void _loadFrom(Appointment a) {
    _appointment = a;
    _meetWith = a.meetWith;
    _mode = a.mode;
    _partyId = a.meetWith == MeetWith.existingClient ? a.clientId : a.contactId;
    _partyName = a.partyName;
    _date = a.meetingDate;
    _time = a.meetingTime;
    _duration = a.durationMinutes ?? 60;
    _purposeController.text = a.purpose ?? '';
    _timeSpent = a.actualTimeSpent ?? Duration(minutes: _duration);
    _keyPersonController.text = a.keyPerson ?? '';
  }

  void _onTabChanged() {
    if (_tabs.indexIsChanging) return;
    if (_tabs.index == 1 && _appointment == null) {
      _tabs.index = 0;
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(
          const SnackBar(content: Text('Save the appointment first to record its outcome.')),
        );
    }
    setState(() {});
  }

  @override
  void dispose() {
    _tabs.removeListener(_onTabChanged);
    _tabs.dispose();
    _purposeController.dispose();
    _keyPersonController.dispose();
    super.dispose();
  }

  /// Appointment details can be edited until an outcome is recorded.
  bool get _editable => _appointment == null || _appointment!.isOpen;

  DateTime? get _start => _time == null
      ? null
      : DateTime(_date.year, _date.month, _date.day, _time!.hour, _time!.minute);

  String _durationLabel(int m) {
    if (m < 60) return '$m min';
    final h = m / 60;
    return h == h.roundToDouble() ? '${h.toInt()} hr' : '$h hr';
  }

  String _spentLabel(Duration d) {
    final h = d.inHours;
    final m = d.inMinutes % 60;
    if (h == 0) return '$m min';
    return m == 0 ? '$h hr' : '$h hr $m min';
  }

  void _toast(String msg) =>
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));

  // ---------------------------------------------------------------- pickers

  Future<DateTime?> _pickDay(DateTime initial) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    return showDatePicker(
      context: context,
      initialDate: initial,
      firstDate: initial.isBefore(today) ? initial : today,
      lastDate: today.add(const Duration(days: 365)),
    );
  }

  Future<void> _pickDate() async {
    final picked = await _pickDay(_date);
    if (picked != null) setState(() => _date = picked);
  }

  Future<void> _pickTime() async {
    final picked = await showTimePicker(
      context: context,
      initialTime: _time ?? const TimeOfDay(hour: 10, minute: 0),
    );
    if (picked != null) setState(() => _time = picked);
  }

  Future<void> _pickParty() async {
    final picked = await showPartyPicker(context, kind: _meetWith, staff: widget.currentStaff);
    _setParty(picked);
  }

  /// Opens the contact person master and selects the created contact.
  Future<void> _createContact() async {
    final created = await openCreateContactPerson(context, staff: widget.currentStaff);
    _setParty(created);
  }

  void _setParty(PickedParty? picked) {
    if (picked != null && mounted) {
      setState(() {
        _partyId = picked.id;
        _partyName = picked.name;
      });
    }
  }

  Future<void> _pickTimeSpent() async {
    var value = _timeSpent;
    final picked = await showModalBottomSheet<Duration>(
      context: context,
      builder: (sheetContext) {
        final p = SoftPalette.of(sheetContext);
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 0, 20, 16),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text('Actual time spent', style: SoftText.title(p, size: 20)),
                SizedBox(
                  height: 200,
                  child: CupertinoTimerPicker(
                    mode: CupertinoTimerPickerMode.hm,
                    minuteInterval: 5,
                    initialTimerDuration: Duration(minutes: (value.inMinutes ~/ 5) * 5),
                    onTimerDurationChanged: (d) => value = d,
                  ),
                ),
                SoftPillButton(
                  label: 'Done',
                  onPressed: () => Navigator.pop(sheetContext, value),
                ),
              ],
            ),
          ),
        );
      },
    );
    if (picked != null) setState(() => _timeSpent = picked);
  }

  Future<void> _pickReschedDate() async {
    final now = DateTime.now();
    final picked = await _pickDay(_reschedDate ?? DateTime(now.year, now.month, now.day));
    if (picked != null) setState(() => _reschedDate = picked);
  }

  Future<void> _pickReschedTime() async {
    final picked = await showTimePicker(
      context: context,
      initialTime: _reschedTime ?? _time ?? const TimeOfDay(hour: 10, minute: 0),
    );
    if (picked != null) setState(() => _reschedTime = picked);
  }

  // ---------------------------------------------------------------- actions

  Future<void> _saveAppointment() async {
    setState(() {
      _apptSubmitted = true;
      _apptError = null;
    });
    final start = _start;
    if (_partyId == null || start == null) {
      setState(
        () => _apptError =
            'Choose a ${_meetWith == MeetWith.existingClient ? 'client' : 'contact'} and a time.',
      );
      return;
    }
    final existing = _appointment;
    final timeChanged = existing == null || existing.start != start;
    if (timeChanged && !start.isAfter(DateTime.now())) {
      setState(() => _apptError = 'Pick a time later than now.');
      return;
    }

    setState(() => _saving = true);
    try {
      final clash = await _store.findClash(
        widget.currentStaff.staffId,
        start,
        _duration,
        exceptId: existing?.id,
      );
      if (clash != null) {
        setState(
          () => _apptError = 'This overlaps your meeting with ${clash.partyName} at '
              '${DateFormat('h:mm a').format(clash.start)}.',
        );
        return;
      }
      final saved = existing == null
          ? await _store.create(
              staff: widget.currentStaff,
              mode: _mode,
              meetWith: _meetWith,
              partyId: _partyId!,
              partyName: _partyName!,
              start: start,
              durationMinutes: _duration,
              purpose: _purposeController.text,
            )
          : await _store.update(
              existing,
              staff: widget.currentStaff,
              mode: _mode,
              meetWith: _meetWith,
              partyId: _partyId!,
              partyName: _partyName!,
              start: start,
              durationMinutes: _duration,
              purpose: _purposeController.text,
            );
      if (!mounted) return;
      setState(() {
        _appointment = saved;
        if (existing == null) _timeSpent = Duration(minutes: _duration);
      });
      _toast(
        existing == null
            ? 'Meeting with ${saved.partyName} saved. Record the outcome after it.'
            : 'Meeting updated',
      );
    } catch (e) {
      if (mounted) setState(() => _apptError = ErrorMessages.friendly(e));
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<void> _saveOutcome() async {
    final a = _appointment;
    if (a == null) return;
    setState(() {
      _outcomeSubmitted = true;
      _outcomeError = null;
    });

    DateTime? reschedTo;
    if (_reschedule) {
      if (_reschedDate == null || _reschedTime == null) {
        setState(() => _outcomeError = 'Choose the new meeting date and time.');
        return;
      }
      reschedTo = DateTime(
        _reschedDate!.year,
        _reschedDate!.month,
        _reschedDate!.day,
        _reschedTime!.hour,
        _reschedTime!.minute,
      );
      if (!reschedTo.isAfter(DateTime.now())) {
        setState(() => _outcomeError = 'The new meeting time must be later than now.');
        return;
      }
    } else {
      if (_keyPersonController.text.trim().isEmpty) {
        setState(() => _outcomeError = 'Enter the key person you met.');
        return;
      }
      if (_timeSpent == Duration.zero) {
        setState(() => _outcomeError = 'Enter the actual time spent.');
        return;
      }
    }

    setState(() => _saving = true);
    try {
      if (reschedTo != null) {
        final clash = await _store.findClash(
          widget.currentStaff.staffId,
          reschedTo,
          a.durationMinutes ?? 60,
          exceptId: a.id,
        );
        if (clash != null) {
          setState(
            () => _outcomeError = 'The new time overlaps your meeting with '
                '${clash.partyName} at ${DateFormat('h:mm a').format(clash.start)}.',
          );
          return;
        }
      }
      await _store.saveOutcome(
        a,
        staff: widget.currentStaff,
        timeSpent: _timeSpent,
        keyPerson: _keyPersonController.text,
        rescheduleTo: reschedTo,
      );
      if (!mounted) return;
      _toast(
        reschedTo == null
            ? 'Outcome saved'
            : 'Meeting rescheduled to ${DateFormat('d MMM, h:mm a').format(reschedTo)}',
      );
      Navigator.pop(context, true);
    } catch (e) {
      if (mounted) setState(() => _outcomeError = ErrorMessages.friendly(e));
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<void> _cancelMeeting() async {
    final a = _appointment;
    if (a == null) return;
    final ok = await showSoftConfirmDialog(
      context,
      title: 'Cancel meeting?',
      message: 'Your meeting with ${a.partyName} will be cancelled.',
      confirmLabel: 'Cancel it',
      cancelLabel: 'Keep',
      destructive: true,
    );
    if (!ok || !mounted) return;
    setState(() => _saving = true);
    try {
      await _store.cancel(a, staff: widget.currentStaff);
      if (!mounted) return;
      _toast('Meeting cancelled');
      Navigator.pop(context, true);
    } catch (e) {
      if (mounted) _toast(ErrorMessages.friendly(e));
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  // ---------------------------------------------------------------- UI

  @override
  Widget build(BuildContext context) {
    final p = SoftPalette.of(context);
    final onOutcome = _tabs.index == 1;
    final a = _appointment;

    Widget? bottomBar;
    if (!onOutcome && _editable) {
      bottomBar = SoftPillButton(
        label: a == null ? 'Save appointment' : 'Update appointment',
        icon: Icons.event_available_rounded,
        loading: _saving,
        onPressed: _saveAppointment,
      );
    } else if (onOutcome && a != null && a.isOpen) {
      bottomBar = SoftPillButton(
        label: _reschedule ? 'Save & reschedule' : 'Save outcome',
        icon: _reschedule ? Icons.event_repeat_rounded : Icons.check_rounded,
        loading: _saving,
        onPressed: _saveOutcome,
      );
    }

    return SoftScaffold(
      title: a == null ? 'Add meeting' : 'Meeting',
      subtitle: a?.partyName,
      bottomBar: bottomBar,
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 0, 20, 8),
            child: Container(
              height: 44,
              padding: const EdgeInsets.all(4),
              decoration: BoxDecoration(
                color: p.surfaceAlt,
                borderRadius: BorderRadius.circular(22),
              ),
              child: TabBar(
                controller: _tabs,
                indicator: BoxDecoration(
                  color: p.pill,
                  borderRadius: BorderRadius.circular(18),
                ),
                indicatorSize: TabBarIndicatorSize.tab,
                dividerColor: Colors.transparent,
                labelColor: p.onPill,
                unselectedLabelColor: p.inkSoft,
                labelStyle: SoftText.heading(p, size: 13.5),
                unselectedLabelStyle: SoftText.heading(p, size: 13.5),
                tabs: [
                  const Tab(text: 'Appointment'),
                  Tab(
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        if (a == null) ...[
                          const Icon(Icons.lock_outline_rounded, size: 14),
                          const SizedBox(width: 4),
                        ],
                        const Text('Outcome'),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
          Expanded(
            child: TabBarView(
              controller: _tabs,
              physics: a == null ? const NeverScrollableScrollPhysics() : null,
              children: [
                _buildAppointmentTab(p),
                a == null ? const SizedBox.shrink() : _buildOutcomeTab(p, a),
              ],
            ),
          ),
        ],
      ),
    );
  }

  /// White form card with a small section heading, matching the Log work form.
  Widget _section(SoftPalette p, String title, IconData icon, List<Widget> children) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: SoftCard(
        radius: 24,
        padding: const EdgeInsets.fromLTRB(18, 16, 18, 20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Icon(icon, size: 17, color: p.accent),
                const SizedBox(width: 8),
                Text(title, style: SoftText.heading(p, size: 15)),
              ],
            ),
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 14),
              child: Divider(height: 1, thickness: 1, color: p.border),
            ),
            ...children,
          ],
        ),
      ),
    );
  }

  Widget _labelled(String label, Widget field, {bool required = false, String? hint}) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [SoftFieldLabel(label, required: required, hint: hint), field],
    );
  }

  Widget _fieldError(SoftPalette p, String text) => Padding(
        padding: const EdgeInsets.only(top: 6, left: 4),
        child: Text(text, style: SoftText.caption(p, size: 12).copyWith(color: p.danger)),
      );

  Widget _buildAppointmentTab(SoftPalette p) {
    final a = _appointment;
    final isClient = _meetWith == MeetWith.existingClient;
    final noun = isClient ? 'client' : 'contact';
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
      child: AbsorbPointer(
        absorbing: !_editable,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (a != null && !a.isOpen) ...[
              _Banner(
                color: p.muted,
                icon: Icons.lock_outline_rounded,
                text: a.isActive
                    ? 'Outcome recorded. Appointment details are locked.'
                    : 'This meeting is ${a.status.label.toLowerCase()}.',
              ),
              const SizedBox(height: 14),
            ],

            // Who
            _section(p, 'Who are you meeting?', Icons.people_alt_outlined, [
              _Segmented<MeetWith>(
                values: MeetWith.values,
                selected: _meetWith,
                labelOf: (w) => w.label,
                onChanged: (w) => setState(() {
                  if (w == _meetWith) return;
                  _meetWith = w;
                  _partyId = null;
                  _partyName = null;
                }),
              ),
              const SizedBox(height: 16),
              _labelled(
                isClient ? 'Client' : 'Contact',
                SoftPickerField(
                  value: _partyName,
                  placeholder: 'Select a $noun',
                  icon: isClient ? Icons.business_center_outlined : Icons.person_outline_rounded,
                  filled: true,
                  hasError: _apptSubmitted && _partyId == null,
                  onTap: _pickParty,
                ),
                required: true,
              ),
              if (_apptSubmitted && _partyId == null) _fieldError(p, 'Please select a $noun'),
              if (!isClient)
                Align(
                  alignment: Alignment.centerLeft,
                  child: TextButton.icon(
                    onPressed: _createContact,
                    icon: const Icon(Icons.person_add_alt_1_rounded, size: 18),
                    label: const Text('Create new contact'),
                    style: TextButton.styleFrom(
                      foregroundColor: p.accent,
                      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 8),
                    ),
                  ),
                ),
            ]),

            // When
            _section(p, 'When', Icons.event_outlined, [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: _labelled(
                      'Date',
                      SoftPickerField(
                        value: DateFormat('EEE, d MMM').format(_date),
                        placeholder: 'Date',
                        icon: Icons.calendar_today_outlined,
                        filled: true,
                        trailing: false,
                        onTap: _pickDate,
                      ),
                      required: true,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: _labelled(
                      'Time',
                      SoftPickerField(
                        value: _time?.format(context),
                        placeholder: 'Select',
                        icon: Icons.schedule_rounded,
                        filled: true,
                        trailing: false,
                        hasError: _apptSubmitted && _time == null,
                        onTap: _pickTime,
                      ),
                      required: true,
                    ),
                  ),
                ],
              ),
              if (_apptSubmitted && _time == null) _fieldError(p, 'Please select a time'),
              const SizedBox(height: 16),
              _labelled(
                'Duration',
                _Segmented<int>(
                  values: _durations,
                  selected: _duration,
                  labelOf: _durationLabel,
                  onChanged: (d) => setState(() => _duration = d),
                ),
              ),
            ]),

            // Details
            _section(p, 'Details', Icons.notes_rounded, [
              _labelled(
                'Meeting mode',
                _Segmented<MeetMode>(
                  values: MeetMode.values,
                  selected: _mode,
                  labelOf: (m) => m.label,
                  iconOf: (m) => m.icon,
                  onChanged: (m) => setState(() => _mode = m),
                ),
              ),
              const SizedBox(height: 16),
              _labelled(
                'Purpose',
                TextField(
                  controller: _purposeController,
                  minLines: 3,
                  maxLines: 5,
                  maxLength: 500,
                  textCapitalization: TextCapitalization.sentences,
                  style: softInputTextStyle(context),
                  decoration: softInputDecoration(
                    context,
                    hint: 'Agenda, documents to discuss...',
                    filled: true,
                    counterText: '',
                  ),
                ),
              ),
            ]),

            if (_apptError != null)
              _Banner(color: p.danger, icon: Icons.error_outline_rounded, text: _apptError!),
            if (a != null && a.isOpen) ...[
              const SizedBox(height: 12),
              SoftPillButton(
                label: 'Cancel meeting',
                variant: SoftPillVariant.danger,
                onPressed: _saving ? null : _cancelMeeting,
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildOutcomeTab(SoftPalette p, Appointment a) {
    final locked = !a.isOpen;
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
      child: AbsorbPointer(
        absorbing: locked,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _section(p, 'Scheduled', Icons.event_note_outlined, [
              SoftInfoRow(
                icon: Icons.calendar_today_rounded,
                label: 'Date & time',
                value: '${DateFormat('EEE, d MMM yyyy').format(a.meetingDate)}'
                    '${a.meetingTime == null ? '' : ', ${DateFormat('h:mm a').format(a.start)}'}',
              ),
              SoftInfoRow(
                icon: a.mode.icon,
                label: 'Mode',
                value: '${a.mode.label} - ${_durationLabel(a.durationMinutes ?? 60)}',
              ),
            ]),
            if (locked) ...[
              _Banner(
                color: p.muted,
                icon: Icons.lock_outline_rounded,
                text: a.isActive
                    ? 'Outcome already recorded.'
                    : 'This meeting is ${a.status.label.toLowerCase()}.',
              ),
              const SizedBox(height: 14),
            ],
            _section(p, 'Outcome', Icons.fact_check_outlined, [
              SwitchListTile.adaptive(
                contentPadding: EdgeInsets.zero,
                value: _reschedule,
                onChanged: (v) => setState(() {
                  _reschedule = v;
                  _outcomeError = null;
                }),
                title: Text('Reschedule this meeting', style: SoftText.heading(p, size: 14.5)),
                subtitle: Text(
                  'Marks this meeting as rescheduled and books a new one.',
                  style: SoftText.caption(p, size: 12.5),
                ),
              ),
              if (_reschedule) ...[
                const SizedBox(height: 12),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: _labelled(
                        'New date',
                        SoftPickerField(
                          value: _reschedDate == null
                              ? null
                              : DateFormat('EEE, d MMM').format(_reschedDate!),
                          placeholder: 'Select',
                          icon: Icons.calendar_today_outlined,
                          filled: true,
                          trailing: false,
                          hasError: _outcomeSubmitted && _reschedDate == null,
                          onTap: _pickReschedDate,
                        ),
                        required: true,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: _labelled(
                        'New time',
                        SoftPickerField(
                          value: _reschedTime?.format(context),
                          placeholder: 'Select',
                          icon: Icons.schedule_rounded,
                          filled: true,
                          trailing: false,
                          hasError: _outcomeSubmitted && _reschedTime == null,
                          onTap: _pickReschedTime,
                        ),
                        required: true,
                      ),
                    ),
                  ],
                ),
              ],
              const SizedBox(height: 16),
              _labelled(
                'Actual time spent',
                SoftPickerField(
                  value: _timeSpent == Duration.zero ? null : _spentLabel(_timeSpent),
                  placeholder: 'Select time spent',
                  icon: Icons.timer_outlined,
                  filled: true,
                  hasError: _outcomeSubmitted && !_reschedule && _timeSpent == Duration.zero,
                  onTap: _pickTimeSpent,
                ),
                required: !_reschedule,
              ),
              const SizedBox(height: 16),
              _labelled(
                'Key person met',
                TextField(
                  controller: _keyPersonController,
                  maxLength: 60,
                  textCapitalization: TextCapitalization.words,
                  style: softInputTextStyle(context),
                  decoration: softInputDecoration(
                    context,
                    hint: 'Name of the person you met',
                    icon: Icons.person_outline_rounded,
                    filled: true,
                    counterText: '',
                  ),
                ),
                required: !_reschedule,
              ),
            ]),
            if (_outcomeError != null)
              _Banner(color: p.danger, icon: Icons.error_outline_rounded, text: _outcomeError!),
          ],
        ),
      ),
    );
  }
}

class _Banner extends StatelessWidget {
  final Color color;
  final IconData icon;
  final String text;
  const _Banner({required this.color, required this.icon, required this.text});

  @override
  Widget build(BuildContext context) {
    final p = SoftPalette.of(context);
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: p.tint(color),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Row(
        children: [
          Icon(icon, color: color, size: 20),
          const SizedBox(width: 10),
          Expanded(child: Text(text, style: SoftText.body(p, color: color))),
        ],
      ),
    );
  }
}

/// Equal-width segmented control on a grey track (one choice of N),
/// styled like the Log work form's From-To / Hrs-Min toggle.
class _Segmented<T> extends StatelessWidget {
  final List<T> values;
  final T selected;
  final String Function(T) labelOf;
  final IconData Function(T)? iconOf;
  final ValueChanged<T> onChanged;

  const _Segmented({
    required this.values,
    required this.selected,
    required this.labelOf,
    required this.onChanged,
    this.iconOf,
  });

  @override
  Widget build(BuildContext context) {
    final p = SoftPalette.of(context);
    final activeBg = p.isDark ? p.accent : const Color(0xFF1E3A8A);
    final activeFg = p.isDark ? p.background : Colors.white;
    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: softFieldFill(p),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Row(
        children: [
          for (final v in values)
            Expanded(
              child: Material(
                color: v == selected ? activeBg : Colors.transparent,
                borderRadius: BorderRadius.circular(11),
                child: InkWell(
                  borderRadius: BorderRadius.circular(11),
                  onTap: () => onChanged(v),
                  child: SizedBox(
                    height: 42,
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        if (iconOf != null) ...[
                          Icon(iconOf!(v), size: 16, color: v == selected ? activeFg : p.muted),
                          const SizedBox(width: 6),
                        ],
                        Flexible(
                          child: Text(
                            labelOf(v),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: SoftText.heading(p, size: 13.5)
                                .copyWith(color: v == selected ? activeFg : p.inkSoft),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}
