import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'dart:typed_data';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';

// ══════════════════════════════════════════════════════════════════════════════
// Staff Dashboard
// ══════════════════════════════════════════════════════════════════════════════
class StaffDashboard extends StatefulWidget {
  final String uid;
  final String clientId;
  final String branchId;
  final String staffDocId;
  final String enrollNo;
  final String staffName;
  final String email;

  const StaffDashboard({
    super.key,
    required this.uid,
    required this.clientId,
    required this.branchId,
    required this.staffDocId,
    required this.enrollNo,
    required this.staffName,
    required this.email,
  });

  @override
  State<StaffDashboard> createState() => _StaffDashboardState();
}

class _StaffDashboardState extends State<StaffDashboard> {
  int _currentTab = 0;

  // Shared data loaded once, passed to tabs
  Map<String, dynamic> _staffDoc         = {};
  List<Map<String, dynamic>> _myBatches  = []; // StaffCourseSchedule
  List<Map<String, dynamic>> _schedules  = []; // CourseSchedule
  List<Map<String, dynamic>> _courses    = []; // Course
  List<Map<String, dynamic>> _timings    = []; // SubType Timings
  List<Map<String, dynamic>> _students   = []; // Students in my batches
  List<Map<String, dynamic>> _stuScheds  = []; // StudentCourseSchedule
  bool _isLoading = true;

  @override
  void initState() { super.initState(); _loadAll(); }

  Future<void> _loadAll() async {
    setState(() => _isLoading = true);
    try {
      final db = FirebaseFirestore.instance;
      final results = await Future.wait([
        // Staff doc
        db.collection('Staff').doc(widget.staffDocId).get(),
        // My assigned batches
        db.collection('StaffCourseSchedule')
            .where('ClientID', isEqualTo: widget.clientId)
            .where('StaffEnrollmentNo', isEqualTo: widget.enrollNo)
            .where('IsActive', isEqualTo: true).get(),
        // All course schedules for this client
        db.collection('CourseSchedule')
            .where('ClientID', isEqualTo: widget.clientId).get(),
        // All courses
        db.collection('Course')
            .where('ClientID', isEqualTo: widget.clientId).get(),
        // Timings subtypes
        db.collection('SubType')
            .where('ClientID', isEqualTo: widget.clientId)
            .where('SubTypeCode', isEqualTo: 'Timings').get(),
        // All student course schedules
        db.collection('StudentCourseSchedule')
            .where('ClientID', isEqualTo: widget.clientId)
            .where('IsActive', isEqualTo: true).get(),
        // All students
        db.collection('Student')
            .where('ClientID', isEqualTo: widget.clientId).get(),
      ]);

      final staffDoc   = results[0] as DocumentSnapshot;
      final batchSnap  = results[1] as QuerySnapshot;
      final csSnap     = results[2] as QuerySnapshot;
      final courseSnap = results[3] as QuerySnapshot;
      final timSnap    = results[4] as QuerySnapshot;
      final ssSnap     = results[5] as QuerySnapshot;
      final stuSnap    = results[6] as QuerySnapshot;

      final myBatches = batchSnap.docs
          .map((d) => {...(d.data() as Map<String,dynamic>), 'DocID': d.id})
          .toList();
      final myScheduleIds = myBatches
          .map((b) => b['CourseScheduleID'] as String? ?? '')
          .toSet();

      // Students enrolled in my batches
      final myStuScheds = (ssSnap.docs
          .map((d) => {...(d.data() as Map<String,dynamic>), 'DocID': d.id})
          .toList())
          .where((s) => myScheduleIds.contains(s['CourseScheduleID']))
          .toList();
      final myStudentEnrollNos = myStuScheds
          .map((s) => s['StudentEnrollmentNo'] as String? ?? '')
          .toSet();
      final myStudents = (stuSnap.docs
          .map((d) => {...(d.data() as Map<String,dynamic>), 'DocID': d.id})
          .toList())
          .where((s) => myStudentEnrollNos
              .contains(s['StudentEnrollmentNo']))
          .toList();

      if (mounted) setState(() {
        _staffDoc  = staffDoc.exists
            ? {...(staffDoc.data() as Map<String,dynamic>), 'DocID': staffDoc.id}
            : {};
        _myBatches = myBatches;
        _schedules = csSnap.docs.map((d) => {...(d.data() as Map<String,dynamic>), 'DocID': d.id}).toList();
        _courses   = courseSnap.docs.map((d) => {...(d.data() as Map<String,dynamic>), 'DocID': d.id}).toList();
        _timings   = timSnap.docs.map((d) => {...(d.data() as Map<String,dynamic>), 'DocID': d.id}).toList();
        _stuScheds = myStuScheds;
        _students  = myStudents;
        _isLoading = false;
      });
    } catch (e) {
      debugPrint('Staff dashboard load error: $e');
      if (mounted) setState(() => _isLoading = false);
    }
  }

  // ── Lookup helpers ─────────────────────────────────────────────────────────
  Map<String, dynamic> _scheduleById(String? id) =>
      _schedules.firstWhere((s) => s['DocID'] == id, orElse: () => {});

  Map<String, dynamic> _courseById(String? id) =>
      _courses.firstWhere((c) => c['DocID'] == id, orElse: () => {});

  Map<String, dynamic> _timingById(String? id) =>
      _timings.firstWhere((t) => t['DocID'] == id, orElse: () => {});

  int _studentCountForSchedule(String csId) =>
      _stuScheds.where((s) => s['CourseScheduleID'] == csId).length;

  List<Map<String, dynamic>> _studentsForSchedule(String csId) {
    final enrollNos = _stuScheds
        .where((s) => s['CourseScheduleID'] == csId)
        .map((s) => s['StudentEnrollmentNo'] as String? ?? '')
        .toSet();
    return _students.where((s) =>
        enrollNos.contains(s['StudentEnrollmentNo'])).toList();
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return Scaffold(backgroundColor: const Color(0xFF0D1B2A),
        body: const Center(child: CircularProgressIndicator(
            color: Color(0xFF1DB954), strokeWidth: 2)));
    }

    final tabs = [
      _HomeTab(
        staffDoc:  _staffDoc,
        myBatches: _myBatches,
        scheduleById: _scheduleById,
        courseById:   _courseById,
        studentCount: _students.length,
        enrollNo:     widget.enrollNo,
        clientId:     widget.clientId,
        onRefresh:    _loadAll,
      ),
      _ScheduleTab(
        myBatches:    _myBatches,
        scheduleById: _scheduleById,
        courseById:   _courseById,
        timingById:   _timingById,
        studentsForSchedule: _studentsForSchedule,
        studentCountForSchedule: _studentCountForSchedule,
        clientId:     widget.clientId,
        enrollNo:     widget.enrollNo,
      ),
      _StudentsTab(
        students:     _students,
        stuScheds:    _stuScheds,
        myBatches:    _myBatches,
        scheduleById: _scheduleById,
        courseById:   _courseById,
      ),
      _MoreTab(
        staffDoc:  _staffDoc,
        clientId:  widget.clientId,
        enrollNo:  widget.enrollNo,
        uid:       widget.uid,
        email:     widget.email,
        onRefresh: _loadAll,
      ),
    ];

    return Scaffold(
      backgroundColor: const Color(0xFF0D1B2A),
      body: tabs[_currentTab],
      bottomNavigationBar: _buildBottomNav(),
    );
  }

  Widget _buildBottomNav() {
    const items = [
      {'icon': Icons.home_rounded, 'label': 'Home'},
      {'icon': Icons.calendar_today_rounded, 'label': 'Schedule'},
      {'icon': Icons.people_rounded, 'label': 'Students'},
      {'icon': Icons.more_horiz_rounded, 'label': 'More'},
    ];

    return Container(
      decoration: const BoxDecoration(
        color: Color(0xFF152232),
        border: Border(top: BorderSide(color: Color(0xFF1E3347), width: 1))),
      child: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 8),
          child: Row(children: items.asMap().entries.map((e) {
            final i       = e.key;
            final item    = e.value;
            final active  = _currentTab == i;
            return Expanded(child: GestureDetector(
              onTap: () => setState(() => _currentTab = i),
              behavior: HitTestBehavior.opaque,
              child: Column(mainAxisSize: MainAxisSize.min, children: [
                Icon(item['icon'] as IconData,
                    color: active ? const Color(0xFF1DB954) : const Color(0xFF556677),
                    size: 22),
                const SizedBox(height: 4),
                Text(item['label'] as String,
                    style: TextStyle(fontSize: 10,
                        fontWeight: active ? FontWeight.w600 : FontWeight.normal,
                        color: active ? const Color(0xFF1DB954) : const Color(0xFF556677))),
              ])));
          }).toList()))));
  }
}  // end _StaffDashboardState

// ══════════════════════════════════════════════════════════════════════════════
// Home Tab
// ══════════════════════════════════════════════════════════════════════════════
class _HomeTab extends StatelessWidget {
  final Map<String, dynamic> staffDoc;
  final List<Map<String, dynamic>> myBatches;
  final Map<String, dynamic> Function(String?) scheduleById;
  final Map<String, dynamic> Function(String?) courseById;
  final int studentCount;
  final String enrollNo;
  final String clientId;
  final VoidCallback onRefresh;

  const _HomeTab({
    required this.staffDoc, required this.myBatches,
    required this.scheduleById, required this.courseById,
    required this.studentCount, required this.enrollNo,
    required this.clientId, required this.onRefresh,
  });

  String _greeting() {
    final h = DateTime.now().hour;
    if (h < 12) return 'Good morning';
    if (h < 17) return 'Good afternoon';
    return 'Good evening';
  }

  @override
  Widget build(BuildContext context) {
    final name = staffDoc['StaffName'] as String? ?? enrollNo;
    final role = staffDoc['Role'] as String? ?? 'Staff';

    return SafeArea(child: RefreshIndicator(
      onRefresh: () async => onRefresh(),
      color: const Color(0xFF1DB954),
      backgroundColor: const Color(0xFF152232),
      child: ListView(
        padding: const EdgeInsets.fromLTRB(20, 16, 20, 100),
        children: [
          // Header
          Row(children: [
            Container(width: 46, height: 46,
              decoration: BoxDecoration(
                color: const Color(0xFFE8A020).withOpacity(0.15),
                borderRadius: BorderRadius.circular(14)),
              child: Center(child: Text(name.substring(0, 1).toUpperCase(),
                  style: const TextStyle(fontSize: 20,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFFE8A020))))),
            const SizedBox(width: 12),
            Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text('${_greeting()}, ${name.split(' ').first}',
                  style: const TextStyle(fontSize: 18,
                      fontWeight: FontWeight.bold, color: Colors.white,
                      fontFamily: 'Georgia')),
              Text('$role · $enrollNo',
                  style: const TextStyle(fontSize: 12, color: Color(0xFF556677))),
            ])),
            GestureDetector(
              onTap: () async {
                await FirebaseAuth.instance.signOut();
              },
              child: Container(width: 38, height: 38,
                decoration: BoxDecoration(
                    color: const Color(0xFF152232),
                    borderRadius: BorderRadius.circular(11),
                    border: Border.all(color: const Color(0xFF1E3347))),
                child: const Icon(Icons.logout_rounded,
                    color: Color(0xFF556677), size: 18))),
          ]),
          const SizedBox(height: 24),

          // Stats row
          Row(children: [
            _statCard('Batches', myBatches.length.toString(),
                Icons.calendar_today_rounded, const Color(0xFF1DB954)),
            const SizedBox(width: 12),
            _statCard('Students', studentCount.toString(),
                Icons.school_outlined, const Color(0xFF5BA3D9)),
          ]),
          const SizedBox(height: 12),

          // This month payroll
          _PayrollSummaryCard(clientId: clientId, enrollNo: enrollNo),
          const SizedBox(height: 24),

          // My batches quick list
          const Text('My Batches',
              style: TextStyle(fontSize: 15,
                  fontWeight: FontWeight.w600, color: Colors.white)),
          const SizedBox(height: 12),
          if (myBatches.isEmpty)
            _emptyCard('No batches assigned yet.')
          else
            ...myBatches.map((b) {
              final cs     = scheduleById(b['CourseScheduleID']);
              final course = courseById(cs['CourseID']);
              final days   = (cs['DaysOfWeek'] as List?)?.cast<String>() ?? [];
              return Container(
                margin: const EdgeInsets.only(bottom: 10),
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: const Color(0xFF152232),
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: const Color(0xFF1E3347))),
                child: Row(children: [
                  Container(width: 40, height: 40,
                    decoration: BoxDecoration(
                        color: const Color(0xFF1DB954).withOpacity(0.12),
                        borderRadius: BorderRadius.circular(11)),
                    child: const Icon(Icons.menu_book_rounded,
                        color: Color(0xFF1DB954), size: 20)),
                  const SizedBox(width: 12),
                  Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Text(course['CourseName'] ?? '—',
                        style: const TextStyle(fontSize: 14,
                            fontWeight: FontWeight.w600, color: Colors.white)),
                    Text('${cs['BatchName'] ?? ''} · ${days.join(', ')}',
                        style: const TextStyle(fontSize: 11, color: Color(0xFF556677))),
                  ])),
                ]));
            }),
        ],
      )));
  }

  Widget _statCard(String label, String value, IconData icon, Color color) =>
    Expanded(child: Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFF152232), borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFF1E3347))),
      child: Row(children: [
        Container(width: 40, height: 40,
          decoration: BoxDecoration(color: color.withOpacity(0.12),
              borderRadius: BorderRadius.circular(11)),
          child: Icon(icon, color: color, size: 20)),
        const SizedBox(width: 12),
        Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(value, style: const TextStyle(fontSize: 22,
              fontWeight: FontWeight.bold, color: Colors.white)),
          Text(label, style: const TextStyle(fontSize: 11, color: Color(0xFF556677))),
        ]),
      ])));

  Widget _emptyCard(String msg) => Container(
    padding: const EdgeInsets.all(16),
    decoration: BoxDecoration(color: const Color(0xFF152232),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFF1E3347))),
    child: Center(child: Text(msg,
        style: const TextStyle(color: Color(0xFF556677), fontSize: 13))));
}

