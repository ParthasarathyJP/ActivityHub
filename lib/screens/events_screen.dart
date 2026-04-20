import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'dart:typed_data';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';

// ══════════════════════════════════════════════════════════════════════════════
// FIRESTORE SCHEMA (reference)
//
// Events/{EventID}
//   EventID, ClientID, Title, Description, EventDate (String 'YYYY-MM-DD'),
//   Venue, MaxParticipants (int), IsActive (bool), CreatedAt,
//   Status: 'Upcoming' | 'Ongoing' | 'Completed'
//
// EventEnrollments/{EnrollmentID}
//   EnrollmentID, ClientID, EventID, EventTitle,
//   StudentEnrollmentNo, StudentName,
//   EnrolledAt, Score (num?), Feedback (String?),
//   IsActive (bool)
// ══════════════════════════════════════════════════════════════════════════════

// ── Accent colours ─────────────────────────────────────────────────────────────
const _bg       = Color(0xFF0D1B2A);
const _card     = Color(0xFF152232);
const _border   = Color(0xFF1E3347);
const _muted    = Color(0xFF556677);
const _dimmed   = Color(0xFF3A5068);
const _accent   = Color(0xFFE8A020);  // gold for events
const _green    = Color(0xFF1DB954);
const _blue     = Color(0xFF5BA3D9);
const _purple   = Color(0xFF7F77DD);
const _red      = Color(0xFFE74C3C);

// ══════════════════════════════════════════════════════════════════════════════
// EventsTab  — drop-in tab for Client & Staff dashboards
//   isClient: true  → can create / edit / delete events + enter scores
//   isClient: false → view events + enter scores only
// ══════════════════════════════════════════════════════════════════════════════
class EventsTab extends StatefulWidget {
  final String clientId;
  final String staffEnrollNo;   // empty string if client login
  final bool   isClient;

  const EventsTab({
    super.key,
    required this.clientId,
    required this.isClient,
    this.staffEnrollNo = '',
  });

  @override
  State<EventsTab> createState() => _EventsTabState();
}

class _EventsTabState extends State<EventsTab> {
  List<Map<String, dynamic>> _events = [];
  bool _isLoading = true;
  String _filter  = 'All'; // All | Upcoming | Ongoing | Completed

  @override
  void initState() { super.initState(); _load(); }

  Future<void> _load() async {
    setState(() => _isLoading = true);
    try {
      QuerySnapshot snap;
      try {
        snap = await FirebaseFirestore.instance
            .collection('Events')
            .where('ClientID', isEqualTo: widget.clientId)
            .where('IsActive', isEqualTo: true)
            .orderBy('EventDate', descending: false)
            .get();
      } catch (_) {
        snap = await FirebaseFirestore.instance
            .collection('Events')
            .where('ClientID', isEqualTo: widget.clientId)
            .where('IsActive', isEqualTo: true)
            .get();
      }
      if (mounted) setState(() {
        _events = snap.docs.map((d) =>
            {...(d.data() as Map<String, dynamic>), 'DocID': d.id}).toList();
        _isLoading = false;
      });
    } catch (e) {
      debugPrint('Events load error: $e');
      if (mounted) setState(() => _isLoading = false);
    }
  }

  List<Map<String, dynamic>> get _filtered => _filter == 'All'
      ? _events
      : _events.where((e) => e['Status'] == _filter).toList();

