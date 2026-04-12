import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'staff_schedule_screen.dart';

class CoursesTab extends StatefulWidget {
  final String clientId;
  final String branchId;
  const CoursesTab({super.key, required this.clientId, required this.branchId});
  @override
  State<CoursesTab> createState() => _CoursesTabState();
}

class _CoursesTabState extends State<CoursesTab> {
  List<Map<String, dynamic>> _courses   = [];
  List<Map<String, dynamic>> _subTypes  = [];
  List<Map<String, dynamic>> _branches  = [];
  List<Map<String, dynamic>> _durations = []; // SubTypeCode='CourseDuration'
  bool _isLoading = true;
  String _filterSubTypeId = 'All';

  @override
  void initState() { super.initState(); _load(); }

  Future<void> _load() async {
    setState(() => _isLoading = true);
    try {
      final db = FirebaseFirestore.instance;

      // Course query — try with orderBy first, fall back without if index not ready
      QuerySnapshot? courseSnap;
      try {
        courseSnap = await db.collection('Course')
            .where('ClientID', isEqualTo: widget.clientId)
            .orderBy('CreatedAt').get();
      } catch (e) {
        debugPrint('Course orderBy query failed, trying without orderBy: $e');
        try {
          courseSnap = await db.collection('Course')
              .where('ClientID', isEqualTo: widget.clientId).get();
        } catch (e2) {
          debugPrint('Course query failed entirely: $e2');
        }
      }

      final results = await Future.wait([
        db.collection('SubType')
            .where('ClientID', isEqualTo: widget.clientId)
            .where('SubTypeCode', isEqualTo: 'Course')
            .where('IsActive', isEqualTo: true)
            .orderBy('CreatedAt').get(),
        db.collection('Branch')
            .where('ClientID', isEqualTo: widget.clientId)
            .where('IsActive', isEqualTo: true)
            .orderBy('CreatedAt').get(),
        db.collection('SubType')
            .where('ClientID', isEqualTo: widget.clientId)
            .where('SubTypeCode', isEqualTo: 'CourseDuration')
            .where('IsActive', isEqualTo: true)
            .orderBy('CreatedAt').get(),
      ]);

      if (mounted) setState(() {
        _courses   = courseSnap?.docs.map((d) =>
            {...(d.data() as Map<String,dynamic>), 'DocID': d.id}).toList() ?? [];
        _subTypes  = (results[0] as QuerySnapshot).docs.map((d) =>
            {...(d.data() as Map<String,dynamic>), 'DocID': d.id}).toList();
        _branches  = (results[1] as QuerySnapshot).docs.map((d) =>
            {...(d.data() as Map<String,dynamic>), 'DocID': d.id}).toList();
        _durations = (results[2] as QuerySnapshot).docs.map((d) =>
            {...(d.data() as Map<String,dynamic>), 'DocID': d.id}).toList();
        _isLoading = false;
      });
    } catch (e) {
      debugPrint('Load error: $e');
      if (mounted) setState(() => _isLoading = false);
    }
  }

  List<Map<String, dynamic>> get _filtered => _filterSubTypeId == 'All'
      ? _courses : _courses.where((c) => c['CourseSubTypeID'] == _filterSubTypeId).toList();

  String _subTypeName(String? id) {
    if (id == null) return '';
    final s = _subTypes.firstWhere((s) => s['DocID'] == id, orElse: () => {});
    return s['SubTypeName'] ?? '';
  }

  String _durationName(String? id) {
    if (id == null) return '';
    final d = _durations.firstWhere((d) => d['DocID'] == id, orElse: () => {});
    return d['SubTypeName'] ?? '';
  }

  String _branchLabel(String? id) {
    if (id == null) return '';
    final b = _branches.firstWhere((b) => b['DocID'] == id, orElse: () => {});
    return b['IsPrimary'] == true ? 'Primary Branch' : b['BranchAddress'] ?? 'Branch';
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(child: Column(children: [
      _topBar(),
      _filterChips(),
      Expanded(child: _isLoading
          ? const Center(child: CircularProgressIndicator(color: Color(0xFF1DB954), strokeWidth: 2))
          : RefreshIndicator(
              onRefresh: _load, color: const Color(0xFF1DB954), backgroundColor: const Color(0xFF152232),
              child: _filtered.isEmpty ? _emptyState() : ListView(
                padding: const EdgeInsets.fromLTRB(20, 8, 20, 100),
                children: [
                  Padding(padding: const EdgeInsets.only(bottom: 12),
                    child: Text('${_filtered.length} ${_filtered.length == 1 ? "Course" : "Courses"}',
                        style: const TextStyle(fontSize: 13, color: Color(0xFF8899AA), fontWeight: FontWeight.w500))),
                  ..._filtered.map((c) => _courseCard(c)),
                ],
              ))),
    ]));
  }

