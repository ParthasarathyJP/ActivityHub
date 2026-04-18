import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

// ══════════════════════════════════════════════════════════════════════════════
// Payroll Screen — Monthly payroll generation for all staff
// ══════════════════════════════════════════════════════════════════════════════
class PayrollScreen extends StatefulWidget {
  final String clientId;
  final String branchId;

  const PayrollScreen({
    super.key,
    required this.clientId,
    required this.branchId,
  });

  @override
  State<PayrollScreen> createState() => _PayrollScreenState();
}

class _PayrollScreenState extends State<PayrollScreen> {
  // ── Selected month ─────────────────────────────────────────────────────────
  late DateTime _selectedMonth;

  // ── Payroll records for selected month ────────────────────────────────────
  List<Map<String, dynamic>> _payrolls  = [];
  List<Map<String, dynamic>> _allStaff  = [];
  bool _isLoading   = false;
  bool _isGenerating = false;

  // ── Summary ────────────────────────────────────────────────────────────────
  double _totalPayroll = 0;
  int    _skippedCount = 0;

  @override
  void initState() {
    super.initState();
    // Default to current month
    final now = DateTime.now();
    _selectedMonth = DateTime(now.year, now.month);
    _load();
  }

  // ── Month helpers ──────────────────────────────────────────────────────────
  String get _monthKey =>
      '${_selectedMonth.year}-${_selectedMonth.month.toString().padLeft(2, '0')}';

  String get _monthDisplay {
    const months = ['January','February','March','April','May','June',
        'July','August','September','October','November','December'];
    return '${months[_selectedMonth.month - 1]} ${_selectedMonth.year}';
  }

  void _prevMonth() {
    setState(() {
      _selectedMonth = DateTime(
          _selectedMonth.year, _selectedMonth.month - 1);
    });
    _load();
  }

  void _nextMonth() {
    final now = DateTime.now();
    if (_selectedMonth.year == now.year &&
        _selectedMonth.month == now.month) return;
    setState(() {
      _selectedMonth = DateTime(
          _selectedMonth.year, _selectedMonth.month + 1);
    });
    _load();
  }

  // ── Load payrolls for selected month ──────────────────────────────────────
  Future<void> _load() async {
    setState(() => _isLoading = true);
    try {
      final db = FirebaseFirestore.instance;

      QuerySnapshot? payrollSnap;
      try {
        payrollSnap = await db.collection('PayrollTransactions')
            .where('ClientID', isEqualTo: widget.clientId)
            .where('PayrollMonth', isEqualTo: _monthKey)
            .orderBy('CreatedAt').get();
      } catch (_) {
        payrollSnap = await db.collection('PayrollTransactions')
            .where('ClientID', isEqualTo: widget.clientId)
            .where('PayrollMonth', isEqualTo: _monthKey).get();
      }

      QuerySnapshot? staffSnap;
      try {
        staffSnap = await db.collection('Staff')
            .where('ClientID', isEqualTo: widget.clientId)
            .where('IsActive', isEqualTo: true)
            .orderBy('CreatedAt').get();
      } catch (_) {
        staffSnap = await db.collection('Staff')
            .where('ClientID', isEqualTo: widget.clientId)
            .where('IsActive', isEqualTo: true).get();
      }

      final payrolls = payrollSnap!.docs
          .map((d) => {...(d.data() as Map<String,dynamic>), 'DocID': d.id})
          .toList();

      if (mounted) setState(() {
        _payrolls     = payrolls;
        _allStaff     = staffSnap!.docs
            .map((d) => {...(d.data() as Map<String,dynamic>), 'DocID': d.id})
            .toList();
        _totalPayroll = payrolls.fold(0, (sum, p) =>
            sum + ((p['PaymentAmount'] as num?)?.toDouble() ?? 0));
        _isLoading    = false;
      });
    } catch (e) {
      debugPrint('Payroll load error: $e');
      if (mounted) setState(() => _isLoading = false);
    }
  }

