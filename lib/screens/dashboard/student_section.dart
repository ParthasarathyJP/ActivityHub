import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';

// ══════════════════════════════════════════════════════════════════════════════
// Student Section — used inside PeopleTab Students tab
// ══════════════════════════════════════════════════════════════════════════════
class StudentSection extends StatefulWidget {
  final String clientId;
  final String branchId;
  const StudentSection({super.key, required this.clientId, required this.branchId});

  @override
  State<StudentSection> createState() => _StudentSectionState();
}

class _StudentSectionState extends State<StudentSection> {
  List<Map<String, dynamic>> _students     = [];
  List<Map<String, dynamic>> _paymentCycles = []; // SubType PaymentCycle
  List<Map<String, dynamic>> _branches     = [];
  bool _isLoading = true;

  @override
  void initState() { super.initState(); _load(); }

  Future<void> _load() async {
    setState(() => _isLoading = true);
    try {
      final db = FirebaseFirestore.instance;

      QuerySnapshot? studentSnap;
      try {
        studentSnap = await db.collection('Student')
            .where('ClientID', isEqualTo: widget.clientId)
            .orderBy('CreatedAt').get();
      } catch (_) {
        studentSnap = await db.collection('Student')
            .where('ClientID', isEqualTo: widget.clientId).get();
      }

      final results = await Future.wait([
        db.collection('SubType')
            .where('ClientID', isEqualTo: widget.clientId)
            .where('SubTypeCode', isEqualTo: 'PaymentCycle')
            .where('IsActive', isEqualTo: true)
            .orderBy('CreatedAt').get(),
        db.collection('Branch')
            .where('ClientID', isEqualTo: widget.clientId)
            .where('IsActive', isEqualTo: true)
            .orderBy('CreatedAt').get(),
      ]);

      if (mounted) setState(() {
        _students      = studentSnap!.docs.map((d) => {...(d.data() as Map<String,dynamic>), 'DocID': d.id}).toList();
        _paymentCycles = (results[0] as QuerySnapshot).docs.map((d) => {...(d.data() as Map<String,dynamic>), 'DocID': d.id}).toList();
        _branches      = (results[1] as QuerySnapshot).docs.map((d) => {...(d.data() as Map<String,dynamic>), 'DocID': d.id}).toList();
        _isLoading     = false;
      });
    } catch (e) {
      debugPrint('Student load error: $e');
      if (mounted) setState(() => _isLoading = false);
    }
  }

  String _paymentCycleName(String? id) {
    if (id == null) return '';
    final p = _paymentCycles.firstWhere((p) => p['DocID'] == id, orElse: () => {});
    return p['SubTypeName'] ?? '';
  }

  String _branchLabel(String? id) {
    if (id == null) return '';
    final b = _branches.firstWhere((b) => b['DocID'] == id, orElse: () => {});
    return b['IsPrimary'] == true ? 'Primary Branch' : b['BranchAddress'] ?? 'Branch';
  }

  Future<String> _generateEnrollmentNo() async {
    final year = DateTime.now().year;
    final db   = FirebaseFirestore.instance;
    final snap = await db.collection('Student')
        .where('ClientID', isEqualTo: widget.clientId)
        .count().get();
    int count = (snap.count ?? 0) + 1;
    while (true) {
      final candidate = 'STU-$year-${count.toString().padLeft(3, '0')}';
      final existing  = await db.collection('Student')
          .where('ClientID', isEqualTo: widget.clientId)
          .where('StudentEnrollmentNo', isEqualTo: candidate)
          .limit(1).get();
      if (existing.docs.isEmpty) return candidate;
      count++;
    }
  }

  Future<FirebaseApp> _getSecondaryApp() async {
    try {
      return await Firebase.initializeApp(
          name: 'secondaryAuth', options: Firebase.app().options);
    } catch (_) { return Firebase.app('secondaryAuth'); }
  }

  @override
  Widget build(BuildContext context) {
    return Column(children: [
      // Add button row
      Padding(
        padding: const EdgeInsets.fromLTRB(20, 0, 20, 8),
        child: Row(children: [
          Expanded(child: Text('${_students.length} ${_students.length == 1 ? "Student" : "Students"}',
              style: const TextStyle(fontSize: 13, color: Color(0xFF8899AA), fontWeight: FontWeight.w500))),
          GestureDetector(
            onTap: () => _showStudentSheet(),
            child: Container(width: 38, height: 38,
              decoration: BoxDecoration(
                color: const Color(0xFF1DB954).withOpacity(0.12),
                borderRadius: BorderRadius.circular(11),
                border: Border.all(color: const Color(0xFF1DB954).withOpacity(0.3))),
              child: const Icon(Icons.add_rounded, color: Color(0xFF1DB954), size: 20))),
        ]),
      ),

      Expanded(
        child: _isLoading
            ? const Center(child: CircularProgressIndicator(color: Color(0xFF1DB954), strokeWidth: 2))
            : RefreshIndicator(
                onRefresh: _load,
                color: const Color(0xFF1DB954),
                backgroundColor: const Color(0xFF152232),
                child: _students.isEmpty ? _emptyState() : ListView(
                  padding: const EdgeInsets.fromLTRB(20, 0, 20, 100),
                  children: _students.map((s) => _studentCard(s)).toList())),
      ),
    ]);
  }

