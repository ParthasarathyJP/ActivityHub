import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'events_screen.dart';

// ══════════════════════════════════════════════════════════════════════════════
// Student Dashboard
// ══════════════════════════════════════════════════════════════════════════════
class StudentDashboard extends StatefulWidget {
  final String uid;
  final String clientId;
  final String enrollNo;
  final String studentName;
  final String email;

  const StudentDashboard({
    super.key,
    required this.uid,
    required this.clientId,
    required this.enrollNo,
    required this.studentName,
    required this.email,
  });

  @override
  State<StudentDashboard> createState() => _StudentDashboardState();
}

class _StudentDashboardState extends State<StudentDashboard> {
  int _currentTab = 0;

  // Shared data loaded once
  Map<String, dynamic>       _studentDoc  = {};
  List<Map<String, dynamic>> _myScheds    = []; // StudentCourseSchedule
  List<Map<String, dynamic>> _schedules   = []; // CourseSchedule
  List<Map<String, dynamic>> _courses     = []; // Course
  bool _isLoading = true;

  @override
  void initState() { super.initState(); _loadAll(); }

  Future<void> _loadAll() async {
    setState(() => _isLoading = true);
    try {
      final db = FirebaseFirestore.instance;
      final results = await Future.wait([
        // Student doc
        db.collection('Student')
            .where('StudentEnrollmentNo', isEqualTo: widget.enrollNo)
            .where('ClientID', isEqualTo: widget.clientId)
            .limit(1).get(),
        // My course schedules
        db.collection('StudentCourseSchedule')
            .where('ClientID', isEqualTo: widget.clientId)
            .where('StudentEnrollmentNo', isEqualTo: widget.enrollNo)
            .where('IsActive', isEqualTo: true).get(),
        // All course schedules for this client
        db.collection('CourseSchedule')
            .where('ClientID', isEqualTo: widget.clientId).get(),
        // All courses
        db.collection('Course')
            .where('ClientID', isEqualTo: widget.clientId).get(),
      ]);

      final stuSnap  = results[0] as QuerySnapshot;
      final ssSnap   = results[1] as QuerySnapshot;
      final csSnap   = results[2] as QuerySnapshot;
      final crsSnap  = results[3] as QuerySnapshot;

      if (mounted) setState(() {
        _studentDoc = stuSnap.docs.isNotEmpty
            ? {...(stuSnap.docs.first.data() as Map<String, dynamic>),
                'DocID': stuSnap.docs.first.id}
            : {};
        _myScheds  = ssSnap.docs.map((d) =>
            {...(d.data() as Map<String, dynamic>), 'DocID': d.id}).toList();
        _schedules = csSnap.docs.map((d) =>
            {...(d.data() as Map<String, dynamic>), 'DocID': d.id}).toList();
        _courses   = crsSnap.docs.map((d) =>
            {...(d.data() as Map<String, dynamic>), 'DocID': d.id}).toList();
        _isLoading = false;
      });
    } catch (e) {
      debugPrint('Student dashboard load error: $e');
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Map<String, dynamic> _scheduleById(String? id) =>
      _schedules.firstWhere((s) => s['DocID'] == id, orElse: () => {});

  Map<String, dynamic> _courseById(String? id) =>
      _courses.firstWhere((c) => c['DocID'] == id, orElse: () => {});

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return Scaffold(backgroundColor: const Color(0xFF0D1B2A),
        body: const Center(child: CircularProgressIndicator(
            color: Color(0xFF1DB954), strokeWidth: 2)));
    }

    final name = (_studentDoc['Name'] as String? ??
        (widget.studentName.isNotEmpty ? widget.studentName : widget.enrollNo));

    final tabs = [
      _StudentHomeTab(
        studentDoc:   _studentDoc,
        myScheds:     _myScheds,
        scheduleById: _scheduleById,
        courseById:   _courseById,
        enrollNo:     widget.enrollNo,
        onRefresh:    _loadAll,
      ),
      _StudentScheduleTab(
        myScheds:     _myScheds,
        scheduleById: _scheduleById,
        courseById:   _courseById,
      ),
      StudentEventsTab(
        clientId:         widget.clientId,
        studentEnrollNo:  widget.enrollNo,
        studentName:      name,
      ),
      _StudentMoreTab(
        studentDoc: _studentDoc,
        enrollNo:   widget.enrollNo,
        email:      widget.email,
        uid:        widget.uid,
        onRefresh:  _loadAll,
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
      {'icon': Icons.home_rounded,            'label': 'Home'},
      {'icon': Icons.calendar_today_rounded,  'label': 'Schedule'},
      {'icon': Icons.emoji_events_outlined,   'label': 'Events'},
      {'icon': Icons.more_horiz_rounded,      'label': 'More'},
    ];

    return Container(
      decoration: const BoxDecoration(
        color: Color(0xFF152232),
        border: Border(top: BorderSide(color: Color(0xFF1E3347), width: 1))),
      child: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 8),
          child: Row(children: items.asMap().entries.map((e) {
            final i      = e.key;
            final item   = e.value;
            final active = _currentTab == i;
            // Events tab uses gold accent
            final color  = active
                ? (i == 2 ? const Color(0xFFE8A020) : const Color(0xFF1DB954))
                : const Color(0xFF556677);
            return Expanded(child: GestureDetector(
              onTap: () => setState(() => _currentTab = i),
              behavior: HitTestBehavior.opaque,
              child: Column(mainAxisSize: MainAxisSize.min, children: [
                Icon(item['icon'] as IconData, color: color, size: 22),
                const SizedBox(height: 4),
                Text(item['label'] as String,
                    style: TextStyle(fontSize: 10,
                        fontWeight: active ? FontWeight.w600 : FontWeight.normal,
                        color: color)),
              ])));
          }).toList()))));
  }
}