// ── Payroll summary card for Home tab ─────────────────────────────────────────
class _PayrollSummaryCard extends StatelessWidget {
  final String clientId;
  final String enrollNo;

  const _PayrollSummaryCard({required this.clientId, required this.enrollNo});

  @override
  Widget build(BuildContext context) {
    final now      = DateTime.now();
    final monthKey = '${now.year}-${now.month.toString().padLeft(2, '0')}';
    const months   = ['Jan','Feb','Mar','Apr','May','Jun',
        'Jul','Aug','Sep','Oct','Nov','Dec'];
    final monthDisplay = '${months[now.month - 1]} ${now.year}';

    return FutureBuilder<QuerySnapshot>(
      future: FirebaseFirestore.instance
          .collection('PayrollTransactions')
          .where('ClientID', isEqualTo: clientId)
          .where('StaffEnrollmentNo', isEqualTo: enrollNo)
          .where('PayrollMonth', isEqualTo: monthKey)
          .limit(1).get(),
      builder: (ctx, snap) {
        double amount = 0;
        bool isPaid   = false;
        String invoice = '—';
        if (snap.hasData && snap.data!.docs.isNotEmpty) {
          final data = snap.data!.docs.first.data() as Map<String, dynamic>;
          amount  = (data['PaymentAmount'] as num?)?.toDouble() ?? 0;
          isPaid  = data['IsPaid'] == true;
          invoice = data['PayrollInvoiceNo'] as String? ?? '—';
        }
        return Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: const Color(0xFF152232),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: amount > 0
                ? const Color(0xFF1DB954).withOpacity(0.3)
                : const Color(0xFF1E3347))),
          child: Row(children: [
            Container(width: 40, height: 40,
              decoration: BoxDecoration(
                color: const Color(0xFFE8A020).withOpacity(0.12),
                borderRadius: BorderRadius.circular(11)),
              child: const Icon(Icons.account_balance_wallet_outlined,
                  color: Color(0xFFE8A020), size: 20)),
            const SizedBox(width: 12),
            Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text('$monthDisplay Payroll',
                  style: const TextStyle(fontSize: 12, color: Color(0xFF556677))),
              Text(amount > 0 ? '₹${amount.toStringAsFixed(2)}' : 'Not generated yet',
                  style: const TextStyle(fontSize: 16,
                      fontWeight: FontWeight.bold, color: Colors.white)),
              if (invoice != '—') Text(invoice,
                  style: const TextStyle(fontSize: 10, color: Color(0xFF3A5068))),
            ])),
            if (amount > 0) Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: isPaid
                    ? const Color(0xFF1DB954).withOpacity(0.1)
                    : const Color(0xFFE74C3C).withOpacity(0.1),
                borderRadius: BorderRadius.circular(8)),
              child: Text(isPaid ? 'Paid' : 'Pending',
                  style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600,
                      color: isPaid ? const Color(0xFF1DB954) : const Color(0xFFE74C3C)))),
          ]));
      },
    );
  }
}

// ══════════════════════════════════════════════════════════════════════════════
// Schedule Tab
// ══════════════════════════════════════════════════════════════════════════════
class _ScheduleTab extends StatelessWidget {
  final List<Map<String, dynamic>> myBatches;
  final Map<String, dynamic> Function(String?) scheduleById;
  final Map<String, dynamic> Function(String?) courseById;
  final Map<String, dynamic> Function(String?) timingById;
  final List<Map<String, dynamic>> Function(String) studentsForSchedule;
  final int Function(String) studentCountForSchedule;
  final String clientId;
  final String enrollNo;

  const _ScheduleTab({
    required this.myBatches, required this.scheduleById,
    required this.courseById, required this.timingById,
    required this.studentsForSchedule,
    required this.studentCountForSchedule,
    required this.clientId, required this.enrollNo,
  });

  @override
  Widget build(BuildContext context) {
    return SafeArea(child: Column(children: [
      const Padding(
        padding: EdgeInsets.fromLTRB(20, 16, 20, 12),
        child: Row(children: [
          Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text('My Schedule', style: TextStyle(fontFamily: 'Georgia',
                fontSize: 22, fontWeight: FontWeight.bold, color: Colors.white)),
            Text('Batches · Attendance · Online Class',
                style: TextStyle(fontSize: 12, color: Color(0xFF556677))),
          ]),
        ])),
      Expanded(child: myBatches.isEmpty
          ? Center(child: Column(mainAxisSize: MainAxisSize.min, children: [
              Container(width: 64, height: 64,
                decoration: BoxDecoration(color: const Color(0xFF1DB954).withOpacity(0.08),
                    borderRadius: BorderRadius.circular(18)),
                child: const Icon(Icons.calendar_today_outlined,
                    color: Color(0xFF3A5068), size: 32)),
              const SizedBox(height: 16),
              const Text('No batches assigned',
                  style: TextStyle(fontSize: 16, color: Colors.white,
                      fontFamily: 'Georgia')),
            ]))
          : ListView(
              padding: const EdgeInsets.fromLTRB(20, 0, 20, 100),
              children: myBatches.map((b) {
                final csId   = b['CourseScheduleID'] as String? ?? '';
                final cs     = scheduleById(csId);
                final course = courseById(cs['CourseID']);
                final timing = timingById(cs['TimingsSubTypeID']);
                final days   = (cs['DaysOfWeek'] as List?)?.cast<String>() ?? [];
                final count  = studentCountForSchedule(csId);

                return Container(
                  margin: const EdgeInsets.only(bottom: 14),
                  decoration: BoxDecoration(
                    color: const Color(0xFF152232),
                    borderRadius: BorderRadius.circular(18),
                    border: Border.all(color: const Color(0xFF1E3347))),
                  child: Column(children: [
                    // Header
                    Padding(padding: const EdgeInsets.all(16), child: Row(children: [
                      Container(width: 44, height: 44,
                        decoration: BoxDecoration(
                            color: const Color(0xFF1DB954).withOpacity(0.12),
                            borderRadius: BorderRadius.circular(13)),
                        child: const Icon(Icons.menu_book_rounded,
                            color: Color(0xFF1DB954), size: 22)),
                      const SizedBox(width: 12),
                      Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                        Text(course['CourseName'] ?? '—',
                            style: const TextStyle(fontSize: 15,
                                fontWeight: FontWeight.w600, color: Colors.white)),
                        Text(cs['BatchName'] ?? '—',
                            style: const TextStyle(fontSize: 12, color: Color(0xFF8899AA))),
                      ])),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                            color: const Color(0xFF5BA3D9).withOpacity(0.12),
                            borderRadius: BorderRadius.circular(8)),
                        child: Text('$count students',
                            style: const TextStyle(fontSize: 11,
                                color: Color(0xFF5BA3D9)))),
                    ])),

                    // Timing + days
                    Padding(padding: const EdgeInsets.fromLTRB(16, 0, 16, 12), child: Row(children: [
                      const Icon(Icons.access_time_rounded,
                          color: Color(0xFF556677), size: 14),
                      const SizedBox(width: 4),
                      Text(timing['SubTypeName'] ?? '—',
                          style: const TextStyle(fontSize: 12, color: Color(0xFF8899AA))),
                      const SizedBox(width: 12),
                      Expanded(child: Wrap(spacing: 4, children: days.map((d) =>
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                            decoration: BoxDecoration(
                                color: const Color(0xFF0D1B2A),
                                borderRadius: BorderRadius.circular(5),
                                border: Border.all(color: const Color(0xFF1E3347))),
                            child: Text(d, style: const TextStyle(
                                fontSize: 10, color: Color(0xFF8899AA))))).toList())),
                    ])),

                    // Action buttons
                    Container(
                      padding: const EdgeInsets.fromLTRB(12, 8, 12, 12),
                      decoration: const BoxDecoration(
                          border: Border(top: BorderSide(
                              color: Color(0xFF1E3347), width: 1))),
                      child: Row(children: [
                        // Mark Attendance
                        Expanded(child: _actionBtn(
                          context: context,
                          label: 'Attendance',
                          icon: Icons.fact_check_outlined,
                          color: const Color(0xFF1DB954),
                          onTap: () => Navigator.push(context,
                              MaterialPageRoute(builder: (_) =>
                                  AttendanceScreen(
                                    clientId:    clientId,
                                    enrollNo:    enrollNo,
                                    scheduleId:  csId,
                                    batchName:   cs['BatchName'] ?? '',
                                    courseName:  course['CourseName'] ?? '',
                                    students:    studentsForSchedule(csId),
                                  ))),
                        )),
                        const SizedBox(width: 8),
                        // Attendance History
                        Expanded(child: _actionBtn(
                          context: context,
                          label: 'History',
                          icon: Icons.history_rounded,
                          color: const Color(0xFF5BA3D9),
                          onTap: () => Navigator.push(context,
                              MaterialPageRoute(builder: (_) =>
                                  AttendanceHistoryScreen(
                                    clientId:   clientId,
                                    scheduleId: csId,
                                    batchName:  cs['BatchName'] ?? '',
                                    courseName: course['CourseName'] ?? '',
                                    students:   studentsForSchedule(csId),
                                  ))),
                        )),
                        const SizedBox(width: 8),
                        // Online Class
                        Expanded(child: _actionBtn(
                          context: context,
                          label: 'Online',
                          icon: Icons.videocam_outlined,
                          color: const Color(0xFF7F77DD),
                          onTap: () => Navigator.push(context,
                              MaterialPageRoute(builder: (_) =>
                                  OnlineClassScreen(
                                    clientId:   clientId,
                                    enrollNo:   enrollNo,
                                    scheduleId: csId,
                                    batchName:  cs['BatchName'] ?? '',
                                    courseName: course['CourseName'] ?? '',
                                  ))),
                        )),
                      ])),
                  ]));
              }).toList()),
      ),
    ]));
  }

  Widget _actionBtn({required BuildContext context, required String label,
      required IconData icon, required Color color, required VoidCallback onTap}) =>
    GestureDetector(onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 8),
        decoration: BoxDecoration(
          color: color.withOpacity(0.1),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: color.withOpacity(0.3))),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          Icon(icon, color: color, size: 18),
          const SizedBox(height: 3),
          Text(label, style: TextStyle(fontSize: 10,
              color: color, fontWeight: FontWeight.w500)),
        ])));
}