  Widget _topBar() => Padding(
    padding: const EdgeInsets.fromLTRB(20, 16, 20, 8),
    child: Row(children: [
      const Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text('Courses', style: TextStyle(fontFamily: 'Georgia', fontSize: 22, fontWeight: FontWeight.bold, color: Colors.white)),
        Text('Manage your activities', style: TextStyle(fontSize: 12, color: Color(0xFF556677))),
      ])),
      GestureDetector(onTap: () => _showCourseSheet(),
        child: Container(width: 40, height: 40,
          decoration: BoxDecoration(color: const Color(0xFF1DB954).withOpacity(0.12), borderRadius: BorderRadius.circular(12),
            border: Border.all(color: const Color(0xFF1DB954).withOpacity(0.3))),
          child: const Icon(Icons.add_rounded, color: Color(0xFF1DB954), size: 22))),
    ]),
  );

  Widget _filterChips() {
    if (_subTypes.isEmpty) return const SizedBox(height: 8);
    return ClipRect(
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.fromLTRB(20, 4, 20, 8),
        physics: const BouncingScrollPhysics(),
        child: IntrinsicHeight(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              _chip('All', 'All'),
              ..._subTypes.map((s) => _chip(s['DocID'], s['SubTypeName'] ?? '')),
              const SizedBox(width: 20),
            ],
          ),
        ),
      ),
    );
  }

  Widget _chip(String id, String label) {
    final active = _filterSubTypeId == id;
    return GestureDetector(
      onTap: () => setState(() => _filterSubTypeId = id),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        margin: const EdgeInsets.only(right: 8),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        decoration: BoxDecoration(
          color: active ? const Color(0xFF1DB954) : const Color(0xFF152232),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
              color: active ? const Color(0xFF1DB954) : const Color(0xFF1E3347))),
        child: Text(label,
            style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w500,
                color: active ? Colors.white : const Color(0xFF8899AA))),
      ),
    );
  }

  Widget _courseCard(Map<String, dynamic> c) {
    final active = c['IsActive'] != false;
    final stName = _subTypeName(c['CourseSubTypeID']);
    final fee    = c['CourseFee'];
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: const Color(0xFF152232),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: active ? const Color(0xFF1E3347) : const Color(0xFFE74C3C).withOpacity(0.35),
          width: active ? 1 : 1.5,
        ),
      ),
      child: Column(children: [
        // ── Top section: icon + name + fee ───────────────────────────────────
        Padding(padding: const EdgeInsets.all(16), child: Row(children: [
          Container(width: 46, height: 46,
            decoration: BoxDecoration(
              color: active ? const Color(0xFF1DB954).withOpacity(0.12) : const Color(0xFFE74C3C).withOpacity(0.08),
              borderRadius: BorderRadius.circular(13)),
            child: Icon(Icons.menu_book_rounded,
                color: active ? const Color(0xFF1DB954) : const Color(0xFF556677), size: 22)),
          const SizedBox(width: 12),
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(c['CourseName'] ?? '',
                style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600,
                    color: active ? Colors.white : const Color(0xFF8899AA))),
            const SizedBox(height: 4),
            Row(children: [
              if (stName.isNotEmpty) Container(
                padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                decoration: BoxDecoration(
                  color: active ? const Color(0xFF1DB954).withOpacity(0.1) : const Color(0xFF3A5068).withOpacity(0.2),
                  borderRadius: BorderRadius.circular(5)),
                child: Text(stName, style: TextStyle(fontSize: 10,
                    color: active ? const Color(0xFF1DB954) : const Color(0xFF556677)))),
              if (!active) ...[const SizedBox(width: 6), Container(
                padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                decoration: BoxDecoration(color: const Color(0xFFE74C3C).withOpacity(0.1), borderRadius: BorderRadius.circular(5)),
                child: const Text('Inactive', style: TextStyle(fontSize: 10, color: Color(0xFFE74C3C))))],
            ]),
          ])),
          const SizedBox(width: 8),
          Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
            Text(fee != null ? '₹${fee.toString()}' : '—',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold,
                    color: active ? Colors.white : const Color(0xFF556677))),
            const Text('/month', style: TextStyle(fontSize: 10, color: Color(0xFF556677))),
          ]),
        ])),

        // ── Action footer ─────────────────────────────────────────────────────
        Container(
          padding: const EdgeInsets.fromLTRB(12, 8, 12, 8),
          decoration: const BoxDecoration(border: Border(top: BorderSide(color: Color(0xFF1E3347), width: 1))),
          child: Row(children: [
            const Icon(Icons.location_on_outlined, color: Color(0xFF556677), size: 12),
            const SizedBox(width: 3),
            Expanded(child: Text(_branchLabel(c['BranchID']),
                style: const TextStyle(fontSize: 10, color: Color(0xFF556677)),
                overflow: TextOverflow.ellipsis)),
            const SizedBox(width: 8),

            // Edit
            GestureDetector(
              onTap: () => _showCourseSheet(existing: c),
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
                ]),
              ),
            ),
            const SizedBox(width: 6),

            // Activate / Deactivate
            GestureDetector(
              onTap: () => _quickToggle(c, active),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                decoration: BoxDecoration(
                  color: active ? const Color(0xFFE74C3C).withOpacity(0.08) : const Color(0xFF1DB954).withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(
                      color: active ? const Color(0xFFE74C3C).withOpacity(0.3) : const Color(0xFF1DB954).withOpacity(0.3))),
                child: Row(mainAxisSize: MainAxisSize.min, children: [
                  Icon(active ? Icons.pause_circle_outline_rounded : Icons.play_circle_outline_rounded,
                      color: active ? const Color(0xFFE74C3C) : const Color(0xFF1DB954), size: 12),
                  const SizedBox(width: 4),
                  Text(active ? 'Deactivate' : 'Activate',
                      style: TextStyle(fontSize: 11, fontWeight: FontWeight.w500,
                          color: active ? const Color(0xFFE74C3C) : const Color(0xFF1DB954))),
                ]),
              ),
            ),
            const SizedBox(width: 6),

            // Schedules arrow
            GestureDetector(
              onTap: () => Navigator.push(context, MaterialPageRoute(
                  builder: (_) => CourseDetailScreen(
                      course: c, clientId: widget.clientId, branchId: widget.branchId,
                      branches: _branches, subTypeName: stName,
                      branchName: _branchLabel(c['BranchID']),
                      durationName: _durationName(c['CourseDurationSubTypeID']),
                      onUpdated: _load))),
              child: Container(
                width: 30, height: 30,
                decoration: BoxDecoration(
                  color: const Color(0xFF1DB954).withOpacity(0.08),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: const Color(0xFF1DB954).withOpacity(0.2))),
                child: const Icon(Icons.calendar_today_outlined, color: Color(0xFF1DB954), size: 14),
              ),
            ),
          ]),
        ),
      ]),
    );
  }

  Future<void> _quickToggle(Map<String, dynamic> c, bool isActive) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF152232),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Text(isActive ? 'Deactivate course?' : 'Activate course?',
            style: const TextStyle(color: Colors.white, fontFamily: 'Georgia')),
        content: Text(
          isActive
              ? '"${c['CourseName']}" will be hidden from enrollment.'
              : '"${c['CourseName']}" will be available for enrollment.',
          style: const TextStyle(color: Color(0xFF8899AA), height: 1.5),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Cancel', style: TextStyle(color: Color(0xFF8899AA)))),
          TextButton(onPressed: () => Navigator.pop(ctx, true),
              child: Text(isActive ? 'Deactivate' : 'Activate',
                  style: TextStyle(color: isActive ? const Color(0xFFE74C3C) : const Color(0xFF1DB954)))),
        ],
      ),
    );
    if (confirm != true) return;
    try {
      await FirebaseFirestore.instance.collection('Course').doc(c['DocID'])
          .update({'IsActive': !isActive, 'UpdatedAt': FieldValue.serverTimestamp()});
      await _load();
      _snack(isActive ? 'Course deactivated.' : 'Course activated!', ok: !isActive);
    } catch (e) {
      _snack('Failed to update course status.');
    }
  }

  Widget _emptyState() {
    final noST = _subTypes.isEmpty;
    return ListView(padding: const EdgeInsets.all(32), children: [
      const SizedBox(height: 40),
      Center(child: Column(children: [
        Container(width: 72, height: 72,
          decoration: BoxDecoration(color: const Color(0xFF1DB954).withOpacity(0.08), borderRadius: BorderRadius.circular(20)),
          child: const Icon(Icons.menu_book_outlined, color: Color(0xFF3A5068), size: 36)),
        const SizedBox(height: 20),
        Text(noST ? 'Set up activities first' : 'No courses yet',
            style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w600, color: Colors.white, fontFamily: 'Georgia')),
        const SizedBox(height: 8),
        Text(noST ? 'Go to More → Sub Types and add\ncourse activities first.' : 'Tap + to add your first course.',
            textAlign: TextAlign.center, style: const TextStyle(fontSize: 13, color: Color(0xFF556677), height: 1.5)),
      ])),
    ]);
  }

  void _showCourseSheet({Map<String, dynamic>? existing}) {
    if (_subTypes.isEmpty) { _snack('Add course activities in More → Sub Types first.'); return; }
    final isEdit    = existing != null;
    final nameCtrl  = TextEditingController(text: existing?['CourseName'] ?? '');
    final feeCtrl   = TextEditingController(text: existing?['CourseFee']?.toString() ?? '');
    String? stId    = existing?['CourseSubTypeID'] ?? _subTypes.first['DocID'];
    String? brId    = existing?['BranchID'] ?? widget.branchId;
    String? durId   = existing?['CourseDurationSubTypeID'] ??
        (_durations.isNotEmpty ? _durations.first['DocID'] : null);
    bool saving     = false;

    showModalBottomSheet(context: context, isScrollControlled: true, backgroundColor: Colors.transparent,
      builder: (ctx) => StatefulBuilder(builder: (ctx, ss) => Padding(
        padding: EdgeInsets.only(bottom: MediaQuery.of(ctx).viewInsets.bottom),
        child: Container(
          decoration: const BoxDecoration(color: Color(0xFF152232), borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
          padding: const EdgeInsets.all(24),
          child: SingleChildScrollView(child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
            Center(child: Container(width: 40, height: 4, decoration: BoxDecoration(color: const Color(0xFF1E3347), borderRadius: BorderRadius.circular(2)))),
            const SizedBox(height: 20),
            Row(children: [
              Container(width: 36, height: 36, decoration: BoxDecoration(color: const Color(0xFF1DB954).withOpacity(0.12), borderRadius: BorderRadius.circular(10)),
                child: const Icon(Icons.menu_book_rounded, color: Color(0xFF1DB954), size: 18)),
              const SizedBox(width: 12),
              Text(isEdit ? 'Edit Course' : 'Add New Course',
                  style: const TextStyle(fontFamily: 'Georgia', fontSize: 18, fontWeight: FontWeight.bold, color: Colors.white)),
            ]),
            const SizedBox(height: 24),

            _lbl('Activity Type *'), const SizedBox(height: 8),
            _dd(value: stId, items: _subTypes, lk: 'SubTypeName', vk: 'DocID',
                hint: 'Select activity', onChanged: (v) => ss(() => stId = v)),
            const SizedBox(height: 14),

            _lbl('Course Name *'), const SizedBox(height: 8),
            _tf(ctrl: nameCtrl, hint: 'e.g. Yoga Morning Batch'),
            const SizedBox(height: 14),

            _lbl('Course Fee (₹ / month) *'), const SizedBox(height: 8),
            _tf(ctrl: feeCtrl, hint: 'e.g. 1200', kb: TextInputType.number),
            const SizedBox(height: 14),

            _lbl('Course Duration *'), const SizedBox(height: 8),
            _durations.isEmpty
                ? Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: const Color(0xFFE74C3C).withOpacity(0.08),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: const Color(0xFFE74C3C).withOpacity(0.3))),
                    child: const Text(
                      'No durations found.\nGo to More → Sub Types → Course Duration.',
                      style: TextStyle(fontSize: 12, color: Color(0xFFE74C3C), height: 1.4)))
                : _dd(value: durId, items: _durations, lk: 'SubTypeName', vk: 'DocID',
                    hint: 'Select duration', onChanged: (v) => ss(() => durId = v)),

            if (_branches.length > 1) ...[
              const SizedBox(height: 14),
              _lbl('Branch *'), const SizedBox(height: 8),
              _dd(value: brId, items: _branches, lk: 'BranchAddress', vk: 'DocID',
                  hint: 'Select branch', onChanged: (v) => ss(() => brId = v),
                  lb: (b) => b['IsPrimary'] == true ? 'Primary Branch' : b['BranchAddress'] ?? 'Branch'),
            ],
            const SizedBox(height: 24),

            Row(children: [
              Expanded(child: OutlinedButton(onPressed: () => Navigator.pop(ctx),
                style: OutlinedButton.styleFrom(foregroundColor: const Color(0xFF8899AA),
                  side: const BorderSide(color: Color(0xFF1E3347)),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                  padding: const EdgeInsets.symmetric(vertical: 14)),
                child: const Text('Cancel'))),
              const SizedBox(width: 12),
              Expanded(flex: 2, child: ElevatedButton(
                onPressed: saving ? null : () async {
                  if (stId == null) { _snack('Select an activity type.'); return; }
                  if (nameCtrl.text.trim().isEmpty) { _snack('Course name is required.'); return; }
                  final fee = double.tryParse(feeCtrl.text.trim());
                  if (fee == null || fee <= 0) { _snack('Enter a valid course fee.'); return; }
                  if (durId == null) { _snack('Select a course duration.'); return; }
                  ss(() => saving = true);
                  try {
                    final db = FirebaseFirestore.instance;
                    if (isEdit) {
                      await db.collection('Course').doc(existing!['DocID']).update({
                        'CourseSubTypeID': stId,
                        'CourseName': nameCtrl.text.trim(),
                        'CourseFee': fee,
                        'CourseDurationSubTypeID': durId,
                        'BranchID': brId,
                        'UpdatedAt': FieldValue.serverTimestamp()});
                    } else {
                      final ref = db.collection('Course').doc();
                      await ref.set({
                        'CourseID': ref.id,
                        'ClientID': widget.clientId,
                        'BranchID': brId,
                        'CourseSubTypeID': stId,
                        'CourseName': nameCtrl.text.trim(),
                        'CourseFee': fee,
                        'CourseDurationSubTypeID': durId,
                        'IsActive': true,
                        'CreatedAt': FieldValue.serverTimestamp()});
                    }
                    if (ctx.mounted) Navigator.pop(ctx);
                    await _load();
                    _snack(isEdit ? 'Course updated!' : 'Course added!', ok: true);
                  } catch (e) { _snack('Failed. Please try again.'); ss(() => saving = false); }
                },
                style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF1DB954), foregroundColor: Colors.white,
                  elevation: 0, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                  padding: const EdgeInsets.symmetric(vertical: 14)),
                child: saving
                    ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                    : Text(isEdit ? 'Update' : 'Save Course',
                        style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600)))),
            ]),
            const SizedBox(height: 8),
          ])),
        ),
      )));
  }

  Widget _dd({required String? value, required List<Map<String,dynamic>> items, required String lk, required String vk,
      required String hint, required ValueChanged<String?> onChanged, String Function(Map<String,dynamic>)? lb}) {
    return Container(
      decoration: BoxDecoration(color: const Color(0xFF0D1B2A), borderRadius: BorderRadius.circular(12),
        border: Border.all(color: value != null ? const Color(0xFF1DB954) : const Color(0xFF1E3347), width: value != null ? 1.5 : 1)),
      child: DropdownButtonHideUnderline(child: DropdownButton<String>(
        value: value, isExpanded: true, dropdownColor: const Color(0xFF152232),
        padding: const EdgeInsets.symmetric(horizontal: 12),
        hint: Text(hint, style: const TextStyle(color: Color(0xFF3A5068), fontSize: 14)),
        icon: const Icon(Icons.keyboard_arrow_down_rounded, color: Color(0xFF556677)),
        items: items.map((i) => DropdownMenuItem<String>(value: i[vk] as String,
            child: Text(lb != null ? lb(i) : i[lk] ?? '', style: const TextStyle(color: Colors.white, fontSize: 14)))).toList(),
        onChanged: onChanged)));
  }

  Widget _lbl(String t) => Text(t, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w500, color: Color(0xFF8899AA)));

  Widget _tf({required TextEditingController ctrl, required String hint, TextInputType kb = TextInputType.text}) =>
    TextField(controller: ctrl, keyboardType: kb, style: const TextStyle(color: Colors.white, fontSize: 15),
      cursorColor: const Color(0xFF1DB954),
      decoration: InputDecoration(hintText: hint, hintStyle: const TextStyle(color: Color(0xFF3A5068), fontSize: 15),
        filled: true, fillColor: const Color(0xFF0D1B2A), contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: Color(0xFF1E3347), width: 1)),
        enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: Color(0xFF1E3347), width: 1)),
        focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: Color(0xFF1DB954), width: 1.5))));

  void _snack(String msg, {bool ok = false}) => ScaffoldMessenger.of(context).showSnackBar(SnackBar(
    content: Text(msg, style: const TextStyle(color: Colors.white, fontSize: 14)),
    backgroundColor: ok ? const Color(0xFF2ECC71) : const Color(0xFFE74C3C),
    behavior: SnackBarBehavior.floating,
    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)), margin: const EdgeInsets.all(16)));
}

