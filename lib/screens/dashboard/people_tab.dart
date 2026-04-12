import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'staff_schedule_screen.dart';
import 'student_section.dart';

class PeopleTab extends StatefulWidget {
  final String clientId;
  final String branchId;
  const PeopleTab({super.key, required this.clientId, required this.branchId});

  @override
  State<PeopleTab> createState() => _PeopleTabState();
}

class _PeopleTabState extends State<PeopleTab> with SingleTickerProviderStateMixin {
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Column(children: [
        // Header
        const Padding(
          padding: EdgeInsets.fromLTRB(20, 16, 20, 0),
          child: Row(children: [
            Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text('People', style: TextStyle(fontFamily: 'Georgia', fontSize: 22, fontWeight: FontWeight.bold, color: Colors.white)),
              Text('Staff & Students', style: TextStyle(fontSize: 12, color: Color(0xFF556677))),
            ]),
          ]),
        ),
        // Tab bar
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 14, 20, 0),
          child: Container(
            height: 42,
            decoration: BoxDecoration(
              color: const Color(0xFF152232),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: const Color(0xFF1E3347)),
            ),
            child: TabBar(
              controller: _tabController,
              indicator: BoxDecoration(color: const Color(0xFF1DB954), borderRadius: BorderRadius.circular(10)),
              indicatorSize: TabBarIndicatorSize.tab,
              dividerColor: Colors.transparent,
              labelColor: Colors.white,
              unselectedLabelColor: const Color(0xFF556677),
              labelStyle: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
              unselectedLabelStyle: const TextStyle(fontSize: 13),
              tabs: const [Tab(text: 'Staff'), Tab(text: 'Students')],
            ),
          ),
        ),
        const SizedBox(height: 12),
        Expanded(
          child: TabBarView(
            controller: _tabController,
            children: [
              StaffSection(clientId: widget.clientId, branchId: widget.branchId),
              StudentSection(clientId: widget.clientId, branchId: widget.branchId),
            ],
          ),
        ),
      ]),
    );
  }
}

class _ComingSoon extends StatelessWidget {
  final String label;
  const _ComingSoon({required this.label});
  @override
  Widget build(BuildContext context) => Center(
    child: Column(mainAxisSize: MainAxisSize.min, children: [
      Container(width: 64, height: 64,
        decoration: BoxDecoration(color: const Color(0xFF1DB954).withOpacity(0.08), borderRadius: BorderRadius.circular(18)),
        child: const Icon(Icons.people_outline_rounded, color: Color(0xFF3A5068), size: 32)),
      const SizedBox(height: 16),
      Text(label, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w600, color: Colors.white, fontFamily: 'Georgia')),
      const SizedBox(height: 6),
      const Text('Coming next...', style: TextStyle(fontSize: 13, color: Color(0xFF556677))),
    ]),
  );
}

// ══════════════════════════════════════════════════════════════════════════════
// Staff Section
// ══════════════════════════════════════════════════════════════════════════════
class StaffSection extends StatefulWidget {
  final String clientId;
  final String branchId;
  const StaffSection({super.key, required this.clientId, required this.branchId});
  @override
  State<StaffSection> createState() => _StaffSectionState();
}

class _StaffSectionState extends State<StaffSection> {
  List<Map<String, dynamic>> _staff    = [];
  List<Map<String, dynamic>> _roles    = [];
  List<Map<String, dynamic>> _payTypes = [];
  List<Map<String, dynamic>> _revShare = [];
  List<Map<String, dynamic>> _branches = [];
  bool _isLoading = true;
  String _filter  = 'All';

  @override
  void initState() { super.initState(); _load(); }