// ══════════════════════════════════════════════════════════════════════════════
// Students Tab
// ══════════════════════════════════════════════════════════════════════════════
class _StudentsTab extends StatefulWidget {
  final List<Map<String, dynamic>> students;
  final List<Map<String, dynamic>> stuScheds;
  final List<Map<String, dynamic>> myBatches;
  final Map<String, dynamic> Function(String?) scheduleById;
  final Map<String, dynamic> Function(String?) courseById;

  const _StudentsTab({
    required this.students, required this.stuScheds,
    required this.myBatches, required this.scheduleById,
    required this.courseById,
  });

  @override
  State<_StudentsTab> createState() => _StudentsTabState();
}

class _StudentsTabState extends State<_StudentsTab> {
  String _filterScheduleId = 'All';

  @override
  Widget build(BuildContext context) {
    // Filter chips: All + each batch
    final chips = <String>['All',
      ...widget.myBatches.map((b) => b['CourseScheduleID'] as String? ?? '')];

    final filtered = _filterScheduleId == 'All'
        ? widget.students
        : widget.students.where((s) => widget.stuScheds.any((ss) =>
            ss['StudentEnrollmentNo'] == s['StudentEnrollmentNo'] &&
            ss['CourseScheduleID'] == _filterScheduleId)).toList();

    return SafeArea(child: Column(children: [
      const Padding(
        padding: EdgeInsets.fromLTRB(20, 16, 20, 8),
        child: Row(children: [
          Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text('My Students', style: TextStyle(fontFamily: 'Georgia',
                fontSize: 22, fontWeight: FontWeight.bold, color: Colors.white)),
            Text('Students enrolled in my batches',
                style: TextStyle(fontSize: 12, color: Color(0xFF556677))),
          ]),
        ])),

      // Filter chips
      ClipRect(child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.fromLTRB(20, 0, 20, 8),
        physics: const BouncingScrollPhysics(),
        child: Row(children: chips.map((id) {
          final isAll    = id == 'All';
          final active   = _filterScheduleId == id;
          final label    = isAll ? 'All'
              : widget.scheduleById(id)['BatchName'] as String? ?? 'Batch';
          return GestureDetector(
            onTap: () => setState(() => _filterScheduleId = id),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              margin: const EdgeInsets.only(right: 8),
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
              decoration: BoxDecoration(
                color: active ? const Color(0xFF1DB954) : const Color(0xFF152232),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: active
                    ? const Color(0xFF1DB954) : const Color(0xFF1E3347))),
              child: Text(label, style: TextStyle(fontSize: 12,
                  fontWeight: FontWeight.w500,
                  color: active ? Colors.white : const Color(0xFF8899AA)))));
        }).toList()))),

      // Count
      Padding(padding: const EdgeInsets.fromLTRB(20, 0, 20, 8),
        child: Text('${filtered.length} Students',
            style: const TextStyle(fontSize: 13, color: Color(0xFF8899AA),
                fontWeight: FontWeight.w500))),

      Expanded(child: filtered.isEmpty
          ? Center(child: Column(mainAxisSize: MainAxisSize.min, children: [
              Container(width: 64, height: 64,
                decoration: BoxDecoration(color: const Color(0xFF1DB954).withOpacity(0.08),
                    borderRadius: BorderRadius.circular(18)),
                child: const Icon(Icons.school_outlined,
                    color: Color(0xFF3A5068), size: 32)),
              const SizedBox(height: 12),
              const Text('No students found', style: TextStyle(
                  fontSize: 16, color: Colors.white, fontFamily: 'Georgia')),
            ]))
          : ListView(
              padding: const EdgeInsets.fromLTRB(20, 0, 20, 100),
              children: filtered.map((s) => _studentCard(s)).toList())),
    ]));
  }

  Widget _studentCard(Map<String, dynamic> s) {
    final name      = s['Name'] as String? ?? '—';
    final enrollNo  = s['StudentEnrollmentNo'] as String? ?? '';
    final contact   = s['Contact'] as Map<String, dynamic>? ?? {};
    final phone     = contact['phone'] as String? ?? '';
    final guardian  = s['GuardianInfo'] as Map<String, dynamic>? ?? {};
    final gName     = guardian['name'] as String? ?? '';
    final gPhone    = guardian['phone'] as String? ?? '';

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFF152232),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFF1E3347))),
      child: Row(children: [
        Container(width: 44, height: 44,
          decoration: BoxDecoration(
              color: const Color(0xFF5BA3D9).withOpacity(0.15),
              borderRadius: BorderRadius.circular(13)),
          child: Center(child: Text(name.substring(0, 1).toUpperCase(),
              style: const TextStyle(fontSize: 18,
                  fontWeight: FontWeight.bold, color: Color(0xFF5BA3D9))))),
        const SizedBox(width: 12),
        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(name, style: const TextStyle(fontSize: 14,
              fontWeight: FontWeight.w600, color: Colors.white)),
          Text(enrollNo, style: const TextStyle(fontSize: 10, color: Color(0xFF3A5068))),
          if (phone.isNotEmpty) Row(children: [
            const Icon(Icons.phone_outlined, color: Color(0xFF556677), size: 12),
            const SizedBox(width: 4),
            Text(phone, style: const TextStyle(fontSize: 11, color: Color(0xFF556677))),
          ]),
          if (gName.isNotEmpty) Row(children: [
            const Icon(Icons.people_outline_rounded, color: Color(0xFF556677), size: 12),
            const SizedBox(width: 4),
            Text('$gName · $gPhone', style: const TextStyle(
                fontSize: 11, color: Color(0xFF556677))),
          ]),
        ])),
      ]));
  }
}

// ══════════════════════════════════════════════════════════════════════════════
// More Tab
// ══════════════════════════════════════════════════════════════════════════════
class _MoreTab extends StatelessWidget {
  final Map<String, dynamic> staffDoc;
  final String clientId;
  final String enrollNo;
  final String uid;
  final String email;
  final VoidCallback onRefresh;

  const _MoreTab({
    required this.staffDoc, required this.clientId,
    required this.enrollNo, required this.uid,
    required this.email, required this.onRefresh,
  });

  @override
  Widget build(BuildContext context) {
    return SafeArea(child: ListView(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 100),
      children: [
        const Text('More', style: TextStyle(fontFamily: 'Georgia',
            fontSize: 22, fontWeight: FontWeight.bold, color: Colors.white)),
        const SizedBox(height: 4),
        const Text('Earnings · Profile · Settings',
            style: TextStyle(fontSize: 12, color: Color(0xFF556677))),
        const SizedBox(height: 24),

        // My Earnings
        _menuCard(context,
          icon: Icons.account_balance_wallet_outlined,
          color: const Color(0xFFE8A020),
          title: 'My Earnings',
          subtitle: 'Payroll history & pay slip download',
          onTap: () => Navigator.push(context, MaterialPageRoute(
              builder: (_) => StaffEarningsScreen(
                  clientId: clientId, enrollNo: enrollNo,
                  staffDoc: staffDoc))),
        ),
        const SizedBox(height: 10),

        // My Profile
        _menuCard(context,
          icon: Icons.person_outline_rounded,
          color: const Color(0xFF5BA3D9),
          title: 'My Profile',
          subtitle: 'Personal info, contact, photo',
          onTap: () => Navigator.push(context, MaterialPageRoute(
              builder: (_) => StaffProfileScreen(
                  uid: uid, clientId: clientId,
                  staffDoc: staffDoc, onUpdated: onRefresh))),
        ),
        const SizedBox(height: 10),

        // Change Password
        _menuCard(context,
          icon: Icons.lock_outline_rounded,
          color: const Color(0xFF7F77DD),
          title: 'Change Password',
          subtitle: 'Update your login credentials',
          onTap: () => Navigator.push(context, MaterialPageRoute(
              builder: (_) => StaffChangePasswordScreen(
                  uid: uid, enrollNo: enrollNo, email: email))),
        ),
        const SizedBox(height: 10),

        // Events placeholder
        _menuCard(context,
          icon: Icons.emoji_events_outlined,
          color: const Color(0xFF1DB954),
          title: 'Events',
          subtitle: 'Competitions, exams & certificates',
          badge: 'Coming Soon',
          onTap: () {},
        ),
        const SizedBox(height: 10),

        // Announcements placeholder
        _menuCard(context,
          icon: Icons.campaign_outlined,
          color: const Color(0xFFE8A020),
          title: 'Announcements',
          subtitle: 'Post notices to your students',
          badge: 'Coming Soon',
          onTap: () {},
        ),
        const SizedBox(height: 24),

        // Sign out
        GestureDetector(
          onTap: () async => FirebaseAuth.instance.signOut(),
          child: Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: const Color(0xFFE74C3C).withOpacity(0.08),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: const Color(0xFFE74C3C).withOpacity(0.3))),
            child: const Row(mainAxisAlignment: MainAxisAlignment.center, children: [
              Icon(Icons.logout_rounded, color: Color(0xFFE74C3C), size: 18),
              SizedBox(width: 8),
              Text('Sign Out', style: TextStyle(fontSize: 14,
                  fontWeight: FontWeight.w600, color: Color(0xFFE74C3C))),
            ]))),
      ],
    ));
  }

  Widget _menuCard(BuildContext context, {
    required IconData icon, required Color color,
    required String title, required String subtitle,
    required VoidCallback onTap, String? badge,
  }) => GestureDetector(onTap: onTap,
    child: Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFF152232), borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFF1E3347))),
      child: Row(children: [
        Container(width: 44, height: 44,
          decoration: BoxDecoration(color: color.withOpacity(0.12),
              borderRadius: BorderRadius.circular(13)),
          child: Icon(icon, color: color, size: 22)),
        const SizedBox(width: 14),
        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(title, style: const TextStyle(fontSize: 14,
              fontWeight: FontWeight.w600, color: Colors.white)),
          Text(subtitle, style: const TextStyle(
              fontSize: 11, color: Color(0xFF556677))),
        ])),
        if (badge != null) Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
          decoration: BoxDecoration(
              color: const Color(0xFF3A5068).withOpacity(0.3),
              borderRadius: BorderRadius.circular(8)),
          child: Text(badge, style: const TextStyle(
              fontSize: 10, color: Color(0xFF8899AA))))
        else const Icon(Icons.chevron_right_rounded,
            color: Color(0xFF3A5068), size: 20),
      ])));
}

// ══════════════════════════════════════════════════════════════════════════════
// Staff Earnings Screen
// ══════════════════════════════════════════════════════════════════════════════
class StaffEarningsScreen extends StatefulWidget {
  final String clientId;
  final String enrollNo;
  final Map<String, dynamic> staffDoc;

  const StaffEarningsScreen({super.key,
      required this.clientId, required this.enrollNo, required this.staffDoc});

  @override
  State<StaffEarningsScreen> createState() => _StaffEarningsScreenState();
}

class _StaffEarningsScreenState extends State<StaffEarningsScreen> {
  late DateTime _selectedMonth;
  List<Map<String, dynamic>> _allPayrolls = [];
  Map<String, dynamic>? _currentPayroll;
  bool _isLoading   = false;
  bool _isExporting = false;

  @override
  void initState() {
    super.initState();
    final now = DateTime.now();
    _selectedMonth = DateTime(now.year, now.month);
    _load();
  }

  String get _monthKey =>
      '${_selectedMonth.year}-${_selectedMonth.month.toString().padLeft(2, '0')}';

  String get _monthDisplay {
    const months = ['January','February','March','April','May','June',
        'July','August','September','October','November','December'];
    return '${months[_selectedMonth.month - 1]} ${_selectedMonth.year}';
  }

