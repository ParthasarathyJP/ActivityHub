import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'payroll_screen.dart';
import 'revenue_screen.dart';

class FinanceTab extends StatefulWidget {
  final String clientId;
  final String branchId;
  final String userType;

  const FinanceTab({
    super.key,
    required this.clientId,
    required this.branchId,
    this.userType = 'Client',
  });

  @override
  State<FinanceTab> createState() => _FinanceTabState();
}

class _FinanceTabState extends State<FinanceTab> {
  int _slideIndex = 0;
  final List<String> _slides = ['Fees', 'Payroll', 'Revenue'];

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Column(children: [
        // Header
        const Padding(
          padding: EdgeInsets.fromLTRB(20, 16, 20, 0),
          child: Row(children: [
            Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text('Finance', style: TextStyle(fontFamily: 'Georgia', fontSize: 22,
                  fontWeight: FontWeight.bold, color: Colors.white)),
              Text('Fees · Payroll · Revenue',
                  style: TextStyle(fontSize: 12, color: Color(0xFF556677))),
            ]),
          ]),
        ),
        const SizedBox(height: 14),

        // Slide chips
        ClipRect(
          child: SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.fromLTRB(20, 0, 20, 8),
            physics: const BouncingScrollPhysics(),
            child: Row(children: [
              ..._slides.asMap().entries.map((e) {
                final isActive = _slideIndex == e.key;
                return GestureDetector(
                  onTap: () => setState(() => _slideIndex = e.key),
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 200),
                    margin: const EdgeInsets.only(right: 8),
                    padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
                    decoration: BoxDecoration(
                      color: isActive ? const Color(0xFF1DB954) : const Color(0xFF152232),
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(
                          color: isActive ? const Color(0xFF1DB954) : const Color(0xFF1E3347))),
                    child: Text(e.value, style: TextStyle(fontSize: 13,
                        fontWeight: FontWeight.w500,
                        color: isActive ? Colors.white : const Color(0xFF8899AA)))),
                );
              }),
              const SizedBox(width: 8),
            ]),
          ),
        ),

        Expanded(child: _buildSlide()),
      ]),
    );
  }

  Widget _buildSlide() {
    switch (_slideIndex) {
      case 0: return FeesSection(
          clientId: widget.clientId,
          branchId: widget.branchId,
          userType: widget.userType);
      case 1: return _PayrollEntry(
          clientId: widget.clientId,
          branchId: widget.branchId);
      case 2: return _RevenueEntry(
          clientId: widget.clientId,
          branchId: widget.branchId,
          clientName: '');
      default: return const SizedBox.shrink();
    }
  }

  Widget _comingSoon(String label, IconData icon, String sub) => Center(
    child: Column(mainAxisSize: MainAxisSize.min, children: [
      Container(width: 64, height: 64,
        decoration: BoxDecoration(color: const Color(0xFF1DB954).withOpacity(0.08),
            borderRadius: BorderRadius.circular(18)),
        child: Icon(icon, color: const Color(0xFF3A5068), size: 32)),
      const SizedBox(height: 16),
      Text(label, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w600,
          color: Colors.white, fontFamily: 'Georgia')),
      const SizedBox(height: 6),
      Text(sub, style: const TextStyle(fontSize: 13, color: Color(0xFF556677))),
      const SizedBox(height: 4),
      const Text('Coming soon...', style: TextStyle(fontSize: 12, color: Color(0xFF3A5068))),
    ]),
  );
}

// ══════════════════════════════════════════════════════════════════════════════
// Fees Section
// ══════════════════════════════════════════════════════════════════════════════
class FeesSection extends StatefulWidget {
  final String clientId;
  final String branchId;
  final String userType;

  const FeesSection({
    super.key,
    required this.clientId,
    required this.branchId,
    required this.userType,
  });

  @override
  State<FeesSection> createState() => _FeesSectionState();
}

class _FeesSectionState extends State<FeesSection> {
  List<Map<String, dynamic>> _fees            = [];
  List<Map<String, dynamic>> _students        = [];
  List<Map<String, dynamic>> _courses         = [];
  List<Map<String, dynamic>> _courseSchedules = []; // CourseSchedule collection
  List<Map<String, dynamic>> _schedules       = []; // StudentCourseSchedule collection
  List<Map<String, dynamic>> _subTypes        = [];
  bool _isLoading = true;

  @override
  void initState() { super.initState(); _load(); }