  // ── Create / Edit event sheet ───────────────────────────────────────────────
  void _showEventSheet({Map<String, dynamic>? event}) {
    final titleCtrl  = TextEditingController(text: event?['Title'] ?? '');
    final descCtrl   = TextEditingController(text: event?['Description'] ?? '');
    final dateCtrl   = TextEditingController(text: event?['EventDate'] ?? '');
    final venueCtrl  = TextEditingController(text: event?['Venue'] ?? '');
    final maxCtrl    = TextEditingController(
        text: event != null ? '${event['MaxParticipants'] ?? ''}' : '');
    String status    = event?['Status'] ?? 'Upcoming';
    bool saving      = false;
    final isEdit     = event != null;

    showModalBottomSheet(
      context: context, isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => StatefulBuilder(builder: (ctx, ss) => Padding(
        padding: EdgeInsets.only(bottom: MediaQuery.of(ctx).viewInsets.bottom),
        child: Container(
          decoration: const BoxDecoration(color: _card,
              borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
          padding: const EdgeInsets.all(24),
          child: SingleChildScrollView(child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start, children: [
            // Handle
            Center(child: Container(width: 40, height: 4,
                decoration: BoxDecoration(color: _border,
                    borderRadius: BorderRadius.circular(2)))),
            const SizedBox(height: 20),
            // Header
            Row(children: [
              Container(width: 36, height: 36,
                decoration: BoxDecoration(
                    color: _accent.withOpacity(0.12),
                    borderRadius: BorderRadius.circular(10)),
                child: const Icon(Icons.emoji_events_outlined,
                    color: _accent, size: 18)),
              const SizedBox(width: 12),
              Text(isEdit ? 'Edit Event' : 'New Event',
                  style: const TextStyle(fontFamily: 'Georgia', fontSize: 18,
                      fontWeight: FontWeight.bold, color: Colors.white)),
            ]),
            const SizedBox(height: 20),

            _lbl('Event Title *'), const SizedBox(height: 8),
            _tf(ctrl: titleCtrl, hint: 'e.g. Annual Day Competition',
                icon: Icons.title_rounded),
            const SizedBox(height: 12),

            _lbl('Description'), const SizedBox(height: 8),
            TextField(controller: descCtrl, maxLines: 3,
              style: const TextStyle(color: Colors.white, fontSize: 14),
              cursorColor: _accent,
              decoration: InputDecoration(
                hintText: 'Brief description of the event…',
                hintStyle: const TextStyle(color: _dimmed),
                filled: true, fillColor: _bg,
                contentPadding: const EdgeInsets.all(14),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12),
                    borderSide: const BorderSide(color: _border)),
                enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12),
                    borderSide: const BorderSide(color: _border)),
                focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12),
                    borderSide: const BorderSide(color: _accent, width: 1.5)))),
            const SizedBox(height: 12),

            Row(children: [
              Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                _lbl('Event Date *'), const SizedBox(height: 8),
                _tf(ctrl: dateCtrl, hint: 'YYYY-MM-DD',
                    icon: Icons.calendar_today_outlined,
                    kb: TextInputType.datetime),
              ])),
              const SizedBox(width: 12),
              Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                _lbl('Max Participants'), const SizedBox(height: 8),
                _tf(ctrl: maxCtrl, hint: 'e.g. 50',
                    icon: Icons.group_outlined,
                    kb: TextInputType.number),
              ])),
            ]),
            const SizedBox(height: 12),

            _lbl('Venue'), const SizedBox(height: 8),
            _tf(ctrl: venueCtrl, hint: 'Hall / Online / Address',
                icon: Icons.location_on_outlined),
            const SizedBox(height: 14),

            // Status chips
            _lbl('Status'), const SizedBox(height: 8),
            Wrap(spacing: 8, children: ['Upcoming', 'Ongoing', 'Completed'].map((s) {
              final sel = status == s;
              final color = s == 'Upcoming' ? _blue
                  : s == 'Ongoing' ? _green : _muted;
              return GestureDetector(
                onTap: () => ss(() => status = s),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 150),
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
                  decoration: BoxDecoration(
                    color: sel ? color : _bg,
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: sel ? color : _border)),
                  child: Text(s, style: TextStyle(fontSize: 12,
                      color: sel ? Colors.white : const Color(0xFF8899AA)))));
            }).toList()),
            const SizedBox(height: 20),

            // Save button
            SizedBox(width: double.infinity, child: ElevatedButton(
              onPressed: saving ? null : () async {
                if (titleCtrl.text.trim().isEmpty ||
                    dateCtrl.text.trim().isEmpty) return;
                ss(() => saving = true);
                try {
                  final db  = FirebaseFirestore.instance;
                  final max = int.tryParse(maxCtrl.text.trim()) ?? 0;
                  final payload = {
                    'ClientID':         widget.clientId,
                    'Title':            titleCtrl.text.trim(),
                    'Description':      descCtrl.text.trim(),
                    'EventDate':        dateCtrl.text.trim(),
                    'Venue':            venueCtrl.text.trim(),
                    'MaxParticipants':  max,
                    'Status':           status,
                    'IsActive':         true,
                    'UpdatedAt':        FieldValue.serverTimestamp(),
                  };
                  if (isEdit) {
                    await db.collection('Events')
                        .doc(event!['DocID']).update(payload);
                  } else {
                    final ref = db.collection('Events').doc();
                    await ref.set({...payload,
                      'EventID':   ref.id,
                      'CreatedAt': FieldValue.serverTimestamp()});
                  }
                  if (ctx.mounted) Navigator.pop(ctx);
                  await _load();
                } catch (e) { ss(() => saving = false); }
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: _accent, foregroundColor: Colors.white,
                elevation: 0,
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14)),
                padding: const EdgeInsets.symmetric(vertical: 14)),
              child: saving
                  ? const SizedBox(width: 20, height: 20,
                      child: CircularProgressIndicator(
                          color: Colors.white, strokeWidth: 2))
                  : Text(isEdit ? 'Save Changes' : 'Create Event',
                      style: const TextStyle(
                          fontSize: 15, fontWeight: FontWeight.w600)))),
            const SizedBox(height: 8),
          ]))),
        )));
  }

  // ── Delete event ────────────────────────────────────────────────────────────
  Future<void> _deleteEvent(String docId) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: _card,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('Delete Event?',
            style: TextStyle(color: Colors.white, fontFamily: 'Georgia')),
        content: const Text('This will also remove all enrollments.',
            style: TextStyle(color: _muted, fontSize: 13)),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Cancel', style: TextStyle(color: _muted))),
          TextButton(onPressed: () => Navigator.pop(ctx, true),
              child: const Text('Delete',
                  style: TextStyle(color: _red, fontWeight: FontWeight.w600))),
        ]));
    if (confirm != true) return;
    await FirebaseFirestore.instance.collection('Events')
        .doc(docId).update({'IsActive': false});
    await _load();
  }

  @override
  Widget build(BuildContext context) {
    final filtered = _filtered;
    return SafeArea(child: Column(children: [
      // ── Header ──────────────────────────────────────────────────────────────
      Padding(padding: const EdgeInsets.fromLTRB(20, 16, 20, 0),
        child: Row(children: [
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            const Text('Events', style: TextStyle(fontFamily: 'Georgia',
                fontSize: 22, fontWeight: FontWeight.bold, color: Colors.white)),
            Text(widget.isClient
                ? 'Manage competitions & exams'
                : 'Competitions, exams & scoring',
                style: const TextStyle(fontSize: 12, color: _muted)),
          ])),
          if (widget.isClient)
            GestureDetector(
              onTap: () => _showEventSheet(),
              child: Container(width: 40, height: 40,
                decoration: BoxDecoration(
                  color: _accent.withOpacity(0.12),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: _accent.withOpacity(0.3))),
                child: const Icon(Icons.add_rounded, color: _accent, size: 22))),
        ])),

      // ── Filter chips ─────────────────────────────────────────────────────────
      SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.fromLTRB(20, 12, 20, 4),
        child: Row(children: ['All', 'Upcoming', 'Ongoing', 'Completed'].map((f) {
          final active = _filter == f;
          final color = f == 'Upcoming' ? _blue
              : f == 'Ongoing' ? _green
              : f == 'Completed' ? _muted : _accent;
          return GestureDetector(
            onTap: () => setState(() => _filter = f),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              margin: const EdgeInsets.only(right: 8),
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
              decoration: BoxDecoration(
                color: active ? color : _card,
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: active ? color : _border)),
              child: Text(f, style: TextStyle(fontSize: 12,
                  fontWeight: FontWeight.w500,
                  color: active ? Colors.white : const Color(0xFF8899AA)))));
        }).toList())),

      // ── Count ────────────────────────────────────────────────────────────────
      Padding(padding: const EdgeInsets.fromLTRB(20, 4, 20, 8),
        child: Align(alignment: Alignment.centerLeft,
          child: Text('${filtered.length} event${filtered.length == 1 ? '' : 's'}',
              style: const TextStyle(fontSize: 12, color: _muted)))),

      // ── List ─────────────────────────────────────────────────────────────────
      Expanded(child: _isLoading
          ? const Center(child: CircularProgressIndicator(
              color: _accent, strokeWidth: 2))
          : filtered.isEmpty
              ? _emptyState()
              : RefreshIndicator(
                  onRefresh: _load,
                  color: _accent,
                  backgroundColor: _card,
                  child: ListView(
                    padding: const EdgeInsets.fromLTRB(20, 0, 20, 100),
                    children: filtered.map((e) =>
                        _EventCard(
                          event:      e,
                          isClient:   widget.isClient,
                          clientId:   widget.clientId,
                          staffEnrollNo: widget.staffEnrollNo,
                          onEdit:     () => _showEventSheet(event: e),
                          onDelete:   () => _deleteEvent(e['DocID']),
                        )).toList()))),
    ]));
  }

  Widget _emptyState() => Center(child: Column(mainAxisSize: MainAxisSize.min, children: [
    Container(width: 64, height: 64,
      decoration: BoxDecoration(
          color: _accent.withOpacity(0.08),
          borderRadius: BorderRadius.circular(18)),
      child: const Icon(Icons.emoji_events_outlined, color: _dimmed, size: 32)),
    const SizedBox(height: 16),
    const Text('No events yet', style: TextStyle(fontSize: 16,
        color: Colors.white, fontFamily: 'Georgia')),
    const SizedBox(height: 6),
    Text(widget.isClient ? 'Tap + to create an event' : 'Events will appear here',
        style: const TextStyle(fontSize: 12, color: _muted)),
  ]));

  // ── Shared form helpers ──────────────────────────────────────────────────────
  Widget _lbl(String t) => Text(t, style: const TextStyle(
      fontSize: 13, fontWeight: FontWeight.w500, color: Color(0xFF8899AA)));

  Widget _tf({required TextEditingController ctrl, required String hint,
      required IconData icon, TextInputType kb = TextInputType.text}) =>
    TextField(controller: ctrl, keyboardType: kb,
      style: const TextStyle(color: Colors.white, fontSize: 14),
      cursorColor: _accent,
      decoration: InputDecoration(hintText: hint,
        hintStyle: const TextStyle(color: _dimmed),
        prefixIcon: Icon(icon, color: _dimmed, size: 18),
        filled: true, fillColor: _bg,
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12),
            borderSide: const BorderSide(color: _border)),
        enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12),
            borderSide: const BorderSide(color: _border)),
        focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12),
            borderSide: const BorderSide(color: _accent, width: 1.5))));
}