// ══════════════════════════════════════════════════════════════════════════════
// Course Detail Screen
// ══════════════════════════════════════════════════════════════════════════════
class CourseDetailScreen extends StatefulWidget {
  final Map<String, dynamic> course;
  final String clientId;
  final String branchId;
  final List<Map<String, dynamic>> branches;
  final String subTypeName;
  final String branchName;
  final String durationName;
  final VoidCallback onUpdated;

  const CourseDetailScreen({super.key, required this.course, required this.clientId, required this.branchId,
      required this.branches, required this.subTypeName, required this.branchName,
      this.durationName = '', required this.onUpdated});

  @override
  State<CourseDetailScreen> createState() => _CourseDetailScreenState();
}

class _CourseDetailScreenState extends State<CourseDetailScreen> {
  List<Map<String, dynamic>> _schedules = [];
  List<Map<String, dynamic>> _timings   = [];
  bool _isLoading = true;

  @override
  void initState() { super.initState(); _load(); }

  Future<void> _load() async {
    setState(() => _isLoading = true);
    try {
      final db = FirebaseFirestore.instance;
      final results = await Future.wait([
        db.collection('CourseSchedule').where('CourseID', isEqualTo: widget.course['DocID']).orderBy('CreatedAt').get(),
        db.collection('SubType').where('ClientID', isEqualTo: widget.clientId).where('SubTypeCode', isEqualTo: 'Timings').where('IsActive', isEqualTo: true).orderBy('CreatedAt').get(),
      ]);
      if (mounted) setState(() {
        _schedules = (results[0] as QuerySnapshot).docs.map((d) => {...(d.data() as Map<String,dynamic>), 'DocID': d.id}).toList();
        _timings   = (results[1] as QuerySnapshot).docs.map((d) => {...(d.data() as Map<String,dynamic>), 'DocID': d.id}).toList();
        _isLoading = false;
      });
    } catch (e) { if (mounted) setState(() => _isLoading = false); }
  }