  Future<void> _load() async {
    setState(() => _isLoading = true);
    try {
      final db = FirebaseFirestore.instance;
      QuerySnapshot? staffSnap;
      try {
        staffSnap = await db.collection('Staff')
            .where('ClientID', isEqualTo: widget.clientId)
            .orderBy('CreatedAt').get();
      } catch (_) {
        staffSnap = await db.collection('Staff')
            .where('ClientID', isEqualTo: widget.clientId).get();
      }

      final results = await Future.wait([
        db.collection('TypeMaster').where('TypeCode', isEqualTo: 'Role').get(),
        db.collection('TypeMaster').where('TypeCode', isEqualTo: 'PayrollType').get(),
        db.collection('SubType')
            .where('ClientID', isEqualTo: widget.clientId)
            .where('SubTypeCode', isEqualTo: 'RevenueShare')
            .where('IsActive', isEqualTo: true)
            .orderBy('CreatedAt').get(),
        db.collection('Branch')
            .where('ClientID', isEqualTo: widget.clientId)
            .where('IsActive', isEqualTo: true)
            .orderBy('CreatedAt').get(),
      ]);

      if (mounted) setState(() {
        _staff    = staffSnap!.docs.map((d) => {...(d.data() as Map<String,dynamic>), 'DocID': d.id}).toList();
        _roles    = (results[0] as QuerySnapshot).docs
            .map((d) => {...(d.data() as Map<String,dynamic>), 'DocID': d.id})
            .toList()
            ..sort((a, b) => (a['TypeID'] as num).compareTo(b['TypeID'] as num));
        _payTypes = (results[1] as QuerySnapshot).docs
            .map((d) => {...(d.data() as Map<String,dynamic>), 'DocID': d.id})
            .toList()
            ..sort((a, b) => (a['TypeID'] as num).compareTo(b['TypeID'] as num));
        _revShare = (results[2] as QuerySnapshot).docs.map((d) => {...(d.data() as Map<String,dynamic>), 'DocID': d.id}).toList();
        _branches = (results[3] as QuerySnapshot).docs.map((d) => {...(d.data() as Map<String,dynamic>), 'DocID': d.id}).toList();
        _isLoading = false;
      });
    } catch (e) {
      debugPrint('Staff load error: $e');
      if (mounted) setState(() => _isLoading = false);
    }
  }

  // ── Secondary App Helper ───────────────────────────────────────────────────
  Future<FirebaseApp> _getSecondaryApp() async {
    try {
      return await Firebase.initializeApp(
        name: 'secondaryAuth',
        options: Firebase.app().options,
      );
    } catch (_) {
      return Firebase.app('secondaryAuth');
    }
  }

  List<Map<String, dynamic>> get _filtered =>
      _filter == 'All' ? _staff : _staff.where((s) => s['Role'] == _filter).toList();

  List<String> get _roleFilters =>
      _staff.map((s) => s['Role']?.toString() ?? '').where((r) => r.isNotEmpty).toSet().toList()..sort();

  String _payTypeName(dynamic id) {
    if (id == null) return '';
    final p = _payTypes.firstWhere((p) => p['TypeID'].toString() == id.toString(), orElse: () => {});
    return p['TypeName'] ?? '';
  }

  String _branchLabel(String? id) {
    if (id == null) return '';
    final b = _branches.firstWhere((b) => b['DocID'] == id, orElse: () => {});
    return b['IsPrimary'] == true ? 'Primary Branch' : b['BranchAddress'] ?? 'Branch';
  }

  bool _isMonthlyFixed(String? payTypeId) {
    if (payTypeId == null) return true;
    final p = _payTypes.firstWhere((p) => p['TypeID'].toString() == payTypeId, orElse: () => {});
    return (p['TypeName'] ?? '').toString().contains('Fixed');
  }