// ══════════════════════════════════════════════════════════════════════════════
// EventCard  — single row in the Events list
// ══════════════════════════════════════════════════════════════════════════════
class _EventCard extends StatelessWidget {
  final Map<String, dynamic> event;
  final bool     isClient;
  final String   clientId;
  final String   staffEnrollNo;
  final VoidCallback onEdit;
  final VoidCallback onDelete;

  const _EventCard({
    required this.event, required this.isClient,
    required this.clientId, required this.staffEnrollNo,
    required this.onEdit, required this.onDelete,
  });

  Color get _statusColor {
    switch (event['Status'] as String? ?? '') {
      case 'Ongoing':   return _green;
      case 'Completed': return _muted;
      default:          return _blue;
    }
  }

  @override
  Widget build(BuildContext context) {
    final title   = event['Title']    as String? ?? '—';
    final date    = event['EventDate'] as String? ?? '';
    final venue   = event['Venue']    as String? ?? '';
    final max     = event['MaxParticipants'] as int? ?? 0;
    final status  = event['Status']   as String? ?? 'Upcoming';

    return GestureDetector(
      onTap: () => Navigator.push(context, MaterialPageRoute(
          builder: (_) => EventDetailScreen(
            event:        event,
            clientId:     clientId,
            isClient:     isClient,
            staffEnrollNo: staffEnrollNo,
          ))),
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: _card, borderRadius: BorderRadius.circular(16),
          border: Border.all(color: _border)),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            Container(width: 44, height: 44,
              decoration: BoxDecoration(
                  color: _accent.withOpacity(0.12),
                  borderRadius: BorderRadius.circular(13)),
              child: const Icon(Icons.emoji_events_outlined,
                  color: _accent, size: 22)),
            const SizedBox(width: 12),
            Expanded(child: Column(
                crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(title, style: const TextStyle(fontSize: 15,
                  fontWeight: FontWeight.w600, color: Colors.white)),
              if (date.isNotEmpty)
                Text(date, style: const TextStyle(
                    fontSize: 11, color: _muted)),
            ])),
            // Status badge
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                  color: _statusColor.withOpacity(0.12),
                  borderRadius: BorderRadius.circular(8)),
              child: Text(status, style: TextStyle(fontSize: 10,
                  fontWeight: FontWeight.w600, color: _statusColor))),
          ]),
          if (venue.isNotEmpty || max > 0) ...[
            const SizedBox(height: 10),
            Row(children: [
              if (venue.isNotEmpty) ...[
                const Icon(Icons.location_on_outlined, color: _dimmed, size: 13),
                const SizedBox(width: 4),
                Expanded(child: Text(venue, style: const TextStyle(
                    fontSize: 11, color: _muted),
                    overflow: TextOverflow.ellipsis)),
              ],
              if (max > 0) ...[
                const Icon(Icons.group_outlined, color: _dimmed, size: 13),
                const SizedBox(width: 4),
                Text('Max $max', style: const TextStyle(
                    fontSize: 11, color: _muted)),
              ],
            ]),
          ],
          // Client action row
          if (isClient) ...[
            const SizedBox(height: 12),
            Row(children: [
              _actionBtn('Edit', Icons.edit_outlined, _blue,
                  onTap: onEdit),
              const SizedBox(width: 8),
              _actionBtn('Delete', Icons.delete_outline_rounded, _red,
                  onTap: onDelete),
              const Spacer(),
              _actionBtn('Participants', Icons.people_outline_rounded, _accent,
                  onTap: () => Navigator.push(context, MaterialPageRoute(
                      builder: (_) => EventParticipantsScreen(
                        event:    event,
                        clientId: clientId,
                        isClient: isClient,
                        staffEnrollNo: staffEnrollNo,
                      )))),
            ]),
          ],
        ])));
  }

  Widget _actionBtn(String label, IconData icon, Color color,
      {required VoidCallback onTap}) =>
    GestureDetector(onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(
          color: color.withOpacity(0.1),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: color.withOpacity(0.25))),
        child: Row(mainAxisSize: MainAxisSize.min, children: [
          Icon(icon, color: color, size: 13),
          const SizedBox(width: 4),
          Text(label, style: TextStyle(fontSize: 11,
              fontWeight: FontWeight.w600, color: color)),
        ])));
}