  Widget _studentCard(Map<String, dynamic> s) {
    final isActive  = s['IsActive'] != false;
    final enrollNo  = s['StudentEnrollmentNo'] ?? '';
    final contact   = s['Contact'] as Map<String, dynamic>? ?? {};
    final phone     = contact['phone'] ?? '';
    final guardian  = s['GuardianInfo'] as Map<String, dynamic>? ?? {};
    final guardName = guardian['name'] ?? '';
    final payCycle  = _paymentCycleName(s['PaymentCycleSubTypeID']);

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: const Color(0xFF152232),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: isActive ? const Color(0xFF1E3347) : const Color(0xFFE74C3C).withOpacity(0.35),
          width: isActive ? 1 : 1.5)),
      child: Column(children: [
        // Main info
        Padding(padding: const EdgeInsets.all(16), child: Row(children: [
          Container(width: 48, height: 48,
            decoration: BoxDecoration(
              color: const Color(0xFF5BA3D9).withOpacity(0.15),
              borderRadius: BorderRadius.circular(14)),
            child: Center(child: Text(
              (s['Name'] ?? 'S').substring(0, 1).toUpperCase(),
              style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Color(0xFF5BA3D9))))),
          const SizedBox(width: 12),
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(s['Name'] ?? '',
                style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600,
                    color: isActive ? Colors.white : const Color(0xFF8899AA))),
            const SizedBox(height: 4),
            Row(children: [
              if (payCycle.isNotEmpty) Container(
                padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                decoration: BoxDecoration(
                  color: const Color(0xFF5BA3D9).withOpacity(0.12),
                  borderRadius: BorderRadius.circular(5)),
                child: Text(payCycle, style: const TextStyle(fontSize: 10, color: Color(0xFF5BA3D9)))),
              if (!isActive) ...[
                const SizedBox(width: 6),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                  decoration: BoxDecoration(color: const Color(0xFFE74C3C).withOpacity(0.1), borderRadius: BorderRadius.circular(5)),
                  child: const Text('Inactive', style: TextStyle(fontSize: 10, color: Color(0xFFE74C3C)))),
              ],
            ]),
          ])),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
              color: const Color(0xFF0D1B2A),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: const Color(0xFF1E3347))),
            child: Text(enrollNo, style: const TextStyle(fontSize: 10, color: Color(0xFF8899AA)))),
        ])),

        // Contact + guardian row
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
          decoration: const BoxDecoration(border: Border(top: BorderSide(color: Color(0xFF1E3347), width: 1))),
          child: Row(children: [
            if (phone.isNotEmpty) ...[
              const Icon(Icons.phone_outlined, color: Color(0xFF556677), size: 13),
              const SizedBox(width: 4),
              Text(phone, style: const TextStyle(fontSize: 11, color: Color(0xFF556677))),
              const SizedBox(width: 12),
            ],
            if (guardName.isNotEmpty) ...[
              const Icon(Icons.people_outline_rounded, color: Color(0xFF556677), size: 13),
              const SizedBox(width: 4),
              Expanded(child: Text('Guardian: $guardName',
                  style: const TextStyle(fontSize: 11, color: Color(0xFF556677)), overflow: TextOverflow.ellipsis)),
            ],
          ]),
        ),

        // Actions
        Container(
          padding: const EdgeInsets.fromLTRB(12, 8, 12, 8),
          decoration: const BoxDecoration(border: Border(top: BorderSide(color: Color(0xFF1E3347), width: 1))),
          child: Row(children: [
            Expanded(child: Text(_branchLabel(s['BranchID']),
                style: const TextStyle(fontSize: 10, color: Color(0xFF3A5068)), overflow: TextOverflow.ellipsis)),

            // Courses
            GestureDetector(
              onTap: () => Navigator.push(context, MaterialPageRoute(
                  builder: (_) => StudentScheduleScreen(
                      clientId: widget.clientId, branchId: widget.branchId, student: s))),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                decoration: BoxDecoration(
                  color: const Color(0xFF1DB954).withOpacity(0.08),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: const Color(0xFF1DB954).withOpacity(0.25))),
                child: const Row(mainAxisSize: MainAxisSize.min, children: [
                  Icon(Icons.calendar_today_outlined, color: Color(0xFF1DB954), size: 12),
                  SizedBox(width: 4),
                  Text('Courses', style: TextStyle(fontSize: 11, color: Color(0xFF1DB954), fontWeight: FontWeight.w500)),
                ]))),
            const SizedBox(width: 6),

            // Edit
            GestureDetector(
              onTap: () => _showStudentSheet(existing: s),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                decoration: BoxDecoration(
                  color: const Color(0xFF5BA3D9).withOpacity(0.12),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: const Color(0xFF5BA3D9).withOpacity(0.3))),
                child: const Row(mainAxisSize: MainAxisSize.min, children: [
                  Icon(Icons.edit_outlined, color: Color(0xFF5BA3D9), size: 12),
                  SizedBox(width: 4),
                  Text('Edit', style: TextStyle(fontSize: 11, color: Color(0xFF5BA3D9), fontWeight: FontWeight.w500)),
                ]))),
            const SizedBox(width: 6),

            // Toggle
            GestureDetector(
              onTap: () => _toggleActive(s, isActive),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                decoration: BoxDecoration(
                  color: isActive ? const Color(0xFFE74C3C).withOpacity(0.08) : const Color(0xFF1DB954).withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(
                    color: isActive ? const Color(0xFFE74C3C).withOpacity(0.3) : const Color(0xFF1DB954).withOpacity(0.3))),
                child: Row(mainAxisSize: MainAxisSize.min, children: [
                  Icon(isActive ? Icons.pause_circle_outline_rounded : Icons.play_circle_outline_rounded,
                      color: isActive ? const Color(0xFFE74C3C) : const Color(0xFF1DB954), size: 12),
                  const SizedBox(width: 4),
                  Text(isActive ? 'Deactivate' : 'Activate',
                      style: TextStyle(fontSize: 11, fontWeight: FontWeight.w500,
                          color: isActive ? const Color(0xFFE74C3C) : const Color(0xFF1DB954))),
                ]))),
          ]),
        ),
      ]),
    );
  }

  Widget _emptyState() => ListView(padding: const EdgeInsets.all(32), children: [
    const SizedBox(height: 40),
    Center(child: Column(children: [
      Container(width: 72, height: 72,
        decoration: BoxDecoration(color: const Color(0xFF1DB954).withOpacity(0.08), borderRadius: BorderRadius.circular(20)),
        child: const Icon(Icons.school_outlined, color: Color(0xFF3A5068), size: 36)),
      const SizedBox(height: 20),
      const Text('No students yet', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600, color: Colors.white, fontFamily: 'Georgia')),
      const SizedBox(height: 8),
      const Text('Tap + to add your first student.', textAlign: TextAlign.center,
          style: TextStyle(fontSize: 13, color: Color(0xFF556677), height: 1.5)),
    ])),
  ]);

  // ── Add / Edit Student Sheet ───────────────────────────────────────────────
  void _showStudentSheet({Map<String, dynamic>? existing}) {
    final isEdit        = existing != null;
    final nameCtrl      = TextEditingController(text: existing?['Name'] ?? '');
    final phoneCtrl     = TextEditingController(text: (existing?['Contact'] as Map?)?['phone'] ?? '');
    final emailCtrl     = TextEditingController(text: (existing?['Contact'] as Map?)?['email'] ?? '');
    final addressCtrl   = TextEditingController(text: existing?['Address'] ?? '');
    final gNameCtrl     = TextEditingController(text: (existing?['GuardianInfo'] as Map?)?['name'] ?? '');
    final gPhoneCtrl    = TextEditingController(text: (existing?['GuardianInfo'] as Map?)?['phone'] ?? '');
    final gEmailCtrl    = TextEditingController(text: (existing?['GuardianInfo'] as Map?)?['email'] ?? '');
    String? selPayCycleId = existing?['PaymentCycleSubTypeID'] ??
        (_paymentCycles.isNotEmpty ? _paymentCycles.first['DocID'] : null);
    String? selBranchId   = existing?['BranchID'] ?? widget.branchId;
    bool saving = false;

    showModalBottomSheet(
      context: context, isScrollControlled: true, backgroundColor: Colors.transparent,
      builder: (ctx) => StatefulBuilder(builder: (ctx, ss) => Padding(
        padding: EdgeInsets.only(bottom: MediaQuery.of(ctx).viewInsets.bottom),
        child: Container(
          decoration: const BoxDecoration(color: Color(0xFF152232), borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
          padding: const EdgeInsets.all(24),
          child: SingleChildScrollView(child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
            Center(child: Container(width: 40, height: 4,
              decoration: BoxDecoration(color: const Color(0xFF1E3347), borderRadius: BorderRadius.circular(2)))),
            const SizedBox(height: 20),
            Row(children: [
              Container(width: 36, height: 36,
                decoration: BoxDecoration(color: const Color(0xFF5BA3D9).withOpacity(0.12), borderRadius: BorderRadius.circular(10)),
                child: const Icon(Icons.school_outlined, color: Color(0xFF5BA3D9), size: 18)),
              const SizedBox(width: 12),
              Text(isEdit ? 'Edit Student' : 'Add Student',
                  style: const TextStyle(fontFamily: 'Georgia', fontSize: 18, fontWeight: FontWeight.bold, color: Colors.white)),
            ]),
            const SizedBox(height: 24),

            // Student details
            _lbl('Full Name *'), const SizedBox(height: 8),
            _tf(ctrl: nameCtrl, hint: 'e.g. Anitha Krishnan'),
            const SizedBox(height: 14),

            _lbl('Phone'), const SizedBox(height: 8),
            _tf(ctrl: phoneCtrl, hint: '+91 98765 43210', kb: TextInputType.phone),
            const SizedBox(height: 14),

            _lbl('Email (optional — used for login)'), const SizedBox(height: 8),
            _tf(ctrl: emailCtrl, hint: 'student@email.com', kb: TextInputType.emailAddress),
            const SizedBox(height: 14),

            _lbl('Address'), const SizedBox(height: 8),
            _tf(ctrl: addressCtrl, hint: 'Home address', maxLines: 2),
            const SizedBox(height: 14),

            _lbl('Payment Cycle *'), const SizedBox(height: 8),
            _paymentCycles.isEmpty
                ? Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: const Color(0xFFE74C3C).withOpacity(0.08),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: const Color(0xFFE74C3C).withOpacity(0.3))),
                    child: const Text('No payment cycles found.\nGo to More → Sub Types → Payment Cycle.',
                        style: TextStyle(fontSize: 12, color: Color(0xFFE74C3C), height: 1.4)))
                : _dd(value: selPayCycleId, items: _paymentCycles, lk: 'SubTypeName', vk: 'DocID',
                    hint: 'Select payment cycle', onChanged: (v) => ss(() => selPayCycleId = v)),

            const SizedBox(height: 20),
            // Guardian section
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: const Color(0xFF0D1B2A),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: const Color(0xFF1E3347))),
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Row(children: [
                  Container(width: 28, height: 28,
                    decoration: BoxDecoration(color: const Color(0xFFE8A020).withOpacity(0.12), borderRadius: BorderRadius.circular(8)),
                    child: const Icon(Icons.people_outline_rounded, color: Color(0xFFE8A020), size: 15)),
                  const SizedBox(width: 8),
                  const Text('Guardian Info', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: Colors.white)),
                ]),
                const SizedBox(height: 14),
                _lbl('Guardian Name'), const SizedBox(height: 8),
                _tf(ctrl: gNameCtrl, hint: 'e.g. Krishnan P'),
                const SizedBox(height: 12),
                _lbl('Guardian Phone'), const SizedBox(height: 8),
                _tf(ctrl: gPhoneCtrl, hint: '+91 98765 43210', kb: TextInputType.phone),
                const SizedBox(height: 12),
                _lbl('Guardian Email'), const SizedBox(height: 8),
                _tf(ctrl: gEmailCtrl, hint: 'guardian@email.com', kb: TextInputType.emailAddress),
              ])),

            if (_branches.length > 1) ...[
              const SizedBox(height: 14),
              _lbl('Branch *'), const SizedBox(height: 8),
              _dd(value: selBranchId, items: _branches, lk: 'BranchAddress', vk: 'DocID',
                  hint: 'Select branch', onChanged: (v) => ss(() => selBranchId = v),
                  lb: (b) => b['IsPrimary'] == true ? 'Primary Branch' : b['BranchAddress'] ?? 'Branch'),
            ],

            const SizedBox(height: 24),
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
                onPressed: saving ? null : () async {
                  if (nameCtrl.text.trim().isEmpty) { _snack('Student name is required.'); return; }
                  if (selPayCycleId == null) { _snack('Select a payment cycle.'); return; }
                  ss(() => saving = true);
                  try {
                    if (isEdit) {
                      await _updateStudent(
                        docId: existing!['DocID'],
                        name: nameCtrl.text.trim(),
                        phone: phoneCtrl.text.trim(),
                        email: emailCtrl.text.trim(),
                        address: addressCtrl.text.trim(),
                        guardName: gNameCtrl.text.trim(),
                        guardPhone: gPhoneCtrl.text.trim(),
                        guardEmail: gEmailCtrl.text.trim(),
                        paymentCycleId: selPayCycleId!,
                        branchId: selBranchId!);
                      if (ctx.mounted) Navigator.pop(ctx);
                      await _load();
                      _snack('Student updated!', ok: true);
                    } else {
                      await _createStudent(
                        name: nameCtrl.text.trim(),
                        phone: phoneCtrl.text.trim(),
                        email: emailCtrl.text.trim(),
                        address: addressCtrl.text.trim(),
                        guardName: gNameCtrl.text.trim(),
                        guardPhone: gPhoneCtrl.text.trim(),
                        guardEmail: gEmailCtrl.text.trim(),
                        paymentCycleId: selPayCycleId!,
                        branchId: selBranchId!,
                        ctx: ctx);
                    }
                  } catch (e) {
                    _snack('Error: ${e.toString()}');
                    ss(() => saving = false);
                  }
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF1DB954), foregroundColor: Colors.white,
                  elevation: 0, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                  padding: const EdgeInsets.symmetric(vertical: 14)),
                child: saving
                    ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                    : Text(isEdit ? 'Update' : 'Save Student',
                        style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600)))),
            ]),
            const SizedBox(height: 8),
          ])),
        ),
      )));
  }

  Future<void> _createStudent({
    required String name, required String phone, required String email,
    required String address, required String guardName, required String guardPhone,
    required String guardEmail, required String paymentCycleId,
    required String branchId, required BuildContext ctx,
  }) async {
    final db       = FirebaseFirestore.instance;
    final enrollNo = await _generateEnrollmentNo();
    final authEmail = email.isNotEmpty
        ? email
        : '${enrollNo.toLowerCase()}@${widget.clientId.toLowerCase()}.activityhub.app';

    // Create Firebase Auth via secondary app — keeps admin logged in
    final secondaryApp  = await _getSecondaryApp();
    final secondaryAuth = FirebaseAuth.instanceFor(app: secondaryApp);
    final cred = await secondaryAuth.createUserWithEmailAndPassword(
        email: authEmail, password: enrollNo);
    final uid = cred.user!.uid;
    await secondaryAuth.signOut();

    final studentRef = db.collection('Student').doc();
    final batch      = db.batch();

    batch.set(studentRef, {
      'StudentID':             studentRef.id,
      'ClientID':              widget.clientId,
      'BranchID':              branchId,
      'Name':                  name,
      'Address':               address,
      'Contact':               {'phone': phone, 'email': authEmail},
      'GuardianInfo':          {'name': guardName, 'phone': guardPhone, 'email': guardEmail},
      'EnrollmentDate':        FieldValue.serverTimestamp(),
      'StudentEnrollmentNo':   enrollNo,
      'PaymentCycleSubTypeID': paymentCycleId,
      'FirebaseUID':           uid,
      'IsActive':              true,
      'CreatedAt':             FieldValue.serverTimestamp(),
    });

    batch.set(db.collection('ClientAuthorizedUsers').doc(uid), {
      'AuthUserID':          uid,
      'ClientID':            widget.clientId,
      'BranchID':            branchId,
      'FirebaseUID':         uid,
      'AdminName':           name,
      'Email':               authEmail,
      'UserType':            'Student',
      'LinkedID':            studentRef.id,
      'IsActive':            true,
      'MustChangePassword':  true,
      'StudentEnrollmentNo': enrollNo,
      'CreatedAt':           FieldValue.serverTimestamp(),
    });

    await batch.commit();

    // Show success dialog
    if (mounted) {
      if (ctx.mounted) Navigator.pop(ctx);
      await _load();
      await Future.delayed(const Duration(milliseconds: 300));
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (dialogCtx) => AlertDialog(
          backgroundColor: const Color(0xFF152232),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          content: Column(mainAxisSize: MainAxisSize.min, children: [
            Container(width: 64, height: 64,
              decoration: BoxDecoration(color: const Color(0xFF1DB954).withOpacity(0.12), borderRadius: BorderRadius.circular(18)),
              child: const Icon(Icons.check_circle_outline_rounded, color: Color(0xFF1DB954), size: 36)),
            const SizedBox(height: 16),
            const Text('Student Added!', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.white, fontFamily: 'Georgia')),
            const SizedBox(height: 8),
            const Text('Enrollment Number', style: TextStyle(fontSize: 12, color: Color(0xFF556677))),
            const SizedBox(height: 6),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
              decoration: BoxDecoration(color: const Color(0xFF0D1B2A), borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: const Color(0xFF1DB954).withOpacity(0.4))),
              child: Text(enrollNo, style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold,
                  color: Color(0xFF1DB954), letterSpacing: 1.5))),
            const SizedBox(height: 6),
            Text('Login: $authEmail', style: const TextStyle(fontSize: 11, color: Color(0xFF556677))),
            const Text('Password: (same as enrollment no)', style: TextStyle(fontSize: 11, color: Color(0xFF556677))),
            const SizedBox(height: 20),
            SizedBox(width: double.infinity, child: ElevatedButton(
              onPressed: () => Navigator.pop(dialogCtx),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF1DB954), foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                padding: const EdgeInsets.symmetric(vertical: 13)),
              child: const Text('Done', style: TextStyle(fontWeight: FontWeight.w600)))),
          ]),
        ),
      );
    }
  }

  Future<void> _updateStudent({
    required String docId, required String name, required String phone,
    required String email, required String address, required String guardName,
    required String guardPhone, required String guardEmail,
    required String paymentCycleId, required String branchId,
  }) async {
    await FirebaseFirestore.instance.collection('Student').doc(docId).update({
      'Name':                  name,
      'Address':               address,
      'Contact':               {'phone': phone, 'email': email},
      'GuardianInfo':          {'name': guardName, 'phone': guardPhone, 'email': guardEmail},
      'PaymentCycleSubTypeID': paymentCycleId,
      'BranchID':              branchId,
      'UpdatedAt':             FieldValue.serverTimestamp(),
    });
  }

  Future<void> _toggleActive(Map<String, dynamic> s, bool isActive) async {
    final confirm = await showDialog<bool>(context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF152232),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Text(isActive ? 'Deactivate student?' : 'Activate student?',
            style: const TextStyle(color: Colors.white, fontFamily: 'Georgia')),
        content: Text(
          isActive ? '"${s['Name']}" will lose app access.' : '"${s['Name']}" will regain app access.',
          style: const TextStyle(color: Color(0xFF8899AA), height: 1.5)),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Cancel', style: TextStyle(color: Color(0xFF8899AA)))),
          TextButton(onPressed: () => Navigator.pop(ctx, true),
              child: Text(isActive ? 'Deactivate' : 'Activate',
                  style: TextStyle(color: isActive ? const Color(0xFFE74C3C) : const Color(0xFF1DB954)))),
        ]));
    if (confirm != true) return;
    try {
      final db  = FirebaseFirestore.instance;
      final uid = s['FirebaseUID'] as String?;
      final batch = db.batch();
      batch.update(db.collection('Student').doc(s['DocID']),
          {'IsActive': !isActive, 'UpdatedAt': FieldValue.serverTimestamp()});
      if (uid != null) {
        batch.update(db.collection('ClientAuthorizedUsers').doc(uid),
            {'IsActive': !isActive, 'UpdatedAt': FieldValue.serverTimestamp()});
      }
      await batch.commit();
      await _load();
      _snack(isActive ? 'Student deactivated.' : 'Student activated!', ok: !isActive);
    } catch (e) { _snack('Failed to update status.'); }
  }

  void _snack(String msg, {bool ok = false}) =>
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(msg, style: const TextStyle(color: Colors.white, fontSize: 14)),
      backgroundColor: ok ? const Color(0xFF2ECC71) : const Color(0xFFE74C3C),
      behavior: SnackBarBehavior.floating,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      margin: const EdgeInsets.all(16)));

  Widget _lbl(String t) => Text(t,
      style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w500, color: Color(0xFF8899AA)));

  Widget _tf({required TextEditingController ctrl, required String hint,
      TextInputType kb = TextInputType.text, int maxLines = 1}) =>
    TextField(controller: ctrl, keyboardType: kb, maxLines: maxLines,
      style: const TextStyle(color: Colors.white, fontSize: 15),
      cursorColor: const Color(0xFF1DB954),
      decoration: InputDecoration(hintText: hint,
        hintStyle: const TextStyle(color: Color(0xFF3A5068), fontSize: 15),
        filled: true, fillColor: const Color(0xFF0D1B2A),
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: Color(0xFF1E3347), width: 1)),
        enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: Color(0xFF1E3347), width: 1)),
        focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: Color(0xFF1DB954), width: 1.5))));

  Widget _dd({required String? value, required List<Map<String,dynamic>> items,
      required String lk, required String vk, required String hint,
      required ValueChanged<String?> onChanged, String Function(Map<String,dynamic>)? lb}) {
    final valid = items.any((i) => i[vk].toString() == value) ? value : null;
    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFF0D1B2A), borderRadius: BorderRadius.circular(12),
        border: Border.all(color: valid != null ? const Color(0xFF1DB954) : const Color(0xFF1E3347),
            width: valid != null ? 1.5 : 1)),
      child: DropdownButtonHideUnderline(child: DropdownButton<String>(
        value: valid, isExpanded: true, dropdownColor: const Color(0xFF152232),
        padding: const EdgeInsets.symmetric(horizontal: 12),
        hint: Text(hint, style: const TextStyle(color: Color(0xFF3A5068), fontSize: 14)),
        icon: const Icon(Icons.keyboard_arrow_down_rounded, color: Color(0xFF556677)),
        items: items.map((i) => DropdownMenuItem<String>(value: i[vk].toString(),
            child: Text(lb != null ? lb(i) : i[lk] ?? '',
                style: const TextStyle(color: Colors.white, fontSize: 14)))).toList(),
        onChanged: onChanged)));
  }
}