  Future<void> _load() async {
    setState(() => _isLoading = true);
    try {
      final db  = FirebaseFirestore.instance;

      QuerySnapshot? allSnap;
      try {
        allSnap = await db.collection('PayrollTransactions')
            .where('ClientID', isEqualTo: widget.clientId)
            .where('StaffEnrollmentNo', isEqualTo: widget.enrollNo)
            .orderBy('CreatedAt', descending: true).get();
      } catch (_) {
        allSnap = await db.collection('PayrollTransactions')
            .where('ClientID', isEqualTo: widget.clientId)
            .where('StaffEnrollmentNo', isEqualTo: widget.enrollNo).get();
      }

      final all = allSnap!.docs.map((d) =>
          {...(d.data() as Map<String,dynamic>), 'DocID': d.id}).toList();

      final current = all.firstWhere(
          (p) => p['PayrollMonth'] == _monthKey, orElse: () => {});

      if (mounted) setState(() {
        _allPayrolls    = all;
        _currentPayroll = current.isNotEmpty ? current : null;
        _isLoading      = false;
      });
    } catch (e) {
      debugPrint('Earnings load error: $e');
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0D1B2A),
      body: Stack(children: [
        _bgCircles(),
        SafeArea(child: Column(children: [
          // Top bar
          Padding(padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            child: Row(children: [
              GestureDetector(onTap: () => Navigator.pop(context),
                child: Container(width: 40, height: 40,
                  decoration: BoxDecoration(color: const Color(0xFF152232),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: const Color(0xFF1E3347))),
                  child: const Icon(Icons.arrow_back_ios_new_rounded,
                      color: Color(0xFF8899AA), size: 18))),
              const SizedBox(width: 14),
              const Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text('My Earnings', style: TextStyle(fontFamily: 'Georgia',
                    fontSize: 20, fontWeight: FontWeight.bold, color: Colors.white)),
                Text('Payroll history & pay slip',
                    style: TextStyle(fontSize: 12, color: Color(0xFF556677))),
              ])),
              // Export pay slip for selected month
              if (_currentPayroll != null)
                GestureDetector(
                  onTap: _isExporting ? null : _exportPaySlip,
                  child: Container(width: 40, height: 40,
                    decoration: BoxDecoration(
                      color: const Color(0xFF5BA3D9).withOpacity(0.12),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: const Color(0xFF5BA3D9).withOpacity(0.3))),
                    child: _isExporting
                        ? const Padding(padding: EdgeInsets.all(10),
                            child: CircularProgressIndicator(
                                color: Color(0xFF5BA3D9), strokeWidth: 2))
                        : const Icon(Icons.download_outlined,
                            color: Color(0xFF5BA3D9), size: 20))),
            ])),

          // Month selector
          Padding(padding: const EdgeInsets.fromLTRB(20, 0, 20, 12),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(color: const Color(0xFF152232),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: const Color(0xFF1E3347))),
              child: Row(children: [
                GestureDetector(onTap: () {
                  setState(() => _selectedMonth = DateTime(
                      _selectedMonth.year, _selectedMonth.month - 1));
                  _load();
                },
                  child: Container(width: 36, height: 36,
                    decoration: BoxDecoration(color: const Color(0xFF0D1B2A),
                        borderRadius: BorderRadius.circular(10)),
                    child: const Icon(Icons.chevron_left_rounded,
                        color: Color(0xFF8899AA), size: 22))),
                Expanded(child: Center(child: Text(_monthDisplay,
                    style: const TextStyle(fontSize: 16,
                        fontWeight: FontWeight.w600, color: Colors.white)))),
                GestureDetector(onTap: () {
                  final now = DateTime.now();
                  if (_selectedMonth.year == now.year &&
                      _selectedMonth.month == now.month) return;
                  setState(() => _selectedMonth = DateTime(
                      _selectedMonth.year, _selectedMonth.month + 1));
                  _load();
                },
                  child: Container(width: 36, height: 36,
                    decoration: BoxDecoration(color: const Color(0xFF0D1B2A),
                        borderRadius: BorderRadius.circular(10)),
                    child: const Icon(Icons.chevron_right_rounded,
                        color: Color(0xFF8899AA), size: 22))),
              ])),
          ),

          Expanded(child: _isLoading
              ? const Center(child: CircularProgressIndicator(
                  color: Color(0xFF1DB954), strokeWidth: 2))
              : RefreshIndicator(
                  onRefresh: _load,
                  color: const Color(0xFF1DB954),
                  backgroundColor: const Color(0xFF152232),
                  child: ListView(
                    padding: const EdgeInsets.fromLTRB(20, 0, 20, 100),
                    children: [
                      // Current month payroll card
                      if (_currentPayroll == null)
                        Container(
                          padding: const EdgeInsets.all(20),
                          decoration: BoxDecoration(
                            color: const Color(0xFF152232),
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(color: const Color(0xFF1E3347))),
                          child: Column(children: [
                            const Icon(Icons.pending_outlined,
                                color: Color(0xFF3A5068), size: 36),
                            const SizedBox(height: 12),
                            Text('No payroll for $_monthDisplay',
                                style: const TextStyle(fontSize: 15,
                                    color: Colors.white, fontFamily: 'Georgia')),
                            const SizedBox(height: 4),
                            const Text('Payroll has not been generated yet.',
                                style: TextStyle(fontSize: 12, color: Color(0xFF556677))),
                          ]))
                      else
                        _payrollDetailCard(_currentPayroll!),

                      const SizedBox(height: 20),

                      // All payroll history
                      if (_allPayrolls.isNotEmpty) ...[
                        const Text('Payroll History',
                            style: TextStyle(fontSize: 14,
                                fontWeight: FontWeight.w600, color: Colors.white)),
                        const SizedBox(height: 10),
                        ..._allPayrolls.map((p) {
                          final month   = p['PayrollMonthDisplay'] ?? p['PayrollMonth'] ?? '';
                          final amount  = (p['PaymentAmount'] as num?)?.toDouble() ?? 0;
                          final isPaid  = p['IsPaid'] == true;
                          final invoice = p['PayrollInvoiceNo'] ?? '—';
                          return Container(
                            margin: const EdgeInsets.only(bottom: 8),
                            padding: const EdgeInsets.symmetric(
                                horizontal: 14, vertical: 12),
                            decoration: BoxDecoration(
                              color: const Color(0xFF152232),
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(color: const Color(0xFF1E3347))),
                            child: Row(children: [
                              Expanded(child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                Text(month, style: const TextStyle(
                                    fontSize: 13, fontWeight: FontWeight.w500,
                                    color: Colors.white)),
                                Text(invoice, style: const TextStyle(
                                    fontSize: 10, color: Color(0xFF3A5068))),
                              ])),
                              Text('₹${amount.toStringAsFixed(2)}',
                                  style: const TextStyle(fontSize: 14,
                                      fontWeight: FontWeight.bold,
                                      color: Color(0xFF1DB954))),
                              const SizedBox(width: 8),
                              Container(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 7, vertical: 3),
                                decoration: BoxDecoration(
                                  color: isPaid
                                      ? const Color(0xFF1DB954).withOpacity(0.1)
                                      : const Color(0xFFE74C3C).withOpacity(0.1),
                                  borderRadius: BorderRadius.circular(6)),
                                child: Text(isPaid ? 'Paid' : 'Pending',
                                    style: TextStyle(fontSize: 10,
                                        fontWeight: FontWeight.w600,
                                        color: isPaid
                                            ? const Color(0xFF1DB954)
                                            : const Color(0xFFE74C3C)))),
                            ]));
                        }),
                      ],
                    ]))),
        ])),
      ]));
  }

  Widget _payrollDetailCard(Map<String, dynamic> p) {
    final amount     = (p['PaymentAmount'] as num?)?.toDouble() ?? 0;
    final isPaid     = p['IsPaid'] == true;
    final type       = p['PayrollType'] as String? ?? '—';
    final invoice    = p['PayrollInvoiceNo'] as String? ?? '—';
    final breakdown  = (p['PayrollBreakdown'] as List?)
        ?.map((b) => b as Map<String, dynamic>).toList() ?? [];
    final isPartnership = type == 'Partnership';

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFF152232),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: isPaid
              ? const Color(0xFF1DB954).withOpacity(0.4)
              : const Color(0xFF1E3347))),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Container(width: 44, height: 44,
            decoration: BoxDecoration(
              color: const Color(0xFFE8A020).withOpacity(0.12),
              borderRadius: BorderRadius.circular(13)),
            child: const Icon(Icons.account_balance_wallet_outlined,
                color: Color(0xFFE8A020), size: 22)),
          const SizedBox(width: 12),
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(_monthDisplay, style: const TextStyle(
                fontSize: 12, color: Color(0xFF556677))),
            Text('₹${amount.toStringAsFixed(2)}',
                style: const TextStyle(fontSize: 22,
                    fontWeight: FontWeight.bold, color: Colors.white)),
          ])),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
            decoration: BoxDecoration(
              color: isPaid
                  ? const Color(0xFF1DB954).withOpacity(0.1)
                  : const Color(0xFFE74C3C).withOpacity(0.1),
              borderRadius: BorderRadius.circular(8)),
            child: Text(isPaid ? 'Paid' : 'Pending',
                style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600,
                    color: isPaid ? const Color(0xFF1DB954) : const Color(0xFFE74C3C)))),
        ]),
        const SizedBox(height: 12),
        Row(children: [
          _infoChip(type, isPartnership ? const Color(0xFFE8A020) : const Color(0xFF5BA3D9)),
          const SizedBox(width: 8),
          _infoChip(invoice, const Color(0xFF3A5068)),
        ]),

        // Partnership breakdown
        if (isPartnership && breakdown.isNotEmpty) ...[
          const SizedBox(height: 14),
          const Divider(color: Color(0xFF1E3347)),
          const SizedBox(height: 8),
          const Text('Earnings Breakdown',
              style: TextStyle(fontSize: 12,
                  fontWeight: FontWeight.w500, color: Color(0xFF8899AA))),
          const SizedBox(height: 8),
          // Table header
          const Row(children: [
            Expanded(flex: 3, child: Text('Batch',
                style: TextStyle(fontSize: 10, color: Color(0xFF556677)))),
            Expanded(child: Text('Std', textAlign: TextAlign.center,
                style: TextStyle(fontSize: 10, color: Color(0xFF556677)))),
            Expanded(flex: 2, child: Text('Revenue', textAlign: TextAlign.right,
                style: TextStyle(fontSize: 10, color: Color(0xFF556677)))),
            Expanded(flex: 2, child: Text('Earning', textAlign: TextAlign.right,
                style: TextStyle(fontSize: 10, color: Color(0xFF556677)))),
          ]),
          const Divider(color: Color(0xFF1E3347), height: 12),
          ...breakdown.map((b) => Padding(
            padding: const EdgeInsets.symmetric(vertical: 5),
            child: Row(children: [
              Expanded(flex: 3, child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(b['CourseName'] ?? '—', style: const TextStyle(
                    fontSize: 12, color: Colors.white,
                    fontWeight: FontWeight.w500),
                    overflow: TextOverflow.ellipsis),
                Text(b['BatchName'] ?? '—', style: const TextStyle(
                    fontSize: 10, color: Color(0xFF556677))),
              ])),
              Expanded(child: Text('${b['StudentCount'] ?? 0}',
                  textAlign: TextAlign.center,
                  style: const TextStyle(fontSize: 12, color: Color(0xFF8899AA)))),
              Expanded(flex: 2, child: Text(
                  '₹${(b['Revenue'] as num?)?.toStringAsFixed(0) ?? '0'}',
                  textAlign: TextAlign.right,
                  style: const TextStyle(fontSize: 12, color: Color(0xFF8899AA)))),
              Expanded(flex: 2, child: Text(
                  '₹${(b['StaffAmount'] as num?)?.toStringAsFixed(2) ?? '0'}',
                  textAlign: TextAlign.right,
                  style: const TextStyle(fontSize: 12,
                      color: Color(0xFF1DB954), fontWeight: FontWeight.w600))),
            ]))),
          const Divider(color: Color(0xFF1E3347), height: 12),
          Row(children: [
            Expanded(child: Text(
              '${(breakdown.isNotEmpty ? breakdown.first['SharePercent'] as num? : 0)?.toStringAsFixed(0) ?? '?'}% of revenue',
              style: const TextStyle(fontSize: 11, color: Color(0xFF556677)))),
            Text('Total: ₹${amount.toStringAsFixed(2)}',
                style: const TextStyle(fontSize: 13,
                    fontWeight: FontWeight.bold, color: Color(0xFF1DB954))),
          ]),
        ],
      ]));
  }

  Widget _infoChip(String label, Color color) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
    decoration: BoxDecoration(
        color: color.withOpacity(0.12), borderRadius: BorderRadius.circular(6)),
    child: Text(label, style: TextStyle(fontSize: 10, color: color)));

  // ── Export Pay Slip PDF ────────────────────────────────────────────────────
  Future<void> _exportPaySlip() async {
    if (_currentPayroll == null) return;
    setState(() => _isExporting = true);
    try {
      final bytes = await _generatePaySlipPdf(_currentPayroll!);
      await Printing.sharePdf(
          bytes: bytes,
          filename: 'PaySlip_${widget.enrollNo}_$_monthKey.pdf');
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text('PDF export failed: $e'),
        backgroundColor: const Color(0xFFE74C3C)));
    } finally {
      if (mounted) setState(() => _isExporting = false);
    }
  }

  Future<Uint8List> _generatePaySlipPdf(Map<String, dynamic> p) async {
    final pdf       = pw.Document();
    final amount    = (p['PaymentAmount'] as num?)?.toDouble() ?? 0;
    final isPaid    = p['IsPaid'] == true;
    final type      = p['PayrollType'] as String? ?? '—';
    final invoice   = p['PayrollInvoiceNo'] as String? ?? '—';
    final breakdown = (p['PayrollBreakdown'] as List?)
        ?.map((b) => b as Map<String, dynamic>).toList() ?? [];
    final staffName = widget.staffDoc['StaffName'] as String? ?? widget.enrollNo;
    final role      = widget.staffDoc['Role'] as String? ?? 'Staff';
    final isPartnership = type == 'Partnership';

    pdf.addPage(pw.Page(
      pageFormat: PdfPageFormat.a4,
      margin: const pw.EdgeInsets.all(36),
      build: (ctx) => pw.Column(
          crossAxisAlignment: pw.CrossAxisAlignment.start, children: [
        // Header
        pw.Container(
          padding: const pw.EdgeInsets.all(16),
          decoration: pw.BoxDecoration(
              color: PdfColors.grey900,
              borderRadius: pw.BorderRadius.circular(8)),
          child: pw.Row(
              mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
              children: [
            pw.Column(crossAxisAlignment: pw.CrossAxisAlignment.start, children: [
              pw.Text('PAY SLIP', style: pw.TextStyle(
                  fontSize: 18, fontWeight: pw.FontWeight.bold,
                  color: PdfColors.white)),
              pw.Text(_monthDisplay, style: pw.TextStyle(
                  fontSize: 12, color: PdfColors.grey400)),
            ]),
            pw.Column(crossAxisAlignment: pw.CrossAxisAlignment.end, children: [
              pw.Text(invoice, style: pw.TextStyle(
                  fontSize: 12, fontWeight: pw.FontWeight.bold,
                  color: PdfColors.green400)),
              pw.Text(isPaid ? 'PAID' : 'PENDING',
                  style: pw.TextStyle(fontSize: 11, fontWeight: pw.FontWeight.bold,
                      color: isPaid ? PdfColors.green400 : PdfColors.red400)),
            ]),
          ])),
        pw.SizedBox(height: 16),

        // Staff info
        pw.Container(
          padding: const pw.EdgeInsets.all(14),
          decoration: pw.BoxDecoration(
              border: pw.Border.all(color: PdfColors.grey300),
              borderRadius: pw.BorderRadius.circular(6)),
          child: pw.Row(children: [
            pw.Expanded(child: pw.Column(
                crossAxisAlignment: pw.CrossAxisAlignment.start, children: [
              pw.Text('Staff Name', style: pw.TextStyle(fontSize: 9, color: PdfColors.grey600)),
              pw.Text(staffName, style: pw.TextStyle(fontSize: 14, fontWeight: pw.FontWeight.bold)),
            ])),
            pw.Expanded(child: pw.Column(
                crossAxisAlignment: pw.CrossAxisAlignment.start, children: [
              pw.Text('Enrollment No', style: pw.TextStyle(fontSize: 9, color: PdfColors.grey600)),
              pw.Text(widget.enrollNo, style: pw.TextStyle(fontSize: 12, fontWeight: pw.FontWeight.bold)),
            ])),
            pw.Expanded(child: pw.Column(
                crossAxisAlignment: pw.CrossAxisAlignment.start, children: [
              pw.Text('Role', style: pw.TextStyle(fontSize: 9, color: PdfColors.grey600)),
              pw.Text(role, style: pw.TextStyle(fontSize: 12)),
            ])),
            pw.Expanded(child: pw.Column(
                crossAxisAlignment: pw.CrossAxisAlignment.start, children: [
              pw.Text('Payroll Type', style: pw.TextStyle(fontSize: 9, color: PdfColors.grey600)),
              pw.Text(type, style: pw.TextStyle(fontSize: 12)),
            ])),
          ])),
        pw.SizedBox(height: 16),

        // Breakdown (Partnership only)
        if (isPartnership && breakdown.isNotEmpty) ...[
          pw.Text('Earnings Breakdown',
              style: pw.TextStyle(fontSize: 12, fontWeight: pw.FontWeight.bold)),
          pw.SizedBox(height: 8),
          pw.TableHelper.fromTextArray(
            headers: ['Course', 'Batch', 'Students', 'Fee/Month',
                'Revenue', 'Share%', 'Earning'],
            headerStyle: pw.TextStyle(fontWeight: pw.FontWeight.bold,
                fontSize: 9, color: PdfColors.white),
            headerDecoration: pw.BoxDecoration(color: PdfColors.grey800),
            cellStyle: pw.TextStyle(fontSize: 9),
            cellAlignments: {
              2: pw.Alignment.center,
              3: pw.Alignment.centerRight,
              4: pw.Alignment.centerRight,
              5: pw.Alignment.center,
              6: pw.Alignment.centerRight,
            },
            data: breakdown.map((b) => [
              b['CourseName'] ?? '—',
              b['BatchName'] ?? '—',
              '${b['StudentCount'] ?? 0}',
              '₹${(b['CourseFee'] as num?)?.toStringAsFixed(0) ?? '0'}',
              '₹${(b['Revenue'] as num?)?.toStringAsFixed(2) ?? '0'}',
              '${(b['SharePercent'] as num?)?.toStringAsFixed(0) ?? '?'}%',
              '₹${(b['StaffAmount'] as num?)?.toStringAsFixed(2) ?? '0'}',
            ]).toList()),
          pw.SizedBox(height: 8),
        ],

        // Fixed salary detail
        if (!isPartnership) ...[
          pw.Text('Salary Details',
              style: pw.TextStyle(fontSize: 12, fontWeight: pw.FontWeight.bold)),
          pw.SizedBox(height: 8),
          pw.Container(
            padding: const pw.EdgeInsets.all(12),
            decoration: pw.BoxDecoration(
                border: pw.Border.all(color: PdfColors.grey300),
                borderRadius: pw.BorderRadius.circular(6)),
            child: pw.Row(
                mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                children: [
              pw.Text('Monthly Fixed Salary',
                  style: pw.TextStyle(fontSize: 11)),
              pw.Text('₹${amount.toStringAsFixed(2)}',
                  style: pw.TextStyle(fontSize: 11,
                      fontWeight: pw.FontWeight.bold)),
            ])),
          pw.SizedBox(height: 8),
        ],

        // Net pay
        pw.Container(
          padding: const pw.EdgeInsets.all(14),
          decoration: pw.BoxDecoration(
            border: pw.Border.all(color: PdfColors.green700, width: 1.5),
            borderRadius: pw.BorderRadius.circular(8)),
          child: pw.Row(
              mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
              children: [
            pw.Text('NET PAY', style: pw.TextStyle(fontSize: 14,
                fontWeight: pw.FontWeight.bold, color: PdfColors.green700)),
            pw.Text('₹${amount.toStringAsFixed(2)}',
                style: pw.TextStyle(fontSize: 18,
                    fontWeight: pw.FontWeight.bold, color: PdfColors.green700)),
          ])),
        pw.SizedBox(height: 8),
        if (isPaid)
          pw.Text('Payment Status: PAID',
              style: pw.TextStyle(fontSize: 10, color: PdfColors.green700))
        else
          pw.Text('Payment Status: PENDING',
              style: pw.TextStyle(fontSize: 10, color: PdfColors.red400)),
      ]),
    ));

    return pdf.save();
  }

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
// Staff Profile Screen
// ══════════════════════════════════════════════════════════════════════════════
class StaffProfileScreen extends StatefulWidget {
  final String uid;
  final String clientId;
  final Map<String, dynamic> staffDoc;
  final VoidCallback onUpdated;