// ══════════════════════════════════════════════════════════════════════════════
// EventDetailScreen  — tapped from EventCard (read-only detail + enroll CTA)
//   For Client/Staff: jumps straight to participants
//   For Student: shown from StudentEventsTab (separate widget below)
// ══════════════════════════════════════════════════════════════════════════════
class EventDetailScreen extends StatelessWidget {
  final Map<String, dynamic> event;
  final String clientId;
  final bool   isClient;
  final String staffEnrollNo;

  const EventDetailScreen({
    super.key,
    required this.event, required this.clientId,
    required this.isClient, required this.staffEnrollNo,
  });

  @override
  Widget build(BuildContext context) {
    final title   = event['Title']       as String? ?? '—';
    final date    = event['EventDate']   as String? ?? '—';
    final venue   = event['Venue']       as String? ?? '—';
    final desc    = event['Description'] as String? ?? '';
    final max     = event['MaxParticipants'] as int? ?? 0;
    final status  = event['Status']      as String? ?? 'Upcoming';

    final statusColor = status == 'Ongoing' ? _green
        : status == 'Completed' ? _muted : _blue;

    return Scaffold(
      backgroundColor: _bg,
      body: SafeArea(child: Column(children: [
        // Top bar
        Padding(padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          child: Row(children: [
            GestureDetector(onTap: () => Navigator.pop(context),
              child: Container(width: 40, height: 40,
                decoration: BoxDecoration(color: _card,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: _border)),
                child: const Icon(Icons.arrow_back_ios_new_rounded,
                    color: Color(0xFF8899AA), size: 18))),
            const SizedBox(width: 14),
            Expanded(child: Text(title, style: const TextStyle(
                fontFamily: 'Georgia', fontSize: 17,
                fontWeight: FontWeight.bold, color: Colors.white),
                overflow: TextOverflow.ellipsis)),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
              decoration: BoxDecoration(
                  color: statusColor.withOpacity(0.12),
                  borderRadius: BorderRadius.circular(8)),
              child: Text(status, style: TextStyle(fontSize: 11,
                  fontWeight: FontWeight.w600, color: statusColor))),
          ])),

        Expanded(child: ListView(
          padding: const EdgeInsets.fromLTRB(20, 4, 20, 100),
          children: [
            // Banner card
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: _card, borderRadius: BorderRadius.circular(18),
                border: Border.all(color: _border)),
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Center(child: Container(width: 64, height: 64,
                  decoration: BoxDecoration(
                      color: _accent.withOpacity(0.12),
                      borderRadius: BorderRadius.circular(18)),
                  child: const Icon(Icons.emoji_events_outlined,
                      color: _accent, size: 32))),
                const SizedBox(height: 16),
                _row(Icons.calendar_today_outlined, 'Date', date),
                if (venue.isNotEmpty) ...[
                  const SizedBox(height: 10),
                  _row(Icons.location_on_outlined, 'Venue', venue),
                ],
                if (max > 0) ...[
                  const SizedBox(height: 10),
                  _row(Icons.group_outlined, 'Capacity', '$max participants'),
                ],
                if (desc.isNotEmpty) ...[
                  const Divider(color: _border, height: 24),
                  Text(desc, style: const TextStyle(
                      fontSize: 13, color: _muted, height: 1.5)),
                ],
              ])),
            const SizedBox(height: 16),

            // View participants (client/staff)
            if (isClient || staffEnrollNo.isNotEmpty)
              _primaryBtn(
                label: 'View Participants & Scores',
                icon: Icons.people_outline_rounded,
                color: _accent,
                onTap: () => Navigator.push(context, MaterialPageRoute(
                    builder: (_) => EventParticipantsScreen(
                      event:         event,
                      clientId:      clientId,
                      isClient:      isClient,
                      staffEnrollNo: staffEnrollNo,
                    )))),
          ])),
      ])));
  }

  Widget _row(IconData icon, String label, String value) =>
    Row(children: [
      Icon(icon, color: _dimmed, size: 16),
      const SizedBox(width: 10),
      Text(label, style: const TextStyle(fontSize: 12, color: _muted)),
      const SizedBox(width: 8),
      Expanded(child: Text(value, style: const TextStyle(
          fontSize: 13, fontWeight: FontWeight.w500, color: Colors.white),
          textAlign: TextAlign.right)),
    ]);

  Widget _primaryBtn({required String label, required IconData icon,
      required Color color, required VoidCallback onTap}) =>
    GestureDetector(onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: color.withOpacity(0.1),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: color.withOpacity(0.3))),
        child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
          Icon(icon, color: color, size: 20),
          const SizedBox(width: 8),
          Text(label, style: TextStyle(fontSize: 14,
              fontWeight: FontWeight.w600, color: color)),
        ])));
}

// ══════════════════════════════════════════════════════════════════════════════
// EventParticipantsScreen
//   Lists all enrolled students; Client/Staff can enter Score + Feedback
// ══════════════════════════════════════════════════════════════════════════════
class EventParticipantsScreen extends StatefulWidget {
  final Map<String, dynamic> event;
  final String clientId;
  final bool   isClient;
  final String staffEnrollNo;

  const EventParticipantsScreen({
    super.key,
    required this.event, required this.clientId,
    required this.isClient, required this.staffEnrollNo,
  });

  @override
  State<EventParticipantsScreen> createState() =>
      _EventParticipantsScreenState();
}