// ══════════════════════════════════════════════════════════════════════════════
// Student Home Tab
// ══════════════════════════════════════════════════════════════════════════════
class _StudentHomeTab extends StatelessWidget {
  final Map<String, dynamic> studentDoc;
  final List<Map<String, dynamic>> myScheds;
  final Map<String, dynamic> Function(String?) scheduleById;
  final Map<String, dynamic> Function(String?) courseById;
  final String      enrollNo;
  final VoidCallback onRefresh;

  const _StudentHomeTab({
    required this.studentDoc, required this.myScheds,
    required this.scheduleById, required this.courseById,
    required this.enrollNo, required this.onRefresh,
  });

  String _greeting() {
    final h = DateTime.now().hour;
    if (h < 12) return 'Good morning';
    if (h < 17) return 'Good afternoon';
    return 'Good evening';
  }

  @override
  Widget build(BuildContext context) {
    final name = studentDoc['Name'] as String? ?? enrollNo;

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
                color: const Color(0xFF5BA3D9).withOpacity(0.15),
                borderRadius: BorderRadius.circular(14)),
              child: Center(child: Text(
                  name.substring(0, 1).toUpperCase(),
                  style: const TextStyle(fontSize: 20,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFF5BA3D9))))),
            const SizedBox(width: 12),
            Expanded(child: Column(
                crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text('${_greeting()}, ${name.split(' ').first}',
                  style: const TextStyle(fontSize: 18,
                      fontWeight: FontWeight.bold, color: Colors.white,
                      fontFamily: 'Georgia')),
              Text(enrollNo,
                  style: const TextStyle(fontSize: 12,
                      color: Color(0xFF556677))),
            ])),
            GestureDetector(
              onTap: () async => FirebaseAuth.instance.signOut(),
              child: Container(width: 38, height: 38,
                decoration: BoxDecoration(
                    color: const Color(0xFF152232),
                    borderRadius: BorderRadius.circular(11),
                    border: Border.all(color: const Color(0xFF1E3347))),
                child: const Icon(Icons.logout_rounded,
                    color: Color(0xFF556677), size: 18))),
          ]),
          const SizedBox(height: 24),

          // Stats
          Row(children: [
            _statCard('Courses', myScheds.length.toString(),
                Icons.menu_book_rounded, const Color(0xFF1DB954)),
            const SizedBox(width: 12),
            _statCard('Events', '—',
                Icons.emoji_events_outlined, const Color(0xFFE8A020)),
          ]),
          const SizedBox(height: 24),

          // My courses
          const Text('My Courses', style: TextStyle(fontSize: 15,
              fontWeight: FontWeight.w600, color: Colors.white)),
          const SizedBox(height: 12),

          if (myScheds.isEmpty)
            _emptyCard('No courses enrolled yet.')
          else
            ...myScheds.map((ss) {
              final cs     = scheduleById(ss['CourseScheduleID']);
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
                  Expanded(child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Text(course['CourseName'] ?? '—',
                        style: const TextStyle(fontSize: 14,
                            fontWeight: FontWeight.w600, color: Colors.white)),
                    Text('${cs['BatchName'] ?? ''}'
                        '${days.isNotEmpty ? ' · ${days.join(', ')}' : ''}',
                        style: const TextStyle(
                            fontSize: 11, color: Color(0xFF556677))),
                  ])),
                ]));
            }),
        ])));
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
          Text(label, style: const TextStyle(
              fontSize: 11, color: Color(0xFF556677))),
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