  const StaffProfileScreen({super.key,
      required this.uid, required this.clientId,
      required this.staffDoc, required this.onUpdated});

  @override
  State<StaffProfileScreen> createState() => _StaffProfileScreenState();
}

class _StaffProfileScreenState extends State<StaffProfileScreen> {
  late TextEditingController _nameCtrl;
  late TextEditingController _phoneCtrl;
  late TextEditingController _addressCtrl;
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    final contact = widget.staffDoc['StaffContact'] as Map<String, dynamic>? ?? {};
    _nameCtrl    = TextEditingController(text: widget.staffDoc['StaffName'] ?? '');
    _phoneCtrl   = TextEditingController(text: contact['phone'] ?? '');
    _addressCtrl = TextEditingController(text: widget.staffDoc['StaffAddress'] ?? '');
  }

  @override
  void dispose() {
    _nameCtrl.dispose(); _phoneCtrl.dispose(); _addressCtrl.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    setState(() => _isSaving = true);
    try {
      final docId   = widget.staffDoc['DocID'] as String? ?? '';
      final contact = Map<String, dynamic>.from(
          widget.staffDoc['StaffContact'] as Map<String, dynamic>? ?? {});
      contact['phone'] = _phoneCtrl.text.trim();

      await FirebaseFirestore.instance.collection('Staff').doc(docId).update({
        'StaffName':    _nameCtrl.text.trim(),
        'StaffContact': contact,
        'StaffAddress': _addressCtrl.text.trim(),
        'UpdatedAt':    FieldValue.serverTimestamp(),
      });
      widget.onUpdated();
      if (mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text('Profile updated!', style: TextStyle(color: Colors.white)),
          backgroundColor: Color(0xFF2ECC71)));
      }
    } catch (e) {
      setState(() => _isSaving = false);
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text('Failed: $e', style: const TextStyle(color: Colors.white)),
        backgroundColor: const Color(0xFFE74C3C)));
    }
  }

  @override
  Widget build(BuildContext context) {
    final enrollNo = widget.staffDoc['StaffEnrollmentNo'] ?? '';
    final role     = widget.staffDoc['Role'] ?? '';
    final contact  = widget.staffDoc['StaffContact'] as Map? ?? {};
    final email    = contact['email'] as String? ?? '';

    return Scaffold(
      backgroundColor: const Color(0xFF0D1B2A),
      body: SafeArea(child: Column(children: [
        Padding(padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          child: Row(children: [
            GestureDetector(onTap: () => Navigator.pop(context),
              child: Container(width: 40, height: 40,
                decoration: BoxDecoration(color: const Color(0xFF152232),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: const Color(0xFF1E3347))),
                child: const Icon(Icons.arrow_back_ios_new_rounded,
                    color: Color(0xFF8899AA), size: 18))),
            const SizedBox(width: 14),
            const Text('My Profile', style: TextStyle(fontFamily: 'Georgia',
                fontSize: 20, fontWeight: FontWeight.bold, color: Colors.white)),
          ])),

        Expanded(child: SingleChildScrollView(
          padding: const EdgeInsets.all(20),
          child: Column(children: [
            // Avatar
            Container(width: 80, height: 80,
              decoration: BoxDecoration(
                color: const Color(0xFFE8A020).withOpacity(0.15),
                shape: BoxShape.circle),
              child: Center(child: Text(
                (_nameCtrl.text.isNotEmpty ? _nameCtrl.text : 'S').substring(0, 1).toUpperCase(),
                style: const TextStyle(fontSize: 32,
                    fontWeight: FontWeight.bold, color: Color(0xFFE8A020))))),
            const SizedBox(height: 8),
            Text(enrollNo, style: const TextStyle(
                fontSize: 12, color: Color(0xFF556677))),
            Text(role, style: const TextStyle(
                fontSize: 13, color: Color(0xFF8899AA))),
            const SizedBox(height: 24),

            // Editable fields
            _lbl('Full Name'), const SizedBox(height: 8),
            _tf(ctrl: _nameCtrl, hint: 'Your full name'),
            const SizedBox(height: 14),
            _lbl('Phone'), const SizedBox(height: 8),
            _tf(ctrl: _phoneCtrl, hint: '+91 98765 43210',
                kb: TextInputType.phone),
            const SizedBox(height: 14),
            _lbl('Address'), const SizedBox(height: 8),
            _tf(ctrl: _addressCtrl, hint: 'Home address', maxLines: 2),

            const SizedBox(height: 14),
            // Email (read-only — change via settings)
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: const Color(0xFF0D1B2A),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: const Color(0xFF1E3347))),
              child: Row(children: [
                const Icon(Icons.email_outlined, color: Color(0xFF3A5068), size: 18),
                const SizedBox(width: 10),
                Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  const Text('Email', style: TextStyle(fontSize: 10, color: Color(0xFF556677))),
                  Text(email, style: const TextStyle(fontSize: 13, color: Color(0xFF8899AA))),
                ])),
                const Text('Change in Settings',
                    style: TextStyle(fontSize: 10, color: Color(0xFF3A5068))),
              ])),

            const SizedBox(height: 24),
            SizedBox(width: double.infinity, child: ElevatedButton(
              onPressed: _isSaving ? null : _save,
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF1DB954),
                foregroundColor: Colors.white,
                elevation: 0,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                padding: const EdgeInsets.symmetric(vertical: 14)),
              child: _isSaving
                  ? const SizedBox(width: 20, height: 20,
                      child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                  : const Text('Save Changes',
                      style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600)))),
          ]))),  // closes Column, SingleChildScrollView, Expanded
      ])));  // closes Column children, SafeArea
  }

  Widget _lbl(String t) => Align(alignment: Alignment.centerLeft,
      child: Text(t, style: const TextStyle(fontSize: 13,
          fontWeight: FontWeight.w500, color: Color(0xFF8899AA))));

  Widget _tf({required TextEditingController ctrl, required String hint,
      TextInputType kb = TextInputType.text, int maxLines = 1}) =>
    TextField(controller: ctrl, keyboardType: kb, maxLines: maxLines,
      style: const TextStyle(color: Colors.white, fontSize: 15),
      cursorColor: const Color(0xFF1DB954),
      decoration: InputDecoration(hintText: hint,
        hintStyle: const TextStyle(color: Color(0xFF3A5068)),
        filled: true, fillColor: const Color(0xFF152232),
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12),
            borderSide: const BorderSide(color: Color(0xFF1E3347))),
        enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12),
            borderSide: const BorderSide(color: Color(0xFF1E3347))),
        focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12),
            borderSide: const BorderSide(color: Color(0xFF1DB954), width: 1.5))));
}