  Future<void> _load() async {
    setState(() => _isLoading = true);
    try {
      final db = FirebaseFirestore.instance;

      QuerySnapshot? feeSnap;
      try {
        feeSnap = await db.collection('StudentFee')
            .where('ClientID', isEqualTo: widget.clientId)
            .orderBy('CreatedAt', descending: true).get();
      } catch (_) {
        feeSnap = await db.collection('StudentFee')
            .where('ClientID', isEqualTo: widget.clientId).get();
      }

      final results = await Future.wait([
        db.collection('Student').where('ClientID', isEqualTo: widget.clientId).get(),
        db.collection('Course').where('ClientID', isEqualTo: widget.clientId).get(),
        db.collection('CourseSchedule').where('ClientID', isEqualTo: widget.clientId).get(),
        db.collection('StudentCourseSchedule')
            .where('ClientID', isEqualTo: widget.clientId).get(),
        db.collection('SubType')
            .where('ClientID', isEqualTo: widget.clientId)
            .where('SubTypeCode', isEqualTo: 'PaymentCycle')
            .where('IsActive', isEqualTo: true).get(),
      ]);

      if (mounted) setState(() {
        _fees            = feeSnap!.docs.map((d) => {...(d.data() as Map<String,dynamic>), 'DocID': d.id}).toList();
        _students        = (results[0] as QuerySnapshot).docs.map((d) => {...(d.data() as Map<String,dynamic>), 'DocID': d.id}).toList();
        _courses         = (results[1] as QuerySnapshot).docs.map((d) => {...(d.data() as Map<String,dynamic>), 'DocID': d.id}).toList();
        _courseSchedules = (results[2] as QuerySnapshot).docs.map((d) => {...(d.data() as Map<String,dynamic>), 'DocID': d.id}).toList();
        _schedules       = (results[3] as QuerySnapshot).docs.map((d) => {...(d.data() as Map<String,dynamic>), 'DocID': d.id}).toList();
        _subTypes        = (results[4] as QuerySnapshot).docs.map((d) => {...(d.data() as Map<String,dynamic>), 'DocID': d.id}).toList();
        _isLoading = false;
      });
    } catch (e) {
      debugPrint('Fees load error: $e');
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Map<String, dynamic> _studentByEnrollNo(String? no) =>
      _students.firstWhere((s) => s['StudentEnrollmentNo'] == no, orElse: () => {});

  Map<String, dynamic> _courseById(String? id) =>
      _courses.firstWhere((c) => c['DocID'] == id, orElse: () => {});

  /// Lookup: CourseSchedule doc by its ID
  Map<String, dynamic> _courseScheduleById(String? id) =>
      _courseSchedules.firstWhere((cs) => cs['DocID'] == id, orElse: () => {});

  /// Two-hop: StudentCourseSchedule → CourseSchedule → Course
  Map<String, dynamic> _courseFromStudentSchedule(Map<String, dynamic> studentSched) {
    final csId     = studentSched['CourseScheduleID'] as String? ?? '';
    final courseSched = _courseScheduleById(csId);
    final courseId = courseSched['CourseID'] as String? ?? '';
    return _courseById(courseId);
  }

  Map<String, dynamic> _scheduleById(String? id) =>
      _schedules.firstWhere((s) => s['DocID'] == id, orElse: () => {});

  Map<String, dynamic> _subTypeById(String? id) =>
      _subTypes.firstWhere((s) => s['DocID'] == id, orElse: () => {});

  String _cycleName(String? id) => _subTypeById(id)['SubTypeName'] ?? '—';

  int _multiplierFromName(String name) {
    final n = name.toLowerCase();
    if (n.contains('annual') || n.contains('12')) return 12;
    if (n.contains('6'))  return 6;
    if (n.contains('3'))  return 3;
    return 1;
  }

  Future<String> _generateReceiptNo() async {
    final year = DateTime.now().year;
    final db   = FirebaseFirestore.instance;
    final snap = await db.collection('StudentFee')
        .where('ClientID', isEqualTo: widget.clientId).count().get();
    int count = (snap.count ?? 0) + 1;
    while (true) {
      final candidate = 'RCP-$year-${count.toString().padLeft(3, '0')}';
      final existing  = await db.collection('StudentFee')
          .where('ClientID', isEqualTo: widget.clientId)
          .where('ReceiptNumber', isEqualTo: candidate).limit(1).get();
      if (existing.docs.isEmpty) return candidate;
      count++;
    }
  }

  Map<String, double> _calcConvenience(double totalAmount) {
    final service = totalAmount * 0.02;
    final gst     = service * 0.18;
    return {'service': service, 'gst': gst, 'total': service + gst};
  }

  @override
  Widget build(BuildContext context) {
    return Column(children: [
      Padding(
        padding: const EdgeInsets.fromLTRB(20, 0, 20, 8),
        child: Row(children: [
          Expanded(child: Text(
            '${_fees.length} ${_fees.length == 1 ? "Receipt" : "Receipts"}',
            style: const TextStyle(fontSize: 13, color: Color(0xFF8899AA), fontWeight: FontWeight.w500))),
          GestureDetector(
            onTap: _showAddFeeSheet,
            child: Container(
              height: 36,
              padding: const EdgeInsets.symmetric(horizontal: 14),
              decoration: BoxDecoration(
                color: const Color(0xFF1DB954).withOpacity(0.12),
                borderRadius: BorderRadius.circular(11),
                border: Border.all(color: const Color(0xFF1DB954).withOpacity(0.3))),
              child: const Row(mainAxisSize: MainAxisSize.min, children: [
                Icon(Icons.add_rounded, color: Color(0xFF1DB954), size: 18),
                SizedBox(width: 6),
                Text('Collect Fee', style: TextStyle(fontSize: 13,
                    color: Color(0xFF1DB954), fontWeight: FontWeight.w500)),
              ]))),
        ]),
      ),
      Expanded(
        child: _isLoading
            ? const Center(child: CircularProgressIndicator(
                color: Color(0xFF1DB954), strokeWidth: 2))
            : RefreshIndicator(
                onRefresh: _load,
                color: const Color(0xFF1DB954),
                backgroundColor: const Color(0xFF152232),
                child: _fees.isEmpty
                    ? _emptyState()
                    : ListView(
                        padding: const EdgeInsets.fromLTRB(20, 0, 20, 100),
                        children: _fees.map((f) => _feeCard(f)).toList()))),
    ]);
  }

  Widget _feeCard(Map<String, dynamic> f) {
    final student    = _studentByEnrollNo(f['StudentEnrollmentNo']);
    final schedule   = _scheduleById(f['StudentCourseScheduleID']);
    final course     = _courseFromStudentSchedule(schedule);
    final name       = student['Name'] ?? f['StudentEnrollmentNo'] ?? '—';
    final courseName = course['CourseName'] ?? '—';
    final grandTotal = (f['GrandTotal'] as num?)?.toDouble() ?? 0.0;
    final mode       = f['PaymentMode'] as String? ?? 'Cash';
    final receipt    = f['ReceiptNumber'] ?? '—';
    final ts         = f['DateOfPayment'] as Timestamp?;
    final date       = ts != null ? _formatDate(ts.toDate()) : '—';
    final cycle      = _cycleName(f['PaymentCycleSubTypeID']);
    final isGateway  = mode == 'Payment Gateway';

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: const Color(0xFF152232),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: const Color(0xFF1E3347))),
      child: Column(children: [
        Padding(padding: const EdgeInsets.all(16), child: Row(children: [
          Container(width: 46, height: 46,
            decoration: BoxDecoration(
              color: const Color(0xFF1DB954).withOpacity(0.12),
              borderRadius: BorderRadius.circular(13)),
            child: const Icon(Icons.receipt_long_outlined,
                color: Color(0xFF1DB954), size: 22)),
          const SizedBox(width: 12),
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(name, style: const TextStyle(fontSize: 15,
                fontWeight: FontWeight.w600, color: Colors.white)),
            Text(courseName, style: const TextStyle(
                fontSize: 12, color: Color(0xFF8899AA))),
          ])),
          Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
            Text('₹${grandTotal.toStringAsFixed(2)}',
                style: const TextStyle(fontSize: 16,
                    fontWeight: FontWeight.bold, color: Color(0xFF1DB954))),
            Text(cycle, style: const TextStyle(
                fontSize: 10, color: Color(0xFF556677))),
          ]),
        ])),
        Container(
          padding: const EdgeInsets.fromLTRB(16, 10, 16, 10),
          decoration: const BoxDecoration(
              border: Border(top: BorderSide(color: Color(0xFF1E3347), width: 1))),
          child: Row(children: [
            const Icon(Icons.confirmation_number_outlined,
                color: Color(0xFF556677), size: 13),
            const SizedBox(width: 4),
            Text(receipt, style: const TextStyle(
                fontSize: 11, color: Color(0xFF8899AA))),
            const SizedBox(width: 10),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
              decoration: BoxDecoration(
                color: isGateway
                    ? const Color(0xFF7F77DD).withOpacity(0.12)
                    : const Color(0xFF1DB954).withOpacity(0.1),
                borderRadius: BorderRadius.circular(5)),
              child: Text(mode, style: TextStyle(fontSize: 10,
                  color: isGateway
                      ? const Color(0xFF7F77DD)
                      : const Color(0xFF1DB954)))),
            const Spacer(),
            const Icon(Icons.calendar_today_outlined,
                color: Color(0xFF556677), size: 12),
            const SizedBox(width: 4),
            Text(date, style: const TextStyle(
                fontSize: 11, color: Color(0xFF556677))),
          ])),
      ]));
  }

  Widget _emptyState() => ListView(padding: const EdgeInsets.all(32), children: [
    const SizedBox(height: 40),
    Center(child: Column(children: [
      Container(width: 72, height: 72,
        decoration: BoxDecoration(color: const Color(0xFF1DB954).withOpacity(0.08),
            borderRadius: BorderRadius.circular(20)),
        child: const Icon(Icons.receipt_long_outlined,
            color: Color(0xFF3A5068), size: 36)),
      const SizedBox(height: 20),
      const Text('No fees collected yet',
          style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600,
              color: Colors.white, fontFamily: 'Georgia')),
      const SizedBox(height: 8),
      const Text('Tap "Collect Fee" to record\na student fee payment.',
          textAlign: TextAlign.center,
          style: TextStyle(fontSize: 13, color: Color(0xFF556677), height: 1.5)),
    ])),
  ]);

  String _formatDate(DateTime dt) {
    const months = ['Jan','Feb','Mar','Apr','May','Jun',
        'Jul','Aug','Sep','Oct','Nov','Dec'];
    return '${dt.day} ${months[dt.month - 1]} ${dt.year}';
  }

  // ══════════════════════════════════════════════════════════════════════════
  // Add Fee Sheet — 3 step flow
  // ══════════════════════════════════════════════════════════════════════════
  void _showAddFeeSheet() {
    int step = 0;
    final searchCtrl = TextEditingController();
    Map<String, dynamic>? selectedStudent;
    List<Map<String, dynamic>> searchResults    = [];
    List<Map<String, dynamic>> selectedSchedules = [];
    List<Map<String, dynamic>> studentSchedules  = [];
    Map<String, dynamic>? selectedPayCycle;
    final paymentMode = widget.userType == 'Student'
        ? 'Payment Gateway' : 'Cash';
    double baseAmount     = 0;
    double totalAmount    = 0;
    double convenienceFee = 0;
    double grandTotal     = 0;
    int    multiplier     = 1;
    bool saving = false;

    void calcAmounts(StateSetter ss) {
      if (selectedSchedules.isEmpty || selectedPayCycle == null) return;
      // Sum CourseFee for every selected schedule
      baseAmount = selectedSchedules.fold<double>(0.0, (sum, s) {
        final course = _courseFromStudentSchedule(s);
        return sum + ((course['CourseFee'] as num?)?.toDouble() ?? 0.0);
      });
      multiplier   = _multiplierFromName(
          selectedPayCycle!['SubTypeName'] as String? ?? '');
      totalAmount  = baseAmount * multiplier;
      if (paymentMode == 'Payment Gateway') {
        convenienceFee = _calcConvenience(totalAmount)['total']!;
      } else {
        convenienceFee = 0;
      }
      grandTotal = totalAmount + convenienceFee;
      ss(() {});
    }

    void searchStudents(StateSetter ss, String query) {
      if (query.trim().isEmpty) { ss(() => searchResults = []); return; }
      final q = query.toLowerCase();
      ss(() => searchResults = _students.where((s) {
        final name = (s['Name'] ?? '').toLowerCase();
        final enNo = (s['StudentEnrollmentNo'] ?? '').toLowerCase();
        return name.contains(q) || enNo.contains(q);
      }).take(5).toList());
    }

    void loadSchedules(StateSetter ss, Map<String, dynamic> student) {
      final enNo   = student['StudentEnrollmentNo'] as String? ?? '';
      final active = _schedules.where((s) =>
          s['StudentEnrollmentNo'] == enNo && s['IsActive'] == true).toList();
      ss(() {
        selectedStudent   = student;
        studentSchedules  = active;
        selectedSchedules = [];
        searchResults     = [];
        step              = 1;
      });
    }

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
          child: SingleChildScrollView(child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Handle
              Center(child: Container(width: 40, height: 4,
                decoration: BoxDecoration(color: const Color(0xFF1E3347),
                    borderRadius: BorderRadius.circular(2)))),
              const SizedBox(height: 20),

              // Header
              Row(children: [
                Container(width: 36, height: 36,
                  decoration: BoxDecoration(
                    color: const Color(0xFF1DB954).withOpacity(0.12),
                    borderRadius: BorderRadius.circular(10)),
                  child: const Icon(Icons.receipt_long_outlined,
                      color: Color(0xFF1DB954), size: 18)),
                const SizedBox(width: 12),
                const Text('Collect Fee', style: TextStyle(
                    fontFamily: 'Georgia', fontSize: 18,
                    fontWeight: FontWeight.bold, color: Colors.white)),
              ]),
              const SizedBox(height: 16),

              // Step indicator
              Row(children: List.generate(3, (i) {
                final done   = i < step;
                final active = i == step;
                return Expanded(child: Row(children: [
                  if (i > 0) Expanded(child: Container(height: 2,
                      color: done ? const Color(0xFF1DB954) : const Color(0xFF1E3347))),
                  Container(width: 24, height: 24,
                    decoration: BoxDecoration(shape: BoxShape.circle,
                      color: done ? const Color(0xFF1DB954)
                          : active ? const Color(0xFF1DB954).withOpacity(0.2)
                          : const Color(0xFF0D1B2A),
                      border: Border.all(
                          color: (done || active)
                              ? const Color(0xFF1DB954)
                              : const Color(0xFF1E3347))),
                    child: Center(child: done
                        ? const Icon(Icons.check_rounded, color: Colors.white, size: 12)
                        : Text('${i+1}', style: TextStyle(fontSize: 10,
                            fontWeight: FontWeight.bold,
                            color: active ? const Color(0xFF1DB954) : const Color(0xFF556677))))),
                  if (i < 2) Expanded(child: Container(height: 2,
                      color: i < step ? const Color(0xFF1DB954) : const Color(0xFF1E3347))),
                ]));
              })),
              const SizedBox(height: 4),
              Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
                Text('Student', style: TextStyle(fontSize: 9,
                    color: step >= 0 ? const Color(0xFF1DB954) : const Color(0xFF556677))),
                Text('Course', style: TextStyle(fontSize: 9,
                    color: step >= 1 ? const Color(0xFF1DB954) : const Color(0xFF556677))),
                Text('Payment', style: TextStyle(fontSize: 9,
                    color: step >= 2 ? const Color(0xFF1DB954) : const Color(0xFF556677))),
              ]),
              const SizedBox(height: 20),

              // ── Step 0: Search Student ──────────────────────────────────
              if (step == 0) ...[
                _lbl('Search Student *'),
                const SizedBox(height: 8),
                TextField(
                  controller: searchCtrl,
                  onChanged: (v) => searchStudents(ss, v),
                  style: const TextStyle(color: Colors.white, fontSize: 15),
                  cursorColor: const Color(0xFF1DB954),
                  decoration: InputDecoration(
                    hintText: 'Name or enrollment number',
                    hintStyle: const TextStyle(color: Color(0xFF3A5068), fontSize: 14),
                    prefixIcon: const Icon(Icons.search_rounded,
                        color: Color(0xFF3A5068), size: 20),
                    filled: true, fillColor: const Color(0xFF0D1B2A),
                    contentPadding: const EdgeInsets.symmetric(
                        horizontal: 16, vertical: 14),
                    border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: const BorderSide(color: Color(0xFF1E3347))),
                    enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: const BorderSide(color: Color(0xFF1E3347))),
                    focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: const BorderSide(
                            color: Color(0xFF1DB954), width: 1.5)))),
                const SizedBox(height: 8),
                ...searchResults.map((s) => GestureDetector(
                  onTap: () => loadSchedules(ss, s),
                  child: Container(
                    margin: const EdgeInsets.only(bottom: 8),
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                        color: const Color(0xFF0D1B2A),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: const Color(0xFF1E3347))),
                    child: Row(children: [
                      Container(width: 36, height: 36,
                        decoration: BoxDecoration(
                          color: const Color(0xFF5BA3D9).withOpacity(0.15),
                          borderRadius: BorderRadius.circular(10)),
                        child: Center(child: Text(
                            (s['Name'] ?? 'S').substring(0, 1).toUpperCase(),
                            style: const TextStyle(fontSize: 16,
                                fontWeight: FontWeight.bold,
                                color: Color(0xFF5BA3D9))))),
                      const SizedBox(width: 10),
                      Expanded(child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(s['Name'] ?? '', style: const TextStyle(
                                fontSize: 13, fontWeight: FontWeight.w500,
                                color: Colors.white)),
                            Text(s['StudentEnrollmentNo'] ?? '',
                                style: const TextStyle(fontSize: 11,
                                    color: Color(0xFF556677))),
                          ])),
                      const Icon(Icons.chevron_right_rounded,
                          color: Color(0xFF3A5068), size: 18),
                    ])))),
                if (searchResults.isEmpty && searchCtrl.text.isNotEmpty)
                  Container(
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                        color: const Color(0xFF0D1B2A),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: const Color(0xFF1E3347))),
                    child: const Center(child: Text('No students found',
                        style: TextStyle(color: Color(0xFF556677),
                            fontSize: 13)))),
              ],

              // ── Step 1: Select Course ───────────────────────────────────
              if (step == 1) ...[
                if (selectedStudent != null) Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: const Color(0xFF1DB954).withOpacity(0.08),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                        color: const Color(0xFF1DB954).withOpacity(0.3))),
                  child: Row(children: [
                    const Icon(Icons.check_circle_rounded,
                        color: Color(0xFF1DB954), size: 16),
                    const SizedBox(width: 8),
                    Text(
                      '${selectedStudent!['Name']} · '
                      '${selectedStudent!['StudentEnrollmentNo']}',
                      style: const TextStyle(fontSize: 13,
                          color: Color(0xFF1DB954),
                          fontWeight: FontWeight.w500)),
                  ])),
                const SizedBox(height: 14),
                _lbl('Select Enrolled Course *'),
                const SizedBox(height: 8),
                if (studentSchedules.isEmpty)
                  Container(
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: const Color(0xFFE74C3C).withOpacity(0.08),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                          color: const Color(0xFFE74C3C).withOpacity(0.3))),
                    child: const Text(
                      'No active course enrollments for this student.',
                      style: TextStyle(fontSize: 12,
                          color: Color(0xFFE74C3C), height: 1.4)))
                else
                  ...studentSchedules.map((s) {
                    final course     = _courseFromStudentSchedule(s);
                    final name       = course['CourseName'] ?? '—';
                    final fee        = (course['CourseFee'] as num?)?.toDouble() ?? 0;
                    final isSelected = selectedSchedules.any((sel) => sel['DocID'] == s['DocID']);
                    return GestureDetector(
                      onTap: () {
                        ss(() {
                          if (isSelected) {
                            selectedSchedules.removeWhere((sel) => sel['DocID'] == s['DocID']);
                          } else {
                            selectedSchedules.add(s);
                          }
                        });
                        calcAmounts(ss);
                      },
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 200),
                        margin: const EdgeInsets.only(bottom: 8),
                        padding: const EdgeInsets.all(14),
                        decoration: BoxDecoration(
                          color: isSelected
                              ? const Color(0xFF1DB954).withOpacity(0.08)
                              : const Color(0xFF0D1B2A),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                              color: isSelected
                                  ? const Color(0xFF1DB954)
                                  : const Color(0xFF1E3347),
                              width: isSelected ? 1.5 : 1)),
                        child: Row(children: [
                          Icon(
                            isSelected
                                ? Icons.check_circle_rounded
                                : Icons.menu_book_outlined,
                            color: const Color(0xFF1DB954), size: 18),
                          const SizedBox(width: 12),
                          Expanded(child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(name, style: const TextStyle(
                                    fontSize: 13, fontWeight: FontWeight.w600,
                                    color: Colors.white)),
                                Text('₹${fee.toStringAsFixed(0)} / month',
                                    style: const TextStyle(fontSize: 11,
                                        color: Color(0xFF556677))),
                              ])),
                        ])));
                  }),

                if (selectedSchedules.isNotEmpty) ...[
                  const SizedBox(height: 14),
                  _lbl('Payment Cycle *'),
                  const SizedBox(height: 8),
                  Builder(builder: (_) {
                    final cycleId =
                        selectedStudent?['PaymentCycleSubTypeID'] as String?;
                    if (selectedPayCycle == null && cycleId != null) {
                      final match = _subTypes.firstWhere(
                          (s) => s['DocID'] == cycleId, orElse: () => {});
                      if (match.isNotEmpty) {
                        WidgetsBinding.instance.addPostFrameCallback((_) {
                          ss(() => selectedPayCycle = match);
                          calcAmounts(ss);
                        });
                      }
                    }
                    return Container(
                      decoration: BoxDecoration(
                        color: const Color(0xFF0D1B2A),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                            color: selectedPayCycle != null
                                ? const Color(0xFF1DB954)
                                : const Color(0xFF1E3347),
                            width: selectedPayCycle != null ? 1.5 : 1)),
                      child: DropdownButtonHideUnderline(
                          child: DropdownButton<String>(
                        value: selectedPayCycle?['DocID'] as String?,
                        isExpanded: true,
                        dropdownColor: const Color(0xFF152232),
                        padding:
                            const EdgeInsets.symmetric(horizontal: 12),
                        hint: const Text('Select payment cycle',
                            style: TextStyle(
                                color: Color(0xFF3A5068), fontSize: 14)),
                        icon: const Icon(
                            Icons.keyboard_arrow_down_rounded,
                            color: Color(0xFF556677)),
                        items: _subTypes
                            .map((s) => DropdownMenuItem<String>(
                                  value: s['DocID'] as String,
                                  child: Text(s['SubTypeName'] ?? '',
                                      style: const TextStyle(
                                          color: Colors.white,
                                          fontSize: 14)),
                                ))
                            .toList(),
                        onChanged: (v) {
                          ss(() => selectedPayCycle = _subTypes
                              .firstWhere((s) => s['DocID'] == v,
                                  orElse: () => {}));
                          calcAmounts(ss);
                        },
                      )));
                  }),
                ],
                const SizedBox(height: 20),
                Row(children: [
                  Expanded(child: OutlinedButton(
                    onPressed: () => ss(() => step = 0),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: const Color(0xFF8899AA),
                      side: const BorderSide(color: Color(0xFF1E3347)),
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14)),
                      padding: const EdgeInsets.symmetric(vertical: 14)),
                    child: const Text('Back'))),
                  const SizedBox(width: 12),
                  Expanded(flex: 2, child: ElevatedButton(
                    onPressed: (selectedSchedules.isEmpty ||
                            selectedPayCycle == null)
                        ? null
                        : () => ss(() => step = 2),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF1DB954),
                      foregroundColor: Colors.white,
                      disabledBackgroundColor:
                          const Color(0xFF1DB954).withOpacity(0.3),
                      elevation: 0,
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14)),
                      padding: const EdgeInsets.symmetric(vertical: 14)),
                    child: const Text('Continue',
                        style: TextStyle(
                            fontSize: 15, fontWeight: FontWeight.w600)))),
                ]),
              ],

              // ── Step 2: Payment Summary ─────────────────────────────────
              if (step == 2) ...[
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                      color: const Color(0xFF0D1B2A),
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: const Color(0xFF1E3347))),
                  child: Column(children: [
                    _feeRow(
                      selectedSchedules.length == 1 ? 'Course' : 'Courses',
                      selectedSchedules.length == 1
                          ? (_courseFromStudentSchedule(selectedSchedules.first)['CourseName'] ?? '—')
                          : '${selectedSchedules.length} courses',
                      isTitle: true),
                    if (selectedSchedules.length > 1) ...[
                      const SizedBox(height: 6),
                      ...selectedSchedules.map((s) {
                        final c    = _courseFromStudentSchedule(s);
                        final cFee = (c['CourseFee'] as num?)?.toDouble() ?? 0;
                        return _feeRow(c['CourseName'] ?? '—',
                            '₹${cFee.toStringAsFixed(2)}');
                      }),
                    ],
                    const SizedBox(height: 8),
                    _feeRow('Fee per month',
                        '₹${baseAmount.toStringAsFixed(2)}'),
                    _feeRow('Payment cycle',
                        '${selectedPayCycle?['SubTypeName'] ?? ''} (×$multiplier)'),
                    const Divider(color: Color(0xFF1E3347), height: 20),
                    _feeRow('Total Amount',
                        '₹${totalAmount.toStringAsFixed(2)}', highlight: true),
                    const SizedBox(height: 14),

                    // Payment mode
                    _lbl('Payment Mode'),
                    const SizedBox(height: 8),
                    if (widget.userType == 'Student')
                      _modeCard('Payment Gateway', Icons.payment_rounded,
                          const Color(0xFF7F77DD), 'Razorpay')
                    else
                      _modeCard('Cash', Icons.payments_outlined,
                          const Color(0xFF1DB954), 'In-person'),

                    // Convenience fee
                    if (paymentMode == 'Payment Gateway') ...[
                      const Divider(color: Color(0xFF1E3347), height: 20),
                      _feeRow('Service charge (2%)',
                          '₹${(totalAmount * 0.02).toStringAsFixed(2)}'),
                      _feeRow('GST on service (18%)',
                          '₹${(totalAmount * 0.02 * 0.18).toStringAsFixed(2)}'),
                      _feeRow('Convenience fee',
                          '₹${convenienceFee.toStringAsFixed(2)}',
                          isConvenience: true),
                    ],
                    const Divider(color: Color(0xFF1E3347), height: 20),
                    _feeRow('Grand Total',
                        '₹${grandTotal.toStringAsFixed(2)}',
                        isGrandTotal: true),
                  ])),

                if (paymentMode == 'Payment Gateway') ...[
                  const SizedBox(height: 12),
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: const Color(0xFFE8A020).withOpacity(0.08),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                          color: const Color(0xFFE8A020).withOpacity(0.3))),
                    child: const Row(children: [
                      Icon(Icons.info_outline_rounded,
                          color: Color(0xFFE8A020), size: 16),
                      SizedBox(width: 8),
                      Expanded(child: Text(
                        'Razorpay integration coming soon. '
                        'Fee will be recorded as pending.',
                        style: TextStyle(fontSize: 11,
                            color: Color(0xFFE8A020), height: 1.4))),
                    ])),
                ],

                const SizedBox(height: 20),
                Row(children: [
                  Expanded(child: OutlinedButton(
                    onPressed: () => ss(() => step = 1),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: const Color(0xFF8899AA),
                      side: const BorderSide(color: Color(0xFF1E3347)),
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14)),
                      padding: const EdgeInsets.symmetric(vertical: 14)),
                    child: const Text('Back'))),
                  const SizedBox(width: 12),
                  Expanded(flex: 2, child: ElevatedButton(
                    onPressed: saving
                        ? null
                        : () async {
                            ss(() => saving = true);
                            try {
                              final db = FirebaseFirestore.instance;
                              // Save one fee record per selected course schedule
                              for (final sched in selectedSchedules) {
                                final course   = _courseFromStudentSchedule(sched);
                                final cFee     = (course['CourseFee'] as num?)?.toDouble() ?? 0.0;
                                final cTotal   = cFee * multiplier;
                                final cConv    = paymentMode == 'Payment Gateway'
                                    ? _calcConvenience(cTotal)['total']! : 0.0;
                                final receiptNo = await _generateReceiptNo();
                                final ref       = db.collection('StudentFee').doc();
                                await ref.set({
                                  'FeeID':                   ref.id,
                                  'ClientID':                widget.clientId,
                                  'StudentEnrollmentNo':     selectedStudent!['StudentEnrollmentNo'],
                                  'StudentCourseScheduleID': sched['DocID'],
                                  'PaymentCycleSubTypeID':   selectedPayCycle!['DocID'],
                                  'PaymentMode':             paymentMode,
                                  'BaseAmount':              cFee,
                                  'PaymentCycleMultiplier':  multiplier,
                                  'TotalAmount':             cTotal,
                                  'ConvenienceFee':          cConv,
                                  'GrandTotal':              cTotal + cConv,
                                  'ReceiptNumber':           receiptNo,
                                  'DateOfPayment':           FieldValue.serverTimestamp(),
                                  'IsActive':                true,
                                  'CreatedAt':               FieldValue.serverTimestamp(),
                                });
                              }
                              if (ctx.mounted) Navigator.pop(ctx);
                              await _load();
                              if (mounted) {
                                final firstCourse = _courseFromStudentSchedule(selectedSchedules.first);
                                final displayCourse = selectedSchedules.length > 1
                                    ? {'CourseName': '${selectedSchedules.length} courses'}
                                    : firstCourse;
                                _showReceiptDialog(
                                  '(see list)', selectedStudent!,
                                  displayCourse,
                                  grandTotal, paymentMode);
                              }
                            } catch (e) {
                              _snack('Failed to record fee: $e');
                              ss(() => saving = false);
                            }
                          },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF1DB954),
                      foregroundColor: Colors.white,
                      elevation: 0,
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14)),
                      padding: const EdgeInsets.symmetric(vertical: 14)),
                    child: saving
                        ? const SizedBox(width: 20, height: 20,
                            child: CircularProgressIndicator(
                                color: Colors.white, strokeWidth: 2))
                        : const Text('Confirm Payment',
                            style: TextStyle(fontSize: 15,
                                fontWeight: FontWeight.w600)))),
                ]),
              ],
              const SizedBox(height: 8),
            ])),
        ),
      )));
  }

  Widget _modeCard(String label, IconData icon, Color color, String sub) =>
    Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: color.withOpacity(0.08),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withOpacity(0.3))),
      child: Row(children: [
        Icon(icon, color: color, size: 18),
        const SizedBox(width: 10),
        Text(label, style: TextStyle(fontSize: 13, color: color,
            fontWeight: FontWeight.w500)),
        const Spacer(),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
          decoration: BoxDecoration(
              color: color.withOpacity(0.12),
              borderRadius: BorderRadius.circular(6)),
          child: Text(sub, style: TextStyle(fontSize: 10, color: color))),
      ]));

  void _showReceiptDialog(String receiptNo, Map<String, dynamic> student,
      Map<String, dynamic> course, double grandTotal, String mode) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF152232),
        shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20)),
        content: Column(mainAxisSize: MainAxisSize.min, children: [
          Container(width: 64, height: 64,
            decoration: BoxDecoration(
              color: const Color(0xFF1DB954).withOpacity(0.12),
              borderRadius: BorderRadius.circular(18)),
            child: const Icon(Icons.receipt_long_outlined,
                color: Color(0xFF1DB954), size: 32)),
          const SizedBox(height: 16),
          const Text('Payment Recorded!',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold,
                  color: Colors.white, fontFamily: 'Georgia')),
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: const Color(0xFF0D1B2A),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                  color: const Color(0xFF1DB954).withOpacity(0.3))),
            child: Column(children: [
              _feeRow('Receipt', receiptNo, isTitle: true),
              const SizedBox(height: 6),
              _feeRow('Student', student['Name'] ?? ''),
              _feeRow('Course', course['CourseName'] ?? ''),
              _feeRow('Mode', mode),
              const Divider(color: Color(0xFF1E3347), height: 16),
              _feeRow('Amount Paid',
                  '₹${grandTotal.toStringAsFixed(2)}',
                  isGrandTotal: true),
            ])),
          const SizedBox(height: 20),
          SizedBox(width: double.infinity, child: ElevatedButton(
            onPressed: () => Navigator.pop(ctx),
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF1DB954),
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12)),
              padding: const EdgeInsets.symmetric(vertical: 13)),
            child: const Text('Done',
                style: TextStyle(fontWeight: FontWeight.w600)))),
        ]),
      ),
    );
  }

  Widget _feeRow(String label, String value, {
    bool isTitle = false, bool highlight = false,
    bool isConvenience = false, bool isGrandTotal = false,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Row(children: [
        Text(label, style: TextStyle(
          fontSize: isGrandTotal ? 14 : 12,
          color: isTitle ? Colors.white : const Color(0xFF8899AA),
          fontWeight: isTitle || isGrandTotal
              ? FontWeight.w600 : FontWeight.normal)),
        const Spacer(),
        Text(value, style: TextStyle(
          fontSize: isGrandTotal ? 15 : 12,
          fontWeight: isGrandTotal || highlight
              ? FontWeight.bold : FontWeight.w500,
          color: isGrandTotal
              ? const Color(0xFF1DB954)
              : isConvenience
                  ? const Color(0xFFE74C3C)
                  : highlight
                      ? Colors.white
                      : const Color(0xFF8899AA))),
      ]));
  }

  Widget _lbl(String t) => Text(t,
      style: const TextStyle(fontSize: 13,
          fontWeight: FontWeight.w500, color: Color(0xFF8899AA)));

  void _snack(String msg, {bool ok = false}) =>
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(msg,
          style: const TextStyle(color: Colors.white, fontSize: 14)),
      backgroundColor:
          ok ? const Color(0xFF2ECC71) : const Color(0xFFE74C3C),
      behavior: SnackBarBehavior.floating,
      shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12)),
      margin: const EdgeInsets.all(16)));
}

