import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

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
      case 1: return _comingSoon('Payroll', Icons.account_balance_wallet_outlined,
          'Staff payroll management');
      case 2: return _comingSoon('Revenue', Icons.bar_chart_rounded,
          'Revenue & analytics summary');
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