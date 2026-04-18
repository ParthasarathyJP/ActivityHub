import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';

// ══════════════════════════════════════════════════════════════════════════════
// Revenue Screen — Monthly Income & Expenditure Balance Sheet
// ══════════════════════════════════════════════════════════════════════════════
class RevenueScreen extends StatefulWidget {
  final String clientId;
  final String branchId;
  final String clientName;

  const RevenueScreen({
    super.key,
    required this.clientId,
    required this.branchId,
    this.clientName = '',
  });

  @override
  State<RevenueScreen> createState() => _RevenueScreenState();
}

class _RevenueScreenState extends State<RevenueScreen> {
  late DateTime _selectedMonth;
  bool _isLoading   = false;
  bool _isExporting = false;

  // ── Data ───────────────────────────────────────────────────────────────────
  List<Map<String, dynamic>> _fees     = [];
  List<Map<String, dynamic>> _payrolls = [];
  List<Map<String, dynamic>> _students = [];
  List<Map<String, dynamic>> _courses  = [];
  List<Map<String, dynamic>> _courseSchedules = [];
  List<Map<String, dynamic>> _stuSchedules    = [];

  // ── Totals ─────────────────────────────────────────────────────────────────
  double get _totalRevenue  => _fees.fold(0, (s, f) => s + ((f['GrandTotal'] as num?)?.toDouble() ?? 0));
  double get _totalExpense  => _payrolls.fold(0, (s, p) => s + ((p['PaymentAmount'] as num?)?.toDouble() ?? 0));
  double get _netProfit     => _totalRevenue - _totalExpense;
  double get _marginPct     => _totalRevenue > 0 ? (_netProfit / _totalRevenue) * 100 : 0;

  // ── Expand state ───────────────────────────────────────────────────────────
  bool _incomeExpanded  = true;
  bool _expenseExpanded = true;

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

  void _prevMonth() { setState(() => _selectedMonth = DateTime(_selectedMonth.year, _selectedMonth.month - 1)); _load(); }
  void _nextMonth()  {
    final now = DateTime.now();
    if (_selectedMonth.year == now.year && _selectedMonth.month == now.month) return;
    setState(() => _selectedMonth = DateTime(_selectedMonth.year, _selectedMonth.month + 1));
    _load();
  }

  Future<void> _load() async {
    setState(() => _isLoading = true);
    try {
      final db   = FirebaseFirestore.instance;
      // Date range for the selected month
      final from = DateTime(_selectedMonth.year, _selectedMonth.month, 1);
      final to   = DateTime(_selectedMonth.year, _selectedMonth.month + 1, 1);

      final results = await Future.wait([
        // Fees collected in this month (by DateOfPayment)
        db.collection('StudentFee')
            .where('ClientID', isEqualTo: widget.clientId)
            .where('DateOfPayment', isGreaterThanOrEqualTo: Timestamp.fromDate(from))
            .where('DateOfPayment', isLessThan: Timestamp.fromDate(to))
            .get(),
        // Payroll generated for this month
        db.collection('PayrollTransactions')
            .where('ClientID', isEqualTo: widget.clientId)
            .where('PayrollMonth', isEqualTo: _monthKey)
            .get(),
        // Supporting data for display
        db.collection('Student').where('ClientID', isEqualTo: widget.clientId).get(),
        db.collection('Course').where('ClientID', isEqualTo: widget.clientId).get(),
        db.collection('CourseSchedule').where('ClientID', isEqualTo: widget.clientId).get(),
        db.collection('StudentCourseSchedule').where('ClientID', isEqualTo: widget.clientId).get(),
      ]);

      if (mounted) setState(() {
        _fees            = (results[0] as QuerySnapshot).docs.map((d) => {...(d.data() as Map<String,dynamic>), 'DocID': d.id}).toList();
        _payrolls        = (results[1] as QuerySnapshot).docs.map((d) => {...(d.data() as Map<String,dynamic>), 'DocID': d.id}).toList();
        _students        = (results[2] as QuerySnapshot).docs.map((d) => {...(d.data() as Map<String,dynamic>), 'DocID': d.id}).toList();
        _courses         = (results[3] as QuerySnapshot).docs.map((d) => {...(d.data() as Map<String,dynamic>), 'DocID': d.id}).toList();
        _courseSchedules = (results[4] as QuerySnapshot).docs.map((d) => {...(d.data() as Map<String,dynamic>), 'DocID': d.id}).toList();
        _stuSchedules    = (results[5] as QuerySnapshot).docs.map((d) => {...(d.data() as Map<String,dynamic>), 'DocID': d.id}).toList();
        _isLoading       = false;
      });
    } catch (e) {
      debugPrint('Revenue load error: $e');
      if (mounted) setState(() => _isLoading = false);
    }
  }