// ══════════════════════════════════════════════════════════════════════════════
// Payroll Section
// ══════════════════════════════════════════════════════════════════════════════
class PayrollSection extends StatefulWidget {
  final String clientId;
  final String branchId;

  const PayrollSection({
    super.key,
    required this.clientId,
    required this.branchId,
  });

  @override
  State<PayrollSection> createState() => _PayrollSectionState();
}

class _PayrollSectionState extends State<PayrollSection> {
  // ── Data ──────────────────────────────────────────────────────────────────
  List<Map<String, dynamic>> _staff                = [];
  List<Map<String, dynamic>> _staffSchedules       = [];
  List<Map<String, dynamic>> _courseSchedules      = [];
  List<Map<String, dynamic>> _courses              = [];
  List<Map<String, dynamic>> _studentSchedules     = [];
  List<Map<String, dynamic>> _revenueShareSubTypes = [];
  List<Map<String, dynamic>> _transactions         = [];

  bool _isLoading    = true;
  bool _isGenerating = false;

  late DateTime _selectedMonth;

  @override
  void initState() {
    super.initState();
    final now = DateTime.now();
    _selectedMonth = DateTime(now.year, now.month);
    _load();
  }

  // ── Helpers ───────────────────────────────────────────────────────────────
  String _monthLabel(DateTime d) {
    const months = [
      'January','February','March','April','May','June',
      'July','August','September','October','November','December'
    ];
    return '${months[d.month - 1]} ${d.year}';
  }