class _EventParticipantsScreenState
    extends State<EventParticipantsScreen> {
  List<Map<String, dynamic>> _enrollments = [];
  bool _isLoading = true;

  @override
  void initState() { super.initState(); _load(); }

  Future<void> _load() async {
    setState(() => _isLoading = true);
    try {
      final snap = await FirebaseFirestore.instance
          .collection('EventEnrollments')
          .where('ClientID', isEqualTo: widget.clientId)
          .where('EventID',  isEqualTo: widget.event['DocID'])
          .where('IsActive', isEqualTo: true)
          .get();
      if (mounted) setState(() {
        _enrollments = snap.docs.map((d) =>
            {...(d.data() as Map<String, dynamic>), 'DocID': d.id}).toList();
        _isLoading = false;
      });
    } catch (e) {
      debugPrint('Participants load error: $e');
      if (mounted) setState(() => _isLoading = false);
    }
  }

  // ── Score + Feedback sheet ──────────────────────────────────────────────────
  void _showScoreSheet(Map<String, dynamic> enr) {
    final scoreCtrl = TextEditingController(
        text: enr['Score'] != null ? '${enr['Score']}' : '');
    final fbCtrl = TextEditingController(
        text: enr['Feedback'] as String? ?? '');
    bool saving = false;

    showModalBottomSheet(
      context: context, isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => StatefulBuilder(builder: (ctx, ss) => Padding(
        padding: EdgeInsets.only(bottom: MediaQuery.of(ctx).viewInsets.bottom),
        child: Container(
          decoration: const BoxDecoration(color: _card,
              borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
          padding: const EdgeInsets.all(24),
          child: Column(mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start, children: [
            Center(child: Container(width: 40, height: 4,
                decoration: BoxDecoration(color: _border,
                    borderRadius: BorderRadius.circular(2)))),
            const SizedBox(height: 20),
            Text(enr['StudentName'] as String? ?? '—',
                style: const TextStyle(fontFamily: 'Georgia', fontSize: 18,
                    fontWeight: FontWeight.bold, color: Colors.white)),
            Text(enr['StudentEnrollmentNo'] as String? ?? '',
                style: const TextStyle(fontSize: 12, color: _muted)),
            const SizedBox(height: 20),

            const Text('Score', style: TextStyle(fontSize: 13,
                fontWeight: FontWeight.w500, color: Color(0xFF8899AA))),
            const SizedBox(height: 8),
            TextField(controller: scoreCtrl, keyboardType: TextInputType.number,
              style: const TextStyle(color: Colors.white, fontSize: 14),
              cursorColor: _green,
              decoration: InputDecoration(hintText: 'e.g. 85',
                hintStyle: const TextStyle(color: _dimmed),
                prefixIcon: const Icon(Icons.star_outline_rounded,
                    color: _dimmed, size: 18),
                filled: true, fillColor: _bg,
                contentPadding: const EdgeInsets.symmetric(
                    horizontal: 16, vertical: 12),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12),
                    borderSide: const BorderSide(color: _border)),
                enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: const BorderSide(color: _border)),
                focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: const BorderSide(color: _green, width: 1.5)))),
            const SizedBox(height: 12),

            const Text('Feedback', style: TextStyle(fontSize: 13,
                fontWeight: FontWeight.w500, color: Color(0xFF8899AA))),
            const SizedBox(height: 8),
            TextField(controller: fbCtrl, maxLines: 3,
              style: const TextStyle(color: Colors.white, fontSize: 14),
              cursorColor: _green,
              decoration: InputDecoration(
                hintText: 'Remarks / feedback for the student…',
                hintStyle: const TextStyle(color: _dimmed),
                filled: true, fillColor: _bg,
                contentPadding: const EdgeInsets.all(14),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12),
                    borderSide: const BorderSide(color: _border)),
                enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: const BorderSide(color: _border)),
                focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: const BorderSide(color: _green, width: 1.5)))),
            const SizedBox(height: 20),

            SizedBox(width: double.infinity, child: ElevatedButton(
              onPressed: saving ? null : () async {
                ss(() => saving = true);
                try {
                  await FirebaseFirestore.instance
                      .collection('EventEnrollments')
                      .doc(enr['DocID'])
                      .update({
                    'Score':    double.tryParse(scoreCtrl.text.trim()),
                    'Feedback': fbCtrl.text.trim(),
                    'ScoredAt': FieldValue.serverTimestamp(),
                    'ScoredBy': widget.isClient ? 'Client' : widget.staffEnrollNo,
                  });
                  if (ctx.mounted) Navigator.pop(ctx);
                  await _load();
                } catch (e) { ss(() => saving = false); }
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: _green, foregroundColor: Colors.white,
                elevation: 0,
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14)),
                padding: const EdgeInsets.symmetric(vertical: 14)),
              child: saving
                  ? const SizedBox(width: 20, height: 20,
                      child: CircularProgressIndicator(
                          color: Colors.white, strokeWidth: 2))
                  : const Text('Save Score & Feedback',
                      style: TextStyle(
                          fontSize: 15, fontWeight: FontWeight.w600)))),
            const SizedBox(height: 8),
          ])))));
  }

  @override
  Widget build(BuildContext context) {
    final title = widget.event['Title'] as String? ?? 'Event';
    return Scaffold(
      backgroundColor: _bg,
      body: SafeArea(child: Column(children: [
        // Top bar
        Padding(padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          child: Row(children: [
            GestureDetector(onTap: () => Navigator.pop(context),
              child: Container(width: 40, height: 40,
                decoration: BoxDecoration(color: _card,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: _border)),
                child: const Icon(Icons.arrow_back_ios_new_rounded,
                    color: Color(0xFF8899AA), size: 18))),
            const SizedBox(width: 14),
            Expanded(child: Column(
                crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(title, style: const TextStyle(fontFamily: 'Georgia',
                  fontSize: 17, fontWeight: FontWeight.bold, color: Colors.white),
                  overflow: TextOverflow.ellipsis),
              Text('${_enrollments.length} Enrolled',
                  style: const TextStyle(fontSize: 11, color: _muted)),
            ])),
          ])),

        // List
        Expanded(child: _isLoading
            ? const Center(child: CircularProgressIndicator(
                color: _green, strokeWidth: 2))
            : _enrollments.isEmpty
                ? Center(child: Column(mainAxisSize: MainAxisSize.min, children: [
                    Container(width: 64, height: 64,
                      decoration: BoxDecoration(
                          color: _accent.withOpacity(0.08),
                          borderRadius: BorderRadius.circular(18)),
                      child: const Icon(Icons.people_outline_rounded,
                          color: _dimmed, size: 32)),
                    const SizedBox(height: 12),
                    const Text('No enrollments yet',
                        style: TextStyle(fontSize: 15, color: Colors.white,
                            fontFamily: 'Georgia')),
                  ]))
                : ListView(
                    padding: const EdgeInsets.fromLTRB(20, 0, 20, 100),
                    children: _enrollments.map((e) {
                      final name   = e['StudentName'] as String? ?? '—';
                      final enrNo  = e['StudentEnrollmentNo'] as String? ?? '';
                      final score  = e['Score'];
                      final fb     = e['Feedback'] as String? ?? '';
                      final hasScore = score != null;

                      return Container(
                        margin: const EdgeInsets.only(bottom: 10),
                        padding: const EdgeInsets.all(14),
                        decoration: BoxDecoration(
                          color: _card,
                          borderRadius: BorderRadius.circular(14),
                          border: Border.all(color: hasScore
                              ? _green.withOpacity(0.3) : _border)),
                        child: Row(children: [
                          Container(width: 42, height: 42,
                            decoration: BoxDecoration(
                              color: _blue.withOpacity(0.12),
                              borderRadius: BorderRadius.circular(12)),
                            child: Center(child: Text(
                                name.substring(0, 1).toUpperCase(),
                                style: const TextStyle(fontSize: 18,
                                    fontWeight: FontWeight.bold, color: _blue)))),
                          const SizedBox(width: 12),
                          Expanded(child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                            Text(name, style: const TextStyle(fontSize: 14,
                                fontWeight: FontWeight.w500, color: Colors.white)),
                            Text(enrNo, style: const TextStyle(
                                fontSize: 10, color: _dimmed)),
                            if (fb.isNotEmpty) ...[
                              const SizedBox(height: 4),
                              Text(fb, style: const TextStyle(
                                  fontSize: 11, color: _muted),
                                  maxLines: 1, overflow: TextOverflow.ellipsis),
                            ],
                          ])),
                          // Score badge + edit button
                          Column(crossAxisAlignment: CrossAxisAlignment.end,
                              children: [
                            if (hasScore)
                              Container(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 10, vertical: 4),
                                decoration: BoxDecoration(
                                    color: _green.withOpacity(0.12),
                                    borderRadius: BorderRadius.circular(8)),
                                child: Text('$score',
                                    style: const TextStyle(fontSize: 14,
                                        fontWeight: FontWeight.bold,
                                        color: _green))),
                            const SizedBox(height: 6),
                            GestureDetector(
                              onTap: () => _showScoreSheet(e),
                              child: Container(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 8, vertical: 4),
                                decoration: BoxDecoration(
                                  color: _accent.withOpacity(0.1),
                                  borderRadius: BorderRadius.circular(7),
                                  border: Border.all(
                                      color: _accent.withOpacity(0.25))),
                                child: Text(hasScore ? 'Edit' : 'Score',
                                    style: const TextStyle(fontSize: 11,
                                        fontWeight: FontWeight.w600,
                                        color: _accent)))),
                          ]),
                        ]));
                    }).toList())),
      ])));
  }
}