  String _timingName(String? id) {
    if (id == null) return '—';
    final t = _timings.firstWhere((t) => t['DocID'] == id, orElse: () => {});
    return t['SubTypeName'] ?? '—';
  }

  @override
  Widget build(BuildContext context) {
    final c = widget.course;
    final isActive = c['IsActive'] != false;
    final fee = c['CourseFee'];
    return Scaffold(backgroundColor: const Color(0xFF0D1B2A),
      body: SafeArea(child: Column(children: [
        Padding(padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          child: Row(children: [
            GestureDetector(onTap: () => Navigator.pop(context),
              child: Container(width: 40, height: 40,
                decoration: BoxDecoration(color: const Color(0xFF152232), borderRadius: BorderRadius.circular(12), border: Border.all(color: const Color(0xFF1E3347))),
                child: const Icon(Icons.arrow_back_ios_new_rounded, color: Color(0xFF8899AA), size: 18))),
            const SizedBox(width: 14),
            Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(c['CourseName'] ?? '', style: const TextStyle(fontFamily: 'Georgia', fontSize: 18, fontWeight: FontWeight.bold, color: Colors.white)),
              Text(widget.subTypeName, style: const TextStyle(fontSize: 12, color: Color(0xFF556677))),
            ])),
          ])),
        Expanded(child: _isLoading
          ? const Center(child: CircularProgressIndicator(color: Color(0xFF1DB954), strokeWidth: 2))
          : RefreshIndicator(onRefresh: _load, color: const Color(0xFF1DB954), backgroundColor: const Color(0xFF152232),
            child: ListView(padding: const EdgeInsets.fromLTRB(20, 0, 20, 100), children: [
              _infoCard(c, isActive, fee),
              const SizedBox(height: 24),
              Row(children: [
                const Expanded(child: Text('Schedules / Batches', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600, color: Colors.white))),
                GestureDetector(onTap: () => _showScheduleSheet(),
                  child: Container(height: 34, padding: const EdgeInsets.symmetric(horizontal: 14),
                    decoration: BoxDecoration(color: const Color(0xFF1DB954).withOpacity(0.12), borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: const Color(0xFF1DB954).withOpacity(0.3))),
                    child: const Row(children: [
                      Icon(Icons.add_rounded, color: Color(0xFF1DB954), size: 16),
                      SizedBox(width: 4),
                      Text('Add Batch', style: TextStyle(fontSize: 12, color: Color(0xFF1DB954), fontWeight: FontWeight.w500)),
                    ]))),
              ]),
              const SizedBox(height: 12),
              if (_schedules.isEmpty) _emptySchedule()
              else ..._schedules.map((s) => _scheduleCard(s)),
            ]))),
      ])));
  }

  Widget _infoCard(Map<String,dynamic> c, bool isActive, dynamic fee) {
    return Container(padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(color: const Color(0xFF152232), borderRadius: BorderRadius.circular(18), border: Border.all(color: const Color(0xFF1E3347))),
      child: Column(children: [
        _row(Icons.payments_outlined, 'Course Fee', fee != null ? '₹${fee.toString()} / month' : '—', const Color(0xFF1DB954)),
        const SizedBox(height: 12),
        _row(Icons.date_range_outlined, 'Duration',
            widget.durationName.isNotEmpty ? widget.durationName : '—',
            const Color(0xFF7F77DD)),
        const SizedBox(height: 12),
        _row(Icons.location_on_outlined, 'Branch', widget.branchName, const Color(0xFF5BA3D9)),
        const SizedBox(height: 12),
        _row(isActive ? Icons.check_circle_outline_rounded : Icons.cancel_outlined, 'Status',
            isActive ? 'Active' : 'Inactive', isActive ? const Color(0xFF1DB954) : const Color(0xFFE74C3C)),
        const SizedBox(height: 14),
        GestureDetector(onTap: () => _toggleCourse(c, isActive),
          child: Container(width: double.infinity, padding: const EdgeInsets.symmetric(vertical: 10),
            decoration: BoxDecoration(
              color: isActive ? const Color(0xFFE74C3C).withOpacity(0.08) : const Color(0xFF1DB954).withOpacity(0.08),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: isActive ? const Color(0xFFE74C3C).withOpacity(0.3) : const Color(0xFF1DB954).withOpacity(0.3))),
            child: Center(child: Text(isActive ? 'Deactivate Course' : 'Activate Course',
                style: TextStyle(fontSize: 13, fontWeight: FontWeight.w500,
                    color: isActive ? const Color(0xFFE74C3C) : const Color(0xFF1DB954)))))),
      ]));
  }

  Widget _row(IconData icon, String label, String value, Color color) {
    return Row(children: [
      Container(width: 32, height: 32, decoration: BoxDecoration(color: color.withOpacity(0.1), borderRadius: BorderRadius.circular(8)),
        child: Icon(icon, color: color, size: 16)),
      const SizedBox(width: 12),
      Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(label, style: const TextStyle(fontSize: 10, color: Color(0xFF556677))),
        Text(value, style: const TextStyle(fontSize: 13, color: Colors.white, fontWeight: FontWeight.w500)),
      ])),
    ]);
  }

  Widget _emptySchedule() => GestureDetector(onTap: _showScheduleSheet,
    child: Container(padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(color: const Color(0xFF1DB954).withOpacity(0.05), borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFF1DB954).withOpacity(0.3))),
      child: const Row(mainAxisAlignment: MainAxisAlignment.center, children: [
        Icon(Icons.add_circle_outline_rounded, color: Color(0xFF1DB954), size: 18),
        SizedBox(width: 8),
        Text('Add first batch / schedule', style: TextStyle(fontSize: 13, color: Color(0xFF1DB954))),
      ])));

  Widget _scheduleCard(Map<String, dynamic> s) {
    final isActive = s['IsActive'] != false;
    final days = (s['DaysOfWeek'] as List?)?.cast<String>() ?? [];
    return Container(margin: const EdgeInsets.only(bottom: 10), padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(color: const Color(0xFF152232), borderRadius: BorderRadius.circular(16), border: Border.all(color: const Color(0xFF1E3347))),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Container(width: 36, height: 36,
            decoration: BoxDecoration(color: const Color(0xFF5BA3D9).withOpacity(0.12), borderRadius: BorderRadius.circular(10)),
            child: const Icon(Icons.calendar_today_outlined, color: Color(0xFF5BA3D9), size: 18)),
          const SizedBox(width: 12),
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(s['BatchName'] ?? 'Batch', style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: Colors.white)),
            Text(_timingName(s['TimingsSubTypeID']), style: const TextStyle(fontSize: 11, color: Color(0xFF556677))),
          ])),
          Container(padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
            decoration: BoxDecoration(
              color: isActive ? const Color(0xFF1DB954).withOpacity(0.1) : const Color(0xFFE74C3C).withOpacity(0.1),
              borderRadius: BorderRadius.circular(6)),
            child: Text(isActive ? 'Active' : 'Inactive',
                style: TextStyle(fontSize: 10, color: isActive ? const Color(0xFF1DB954) : const Color(0xFFE74C3C)))),
          const SizedBox(width: 8),
          GestureDetector(onTap: () => _showScheduleSheet(existing: s),
            child: Container(width: 30, height: 30,
              decoration: BoxDecoration(color: const Color(0xFF5BA3D9).withOpacity(0.12), borderRadius: BorderRadius.circular(8)),
              child: const Icon(Icons.edit_outlined, color: Color(0xFF5BA3D9), size: 15))),
        ]),
        if (days.isNotEmpty) ...[
          const SizedBox(height: 12),
          Wrap(spacing: 6, runSpacing: 6, children: days.map((d) => Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            decoration: BoxDecoration(color: const Color(0xFF0D1B2A), borderRadius: BorderRadius.circular(6), border: Border.all(color: const Color(0xFF1E3347))),
            child: Text(d, style: const TextStyle(fontSize: 11, color: Color(0xFF8899AA))))).toList()),
        ],
        const SizedBox(height: 10),
        Row(children: [
          const Icon(Icons.people_outline_rounded, color: Color(0xFF556677), size: 14),
          const SizedBox(width: 4),
          Text('Max ${s['MaxStudents'] ?? 0} students',
              style: const TextStyle(fontSize: 11, color: Color(0xFF556677))),
          const Spacer(),
          // View Staff button
          GestureDetector(
            onTap: () => Navigator.push(context, MaterialPageRoute(
                builder: (_) => ScheduleStaffScreen(
                    clientId: widget.clientId,
                    branchId: widget.branchId,
                    schedule: s,
                    courseName: widget.course['CourseName'] ?? ''))),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
              decoration: BoxDecoration(
                color: const Color(0xFFE8A020).withOpacity(0.1),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: const Color(0xFFE8A020).withOpacity(0.3))),
              child: const Row(mainAxisSize: MainAxisSize.min, children: [
                Icon(Icons.badge_outlined, color: Color(0xFFE8A020), size: 13),
                SizedBox(width: 4),
                Text('Staff', style: TextStyle(fontSize: 11, color: Color(0xFFE8A020), fontWeight: FontWeight.w500)),
              ]))),
        ]),
      ]));
  }

  void _showScheduleSheet({Map<String, dynamic>? existing}) {
    if (_timings.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
        content: Text('Add timing slots in More → Sub Types first.', style: TextStyle(color: Colors.white)),
        backgroundColor: Color(0xFFE74C3C)));
      return;
    }
    final isEdit  = existing != null;
    final bCtrl   = TextEditingController(text: existing?['BatchName'] ?? '');
    final mCtrl   = TextEditingController(text: existing?['MaxStudents']?.toString() ?? '');
    String? tId   = existing?['TimingsSubTypeID'] ?? _timings.first['DocID'];
    final days    = List<String>.from((existing?['DaysOfWeek'] as List?)?.cast<String>() ?? []);
    bool saving   = false;
    const allDays = ['Mon','Tue','Wed','Thu','Fri','Sat','Sun'];

    showModalBottomSheet(context: context, isScrollControlled: true, backgroundColor: Colors.transparent,
      builder: (ctx) => StatefulBuilder(builder: (ctx, ss) => Padding(
        padding: EdgeInsets.only(bottom: MediaQuery.of(ctx).viewInsets.bottom),
        child: Container(
          decoration: const BoxDecoration(color: Color(0xFF152232), borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
          padding: const EdgeInsets.all(24),
          child: SingleChildScrollView(child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
            Center(child: Container(width: 40, height: 4, decoration: BoxDecoration(color: const Color(0xFF1E3347), borderRadius: BorderRadius.circular(2)))),
            const SizedBox(height: 20),
            Row(children: [
              Container(width: 36, height: 36, decoration: BoxDecoration(color: const Color(0xFF5BA3D9).withOpacity(0.12), borderRadius: BorderRadius.circular(10)),
                child: const Icon(Icons.calendar_today_outlined, color: Color(0xFF5BA3D9), size: 18)),
              const SizedBox(width: 12),
              Text(isEdit ? 'Edit Batch' : 'Add Batch / Schedule',
                  style: const TextStyle(fontFamily: 'Georgia', fontSize: 18, fontWeight: FontWeight.bold, color: Colors.white)),
            ]),
            const SizedBox(height: 24),
            _lbl('Batch Name *'), const SizedBox(height: 8),
            _tf(ctrl: bCtrl, hint: 'e.g. Morning Batch A'),
            const SizedBox(height: 14),
            _lbl('Timing *'), const SizedBox(height: 8),
            Container(
              decoration: BoxDecoration(color: const Color(0xFF0D1B2A), borderRadius: BorderRadius.circular(12),
                border: Border.all(color: tId != null ? const Color(0xFF1DB954) : const Color(0xFF1E3347), width: tId != null ? 1.5 : 1)),
              child: DropdownButtonHideUnderline(child: DropdownButton<String>(
                value: tId, isExpanded: true, dropdownColor: const Color(0xFF152232),
                padding: const EdgeInsets.symmetric(horizontal: 12),
                hint: const Text('Select timing', style: TextStyle(color: Color(0xFF3A5068), fontSize: 14)),
                icon: const Icon(Icons.keyboard_arrow_down_rounded, color: Color(0xFF556677)),
                items: _timings.map((t) => DropdownMenuItem<String>(value: t['DocID'] as String,
                    child: Text(t['SubTypeName'] ?? '', style: const TextStyle(color: Colors.white, fontSize: 14)))).toList(),
                onChanged: (v) => ss(() => tId = v)))),
            const SizedBox(height: 14),
            _lbl('Days of Week *'), const SizedBox(height: 10),
            Wrap(spacing: 8, runSpacing: 8, children: allDays.map((d) {
              final sel = days.contains(d);
              return GestureDetector(onTap: () => ss(() => sel ? days.remove(d) : days.add(d)),
                child: AnimatedContainer(duration: const Duration(milliseconds: 150), width: 44, height: 44,
                  decoration: BoxDecoration(
                    color: sel ? const Color(0xFF1DB954) : const Color(0xFF0D1B2A),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: sel ? const Color(0xFF1DB954) : const Color(0xFF1E3347))),
                  child: Center(child: Text(d, style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: sel ? Colors.white : const Color(0xFF556677))))));
            }).toList()),
            const SizedBox(height: 14),
            _lbl('Max Students'), const SizedBox(height: 8),
            _tf(ctrl: mCtrl, hint: 'e.g. 15', kb: TextInputType.number),
            const SizedBox(height: 24),
            Row(children: [
              Expanded(child: OutlinedButton(onPressed: () => Navigator.pop(ctx),
                style: OutlinedButton.styleFrom(foregroundColor: const Color(0xFF8899AA),
                  side: const BorderSide(color: Color(0xFF1E3347)),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                  padding: const EdgeInsets.symmetric(vertical: 14)),
                child: const Text('Cancel'))),
              const SizedBox(width: 12),
              Expanded(flex: 2, child: ElevatedButton(
                onPressed: saving ? null : () async {
                  if (bCtrl.text.trim().isEmpty) { ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Batch name required.'))); return; }
                  if (days.isEmpty) { ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Select at least one day.'))); return; }
                  ss(() => saving = true);
                  try {
                    final db = FirebaseFirestore.instance;
                    final maxS = int.tryParse(mCtrl.text.trim()) ?? 0;
                    if (isEdit) {
                      await db.collection('CourseSchedule').doc(existing!['DocID']).update({
                        'BatchName': bCtrl.text.trim(), 'TimingsSubTypeID': tId,
                        'DaysOfWeek': days, 'MaxStudents': maxS, 'UpdatedAt': FieldValue.serverTimestamp()});
                    } else {
                      final ref = db.collection('CourseSchedule').doc();
                      await ref.set({'CourseScheduleID': ref.id, 'ClientID': widget.clientId,
                        'BranchID': widget.branchId, 'CourseID': widget.course['DocID'],
                        'BatchName': bCtrl.text.trim(), 'TimingsSubTypeID': tId,
                        'DaysOfWeek': days, 'MaxStudents': maxS, 'IsActive': true, 'CreatedAt': FieldValue.serverTimestamp()});
                    }
                    if (ctx.mounted) Navigator.pop(ctx);
                    await _load();
                  } catch (e) { ss(() => saving = false); }
                },
                style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF1DB954), foregroundColor: Colors.white,
                  elevation: 0, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                  padding: const EdgeInsets.symmetric(vertical: 14)),
                child: saving ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                    : Text(isEdit ? 'Update' : 'Save Batch', style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600)))),
            ]),
            const SizedBox(height: 8),
          ])),
        ))));
  }

  Future<void> _toggleCourse(Map<String,dynamic> c, bool isActive) async {
    final confirm = await showDialog<bool>(context: context,
      builder: (ctx) => AlertDialog(backgroundColor: const Color(0xFF152232),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Text(isActive ? 'Deactivate course?' : 'Activate course?',
            style: const TextStyle(color: Colors.white, fontFamily: 'Georgia')),
        content: Text(isActive ? 'Course hidden from enrollment.' : 'Course available for enrollment.',
            style: const TextStyle(color: Color(0xFF8899AA), height: 1.5)),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel', style: TextStyle(color: Color(0xFF8899AA)))),
          TextButton(onPressed: () => Navigator.pop(ctx, true),
            child: Text(isActive ? 'Deactivate' : 'Activate',
                style: TextStyle(color: isActive ? const Color(0xFFE74C3C) : const Color(0xFF1DB954)))),
        ]));
    if (confirm != true) return;
    await FirebaseFirestore.instance.collection('Course').doc(c['DocID'])
        .update({'IsActive': !isActive, 'UpdatedAt': FieldValue.serverTimestamp()});
    widget.onUpdated();
    if (mounted) Navigator.pop(context);
  }

  Widget _lbl(String t) => Text(t, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w500, color: Color(0xFF8899AA)));

  Widget _tf({required TextEditingController ctrl, required String hint, TextInputType kb = TextInputType.text}) =>
    TextField(controller: ctrl, keyboardType: kb, style: const TextStyle(color: Colors.white, fontSize: 15),
      cursorColor: const Color(0xFF1DB954),
      decoration: InputDecoration(hintText: hint, hintStyle: const TextStyle(color: Color(0xFF3A5068), fontSize: 15),
        filled: true, fillColor: const Color(0xFF0D1B2A), contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: Color(0xFF1E3347), width: 1)),
        enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: Color(0xFF1E3347), width: 1)),
        focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: Color(0xFF1DB954), width: 1.5))));
}