  String _monthKey(DateTime d) =>
      '${d.year}-${d.month.toString().padLeft(2, '0')}';

  List<Map<String, dynamic>> _snap(dynamic s) =>
      (s as QuerySnapshot).docs
          .map((d) => {...(d.data() as Map<String, dynamic>), 'DocID': d.id})
          .toList();

  Map<String, dynamic> _courseScheduleById(String? id) =>
      _courseSchedules.firstWhere((c) => c['DocID'] == id, orElse: () => {});

  Map<String, dynamic> _courseById(String? id) =>
      _courses.firstWhere((c) => c['DocID'] == id, orElse: () => {});

  Map<String, dynamic> _revenueShareById(String? id) =>
      _revenueShareSubTypes.firstWhere((s) => s['DocID'] == id, orElse: () => {});

  /// Parse staff share % from SubTypeName "70-30" -> 30.0
  double _staffSharePercent(Map<String, dynamic> sub) {
    final parts = (sub['SubTypeName'] as String? ?? '').split('-');
    if (parts.length == 2) return double.tryParse(parts[1].trim()) ?? 0;
    return 0;
  }

  String _fmt(double v) {
    if (v >= 100000) return '${(v / 100000).toStringAsFixed(1)}L';
    if (v >= 1000)   return '${(v / 1000).toStringAsFixed(1)}K';
    return v.toStringAsFixed(0);
  }