  // ── Lookups ────────────────────────────────────────────────────────────────
  String _studentName(String? enrollNo) {
    if (enrollNo == null) return '—';
    final s = _students.firstWhere((s) => s['StudentEnrollmentNo'] == enrollNo, orElse: () => {});
    return s['Name'] as String? ?? enrollNo;
  }

  String _courseNameFromStudentScheduleId(String? ssId) {
    if (ssId == null) return '—';
    final ss  = _stuSchedules.firstWhere((s) => s['DocID'] == ssId, orElse: () => {});
    final cs  = _courseSchedules.firstWhere((c) => c['DocID'] == ss['CourseScheduleID'], orElse: () => {});
    final c   = _courses.firstWhere((c) => c['DocID'] == cs['CourseID'], orElse: () => {});
    return c['CourseName'] as String? ?? '—';
  }

  String _formatDate(Timestamp? ts) {
    if (ts == null) return '—';
    final dt = ts.toDate();
    const months = ['Jan','Feb','Mar','Apr','May','Jun','Jul','Aug','Sep','Oct','Nov','Dec'];
    return '${dt.day} ${months[dt.month - 1]}';
  }

  @override
  Widget build(BuildContext context) {
    final isProfit = _netProfit >= 0;

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
                Text('Revenue', style: TextStyle(fontFamily: 'Georgia',
                    fontSize: 20, fontWeight: FontWeight.bold, color: Colors.white)),
                Text('Income & Expenditure', style: TextStyle(
                    fontSize: 12, color: Color(0xFF556677))),
              ])),
              // Export PDF button
              GestureDetector(
                onTap: (_fees.isEmpty && _payrolls.isEmpty) ? null : _exportPdf,
                child: Container(
                  width: 40, height: 40,
                  decoration: BoxDecoration(
                    color: (_fees.isEmpty && _payrolls.isEmpty)
                        ? const Color(0xFF1E3347)
                        : const Color(0xFF5BA3D9).withOpacity(0.12),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: (_fees.isEmpty && _payrolls.isEmpty)
                          ? const Color(0xFF1E3347)
                          : const Color(0xFF5BA3D9).withOpacity(0.3))),
                  child: _isExporting
                      ? const Padding(padding: EdgeInsets.all(10),
                          child: CircularProgressIndicator(
                              color: Color(0xFF5BA3D9), strokeWidth: 2))
                      : Icon(Icons.picture_as_pdf_outlined,
                          color: (_fees.isEmpty && _payrolls.isEmpty)
                              ? const Color(0xFF3A5068)
                              : const Color(0xFF5BA3D9),
                          size: 20))),
            ])),

          // Month selector
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 0, 20, 12),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(color: const Color(0xFF152232),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: const Color(0xFF1E3347))),
              child: Row(children: [
                GestureDetector(onTap: _prevMonth,
                  child: Container(width: 36, height: 36,
                    decoration: BoxDecoration(color: const Color(0xFF0D1B2A),
                        borderRadius: BorderRadius.circular(10)),
                    child: const Icon(Icons.chevron_left_rounded,
                        color: Color(0xFF8899AA), size: 22))),
                Expanded(child: Center(child: Text(_monthDisplay,
                    style: const TextStyle(fontSize: 16,
                        fontWeight: FontWeight.w600, color: Colors.white)))),
                GestureDetector(onTap: _nextMonth,
                  child: Container(width: 36, height: 36,
                    decoration: BoxDecoration(color: const Color(0xFF0D1B2A),
                        borderRadius: BorderRadius.circular(10)),
                    child: const Icon(Icons.chevron_right_rounded,
                        color: Color(0xFF8899AA), size: 22))),
              ])),
          ),

          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator(
                    color: Color(0xFF1DB954), strokeWidth: 2))
                : RefreshIndicator(
                    onRefresh: _load,
                    color: const Color(0xFF1DB954),
                    backgroundColor: const Color(0xFF152232),
                    child: ListView(
                      padding: const EdgeInsets.fromLTRB(20, 0, 20, 100),
                      children: [
                        // ── Summary card ──────────────────────────────────
                        _buildSummaryCard(isProfit),
                        const SizedBox(height: 16),

                        // ── Income section ────────────────────────────────
                        _sectionHeader(
                          'Income',
                          '₹${_totalRevenue.toStringAsFixed(2)}',
                          Icons.arrow_downward_rounded,
                          const Color(0xFF1DB954),
                          _incomeExpanded,
                          () => setState(() => _incomeExpanded = !_incomeExpanded),
                          count: _fees.length),
                        if (_incomeExpanded) ...[
                          const SizedBox(height: 8),
                          if (_fees.isEmpty)
                            _emptySection('No fees collected this month')
                          else
                            ..._fees.map((f) => _feeRow(f)),
                        ],
                        const SizedBox(height: 16),

                        // ── Expenditure section ───────────────────────────
                        _sectionHeader(
                          'Expenditure',
                          '₹${_totalExpense.toStringAsFixed(2)}',
                          Icons.arrow_upward_rounded,
                          const Color(0xFFE74C3C),
                          _expenseExpanded,
                          () => setState(() => _expenseExpanded = !_expenseExpanded),
                          count: _payrolls.length),
                        if (_expenseExpanded) ...[
                          const SizedBox(height: 8),
                          if (_payrolls.isEmpty)
                            _emptySection('No payroll generated this month')
                          else
                            ..._payrolls.map((p) => _payrollRow(p)),
                        ],
                        const SizedBox(height: 16),

                        // ── Net result ────────────────────────────────────
                        _buildNetCard(isProfit),
                      ],
                    ))),
        ])),
      ]),
    );
  }

  // ── Summary card ───────────────────────────────────────────────────────────
  Widget _buildSummaryCard(bool isProfit) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: isProfit
              ? [const Color(0xFF1A3A2A), const Color(0xFF152232)]
              : [const Color(0xFF3A1A1A), const Color(0xFF152232)],
          begin: Alignment.topLeft, end: Alignment.bottomRight),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: isProfit
              ? const Color(0xFF1DB954).withOpacity(0.3)
              : const Color(0xFFE74C3C).withOpacity(0.3))),
      child: Column(children: [
        Row(children: [
          Container(width: 40, height: 40,
            decoration: BoxDecoration(
              color: isProfit
                  ? const Color(0xFF1DB954).withOpacity(0.15)
                  : const Color(0xFFE74C3C).withOpacity(0.15),
              borderRadius: BorderRadius.circular(12)),
            child: Icon(
              isProfit ? Icons.trending_up_rounded : Icons.trending_down_rounded,
              color: isProfit ? const Color(0xFF1DB954) : const Color(0xFFE74C3C),
              size: 22)),
          const SizedBox(width: 12),
          Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(_monthDisplay, style: const TextStyle(
                fontSize: 12, color: Color(0xFF8899AA))),
            const Text('Balance Sheet', style: TextStyle(
                fontSize: 15, fontWeight: FontWeight.w600, color: Colors.white)),
          ]),
          const Spacer(),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            decoration: BoxDecoration(
              color: isProfit
                  ? const Color(0xFF1DB954).withOpacity(0.15)
                  : const Color(0xFFE74C3C).withOpacity(0.15),
              borderRadius: BorderRadius.circular(8)),
            child: Text(
              '${_marginPct.toStringAsFixed(1)}% margin',
              style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600,
                  color: isProfit ? const Color(0xFF1DB954) : const Color(0xFFE74C3C)))),
        ]),
        const SizedBox(height: 16),
        const Divider(color: Color(0xFF1E3347), height: 1),
        const SizedBox(height: 16),
        Row(children: [
          _summaryItem('Revenue', _totalRevenue, const Color(0xFF1DB954), Icons.south_rounded),
          _vertDivider(),
          _summaryItem('Expense', _totalExpense, const Color(0xFFE74C3C), Icons.north_rounded),
          _vertDivider(),
          _summaryItem(
            isProfit ? 'Profit' : 'Loss',
            _netProfit.abs(),
            isProfit ? const Color(0xFF1DB954) : const Color(0xFFE74C3C),
            isProfit ? Icons.add_rounded : Icons.remove_rounded),
        ]),
      ]));
  }

  Widget _summaryItem(String label, double amount, Color color, IconData icon) {
    return Expanded(child: Column(children: [
      Icon(icon, color: color, size: 14),
      const SizedBox(height: 4),
      Text('₹${_compactAmount(amount)}',
          style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: color)),
      Text(label, style: const TextStyle(fontSize: 10, color: Color(0xFF556677))),
    ]));
  }

  Widget _vertDivider() => Container(
      width: 1, height: 40, color: const Color(0xFF1E3347));

  String _compactAmount(double amount) {
    if (amount >= 100000) return '${(amount / 100000).toStringAsFixed(1)}L';
    if (amount >= 1000)   return '${(amount / 1000).toStringAsFixed(1)}K';
    return amount.toStringAsFixed(0);
  }

  // ── Section header ─────────────────────────────────────────────────────────
  Widget _sectionHeader(String title, String total, IconData icon,
      Color color, bool expanded, VoidCallback onTap, {int count = 0}) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: const Color(0xFF152232),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: color.withOpacity(0.25))),
        child: Row(children: [
          Container(width: 32, height: 32,
            decoration: BoxDecoration(
                color: color.withOpacity(0.12),
                borderRadius: BorderRadius.circular(9)),
            child: Icon(icon, color: color, size: 16)),
          const SizedBox(width: 10),
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(title, style: const TextStyle(fontSize: 14,
                fontWeight: FontWeight.w600, color: Colors.white)),
            Text('$count ${count == 1 ? "transaction" : "transactions"}',
                style: const TextStyle(fontSize: 10, color: Color(0xFF556677))),
          ])),
          Text(total, style: TextStyle(fontSize: 15,
              fontWeight: FontWeight.bold, color: color)),
          const SizedBox(width: 8),
          Icon(expanded ? Icons.keyboard_arrow_up_rounded
              : Icons.keyboard_arrow_down_rounded,
              color: const Color(0xFF556677), size: 20),
        ])));
  }

  // ── Fee row ────────────────────────────────────────────────────────────────
  Widget _feeRow(Map<String, dynamic> f) {
    final student     = _studentName(f['StudentEnrollmentNo']);
    final course      = _courseNameFromStudentScheduleId(f['StudentCourseScheduleID']);
    final amount      = (f['GrandTotal'] as num?)?.toDouble() ?? 0;
    final receipt     = f['ReceiptNumber'] as String? ?? '—';
    final date        = _formatDate(f['DateOfPayment'] as Timestamp?);
    final mode        = f['PaymentMode'] as String? ?? 'Cash';
    final isGateway   = mode == 'Payment Gateway';

    return Container(
      margin: const EdgeInsets.only(bottom: 6),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: const Color(0xFF0D1B2A),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFF1E3347))),
      child: Row(children: [
        Container(width: 8, height: 8,
          decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: const Color(0xFF1DB954).withOpacity(0.6))),
        const SizedBox(width: 10),
        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(student, style: const TextStyle(fontSize: 13,
              fontWeight: FontWeight.w500, color: Colors.white)),
          Row(children: [
            Text(course, style: const TextStyle(fontSize: 10, color: Color(0xFF556677))),
            const SizedBox(width: 6),
            Text('· $receipt', style: const TextStyle(fontSize: 10, color: Color(0xFF3A5068))),
          ]),
        ])),
        Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
          Text('₹${amount.toStringAsFixed(2)}',
              style: const TextStyle(fontSize: 13,
                  fontWeight: FontWeight.w600, color: Color(0xFF1DB954))),
          Row(children: [
            Text(date, style: const TextStyle(fontSize: 10, color: Color(0xFF556677))),
            const SizedBox(width: 4),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
              decoration: BoxDecoration(
                color: isGateway
                    ? const Color(0xFF7F77DD).withOpacity(0.1)
                    : const Color(0xFF1DB954).withOpacity(0.08),
                borderRadius: BorderRadius.circular(4)),
              child: Text(isGateway ? 'GW' : 'Cash',
                  style: TextStyle(fontSize: 9,
                      color: isGateway
                          ? const Color(0xFF7F77DD)
                          : const Color(0xFF1DB954)))),
          ]),
        ]),
      ]));
  }

  // ── Payroll row ────────────────────────────────────────────────────────────
  Widget _payrollRow(Map<String, dynamic> p) {
    final name     = p['StaffName'] as String? ?? p['StaffEnrollmentNo'] ?? '—';
    final type     = p['PayrollType'] as String? ?? '—';
    final amount   = (p['PaymentAmount'] as num?)?.toDouble() ?? 0;
    final invoice  = p['PayrollInvoiceNo'] as String? ?? '—';
    final isPaid   = p['IsPaid'] == true;
    final isFixed  = type == 'Monthly Fixed';

    return Container(
      margin: const EdgeInsets.only(bottom: 6),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: const Color(0xFF0D1B2A),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFF1E3347))),
      child: Row(children: [
        Container(width: 8, height: 8,
          decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: const Color(0xFFE74C3C).withOpacity(0.6))),
        const SizedBox(width: 10),
        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(name, style: const TextStyle(fontSize: 13,
              fontWeight: FontWeight.w500, color: Colors.white)),
          Row(children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
              decoration: BoxDecoration(
                color: isFixed
                    ? const Color(0xFF5BA3D9).withOpacity(0.1)
                    : const Color(0xFFE8A020).withOpacity(0.1),
                borderRadius: BorderRadius.circular(4)),
              child: Text(type, style: TextStyle(fontSize: 9,
                  color: isFixed
                      ? const Color(0xFF5BA3D9)
                      : const Color(0xFFE8A020)))),
            const SizedBox(width: 6),
            Text('· $invoice', style: const TextStyle(fontSize: 10, color: Color(0xFF3A5068))),
          ]),
        ])),
        Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
          Text('₹${amount.toStringAsFixed(2)}',
              style: const TextStyle(fontSize: 13,
                  fontWeight: FontWeight.w600, color: Color(0xFFE74C3C))),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
            decoration: BoxDecoration(
              color: isPaid
                  ? const Color(0xFF1DB954).withOpacity(0.08)
                  : const Color(0xFFE74C3C).withOpacity(0.08),
              borderRadius: BorderRadius.circular(4)),
            child: Text(isPaid ? 'Paid' : 'Pending',
                style: TextStyle(fontSize: 9,
                    color: isPaid
                        ? const Color(0xFF1DB954)
                        : const Color(0xFFE74C3C)))),
        ]),
      ]));
  }

  // ── Net profit/loss card ───────────────────────────────────────────────────
  Widget _buildNetCard(bool isProfit) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: const Color(0xFF152232),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isProfit
              ? const Color(0xFF1DB954).withOpacity(0.4)
              : const Color(0xFFE74C3C).withOpacity(0.4),
          width: 1.5)),
      child: Column(children: [
        Row(children: [
          Text(isProfit ? 'Net Profit' : 'Net Loss',
              style: const TextStyle(fontSize: 14,
                  fontWeight: FontWeight.w600, color: Colors.white)),
          const Spacer(),
          Text('₹${_netProfit.abs().toStringAsFixed(2)}',
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold,
                  color: isProfit ? const Color(0xFF1DB954) : const Color(0xFFE74C3C))),
        ]),
        const SizedBox(height: 12),
        // Progress bar
        ClipRRect(
          borderRadius: BorderRadius.circular(4),
          child: Stack(children: [
            Container(height: 8, color: const Color(0xFF0D1B2A)),
            FractionallySizedBox(
              widthFactor: _totalRevenue > 0
                  ? (_totalExpense / _totalRevenue).clamp(0.0, 1.0)
                  : 0,
              child: Container(height: 8,
                  decoration: BoxDecoration(
                    color: const Color(0xFFE74C3C).withOpacity(0.7),
                    borderRadius: BorderRadius.circular(4)))),
          ])),
        const SizedBox(height: 8),
        Row(children: [
          _dotLabel('Revenue', const Color(0xFF1DB954)),
          const SizedBox(width: 16),
          _dotLabel('Expense', const Color(0xFFE74C3C)),
          const Spacer(),
          Text('Margin: ${_marginPct.toStringAsFixed(1)}%',
              style: TextStyle(fontSize: 11,
                  color: isProfit ? const Color(0xFF1DB954) : const Color(0xFFE74C3C),
                  fontWeight: FontWeight.w600)),
        ]),
      ]));
  }

  Widget _dotLabel(String label, Color color) => Row(children: [
    Container(width: 8, height: 8, decoration: BoxDecoration(shape: BoxShape.circle, color: color)),
    const SizedBox(width: 4),
    Text(label, style: const TextStyle(fontSize: 10, color: Color(0xFF8899AA))),
  ]);

  Widget _emptySection(String msg) => Container(
    margin: const EdgeInsets.only(bottom: 6),
    padding: const EdgeInsets.all(14),
    decoration: BoxDecoration(color: const Color(0xFF0D1B2A),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFF1E3347))),
    child: Center(child: Text(msg,
        style: const TextStyle(fontSize: 12, color: Color(0xFF3A5068)))));

  // ══════════════════════════════════════════════════════════════════════════
  // PDF Export
  // ══════════════════════════════════════════════════════════════════════════
  Future<void> _exportPdf() async {
    setState(() => _isExporting = true);
    try {
      final pdfBytes = await _generatePdf();
      await Printing.sharePdf(
          bytes: pdfBytes,
          filename: 'Revenue_${_monthKey}_${widget.clientName.replaceAll(' ', '_')}.pdf');
    } catch (e) {
      _showSnack('PDF export failed: $e');
    } finally {
      if (mounted) setState(() => _isExporting = false);
    }
  }

  Future<Uint8List> _generatePdf() async {
    final pdf      = pw.Document();
    final isProfit = _netProfit >= 0;
    final green    = PdfColors.green700;
    final red      = PdfColors.red700;
    final dark     = PdfColors.grey800;
    final light    = PdfColors.grey200;

    pdf.addPage(pw.MultiPage(
      pageFormat: PdfPageFormat.a4,
      margin: const pw.EdgeInsets.all(32),
      build: (ctx) => [
        // Header
        pw.Container(
          padding: const pw.EdgeInsets.all(16),
          decoration: pw.BoxDecoration(
              color: PdfColors.grey900,
              borderRadius: pw.BorderRadius.circular(8)),
          child: pw.Column(crossAxisAlignment: pw.CrossAxisAlignment.start, children: [
            pw.Text(widget.clientName.isNotEmpty ? widget.clientName : 'ActivityHub',
                style: pw.TextStyle(fontSize: 20, fontWeight: pw.FontWeight.bold,
                    color: PdfColors.white)),
            pw.SizedBox(height: 4),
            pw.Text('Income & Expenditure Statement — $_monthDisplay',
                style: pw.TextStyle(fontSize: 12, color: PdfColors.grey400)),
            pw.SizedBox(height: 4),
            pw.Text('Generated on ${DateTime.now().day}/${DateTime.now().month}/${DateTime.now().year}',
                style: pw.TextStyle(fontSize: 10, color: PdfColors.grey500)),
          ])),
        pw.SizedBox(height: 20),

        // Summary row
        pw.Row(children: [
          _pdfSummaryBox('Total Revenue', '₹${_totalRevenue.toStringAsFixed(2)}', green),
          pw.SizedBox(width: 8),
          _pdfSummaryBox('Total Expense', '₹${_totalExpense.toStringAsFixed(2)}', red),
          pw.SizedBox(width: 8),
          _pdfSummaryBox(isProfit ? 'Net Profit' : 'Net Loss',
              '₹${_netProfit.abs().toStringAsFixed(2)}',
              isProfit ? green : red),
          pw.SizedBox(width: 8),
          _pdfSummaryBox('Profit Margin', '${_marginPct.toStringAsFixed(1)}%',
              isProfit ? green : red),
        ]),
        pw.SizedBox(height: 20),

        // Income table
        pw.Text('INCOME — Fee Collections',
            style: pw.TextStyle(fontSize: 13, fontWeight: pw.FontWeight.bold, color: dark)),
        pw.SizedBox(height: 8),
        if (_fees.isEmpty)
          pw.Text('No fees collected this month.',
              style: pw.TextStyle(color: PdfColors.grey600, fontSize: 11))
        else ...[
          pw.TableHelper.fromTextArray(
            headers: ['Receipt', 'Student', 'Course', 'Mode', 'Date', 'Amount'],
            headerStyle: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 10, color: PdfColors.white),
            headerDecoration: pw.BoxDecoration(color: PdfColors.grey800),
            cellStyle: pw.TextStyle(fontSize: 9),
            cellAlignments: {5: pw.Alignment.centerRight},
            data: _fees.map((f) {
              final student = _studentName(f['StudentEnrollmentNo']);
              final course  = _courseNameFromStudentScheduleId(f['StudentCourseScheduleID']);
              final amount  = (f['GrandTotal'] as num?)?.toDouble() ?? 0;
              final receipt = f['ReceiptNumber'] as String? ?? '—';
              final date    = _formatDate(f['DateOfPayment'] as Timestamp?);
              final mode    = f['PaymentMode'] as String? ?? 'Cash';
              return [receipt, student, course, mode, date, '₹${amount.toStringAsFixed(2)}'];
            }).toList(),
          ),
          pw.SizedBox(height: 4),
          pw.Align(alignment: pw.Alignment.centerRight,
            child: pw.Text('Total Income: ₹${_totalRevenue.toStringAsFixed(2)}',
                style: pw.TextStyle(fontWeight: pw.FontWeight.bold,
                    color: green, fontSize: 11))),
        ],
        pw.SizedBox(height: 20),

        // Expenditure table
        pw.Text('EXPENDITURE — Staff Payroll',
            style: pw.TextStyle(fontSize: 13, fontWeight: pw.FontWeight.bold, color: dark)),
        pw.SizedBox(height: 8),
        if (_payrolls.isEmpty)
          pw.Text('No payroll generated this month.',
              style: pw.TextStyle(color: PdfColors.grey600, fontSize: 11))
        else ...[
          pw.TableHelper.fromTextArray(
            headers: ['Invoice', 'Staff', 'Type', 'Status', 'Amount'],
            headerStyle: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 10, color: PdfColors.white),
            headerDecoration: pw.BoxDecoration(color: PdfColors.grey800),
            cellStyle: pw.TextStyle(fontSize: 9),
            cellAlignments: {4: pw.Alignment.centerRight},
            data: _payrolls.map((p) {
              final name    = p['StaffName'] as String? ?? '—';
              final type    = p['PayrollType'] as String? ?? '—';
              final amount  = (p['PaymentAmount'] as num?)?.toDouble() ?? 0;
              final invoice = p['PayrollInvoiceNo'] as String? ?? '—';
              final isPaid  = p['IsPaid'] == true;
              return [invoice, name, type, isPaid ? 'Paid' : 'Pending',
                  '₹${amount.toStringAsFixed(2)}'];
            }).toList(),
          ),
          pw.SizedBox(height: 4),
          pw.Align(alignment: pw.Alignment.centerRight,
            child: pw.Text('Total Expenditure: ₹${_totalExpense.toStringAsFixed(2)}',
                style: pw.TextStyle(fontWeight: pw.FontWeight.bold,
                    color: red, fontSize: 11))),
        ],
        pw.SizedBox(height: 20),

        // Net result box
        pw.Container(
          padding: const pw.EdgeInsets.all(14),
          decoration: pw.BoxDecoration(
            border: pw.Border.all(
                color: isProfit ? green : red, width: 1.5),
            borderRadius: pw.BorderRadius.circular(8)),
          child: pw.Row(
              mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
              children: [
            pw.Column(crossAxisAlignment: pw.CrossAxisAlignment.start, children: [
              pw.Text(isProfit ? 'NET PROFIT' : 'NET LOSS',
                  style: pw.TextStyle(fontSize: 14,
                      fontWeight: pw.FontWeight.bold,
                      color: isProfit ? green : red)),
              pw.Text('Revenue - Expense = ${isProfit ? "Profit" : "Loss"}',
                  style: pw.TextStyle(fontSize: 9, color: PdfColors.grey600)),
            ]),
            pw.Text('₹${_netProfit.abs().toStringAsFixed(2)}',
                style: pw.TextStyle(fontSize: 18,
                    fontWeight: pw.FontWeight.bold,
                    color: isProfit ? green : red)),
          ])),

        pw.SizedBox(height: 12),
        pw.Text('Profit Margin: ${_marginPct.toStringAsFixed(1)}%  |  '
            'Transactions: ${_fees.length} fees, ${_payrolls.length} payroll',
            style: pw.TextStyle(fontSize: 9, color: PdfColors.grey600)),
      ],
    ));

    return pdf.save();
  }

  pw.Widget _pdfSummaryBox(String label, String value, PdfColor color) {
    return pw.Expanded(child: pw.Container(
      padding: const pw.EdgeInsets.all(10),
      decoration: pw.BoxDecoration(
          border: pw.Border.all(color: color),
          borderRadius: pw.BorderRadius.circular(6)),
      child: pw.Column(crossAxisAlignment: pw.CrossAxisAlignment.start, children: [
        pw.Text(label, style: pw.TextStyle(fontSize: 9, color: PdfColors.grey600)),
        pw.SizedBox(height: 4),
        pw.Text(value, style: pw.TextStyle(fontSize: 12,
            fontWeight: pw.FontWeight.bold, color: color)),
      ])));
  }

  Widget _bgCircles() => Stack(children: [
    Positioned(top: -80, right: -60, child: Container(width: 280, height: 280,
        decoration: BoxDecoration(shape: BoxShape.circle,
            color: const Color(0xFF1A6B4A).withOpacity(0.12)))),
    Positioned(bottom: -100, left: -80, child: Container(width: 320, height: 320,
        decoration: BoxDecoration(shape: BoxShape.circle,
            color: const Color(0xFF1A4B6B).withOpacity(0.15)))),
  ]);

  void _showSnack(String msg, {bool ok = false}) =>
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(msg, style: const TextStyle(color: Colors.white, fontSize: 14)),
      backgroundColor: ok ? const Color(0xFF2ECC71) : const Color(0xFFE74C3C),
      behavior: SnackBarBehavior.floating,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      margin: const EdgeInsets.all(16)));
}