// ══════════════════════════════════════════════════════════════════════════════
// Student Schedule Screen — assign student to course schedules
// ══════════════════════════════════════════════════════════════════════════════
class StudentScheduleScreen extends StatefulWidget {
  final String clientId;
  final String branchId;
  final Map<String, dynamic> student;

  const StudentScheduleScreen({
    super.key, required this.clientId, required this.branchId, required this.student});

  @override
  State<StudentScheduleScreen> createState() => _StudentScheduleScreenState();
}

class _StudentScheduleScreenState extends State<StudentScheduleScreen> {
  List<Map<String, dynamic>> _assignments = [];
  List<Map<String, dynamic>> _schedules   = [];
  List<Map<String, dynamic>> _courses     = [];
  List<Map<String, dynamic>> _timings     = [];
  bool _isLoading = true;

  @override
  void initState() { super.initState(); _load(); }

  Future<void> _load() async {
    setState(() => _isLoading = true);
    try {
      final db       = FirebaseFirestore.instance;
      final enrollNo = widget.student['StudentEnrollmentNo'] as String? ?? '';

      QuerySnapshot? assignSnap;
      try {
        assignSnap = await db.collection('StudentCourseSchedule')
            .where('ClientID', isEqualTo: widget.clientId)
            .where('StudentEnrollmentNo', isEqualTo: enrollNo)
            .orderBy('CreatedAt').get();
      } catch (_) {
        assignSnap = await db.collection('StudentCourseSchedule')
            .where('ClientID', isEqualTo: widget.clientId)
            .where('StudentEnrollmentNo', isEqualTo: enrollNo).get();
      }

      QuerySnapshot? scheduleSnap;
      try {
        scheduleSnap = await db.collection('CourseSchedule')
            .where('ClientID', isEqualTo: widget.clientId)
            .where('IsActive', isEqualTo: true)
            .orderBy('CreatedAt').get();
      } catch (_) {
        scheduleSnap = await db.collection('CourseSchedule')
            .where('ClientID', isEqualTo: widget.clientId)
            .where('IsActive', isEqualTo: true).get();
      }

      final results = await Future.wait([
        db.collection('Course').where('ClientID', isEqualTo: widget.clientId).get(),
        db.collection('SubType').where('ClientID', isEqualTo: widget.clientId)
            .where('SubTypeCode', isEqualTo: 'Timings').where('IsActive', isEqualTo: true).get(),
      ]);

      if (mounted) setState(() {
        _assignments = assignSnap!.docs.map((d) => {...(d.data() as Map<String,dynamic>), 'DocID': d.id}).toList();
        _schedules   = scheduleSnap!.docs.map((d) => {...(d.data() as Map<String,dynamic>), 'DocID': d.id}).toList();
        _courses     = (results[0] as QuerySnapshot).docs.map((d) => {...(d.data() as Map<String,dynamic>), 'DocID': d.id}).toList();
        _timings     = (results[1] as QuerySnapshot).docs.map((d) => {...(d.data() as Map<String,dynamic>), 'DocID': d.id}).toList();
        _isLoading   = false;
      });
    } catch (e) {
      debugPrint('StudentSchedule load error: $e');
      if (mounted) setState(() => _isLoading = false);
    }
  }