  // ── Load ──────────────────────────────────────────────────────────────────
  Future<void> _load() async {
    setState(() => _isLoading = true);
    try {
      final db = FirebaseFirestore.instance;
      final results = await Future.wait([
        db.collection('Staff')
            .where('ClientID', isEqualTo: widget.clientId)
            .where('IsActive', isEqualTo: true).get(),
        db.collection('StaffCourseSchedule')
            .where('ClientID', isEqualTo: widget.clientId)
            .where('IsActive', isEqualTo: true).get(),
        db.collection('CourseSchedule')
            .where('ClientID', isEqualTo: widget.clientId).get(),
        db.collection('Course')
            .where('ClientID', isEqualTo: widget.clientId).get(),
        db.collection('StudentCourseSchedule')
            .where('ClientID', isEqualTo: widget.clientId)
            .where('IsActive', isEqualTo: true).get(),
        db.collection('SubType')
            .where('ClientID', isEqualTo: widget.clientId)
            .where('SubTypeCode', isEqualTo: 'RevenueShare')
            .where('IsActive', isEqualTo: true).get(),
        db.collection('PayrollTransactions')
            .where('ClientID', isEqualTo: widget.clientId).get(),
      ]);

      if (mounted) setState(() {
        _staff                = _snap(results[0]);
        _staffSchedules       = _snap(results[1]);
        _courseSchedules      = _snap(results[2]);
        _courses              = _snap(results[3]);
        _studentSchedules     = _snap(results[4]);
        _revenueShareSubTypes = _snap(results[5]);
        _transactions         = _snap(results[6])
          ..sort((a, b) {
            final aTs = a['CreatedAt'] as Timestamp?;
            final bTs = b['CreatedAt'] as Timestamp?;
            if (aTs == null && bTs == null) return 0;
            if (aTs == null) return 1;
            if (bTs == null) return -1;
            return bTs.compareTo(aTs);
          });
        _isLoading            = false;
      });

      // ── Debug: dump key field names so we can spot mismatches ────────────
      for (final s in _staff) {
        debugPrint('STAFF doc keys: ${s.keys.toList()} | '
            'EnrollNo=${s['StaffEnrollmentNo']} | '
            'PayrollType=${s['PayrollType']} | '
            'PayrollInfo=${s['PayrollInfo']}');
      }
      for (final s in _staffSchedules) {
        debugPrint('STAFF_SCHED doc keys: ${s.keys.toList()} | '
            'StaffEnrollNo=${s['StaffEnrollmentNo']} | '
            'CourseScheduleID=${s['CourseScheduleID']}');
      }
      for (final s in _studentSchedules) {
        debugPrint('STU_SCHED: CourseScheduleID=${s['CourseScheduleID']} | '
            'IsActive=${s['IsActive']}');
      }
      for (final s in _revenueShareSubTypes) {
        debugPrint('REVENUE_SHARE SubType: DocID=${s['DocID']} | '
            'SubTypeName=${s['SubTypeName']} | SubTypeCode=${s['SubTypeCode']}');
      }
    } catch (e) {
      debugPrint('Payroll load error: $e');
      if (mounted) setState(() => _isLoading = false);
    }
  }

  // ── Duplicate check ───────────────────────────────────────────────────────
  bool _alreadyGenerated(DateTime month) {
    final key = _monthKey(month);
    return _transactions.any((t) => t['PayrollMonth'] == key);
  }