// ══════════════════════════════════════════════════════════════════════════════
// StudentEventsTab  — Events tab inside the Student Dashboard
//   Shows all events; student can enroll, view their score/feedback,
//   and download a participation certificate (PDF on-the-fly)
// ══════════════════════════════════════════════════════════════════════════════
class StudentEventsTab extends StatefulWidget {
  final String clientId;
  final String studentEnrollNo;
  final String studentName;

  const StudentEventsTab({
    super.key,
    required this.clientId,
    required this.studentEnrollNo,
    required this.studentName,
  });

  @override
  State<StudentEventsTab> createState() => _StudentEventsTabState();
}

class _StudentEventsTabState extends State<StudentEventsTab> {
  List<Map<String, dynamic>> _events        = [];
  Set<String>                _enrolledIds   = {};
  Map<String, Map<String, dynamic>> _myEnrollments = {}; // eventId → enrollment
  bool _isLoading = true;
  String _filter  = 'All';

  @override
  void initState() { super.initState(); _load(); }

  Future<void> _load() async {
    setState(() => _isLoading = true);
    try {
      final results = await Future.wait([
        // All active events for client
        FirebaseFirestore.instance.collection('Events')
            .where('ClientID', isEqualTo: widget.clientId)
            .where('IsActive', isEqualTo: true)
            .get(),
        // My enrollments
        FirebaseFirestore.instance.collection('EventEnrollments')
            .where('ClientID',           isEqualTo: widget.clientId)
            .where('StudentEnrollmentNo', isEqualTo: widget.studentEnrollNo)
            .where('IsActive',           isEqualTo: true)
            .get(),
      ]);
      final evSnap  = results[0] as QuerySnapshot;
      final enrSnap = results[1] as QuerySnapshot;

      final enrolledMap = <String, Map<String, dynamic>>{};
      for (final d in enrSnap.docs) {
        final data = {...(d.data() as Map<String, dynamic>), 'DocID': d.id};
        enrolledMap[data['EventID'] as String? ?? ''] = data;
      }

      if (mounted) setState(() {
        _events = evSnap.docs.map((d) =>
            {...(d.data() as Map<String, dynamic>), 'DocID': d.id}).toList();
        _enrolledIds   = enrolledMap.keys.toSet();
        _myEnrollments = enrolledMap;
        _isLoading     = false;
      });
    } catch (e) {
      debugPrint('Student events load error: $e');
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _enroll(Map<String, dynamic> event) async {
    final eventId = event['DocID'] as String;
    try {
      final db  = FirebaseFirestore.instance;
      final ref = db.collection('EventEnrollments').doc();
      await ref.set({
        'EnrollmentID':       ref.id,
        'ClientID':           widget.clientId,
        'EventID':            eventId,
        'EventTitle':         event['Title'] ?? '',
        'StudentEnrollmentNo': widget.studentEnrollNo,
        'StudentName':        widget.studentName,
        'EnrolledAt':         FieldValue.serverTimestamp(),
        'Score':              null,
        'Feedback':           null,
        'IsActive':           true,
      });
      await _load();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: const Text('Enrolled successfully!',
              style: TextStyle(color: Colors.white)),
          backgroundColor: _green,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          margin: const EdgeInsets.all(16)));
      }
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text('Enrollment failed: $e'),
          backgroundColor: _red));
    }
  }

  Future<void> _downloadCertificate(Map<String, dynamic> event,
      Map<String, dynamic> enrollment) async {
    final score = enrollment['Score'];
    final pdf   = pw.Document();

    pdf.addPage(pw.Page(
      pageFormat: PdfPageFormat.a4.landscape,
      margin: const pw.EdgeInsets.all(40),
      build: (ctx) => pw.Stack(children: [
        // Outer border
        pw.Container(
          decoration: pw.BoxDecoration(
            border: pw.Border.all(color: PdfColors.amber700, width: 4)),
        ),
        // Inner decorative border
        pw.Padding(padding: const pw.EdgeInsets.all(12),
          child: pw.Container(
            decoration: pw.BoxDecoration(
              border: pw.Border.all(color: PdfColors.amber400, width: 1.5)),
          )),
        // Content
        pw.Center(child: pw.Column(
            mainAxisAlignment: pw.MainAxisAlignment.center,
            children: [
          pw.Text('🏆', style: pw.TextStyle(fontSize: 40)),
          pw.SizedBox(height: 12),
          pw.Text('CERTIFICATE OF PARTICIPATION',
              style: pw.TextStyle(fontSize: 20,
                  fontWeight: pw.FontWeight.bold,
                  color: PdfColors.amber700,
                  letterSpacing: 2)),
          pw.SizedBox(height: 8),
          pw.Text('This is to certify that',
              style: pw.TextStyle(fontSize: 13, color: PdfColors.grey600)),
          pw.SizedBox(height: 14),
          pw.Text(widget.studentName,
              style: pw.TextStyle(fontSize: 28,
                  fontWeight: pw.FontWeight.bold,
                  color: PdfColors.grey900)),
          pw.SizedBox(height: 4),
          pw.Text('(${widget.studentEnrollNo})',
              style: pw.TextStyle(fontSize: 11, color: PdfColors.grey500)),
          pw.SizedBox(height: 14),
          pw.Text('has participated in',
              style: pw.TextStyle(fontSize: 13, color: PdfColors.grey600)),
          pw.SizedBox(height: 8),
          pw.Text(event['Title'] as String? ?? '—',
              style: pw.TextStyle(fontSize: 20,
                  fontWeight: pw.FontWeight.bold, color: PdfColors.grey800),
              textAlign: pw.TextAlign.center),
          pw.SizedBox(height: 6),
          if ((event['EventDate'] as String? ?? '').isNotEmpty)
            pw.Text('held on ${event['EventDate']}',
                style: pw.TextStyle(fontSize: 12, color: PdfColors.grey600)),
          if ((event['Venue'] as String? ?? '').isNotEmpty)
            pw.Text('at ${event['Venue']}',
                style: pw.TextStyle(fontSize: 12, color: PdfColors.grey600)),
          if (score != null) ...[
            pw.SizedBox(height: 16),
            pw.Container(
              padding: const pw.EdgeInsets.symmetric(
                  horizontal: 24, vertical: 10),
              decoration: pw.BoxDecoration(
                color: PdfColors.green50,
                border: pw.Border.all(color: PdfColors.green700, width: 1.5),
                borderRadius: pw.BorderRadius.circular(8)),
              child: pw.Text('Score: $score',
                  style: pw.TextStyle(fontSize: 16,
                      fontWeight: pw.FontWeight.bold,
                      color: PdfColors.green700))),
          ],
          pw.SizedBox(height: 24),
          pw.Divider(color: PdfColors.amber400, thickness: 0.8),
          pw.SizedBox(height: 8),
          pw.Text('ActivityHub · ${DateTime.now().year}',
              style: pw.TextStyle(fontSize: 10, color: PdfColors.grey400)),
        ])),
      ])));

    await Printing.layoutPdf(
      onLayout: (_) async => pdf.save(),
      name: 'Certificate_${widget.studentName.replaceAll(' ', '_')}_'
            '${(event['Title'] as String? ?? 'Event').replaceAll(' ', '_')}.pdf',
    );
  }

  List<Map<String, dynamic>> get _filtered => _filter == 'All'
      ? _events
      : _events.where((e) => e['Status'] == _filter).toList();

  @override
  Widget build(BuildContext context) {
    final filtered = _filtered;
    return SafeArea(child: Column(children: [
      // Header
      const Padding(
        padding: EdgeInsets.fromLTRB(20, 16, 20, 0),
        child: Row(children: [
          Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text('Events', style: TextStyle(fontFamily: 'Georgia',
                fontSize: 22, fontWeight: FontWeight.bold, color: Colors.white)),
            Text('Enroll, view scores & certificates',
                style: TextStyle(fontSize: 12, color: _muted)),
          ]),
        ])),

      // Filter chips
      SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.fromLTRB(20, 12, 20, 4),
        child: Row(children: ['All', 'Upcoming', 'Ongoing', 'Completed'].map((f) {
          final active = _filter == f;
          final color = f == 'Upcoming' ? _blue
              : f == 'Ongoing' ? _green
              : f == 'Completed' ? _muted : _accent;
          return GestureDetector(
            onTap: () => setState(() => _filter = f),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              margin: const EdgeInsets.only(right: 8),
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
              decoration: BoxDecoration(
                color: active ? color : _card,
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: active ? color : _border)),
              child: Text(f, style: TextStyle(fontSize: 12,
                  fontWeight: FontWeight.w500,
                  color: active ? Colors.white
                      : const Color(0xFF8899AA)))));
        }).toList())),

      // List
      Expanded(child: _isLoading
          ? const Center(child: CircularProgressIndicator(
              color: _accent, strokeWidth: 2))
          : filtered.isEmpty
              ? Center(child: Column(mainAxisSize: MainAxisSize.min, children: [
                  Container(width: 64, height: 64,
                    decoration: BoxDecoration(
                        color: _accent.withOpacity(0.08),
                        borderRadius: BorderRadius.circular(18)),
                    child: const Icon(Icons.emoji_events_outlined,
                        color: _dimmed, size: 32)),
                  const SizedBox(height: 12),
                  const Text('No events yet', style: TextStyle(
                      fontSize: 16, color: Colors.white, fontFamily: 'Georgia')),
                ]))
              : RefreshIndicator(
                  onRefresh: _load,
                  color: _accent, backgroundColor: _card,
                  child: ListView(
                    padding: const EdgeInsets.fromLTRB(20, 0, 20, 100),
                    children: filtered.map((event) {
                      final eventId   = event['DocID'] as String;
                      final isEnrolled = _enrolledIds.contains(eventId);
                      final enrollment = _myEnrollments[eventId];
                      final score     = enrollment?['Score'];
                      final feedback  = enrollment?['Feedback'] as String? ?? '';
                      final status    = event['Status'] as String? ?? 'Upcoming';
                      final isCompleted = status == 'Completed';

                      return _StudentEventCard(
                        event:       event,
                        isEnrolled:  isEnrolled,
                        score:       score,
                        feedback:    feedback,
                        isCompleted: isCompleted,
                        onEnroll:    () => _enroll(event),
                        onCertificate: (enrollment != null)
                            ? () => _downloadCertificate(event, enrollment)
                            : null,
                      );
                    }).toList()))),
    ]));
  }
}

