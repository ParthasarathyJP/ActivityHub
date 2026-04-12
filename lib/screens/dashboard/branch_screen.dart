import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class BranchScreen extends StatefulWidget {
  final String clientId;
  final bool hasBranches;

  const BranchScreen({
    super.key,
    required this.clientId,
    required this.hasBranches,
  });

  @override
  State<BranchScreen> createState() => _BranchScreenState();
}

class _BranchScreenState extends State<BranchScreen> {
  List<Map<String, dynamic>> _branches = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _isLoading = true);
    try {
      final snap = await FirebaseFirestore.instance
          .collection('Branch')
          .where('ClientID', isEqualTo: widget.clientId)
          .orderBy('CreatedAt')
          .get();
      if (mounted) {
        setState(() {
          _branches = snap.docs
              .map((d) => {...d.data(), 'DocID': d.id})
              .toList();
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) setState(() => _isLoading = false);
      _showSnack('Failed to load branches.');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0D1B2A),
      body: Stack(
        children: [
          _buildBgCircles(),
          SafeArea(
            child: Column(
              children: [
                _buildTopBar(),
                Expanded(
                  child: _isLoading
                      ? const Center(
                          child: CircularProgressIndicator(
                              color: Color(0xFF1DB954), strokeWidth: 2))
                      : RefreshIndicator(
                          onRefresh: _load,
                          color: const Color(0xFF1DB954),
                          backgroundColor: const Color(0xFF152232),
                          child: ListView(
                            padding: const EdgeInsets.fromLTRB(20, 8, 20, 100),
                            children: [
                              // Multi-branch info banner
                              if (!widget.hasBranches) _buildSingleBranchBanner(),
                              const SizedBox(height: 16),
                              // Branch count header
                              Row(
                                children: [
                                  Text(
                                    '${_branches.length} ${_branches.length == 1 ? 'Branch' : 'Branches'}',
                                    style: const TextStyle(
                                      fontSize: 13,
                                      fontWeight: FontWeight.w600,
                                      color: Color(0xFF8899AA),
                                      letterSpacing: 0.5,
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 12),
                              // Branch cards
                              ..._branches.map((b) => _buildBranchCard(b)),
                              // Add branch button (only if multi-branch enabled)
                              if (widget.hasBranches) ...[
                                const SizedBox(height: 8),
                                _buildAddBranchButton(),
                              ],
                            ],
                          ),
                        ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ── Top bar ────────────────────────────────────────────────────────────────
  Widget _buildTopBar() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Row(
        children: [
          GestureDetector(
            onTap: () => Navigator.of(context).pop(),
            child: Container(
              width: 40, height: 40,
              decoration: BoxDecoration(
                color: const Color(0xFF152232),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: const Color(0xFF1E3347)),
              ),
              child: const Icon(Icons.arrow_back_ios_new_rounded,
                  color: Color(0xFF8899AA), size: 18),
            ),
          ),
          const SizedBox(width: 14),
          const Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Branches',
                    style: TextStyle(
                        fontFamily: 'Georgia',
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                        color: Colors.white)),
                Text('Manage your locations',
                    style: TextStyle(
                        fontSize: 12, color: Color(0xFF556677))),
              ],
            ),
          ),
          if (widget.hasBranches)
            GestureDetector(
              onTap: _showAddSheet,
              child: Container(
                width: 40, height: 40,
                decoration: BoxDecoration(
                  color: const Color(0xFF1DB954).withOpacity(0.12),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                      color: const Color(0xFF1DB954).withOpacity(0.3)),
                ),
                child: const Icon(Icons.add_rounded,
                    color: Color(0xFF1DB954), size: 22),
              ),
            ),
        ],
      ),
    );
  }

  // ── Single branch banner ───────────────────────────────────────────────────
  Widget _buildSingleBranchBanner() {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFF1A4B6B).withOpacity(0.2),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
            color: const Color(0xFF5BA3D9).withOpacity(0.3), width: 1),
      ),
      child: Row(
        children: [
          Container(
            width: 36, height: 36,
            decoration: BoxDecoration(
              color: const Color(0xFF5BA3D9).withOpacity(0.12),
              borderRadius: BorderRadius.circular(10),
            ),
            child: const Icon(Icons.info_outline_rounded,
                color: Color(0xFF5BA3D9), size: 18),
          ),
          const SizedBox(width: 12),
          const Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Single branch mode',
                    style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w500,
                        color: Color(0xFF5BA3D9))),
                SizedBox(height: 2),
                Text(
                  'Multiple branches is disabled. Enable it in Settings to add more locations.',
                  style: TextStyle(
                      fontSize: 11,
                      color: Color(0xFF8899AA),
                      height: 1.4),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ── Branch card ────────────────────────────────────────────────────────────
  Widget _buildBranchCard(Map<String, dynamic> branch) {
    final isPrimary = branch['IsPrimary'] == true;
    final isActive  = branch['IsActive'] != false;

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: const Color(0xFF152232),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: isPrimary
              ? const Color(0xFF1DB954).withOpacity(0.4)
              : const Color(0xFF1E3347),
          width: isPrimary ? 1.5 : 1,
        ),
      ),
      child: Column(
        children: [
          // Card header
          Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                Container(
                  width: 44, height: 44,
                  decoration: BoxDecoration(
                    color: isPrimary
                        ? const Color(0xFF1DB954).withOpacity(0.12)
                        : const Color(0xFF7F77DD).withOpacity(0.12),
                    borderRadius: BorderRadius.circular(13),
                  ),
                  child: Icon(
                    isPrimary
                        ? Icons.account_balance_outlined
                        : Icons.store_outlined,
                    color: isPrimary
                        ? const Color(0xFF1DB954)
                        : const Color(0xFF7F77DD),
                    size: 22,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Text(
                            isPrimary ? 'Primary Branch' : 'Branch',
                            style: const TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.w600,
                              color: Colors.white,
                            ),
                          ),
                          if (isPrimary) ...[
                            const SizedBox(width: 8),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 7, vertical: 3),
                              decoration: BoxDecoration(
                                color: const Color(0xFF1DB954).withOpacity(0.12),
                                borderRadius: BorderRadius.circular(6),
                                border: Border.all(
                                    color: const Color(0xFF1DB954)
                                        .withOpacity(0.3)),
                              ),
                              child: const Text('Primary',
                                  style: TextStyle(
                                      fontSize: 9,
                                      color: Color(0xFF1DB954),
                                      fontWeight: FontWeight.w600)),
                            ),
                          ],
                          if (!isActive) ...[
                            const SizedBox(width: 8),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 7, vertical: 3),
                              decoration: BoxDecoration(
                                color: const Color(0xFFE74C3C).withOpacity(0.1),
                                borderRadius: BorderRadius.circular(6),
                              ),
                              child: const Text('Inactive',
                                  style: TextStyle(
                                      fontSize: 9,
                                      color: Color(0xFFE74C3C))),
                            ),
                          ],
                        ],
                      ),
                    ],
                  ),
                ),
                // Edit button (not for primary — it was set at registration)
                if (widget.hasBranches)
                  GestureDetector(
                    onTap: () => _showEditSheet(branch),
                    child: Container(
                      width: 32, height: 32,
                      decoration: BoxDecoration(
                        color: const Color(0xFF5BA3D9).withOpacity(0.12),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: const Icon(Icons.edit_outlined,
                          color: Color(0xFF5BA3D9), size: 16),
                    ),
                  ),
              ],
            ),
          ),

          // Divider
          const Divider(height: 1, color: Color(0xFF1E3347)),

          // Branch details
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              children: [
                _detailRow(
                  Icons.location_on_outlined,
                  'Address',
                  branch['BranchAddress'] ?? '—',
                  const Color(0xFF7F77DD),
                ),
                const SizedBox(height: 10),
                _detailRow(
                  Icons.phone_outlined,
                  'Contact',
                  branch['ContactNo'] ?? '—',
                  const Color(0xFF5BA3D9),
                ),
                const SizedBox(height: 10),
                _detailRow(
                  Icons.access_time_rounded,
                  'Timings',
                  branch['BusinessTimings'] ?? '—',
                  const Color(0xFFE8A020),
                ),
              ],
            ),
          ),

          // Toggle active/inactive (only for non-primary branches)
          if (!isPrimary && widget.hasBranches) ...[
            const Divider(height: 1, color: Color(0xFF1E3347)),
            Padding(
              padding: const EdgeInsets.symmetric(
                  horizontal: 16, vertical: 10),
              child: Row(
                children: [
                  Icon(
                    isActive
                        ? Icons.toggle_on_rounded
                        : Icons.toggle_off_rounded,
                    color: isActive
                        ? const Color(0xFF1DB954)
                        : const Color(0xFF3A5068),
                    size: 20,
                  ),
                  const SizedBox(width: 8),
                  Text(
                    isActive ? 'Branch is active' : 'Branch is inactive',
                    style: TextStyle(
                      fontSize: 12,
                      color: isActive
                          ? const Color(0xFF1DB954)
                          : const Color(0xFF3A5068),
                    ),
                  ),
                  const Spacer(),
                  GestureDetector(
                    onTap: () => _toggleActive(branch),
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 12, vertical: 6),
                      decoration: BoxDecoration(
                        color: isActive
                            ? const Color(0xFFE74C3C).withOpacity(0.1)
                            : const Color(0xFF1DB954).withOpacity(0.1),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(
                          color: isActive
                              ? const Color(0xFFE74C3C).withOpacity(0.3)
                              : const Color(0xFF1DB954).withOpacity(0.3),
                        ),
                      ),
                      child: Text(
                        isActive ? 'Deactivate' : 'Activate',
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w500,
                          color: isActive
                              ? const Color(0xFFE74C3C)
                              : const Color(0xFF1DB954),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _detailRow(
      IconData icon, String label, String value, Color color) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: 30, height: 30,
          decoration: BoxDecoration(
            color: color.withOpacity(0.1),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Icon(icon, color: color, size: 15),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(label,
                  style: const TextStyle(
                      fontSize: 10, color: Color(0xFF556677))),
              Text(value,
                  style: const TextStyle(
                      fontSize: 13, color: Colors.white, height: 1.4)),
            ],
          ),
        ),
      ],
    );
  }

  // ── Add branch dashed button ───────────────────────────────────────────────
  Widget _buildAddBranchButton() {
    return GestureDetector(
      onTap: _showAddSheet,
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(18),
        decoration: BoxDecoration(
          color: const Color(0xFF1DB954).withOpacity(0.05),
          borderRadius: BorderRadius.circular(18),
          border: Border.all(
            color: const Color(0xFF1DB954).withOpacity(0.3),
            width: 1,
          ),
        ),
        child: const Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.add_circle_outline_rounded,
                color: Color(0xFF1DB954), size: 20),
            SizedBox(width: 10),
            Text('Add New Branch',
                style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                    color: Color(0xFF1DB954))),
          ],
        ),
      ),
    );
  }

  // ── Add branch bottom sheet ────────────────────────────────────────────────
  void _showAddSheet() {
    final addressCtrl  = TextEditingController();
    final contactCtrl  = TextEditingController();
    final timingsCtrl  = TextEditingController();
    bool isSaving = false;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setSheet) => Padding(
          padding: EdgeInsets.only(
              bottom: MediaQuery.of(ctx).viewInsets.bottom),
          child: Container(
            decoration: const BoxDecoration(
              color: Color(0xFF152232),
              borderRadius:
                  BorderRadius.vertical(top: Radius.circular(24)),
            ),
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Handle
                Center(
                  child: Container(
                    width: 40, height: 4,
                    decoration: BoxDecoration(
                      color: const Color(0xFF1E3347),
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ),
                const SizedBox(height: 20),
                Row(
                  children: [
                    Container(
                      width: 36, height: 36,
                      decoration: BoxDecoration(
                        color: const Color(0xFF7F77DD).withOpacity(0.12),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: const Icon(Icons.store_outlined,
                          color: Color(0xFF7F77DD), size: 18),
                    ),
                    const SizedBox(width: 12),
                    const Text('Add New Branch',
                        style: TextStyle(
                            fontFamily: 'Georgia',
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            color: Colors.white)),
                  ],
                ),
                const SizedBox(height: 20),
                _sheetLabel('Branch Address *'),
                const SizedBox(height: 8),
                _sheetTextField(
                    controller: addressCtrl,
                    hint: '123, Main Street, City – 600001',
                    maxLines: 2),
                const SizedBox(height: 14),
                _sheetLabel('Contact Number *'),
                const SizedBox(height: 8),
                _sheetTextField(
                    controller: contactCtrl,
                    hint: '+91 98765 43210',
                    keyboardType: TextInputType.phone),
                const SizedBox(height: 14),
                _sheetLabel('Business Timings *'),
                const SizedBox(height: 8),
                _sheetTextField(
                    controller: timingsCtrl,
                    hint: 'e.g. Mon–Sat: 6 AM – 9 PM'),
                // Quick timing chips
                const SizedBox(height: 8),
                Wrap(
                  spacing: 8, runSpacing: 6,
                  children: [
                    'Mon–Sat: 6AM–9PM',
                    'Mon–Fri: 9AM–6PM',
                    'All days: 6AM–9PM',
                  ].map((t) => GestureDetector(
                    onTap: () => timingsCtrl.text = t,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 10, vertical: 5),
                      decoration: BoxDecoration(
                        color: const Color(0xFF1DB954).withOpacity(0.08),
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(
                            color: const Color(0xFF1DB954).withOpacity(0.25)),
                      ),
                      child: Text(t,
                          style: const TextStyle(
                              fontSize: 10,
                              color: Color(0xFF1DB954))),
                    ),
                  )).toList(),
                ),
                const SizedBox(height: 24),
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton(
                        onPressed: () => Navigator.pop(ctx),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: const Color(0xFF8899AA),
                          side: const BorderSide(color: Color(0xFF1E3347)),
                          shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(14)),
                          padding:
                              const EdgeInsets.symmetric(vertical: 14),
                        ),
                        child: const Text('Cancel'),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      flex: 2,
                      child: ElevatedButton(
                        onPressed: isSaving
                            ? null
                            : () async {
                                if (addressCtrl.text.trim().isEmpty) {
                                  _showSnack('Address is required.');
                                  return;
                                }
                                if (contactCtrl.text.trim().isEmpty) {
                                  _showSnack('Contact is required.');
                                  return;
                                }
                                if (timingsCtrl.text.trim().isEmpty) {
                                  _showSnack('Timings are required.');
                                  return;
                                }
                                setSheet(() => isSaving = true);
                                try {
                                  await _addBranch(
                                    address: addressCtrl.text.trim(),
                                    contact: contactCtrl.text.trim(),
                                    timings: timingsCtrl.text.trim(),
                                  );
                                  if (ctx.mounted) Navigator.pop(ctx);
                                  await _load();
                                  _showSnack('Branch added!', success: true);
                                } catch (e) {
                                  _showSnack('Failed to add branch.');
                                  setSheet(() => isSaving = false);
                                }
                              },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF1DB954),
                          foregroundColor: Colors.white,
                          elevation: 0,
                          shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(14)),
                          padding:
                              const EdgeInsets.symmetric(vertical: 14),
                        ),
                        child: isSaving
                            ? const SizedBox(
                                width: 20, height: 20,
                                child: CircularProgressIndicator(
                                    color: Colors.white, strokeWidth: 2))
                            : const Text('Save Branch',
                                style: TextStyle(
                                    fontSize: 15,
                                    fontWeight: FontWeight.w600)),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
              ],
            ),
          ),
        ),
      ),
    );
  }

  // ── Edit branch bottom sheet ───────────────────────────────────────────────
  void _showEditSheet(Map<String, dynamic> branch) {
    final addressCtrl =
        TextEditingController(text: branch['BranchAddress'] ?? '');
    final contactCtrl =
        TextEditingController(text: branch['ContactNo'] ?? '');
    final timingsCtrl =
        TextEditingController(text: branch['BusinessTimings'] ?? '');
    bool isSaving = false;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setSheet) => Padding(
          padding: EdgeInsets.only(
              bottom: MediaQuery.of(ctx).viewInsets.bottom),
          child: Container(
            decoration: const BoxDecoration(
              color: Color(0xFF152232),
              borderRadius:
                  BorderRadius.vertical(top: Radius.circular(24)),
            ),
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Center(
                  child: Container(
                    width: 40, height: 4,
                    decoration: BoxDecoration(
                      color: const Color(0xFF1E3347),
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ),
                const SizedBox(height: 20),
                Row(
                  children: [
                    Container(
                      width: 36, height: 36,
                      decoration: BoxDecoration(
                        color: const Color(0xFF5BA3D9).withOpacity(0.12),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: const Icon(Icons.edit_outlined,
                          color: Color(0xFF5BA3D9), size: 18),
                    ),
                    const SizedBox(width: 12),
                    const Text('Edit Branch',
                        style: TextStyle(
                            fontFamily: 'Georgia',
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            color: Colors.white)),
                  ],
                ),
                const SizedBox(height: 20),
                _sheetLabel('Branch Address *'),
                const SizedBox(height: 8),
                _sheetTextField(
                    controller: addressCtrl,
                    hint: '123, Main Street, City',
                    maxLines: 2),
                const SizedBox(height: 14),
                _sheetLabel('Contact Number *'),
                const SizedBox(height: 8),
                _sheetTextField(
                    controller: contactCtrl,
                    hint: '+91 98765 43210',
                    keyboardType: TextInputType.phone),
                const SizedBox(height: 14),
                _sheetLabel('Business Timings *'),
                const SizedBox(height: 8),
                _sheetTextField(
                    controller: timingsCtrl,
                    hint: 'e.g. Mon–Sat: 6 AM – 9 PM'),
                const SizedBox(height: 24),
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton(
                        onPressed: () => Navigator.pop(ctx),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: const Color(0xFF8899AA),
                          side: const BorderSide(color: Color(0xFF1E3347)),
                          shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(14)),
                          padding:
                              const EdgeInsets.symmetric(vertical: 14),
                        ),
                        child: const Text('Cancel'),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      flex: 2,
                      child: ElevatedButton(
                        onPressed: isSaving
                            ? null
                            : () async {
                                if (addressCtrl.text.trim().isEmpty ||
                                    contactCtrl.text.trim().isEmpty ||
                                    timingsCtrl.text.trim().isEmpty) {
                                  _showSnack('All fields are required.');
                                  return;
                                }
                                setSheet(() => isSaving = true);
                                try {
                                  await FirebaseFirestore.instance
                                      .collection('Branch')
                                      .doc(branch['DocID'])
                                      .update({
                                    'BranchAddress':
                                        addressCtrl.text.trim(),
                                    'ContactNo': contactCtrl.text.trim(),
                                    'BusinessTimings':
                                        timingsCtrl.text.trim(),
                                    'UpdatedAt':
                                        FieldValue.serverTimestamp(),
                                  });
                                  if (ctx.mounted) Navigator.pop(ctx);
                                  await _load();
                                  _showSnack('Branch updated!',
                                      success: true);
                                } catch (e) {
                                  _showSnack('Failed to update.');
                                  setSheet(() => isSaving = false);
                                }
                              },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF1DB954),
                          foregroundColor: Colors.white,
                          elevation: 0,
                          shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(14)),
                          padding:
                              const EdgeInsets.symmetric(vertical: 14),
                        ),
                        child: isSaving
                            ? const SizedBox(
                                width: 20, height: 20,
                                child: CircularProgressIndicator(
                                    color: Colors.white, strokeWidth: 2))
                            : const Text('Update',
                                style: TextStyle(
                                    fontSize: 15,
                                    fontWeight: FontWeight.w600)),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
              ],
            ),
          ),
        ),
      ),
    );
  }

  // ── Firestore operations ───────────────────────────────────────────────────
  Future<void> _addBranch({
    required String address,
    required String contact,
    required String timings,
  }) async {
    final ref = FirebaseFirestore.instance.collection('Branch').doc();
    await ref.set({
      'BranchID':                  ref.id,
      'ClientID':                  widget.clientId,
      'BranchAddress':             address,
      'ContactNo':                 contact,
      'BusinessTimings':           timings,
      'IsPrimary':                 false,
      'IsActive':                  true,
      'BranchRevenueSharePercent': 0.0,
      'CreatedAt':                 FieldValue.serverTimestamp(),
    });
  }

  Future<void> _toggleActive(Map<String, dynamic> branch) async {
    final isActive = branch['IsActive'] != false;
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF152232),
        shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20)),
        title: Text(isActive ? 'Deactivate branch?' : 'Activate branch?',
            style: const TextStyle(
                color: Colors.white, fontFamily: 'Georgia')),
        content: Text(
          isActive
              ? 'This branch will be hidden from course and student assignment.'
              : 'This branch will be available for courses and students.',
          style: const TextStyle(
              color: Color(0xFF8899AA), height: 1.5),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel',
                style: TextStyle(color: Color(0xFF8899AA))),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: Text(isActive ? 'Deactivate' : 'Activate',
                style: TextStyle(
                    color: isActive
                        ? const Color(0xFFE74C3C)
                        : const Color(0xFF1DB954))),
          ),
        ],
      ),
    );
    if (confirm != true) return;
    try {
      await FirebaseFirestore.instance
          .collection('Branch')
          .doc(branch['DocID'])
          .update({
        'IsActive': !isActive,
        'UpdatedAt': FieldValue.serverTimestamp(),
      });
      await _load();
      _showSnack(
          isActive ? 'Branch deactivated.' : 'Branch activated!',
          success: !isActive);
    } catch (e) {
      _showSnack('Failed to update branch status.');
    }
  }

  // ── Helpers ────────────────────────────────────────────────────────────────
  void _showSnack(String msg, {bool success = false}) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(msg,
          style: const TextStyle(color: Colors.white, fontSize: 14)),
      backgroundColor:
          success ? const Color(0xFF2ECC71) : const Color(0xFFE74C3C),
      behavior: SnackBarBehavior.floating,
      shape:
          RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      margin: const EdgeInsets.all(16),
    ));
  }

  Widget _sheetLabel(String text) => Text(text,
      style: const TextStyle(
          fontSize: 13,
          fontWeight: FontWeight.w500,
          color: Color(0xFF8899AA)));

  Widget _sheetTextField({
    required TextEditingController controller,
    required String hint,
    TextInputType keyboardType = TextInputType.text,
    int maxLines = 1,
  }) =>
      TextField(
        controller: controller,
        keyboardType: keyboardType,
        maxLines: maxLines,
        style: const TextStyle(color: Colors.white, fontSize: 15),
        cursorColor: const Color(0xFF1DB954),
        decoration: InputDecoration(
          hintText: hint,
          hintStyle: const TextStyle(
              color: Color(0xFF3A5068), fontSize: 15),
          filled: true,
          fillColor: const Color(0xFF0D1B2A),
          contentPadding:
              const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide:
                const BorderSide(color: Color(0xFF1E3347), width: 1),
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide:
                const BorderSide(color: Color(0xFF1E3347), width: 1),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide:
                const BorderSide(color: Color(0xFF1DB954), width: 1.5),
          ),
        ),
      );

  Widget _buildBgCircles() => Stack(children: [
        Positioned(
          top: -80, right: -60,
          child: Container(
            width: 280, height: 280,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: const Color(0xFF1A6B4A).withOpacity(0.12),
            ),
          ),
        ),
        Positioned(
          bottom: -100, left: -80,
          child: Container(
            width: 320, height: 320,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: const Color(0xFF1A4B6B).withOpacity(0.15),
            ),
          ),
        ),
      ]);
}