  // ── Calculate one staff member's payroll ──────────────────────────────────
  Map<String, dynamic> _calcStaff(Map<String, dynamic> staff) {
    // Field names: try both common variants
    final enrollNo = staff['StaffEnrollmentNo'] as String?
        ?? staff['EnrollmentNo'] as String?
        ?? staff['DocID'] as String? ?? '';
    final payType  = staff['PayrollType'] as String? ?? '';
    // PayrollInfo holds salary amount (fixed) or RevenueShare SubType DocID (partnership)
    final payInfo  = staff['PayrollInfo'] as String?
        ?? staff['PayrollAmount'] as String? ?? '';

    debugPrint('▶ calcStaff: $enrollNo | type=$payType | info=$payInfo');

    double totalAmount = 0;
    List<Map<String, dynamic>> breakdown = [];

    if (payType == 'Monthly Fixed Salary') {
      // PayrollInfo = "25000"
      totalAmount = double.tryParse(payInfo.trim()) ?? 0;
      debugPrint('  Fixed salary: ₹$totalAmount');

    } else if (payType == 'Partnership') {
      // Step 1: all StaffCourseSchedule rows for this staff
      final myStaffSchedules = _staffSchedules.where((s) {
        final sEnroll = s['StaffEnrollmentNo'] as String?
            ?? s['EnrollmentNo'] as String? ?? '';
        return sEnroll == enrollNo;
      }).toList();

      debugPrint('  StaffCourseSchedules found: ${myStaffSchedules.length}');

      // Step 2: resolve revenue share %
      // payInfo = SubType DocID for the revenue share model (e.g. "50-50")
      final shareSubType = _revenueShareById(payInfo.trim());
      final sharePercent = _staffSharePercent(shareSubType);
      debugPrint('  ShareSubType: ${shareSubType['SubTypeName']} → $sharePercent%');

      for (final ss in myStaffSchedules) {
        // StaffCourseSchedule → CourseScheduleID → CourseSchedule → CourseID → Course
        final csId = ss['CourseScheduleID'] as String?
            ?? ss['ScheduleID'] as String? ?? '';
        final cs        = _courseScheduleById(csId);
        final courseId  = cs['CourseID'] as String? ?? '';
        final course    = _courseById(courseId);
        final courseFee = (course['CourseFee'] as num?)?.toDouble() ?? 0;
        final courseName= course['CourseName'] as String? ?? '(unknown)';

        // Count active StudentCourseSchedule rows for this CourseSchedule
        final enrolled = _studentSchedules.where((stu) {
          final stuCsId = stu['CourseScheduleID'] as String? ?? '';
          return stuCsId == csId;
        }).length;

        final revenue  = courseFee * enrolled;
        final staffAmt = revenue * (sharePercent / 100);
        totalAmount   += staffAmt;

        debugPrint('  Batch $csId | course=$courseName | fee=₹$courseFee'
            ' | enrolled=$enrolled | revenue=₹$revenue | staffAmt=₹$staffAmt');

        breakdown.add({
          'CourseScheduleID': csId,
          'CourseName':       courseName,
          'EnrolledCount':    enrolled,
          'CourseFee':        courseFee,
          'Revenue':          revenue,
          'SharePercent':     sharePercent,
          'StaffAmount':      staffAmt,
        });
      }
      debugPrint('  Total partnership payroll: ₹$totalAmount');
    }

    return {
      'staff':       staff,
      'payType':     payType,
      'totalAmount': totalAmount,
      'breakdown':   breakdown,
    };
  }