// ══════════════════════════════════════════════════════════════════════════════
// Student Schedule Tab
// ══════════════════════════════════════════════════════════════════════════════
class _StudentScheduleTab extends StatelessWidget {
  final List<Map<String, dynamic>> myScheds;
  final Map<String, dynamic> Function(String?) scheduleById;
  final Map<String, dynamic> Function(String?) courseById;

  const _StudentScheduleTab({
    required this.myScheds,
    required this.scheduleById,
    required this.courseById,
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
            Text('Classes & timings', style: TextStyle(
                fontSize: 12, color: Color(0xFF556677))),
          ]),
        ])),
      Expanded(child: myScheds.isEmpty
          ? Center(child: Column(mainAxisSize: MainAxisSize.min, children: [
              Container(width: 64, height: 64,
                decoration: BoxDecoration(
                    color: const Color(0xFF1DB954).withOpacity(0.08),
                    borderRadius: BorderRadius.circular(18)),
                child: const Icon(Icons.calendar_today_rounded,
                    color: Color(0xFF3A5068), size: 32)),
              const SizedBox(height: 12),
              const Text('No classes yet', style: TextStyle(
                  fontSize: 16, color: Colors.white, fontFamily: 'Georgia')),
            ]))
          : ListView(
              padding: const EdgeInsets.fromLTRB(20, 0, 20, 100),
              children: myScheds.map((ss) {
                final cs     = scheduleById(ss['CourseScheduleID']);
                final course = courseById(cs['CourseID']);
                final days   = (cs['DaysOfWeek'] as List?)?.cast<String>() ?? [];
                final timing = cs['TimingDisplay'] as String? ?? '';
                return Container(
                  margin: const EdgeInsets.only(bottom: 12),
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: const Color(0xFF152232),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: const Color(0xFF1E3347))),
                  child: Row(children: [
                    Container(width: 44, height: 44,
                      decoration: BoxDecoration(
                        color: const Color(0xFF5BA3D9).withOpacity(0.12),
                        borderRadius: BorderRadius.circular(13)),
                      child: const Icon(Icons.menu_book_rounded,
                          color: Color(0xFF5BA3D9), size: 22)),
                    const SizedBox(width: 12),
                    Expanded(child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start, children: [
                      Text(course['CourseName'] ?? '—',
                          style: const TextStyle(fontSize: 14,
                              fontWeight: FontWeight.w600, color: Colors.white)),
                      Text(cs['BatchName'] ?? '—',
                          style: const TextStyle(
                              fontSize: 11, color: Color(0xFF8899AA))),
                      if (days.isNotEmpty)
                        Text(days.join(' · '),
                            style: const TextStyle(
                                fontSize: 11, color: Color(0xFF556677))),
                      if (timing.isNotEmpty)
                        Text(timing, style: const TextStyle(
                            fontSize: 11, color: Color(0xFF556677))),
                    ])),
                  ]));
              }).toList())),
    ]));
  }
}