  // ── Delete payroll for month (to allow regeneration after fixing data) ────
  Future<void> _deleteMonthPayroll() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF152232),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Text('Delete $_monthDisplay Payroll?',
            style: const TextStyle(color: Colors.white, fontFamily: 'Georgia')),
        content: const Text(
          'This will delete all payroll records for this month. '
          'You can then regenerate after fixing staff/enrollment data.',
          style: TextStyle(color: Color(0xFF8899AA), height: 1.5)),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Cancel', style: TextStyle(color: Color(0xFF8899AA)))),
          TextButton(onPressed: () => Navigator.pop(ctx, true),
              child: const Text('Delete', style: TextStyle(color: Color(0xFFE74C3C)))),
        ]));
    if (confirm != true) return;
    try {
      final db    = FirebaseFirestore.instance;
      final batch = db.batch();
      for (final p in _payrolls) {
        batch.delete(db.collection('PayrollTransactions').doc(p['DocID']));
      }
      await batch.commit();
      await _load();
      _showSnack('Payroll deleted. You can now regenerate.', ok: true);
    } catch (e) {
      _showSnack('Failed to delete payroll.');
    }
  }

  // ── Parse staff share % from SubType name ─────────────────────────────────
  // "70-30" → 30.0,  "50-50" → 50.0,  invalid → null
  double? _parseStaffShare(String? name) {
    if (name == null || name.isEmpty) return null;
    final match = RegExp(r'(\d+)-(\d+)').firstMatch(name);
    if (match == null) return null;
    final pct = double.tryParse(match.group(2)!);
    if (pct == null || pct <= 0) return null;
    return pct;
  }

  // ── Generate invoice number ────────────────────────────────────────────────
  Future<String> _generateInvoiceNo(int sequence) async {
    final year = _selectedMonth.year;
    return 'PAY-$year-${sequence.toString().padLeft(3, '0')}';
  }

  // ── Generate payroll for all staff ────────────────────────────────────────
  Future<void> _generatePayroll() async {
    // Check duplicate
    if (_payrolls.isNotEmpty) {
      _showSnack('Payroll for $_monthDisplay already generated.', ok: false);
      return;
    }

    setState(() => _isGenerating = true);
    _skippedCount = 0;

    try {
      final db = FirebaseFirestore.instance;

      // Load all data needed for calculation
      final results = await Future.wait([
        db.collection('StaffCourseSchedule')
            .where('ClientID', isEqualTo: widget.clientId)
            .where('IsActive', isEqualTo: true).get(),
        db.collection('StudentCourseSchedule')
            .where('ClientID', isEqualTo: widget.clientId)
            .where('IsActive', isEqualTo: true).get(),
        db.collection('CourseSchedule')
            .where('ClientID', isEqualTo: widget.clientId).get(),
        db.collection('Course')
            .where('ClientID', isEqualTo: widget.clientId).get(),
        db.collection('SubType')
            .where('ClientID', isEqualTo: widget.clientId)
            .where('SubTypeCode', isEqualTo: 'RevenueShare').get(),
        // All payrolls ever for this client — for unique invoice sequence
        db.collection('PayrollTransactions')
            .where('ClientID', isEqualTo: widget.clientId).get(),
        // TypeMaster for PayrollType names
        db.collection('TypeMaster')
            .where('TypeCode', isEqualTo: 'PayrollType').get(),
      ]);

      final staffSchedules   = (results[0] as QuerySnapshot).docs.map((d) => {...(d.data() as Map<String,dynamic>), 'DocID': d.id}).toList();
      final studentSchedules = (results[1] as QuerySnapshot).docs.map((d) => {...(d.data() as Map<String,dynamic>), 'DocID': d.id}).toList();
      final courseSchedules  = (results[2] as QuerySnapshot).docs.map((d) => {...(d.data() as Map<String,dynamic>), 'DocID': d.id}).toList();
      final courses          = (results[3] as QuerySnapshot).docs.map((d) => {...(d.data() as Map<String,dynamic>), 'DocID': d.id}).toList();
      final revShareSubTypes = (results[4] as QuerySnapshot).docs.map((d) => {...(d.data() as Map<String,dynamic>), 'DocID': d.id}).toList();
      final existingTotal    = (results[5] as QuerySnapshot).docs.length;
      final payrollTypes     = (results[6] as QuerySnapshot).docs.map((d) => {...(d.data() as Map<String,dynamic>), 'DocID': d.id}).toList();

      // Helper lookups
      Map<String, dynamic> courseScheduleById(String? id) =>
          courseSchedules.firstWhere((c) => c['DocID'] == id, orElse: () => {});

      Map<String, dynamic> courseById(String? id) =>
          courses.firstWhere((c) => c['DocID'] == id, orElse: () => {});

      Map<String, dynamic> revShareById(String? id) =>
          revShareSubTypes.firstWhere((s) => s['DocID'] == id, orElse: () => {});

      // Resolve PayrollType name from TypeMaster
      // PayrollTypeID stored as int (13=Monthly Fixed, 14=Partnership)
      String payrollTypeName(dynamic typeId) {
        final match = payrollTypes.firstWhere(
            (t) => t['TypeID'].toString() == typeId.toString(),
            orElse: () => {});
        return (match['TypeName'] as String? ?? '').toLowerCase();
      }

      // Count active students per CourseSchedule
      final Map<String, int> studentCountPerSchedule = {};
      for (final ss in studentSchedules) {
        final csId = ss['CourseScheduleID'] as String? ?? '';
        if (csId.isEmpty) continue;
        studentCountPerSchedule[csId] =
            (studentCountPerSchedule[csId] ?? 0) + 1;
      }

      debugPrint('Student counts per schedule: $studentCountPerSchedule');

      // Group StaffCourseSchedule by StaffEnrollmentNo
      final Map<String, List<Map<String, dynamic>>> staffBatches = {};
      for (final scs in staffSchedules) {
        final enNo = scs['StaffEnrollmentNo'] as String? ?? '';
        if (enNo.isEmpty) continue;
        staffBatches.putIfAbsent(enNo, () => []).add(scs);
      }

      debugPrint('Staff batches: ${staffBatches.keys.toList()}');

      // Process each staff
      final batchWrite = db.batch();
      int sequence     = existingTotal + 1; // global unique sequence
      int processed    = 0;
      int skipped      = 0;
      final List<Map<String, dynamic>> generatedList = [];

      for (final staff in _allStaff) {
        final enrollNo  = staff['StaffEnrollmentNo'] as String? ?? '';
        final staffName = staff['StaffName'] as String? ?? '';
        final payTypeId = staff['PayrollTypeID'];
        final payInfo   = staff['PayrollInfo'] as String? ?? '';

        debugPrint('Processing: $staffName ($enrollNo) '
            'payTypeId=$payTypeId payInfo=$payInfo');

        // ── Determine Fixed vs Partnership purely from TypeMaster name ──────
        final typeName = payrollTypeName(payTypeId);
        final isFixed  = typeName.contains('fixed');

        debugPrint('  isFixed=$isFixed typeName=$typeName');

        double paymentAmount = 0;
        List<Map<String, dynamic>> breakdown = [];

        if (isFixed) {
          // ── Monthly Fixed Salary ────────────────────────────────────────
          // PayrollInfo stores salary amount directly e.g. "25000"
          paymentAmount = double.tryParse(payInfo.trim()) ?? 0;
          debugPrint('  Fixed salary parsed: $paymentAmount from "$payInfo"');
          if (paymentAmount <= 0) {
            skipped++;
            debugPrint('  SKIPPED: invalid salary "$payInfo"');
            continue;
          }
        } else {
          // ── Partnership / Revenue Share ──────────────────────────────────
          // PayrollInfo stores RevenueShare SubType DocID
          final revShare  = revShareById(payInfo);
          final shareName = revShare['SubTypeName'] as String? ?? '';
          debugPrint('  RevShare DocID=$payInfo SubTypeName="$shareName"');

          final sharePct = _parseStaffShare(shareName);
          debugPrint('  Parsed share%=$sharePct from "$shareName"');

          if (sharePct == null) {
            skipped++;
            debugPrint('  SKIPPED: cannot parse share from "$shareName"');
            continue;
          }

          final batches = staffBatches[enrollNo] ?? [];
          debugPrint('  Batches count=${batches.length} for $enrollNo');

          if (batches.isEmpty) {
            // Partnership staff with no assigned batches → ₹0, still generate
            debugPrint('  WARNING: no batches assigned, generating ₹0 payroll');
          }

          for (final scs in batches) {
            final csId       = scs['CourseScheduleID'] as String? ?? '';
            final cs         = courseScheduleById(csId);
            final course     = courseById(cs['CourseID'] as String?);
            final courseName = course['CourseName'] as String? ?? '—';
            final batchName  = cs['BatchName'] as String? ?? '—';
            final fee        = (course['CourseFee'] as num?)?.toDouble() ?? 0;
            final count      = studentCountPerSchedule[csId] ?? 0;
            final revenue    = fee * count;
            final staffAmt   = revenue * (sharePct / 100);

            debugPrint('  Batch: $courseName / $batchName csId=$csId '
                'fee=$fee count=$count revenue=$revenue staffAmt=$staffAmt');

            paymentAmount += staffAmt;
            breakdown.add({
              'CourseScheduleID': csId,
              'CourseName':       courseName,
              'BatchName':        batchName,
              'StudentCount':     count,
              'CourseFee':        fee,
              'Revenue':          revenue,
              'SharePercent':     sharePct,
              'StaffAmount':      staffAmt,
            });
          }
        }

        // Generate unique invoice no
        final invoiceNo = await _generateInvoiceNo(sequence);
        // Check uniqueness
        final existing = await db.collection('PayrollTransactions')
            .where('ClientID', isEqualTo: widget.clientId)
            .where('PayrollInvoiceNo', isEqualTo: invoiceNo)
            .limit(1).get();
        int seqRetry = sequence;
        String finalInvoiceNo = invoiceNo;
        if (existing.docs.isNotEmpty) {
          seqRetry++;
          finalInvoiceNo = await _generateInvoiceNo(seqRetry);
        }

        final ref = db.collection('PayrollTransactions').doc();
        batchWrite.set(ref, {
          'PayrollID':           ref.id,
          'ClientID':            widget.clientId,
          'StaffEnrollmentNo':   enrollNo,
          'StaffName':           staffName,
          'PayrollType':         isFixed ? 'Monthly Fixed' : 'Partnership',
          'PayrollMonth':        _monthKey,
          'PayrollMonthDisplay': _monthDisplay,
          'PayrollInvoiceNo':    finalInvoiceNo,
          'PaymentAmount':       paymentAmount,
          'PayrollBreakdown':    breakdown,
          'IsPaid':              false,
          'DateOfPayment':       null,
          'CreatedAt':           FieldValue.serverTimestamp(),
        });

        generatedList.add({
          'StaffName':  staffName,
          'EnrollNo':   enrollNo,
          'InvoiceNo':  finalInvoiceNo,
          'Amount':     paymentAmount,
          'Type':       isFixed ? 'Monthly Fixed' : 'Partnership',
          'Breakdown':  breakdown,
        });

        sequence++;
        processed++;
        debugPrint('  → Generated $finalInvoiceNo ₹$paymentAmount');
      }

      await batchWrite.commit();
      _skippedCount = skipped;

      await _load();
      if (mounted) _showGenerationSummary(processed, skipped, generatedList);

    } catch (e) {
      _showSnack('Payroll generation failed: $e');
      debugPrint('Payroll generation error: $e');
    } finally {
      if (mounted) setState(() => _isGenerating = false);
    }
  }

  // ── Mark as paid ──────────────────────────────────────────────────────────
  Future<void> _markPaid(Map<String, dynamic> payroll, bool isPaid) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF152232),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Text(isPaid ? 'Mark as Unpaid?' : 'Mark as Paid?',
            style: const TextStyle(color: Colors.white, fontFamily: 'Georgia')),
        content: Text(
          isPaid
              ? 'Revert "${payroll['StaffName']}" payment to unpaid?'
              : 'Confirm payment of ₹${(payroll['PaymentAmount'] as num?)?.toStringAsFixed(2)} to "${payroll['StaffName']}"?',
          style: const TextStyle(color: Color(0xFF8899AA), height: 1.5)),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Cancel', style: TextStyle(color: Color(0xFF8899AA)))),
          TextButton(onPressed: () => Navigator.pop(ctx, true),
              child: Text(isPaid ? 'Revert' : 'Confirm',
                  style: TextStyle(color: isPaid
                      ? const Color(0xFFE74C3C)
                      : const Color(0xFF1DB954)))),
        ]));
    if (confirm != true) return;
    try {
      await FirebaseFirestore.instance
          .collection('PayrollTransactions')
          .doc(payroll['DocID'])
          .update({
        'IsPaid':        !isPaid,
        'DateOfPayment': isPaid ? null : FieldValue.serverTimestamp(),
        'UpdatedAt':     FieldValue.serverTimestamp(),
      });
      await _load();
      _showSnack(isPaid ? 'Reverted to unpaid.' : 'Marked as paid!', ok: !isPaid);
    } catch (e) {
      _showSnack('Failed to update payment status.');
    }
  }

  @override
  Widget build(BuildContext context) {
    final bool alreadyGenerated = _payrolls.isNotEmpty;

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
              const Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text('Payroll', style: TextStyle(fontFamily: 'Georgia',
                    fontSize: 20, fontWeight: FontWeight.bold, color: Colors.white)),
                Text('Monthly staff payroll', style: TextStyle(
                    fontSize: 12, color: Color(0xFF556677))),
              ])),
            ])),

          // Month selector
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 0, 20, 16),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(color: const Color(0xFF152232),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: const Color(0xFF1E3347))),
              child: Row(children: [
                GestureDetector(
                  onTap: _prevMonth,
                  child: Container(width: 36, height: 36,
                    decoration: BoxDecoration(
                        color: const Color(0xFF0D1B2A),
                        borderRadius: BorderRadius.circular(10)),
                    child: const Icon(Icons.chevron_left_rounded,
                        color: Color(0xFF8899AA), size: 22))),
                Expanded(child: Center(child: Text(_monthDisplay,
                    style: const TextStyle(fontSize: 16,
                        fontWeight: FontWeight.w600, color: Colors.white)))),
                GestureDetector(
                  onTap: _nextMonth,
                  child: Container(width: 36, height: 36,
                    decoration: BoxDecoration(
                        color: const Color(0xFF0D1B2A),
                        borderRadius: BorderRadius.circular(10)),
                    child: const Icon(Icons.chevron_right_rounded,
                        color: Color(0xFF8899AA), size: 22))),
              ])),
          ),

          // Summary card + Generate button
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 0, 20, 12),
            child: Row(children: [
              // Summary
              Expanded(child: Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(color: const Color(0xFF152232),
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: const Color(0xFF1E3347))),
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  const Text('Total Payroll', style: TextStyle(
                      fontSize: 11, color: Color(0xFF556677))),
                  const SizedBox(height: 4),
                  Text(
                    alreadyGenerated
                        ? '₹${_totalPayroll.toStringAsFixed(2)}'
                        : '—',
                    style: const TextStyle(fontSize: 20,
                        fontWeight: FontWeight.bold, color: Color(0xFF1DB954))),
                  Text('${_payrolls.length} staff · ${_payrolls.where((p) => p['IsPaid'] == true).length} paid',
                      style: const TextStyle(fontSize: 10, color: Color(0xFF556677))),
                ]))),
              const SizedBox(width: 12),

              // Generate / Already generated
              GestureDetector(
                onTap: alreadyGenerated || _isGenerating ? null : _generatePayroll,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                  decoration: BoxDecoration(
                    color: alreadyGenerated
                        ? const Color(0xFF152232)
                        : const Color(0xFF1DB954).withOpacity(0.12),
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(
                        color: alreadyGenerated
                            ? const Color(0xFF1E3347)
                            : const Color(0xFF1DB954).withOpacity(0.4))),
                  child: _isGenerating
                      ? const SizedBox(width: 20, height: 20,
                          child: CircularProgressIndicator(
                              color: Color(0xFF1DB954), strokeWidth: 2))
                      : Column(mainAxisSize: MainAxisSize.min, children: [
                          Icon(
                            alreadyGenerated
                                ? Icons.check_circle_outline_rounded
                                : Icons.play_circle_outline_rounded,
                            color: alreadyGenerated
                                ? const Color(0xFF1DB954)
                                : const Color(0xFF1DB954),
                            size: 22),
                          const SizedBox(height: 4),
                          Text(
                            alreadyGenerated ? 'Generated' : 'Generate',
                            style: TextStyle(fontSize: 11,
                                fontWeight: FontWeight.w600,
                                color: alreadyGenerated
                                    ? const Color(0xFF556677)
                                    : const Color(0xFF1DB954))),
                        ]))),
              // Delete button (only if generated — allows regeneration after fixing data)
              if (alreadyGenerated) ...[
                const SizedBox(width: 8),
                GestureDetector(
                  onTap: _deleteMonthPayroll,
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
                    decoration: BoxDecoration(
                      color: const Color(0xFFE74C3C).withOpacity(0.08),
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(
                          color: const Color(0xFFE74C3C).withOpacity(0.3))),
                    child: Column(mainAxisSize: MainAxisSize.min, children: [
                      const Icon(Icons.delete_outline_rounded,
                          color: Color(0xFFE74C3C), size: 22),
                      const SizedBox(height: 4),
                      const Text('Delete', style: TextStyle(fontSize: 11,
                          fontWeight: FontWeight.w600,
                          color: Color(0xFFE74C3C))),
                    ]))),
              ],
            ])),

          // Payroll list
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator(
                    color: Color(0xFF1DB954), strokeWidth: 2))
                : RefreshIndicator(
                    onRefresh: _load,
                    color: const Color(0xFF1DB954),
                    backgroundColor: const Color(0xFF152232),
                    child: _payrolls.isEmpty
                        ? _emptyState(alreadyGenerated)
                        : ListView(
                            padding: const EdgeInsets.fromLTRB(20, 0, 20, 100),
                            children: _payrolls.map((p) => _payrollCard(p)).toList()))),
        ])),
      ]),
    );
  }

  Widget _payrollCard(Map<String, dynamic> p) {
    final isPaid      = p['IsPaid'] == true;
    final amount      = (p['PaymentAmount'] as num?)?.toDouble() ?? 0;
    final type        = p['PayrollType'] as String? ?? '';
    final invoiceNo   = p['PayrollInvoiceNo'] as String? ?? '—';
    final staffName   = p['StaffName'] as String? ?? p['StaffEnrollmentNo'] ?? '—';
    final breakdown   = (p['PayrollBreakdown'] as List?)
        ?.map((b) => b as Map<String, dynamic>).toList() ?? [];
    final isPartnership = type == 'Partnership';

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: const Color(0xFF152232),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: isPaid
              ? const Color(0xFF1DB954).withOpacity(0.4)
              : const Color(0xFF1E3347))),
      child: Column(children: [
        // Header
        Padding(padding: const EdgeInsets.all(16), child: Row(children: [
          Container(width: 46, height: 46,
            decoration: BoxDecoration(
              color: isPartnership
                  ? const Color(0xFFE8A020).withOpacity(0.12)
                  : const Color(0xFF5BA3D9).withOpacity(0.12),
              borderRadius: BorderRadius.circular(13)),
            child: Center(child: Text(
              staffName.substring(0, 1).toUpperCase(),
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold,
                  color: isPartnership
                      ? const Color(0xFFE8A020)
                      : const Color(0xFF5BA3D9))))),
          const SizedBox(width: 12),
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(staffName, style: const TextStyle(fontSize: 15,
                fontWeight: FontWeight.w600, color: Colors.white)),
            Row(children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: isPartnership
                      ? const Color(0xFFE8A020).withOpacity(0.1)
                      : const Color(0xFF5BA3D9).withOpacity(0.1),
                  borderRadius: BorderRadius.circular(4)),
                child: Text(type, style: TextStyle(fontSize: 9,
                    color: isPartnership
                        ? const Color(0xFFE8A020)
                        : const Color(0xFF5BA3D9)))),
              const SizedBox(width: 6),
              Text(invoiceNo, style: const TextStyle(
                  fontSize: 10, color: Color(0xFF556677))),
            ]),
          ])),
          Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
            Text('₹${amount.toStringAsFixed(2)}',
                style: const TextStyle(fontSize: 16,
                    fontWeight: FontWeight.bold, color: Colors.white)),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
              decoration: BoxDecoration(
                color: isPaid
                    ? const Color(0xFF1DB954).withOpacity(0.12)
                    : const Color(0xFFE74C3C).withOpacity(0.1),
                borderRadius: BorderRadius.circular(5)),
              child: Text(isPaid ? 'Paid' : 'Pending',
                  style: TextStyle(fontSize: 9, fontWeight: FontWeight.w600,
                      color: isPaid
                          ? const Color(0xFF1DB954)
                          : const Color(0xFFE74C3C)))),
          ]),
        ])),

        // Partnership breakdown
        if (isPartnership && breakdown.isNotEmpty) ...[
          Container(
            margin: const EdgeInsets.fromLTRB(12, 0, 12, 0),
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
                color: const Color(0xFF0D1B2A),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: const Color(0xFF1E3347))),
            child: Column(children: [
              // Header row
              const Row(children: [
                Expanded(flex: 3, child: Text('Batch', style: TextStyle(
                    fontSize: 10, color: Color(0xFF556677), fontWeight: FontWeight.w500))),
                Expanded(flex: 1, child: Text('Std', style: TextStyle(
                    fontSize: 10, color: Color(0xFF556677)), textAlign: TextAlign.center)),
                Expanded(flex: 2, child: Text('Revenue', style: TextStyle(
                    fontSize: 10, color: Color(0xFF556677)), textAlign: TextAlign.right)),
                Expanded(flex: 2, child: Text('Earning', style: TextStyle(
                    fontSize: 10, color: Color(0xFF556677)), textAlign: TextAlign.right)),
              ]),
              const Divider(color: Color(0xFF1E3347), height: 10),
              ...breakdown.map((b) => Padding(
                padding: const EdgeInsets.symmetric(vertical: 4),
                child: Row(children: [
                  Expanded(flex: 3, child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Text(b['CourseName'] ?? '—', style: const TextStyle(
                        fontSize: 11, color: Colors.white, fontWeight: FontWeight.w500),
                        overflow: TextOverflow.ellipsis),
                    Text(b['BatchName'] ?? '—', style: const TextStyle(
                        fontSize: 9, color: Color(0xFF556677))),
                  ])),
                  Expanded(flex: 1, child: Text(
                    '${b['StudentCount'] ?? 0}',
                    style: const TextStyle(fontSize: 11, color: Color(0xFF8899AA)),
                    textAlign: TextAlign.center)),
                  Expanded(flex: 2, child: Text(
                    '₹${(b['Revenue'] as num?)?.toStringAsFixed(0) ?? '0'}',
                    style: const TextStyle(fontSize: 11, color: Color(0xFF8899AA)),
                    textAlign: TextAlign.right)),
                  Expanded(flex: 2, child: Text(
                    '₹${(b['StaffAmount'] as num?)?.toStringAsFixed(2) ?? '0'}',
                    style: const TextStyle(fontSize: 11,
                        color: Color(0xFF1DB954), fontWeight: FontWeight.w600),
                    textAlign: TextAlign.right)),
                ]))),
              const Divider(color: Color(0xFF1E3347), height: 10),
              Row(children: [
                Expanded(child: Text(
                  '${(breakdown.first['SharePercent'] as num?)?.toStringAsFixed(0) ?? '?'}% share',
                  style: const TextStyle(fontSize: 10, color: Color(0xFF556677)))),
                Text('Total: ₹${amount.toStringAsFixed(2)}',
                    style: const TextStyle(fontSize: 12,
                        fontWeight: FontWeight.bold, color: Color(0xFF1DB954))),
              ]),
            ])),
          const SizedBox(height: 8),
        ],

        // Action footer
        Container(
          padding: const EdgeInsets.fromLTRB(12, 8, 12, 10),
          decoration: const BoxDecoration(
              border: Border(top: BorderSide(color: Color(0xFF1E3347), width: 1))),
          child: Row(children: [
            if (isPaid) ...[
              const Icon(Icons.check_circle_rounded,
                  color: Color(0xFF1DB954), size: 14),
              const SizedBox(width: 6),
              Text(_formatDate((p['DateOfPayment'] as Timestamp?)?.toDate()),
                  style: const TextStyle(fontSize: 11, color: Color(0xFF556677))),
            ] else ...[
              const Icon(Icons.pending_outlined,
                  color: Color(0xFF556677), size: 14),
              const SizedBox(width: 6),
              const Text('Payment pending',
                  style: TextStyle(fontSize: 11, color: Color(0xFF556677))),
            ],
            const Spacer(),
            GestureDetector(
              onTap: () => _markPaid(p, isPaid),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: isPaid
                      ? const Color(0xFFE74C3C).withOpacity(0.08)
                      : const Color(0xFF1DB954).withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(
                      color: isPaid
                          ? const Color(0xFFE74C3C).withOpacity(0.3)
                          : const Color(0xFF1DB954).withOpacity(0.3))),
                child: Text(isPaid ? 'Revert' : 'Mark Paid',
                    style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600,
                        color: isPaid
                            ? const Color(0xFFE74C3C)
                            : const Color(0xFF1DB954))))),
          ])),
      ]));
  }

  // ── Generation summary dialog ──────────────────────────────────────────────
  void _showGenerationSummary(int processed, int skipped,
      List<Map<String, dynamic>> results) {
    final total = results.fold<double>(
        0, (sum, r) => sum + ((r['Amount'] as num?)?.toDouble() ?? 0));

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF152232),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text('Payroll Generated!',
            style: TextStyle(color: Colors.white, fontFamily: 'Georgia')),
        content: SizedBox(
          width: double.maxFinite,
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            // Summary stats
            Row(children: [
              _summaryChip('${processed}', 'Processed',
                  const Color(0xFF1DB954)),
              const SizedBox(width: 8),
              if (skipped > 0)
                _summaryChip('$skipped', 'Skipped',
                    const Color(0xFFE8A020)),
              const SizedBox(width: 8),
              _summaryChip('₹${total.toStringAsFixed(0)}',
                  'Total', const Color(0xFF5BA3D9)),
            ]),
            const SizedBox(height: 16),

            // Staff-wise list
            ConstrainedBox(
              constraints: const BoxConstraints(maxHeight: 280),
              child: ListView.builder(
                shrinkWrap: true,
                itemCount: results.length,
                itemBuilder: (_, i) {
                  final r = results[i];
                  final amt = (r['Amount'] as num?)?.toDouble() ?? 0;
                  final isPartnership = r['Type'] == 'Partnership';
                  return Container(
                    margin: const EdgeInsets.only(bottom: 8),
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                        color: const Color(0xFF0D1B2A),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: const Color(0xFF1E3347))),
                    child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                      Row(children: [
                        Expanded(child: Text(r['StaffName'] ?? '',
                            style: const TextStyle(fontSize: 13,
                                fontWeight: FontWeight.w600,
                                color: Colors.white))),
                        Text('₹${amt.toStringAsFixed(2)}',
                            style: const TextStyle(fontSize: 13,
                                fontWeight: FontWeight.bold,
                                color: Color(0xFF1DB954))),
                      ]),
                      const SizedBox(height: 2),
                      Row(children: [
                        Text(r['InvoiceNo'] ?? '',
                            style: const TextStyle(fontSize: 10,
                                color: Color(0xFF556677))),
                        const SizedBox(width: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 6, vertical: 1),
                          decoration: BoxDecoration(
                              color: isPartnership
                                  ? const Color(0xFFE8A020).withOpacity(0.1)
                                  : const Color(0xFF5BA3D9).withOpacity(0.1),
                              borderRadius: BorderRadius.circular(4)),
                          child: Text(r['Type'] ?? '',
                              style: TextStyle(fontSize: 9,
                                  color: isPartnership
                                      ? const Color(0xFFE8A020)
                                      : const Color(0xFF5BA3D9)))),
                      ]),

                      // Breakdown for partnership
                      if (isPartnership &&
                          (r['Breakdown'] as List?)?.isNotEmpty == true) ...[
                        const SizedBox(height: 8),
                        ...(r['Breakdown'] as List)
                            .cast<Map<String, dynamic>>()
                            .map((b) => Padding(
                          padding: const EdgeInsets.only(bottom: 3),
                          child: Row(children: [
                            const Icon(Icons.subdirectory_arrow_right_rounded,
                                color: Color(0xFF3A5068), size: 12),
                            const SizedBox(width: 4),
                            Expanded(child: Text(
                                '${b['CourseName']} (${b['BatchName']}) · '
                                '${b['StudentCount']} students',
                                style: const TextStyle(fontSize: 10,
                                    color: Color(0xFF8899AA)),
                                overflow: TextOverflow.ellipsis)),
                            Text('₹${(b['StaffAmount'] as num?)?.toStringAsFixed(2) ?? '0'}',
                                style: const TextStyle(fontSize: 10,
                                    color: Color(0xFF1DB954))),
                          ]))),
                      ],
                    ]));
                })),

            if (skipped > 0) ...[
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                    color: const Color(0xFFE8A020).withOpacity(0.08),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(
                        color: const Color(0xFFE8A020).withOpacity(0.3))),
                child: Row(children: [
                  const Icon(Icons.warning_amber_rounded,
                      color: Color(0xFFE8A020), size: 14),
                  const SizedBox(width: 8),
                  Expanded(child: Text(
                    '$skipped staff skipped due to invalid payroll config '
                    'or zero students.',
                    style: const TextStyle(fontSize: 11,
                        color: Color(0xFFE8A020), height: 1.4))),
                ])),
            ],
          ]),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Close',
                style: TextStyle(color: Color(0xFF1DB954),
                    fontWeight: FontWeight.w600))),
        ],
      ),
    );
  }

  Widget _summaryChip(String value, String label, Color color) =>
    Expanded(child: Container(
      padding: const EdgeInsets.symmetric(vertical: 10),
      decoration: BoxDecoration(color: color.withOpacity(0.1),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: color.withOpacity(0.3))),
      child: Column(children: [
        Text(value, style: TextStyle(fontSize: 16,
            fontWeight: FontWeight.bold, color: color)),
        Text(label, style: const TextStyle(
            fontSize: 10, color: Color(0xFF8899AA))),
      ])));

  Widget _emptyState(bool generated) => ListView(
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
        Text(generated
            ? 'No payroll records'
            : 'No payroll generated',
            style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w600,
                color: Colors.white, fontFamily: 'Georgia')),
        const SizedBox(height: 8),
        Text(
          generated
              ? 'No staff processed for $_monthDisplay.'
              : 'Tap "Generate" to calculate\n$_monthDisplay payroll for all staff.',
          textAlign: TextAlign.center,
          style: const TextStyle(fontSize: 13,
              color: Color(0xFF556677), height: 1.5)),
      ])),
    ]);

  String _formatDate(DateTime? dt) {
    if (dt == null) return '';
    const months = ['Jan','Feb','Mar','Apr','May','Jun',
        'Jul','Aug','Sep','Oct','Nov','Dec'];
    return '${dt.day} ${months[dt.month - 1]} ${dt.year}';
  }

  void _showSnack(String msg, {bool ok = false}) =>
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(msg,
          style: const TextStyle(color: Colors.white, fontSize: 14)),
      backgroundColor:
          ok ? const Color(0xFF2ECC71) : const Color(0xFFE74C3C),
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