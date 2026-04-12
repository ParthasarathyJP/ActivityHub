import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

// ══════════════════════════════════════════════════════════════════════════════
// Staff Schedule Screen — accessed from Staff card
// Shows all course schedule assignments for a staff member
// ══════════════════════════════════════════════════════════════════════════════
class StaffScheduleScreen extends StatefulWidget {
  final String clientId;
  final String branchId;
  final Map<String, dynamic> staff;

  const StaffScheduleScreen({
    super.key,
    required this.clientId,
    required this.branchId,
    required this.staff,
  });

  @override
  State<StaffScheduleScreen> createState() => _StaffScheduleScreenState();
}

class _StaffScheduleScreenState extends State<StaffScheduleScreen> {
  List<Map<String, dynamic>> _assignments   = [];
  List<Map<String, dynamic>> _schedules     = []; // all active CourseSchedules
  List<Map<String, dynamic>> _courses       = []; // for name lookup
  List<Map<String, dynamic>> _timings       = []; // SubType Timings
  bool _isLoading = true;

  @override
  void initState() { super.initState(); _load(); }

  Future<void> _load() async {
    setState(() => _isLoading = true);
    try {
      final db = FirebaseFirestore.instance;
      final enrollNo = widget.staff['StaffEnrollmentNo'] as String? ?? '';

      // Load existing assignments for this staff
      QuerySnapshot? assignSnap;
      try {
        assignSnap = await db.collection('StaffCourseSchedule')
            .where('ClientID', isEqualTo: widget.clientId)
            .where('StaffEnrollmentNo', isEqualTo: enrollNo)
            .orderBy('CreatedAt')
            .get();
      } catch (_) {
        assignSnap = await db.collection('StaffCourseSchedule')
            .where('ClientID', isEqualTo: widget.clientId)
            .where('StaffEnrollmentNo', isEqualTo: enrollNo)
            .get();
      }

      // Load all active course schedules for selection
      QuerySnapshot? scheduleSnap;
      try {
        scheduleSnap = await db.collection('CourseSchedule')
            .where('ClientID', isEqualTo: widget.clientId)
            .where('IsActive', isEqualTo: true)
            .orderBy('CreatedAt')
            .get();
      } catch (_) {
        scheduleSnap = await db.collection('CourseSchedule')
            .where('ClientID', isEqualTo: widget.clientId)
            .where('IsActive', isEqualTo: true)
            .get();
      }

      // Load courses + timings for display
      final results = await Future.wait([
        db.collection('Course')
            .where('ClientID', isEqualTo: widget.clientId)
            .get(),
        db.collection('SubType')
            .where('ClientID', isEqualTo: widget.clientId)
            .where('SubTypeCode', isEqualTo: 'Timings')
            .where('IsActive', isEqualTo: true)
            .get(),
      ]);

      if (mounted) {
        setState(() {
          _assignments = assignSnap!.docs
              .map((d) => {...(d.data() as Map<String,dynamic>), 'DocID': d.id})
              .toList();
          _schedules = scheduleSnap!.docs
              .map((d) => {...(d.data() as Map<String,dynamic>), 'DocID': d.id})
              .toList();
          _courses  = (results[0] as QuerySnapshot).docs
              .map((d) => {...(d.data() as Map<String,dynamic>), 'DocID': d.id})
              .toList();
          _timings  = (results[1] as QuerySnapshot).docs
              .map((d) => {...(d.data() as Map<String,dynamic>), 'DocID': d.id})
              .toList();
          _isLoading = false;
        });
      }
    } catch (e) {
      debugPrint('StaffSchedule load error: $e');
      if (mounted) setState(() => _isLoading = false);
    }
  }

  String _courseName(String? courseId) {
    if (courseId == null) return '—';
    final c = _courses.firstWhere((c) => c['DocID'] == courseId, orElse: () => {});
    return c['CourseName'] ?? '—';
  }

  String _timingName(String? timingId) {
    if (timingId == null) return '—';
    final t = _timings.firstWhere((t) => t['DocID'] == timingId, orElse: () => {});
    return t['SubTypeName'] ?? '—';
  }

  Map<String, dynamic> _scheduleById(String? id) {
    if (id == null) return {};
    return _schedules.firstWhere((s) => s['DocID'] == id, orElse: () => {});
  }

  // Schedules not yet assigned to this staff
  List<Map<String, dynamic>> get _unassignedSchedules {
    final assignedIds = _assignments.map((a) => a['CourseScheduleID'] as String?).toSet();
    return _schedules.where((s) => !assignedIds.contains(s['DocID'])).toList();
  }