// ══════════════════════════════════════════════════════════════════════════════
// Change Password Screen
// ══════════════════════════════════════════════════════════════════════════════
class StaffChangePasswordScreen extends StatefulWidget {
  final String uid;
  final String enrollNo;
  final String email;

  const StaffChangePasswordScreen({super.key,
      required this.uid, required this.enrollNo, required this.email});

  @override
  State<StaffChangePasswordScreen> createState() =>
      _StaffChangePasswordScreenState();
}

class _StaffChangePasswordScreenState
    extends State<StaffChangePasswordScreen> {
  final _currentCtrl = TextEditingController();
  final _newCtrl     = TextEditingController();
  final _confirmCtrl = TextEditingController();
  final _emailCtrl   = TextEditingController();
  bool _obscureCur   = true;
  bool _obscureNew   = true;
  bool _obscureCon   = true;
  bool _isSaving     = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _emailCtrl.text = widget.email;
  }

  @override
  void dispose() {
    _currentCtrl.dispose(); _newCtrl.dispose();
    _confirmCtrl.dispose(); _emailCtrl.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    setState(() { _error = null; _isSaving = true; });
    if (_newCtrl.text.trim().length < 6) {
      setState(() { _error = 'New password must be at least 6 characters.'; _isSaving = false; }); return;
    }
    if (_newCtrl.text.trim() != _confirmCtrl.text.trim()) {
      setState(() { _error = 'Passwords do not match.'; _isSaving = false; }); return;
    }
    try {
      final user = FirebaseAuth.instance.currentUser!;
      // Re-authenticate
      final cred = EmailAuthProvider.credential(
          email: user.email!, password: _currentCtrl.text.trim());
      await user.reauthenticateWithCredential(cred);
      // Update password
      await user.updatePassword(_newCtrl.text.trim());
      // Update email if changed
      final newEmail = _emailCtrl.text.trim();
      if (newEmail.isNotEmpty && newEmail != user.email) {
        await user.verifyBeforeUpdateEmail(newEmail);
        await FirebaseFirestore.instance
            .collection('ClientAuthorizedUsers').doc(widget.uid)
            .update({'Email': newEmail, 'UpdatedAt': FieldValue.serverTimestamp()});
      }
      if (mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text('Password updated successfully!',
              style: TextStyle(color: Colors.white)),
          backgroundColor: Color(0xFF2ECC71)));
      }
    } on FirebaseAuthException catch (e) {
      String msg = 'Failed to update password.';
      if (e.code == 'wrong-password') msg = 'Current password is incorrect.';
      if (e.code == 'too-many-requests') msg = 'Too many attempts. Try later.';
      setState(() { _error = msg; _isSaving = false; });
    } catch (e) {
      setState(() { _error = e.toString(); _isSaving = false; });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0D1B2A),
      body: SafeArea(child: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            GestureDetector(onTap: () => Navigator.pop(context),
              child: Container(width: 40, height: 40,
                decoration: BoxDecoration(color: const Color(0xFF152232),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: const Color(0xFF1E3347))),
                child: const Icon(Icons.arrow_back_ios_new_rounded,
                    color: Color(0xFF8899AA), size: 18))),
            const SizedBox(width: 14),
            const Text('Change Password', style: TextStyle(fontFamily: 'Georgia',
                fontSize: 20, fontWeight: FontWeight.bold, color: Colors.white)),
          ]),
          const SizedBox(height: 28),

          _lbl('Email Address'), const SizedBox(height: 8),
          _tf(ctrl: _emailCtrl, hint: 'your@email.com',
              kb: TextInputType.emailAddress),
          const SizedBox(height: 6),
          const Text('Update if you want to change your login email.',
              style: TextStyle(fontSize: 11, color: Color(0xFF556677))),
          const SizedBox(height: 16),

          _lbl('Current Password'), const SizedBox(height: 8),
          _passField(_currentCtrl, _obscureCur,
              () => setState(() => _obscureCur = !_obscureCur)),
          const SizedBox(height: 14),

          _lbl('New Password'), const SizedBox(height: 8),
          _passField(_newCtrl, _obscureNew,
              () => setState(() => _obscureNew = !_obscureNew)),
          const SizedBox(height: 14),

          _lbl('Confirm New Password'), const SizedBox(height: 8),
          _passField(_confirmCtrl, _obscureCon,
              () => setState(() => _obscureCon = !_obscureCon)),

          if (_error != null) ...[
            const SizedBox(height: 14),
            Container(padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: const Color(0xFFE74C3C).withOpacity(0.08),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: const Color(0xFFE74C3C).withOpacity(0.3))),
              child: Row(children: [
                const Icon(Icons.error_outline_rounded,
                    color: Color(0xFFE74C3C), size: 16),
                const SizedBox(width: 8),
                Expanded(child: Text(_error!,
                    style: const TextStyle(fontSize: 12,
                        color: Color(0xFFE74C3C), height: 1.4))),
              ])),
          ],
          const SizedBox(height: 24),

          SizedBox(width: double.infinity, child: ElevatedButton(
            onPressed: _isSaving ? null : _save,
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF1DB954),
              foregroundColor: Colors.white, elevation: 0,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
              padding: const EdgeInsets.symmetric(vertical: 14)),
            child: _isSaving
                ? const SizedBox(width: 20, height: 20,
                    child: CircularProgressIndicator(
                        color: Colors.white, strokeWidth: 2))
                : const Text('Update Password',
                    style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600)))),
        ]))));
  }

  Widget _lbl(String t) => Text(t, style: const TextStyle(
      fontSize: 13, fontWeight: FontWeight.w500, color: Color(0xFF8899AA)));

  Widget _tf({required TextEditingController ctrl, required String hint,
      TextInputType kb = TextInputType.text}) =>
    TextField(controller: ctrl, keyboardType: kb,
      style: const TextStyle(color: Colors.white),
      cursorColor: const Color(0xFF1DB954),
      decoration: InputDecoration(hintText: hint,
        hintStyle: const TextStyle(color: Color(0xFF3A5068)),
        filled: true, fillColor: const Color(0xFF152232),
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12),
            borderSide: const BorderSide(color: Color(0xFF1E3347))),
        enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12),
            borderSide: const BorderSide(color: Color(0xFF1E3347))),
        focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12),
            borderSide: const BorderSide(color: Color(0xFF1DB954), width: 1.5))));

  Widget _passField(TextEditingController ctrl, bool obscure,
      VoidCallback toggle) =>
    TextField(controller: ctrl, obscureText: obscure,
      style: const TextStyle(color: Colors.white),
      cursorColor: const Color(0xFF1DB954),
      decoration: InputDecoration(
        prefixIcon: const Icon(Icons.lock_outline_rounded,
            color: Color(0xFF3A5068), size: 20),
        suffixIcon: GestureDetector(onTap: toggle,
          child: Icon(obscure ? Icons.visibility_outlined
              : Icons.visibility_off_outlined,
              color: const Color(0xFF3A5068), size: 20)),
        filled: true, fillColor: const Color(0xFF152232),
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12),
            borderSide: const BorderSide(color: Color(0xFF1E3347))),
        enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12),
            borderSide: const BorderSide(color: Color(0xFF1E3347))),
        focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12),
            borderSide: const BorderSide(color: Color(0xFF1DB954), width: 1.5))));
}  // end _StaffChangePasswordScreenState

// ══════════════════════════════════════════════════════════════════════════════
// Attendance Screen — Mark attendance for a batch
// ══════════════════════════════════════════════════════════════════════════════
class AttendanceScreen extends StatefulWidget {
  final String clientId;
  final String enrollNo;
  final String scheduleId;
  final String batchName;
  final String courseName;
  final List<Map<String, dynamic>> students;

  const AttendanceScreen({super.key,
      required this.clientId, required this.enrollNo,
      required this.scheduleId, required this.batchName,
      required this.courseName, required this.students});

  @override
  State<AttendanceScreen> createState() => _AttendanceScreenState();
}

class _AttendanceScreenState extends State<AttendanceScreen> {
  DateTime _selectedDate = DateTime.now();
  Map<String, bool> _attendance = {};
  bool _isLoading = false;
  bool _isSaving  = false;
  bool _alreadySaved = false;

  @override
  void initState() {
    super.initState();
    for (final s in widget.students) {
      _attendance[s['StudentEnrollmentNo'] ?? ''] = true;
    }
    _checkExisting();
  }

  String get _dateKey =>
      '${_selectedDate.year}-${_selectedDate.month.toString().padLeft(2, '0')}-'
      '${_selectedDate.day.toString().padLeft(2, '0')}';

  Future<void> _checkExisting() async {
    setState(() => _isLoading = true);
    try {
      final snap = await FirebaseFirestore.instance
          .collection('Attendance')
          .where('ClientID', isEqualTo: widget.clientId)
          .where('CourseScheduleID', isEqualTo: widget.scheduleId)
          .where('Date', isEqualTo: _dateKey)
          .limit(1).get();

      if (snap.docs.isNotEmpty) {
        final data = snap.docs.first.data();
        final records = (data['Records'] as List?)
            ?.map((r) => r as Map<String, dynamic>).toList() ?? [];
        final map = <String, bool>{};
        for (final r in records) {
          map[r['StudentEnrollmentNo'] as String? ?? ''] =
              r['IsPresent'] as bool? ?? false;
        }
        setState(() { _attendance = map; _alreadySaved = true; });
      } else {
        setState(() => _alreadySaved = false);
      }
    } catch (e) { debugPrint('Attendance check error: $e'); }
    finally { if (mounted) setState(() => _isLoading = false); }
  }