  // ── Delete existing month payroll and regenerate ─────────────────────────
  Future<void> _deleteAndRegenerate() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF152232),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text('Regenerate Payroll?',
            style: TextStyle(color: Colors.white, fontFamily: 'Georgia')),
        content: Text(
          'This will delete and recalculate the ${_monthLabel(_selectedMonth)} payroll.\n\nUse this only if staff data was changed.',
          style: const TextStyle(color: Color(0xFF8899AA), fontSize: 13, height: 1.5)),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Cancel',
                  style: TextStyle(color: Color(0xFF8899AA)))),
          TextButton(onPressed: () => Navigator.pop(ctx, true),
              child: const Text('Regenerate',
                  style: TextStyle(color: Color(0xFFE74C3C)))),
        ]));
    if (confirmed != true) return;

    setState(() => _isGenerating = true);
    try {
      final db      = FirebaseFirestore.instance;
      final monthKey = _monthKey(_selectedMonth);
      // Delete existing records for this month
      final existing = await db.collection('PayrollTransactions')
          .where('ClientID', isEqualTo: widget.clientId)
          .where('PayrollMonth', isEqualTo: monthKey).get();
      final delBatch = db.batch();
      for (final doc in existing.docs) delBatch.delete(doc.reference);
      await delBatch.commit();
      // Remove from local list so _alreadyGenerated returns false
      _transactions.removeWhere((t) => t['PayrollMonth'] == monthKey);
      await _generatePayroll();
    } catch (e) {
      _snack('Failed to regenerate: $e');
      if (mounted) setState(() => _isGenerating = false);
    }
  }

  // ── Generate payroll ──────────────────────────────────────────────────────
  Future<void> _generatePayroll() async {
    if (_alreadyGenerated(_selectedMonth)) {
      _snack('${_monthLabel(_selectedMonth)} payroll already generated.');
      return;
    }
    setState(() => _isGenerating = true);
    try {
      final db       = FirebaseFirestore.instance;
      final monthKey = _monthKey(_selectedMonth);

      // Find next invoice number
      int invoiceNum = 1;
      final nums = _transactions
          .map((t) => t['PayrollInvoiceNo'] as String? ?? '')
          .where((s) => s.startsWith('PAY-'))
          .map((s) => int.tryParse(s.split('-').last) ?? 0)
          .toList();
      if (nums.isNotEmpty) invoiceNum = nums.reduce((a, b) => a > b ? a : b) + 1;

      final batch = db.batch();
      for (final staff in _staff) {
        final calc      = _calcStaff(staff);
        final enrollNo  = staff['StaffEnrollmentNo'] as String? ?? staff['DocID'];
        final invoiceNo = 'PAY-${_selectedMonth.year}-${invoiceNum.toString().padLeft(3, '0')}';
        invoiceNum++;

        final ref = db.collection('PayrollTransactions').doc();
        batch.set(ref, {
          'PayrollID':          ref.id,
          'ClientID':           widget.clientId,
          'StaffEnrollmentNo':  enrollNo,
          'PayrollType':        calc['payType'],
          'PayrollMonth':       monthKey,
          'PayrollInvoiceNo':   invoiceNo,
          'PaymentAmount':      calc['totalAmount'],
          'PayrollBreakdown':   calc['breakdown'],
          'DateOfPayment':      FieldValue.serverTimestamp(),
          'CreatedAt':          FieldValue.serverTimestamp(),
          'IsActive':           true,
        });
      }
      await batch.commit();
      await _load();
      if (mounted) {
        _snack('Payroll generated for ${_monthLabel(_selectedMonth)}!', ok: true);
      }
    } catch (e) {
      _snack('Failed to generate payroll: $e');
    } finally {
      if (mounted) setState(() => _isGenerating = false);
    }
  }

  List<Map<String, dynamic>> get _monthTransactions {
    final key = _monthKey(_selectedMonth);
    return _transactions.where((t) => t['PayrollMonth'] == key).toList();
  }

  // ── Build ─────────────────────────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    final generated = _alreadyGenerated(_selectedMonth);
    return Column(children: [
      // ── Top bar ──────────────────────────────────────────────────────────
      Padding(
        padding: const EdgeInsets.fromLTRB(20, 0, 20, 12),
        child: Row(children: [
          // Month picker
          Expanded(
            child: GestureDetector(
              onTap: _pickMonth,
              child: Container(
                height: 40,
                padding: const EdgeInsets.symmetric(horizontal: 14),
                decoration: BoxDecoration(
                  color: const Color(0xFF0D1B2A),
                  borderRadius: BorderRadius.circular(11),
                  border: Border.all(color: const Color(0xFF1E3347))),
                child: Row(children: [
                  const Icon(Icons.calendar_month_rounded,
                      color: Color(0xFF1DB954), size: 17),
                  const SizedBox(width: 8),
                  Text(_monthLabel(_selectedMonth),
                      style: const TextStyle(fontSize: 13,
                          color: Colors.white, fontWeight: FontWeight.w500)),
                  const Spacer(),
                  const Icon(Icons.keyboard_arrow_down_rounded,
                      color: Color(0xFF556677), size: 18),
                ]),
              ),
            ),
          ),
          const SizedBox(width: 10),
          // Generate / Generated button
          GestureDetector(
            onTap: (_isGenerating || generated) ? null : _generatePayroll,
            onLongPress: generated ? _deleteAndRegenerate : null,
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              height: 40,
              padding: const EdgeInsets.symmetric(horizontal: 14),
              decoration: BoxDecoration(
                color: generated
                    ? const Color(0xFF1E3347)
                    : const Color(0xFF1DB954).withOpacity(0.12),
                borderRadius: BorderRadius.circular(11),
                border: Border.all(
                  color: generated
                      ? const Color(0xFF1E3347)
                      : const Color(0xFF1DB954).withOpacity(0.4))),
              child: Row(mainAxisSize: MainAxisSize.min, children: [
                _isGenerating
                    ? const SizedBox(width: 15, height: 15,
                        child: CircularProgressIndicator(
                            color: Color(0xFF1DB954), strokeWidth: 2))
                    : Icon(
                        generated
                            ? Icons.check_circle_rounded
                            : Icons.bolt_rounded,
                        color: generated
                            ? const Color(0xFF556677)
                            : const Color(0xFF1DB954),
                        size: 17),
                const SizedBox(width: 6),
                Text(
                  generated ? 'Generated' : 'Generate',
                  style: TextStyle(
                    fontSize: 13, fontWeight: FontWeight.w500,
                    color: generated
                        ? const Color(0xFF556677)
                        : const Color(0xFF1DB954))),
              ]),
            ),
          ),
        ]),
      ),

      // ── Body ─────────────────────────────────────────────────────────────
      Expanded(
        child: _isLoading
            ? const Center(child: CircularProgressIndicator(
                color: Color(0xFF1DB954), strokeWidth: 2))
            : RefreshIndicator(
                onRefresh: _load,
                color: const Color(0xFF1DB954),
                backgroundColor: const Color(0xFF152232),
                child: _monthTransactions.isEmpty
                    ? _emptyState()
                    : ListView(
                        padding: const EdgeInsets.fromLTRB(20, 0, 20, 100),
                        children: [
                          _summaryBar(),
                          const SizedBox(height: 14),
                          ..._monthTransactions.map(_payrollCard),
                        ]))),
    ]);
  }

  // ── Month picker sheet ────────────────────────────────────────────────────
  Future<void> _pickMonth() async {
    final now    = DateTime.now();
    final months = List.generate(12, (i) => DateTime(now.year, now.month - i));

    await showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (ctx) => Container(
        decoration: const BoxDecoration(
          color: Color(0xFF152232),
          borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
        padding: const EdgeInsets.all(24),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          Center(child: Container(width: 40, height: 4,
            decoration: BoxDecoration(color: const Color(0xFF1E3347),
                borderRadius: BorderRadius.circular(2)))),
          const SizedBox(height: 16),
          const Text('Select Month', style: TextStyle(fontSize: 16,
              fontWeight: FontWeight.bold, color: Colors.white,
              fontFamily: 'Georgia')),
          const SizedBox(height: 16),
          ...months.map((m) {
            final isSelected  = _monthKey(m) == _monthKey(_selectedMonth);
            final isGenerated = _alreadyGenerated(m);
            return GestureDetector(
              onTap: () { setState(() => _selectedMonth = m); Navigator.pop(ctx); },
              child: Container(
                margin: const EdgeInsets.only(bottom: 8),
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                decoration: BoxDecoration(
                  color: isSelected
                      ? const Color(0xFF1DB954).withOpacity(0.1)
                      : const Color(0xFF0D1B2A),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: isSelected
                        ? const Color(0xFF1DB954)
                        : const Color(0xFF1E3347),
                    width: isSelected ? 1.5 : 1)),
                child: Row(children: [
                  Text(_monthLabel(m), style: TextStyle(fontSize: 14,
                      fontWeight: FontWeight.w500,
                      color: isSelected ? const Color(0xFF1DB954) : Colors.white)),
                  const Spacer(),
                  if (isGenerated)
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                      decoration: BoxDecoration(
                        color: const Color(0xFF1DB954).withOpacity(0.1),
                        borderRadius: BorderRadius.circular(6)),
                      child: const Text('Generated',
                          style: TextStyle(fontSize: 10,
                              color: Color(0xFF1DB954)))),
                  if (isSelected && !isGenerated)
                    const Icon(Icons.check_rounded,
                        color: Color(0xFF1DB954), size: 16),
                ])));
          }),
          const SizedBox(height: 8),
        ]),
      ),
    );
  }

  // ── Summary bar ───────────────────────────────────────────────────────────
  Widget _summaryBar() {
    final total = _monthTransactions.fold<double>(
        0, (s, t) => s + ((t['PaymentAmount'] as num?)?.toDouble() ?? 0));
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: const Color(0xFF1DB954).withOpacity(0.07),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFF1DB954).withOpacity(0.2))),
      child: Row(children: [
        Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(_monthLabel(_selectedMonth),
              style: const TextStyle(fontSize: 12, color: Color(0xFF8899AA))),
          const SizedBox(height: 2),
          Text('₹${_fmt(total)}',
              style: const TextStyle(fontSize: 20,
                  fontWeight: FontWeight.bold, color: Color(0xFF1DB954))),
        ]),
        const Spacer(),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          decoration: BoxDecoration(
            color: const Color(0xFF1DB954).withOpacity(0.1),
            borderRadius: BorderRadius.circular(10)),
          child: Text('${_monthTransactions.length} staff',
              style: const TextStyle(fontSize: 13,
                  fontWeight: FontWeight.w500, color: Color(0xFF1DB954)))),
      ]));
  }

  // ── Payroll card ──────────────────────────────────────────────────────────
  Widget _payrollCard(Map<String, dynamic> txn) {
    final enrollNo  = txn['StaffEnrollmentNo'] as String? ?? '';
    final staffDoc  = _staff.firstWhere(
        (s) => (s['StaffEnrollmentNo'] ?? s['DocID']) == enrollNo,
        orElse: () => {});
    final name      = staffDoc['Name'] as String? ?? enrollNo;
    final payType   = txn['PayrollType'] as String? ?? '';
    final amount    = (txn['PaymentAmount'] as num?)?.toDouble() ?? 0;
    final invoiceNo = txn['PayrollInvoiceNo'] as String? ?? '—';
    final isFixed   = payType == 'Monthly Fixed Salary';
    final breakdown = (txn['PayrollBreakdown'] as List?)
        ?.map((e) => Map<String, dynamic>.from(e as Map)).toList() ?? [];

    final avatarColor = isFixed ? const Color(0xFF5BA3D9) : const Color(0xFF9B59B6);

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: const Color(0xFF152232),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: const Color(0xFF1E3347))),
      child: Column(children: [
        Padding(
          padding: const EdgeInsets.all(16),
          child: Row(children: [
            // Avatar
            Container(width: 46, height: 46,
              decoration: BoxDecoration(
                color: avatarColor.withOpacity(0.15),
                borderRadius: BorderRadius.circular(13)),
              child: Center(child: Text(
                name.isNotEmpty ? name[0].toUpperCase() : 'S',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold,
                    color: avatarColor)))),
            const SizedBox(width: 12),
            Expanded(child: Column(
                crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(name, style: const TextStyle(fontSize: 15,
                  fontWeight: FontWeight.w600, color: Colors.white)),
              const SizedBox(height: 4),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                decoration: BoxDecoration(
                  color: avatarColor.withOpacity(0.12),
                  borderRadius: BorderRadius.circular(5)),
                child: Text(
                  isFixed ? 'Fixed Salary' : 'Partnership',
                  style: TextStyle(fontSize: 10, color: avatarColor))),
            ])),
            Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
              Text('₹${_fmt(amount)}',
                  style: const TextStyle(fontSize: 17,
                      fontWeight: FontWeight.bold, color: Color(0xFF1DB954))),
              if (!isFixed && breakdown.isNotEmpty) ...[
                const SizedBox(height: 4),
                GestureDetector(
                  onTap: () => _showBreakdown(name, invoiceNo, breakdown, amount),
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(
                      color: const Color(0xFF1DB954).withOpacity(0.1),
                      borderRadius: BorderRadius.circular(6)),
                    child: const Row(mainAxisSize: MainAxisSize.min, children: [
                      Icon(Icons.bar_chart_rounded,
                          color: Color(0xFF1DB954), size: 12),
                      SizedBox(width: 4),
                      Text('Details', style: TextStyle(
                          fontSize: 10, color: Color(0xFF1DB954))),
                    ]))),
              ],
            ]),
          ])),
        // Footer
        Container(
          padding: const EdgeInsets.fromLTRB(16, 10, 16, 10),
          decoration: const BoxDecoration(
              border: Border(top: BorderSide(color: Color(0xFF1E3347)))),
          child: Row(children: [
            const Icon(Icons.confirmation_number_outlined,
                color: Color(0xFF556677), size: 13),
            const SizedBox(width: 4),
            Text(invoiceNo, style: const TextStyle(
                fontSize: 11, color: Color(0xFF8899AA))),
            const Spacer(),
            if (!isFixed && breakdown.isNotEmpty) ...[
              const Icon(Icons.groups_rounded,
                  color: Color(0xFF556677), size: 13),
              const SizedBox(width: 4),
              Text(
                '${breakdown.fold<int>(0, (s, b) => s + ((b['EnrolledCount'] as num?)?.toInt() ?? 0))} students'
                ' · ${breakdown.length} batches',
                style: const TextStyle(fontSize: 11, color: Color(0xFF556677))),
            ] else if (isFixed) ...[
              const Icon(Icons.lock_outline_rounded,
                  color: Color(0xFF556677), size: 13),
              const SizedBox(width: 4),
              const Text('Fixed monthly', style: TextStyle(
                  fontSize: 11, color: Color(0xFF556677))),
            ],
          ])),
      ]));
  }

  // ── Breakdown detail bottom sheet ─────────────────────────────────────────
  void _showBreakdown(String staffName, String invoiceNo,
      List<Map<String, dynamic>> breakdown, double totalAmount) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => DraggableScrollableSheet(
        initialChildSize: 0.65,
        minChildSize: 0.4,
        maxChildSize: 0.95,
        builder: (_, controller) => Container(
          decoration: const BoxDecoration(
            color: Color(0xFF152232),
            borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
          child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
            // ── Fixed header ──────────────────────────────────────────────
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 16, 24, 0),
              child: Column(mainAxisSize: MainAxisSize.min, children: [
                Center(child: Container(width: 40, height: 4,
                  decoration: BoxDecoration(color: const Color(0xFF1E3347),
                      borderRadius: BorderRadius.circular(2)))),
                const SizedBox(height: 16),
                Row(children: [
                  Container(width: 36, height: 36,
                    decoration: BoxDecoration(
                      color: const Color(0xFF9B59B6).withOpacity(0.15),
                      borderRadius: BorderRadius.circular(10)),
                    child: const Icon(Icons.bar_chart_rounded,
                        color: Color(0xFF9B59B6), size: 18)),
                  const SizedBox(width: 12),
                  Expanded(child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Text(staffName, style: const TextStyle(fontSize: 16,
                        fontWeight: FontWeight.bold, color: Colors.white,
                        fontFamily: 'Georgia')),
                    Text(invoiceNo, style: const TextStyle(
                        fontSize: 11, color: Color(0xFF556677))),
                  ])),
                ]),
                const SizedBox(height: 14),
                // Total chip
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  decoration: BoxDecoration(
                    color: const Color(0xFF1DB954).withOpacity(0.08),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                        color: const Color(0xFF1DB954).withOpacity(0.25))),
                  child: Column(mainAxisSize: MainAxisSize.min, children: [
                    const Text('Total Payroll',
                        style: TextStyle(fontSize: 11, color: Color(0xFF8899AA))),
                    const SizedBox(height: 4),
                    Text('₹${_fmt(totalAmount)}',
                        style: const TextStyle(fontSize: 22,
                            fontWeight: FontWeight.bold,
                            color: Color(0xFF1DB954))),
                  ])),
                const SizedBox(height: 14),
                const Divider(color: Color(0xFF1E3347), height: 1),
              ])),
            // Batch breakdown list
            Expanded(
              child: ListView.builder(
                controller: controller,
                padding: const EdgeInsets.fromLTRB(24, 12, 24, 32),
                itemCount: breakdown.length,
                itemBuilder: (_, i) {
                  final b            = breakdown[i];
                  final courseName   = b['CourseName'] as String? ?? '—';
                  final enrolled     = (b['EnrolledCount'] as num?)?.toInt() ?? 0;
                  final fee          = (b['CourseFee'] as num?)?.toDouble() ?? 0;
                  final revenue      = (b['Revenue'] as num?)?.toDouble() ?? 0;
                  final sharePercent = (b['SharePercent'] as num?)?.toDouble() ?? 0;
                  final staffAmt     = (b['StaffAmount'] as num?)?.toDouble() ?? 0;

                  return Container(
                    margin: const EdgeInsets.only(bottom: 10),
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: const Color(0xFF0D1B2A),
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(color: const Color(0xFF1E3347))),
                    child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                      Row(children: [
                        const Icon(Icons.menu_book_outlined,
                            color: Color(0xFF9B59B6), size: 15),
                        const SizedBox(width: 8),
                        Expanded(child: Text(courseName,
                            style: const TextStyle(fontSize: 13,
                                fontWeight: FontWeight.w600,
                                color: Colors.white))),
                        Text('₹${_fmt(staffAmt)}',
                            style: const TextStyle(fontSize: 14,
                                fontWeight: FontWeight.bold,
                                color: Color(0xFF1DB954))),
                      ]),
                      const SizedBox(height: 10),
                      const Divider(color: Color(0xFF1E3347), height: 1),
                      const SizedBox(height: 10),
                      _bRow('Students enrolled',  '$enrolled'),
                      _bRow('Fee per student',    '₹${_fmt(fee)} / month'),
                      _bRow('Batch revenue',      '₹${_fmt(revenue)}'),
                      _bRow('Staff share %',      '${sharePercent.toStringAsFixed(0)}%'),
                      const SizedBox(height: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 12, vertical: 8),
                        decoration: BoxDecoration(
                          color: const Color(0xFF1DB954).withOpacity(0.07),
                          borderRadius: BorderRadius.circular(8)),
                        child: Row(children: [
                          const Text('Staff earnings',
                              style: TextStyle(fontSize: 12,
                                  fontWeight: FontWeight.w600,
                                  color: Colors.white)),
                          const Spacer(),
                          Text('₹${_fmt(staffAmt)}',
                              style: const TextStyle(fontSize: 13,
                                  fontWeight: FontWeight.bold,
                                  color: Color(0xFF1DB954))),
                        ])),
                    ]));
                })),
          ]))));
  }

  Widget _bRow(String label, String value) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 3),
    child: Row(children: [
      Text(label, style: const TextStyle(fontSize: 11, color: Color(0xFF8899AA))),
      const Spacer(),
      Text(value, style: const TextStyle(fontSize: 11,
          fontWeight: FontWeight.w500, color: Colors.white)),
    ]));

  Widget _emptyState() => ListView(
    padding: const EdgeInsets.all(32),
    children: [
      const SizedBox(height: 40),
      Center(child: Column(children: [
        Container(width: 72, height: 72,
          decoration: BoxDecoration(
            color: const Color(0xFF1DB954).withOpacity(0.08),
            borderRadius: BorderRadius.circular(20)),
          child: const Icon(Icons.account_balance_wallet_outlined,
              color: Color(0xFF3A5068), size: 36)),
        const SizedBox(height: 20),
        const Text('No Payroll Generated',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600,
                color: Colors.white, fontFamily: 'Georgia')),
        const SizedBox(height: 8),
        const Text(
          'Select a month and tap "Generate"\nto process payroll for all active staff.',
          textAlign: TextAlign.center,
          style: TextStyle(fontSize: 13, color: Color(0xFF556677), height: 1.5)),
      ])),
    ]);

  void _snack(String msg, {bool ok = false}) =>
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(msg,
          style: const TextStyle(color: Colors.white, fontSize: 14)),
      backgroundColor:
          ok ? const Color(0xFF2ECC71) : const Color(0xFFE74C3C),
      behavior: SnackBarBehavior.floating,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      margin: const EdgeInsets.all(16)));
}