  @override
  Widget build(BuildContext context) {
    final roleName = widget.staff['Role'] ?? '';
    Color roleColor = const Color(0xFF5BA3D9);
    if (roleName == 'Teacher') roleColor = const Color(0xFF7F77DD);
    if (roleName == 'Coach')   roleColor = const Color(0xFFE8A020);

    return Scaffold(
      backgroundColor: const Color(0xFF0D1B2A),
      body: Stack(children: [
        _bgCircles(),
        SafeArea(child: Column(children: [
          // Top bar
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            child: Row(children: [
              GestureDetector(
                onTap: () => Navigator.pop(context),
                child: Container(
                  width: 40, height: 40,
                  decoration: BoxDecoration(
                    color: const Color(0xFF152232),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: const Color(0xFF1E3347))),
                  child: const Icon(Icons.arrow_back_ios_new_rounded,
                      color: Color(0xFF8899AA), size: 18))),
              const SizedBox(width: 14),
              // Staff avatar + name
              Container(
                width: 36, height: 36,
                decoration: BoxDecoration(
                  color: roleColor.withOpacity(0.15),
                  borderRadius: BorderRadius.circular(10)),
                child: Center(child: Text(
                  (widget.staff['StaffName'] ?? 'S').substring(0, 1).toUpperCase(),
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: roleColor)))),
              const SizedBox(width: 10),
              Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(widget.staff['StaffName'] ?? '',
                    style: const TextStyle(fontFamily: 'Georgia', fontSize: 17,
                        fontWeight: FontWeight.bold, color: Colors.white)),
                Text('${widget.staff['StaffEnrollmentNo'] ?? ''} · $roleName',
                    style: const TextStyle(fontSize: 11, color: Color(0xFF556677))),
              ])),
              // Add assignment button
              GestureDetector(
                onTap: _unassignedSchedules.isEmpty ? null : _showAssignSheet,
                child: Container(
                  width: 40, height: 40,
                  decoration: BoxDecoration(
                    color: _unassignedSchedules.isEmpty
                        ? const Color(0xFF1E3347)
                        : const Color(0xFF1DB954).withOpacity(0.12),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: _unassignedSchedules.isEmpty
                          ? const Color(0xFF1E3347)
                          : const Color(0xFF1DB954).withOpacity(0.3))),
                  child: Icon(Icons.add_rounded,
                      color: _unassignedSchedules.isEmpty
                          ? const Color(0xFF3A5068)
                          : const Color(0xFF1DB954),
                      size: 22))),
            ])),