  Future<String> _generateEnrollmentNo() async {
    final year = DateTime.now().year;
    final db   = FirebaseFirestore.instance;

    // Get actual count from Firestore — not in-memory list
    final snap = await db.collection('Staff')
        .where('ClientID', isEqualTo: widget.clientId)
        .count()
        .get();
    int count = (snap.count ?? 0) + 1;

    // Guarantee uniqueness — keep incrementing until no match found
    while (true) {
      final candidate = 'STF-$year-${count.toString().padLeft(3, '0')}';
      final existing  = await db.collection('Staff')
          .where('ClientID', isEqualTo: widget.clientId)
          .where('StaffEnrollmentNo', isEqualTo: candidate)
          .limit(1)
          .get();
      if (existing.docs.isEmpty) return candidate;
      count++;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Column(children: [
      // Filter chips + add button
      Padding(
        padding: const EdgeInsets.fromLTRB(20, 0, 20, 8),
        child: Row(children: [
          Expanded(
            child: _roleFilters.isEmpty
                ? const SizedBox.shrink()
                : ClipRect(
                    child: SingleChildScrollView(
                      scrollDirection: Axis.horizontal,
                      physics: const BouncingScrollPhysics(),
                      child: Row(children: [
                        _chip('All'),
                        ..._roleFilters.map((r) => _chip(r)),
                        const SizedBox(width: 8),
                      ]),
                    ),
                  ),
          ),
          GestureDetector(
            onTap: () => _showStaffSheet(),
            child: Container(
              width: 38, height: 38,
              decoration: BoxDecoration(
                color: const Color(0xFF1DB954).withOpacity(0.12),
                borderRadius: BorderRadius.circular(11),
                border: Border.all(color: const Color(0xFF1DB954).withOpacity(0.3))),
              child: const Icon(Icons.add_rounded, color: Color(0xFF1DB954), size: 20)),
          ),
        ]),
      ),

      // List
      Expanded(
        child: _isLoading
            ? const Center(child: CircularProgressIndicator(color: Color(0xFF1DB954), strokeWidth: 2))
            : RefreshIndicator(
                onRefresh: _load,
                color: const Color(0xFF1DB954),
                backgroundColor: const Color(0xFF152232),
                child: _filtered.isEmpty ? _emptyState() : ListView(
                  padding: const EdgeInsets.fromLTRB(20, 0, 20, 100),
                  children: [
                    Padding(padding: const EdgeInsets.only(bottom: 12),
                      child: Text('${_filtered.length} ${_filtered.length == 1 ? "Staff Member" : "Staff Members"}',
                          style: const TextStyle(fontSize: 13, color: Color(0xFF8899AA), fontWeight: FontWeight.w500))),
                    ..._filtered.map((s) => _staffCard(s)),
                  ],
                ),
              ),
      ),
    ]);
  }

  Widget _chip(String label) {
    final active = _filter == label;
    return GestureDetector(
      onTap: () => setState(() => _filter = label),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        margin: const EdgeInsets.only(right: 8),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
        decoration: BoxDecoration(
          color: active ? const Color(0xFF1DB954) : const Color(0xFF152232),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: active ? const Color(0xFF1DB954) : const Color(0xFF1E3347))),
        child: Text(label, style: TextStyle(fontSize: 12, fontWeight: FontWeight.w500,
            color: active ? Colors.white : const Color(0xFF8899AA)))));
  }

  Widget _staffCard(Map<String, dynamic> s) {
    final isActive = s['IsActive'] != false;
    final roleName = s['Role'] ?? '';
    final payType  = _payTypeName(s['PayrollTypeID']);
    final enrollNo = s['StaffEnrollmentNo'] ?? '';
    final contact  = s['StaffContact'] as Map<String, dynamic>? ?? {};
    final phone    = contact['phone'] ?? '';

    Color roleColor = const Color(0xFF5BA3D9);
    if (roleName == 'Teacher') roleColor = const Color(0xFF7F77DD);
    if (roleName == 'Coach')   roleColor = const Color(0xFFE8A020);

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
          // Avatar
          Container(width: 48, height: 48,
            decoration: BoxDecoration(color: roleColor.withOpacity(0.15), borderRadius: BorderRadius.circular(14)),
            child: Center(child: Text(
              (s['StaffName'] ?? 'S').substring(0, 1).toUpperCase(),
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: roleColor)))),
          const SizedBox(width: 12),
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(s['StaffName'] ?? '',
                style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600,
                    color: isActive ? Colors.white : const Color(0xFF8899AA))),
            const SizedBox(height: 4),
            Row(children: [
              if (roleName.isNotEmpty) Container(
                padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                decoration: BoxDecoration(color: roleColor.withOpacity(0.12), borderRadius: BorderRadius.circular(5)),
                child: Text(roleName, style: TextStyle(fontSize: 10, color: roleColor))),
              if (!isActive) ...[
                const SizedBox(width: 6),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                  decoration: BoxDecoration(color: const Color(0xFFE74C3C).withOpacity(0.1), borderRadius: BorderRadius.circular(5)),
                  child: const Text('Inactive', style: TextStyle(fontSize: 10, color: Color(0xFFE74C3C)))),
              ],
            ]),
          ])),
          // Enrollment No
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
              color: const Color(0xFF0D1B2A),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: const Color(0xFF1E3347))),
            child: Text(enrollNo, style: const TextStyle(fontSize: 10, color: Color(0xFF8899AA)))),
        ])),

        // Contact + payroll row
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
            const Icon(Icons.account_balance_wallet_outlined, color: Color(0xFF556677), size: 13),
            const SizedBox(width: 4),
            Expanded(child: Text(payType,
                style: const TextStyle(fontSize: 11, color: Color(0xFF556677)), overflow: TextOverflow.ellipsis)),
          ]),
        ),

        // Actions
        Container(
          padding: const EdgeInsets.fromLTRB(12, 8, 12, 8),
          decoration: const BoxDecoration(border: Border(top: BorderSide(color: Color(0xFF1E3347), width: 1))),
          child: Row(children: [
            Expanded(child: Text(_branchLabel(s['BranchID']),
                style: const TextStyle(fontSize: 10, color: Color(0xFF3A5068)), overflow: TextOverflow.ellipsis)),
            // Schedules
            GestureDetector(
              onTap: () => Navigator.push(context, MaterialPageRoute(
                  builder: (_) => StaffScheduleScreen(
                      clientId: widget.clientId, branchId: widget.branchId, staff: s))),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                decoration: BoxDecoration(
                  color: const Color(0xFF1DB954).withOpacity(0.08),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: const Color(0xFF1DB954).withOpacity(0.25))),
                child: const Row(mainAxisSize: MainAxisSize.min, children: [
                  Icon(Icons.calendar_today_outlined, color: Color(0xFF1DB954), size: 12),
                  SizedBox(width: 4),
                  Text('Schedules', style: TextStyle(fontSize: 11, color: Color(0xFF1DB954), fontWeight: FontWeight.w500)),
                ]))),
            const SizedBox(width: 6),
            // Edit
            GestureDetector(
              onTap: () => _showStaffSheet(existing: s),
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
        child: const Icon(Icons.badge_outlined, color: Color(0xFF3A5068), size: 36)),
      const SizedBox(height: 20),
      const Text('No staff yet', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600, color: Colors.white, fontFamily: 'Georgia')),
      const SizedBox(height: 8),
      const Text('Tap + to add your first staff member.',
          textAlign: TextAlign.center, style: TextStyle(fontSize: 13, color: Color(0xFF556677), height: 1.5)),
    ])),
  ]);

  // ── Add/Edit Sheet ─────────────────────────────────────────────────────────
  void _showStaffSheet({Map<String, dynamic>? existing}) {
    final isEdit      = existing != null;
    final nameCtrl    = TextEditingController(text: existing?['StaffName'] ?? '');
    final emailCtrl   = TextEditingController(text: (existing?['StaffContact'] as Map?)?['email'] ?? '');
    final phoneCtrl   = TextEditingController(text: (existing?['StaffContact'] as Map?)?['phone'] ?? '');
    final addressCtrl = TextEditingController(text: existing?['StaffAddress'] ?? '');
    final salaryCtrl  = TextEditingController();

    String? selRoleId = _roles.isNotEmpty ? _roles.first['TypeID'].toString() : null;
    if (existing != null) {
      final m = _roles.firstWhere((r) => r['TypeName'] == existing['Role'], orElse: () => {});
      if (m.isNotEmpty) selRoleId = m['TypeID'].toString();
    }

    String? selPayTypeId = _payTypes.isNotEmpty ? _payTypes.first['TypeID'].toString() : null;
    if (existing != null) {
      final m = _payTypes.firstWhere((p) => p['TypeID'].toString() == existing['PayrollTypeID']?.toString(), orElse: () => {});
      if (m.isNotEmpty) selPayTypeId = m['TypeID'].toString();
    }

    String? selBranchId  = existing?['BranchID'] ?? widget.branchId;
    String? selRevShareId = existing?['PayrollInfo'];

    // Pre-fill salary if fixed
    if (existing != null && _isMonthlyFixed(selPayTypeId)) {
      salaryCtrl.text = existing['PayrollInfo'] ?? '';
    }

    bool saving = false;

    showModalBottomSheet(
      context: context, isScrollControlled: true, backgroundColor: Colors.transparent,
      builder: (ctx) => StatefulBuilder(builder: (ctx, ss) {
        final isFixed = _isMonthlyFixed(selPayTypeId);
        return Padding(
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
                  decoration: BoxDecoration(color: const Color(0xFFE8A020).withOpacity(0.12), borderRadius: BorderRadius.circular(10)),
                  child: const Icon(Icons.badge_outlined, color: Color(0xFFE8A020), size: 18)),
                const SizedBox(width: 12),
                Text(isEdit ? 'Edit Staff' : 'Add Staff Member',
                    style: const TextStyle(fontFamily: 'Georgia', fontSize: 18, fontWeight: FontWeight.bold, color: Colors.white)),
              ]),
              const SizedBox(height: 24),

              _lbl('Full Name *'), const SizedBox(height: 8),
              _tf(ctrl: nameCtrl, hint: 'e.g. Rajan Subramanian'),
              const SizedBox(height: 14),

              _lbl('Role *'), const SizedBox(height: 8),
              _dd(value: selRoleId,
                  items: _roles.where((r) => r['TypeName'] != 'Client').toList(),
                  lk: 'TypeName', vk: 'TypeID', hint: 'Select role',
                  onChanged: (v) => ss(() => selRoleId = v)),
              const SizedBox(height: 14),

              _lbl('Payroll Type *'), const SizedBox(height: 8),
              _dd(value: selPayTypeId, items: _payTypes, lk: 'TypeName', vk: 'TypeID', hint: 'Select payroll type',
                  onChanged: (v) { ss(() { selPayTypeId = v; selRevShareId = null; salaryCtrl.clear(); }); }),
              const SizedBox(height: 14),

              if (isFixed) ...[
                _lbl('Monthly Salary (₹) *'), const SizedBox(height: 8),
                _tf(ctrl: salaryCtrl, hint: 'e.g. 25000', kb: TextInputType.number),
              ] else ...[
                _lbl('Revenue Share Model *'), const SizedBox(height: 8),
                if (_revShare.isEmpty)
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: const Color(0xFFE74C3C).withOpacity(0.08),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: const Color(0xFFE74C3C).withOpacity(0.3))),
                    child: const Text(
                      'No revenue share models found.\nGo to More → Sub Types → Revenue Share.',
                      style: TextStyle(fontSize: 12, color: Color(0xFFE74C3C), height: 1.4)))
                else
                  _dd(value: selRevShareId, items: _revShare, lk: 'SubTypeName', vk: 'DocID',
                      hint: 'Select revenue share model',
                      onChanged: (v) => ss(() => selRevShareId = v)),
              ],
              const SizedBox(height: 14),

              _lbl('Phone'), const SizedBox(height: 8),
              _tf(ctrl: phoneCtrl, hint: '+91 98765 43210', kb: TextInputType.phone),
              const SizedBox(height: 14),

              _lbl('Email (optional — used for login)'), const SizedBox(height: 8),
              _tf(ctrl: emailCtrl, hint: 'staff@email.com', kb: TextInputType.emailAddress),
              const SizedBox(height: 14),

              _lbl('Address'), const SizedBox(height: 8),
              _tf(ctrl: addressCtrl, hint: 'Staff home address', maxLines: 2),

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
                    if (nameCtrl.text.trim().isEmpty) { _snack('Staff name is required.'); return; }
                    if (selRoleId == null) { _snack('Select a role.'); return; }
                    if (selPayTypeId == null) { _snack('Select payroll type.'); return; }
                    final fixed = _isMonthlyFixed(selPayTypeId);
                    if (fixed && salaryCtrl.text.trim().isEmpty) { _snack('Enter salary amount.'); return; }
                    if (!fixed && selRevShareId == null) { _snack('Select revenue share model.'); return; }
                    ss(() => saving = true);
                    try {
                      final payrollInfo = fixed ? salaryCtrl.text.trim() : selRevShareId!;
                      if (isEdit) {
                        await _updateStaff(
                          docId: existing!['DocID'], name: nameCtrl.text.trim(),
                          roleId: selRoleId!, payTypeId: selPayTypeId!, payrollInfo: payrollInfo,
                          phone: phoneCtrl.text.trim(), email: emailCtrl.text.trim(),
                          address: addressCtrl.text.trim(), branchId: selBranchId!);
                        if (ctx.mounted) Navigator.pop(ctx);
                        await _load();
                        _snack('Staff updated!', ok: true);
                      } else {
                        // ✅ Close sheet first, then create staff and show dialog
                        if (ctx.mounted) Navigator.pop(ctx);
                        await _createStaff(
                          name: nameCtrl.text.trim(), roleId: selRoleId!,
                          payTypeId: selPayTypeId!, payrollInfo: payrollInfo,
                          phone: phoneCtrl.text.trim(), email: emailCtrl.text.trim(),
                          address: addressCtrl.text.trim(), branchId: selBranchId!);
                        await _load();
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
                      : Text(isEdit ? 'Update' : 'Save Staff',
                          style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600)))),
              ]),
              const SizedBox(height: 8),
            ])),
          ),
        );
      }),
    );
  }

  // ── Create Staff ───────────────────────────────────────────────────────────
  Future<void> _createStaff({
    required String name, required String roleId, required String payTypeId,
    required String payrollInfo, required String phone, required String email,
    required String address, required String branchId,
  }) async {
    final db        = FirebaseFirestore.instance;
    final enrollNo  = await _generateEnrollmentNo();
    final authEmail = email.isNotEmpty ? email : '${enrollNo.toLowerCase()}@${widget.clientId.toLowerCase()}.activityhub.app';
    final roleName  = _roles.firstWhere((r) => r['TypeID'].toString() == roleId, orElse: () => {})['TypeName'] ?? '';

    // ✅ Use secondary app — keeps admin logged in
    final secondaryApp  = await _getSecondaryApp();
    final secondaryAuth = FirebaseAuth.instanceFor(app: secondaryApp);
    final cred = await secondaryAuth.createUserWithEmailAndPassword(
        email: authEmail, password: enrollNo);
    final uid = cred.user!.uid;

    // ✅ Sign out secondary immediately so admin session is untouched
    await secondaryAuth.signOut();

    final staffRef = db.collection('Staff').doc();
    final batch    = db.batch();

    batch.set(staffRef, {
      'StaffID': staffRef.id, 'ClientID': widget.clientId, 'BranchID': branchId,
      'StaffName': name, 'Role': roleName,
      'PayrollTypeID': int.tryParse(payTypeId) ?? payTypeId,
      'PayrollInfo': payrollInfo,
      'StaffContact': {'phone': phone, 'email': authEmail},
      'StaffAddress': address,
      'StaffEnrollmentNo': enrollNo,
      'FirebaseUID': uid,
      'IsActive': true,
      'CreatedAt': FieldValue.serverTimestamp(),
    });

    batch.set(db.collection('ClientAuthorizedUsers').doc(uid), {
      'AuthUserID': uid, 'ClientID': widget.clientId, 'BranchID': branchId,
      'FirebaseUID': uid, 'AdminName': name, 'Email': authEmail,
      'UserType': 'Staff', 'RoleTypeID': int.tryParse(roleId) ?? roleId,
      'LinkedID': staffRef.id, 'IsActive': true,
      'MustChangePassword': true,
      'StaffEnrollmentNo': enrollNo,
      'CreatedAt': FieldValue.serverTimestamp(),
    });

    await batch.commit();

    // ✅ Show success dialog — sheet is already closed so context is safe
    if (mounted) {
      await Future.delayed(const Duration(milliseconds: 300));
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (dialogCtx) => AlertDialog(
          backgroundColor: const Color(0xFF152232),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          content: Column(mainAxisSize: MainAxisSize.min, children: [
            Container(
              width: 64, height: 64,
              decoration: BoxDecoration(
                color: const Color(0xFF1DB954).withOpacity(0.12),
                borderRadius: BorderRadius.circular(18)),
              child: const Icon(Icons.check_circle_outline_rounded,
                  color: Color(0xFF1DB954), size: 36)),
            const SizedBox(height: 16),
            const Text('Staff Added!',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold,
                    color: Colors.white, fontFamily: 'Georgia')),
            const SizedBox(height: 8),
            const Text('Enrollment Number',
                style: TextStyle(fontSize: 12, color: Color(0xFF556677))),
            const SizedBox(height: 6),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
              decoration: BoxDecoration(
                color: const Color(0xFF0D1B2A),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: const Color(0xFF1DB954).withOpacity(0.4))),
              child: Text(enrollNo,
                  style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold,
                      color: Color(0xFF1DB954), letterSpacing: 1.5))),
            const SizedBox(height: 6),
            Text('Login: $authEmail',
                style: const TextStyle(fontSize: 11, color: Color(0xFF556677))),
            const Text('Password: (same as enrollment no)',
                style: TextStyle(fontSize: 11, color: Color(0xFF556677))),
            const SizedBox(height: 20),
            SizedBox(width: double.infinity,
              child: ElevatedButton(
                onPressed: () => Navigator.pop(dialogCtx), // ✅ use dialogCtx
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF1DB954),
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  padding: const EdgeInsets.symmetric(vertical: 13)),
                child: const Text('Done',
                    style: TextStyle(fontWeight: FontWeight.w600)))),
          ]),
        ),
      );
    }
  }

  // ── Update Staff ───────────────────────────────────────────────────────────
  Future<void> _updateStaff({
    required String docId, required String name, required String roleId,
    required String payTypeId, required String payrollInfo,
    required String phone, required String email,
    required String address, required String branchId,
  }) async {
    final roleName = _roles.firstWhere(
        (r) => r['TypeID'].toString() == roleId, orElse: () => {})['TypeName'] ?? '';

    final staffDoc = _staff.firstWhere((s) => s['DocID'] == docId, orElse: () => {});
    final uid = staffDoc['FirebaseUID'] as String?;

    // Get OLD email before any updates
    final oldEmail = (staffDoc['StaffContact'] as Map?)?['email'] as String?
        ?? '${(staffDoc['StaffEnrollmentNo'] ?? '').toLowerCase()}@${widget.clientId.toLowerCase()}.activityhub.app';

    // Update Staff collection
    await FirebaseFirestore.instance.collection('Staff').doc(docId).update({
      'StaffName': name, 'Role': roleName,
      'PayrollTypeID': int.tryParse(payTypeId) ?? payTypeId,
      'PayrollInfo': payrollInfo,
      'StaffContact': {'phone': phone, 'email': email},
      'StaffAddress': address, 'BranchID': branchId,
      'UpdatedAt': FieldValue.serverTimestamp(),
    });

    if (uid != null) {
      // Update ClientAuthorizedUsers email
      await FirebaseFirestore.instance
          .collection('ClientAuthorizedUsers')
          .doc(uid)
          .update({
        'Email': email,
        'UpdatedAt': FieldValue.serverTimestamp(),
      });

      // Update Firebase Auth email if email changed
      if (oldEmail != email) {
        await _updateFirebaseAuthEmail(uid, oldEmail, email, staffDoc);
      }
    }
  }

  // ── Update Firebase Auth Email ─────────────────────────────────────────────
  Future<void> _updateFirebaseAuthEmail(
      String uid, String oldEmail, String newEmail, Map<String, dynamic> staffDoc) async {
    try {
      final enrollNo = staffDoc['StaffEnrollmentNo'] as String? ?? '';

      final secondaryApp  = await _getSecondaryApp();
      final secondaryAuth = FirebaseAuth.instanceFor(app: secondaryApp);

      // Sign in with OLD email and enrollment no as password
      final cred = await secondaryAuth.signInWithEmailAndPassword(
        email: oldEmail,
        password: enrollNo,
      );

      // Update to NEW email
      await cred.user!.updateEmail(newEmail);
      await secondaryAuth.signOut();

      debugPrint('Firebase Auth email updated: $oldEmail → $newEmail');
    } catch (e) {
      debugPrint('Failed to update Firebase Auth email: $e');
      _snack('Profile updated. Auth email update failed: $e');
    }
  }

  // ── Toggle Active ──────────────────────────────────────────────────────────
  Future<void> _toggleActive(Map<String, dynamic> s, bool isActive) async {
    final confirm = await showDialog<bool>(context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF152232),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Text(isActive ? 'Deactivate staff?' : 'Activate staff?',
            style: const TextStyle(color: Colors.white, fontFamily: 'Georgia')),
        content: Text(
          isActive ? '"${s['StaffName']}" will lose app access.' : '"${s['StaffName']}" will regain app access.',
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
      batch.update(db.collection('Staff').doc(s['DocID']),
          {'IsActive': !isActive, 'UpdatedAt': FieldValue.serverTimestamp()});
      if (uid != null) {
        batch.update(db.collection('ClientAuthorizedUsers').doc(uid),
            {'IsActive': !isActive, 'UpdatedAt': FieldValue.serverTimestamp()});
      }
      await batch.commit();
      await _load();
      _snack(isActive ? 'Staff deactivated.' : 'Staff activated!', ok: !isActive);
    } catch (e) { _snack('Failed to update status.'); }
  }

  // ── Helpers ────────────────────────────────────────────────────────────────
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