// ── PayrollEntry — inline tab content that opens PayrollScreen ─────────────
class _PayrollEntry extends StatelessWidget {
  final String clientId;
  final String branchId;

  const _PayrollEntry({
    required this.clientId,
    required this.branchId,
  });

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 72, height: 72,
            decoration: BoxDecoration(
              color: const Color(0xFF1DB954).withOpacity(0.08),
              borderRadius: BorderRadius.circular(20)),
            child: const Icon(Icons.account_balance_wallet_outlined,
                color: Color(0xFF1DB954), size: 36)),
          const SizedBox(height: 20),
          const Text('Staff Payroll',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600,
                  color: Colors.white, fontFamily: 'Georgia')),
          const SizedBox(height: 8),
          const Text('Generate monthly payroll\nfor all staff at once.',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 13, color: Color(0xFF556677), height: 1.5)),
          const SizedBox(height: 24),
          ElevatedButton.icon(
            onPressed: () => Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => PayrollScreen(
                  clientId: clientId, branchId: branchId))),
            icon: const Icon(Icons.open_in_new_rounded, size: 18),
            label: const Text('Open Payroll',
                style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600)),
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF1DB954),
              foregroundColor: Colors.white,
              elevation: 0,
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14)),
              padding: const EdgeInsets.symmetric(
                  horizontal: 32, vertical: 14)),
          ),
        ],
      ),
    );
  }
}

// ── RevenueEntry — inline tab content that opens RevenueScreen ─────────────
class _RevenueEntry extends StatelessWidget {
  final String clientId;
  final String branchId;
  final String clientName;

  const _RevenueEntry({
    required this.clientId,
    required this.branchId,
    required this.clientName,
  });

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 72, height: 72,
            decoration: BoxDecoration(
              color: const Color(0xFF5BA3D9).withOpacity(0.08),
              borderRadius: BorderRadius.circular(20)),
            child: const Icon(Icons.bar_chart_rounded,
                color: Color(0xFF5BA3D9), size: 36)),
          const SizedBox(height: 20),
          const Text('Revenue',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600,
                  color: Colors.white, fontFamily: 'Georgia')),
          const SizedBox(height: 8),
          const Text('Monthly income & expenditure\nbalance sheet with PDF export.',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 13, color: Color(0xFF556677), height: 1.5)),
          const SizedBox(height: 24),
          ElevatedButton.icon(
            onPressed: () => Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => RevenueScreen(
                  clientId: clientId,
                  branchId: branchId,
                  clientName: clientName))),
            icon: const Icon(Icons.open_in_new_rounded, size: 18),
            label: const Text('Open Revenue',
                style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600)),
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF5BA3D9),
              foregroundColor: Colors.white,
              elevation: 0,
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14)),
              padding: const EdgeInsets.symmetric(
                  horizontal: 32, vertical: 14)),
          ),
        ],
      ),
    );
  }
}