  Future<void> _save() async {
    setState(() => _isSaving = true);
    try {
      final db      = FirebaseFirestore.instance;
      final records = widget.students.map((s) {
        final enNo = s['StudentEnrollmentNo'] as String? ?? '';
        return {
          'StudentEnrollmentNo': enNo,
          'StudentName':         s['Name'] ?? '',
          'IsPresent':           _attendance[enNo] ?? false,
        };
      }).toList();

      final presentCount = records.where((r) => r['IsPresent'] == true).length;

      // Check if exists
      final existing = await db.collection('Attendance')
          .where('ClientID', isEqualTo: widget.clientId)
          .where('CourseScheduleID', isEqualTo: widget.scheduleId)
          .where('Date', isEqualTo: _dateKey)
          .limit(1).get();

      if (existing.docs.isNotEmpty) {
        await existing.docs.first.reference.update({
          'Records':      records,
          'PresentCount': presentCount,
          'AbsentCount':  records.length - presentCount,
          'UpdatedAt':    FieldValue.serverTimestamp(),
        });
      } else {
        final ref = db.collection('Attendance').doc();
        await ref.set({
          'AttendanceID':    ref.id,
          'ClientID':        widget.clientId,
          'CourseScheduleID': widget.scheduleId,
          'StaffEnrollmentNo': widget.enrollNo,
          'Date':            _dateKey,
          'Records':         records,
          'PresentCount':    presentCount,
          'AbsentCount':     records.length - presentCount,
          'CreatedAt':       FieldValue.serverTimestamp(),
        });
      }
      setState(() => _alreadySaved = true);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text('Attendance saved! $presentCount/${records.length} present',
              style: const TextStyle(color: Colors.white)),
          backgroundColor: const Color(0xFF2ECC71),
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          margin: const EdgeInsets.all(16)));
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text('Failed: $e'), backgroundColor: const Color(0xFFE74C3C)));
    } finally { if (mounted) setState(() => _isSaving = false); }
  }

  @override
  Widget build(BuildContext context) {
    final presentCount = _attendance.values.where((v) => v).length;
    final total = widget.students.length;

    return Scaffold(
      backgroundColor: const Color(0xFF0D1B2A),
      body: SafeArea(child: Column(children: [
        // Top bar
        Padding(padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          child: Row(children: [
            GestureDetector(onTap: () => Navigator.pop(context),
              child: Container(width: 40, height: 40,
                decoration: BoxDecoration(color: const Color(0xFF152232),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: const Color(0xFF1E3347))),
                child: const Icon(Icons.arrow_back_ios_new_rounded,
                    color: Color(0xFF8899AA), size: 18))),
            const SizedBox(width: 14),
            Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(widget.courseName, style: const TextStyle(fontFamily: 'Georgia',
                  fontSize: 17, fontWeight: FontWeight.bold, color: Colors.white)),
              Text('${widget.batchName} · Attendance',
                  style: const TextStyle(fontSize: 11, color: Color(0xFF556677))),
            ])),
          ])),

        // Date selector
        Padding(padding: const EdgeInsets.fromLTRB(20, 0, 20, 12),
          child: GestureDetector(
            onTap: () async {
              final picked = await showDatePicker(
                context: context,
                initialDate: _selectedDate,
                firstDate: DateTime(2024),
                lastDate: DateTime.now(),
                builder: (ctx, child) => Theme(
                  data: ThemeData.dark().copyWith(
                    colorScheme: const ColorScheme.dark(
                        primary: Color(0xFF1DB954))),
                  child: child!));
              if (picked != null) {
                setState(() => _selectedDate = picked);
                _checkExisting();
              }
            },
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              decoration: BoxDecoration(
                color: const Color(0xFF152232),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: const Color(0xFF1DB954).withOpacity(0.3))),
              child: Row(children: [
                const Icon(Icons.calendar_today_rounded,
                    color: Color(0xFF1DB954), size: 18),
                const SizedBox(width: 10),
                Text(_dateKey, style: const TextStyle(
                    fontSize: 15, fontWeight: FontWeight.w500, color: Colors.white)),
                const Spacer(),
                const Text('Change', style: TextStyle(
                    fontSize: 12, color: Color(0xFF1DB954))),
              ]))),
        ),

        // Stats + mark all
        Padding(padding: const EdgeInsets.fromLTRB(20, 0, 20, 12),
          child: Row(children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                  color: const Color(0xFF1DB954).withOpacity(0.1),
                  borderRadius: BorderRadius.circular(10)),
              child: Text('$presentCount / $total Present',
                  style: const TextStyle(fontSize: 13,
                      fontWeight: FontWeight.w600, color: Color(0xFF1DB954)))),
            const Spacer(),
            TextButton(
              onPressed: () => setState(() =>
                  _attendance.updateAll((k, v) => true)),
              child: const Text('All Present',
                  style: TextStyle(color: Color(0xFF1DB954), fontSize: 12))),
            TextButton(
              onPressed: () => setState(() =>
                  _attendance.updateAll((k, v) => false)),
              child: const Text('All Absent',
                  style: TextStyle(color: Color(0xFFE74C3C), fontSize: 12))),
          ])),

        // Student list
        Expanded(child: _isLoading
            ? const Center(child: CircularProgressIndicator(
                color: Color(0xFF1DB954), strokeWidth: 2))
            : widget.students.isEmpty
                ? const Center(child: Text('No students in this batch.',
                    style: TextStyle(color: Color(0xFF556677))))
                : ListView(
                    padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
                    children: widget.students.map((s) {
                      final enNo    = s['StudentEnrollmentNo'] as String? ?? '';
                      final name    = s['Name'] as String? ?? '—';
                      final present = _attendance[enNo] ?? true;
                      return Container(
                        margin: const EdgeInsets.only(bottom: 8),
                        padding: const EdgeInsets.symmetric(
                            horizontal: 14, vertical: 12),
                        decoration: BoxDecoration(
                          color: const Color(0xFF152232),
                          borderRadius: BorderRadius.circular(14),
                          border: Border.all(
                            color: present
                                ? const Color(0xFF1DB954).withOpacity(0.3)
                                : const Color(0xFFE74C3C).withOpacity(0.3))),
                        child: Row(children: [
                          Container(width: 38, height: 38,
                            decoration: BoxDecoration(
                              color: present
                                  ? const Color(0xFF1DB954).withOpacity(0.12)
                                  : const Color(0xFFE74C3C).withOpacity(0.08),
                              borderRadius: BorderRadius.circular(11)),
                            child: Center(child: Text(
                                name.substring(0, 1).toUpperCase(),
                                style: TextStyle(fontSize: 16,
                                    fontWeight: FontWeight.bold,
                                    color: present
                                        ? const Color(0xFF1DB954)
                                        : const Color(0xFFE74C3C))))),
                          const SizedBox(width: 12),
                          Expanded(child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                            Text(name, style: const TextStyle(fontSize: 14,
                                fontWeight: FontWeight.w500, color: Colors.white)),
                            Text(enNo, style: const TextStyle(
                                fontSize: 10, color: Color(0xFF3A5068))),
                          ])),
                          // Toggle
                          GestureDetector(
                            onTap: () => setState(() =>
                                _attendance[enNo] = !present),
                            child: AnimatedContainer(
                              duration: const Duration(milliseconds: 200),
                              width: 70, height: 32,
                              decoration: BoxDecoration(
                                color: present
                                    ? const Color(0xFF1DB954)
                                    : const Color(0xFF152232),
                                borderRadius: BorderRadius.circular(8),
                                border: Border.all(
                                    color: present
                                        ? const Color(0xFF1DB954)
                                        : const Color(0xFFE74C3C))),
                              child: Center(child: Text(
                                  present ? 'Present' : 'Absent',
                                  style: TextStyle(fontSize: 11,
                                      fontWeight: FontWeight.w600,
                                      color: present
                                          ? Colors.white
                                          : const Color(0xFFE74C3C)))))),
                        ]));
                    }).toList())),

        // Save button
        Padding(padding: const EdgeInsets.all(20),
          child: SizedBox(width: double.infinity,
            child: ElevatedButton(
              onPressed: _isSaving ? null : _save,
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF1DB954),
                foregroundColor: Colors.white, elevation: 0,
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14)),
                padding: const EdgeInsets.symmetric(vertical: 14)),
              child: _isSaving
                  ? const SizedBox(width: 20, height: 20,
                      child: CircularProgressIndicator(
                          color: Colors.white, strokeWidth: 2))
                  : Text(_alreadySaved ? 'Update Attendance' : 'Save Attendance',
                      style: const TextStyle(fontSize: 15,
                          fontWeight: FontWeight.w600))))),
      ])));
  }
}

// ══════════════════════════════════════════════════════════════════════════════
// Attendance History Screen
// ══════════════════════════════════════════════════════════════════════════════
class AttendanceHistoryScreen extends StatefulWidget {
  final String clientId;
  final String scheduleId;
  final String batchName;
  final String courseName;
  final List<Map<String, dynamic>> students;

  const AttendanceHistoryScreen({super.key,
      required this.clientId, required this.scheduleId,
      required this.batchName, required this.courseName,
      required this.students});

  @override
  State<AttendanceHistoryScreen> createState() =>
      _AttendanceHistoryScreenState();
}

class _AttendanceHistoryScreenState extends State<AttendanceHistoryScreen> {
  List<Map<String, dynamic>> _records = [];
  bool _isLoading = true;

  @override
  void initState() { super.initState(); _load(); }

  Future<void> _load() async {
    setState(() => _isLoading = true);
    try {
      QuerySnapshot? snap;
      try {
        snap = await FirebaseFirestore.instance
            .collection('Attendance')
            .where('ClientID', isEqualTo: widget.clientId)
            .where('CourseScheduleID', isEqualTo: widget.scheduleId)
            .orderBy('Date', descending: true)
            .get();
      } catch (_) {
        snap = await FirebaseFirestore.instance
            .collection('Attendance')
            .where('ClientID', isEqualTo: widget.clientId)
            .where('CourseScheduleID', isEqualTo: widget.scheduleId)
            .get();
      }
      if (mounted) setState(() {
        _records = snap!.docs.map((d) =>
            {...(d.data() as Map<String,dynamic>), 'DocID': d.id}).toList();
        _isLoading = false;
      });
    } catch (e) {
      debugPrint('Attendance history error: $e');
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0D1B2A),
      body: SafeArea(child: Column(children: [
        Padding(padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          child: Row(children: [
            GestureDetector(onTap: () => Navigator.pop(context),
              child: Container(width: 40, height: 40,
                decoration: BoxDecoration(color: const Color(0xFF152232),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: const Color(0xFF1E3347))),
                child: const Icon(Icons.arrow_back_ios_new_rounded,
                    color: Color(0xFF8899AA), size: 18))),
            const SizedBox(width: 14),
            Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(widget.courseName, style: const TextStyle(fontFamily: 'Georgia',
                  fontSize: 17, fontWeight: FontWeight.bold, color: Colors.white)),
              Text('${widget.batchName} · History',
                  style: const TextStyle(fontSize: 11, color: Color(0xFF556677))),
            ])),
          ])),

        Expanded(child: _isLoading
            ? const Center(child: CircularProgressIndicator(
                color: Color(0xFF1DB954), strokeWidth: 2))
            : RefreshIndicator(
                onRefresh: _load,
                color: const Color(0xFF1DB954),
                backgroundColor: const Color(0xFF152232),
                child: _records.isEmpty
                    ? Center(child: Column(mainAxisSize: MainAxisSize.min, children: [
                        Container(width: 64, height: 64,
                          decoration: BoxDecoration(
                              color: const Color(0xFF1DB954).withOpacity(0.08),
                              borderRadius: BorderRadius.circular(18)),
                          child: const Icon(Icons.history_rounded,
                              color: Color(0xFF3A5068), size: 32)),
                        const SizedBox(height: 12),
                        const Text('No attendance records yet',
                            style: TextStyle(fontSize: 16,
                                color: Colors.white, fontFamily: 'Georgia')),
                      ]))
                    : ListView(
                        padding: const EdgeInsets.fromLTRB(20, 0, 20, 100),
                        children: _records.map((r) {
                          final date     = r['Date'] as String? ?? '—';
                          final present  = r['PresentCount'] as int? ?? 0;
                          final absent   = r['AbsentCount'] as int? ?? 0;
                          final total    = present + absent;
                          final pct      = total > 0
                              ? (present / total * 100).toStringAsFixed(0) : '0';
                          return Container(
                            margin: const EdgeInsets.only(bottom: 10),
                            padding: const EdgeInsets.all(14),
                            decoration: BoxDecoration(
                              color: const Color(0xFF152232),
                              borderRadius: BorderRadius.circular(14),
                              border: Border.all(color: const Color(0xFF1E3347))),
                            child: Row(children: [
                              Container(width: 44, height: 44,
                                decoration: BoxDecoration(
                                  color: const Color(0xFF1DB954).withOpacity(0.1),
                                  borderRadius: BorderRadius.circular(12)),
                                child: Center(child: Text('$pct%',
                                    style: const TextStyle(fontSize: 12,
                                        fontWeight: FontWeight.bold,
                                        color: Color(0xFF1DB954))))),
                              const SizedBox(width: 12),
                              Expanded(child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                Text(date, style: const TextStyle(
                                    fontSize: 14, fontWeight: FontWeight.w600,
                                    color: Colors.white)),
                                Text('$present present · $absent absent',
                                    style: const TextStyle(
                                        fontSize: 11, color: Color(0xFF556677))),
                              ])),
                              // Linear bar
                              Column(children: [
                                SizedBox(width: 60,
                                  child: ClipRRect(
                                    borderRadius: BorderRadius.circular(3),
                                    child: LinearProgressIndicator(
                                      value: total > 0 ? present / total : 0,
                                      backgroundColor: const Color(0xFFE74C3C).withOpacity(0.3),
                                      valueColor: const AlwaysStoppedAnimation<Color>(
                                          Color(0xFF1DB954)),
                                      minHeight: 6))),
                              ]),
                            ]));
                        }).toList()))),
      ])));
  }
}