// ── Student event card ────────────────────────────────────────────────────────
class _StudentEventCard extends StatelessWidget {
  final Map<String, dynamic> event;
  final bool     isEnrolled;
  final dynamic  score;
  final String   feedback;
  final bool     isCompleted;
  final VoidCallback          onEnroll;
  final VoidCallback?         onCertificate;

  const _StudentEventCard({
    required this.event, required this.isEnrolled,
    required this.score, required this.feedback,
    required this.isCompleted, required this.onEnroll,
    this.onCertificate,
  });

  @override
  Widget build(BuildContext context) {
    final title  = event['Title']     as String? ?? '—';
    final date   = event['EventDate'] as String? ?? '';
    final venue  = event['Venue']     as String? ?? '';
    final status = event['Status']    as String? ?? 'Upcoming';

    final statusColor = status == 'Ongoing' ? _green
        : status == 'Completed' ? _muted : _blue;

    return Container(
      margin: const EdgeInsets.only(bottom: 14),
      decoration: BoxDecoration(
        color: _card, borderRadius: BorderRadius.circular(16),
        border: Border.all(
            color: isEnrolled ? _green.withOpacity(0.3) : _border)),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        // Header
        Padding(padding: const EdgeInsets.all(16),
          child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Container(width: 44, height: 44,
              decoration: BoxDecoration(
                  color: _accent.withOpacity(0.12),
                  borderRadius: BorderRadius.circular(13)),
              child: const Icon(Icons.emoji_events_outlined,
                  color: _accent, size: 22)),
            const SizedBox(width: 12),
            Expanded(child: Column(
                crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(title, style: const TextStyle(fontSize: 15,
                  fontWeight: FontWeight.w600, color: Colors.white)),
              if (date.isNotEmpty)
                Text(date, style: const TextStyle(
                    fontSize: 11, color: _muted)),
              if (venue.isNotEmpty)
                Text(venue, style: const TextStyle(
                    fontSize: 11, color: _muted)),
            ])),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                  color: statusColor.withOpacity(0.12),
                  borderRadius: BorderRadius.circular(8)),
              child: Text(status, style: TextStyle(fontSize: 10,
                  fontWeight: FontWeight.w600, color: statusColor))),
          ])),

        // Score + Feedback (if scored)
        if (isEnrolled && score != null) ...[
          const Divider(color: _border, height: 1),
          Padding(padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
            child: Row(children: [
              Container(width: 48, height: 48,
                decoration: BoxDecoration(
                  color: _green.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(14)),
                child: Center(child: Text('$score',
                    style: const TextStyle(fontSize: 18,
                        fontWeight: FontWeight.bold, color: _green)))),
              const SizedBox(width: 12),
              Expanded(child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start, children: [
                const Text('Your Score',
                    style: TextStyle(fontSize: 11, color: _muted)),
                if (feedback.isNotEmpty) ...[
                  const SizedBox(height: 4),
                  Text(feedback, style: const TextStyle(
                      fontSize: 12, color: Colors.white, height: 1.4),
                      maxLines: 2, overflow: TextOverflow.ellipsis),
                ],
              ])),
            ])),
        ],

        // Action row
        Padding(padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
          child: Row(children: [
            if (!isEnrolled && !isCompleted)
              Expanded(child: _btn('Enroll Now', Icons.how_to_reg_rounded,
                  _accent, onEnroll))
            else if (isEnrolled)
              Expanded(child: _enrolledBadge()),
            if (isEnrolled && isCompleted && onCertificate != null) ...[
              const SizedBox(width: 8),
              _btn('Certificate', Icons.download_outlined,
                  _purple, onCertificate!),
            ],
          ])),
      ]));
  }

  Widget _enrolledBadge() => Container(
    padding: const EdgeInsets.symmetric(vertical: 10),
    decoration: BoxDecoration(
      color: _green.withOpacity(0.08),
      borderRadius: BorderRadius.circular(12),
      border: Border.all(color: _green.withOpacity(0.2))),
    child: const Row(mainAxisAlignment: MainAxisAlignment.center, children: [
      Icon(Icons.check_circle_outline_rounded, color: _green, size: 16),
      SizedBox(width: 6),
      Text('Enrolled', style: TextStyle(fontSize: 13,
          fontWeight: FontWeight.w600, color: _green)),
    ]));

  Widget _btn(String label, IconData icon, Color color, VoidCallback onTap) =>
    GestureDetector(onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 16),
        decoration: BoxDecoration(
          color: color.withOpacity(0.1),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: color.withOpacity(0.3))),
        child: Row(mainAxisAlignment: MainAxisAlignment.center,
            mainAxisSize: MainAxisSize.min, children: [
          Icon(icon, color: color, size: 16),
          const SizedBox(width: 6),
          Text(label, style: TextStyle(fontSize: 13,
              fontWeight: FontWeight.w600, color: color)),
        ])));
}