// ══════════════════════════════════════════════════════════════════════════════
// Student More Tab
// ══════════════════════════════════════════════════════════════════════════════
class _StudentMoreTab extends StatelessWidget {
  final Map<String, dynamic> studentDoc;
  final String enrollNo;
  final String email;
  final String uid;
  final VoidCallback onRefresh;

  const _StudentMoreTab({
    required this.studentDoc, required this.enrollNo,
    required this.email, required this.uid,
    required this.onRefresh,
  });

  @override
  Widget build(BuildContext context) {
    final name    = studentDoc['Name'] as String? ?? enrollNo;
    final contact = studentDoc['Contact'] as Map<String, dynamic>? ?? {};
    final phone   = contact['phone'] as String? ?? '';

    return SafeArea(child: ListView(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 100),
      children: [
        const Text('More', style: TextStyle(fontFamily: 'Georgia',
            fontSize: 22, fontWeight: FontWeight.bold, color: Colors.white)),
        const SizedBox(height: 4),
        const Text('Profile & Settings',
            style: TextStyle(fontSize: 12, color: Color(0xFF556677))),
        const SizedBox(height: 24),

        // Profile card
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: const Color(0xFF152232),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: const Color(0xFF1E3347))),
          child: Row(children: [
            Container(width: 52, height: 52,
              decoration: BoxDecoration(
                color: const Color(0xFF5BA3D9).withOpacity(0.15),
                borderRadius: BorderRadius.circular(14)),
              child: Center(child: Text(
                  name.substring(0, 1).toUpperCase(),
                  style: const TextStyle(fontSize: 22,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFF5BA3D9))))),
            const SizedBox(width: 14),
            Expanded(child: Column(
                crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(name, style: const TextStyle(fontSize: 15,
                  fontWeight: FontWeight.w600, color: Colors.white)),
              Text(enrollNo, style: const TextStyle(
                  fontSize: 11, color: Color(0xFF556677))),
              if (phone.isNotEmpty)
                Text(phone, style: const TextStyle(
                    fontSize: 11, color: Color(0xFF556677))),
            ])),
          ])),
        const SizedBox(height: 10),

        // Contact info row
        _infoRow(Icons.email_outlined, email),
        if (phone.isNotEmpty) _infoRow(Icons.phone_outlined, phone),
        const SizedBox(height: 24),

        // Sign out
        GestureDetector(
          onTap: () async => FirebaseAuth.instance.signOut(),
          child: Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: const Color(0xFFE74C3C).withOpacity(0.08),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(
                  color: const Color(0xFFE74C3C).withOpacity(0.3))),
            child: const Row(
                mainAxisAlignment: MainAxisAlignment.center, children: [
              Icon(Icons.logout_rounded, color: Color(0xFFE74C3C), size: 18),
              SizedBox(width: 8),
              Text('Sign Out', style: TextStyle(fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: Color(0xFFE74C3C))),
            ]))),
      ]));
  }

  Widget _infoRow(IconData icon, String value) => Container(
    margin: const EdgeInsets.only(bottom: 8),
    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
    decoration: BoxDecoration(
      color: const Color(0xFF152232),
      borderRadius: BorderRadius.circular(12),
      border: Border.all(color: const Color(0xFF1E3347))),
    child: Row(children: [
      Icon(icon, color: const Color(0xFF3A5068), size: 16),
      const SizedBox(width: 10),
      Text(value, style: const TextStyle(fontSize: 13,
          color: Color(0xFF8899AA))),
    ]));
}