          // Section title
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 4, 20, 12),
            child: Row(children: [
              const Text('Assigned Schedules',
                  style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600, color: Colors.white)),
              const Spacer(),
              if (_assignments.isNotEmpty)
                Text('${_assignments.length} ${_assignments.length == 1 ? "batch" : "batches"}',
                    style: const TextStyle(fontSize: 12, color: Color(0xFF556677))),
            ])),

          // Content
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator(
                    color: Color(0xFF1DB954), strokeWidth: 2))
                : RefreshIndicator(
                    onRefresh: _load,
                    color: const Color(0xFF1DB954),
                    backgroundColor: const Color(0xFF152232),
                    child: _assignments.isEmpty
                        ? _emptyState()
                        : ListView(
                            padding: const EdgeInsets.fromLTRB(20, 0, 20, 100),
                            children: _assignments.map((a) => _assignmentCard(a)).toList())),
          ),
        ])),
      ]),
    );
  }

  Widget _assignmentCard(Map<String, dynamic> a) {
    final isActive   = a['IsActive'] != false;
    final scheduleId = a['CourseScheduleID'] as String?;
    final schedule   = _scheduleById(scheduleId);
    final courseName = _courseName(schedule['CourseID']);
    final batchName  = schedule['BatchName'] ?? '—';
    final timing     = _timingName(schedule['TimingsSubTypeID']);
    final days       = (schedule['DaysOfWeek'] as List?)?.cast<String>() ?? [];

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: const Color(0xFF152232),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: isActive ? const Color(0xFF1E3347) : const Color(0xFFE74C3C).withOpacity(0.35),
          width: isActive ? 1 : 1.5)),
      child: Column(children: [
        Padding(padding: const EdgeInsets.all(16), child: Row(children: [
          Container(width: 44, height: 44,
            decoration: BoxDecoration(
              color: const Color(0xFF1DB954).withOpacity(0.12),
              borderRadius: BorderRadius.circular(13)),
            child: const Icon(Icons.calendar_today_outlined,
                color: Color(0xFF1DB954), size: 20)),
          const SizedBox(width: 12),
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(courseName,
                style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600, color: Colors.white)),
            const SizedBox(height: 3),
            Text(batchName,
                style: const TextStyle(fontSize: 12, color: Color(0xFF8899AA))),
          ])),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
            decoration: BoxDecoration(
              color: isActive
                  ? const Color(0xFF1DB954).withOpacity(0.1)
                  : const Color(0xFFE74C3C).withOpacity(0.1),
              borderRadius: BorderRadius.circular(6)),
            child: Text(isActive ? 'Active' : 'Inactive',
                style: TextStyle(fontSize: 10,
                    color: isActive ? const Color(0xFF1DB954) : const Color(0xFFE74C3C)))),
        ])),

        // Timing + days
        Container(
          padding: const EdgeInsets.fromLTRB(16, 10, 16, 10),
          decoration: const BoxDecoration(
              border: Border(top: BorderSide(color: Color(0xFF1E3347), width: 1))),
          child: Row(children: [
            const Icon(Icons.access_time_rounded, color: Color(0xFF556677), size: 14),
            const SizedBox(width: 6),
            Text(timing, style: const TextStyle(fontSize: 12, color: Color(0xFF8899AA))),
            const SizedBox(width: 12),
            Expanded(child: Wrap(spacing: 4, children: days.map((d) =>
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: const Color(0xFF0D1B2A),
                  borderRadius: BorderRadius.circular(4),
                  border: Border.all(color: const Color(0xFF1E3347))),
                child: Text(d, style: const TextStyle(fontSize: 10, color: Color(0xFF8899AA))))).toList())),
          ])),

        // Actions
        Container(
          padding: const EdgeInsets.fromLTRB(12, 8, 12, 8),
          decoration: const BoxDecoration(
              border: Border(top: BorderSide(color: Color(0xFF1E3347), width: 1))),
          child: Row(children: [
            const Spacer(),
            GestureDetector(
              onTap: () => _toggleAssignment(a, isActive),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                decoration: BoxDecoration(
                  color: isActive
                      ? const Color(0xFFE74C3C).withOpacity(0.08)
                      : const Color(0xFF1DB954).withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(
                    color: isActive
                        ? const Color(0xFFE74C3C).withOpacity(0.3)
                        : const Color(0xFF1DB954).withOpacity(0.3))),
                child: Row(mainAxisSize: MainAxisSize.min, children: [
                  Icon(
                    isActive ? Icons.link_off_rounded : Icons.link_rounded,
                    color: isActive ? const Color(0xFFE74C3C) : const Color(0xFF1DB954),
                    size: 14),
                  const SizedBox(width: 4),
                  Text(isActive ? 'Unassign' : 'Reassign',
                      style: TextStyle(fontSize: 11, fontWeight: FontWeight.w500,
                          color: isActive ? const Color(0xFFE74C3C) : const Color(0xFF1DB954))),
                ]))),
          ])),
      ]));
  }

  Widget _emptyState() => ListView(padding: const EdgeInsets.all(32), children: [
    const SizedBox(height: 40),
    Center(child: Column(children: [
      Container(width: 72, height: 72,
        decoration: BoxDecoration(
          color: const Color(0xFF1DB954).withOpacity(0.08),
          borderRadius: BorderRadius.circular(20)),
        child: const Icon(Icons.calendar_today_outlined, color: Color(0xFF3A5068), size: 32)),
      const SizedBox(height: 20),
      const Text('No schedules assigned',
          style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600,
              color: Colors.white, fontFamily: 'Georgia')),
      const SizedBox(height: 8),
      const Text('Tap + to assign this staff\nto a course batch.',
          textAlign: TextAlign.center,
          style: TextStyle(fontSize: 13, color: Color(0xFF556677), height: 1.5)),
    ])),
  ]);

  // ── Assign Schedule Sheet ──────────────────────────────────────────────────
  void _showAssignSheet() {
    String? selectedScheduleId;
    bool saving = false;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => StatefulBuilder(builder: (ctx, ss) => Padding(
        padding: EdgeInsets.only(bottom: MediaQuery.of(ctx).viewInsets.bottom),
        child: Container(
          decoration: const BoxDecoration(
            color: Color(0xFF152232),
            borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
          padding: const EdgeInsets.all(24),
          child: Column(mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start, children: [
            Center(child: Container(width: 40, height: 4,
              decoration: BoxDecoration(color: const Color(0xFF1E3347),
                  borderRadius: BorderRadius.circular(2)))),
            const SizedBox(height: 20),
            Row(children: [
              Container(width: 36, height: 36,
                decoration: BoxDecoration(
                  color: const Color(0xFF1DB954).withOpacity(0.12),
                  borderRadius: BorderRadius.circular(10)),
                child: const Icon(Icons.link_rounded, color: Color(0xFF1DB954), size: 18)),
              const SizedBox(width: 12),
              const Text('Assign to Schedule',
                  style: TextStyle(fontFamily: 'Georgia', fontSize: 18,
                      fontWeight: FontWeight.bold, color: Colors.white)),
            ]),
            const SizedBox(height: 20),

            // Schedule list
            ..._unassignedSchedules.map((s) {
              final isSelected = selectedScheduleId == s['DocID'];
              final courseName = _courseName(s['CourseID']);
              final timing     = _timingName(s['TimingsSubTypeID']);
              final days       = (s['DaysOfWeek'] as List?)?.cast<String>() ?? [];
              return GestureDetector(
                onTap: () => ss(() => selectedScheduleId = s['DocID']),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  margin: const EdgeInsets.only(bottom: 10),
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: isSelected
                        ? const Color(0xFF1DB954).withOpacity(0.08)
                        : const Color(0xFF0D1B2A),
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(
                      color: isSelected
                          ? const Color(0xFF1DB954)
                          : const Color(0xFF1E3347),
                      width: isSelected ? 1.5 : 1)),
                  child: Row(children: [
                    Container(width: 36, height: 36,
                      decoration: BoxDecoration(
                        color: const Color(0xFF1DB954).withOpacity(0.1),
                        borderRadius: BorderRadius.circular(10)),
                      child: Icon(
                        isSelected ? Icons.check_circle_rounded : Icons.calendar_today_outlined,
                        color: const Color(0xFF1DB954), size: 18)),
                    const SizedBox(width: 12),
                    Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      Text(courseName,
                          style: const TextStyle(fontSize: 13,
                              fontWeight: FontWeight.w600, color: Colors.white)),
                      Text('${s['BatchName'] ?? ''} · $timing',
                          style: const TextStyle(fontSize: 11, color: Color(0xFF556677))),
                      if (days.isNotEmpty)
                        Text(days.join(', '),
                            style: const TextStyle(fontSize: 10, color: Color(0xFF3A5068))),
                    ])),
                  ])));
            }),

            if (_unassignedSchedules.isEmpty)
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: const Color(0xFF1DB954).withOpacity(0.05),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: const Color(0xFF1DB954).withOpacity(0.2))),
                child: const Center(child: Text('All schedules already assigned.',
                    style: TextStyle(fontSize: 13, color: Color(0xFF556677))))),

            const SizedBox(height: 20),
            Row(children: [
              Expanded(child: OutlinedButton(
                onPressed: () => Navigator.pop(ctx),
                style: OutlinedButton.styleFrom(
                  foregroundColor: const Color(0xFF8899AA),
                  side: const BorderSide(color: Color(0xFF1E3347)),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                  padding: const EdgeInsets.symmetric(vertical: 14)),
                child: const Text('Cancel'))),
              const SizedBox(width: 12),
              Expanded(flex: 2, child: ElevatedButton(
                onPressed: (saving || selectedScheduleId == null) ? null : () async {
                  ss(() => saving = true);
                  try {
                    final db  = FirebaseFirestore.instance;
                    final ref = db.collection('StaffCourseSchedule').doc();
                    await ref.set({
                      'StaffCourseScheduleID': ref.id,
                      'ClientID':              widget.clientId,
                      'BranchID':              widget.branchId,
                      'StaffEnrollmentNo':     widget.staff['StaffEnrollmentNo'],
                      'CourseScheduleID':      selectedScheduleId,
                      'IsActive':              true,
                      'CreatedAt':             FieldValue.serverTimestamp(),
                    });
                    if (ctx.mounted) Navigator.pop(ctx);
                    await _load();
                    _snack('Schedule assigned!', ok: true);
                  } catch (e) {
                    _snack('Failed to assign. Try again.');
                    ss(() => saving = false);
                  }
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF1DB954),
                  foregroundColor: Colors.white,
                  disabledBackgroundColor: const Color(0xFF1DB954).withOpacity(0.3),
                  elevation: 0,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                  padding: const EdgeInsets.symmetric(vertical: 14)),
                child: saving
                    ? const SizedBox(width: 20, height: 20,
                        child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                    : const Text('Assign', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600)))),
            ]),
            const SizedBox(height: 8),
          ]),
        ),
      )));
  }

  // ── Toggle assignment active/inactive ──────────────────────────────────────
  Future<void> _toggleAssignment(Map<String, dynamic> a, bool isActive) async {
    final schedule   = _scheduleById(a['CourseScheduleID']);
    final courseName = _courseName(schedule['CourseID']);
    final batchName  = schedule['BatchName'] ?? '';

    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF152232),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Text(isActive ? 'Unassign from schedule?' : 'Reassign to schedule?',
            style: const TextStyle(color: Colors.white, fontFamily: 'Georgia')),
        content: Text(
          isActive
              ? 'Remove ${widget.staff['StaffName']} from $courseName – $batchName?'
              : 'Reassign ${widget.staff['StaffName']} to $courseName – $batchName?',
          style: const TextStyle(color: Color(0xFF8899AA), height: 1.5)),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Cancel', style: TextStyle(color: Color(0xFF8899AA)))),
          TextButton(onPressed: () => Navigator.pop(ctx, true),
              child: Text(isActive ? 'Unassign' : 'Reassign',
                  style: TextStyle(
                      color: isActive ? const Color(0xFFE74C3C) : const Color(0xFF1DB954)))),
        ]));
    if (confirm != true) return;
    try {
      await FirebaseFirestore.instance
          .collection('StaffCourseSchedule')
          .doc(a['DocID'])
          .update({'IsActive': !isActive, 'UpdatedAt': FieldValue.serverTimestamp()});
      await _load();
      _snack(isActive ? 'Unassigned.' : 'Reassigned!', ok: !isActive);
    } catch (e) { _snack('Failed to update assignment.'); }
  }

  void _snack(String msg, {bool ok = false}) =>
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(msg, style: const TextStyle(color: Colors.white, fontSize: 14)),
      backgroundColor: ok ? const Color(0xFF2ECC71) : const Color(0xFFE74C3C),
      behavior: SnackBarBehavior.floating,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      margin: const EdgeInsets.all(16)));

  Widget _bgCircles() => Stack(children: [
    Positioned(top: -80, right: -60, child: Container(width: 280, height: 280,
      decoration: BoxDecoration(shape: BoxShape.circle,
          color: const Color(0xFF1A6B4A).withOpacity(0.12)))),
    Positioned(bottom: -100, left: -80, child: Container(width: 320, height: 320,
      decoration: BoxDecoration(shape: BoxShape.circle,
          color: const Color(0xFF1A4B6B).withOpacity(0.15)))),
  ]);
}

