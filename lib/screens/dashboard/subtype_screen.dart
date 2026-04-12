import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../services/subtype_seed_service.dart';

// ── SubType code config ───────────────────────────────────────────────────────
const Map<String, Map<String, dynamic>> kSubTypeMeta = {
  'Course': {
    'label': 'Course Activities',
    'icon': Icons.menu_book_outlined,
    'color': Color(0xFF1DB954),
    'hint': 'e.g. Yoga, French, Badminton',
    'empty': 'Add your first course activity',
  },
  'Timings': {
    'label': 'Timings',
    'icon': Icons.access_time_rounded,
    'color': Color(0xFF5BA3D9),
    'hint': 'e.g. 6 AM to 7 AM',
    'empty': 'Add a timing slot',
  },
  'CourseDuration': {
    'label': 'Course Duration',
    'icon': Icons.date_range_outlined,
    'color': Color(0xFF7F77DD),
    'hint': 'e.g. 3 Months',
    'empty': 'Add a duration option',
  },
  'PaymentCycle': {
    'label': 'Payment Cycle',
    'icon': Icons.repeat_rounded,
    'color': Color(0xFFE8A020),
    'hint': 'e.g. Monthly',
    'empty': 'Add a payment cycle',
  },
  'RevenueShare': {
    'label': 'Revenue Share',
    'icon': Icons.pie_chart_outline_rounded,
    'color': Color(0xFFD4537E),
    'hint': 'e.g. 70-30',
    'empty': 'Add a revenue share model',
  },
};

const List<String> kFilterOrder = [
  'All', 'Course', 'Timings', 'CourseDuration', 'PaymentCycle', 'RevenueShare'
];

class SubTypeScreen extends StatefulWidget {
  final String clientId;
  const SubTypeScreen({super.key, required this.clientId});

  @override
  State<SubTypeScreen> createState() => _SubTypeScreenState();
}