  String _courseName(String? courseId) {
    if (courseId == null) return '—';
    final c = _courses.firstWhere((c) => c['DocID'] == courseId, orElse: () => {});
    return c['CourseName'] ?? '—';
  }

  String _timingName(String? id) {
    if (id == null) return '—';
    final t = _timings.firstWhere((t) => t['DocID'] == id, orElse: () => {});
    return t['SubTypeName'] ?? '—';
  }

  Map<String, dynamic> _scheduleById(String? id) {
    if (id == null) return {};
    return _schedules.firstWhere((s) => s['DocID'] == id, orElse: () => {});
  }

  List<Map<String, dynamic>> get _unassigned {
    final assigned = _assignments.map((a) => a['CourseScheduleID'] as String?).toSet();
    return _schedules.where((s) => !assigned.contains(s['DocID'])).toList();
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
                  decoration: BoxDecoration(color: const Color(0xFF152232), borderRadius: BorderRadius.circular(12), border: Border.all(color: const Color(0xFF1E3347))),
                  child: const Icon(Icons.arrow_back_ios_new_rounded, color: Color(0xFF8899AA), size: 18))),
              const SizedBox(width: 14),
              Container(width: 36, height: 36,
                decoration: BoxDecoration(color: const Color(0xFF5BA3D9).withOpacity(0.15), borderRadius: BorderRadius.circular(10)),
                child: Center(child: Text(
                  (widget.student['Name'] ?? 'S').substring(0, 1).toUpperCase(),
                  style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Color(0xFF5BA3D9))))),
              const SizedBox(width: 10),
              Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(widget.student['Name'] ?? '', style: const TextStyle(fontFamily: 'Georgia', fontSize: 17, fontWeight: FontWeight.bold, color: Colors.white)),
                Text('${widget.student['StudentEnrollmentNo'] ?? ''} · Student',
                    style: const TextStyle(fontSize: 11, color: Color(0xFF556677))),
              ])),
              GestureDetector(
                onTap: _unassigned.isEmpty ? null : _showAssignSheet,
                child: Container(width: 40, height: 40,
                  decoration: BoxDecoration(
                    color: _unassigned.isEmpty ? const Color(0xFF1E3347) : const Color(0xFF1DB954).withOpacity(0.12),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: _unassigned.isEmpty ? const Color(0xFF1E3347) : const Color(0xFF1DB954).withOpacity(0.3))),
                  child: Icon(Icons.add_rounded,
                      color: _unassigned.isEmpty ? const Color(0xFF3A5068) : const Color(0xFF1DB954), size: 22))),
            ])),

          Padding(padding: const EdgeInsets.fromLTRB(20, 4, 20, 12),
            child: Row(children: [
              const Text('Enrolled Courses', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600, color: Colors.white)),
              const Spacer(),
              if (_assignments.isNotEmpty)
                Text('${_assignments.length} ${_assignments.length == 1 ? "course" : "courses"}',
                    style: const TextStyle(fontSize: 12, color: Color(0xFF556677))),
            ])),

          Expanded(child: _isLoading
              ? const Center(child: CircularProgressIndicator(color: Color(0xFF1DB954), strokeWidth: 2))
              : RefreshIndicator(onRefresh: _load, color: const Color(0xFF1DB954), backgroundColor: const Color(0xFF152232),
                  child: _assignments.isEmpty ? _emptyState() : ListView(
                    padding: const EdgeInsets.fromLTRB(20, 0, 20, 100),
                    children: _assignments.map((a) => _assignmentCard(a)).toList()))),
        ])),
      ]),
    );
  }

  Widget _assignmentCard(Map<String, dynamic> a) {
    final isActive   = a['IsActive'] != false;
    final schedule   = _scheduleById(a['CourseScheduleID']);
    final courseName = _courseName(schedule['CourseID']);
    final batchName  = schedule['BatchName'] ?? '—';
    final timing     = _timingName(schedule['TimingsSubTypeID']);
    final days       = (schedule['DaysOfWeek'] as List?)?.cast<String>() ?? [];

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: const Color(0xFF152232), borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: isActive ? const Color(0xFF1E3347) : const Color(0xFFE74C3C).withOpacity(0.35),
          width: isActive ? 1 : 1.5)),
      child: Column(children: [
        Padding(padding: const EdgeInsets.all(16), child: Row(children: [
          Container(width: 44, height: 44,
            decoration: BoxDecoration(color: const Color(0xFF5BA3D9).withOpacity(0.12), borderRadius: BorderRadius.circular(13)),
            child: const Icon(Icons.menu_book_rounded, color: Color(0xFF5BA3D9), size: 20)),
          const SizedBox(width: 12),
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(courseName, style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600, color: Colors.white)),
            Text(batchName, style: const TextStyle(fontSize: 12, color: Color(0xFF8899AA))),
          ])),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
            decoration: BoxDecoration(
              color: isActive ? const Color(0xFF1DB954).withOpacity(0.1) : const Color(0xFFE74C3C).withOpacity(0.1),
              borderRadius: BorderRadius.circular(6)),
            child: Text(isActive ? 'Active' : 'Inactive',
                style: TextStyle(fontSize: 10, color: isActive ? const Color(0xFF1DB954) : const Color(0xFFE74C3C)))),
        ])),
        Container(
          padding: const EdgeInsets.fromLTRB(16, 10, 16, 10),
          decoration: const BoxDecoration(border: Border(top: BorderSide(color: Color(0xFF1E3347), width: 1))),
          child: Row(children: [
            const Icon(Icons.access_time_rounded, color: Color(0xFF556677), size: 14),
            const SizedBox(width: 6),
            Text(timing, style: const TextStyle(fontSize: 12, color: Color(0xFF8899AA))),
            const SizedBox(width: 12),
            Expanded(child: Wrap(spacing: 4, children: days.map((d) => Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
              decoration: BoxDecoration(color: const Color(0xFF0D1B2A), borderRadius: BorderRadius.circular(4), border: Border.all(color: const Color(0xFF1E3347))),
              child: Text(d, style: const TextStyle(fontSize: 10, color: Color(0xFF8899AA))))).toList())),
          ])),
        Container(
          padding: const EdgeInsets.fromLTRB(12, 8, 12, 8),
          decoration: const BoxDecoration(border: Border(top: BorderSide(color: Color(0xFF1E3347), width: 1))),
          child: Row(children: [
            const Spacer(),
            GestureDetector(
              onTap: () => _toggleAssignment(a, isActive),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                decoration: BoxDecoration(
                  color: isActive ? const Color(0xFFE74C3C).withOpacity(0.08) : const Color(0xFF1DB954).withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: isActive ? const Color(0xFFE74C3C).withOpacity(0.3) : const Color(0xFF1DB954).withOpacity(0.3))),
                child: Row(mainAxisSize: MainAxisSize.min, children: [
                  Icon(isActive ? Icons.link_off_rounded : Icons.link_rounded,
                      color: isActive ? const Color(0xFFE74C3C) : const Color(0xFF1DB954), size: 14),
                  const SizedBox(width: 4),
                  Text(isActive ? 'Unenroll' : 'Re-enroll',
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
        decoration: BoxDecoration(color: const Color(0xFF1DB954).withOpacity(0.08), borderRadius: BorderRadius.circular(20)),
        child: const Icon(Icons.menu_book_outlined, color: Color(0xFF3A5068), size: 32)),
      const SizedBox(height: 20),
      const Text('Not enrolled in any course', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600, color: Colors.white, fontFamily: 'Georgia')),
      const SizedBox(height: 8),
      const Text('Tap + to enroll in a course batch.', textAlign: TextAlign.center,
          style: TextStyle(fontSize: 13, color: Color(0xFF556677), height: 1.5)),
    ])),
  ]);

  void _showAssignSheet() {
    String? selectedScheduleId;
    bool saving = false;

    showModalBottomSheet(
      context: context, isScrollControlled: true, backgroundColor: Colors.transparent,
      builder: (ctx) => StatefulBuilder(builder: (ctx, ss) => Container(
        decoration: const BoxDecoration(color: Color(0xFF152232), borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
        padding: const EdgeInsets.all(24),
        child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
          Center(child: Container(width: 40, height: 4, decoration: BoxDecoration(color: const Color(0xFF1E3347), borderRadius: BorderRadius.circular(2)))),
          const SizedBox(height: 20),
          Row(children: [
            Container(width: 36, height: 36,
              decoration: BoxDecoration(color: const Color(0xFF5BA3D9).withOpacity(0.12), borderRadius: BorderRadius.circular(10)),
              child: const Icon(Icons.link_rounded, color: Color(0xFF5BA3D9), size: 18)),
            const SizedBox(width: 12),
            const Text('Enroll in Course', style: TextStyle(fontFamily: 'Georgia', fontSize: 18, fontWeight: FontWeight.bold, color: Colors.white)),
          ]),
          const SizedBox(height: 20),

          Flexible(child: SingleChildScrollView(child: Column(children: [
            ..._unassigned.map((s) {
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
                    color: isSelected ? const Color(0xFF1DB954).withOpacity(0.08) : const Color(0xFF0D1B2A),
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: isSelected ? const Color(0xFF1DB954) : const Color(0xFF1E3347), width: isSelected ? 1.5 : 1)),
                  child: Row(children: [
                    Container(width: 36, height: 36,
                      decoration: BoxDecoration(color: const Color(0xFF5BA3D9).withOpacity(0.1), borderRadius: BorderRadius.circular(10)),
                      child: Icon(isSelected ? Icons.check_circle_rounded : Icons.menu_book_outlined,
                          color: const Color(0xFF5BA3D9), size: 18)),
                    const SizedBox(width: 12),
                    Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      Text(courseName, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: Colors.white)),
                      Text('${s['BatchName'] ?? ''} · $timing', style: const TextStyle(fontSize: 11, color: Color(0xFF556677))),
                      if (days.isNotEmpty)
                        Text(days.join(', '), style: const TextStyle(fontSize: 10, color: Color(0xFF3A5068))),
                    ])),
                  ])));
            }),
          ]))),

          const SizedBox(height: 20),
          Row(children: [
            Expanded(child: OutlinedButton(
              onPressed: () => Navigator.pop(ctx),
              style: OutlinedButton.styleFrom(
                foregroundColor: const Color(0xFF8899AA), side: const BorderSide(color: Color(0xFF1E3347)),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                padding: const EdgeInsets.symmetric(vertical: 14)),
              child: const Text('Cancel'))),
            const SizedBox(width: 12),
            Expanded(flex: 2, child: ElevatedButton(
              onPressed: (saving || selectedScheduleId == null) ? null : () async {
                ss(() => saving = true);
                try {
                  final db  = FirebaseFirestore.instance;
                  final ref = db.collection('StudentCourseSchedule').doc();
                  await ref.set({
                    'StudentCourseScheduleID': ref.id,
                    'ClientID':                widget.clientId,
                    'StudentEnrollmentNo':     widget.student['StudentEnrollmentNo'],
                    'CourseScheduleID':        selectedScheduleId,
                    'IsActive':                true,
                    'CreatedAt':               FieldValue.serverTimestamp(),
                  });
                  if (ctx.mounted) Navigator.pop(ctx);
                  await _load();
                  _snack('Enrolled successfully!', ok: true);
                } catch (e) {
                  _snack('Failed to enroll. Try again.');
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
                  : const Text('Enroll', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600)))),
          ]),
          const SizedBox(height: 8),
        ]),
      )));
  }

  Future<void> _toggleAssignment(Map<String, dynamic> a, bool isActive) async {
    final schedule   = _scheduleById(a['CourseScheduleID']);
    final courseName = _courseName(schedule['CourseID']);
    final confirm = await showDialog<bool>(context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF152232),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Text(isActive ? 'Unenroll from course?' : 'Re-enroll in course?',
            style: const TextStyle(color: Colors.white, fontFamily: 'Georgia')),
        content: Text(
          isActive ? 'Remove ${widget.student['Name']} from $courseName?' : 'Re-enroll ${widget.student['Name']} in $courseName?',
          style: const TextStyle(color: Color(0xFF8899AA), height: 1.5)),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Cancel', style: TextStyle(color: Color(0xFF8899AA)))),
          TextButton(onPressed: () => Navigator.pop(ctx, true),
              child: Text(isActive ? 'Unenroll' : 'Re-enroll',
                  style: TextStyle(color: isActive ? const Color(0xFFE74C3C) : const Color(0xFF1DB954)))),
        ]));
    if (confirm != true) return;
    try {
      await FirebaseFirestore.instance.collection('StudentCourseSchedule').doc(a['DocID'])
          .update({'IsActive': !isActive, 'UpdatedAt': FieldValue.serverTimestamp()});
      await _load();
      _snack(isActive ? 'Unenrolled.' : 'Re-enrolled!', ok: !isActive);
    } catch (e) { _snack('Failed to update enrollment.'); }
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