// ══════════════════════════════════════════════════════════════════════════════
// Schedule Staff Screen — accessed from Course Schedule card
// Shows all staff assigned to a specific course schedule
// ══════════════════════════════════════════════════════════════════════════════
class ScheduleStaffScreen extends StatefulWidget {
  final String clientId;
  final String branchId;
  final Map<String, dynamic> schedule;
  final String courseName;

  const ScheduleStaffScreen({
    super.key,
    required this.clientId,
    required this.branchId,
    required this.schedule,
    required this.courseName,
  });

  @override
  State<ScheduleStaffScreen> createState() => _ScheduleStaffScreenState();
}

class _ScheduleStaffScreenState extends State<ScheduleStaffScreen> {
  List<Map<String, dynamic>> _assignments = [];
  List<Map<String, dynamic>> _allStaff    = [];
  bool _isLoading = true;

  @override
  void initState() { super.initState(); _load(); }

  Future<void> _load() async {
    setState(() => _isLoading = true);
    try {
      final db = FirebaseFirestore.instance;

      QuerySnapshot? assignSnap;
      try {
        assignSnap = await db.collection('StaffCourseSchedule')
            .where('ClientID', isEqualTo: widget.clientId)
            .where('CourseScheduleID', isEqualTo: widget.schedule['DocID'])
            .orderBy('CreatedAt')
            .get();
      } catch (_) {
        assignSnap = await db.collection('StaffCourseSchedule')
            .where('ClientID', isEqualTo: widget.clientId)
            .where('CourseScheduleID', isEqualTo: widget.schedule['DocID'])
            .get();
      }

      // All active staff for this client
      QuerySnapshot? staffSnap;
      try {
        staffSnap = await db.collection('Staff')
            .where('ClientID', isEqualTo: widget.clientId)
            .where('IsActive', isEqualTo: true)
            .orderBy('CreatedAt')
            .get();
      } catch (_) {
        staffSnap = await db.collection('Staff')
            .where('ClientID', isEqualTo: widget.clientId)
            .where('IsActive', isEqualTo: true)
            .get();
      }

      if (mounted) setState(() {
        _assignments = assignSnap!.docs
            .map((d) => {...(d.data() as Map<String,dynamic>), 'DocID': d.id})
            .toList();
        _allStaff = staffSnap!.docs
            .map((d) => {...(d.data() as Map<String,dynamic>), 'DocID': d.id})
            .toList();
        _isLoading = false;
      });
    } catch (e) {
      debugPrint('ScheduleStaff load error: $e');
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Map<String, dynamic> _staffByEnrollNo(String? enrollNo) {
    if (enrollNo == null) return {};
    return _allStaff.firstWhere(
        (s) => s['StaffEnrollmentNo'] == enrollNo, orElse: () => {});
  }

  List<Map<String, dynamic>> get _unassignedStaff {
    final assignedNos = _assignments
        .where((a) => a['IsActive'] == true)
        .map((a) => a['StaffEnrollmentNo'] as String?)
        .toSet();
    return _allStaff.where((s) => !assignedNos.contains(s['StaffEnrollmentNo'])).toList();
  }

  @override
  Widget build(BuildContext context) {
    final days    = (widget.schedule['DaysOfWeek'] as List?)?.cast<String>() ?? [];
    final batch   = widget.schedule['BatchName'] ?? '';

    return Scaffold(
      backgroundColor: const Color(0xFF0D1B2A),
      body: Stack(children: [
        _bgCircles(),
        SafeArea(child: Column(children: [
          // Top bar
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            child: Row(children: [
              GestureDetector(
                onTap: () => Navigator.pop(context),
                child: Container(width: 40, height: 40,
                  decoration: BoxDecoration(color: const Color(0xFF152232),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: const Color(0xFF1E3347))),
                  child: const Icon(Icons.arrow_back_ios_new_rounded,
                      color: Color(0xFF8899AA), size: 18))),
              const SizedBox(width: 14),
              Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(widget.courseName,
                    style: const TextStyle(fontFamily: 'Georgia', fontSize: 17,
                        fontWeight: FontWeight.bold, color: Colors.white)),
                Text('$batch · ${days.join(', ')}',
                    style: const TextStyle(fontSize: 11, color: Color(0xFF556677))),
              ])),
              GestureDetector(
                onTap: _unassignedStaff.isEmpty ? null : _showAssignStaffSheet,
                child: Container(width: 40, height: 40,
                  decoration: BoxDecoration(
                    color: _unassignedStaff.isEmpty
                        ? const Color(0xFF1E3347)
                        : const Color(0xFF1DB954).withOpacity(0.12),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: _unassignedStaff.isEmpty
                          ? const Color(0xFF1E3347)
                          : const Color(0xFF1DB954).withOpacity(0.3))),
                  child: Icon(Icons.person_add_outlined,
                      color: _unassignedStaff.isEmpty
                          ? const Color(0xFF3A5068)
                          : const Color(0xFF1DB954),
                      size: 20))),
            ])),

          Padding(
            padding: const EdgeInsets.fromLTRB(20, 4, 20, 12),
            child: Row(children: [
              const Text('Assigned Staff',
                  style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600, color: Colors.white)),
              const Spacer(),
              if (_assignments.isNotEmpty)
                Text('${_assignments.length} ${_assignments.length == 1 ? "member" : "members"}',
                    style: const TextStyle(fontSize: 12, color: Color(0xFF556677))),
            ])),

          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator(
                    color: Color(0xFF1DB954), strokeWidth: 2))
                : RefreshIndicator(
                    onRefresh: _load,
                    color: const Color(0xFF1DB954),
                    backgroundColor: const Color(0xFF152232),
                    child: _assignments.isEmpty
                        ? _emptyState()
                        : ListView(
                            padding: const EdgeInsets.fromLTRB(20, 0, 20, 100),
                            children: _assignments.map((a) => _staffCard(a)).toList()))),
        ])),
      ]),
    );
  }

  Widget _staffCard(Map<String, dynamic> a) {
    final isActive = a['IsActive'] != false;
    final staff    = _staffByEnrollNo(a['StaffEnrollmentNo']);
    final name     = staff['StaffName'] ?? a['StaffEnrollmentNo'] ?? '—';
    final role     = staff['Role'] ?? '';
    final enrollNo = a['StaffEnrollmentNo'] ?? '';

    Color roleColor = const Color(0xFF5BA3D9);
    if (role == 'Teacher') roleColor = const Color(0xFF7F77DD);
    if (role == 'Coach')   roleColor = const Color(0xFFE8A020);

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFF152232),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isActive ? const Color(0xFF1E3347) : const Color(0xFFE74C3C).withOpacity(0.35),
          width: isActive ? 1 : 1.5)),
      child: Row(children: [
        Container(width: 42, height: 42,
          decoration: BoxDecoration(color: roleColor.withOpacity(0.15), borderRadius: BorderRadius.circular(12)),
          child: Center(child: Text(name.substring(0, 1).toUpperCase(),
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: roleColor)))),
        const SizedBox(width: 12),
        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(name, style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600,
              color: isActive ? Colors.white : const Color(0xFF8899AA))),
          Row(children: [
            if (role.isNotEmpty) Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
              decoration: BoxDecoration(color: roleColor.withOpacity(0.12), borderRadius: BorderRadius.circular(4)),
              child: Text(role, style: TextStyle(fontSize: 9, color: roleColor))),
            const SizedBox(width: 6),
            Text(enrollNo, style: const TextStyle(fontSize: 10, color: Color(0xFF3A5068))),
          ]),
        ])),
        GestureDetector(
          onTap: () => _toggleStaffAssignment(a, isActive, name),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
            decoration: BoxDecoration(
              color: isActive
                  ? const Color(0xFFE74C3C).withOpacity(0.08)
                  : const Color(0xFF1DB954).withOpacity(0.1),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(
                color: isActive
                    ? const Color(0xFFE74C3C).withOpacity(0.3)
                    : const Color(0xFF1DB954).withOpacity(0.3))),
            child: Row(mainAxisSize: MainAxisSize.min, children: [
              Icon(isActive ? Icons.link_off_rounded : Icons.link_rounded,
                  color: isActive ? const Color(0xFFE74C3C) : const Color(0xFF1DB954), size: 13),
              const SizedBox(width: 4),
              Text(isActive ? 'Unassign' : 'Reassign',
                  style: TextStyle(fontSize: 11, fontWeight: FontWeight.w500,
                      color: isActive ? const Color(0xFFE74C3C) : const Color(0xFF1DB954))),
            ]))),
      ]));
  }

  Widget _emptyState() => ListView(padding: const EdgeInsets.all(32), children: [
    const SizedBox(height: 40),
    Center(child: Column(children: [
      Container(width: 72, height: 72,
        decoration: BoxDecoration(color: const Color(0xFF1DB954).withOpacity(0.08), borderRadius: BorderRadius.circular(20)),
        child: const Icon(Icons.person_outline_rounded, color: Color(0xFF3A5068), size: 32)),
      const SizedBox(height: 20),
      const Text('No staff assigned', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600, color: Colors.white, fontFamily: 'Georgia')),
      const SizedBox(height: 8),
      const Text('Tap + to assign staff\nto this batch.', textAlign: TextAlign.center,
          style: TextStyle(fontSize: 13, color: Color(0xFF556677), height: 1.5)),
    ])),
  ]);

  void _showAssignStaffSheet() {
    String? selectedEnrollNo;
    bool saving = false;

    showModalBottomSheet(
      context: context, isScrollControlled: true, backgroundColor: Colors.transparent,
      builder: (ctx) => StatefulBuilder(builder: (ctx, ss) => Container(
        decoration: const BoxDecoration(color: Color(0xFF152232),
            borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
        padding: const EdgeInsets.all(24),
        child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
          Center(child: Container(width: 40, height: 4,
            decoration: BoxDecoration(color: const Color(0xFF1E3347), borderRadius: BorderRadius.circular(2)))),
          const SizedBox(height: 20),
          Row(children: [
            Container(width: 36, height: 36,
              decoration: BoxDecoration(color: const Color(0xFF1DB954).withOpacity(0.12), borderRadius: BorderRadius.circular(10)),
              child: const Icon(Icons.person_add_outlined, color: Color(0xFF1DB954), size: 18)),
            const SizedBox(width: 12),
            const Text('Assign Staff', style: TextStyle(fontFamily: 'Georgia', fontSize: 18,
                fontWeight: FontWeight.bold, color: Colors.white)),
          ]),
          const SizedBox(height: 20),

          // Staff list
          ..._unassignedStaff.map((s) {
            final enrollNo  = s['StaffEnrollmentNo'] ?? '';
            final isSelected = selectedEnrollNo == enrollNo;
            final role      = s['Role'] ?? '';
            Color roleColor = const Color(0xFF5BA3D9);
            if (role == 'Teacher') roleColor = const Color(0xFF7F77DD);
            if (role == 'Coach')   roleColor = const Color(0xFFE8A020);

            return GestureDetector(
              onTap: () => ss(() => selectedEnrollNo = enrollNo),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                margin: const EdgeInsets.only(bottom: 8),
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: isSelected ? const Color(0xFF1DB954).withOpacity(0.08) : const Color(0xFF0D1B2A),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: isSelected ? const Color(0xFF1DB954) : const Color(0xFF1E3347),
                    width: isSelected ? 1.5 : 1)),
                child: Row(children: [
                  Container(width: 36, height: 36,
                    decoration: BoxDecoration(color: roleColor.withOpacity(0.15), borderRadius: BorderRadius.circular(10)),
                    child: Center(child: Text(
                      (s['StaffName'] ?? 'S').substring(0, 1).toUpperCase(),
                      style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: roleColor)))),
                  const SizedBox(width: 12),
                  Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Text(s['StaffName'] ?? '', style: const TextStyle(fontSize: 13,
                        fontWeight: FontWeight.w600, color: Colors.white)),
                    Text('$role · $enrollNo', style: const TextStyle(fontSize: 11, color: Color(0xFF556677))),
                  ])),
                  if (isSelected) const Icon(Icons.check_circle_rounded, color: Color(0xFF1DB954), size: 20),
                ])));
          }),

          const SizedBox(height: 20),
          Row(children: [
            Expanded(child: OutlinedButton(
              onPressed: () => Navigator.pop(ctx),
              style: OutlinedButton.styleFrom(
                foregroundColor: const Color(0xFF8899AA),
                side: const BorderSide(color: Color(0xFF1E3347)),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                padding: const EdgeInsets.symmetric(vertical: 14)),
              child: const Text('Cancel'))),
            const SizedBox(width: 12),
            Expanded(flex: 2, child: ElevatedButton(
              onPressed: (saving || selectedEnrollNo == null) ? null : () async {
                ss(() => saving = true);
                try {
                  final db  = FirebaseFirestore.instance;
                  final ref = db.collection('StaffCourseSchedule').doc();
                  await ref.set({
                    'StaffCourseScheduleID': ref.id,
                    'ClientID':              widget.clientId,
                    'BranchID':              widget.branchId,
                    'StaffEnrollmentNo':     selectedEnrollNo,
                    'CourseScheduleID':      widget.schedule['DocID'],
                    'IsActive':              true,
                    'CreatedAt':             FieldValue.serverTimestamp(),
                  });
                  if (ctx.mounted) Navigator.pop(ctx);
                  await _load();
                  _snack('Staff assigned!', ok: true);
                } catch (e) {
                  _snack('Failed to assign. Try again.');
                  ss(() => saving = false);
                }
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF1DB954), foregroundColor: Colors.white,
                disabledBackgroundColor: const Color(0xFF1DB954).withOpacity(0.3),
                elevation: 0, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                padding: const EdgeInsets.symmetric(vertical: 14)),
              child: saving
                  ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                  : const Text('Assign', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600)))),
          ]),
          const SizedBox(height: 8),
        ]),
      )));
  }

  Future<void> _toggleStaffAssignment(Map<String, dynamic> a, bool isActive, String name) async {
    final confirm = await showDialog<bool>(context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF152232),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Text(isActive ? 'Unassign staff?' : 'Reassign staff?',
            style: const TextStyle(color: Colors.white, fontFamily: 'Georgia')),
        content: Text(
          isActive ? 'Remove $name from this batch?' : 'Reassign $name to this batch?',
          style: const TextStyle(color: Color(0xFF8899AA), height: 1.5)),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Cancel', style: TextStyle(color: Color(0xFF8899AA)))),
          TextButton(onPressed: () => Navigator.pop(ctx, true),
              child: Text(isActive ? 'Unassign' : 'Reassign',
                  style: TextStyle(color: isActive ? const Color(0xFFE74C3C) : const Color(0xFF1DB954)))),
        ]));
    if (confirm != true) return;
    try {
      await FirebaseFirestore.instance.collection('StaffCourseSchedule').doc(a['DocID'])
          .update({'IsActive': !isActive, 'UpdatedAt': FieldValue.serverTimestamp()});
      await _load();
      _snack(isActive ? 'Unassigned.' : 'Reassigned!', ok: !isActive);
    } catch (e) { _snack('Failed to update.'); }
  }

  void _snack(String msg, {bool ok = false}) =>
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(msg, style: const TextStyle(color: Colors.white, fontSize: 14)),
      backgroundColor: ok ? const Color(0xFF2ECC71) : const Color(0xFFE74C3C),
      behavior: SnackBarBehavior.floating,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      margin: const EdgeInsets.all(16)));

  Widget _bgCircles() => Stack(children: [
    Positioned(top: -80, right: -60, child: Container(width: 280, height: 280,
      decoration: BoxDecoration(shape: BoxShape.circle, color: const Color(0xFF1A6B4A).withOpacity(0.12)))),
    Positioned(bottom: -100, left: -80, child: Container(width: 320, height: 320,
      decoration: BoxDecoration(shape: BoxShape.circle, color: const Color(0xFF1A4B6B).withOpacity(0.15)))),
  ]);
}