class _SubTypeScreenState extends State<SubTypeScreen> {
  String _activeFilter = 'All';
  Map<String, List<Map<String, dynamic>>> _grouped = {};
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _isLoading = true);
    try {
      // Load both active and inactive
      final snap = await FirebaseFirestore.instance
          .collection('SubType')
          .where('ClientID', isEqualTo: widget.clientId)
          .orderBy('CreatedAt')
          .get();

      final Map<String, List<Map<String, dynamic>>> grouped = {};
      for (final doc in snap.docs) {
        final data = {...doc.data(), 'DocID': doc.id};
        final code = data['SubTypeCode'] as String? ?? 'Other';
        grouped.putIfAbsent(code, () => []).add(data);
      }
      if (mounted) setState(() { _grouped = grouped; _isLoading = false; });
    } catch (e) {
      if (mounted) setState(() => _isLoading = false);
      _showSnack('Failed to load sub types.');
    }
  }

  List<String> get _visibleCodes {
    if (_activeFilter == 'All') return kSubTypeMeta.keys.toList();
    return [_activeFilter];
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
                _buildFilterChips(),
                Expanded(
                  child: _isLoading
                      ? const Center(child: CircularProgressIndicator(
                          color: Color(0xFF1DB954), strokeWidth: 2))
                      : RefreshIndicator(
                          onRefresh: _load,
                          color: const Color(0xFF1DB954),
                          backgroundColor: const Color(0xFF152232),
                          child: ListView(
                            padding: const EdgeInsets.fromLTRB(20, 8, 20, 100),
                            children: _visibleCodes
                                .map((code) => _buildSection(code))
                                .toList(),
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
                Text('Sub Types',
                    style: TextStyle(
                        fontFamily: 'Georgia',
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                        color: Colors.white)),
                Text('Client configuration',
                    style: TextStyle(fontSize: 12, color: Color(0xFF556677))),
              ],
            ),
          ),
          // Reload button
          GestureDetector(
            onTap: _load,
            child: Container(
              width: 40, height: 40,
              decoration: BoxDecoration(
                color: const Color(0xFF152232),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: const Color(0xFF1E3347)),
              ),
              child: const Icon(Icons.refresh_rounded,
                  color: Color(0xFF8899AA), size: 18),
            ),
          ),
        ],
      ),
    );
  }

  // ── Filter chips ───────────────────────────────────────────────────────────
  Widget _buildFilterChips() {
    return SizedBox(
      height: 42,
      child: ListView(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 20),
        children: kFilterOrder.map((f) {
          final isActive = _activeFilter == f;
          return GestureDetector(
            onTap: () => setState(() => _activeFilter = f),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              margin: const EdgeInsets.only(right: 8),
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              decoration: BoxDecoration(
                color: isActive ? const Color(0xFF1DB954) : const Color(0xFF152232),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(
                  color: isActive ? const Color(0xFF1DB954) : const Color(0xFF1E3347),
                ),
              ),
              child: Text(
                f == 'CourseDuration' ? 'Duration'
                    : f == 'PaymentCycle' ? 'Payment'
                    : f == 'RevenueShare' ? 'Revenue'
                    : f,
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w500,
                  color: isActive ? Colors.white : const Color(0xFF8899AA),
                ),
              ),
            ),
          );
        }).toList(),
      ),
    );
  }

  // ── Section per SubTypeCode ────────────────────────────────────────────────
  Widget _buildSection(String code) {
    final meta = kSubTypeMeta[code]!;
    final items = _grouped[code] ?? [];
    final active   = items.where((i) => i['IsActive'] == true).toList();
    final inactive = items.where((i) => i['IsActive'] != true).toList();
    final color    = meta['color'] as Color;
    final icon     = meta['icon'] as IconData;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SizedBox(height: 20),
        // Section header
        Row(
          children: [
            Container(
              width: 30, height: 30,
              decoration: BoxDecoration(
                color: color.withOpacity(0.12),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Icon(icon, color: color, size: 16),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                meta['label'] as String,
                style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: Colors.white),
              ),
            ),
            // Count badge
            if (active.isNotEmpty)
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: color.withOpacity(0.12),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Text('${active.length}',
                    style: TextStyle(fontSize: 11, color: color,
                        fontWeight: FontWeight.w600)),
              ),
            const SizedBox(width: 8),
            // Add button
            GestureDetector(
              onTap: () => _showAddSheet(code),
              child: Container(
                width: 30, height: 30,
                decoration: BoxDecoration(
                  color: color.withOpacity(0.12),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: color.withOpacity(0.3)),
                ),
                child: Icon(Icons.add_rounded, color: color, size: 18),
              ),
            ),
          ],
        ),
        const SizedBox(height: 10),

        // Empty state
        if (items.isEmpty)
          GestureDetector(
            onTap: () => _showAddSheet(code),
            child: Container(
              width: double.infinity,
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: color.withOpacity(0.05),
                borderRadius: BorderRadius.circular(14),
                border: Border.all(
                    color: color.withOpacity(0.3), width: 1,
                    style: BorderStyle.solid),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.add_circle_outline_rounded,
                      color: color, size: 16),
                  const SizedBox(width: 8),
                  Text(meta['empty'] as String,
                      style: TextStyle(fontSize: 13, color: color)),
                ],
              ),
            ),
          ),

        // Active items
        ...active.map((item) => _buildItem(item, code, isActive: true)),

        // Inactive section
        if (inactive.isNotEmpty) ...[
          const SizedBox(height: 8),
          const Text('Inactive',
              style: TextStyle(fontSize: 11, color: Color(0xFF3A5068))),
          const SizedBox(height: 6),
          ...inactive.map((item) => _buildItem(item, code, isActive: false)),
        ],
      ],
    );
  }

  // ── Single item row ────────────────────────────────────────────────────────
  Widget _buildItem(Map<String, dynamic> item, String code,
      {required bool isActive}) {
    final isDefault = item['IsDefault'] == true;
    final color = (kSubTypeMeta[code]!['color'] as Color);

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: const Color(0xFF152232),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: isActive ? const Color(0xFF1E3347) : const Color(0xFF152232),
        ),
      ),
      child: Row(
        children: [
          // Active dot
          Container(
            width: 8, height: 8,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: isActive ? color : const Color(0xFF3A5068),
            ),
          ),
          const SizedBox(width: 12),

          // Name + description
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  item['SubTypeName'] ?? '',
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w500,
                    color: isActive ? Colors.white : const Color(0xFF556677),
                  ),
                ),
                if ((item['SubTypeDescription'] ?? '').isNotEmpty)
                  Text(item['SubTypeDescription'],
                      style: const TextStyle(
                          fontSize: 11, color: Color(0xFF556677))),
              ],
            ),
          ),

          // Default badge
          if (isDefault)
            Container(
              margin: const EdgeInsets.only(right: 8),
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
              decoration: BoxDecoration(
                color: const Color(0xFF1DB954).withOpacity(0.1),
                borderRadius: BorderRadius.circular(6),
                border: Border.all(
                    color: const Color(0xFF1DB954).withOpacity(0.3)),
              ),
              child: const Text('Default',
                  style: TextStyle(fontSize: 9, color: Color(0xFF1DB954))),
            ),

          // Action buttons
          if (isActive) ...[
            _actionBtn(
              icon: Icons.edit_outlined,
              color: const Color(0xFF5BA3D9),
              onTap: () => _showEditSheet(item, code),
            ),
            const SizedBox(width: 6),
            _actionBtn(
              icon: Icons.remove_circle_outline_rounded,
              color: const Color(0xFFE74C3C),
              onTap: () => _confirmDeactivate(item),
            ),
          ] else
            _actionBtn(
              icon: Icons.refresh_rounded,
              color: const Color(0xFF1DB954),
              onTap: () => _reactivate(item),
            ),
        ],
      ),
    );
  }

  Widget _actionBtn({
    required IconData icon,
    required Color color,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 30, height: 30,
        decoration: BoxDecoration(
          color: color.withOpacity(0.12),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Icon(icon, color: color, size: 16),
      ),
    );
  }

  // ── Add bottom sheet ───────────────────────────────────────────────────────
  void _showAddSheet(String code) {
    final meta = kSubTypeMeta[code]!;
    final nameCtrl = TextEditingController();
    final descCtrl = TextEditingController();
    bool isSaving = false;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setSheetState) => Padding(
          padding: EdgeInsets.only(
              bottom: MediaQuery.of(ctx).viewInsets.bottom),
          child: Container(
            decoration: const BoxDecoration(
              color: Color(0xFF152232),
              borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
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
                        color: (meta['color'] as Color).withOpacity(0.12),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Icon(meta['icon'] as IconData,
                          color: meta['color'] as Color, size: 18),
                    ),
                    const SizedBox(width: 12),
                    Text('Add ${meta['label']}',
                        style: const TextStyle(
                            fontFamily: 'Georgia',
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            color: Colors.white)),
                  ],
                ),
                const SizedBox(height: 20),
                _sheetLabel('Name *'),
                const SizedBox(height: 8),
                _sheetTextField(
                    controller: nameCtrl,
                    hint: meta['hint'] as String),
                const SizedBox(height: 14),
                _sheetLabel('Description (optional)'),
                const SizedBox(height: 8),
                _sheetTextField(
                    controller: descCtrl,
                    hint: 'Short description'),
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
                          padding: const EdgeInsets.symmetric(vertical: 14),
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
                                if (nameCtrl.text.trim().isEmpty) {
                                  _showSnack('Name is required.');
                                  return;
                                }
                                setSheetState(() => isSaving = true);
                                try {
                                  await SubTypeSeedService.add(
                                    clientId: widget.clientId,
                                    subTypeCode: code,
                                    subTypeName: nameCtrl.text.trim(),
                                    subTypeDescription: descCtrl.text.trim(),
                                  );
                                  if (ctx.mounted) Navigator.pop(ctx);
                                  await _load();
                                  _showSnack('Added successfully!',
                                      success: true);
                                } catch (e) {
                                  _showSnack('Failed to add. Try again.');
                                  setSheetState(() => isSaving = false);
                                }
                              },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF1DB954),
                          foregroundColor: Colors.white,
                          disabledBackgroundColor:
                              const Color(0xFF1DB954).withOpacity(0.5),
                          elevation: 0,
                          shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(14)),
                          padding: const EdgeInsets.symmetric(vertical: 14),
                        ),
                        child: isSaving
                            ? const SizedBox(
                                width: 20, height: 20,
                                child: CircularProgressIndicator(
                                    color: Colors.white, strokeWidth: 2))
                            : const Text('Save',
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

  // ── Edit bottom sheet ──────────────────────────────────────────────────────
  void _showEditSheet(Map<String, dynamic> item, String code) {
    final meta = kSubTypeMeta[code]!;
    final nameCtrl =
        TextEditingController(text: item['SubTypeName'] ?? '');
    final descCtrl =
        TextEditingController(text: item['SubTypeDescription'] ?? '');
    bool isSaving = false;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setSheetState) => Padding(
          padding: EdgeInsets.only(
              bottom: MediaQuery.of(ctx).viewInsets.bottom),
          child: Container(
            decoration: const BoxDecoration(
              color: Color(0xFF152232),
              borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
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
                        color: (meta['color'] as Color).withOpacity(0.12),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Icon(meta['icon'] as IconData,
                          color: meta['color'] as Color, size: 18),
                    ),
                    const SizedBox(width: 12),
                    Text('Edit ${meta['label']}',
                        style: const TextStyle(
                            fontFamily: 'Georgia',
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            color: Colors.white)),
                  ],
                ),
                const SizedBox(height: 20),
                _sheetLabel('Name *'),
                const SizedBox(height: 8),
                _sheetTextField(
                    controller: nameCtrl,
                    hint: meta['hint'] as String),
                const SizedBox(height: 14),
                _sheetLabel('Description (optional)'),
                const SizedBox(height: 8),
                _sheetTextField(
                    controller: descCtrl,
                    hint: 'Short description'),
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
                          padding: const EdgeInsets.symmetric(vertical: 14),
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
                                if (nameCtrl.text.trim().isEmpty) {
                                  _showSnack('Name is required.');
                                  return;
                                }
                                setSheetState(() => isSaving = true);
                                try {
                                  await SubTypeSeedService.update(
                                    docId: item['DocID'],
                                    subTypeName: nameCtrl.text.trim(),
                                    subTypeDescription: descCtrl.text.trim(),
                                  );
                                  if (ctx.mounted) Navigator.pop(ctx);
                                  await _load();
                                  _showSnack('Updated successfully!',
                                      success: true);
                                } catch (e) {
                                  _showSnack('Failed to update. Try again.');
                                  setSheetState(() => isSaving = false);
                                }
                              },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF1DB954),
                          foregroundColor: Colors.white,
                          elevation: 0,
                          shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(14)),
                          padding: const EdgeInsets.symmetric(vertical: 14),
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

  // ── Deactivate confirm ─────────────────────────────────────────────────────
  Future<void> _confirmDeactivate(Map<String, dynamic> item) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF152232),
        shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20)),
        title: const Text('Deactivate?',
            style: TextStyle(
                color: Colors.white, fontFamily: 'Georgia')),
        content: Text(
          '"${item['SubTypeName']}" will be hidden from course setup.\n\n'
          'Existing courses using this will not be affected.',
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
            child: const Text('Deactivate',
                style: TextStyle(color: Color(0xFFE74C3C))),
          ),
        ],
      ),
    );
    if (confirm != true) return;
    try {
      await SubTypeSeedService.deactivate(item['DocID']);
      await _load();
      _showSnack('Deactivated.', success: true);
    } catch (e) {
      _showSnack('Failed to deactivate.');
    }
  }

  // ── Reactivate ─────────────────────────────────────────────────────────────
  Future<void> _reactivate(Map<String, dynamic> item) async {
    try {
      await SubTypeSeedService.reactivate(item['DocID']);
      await _load();
      _showSnack('Reactivated!', success: true);
    } catch (e) {
      _showSnack('Failed to reactivate.');
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
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
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
  }) =>
      TextField(
        controller: controller,
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