// ══════════════════════════════════════════════════════════════════════════════
// Online Class Screen
// ══════════════════════════════════════════════════════════════════════════════
class OnlineClassScreen extends StatefulWidget {
  final String clientId;
  final String enrollNo;
  final String scheduleId;
  final String batchName;
  final String courseName;

  const OnlineClassScreen({super.key,
      required this.clientId, required this.enrollNo,
      required this.scheduleId, required this.batchName,
      required this.courseName});

  @override
  State<OnlineClassScreen> createState() => _OnlineClassScreenState();
}

class _OnlineClassScreenState extends State<OnlineClassScreen> {
  List<Map<String, dynamic>> _classes = [];
  bool _isLoading = true;

  @override
  void initState() { super.initState(); _load(); }

  Future<void> _load() async {
    setState(() => _isLoading = true);
    try {
      QuerySnapshot? snap;
      try {
        snap = await FirebaseFirestore.instance
            .collection('OnlineClass')
            .where('ClientID', isEqualTo: widget.clientId)
            .where('CourseScheduleID', isEqualTo: widget.scheduleId)
            .orderBy('ClassDate', descending: true)
            .get();
      } catch (_) {
        snap = await FirebaseFirestore.instance
            .collection('OnlineClass')
            .where('ClientID', isEqualTo: widget.clientId)
            .where('CourseScheduleID', isEqualTo: widget.scheduleId).get();
      }
      if (mounted) setState(() {
        _classes = snap!.docs.map((d) =>
            {...(d.data() as Map<String,dynamic>), 'DocID': d.id}).toList();
        _isLoading = false;
      });
    } catch (e) { if (mounted) setState(() => _isLoading = false); }
  }

  void _showAddClassSheet() {
    final linkCtrl    = TextEditingController();
    final dateCtrl    = TextEditingController();
    final timeCtrl    = TextEditingController();
    String platform   = 'Google Meet';
    bool saving       = false;
    final platforms   = ['Google Meet', 'Zoom', 'Microsoft Teams', 'Custom URL'];

    showModalBottomSheet(
      context: context, isScrollControlled: true, backgroundColor: Colors.transparent,
      builder: (ctx) => StatefulBuilder(builder: (ctx, ss) => Padding(
        padding: EdgeInsets.only(bottom: MediaQuery.of(ctx).viewInsets.bottom),
        child: Container(
          decoration: const BoxDecoration(color: Color(0xFF152232),
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
                decoration: BoxDecoration(color: const Color(0xFF7F77DD).withOpacity(0.12),
                    borderRadius: BorderRadius.circular(10)),
                child: const Icon(Icons.videocam_outlined,
                    color: Color(0xFF7F77DD), size: 18)),
              const SizedBox(width: 12),
              const Text('Schedule Online Class', style: TextStyle(
                  fontFamily: 'Georgia', fontSize: 18,
                  fontWeight: FontWeight.bold, color: Colors.white)),
            ]),
            const SizedBox(height: 20),

            // Platform chips
            _lbl('Platform'),
            const SizedBox(height: 8),
            Wrap(spacing: 8, children: platforms.map((p) {
              final sel = platform == p;
              return GestureDetector(
                onTap: () => ss(() => platform = p),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 150),
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: sel ? const Color(0xFF7F77DD) : const Color(0xFF0D1B2A),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: sel ? const Color(0xFF7F77DD) : const Color(0xFF1E3347))),
                  child: Text(p, style: TextStyle(fontSize: 11,
                      color: sel ? Colors.white : const Color(0xFF8899AA)))));
            }).toList()),
            const SizedBox(height: 14),

            // Date
            _lbl('Class Date *'), const SizedBox(height: 8),
            _tf(ctrl: dateCtrl, hint: 'YYYY-MM-DD', icon: Icons.calendar_today_outlined),
            const SizedBox(height: 12),

            // Time
            _lbl('Class Time *'), const SizedBox(height: 8),
            _tf(ctrl: timeCtrl, hint: 'e.g. 10:00 AM', icon: Icons.access_time_rounded),
            const SizedBox(height: 12),

            // Link
            _lbl('Join Link *'), const SizedBox(height: 8),
            _tf(ctrl: linkCtrl, hint: 'https://meet.google.com/...',
                icon: Icons.link_rounded, kb: TextInputType.url),
            const SizedBox(height: 20),

            SizedBox(width: double.infinity, child: ElevatedButton(
              onPressed: saving ? null : () async {
                if (linkCtrl.text.trim().isEmpty ||
                    dateCtrl.text.trim().isEmpty) return;
                ss(() => saving = true);
                try {
                  final db  = FirebaseFirestore.instance;
                  final ref = db.collection('OnlineClass').doc();
                  await ref.set({
                    'ClassID':           ref.id,
                    'ClientID':          widget.clientId,
                    'CourseScheduleID':  widget.scheduleId,
                    'StaffEnrollmentNo': widget.enrollNo,
                    'ClassDate':         dateCtrl.text.trim(),
                    'ClassTime':         timeCtrl.text.trim(),
                    'JoinLink':          linkCtrl.text.trim(),
                    'Platform':          platform,
                    'IsActive':          true,
                    'CreatedAt':         FieldValue.serverTimestamp(),
                  });
                  if (ctx.mounted) Navigator.pop(ctx);
                  await _load();
                } catch (e) { ss(() => saving = false); }
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF7F77DD),
                foregroundColor: Colors.white, elevation: 0,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                padding: const EdgeInsets.symmetric(vertical: 14)),
              child: saving
                  ? const SizedBox(width: 20, height: 20,
                      child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                  : const Text('Schedule Class',
                      style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600)))),
            const SizedBox(height: 8),
          ])))));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0D1B2A),
      body: SafeArea(child: Column(children: [
        Padding(padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          child: Row(children: [
            GestureDetector(onTap: () => Navigator.pop(context),
              child: Container(width: 40, height: 40,
                decoration: BoxDecoration(color: const Color(0xFF152232),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: const Color(0xFF1E3347))),
                child: const Icon(Icons.arrow_back_ios_new_rounded,
                    color: Color(0xFF8899AA), size: 18))),
            const SizedBox(width: 14),
            Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(widget.courseName, style: const TextStyle(fontFamily: 'Georgia',
                  fontSize: 17, fontWeight: FontWeight.bold, color: Colors.white)),
              Text('${widget.batchName} · Online Classes',
                  style: const TextStyle(fontSize: 11, color: Color(0xFF556677))),
            ])),
            GestureDetector(
              onTap: _showAddClassSheet,
              child: Container(width: 40, height: 40,
                decoration: BoxDecoration(
                  color: const Color(0xFF7F77DD).withOpacity(0.12),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: const Color(0xFF7F77DD).withOpacity(0.3))),
                child: const Icon(Icons.add_rounded,
                    color: Color(0xFF7F77DD), size: 22))),
          ])),

        Expanded(child: _isLoading
            ? const Center(child: CircularProgressIndicator(
                color: Color(0xFF7F77DD), strokeWidth: 2))
            : _classes.isEmpty
                ? Center(child: Column(mainAxisSize: MainAxisSize.min, children: [
                    Container(width: 64, height: 64,
                      decoration: BoxDecoration(
                        color: const Color(0xFF7F77DD).withOpacity(0.08),
                        borderRadius: BorderRadius.circular(18)),
                      child: const Icon(Icons.videocam_outlined,
                          color: Color(0xFF3A5068), size: 32)),
                    const SizedBox(height: 16),
                    const Text('No online classes scheduled',
                        style: TextStyle(fontSize: 16,
                            color: Colors.white, fontFamily: 'Georgia')),
                    const SizedBox(height: 8),
                    const Text('Tap + to schedule a class',
                        style: TextStyle(fontSize: 12, color: Color(0xFF556677))),
                  ]))
                : ListView(
                    padding: const EdgeInsets.fromLTRB(20, 0, 20, 100),
                    children: _classes.map((c) {
                      final platform = c['Platform'] as String? ?? 'Online';
                      final date     = c['ClassDate'] as String? ?? '—';
                      final time     = c['ClassTime'] as String? ?? '';
                      final link     = c['JoinLink'] as String? ?? '';

                      return Container(
                        margin: const EdgeInsets.only(bottom: 12),
                        padding: const EdgeInsets.all(14),
                        decoration: BoxDecoration(
                          color: const Color(0xFF152232),
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(color: const Color(0xFF1E3347))),
                        child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                          Row(children: [
                            Container(width: 40, height: 40,
                              decoration: BoxDecoration(
                                color: const Color(0xFF7F77DD).withOpacity(0.12),
                                borderRadius: BorderRadius.circular(11)),
                              child: const Icon(Icons.videocam_outlined,
                                  color: Color(0xFF7F77DD), size: 20)),
                            const SizedBox(width: 12),
                            Expanded(child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                              Text(platform, style: const TextStyle(
                                  fontSize: 14, fontWeight: FontWeight.w600,
                                  color: Colors.white)),
                              Text('$date ${time.isNotEmpty ? "· $time" : ""}',
                                  style: const TextStyle(
                                      fontSize: 11, color: Color(0xFF556677))),
                            ])),
                          ]),
                          if (link.isNotEmpty) ...[
                            const SizedBox(height: 10),
                            GestureDetector(
                              onTap: () {
                                // TODO: url_launcher to open link
                              },
                              child: Container(
                                width: double.infinity,
                                padding: const EdgeInsets.symmetric(
                                    vertical: 10),
                                decoration: BoxDecoration(
                                  color: const Color(0xFF7F77DD),
                                  borderRadius: BorderRadius.circular(10)),
                                child: const Row(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: [
                                  Icon(Icons.open_in_new_rounded,
                                      color: Colors.white, size: 16),
                                  SizedBox(width: 6),
                                  Text('Join Class',
                                      style: TextStyle(fontSize: 13,
                                          fontWeight: FontWeight.w600,
                                          color: Colors.white)),
                                ]))),
                          ],
                        ]));
                    }).toList())),
      ])));
  }

  Widget _lbl(String t) => Text(t, style: const TextStyle(
      fontSize: 13, fontWeight: FontWeight.w500, color: Color(0xFF8899AA)));

  Widget _tf({required TextEditingController ctrl, required String hint,
      required IconData icon, TextInputType kb = TextInputType.text}) =>
    TextField(controller: ctrl, keyboardType: kb,
      style: const TextStyle(color: Colors.white, fontSize: 14),
      cursorColor: const Color(0xFF7F77DD),
      decoration: InputDecoration(hintText: hint,
        hintStyle: const TextStyle(color: Color(0xFF3A5068)),
        prefixIcon: Icon(icon, color: const Color(0xFF3A5068), size: 18),
        filled: true, fillColor: const Color(0xFF0D1B2A),
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12),
            borderSide: const BorderSide(color: Color(0xFF1E3347))),
        enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12),
            borderSide: const BorderSide(color: Color(0xFF1E3347))),
        focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12),
            borderSide: const BorderSide(color: Color(0xFF7F77DD), width: 1.5))));
}  // end _OnlineClassScreenState