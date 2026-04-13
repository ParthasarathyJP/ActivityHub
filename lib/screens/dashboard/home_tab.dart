import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class HomeTab extends StatefulWidget {
  final String clientId;
  final String branchId;
  final String adminName;
  final String clientName;
  final String institutionType;
  final bool isLoading;

  const HomeTab({
    super.key,
    required this.clientId,
    required this.branchId,
    required this.adminName,
    required this.clientName,
    required this.institutionType,
    required this.isLoading,
  });

  @override
  State<HomeTab> createState() => _HomeTabState();
}

class _HomeTabState extends State<HomeTab> {
  int _slideIndex = 0;
  final List<String> _slides = ['Overview', 'Students', 'Staff', 'Courses'];

  // Live counts from Firestore
  int _studentCount = 0;
  int _courseCount = 0;
  int _staffCount = 0;
  int _branchCount = 0;
  bool _statsLoaded = false;

  @override
  void initState() {
    super.initState();
    _loadStats();
  }

  Future<void> _loadStats() async {
    final db = FirebaseFirestore.instance;

    // Query each independently — one failure won't zero out others
    Future<int> safeCount(Query q) async {
      try {
        final snap = await q.count().get();
        return snap.count ?? 0;
      } catch (e) {
        debugPrint('Count query failed: $e');
        // Fallback: get docs and count manually
        try {
          final snap = await q.get();
          return snap.docs.length;
        } catch (_) { return 0; }
      }
    }

    final studentCount = await safeCount(
        db.collection('Student').where('ClientID', isEqualTo: widget.clientId));
    final courseCount  = await safeCount(
        db.collection('Course').where('ClientID', isEqualTo: widget.clientId));
    final staffCount   = await safeCount(
        db.collection('Staff').where('ClientID', isEqualTo: widget.clientId));
    final branchCount  = await safeCount(
        db.collection('Branch').where('ClientID', isEqualTo: widget.clientId));

    if (mounted) {
      setState(() {
        _studentCount = studentCount;
        _courseCount  = courseCount;
        _staffCount   = staffCount;
        _branchCount  = branchCount;
        _statsLoaded  = true;
      });
    }
  }

  String _greeting() {
    final hour = DateTime.now().hour;
    if (hour < 12) return 'Good morning';
    if (hour < 17) return 'Good afternoon';
    return 'Good evening';
  }

  String _firstName() {
    final parts = widget.adminName.trim().split(' ');
    return parts.isNotEmpty ? parts[0] : 'Admin';
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: RefreshIndicator(
        onRefresh: _loadStats,
        color: const Color(0xFF1DB954),
        backgroundColor: const Color(0xFF152232),
        child: SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.symmetric(horizontal: 20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SizedBox(height: 20),
              _buildHeader(),
              const SizedBox(height: 20),
              _buildSlideChips(),
              const SizedBox(height: 16),
              _buildSlideContent(),
              const SizedBox(height: 24),
              _buildSectionTitle('Recent Activity'),
              const SizedBox(height: 12),
              _buildRecentActivity(),
              const SizedBox(height: 32),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return Row(
      children: [
        // Avatar
        Container(
          width: 46,
          height: 46,
          decoration: BoxDecoration(
            color: const Color(0xFF1DB954).withOpacity(0.15),
            borderRadius: BorderRadius.circular(14),
          ),
          child: Center(
            child: Text(
              _firstName().isNotEmpty ? _firstName()[0].toUpperCase() : 'A',
              style: const TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: Color(0xFF1DB954),
              ),
            ),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                '${_greeting()}, ${_firstName()}',
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  color: Colors.white,
                ),
              ),
              Text(
                widget.isLoading
                    ? 'Loading...'
                    : widget.clientName.isNotEmpty
                        ? widget.clientName
                        : 'ActivityHub',
                style: const TextStyle(
                  fontSize: 12,
                  color: Color(0xFF8899AA),
                ),
              ),
            ],
          ),
        ),
        // Notification bell
        Container(
          width: 40,
          height: 40,
          decoration: BoxDecoration(
            color: const Color(0xFF152232),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: const Color(0xFF1E3347), width: 1),
          ),
          child: const Icon(Icons.notifications_outlined,
              color: Color(0xFF8899AA), size: 20),
        ),
      ],
    );
  }

  Widget _buildSlideChips() {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: List.generate(_slides.length, (i) {
          final isActive = _slideIndex == i;
          return GestureDetector(
            onTap: () => setState(() => _slideIndex = i),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              margin: const EdgeInsets.only(right: 8),
              padding:
                  const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              decoration: BoxDecoration(
                color: isActive
                    ? const Color(0xFF1DB954)
                    : const Color(0xFF152232),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(
                  color: isActive
                      ? const Color(0xFF1DB954)
                      : const Color(0xFF1E3347),
                  width: 1,
                ),
              ),
              child: Text(
                _slides[i],
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w500,
                  color: isActive ? Colors.white : const Color(0xFF8899AA),
                ),
              ),
            ),
          );
        }),
      ),
    );
  }

  Widget _buildSlideContent() {
    switch (_slideIndex) {
      case 0:
        return _buildOverviewStats();
      case 1:
        return _buildStudentStats();
      case 2:
        return _buildStaffStats();
      case 3:
        return _buildCourseStats();
      default:
        return _buildOverviewStats();
    }
  }

  Widget _buildOverviewStats() {
    return Column(
      children: [
        Row(
          children: [
            Expanded(child: _statCard('Students', _studentCount.toString(),
                Icons.school_outlined, const Color(0xFF1DB954))),
            const SizedBox(width: 12),
            Expanded(child: _statCard('Courses', _courseCount.toString(),
                Icons.menu_book_outlined, const Color(0xFF5BA3D9))),
          ],
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(child: _statCard('Staff', _staffCount.toString(),
                Icons.badge_outlined, const Color(0xFFE8A020))),
            const SizedBox(width: 12),
            Expanded(child: _statCard('Branches', _branchCount.toString(),
                Icons.account_tree_outlined, const Color(0xFF7F77DD))),
          ],
        ),
      ],
    );
  }

  Widget _buildStudentStats() {
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('Student')
          .where('ClientID', isEqualTo: widget.clientId)
          .orderBy('CreatedAt', descending: false)
          .limit(3)
          .snapshots(),
      builder: (context, snap) {
        if (snap.hasError) {
          debugPrint('Student stream error: ${snap.error}');
          return _emptyCard('Unable to load students', Icons.school_outlined);
        }
        if (!snap.hasData) return _loadingCard();
        final docs = snap.data!.docs;
        if (docs.isEmpty) return _emptyCard('No students yet', Icons.school_outlined);
        return Column(
          children: [
            _statCard('Total Students', _studentCount.toString(),
                Icons.school_outlined, const Color(0xFF1DB954)),
            const SizedBox(height: 12),
            ...docs.map((d) {
              final data = d.data() as Map<String, dynamic>;
              return _listCard(
                title: data['Name'] ?? 'Unknown',
                subtitle: data['StudentEnrollmentNo'] ?? '',
                icon: Icons.person_outline_rounded,
                iconColor: const Color(0xFF1DB954),
              );
            }),
          ],
        );
      },
    );
  }

  Widget _buildStaffStats() {
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('Staff')
          .where('ClientID', isEqualTo: widget.clientId)
          .orderBy('CreatedAt', descending: false)
          .limit(3)
          .snapshots(),
      builder: (context, snap) {
        if (snap.hasError) {
          debugPrint('Staff stream error: ${snap.error}');
          return _emptyCard('Unable to load staff', Icons.badge_outlined);
        }
        if (!snap.hasData) return _loadingCard();
        final docs = snap.data!.docs;
        if (docs.isEmpty) return _emptyCard('No staff yet', Icons.badge_outlined);
        return Column(
          children: [
            _statCard('Total Staff', _staffCount.toString(),
                Icons.badge_outlined, const Color(0xFFE8A020)),
            const SizedBox(height: 12),
            ...docs.map((d) {
              final data = d.data() as Map<String, dynamic>;
              return _listCard(
                title: data['StaffName'] ?? 'Unknown',
                subtitle: '${data['Role'] ?? ''} · ${data['StaffEnrollmentNo'] ?? ''}',
                icon: Icons.badge_outlined,
                iconColor: const Color(0xFFE8A020),
              );
            }),
          ],
        );
      },
    );
  }

  Widget _buildCourseStats() {
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('Course')
          .where('ClientID', isEqualTo: widget.clientId)
          .orderBy('CreatedAt', descending: false)
          .limit(3)
          .snapshots(),
      builder: (context, snap) {
        if (snap.hasError) {
          debugPrint('Course stream error: ${snap.error}');
          return _emptyCard('Unable to load courses', Icons.menu_book_outlined);
        }
        if (!snap.hasData) return _loadingCard();
        final docs = snap.data!.docs;
        if (docs.isEmpty) return _emptyCard('No courses yet', Icons.menu_book_outlined);
        return Column(
          children: [
            _statCard('Total Courses', _courseCount.toString(),
                Icons.menu_book_outlined, const Color(0xFF5BA3D9)),
            const SizedBox(height: 12),
            ...docs.map((d) {
              final data = d.data() as Map<String, dynamic>;
              final fee = data['CourseFee'];
              return _listCard(
                title: data['CourseName'] ?? 'Unknown',
                subtitle: fee != null ? '₹$fee / month' : '',
                icon: Icons.menu_book_outlined,
                iconColor: const Color(0xFF5BA3D9),
              );
            }),
          ],
        );
      },
    );
  }

  Widget _buildRecentActivity() {
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('ClientAuthorizedUsers')
          .where('ClientID', isEqualTo: widget.clientId)
          .orderBy('CreatedAt', descending: true)
          .limit(5)
          .snapshots(),
      builder: (context, snap) {
        if (!snap.hasData) return _loadingCard();
        final docs = snap.data!.docs;
        if (docs.isEmpty) {
          return _emptyCard('No recent activity', Icons.history_rounded);
        }
        return Column(
          children: docs.map((d) {
            final data = d.data() as Map<String, dynamic>;
            final ts = data['CreatedAt'] as Timestamp?;
            final date = ts != null ? _formatDate(ts.toDate()) : 'Recently';
            final userType = data['UserType'] as String? ?? 'User';
            final name = data['AdminName'] as String? ?? data['Email'] ?? '';

            IconData icon = Icons.person_add_outlined;
            Color iconColor = const Color(0xFF1DB954);
            String title = '$userType account created';

            if (userType == 'Student') {
              icon = Icons.school_outlined;
              iconColor = const Color(0xFF5BA3D9);
            } else if (userType == 'Staff') {
              icon = Icons.badge_outlined;
              iconColor = const Color(0xFFE8A020);
            } else if (userType == 'Client') {
              icon = Icons.business_outlined;
              iconColor = const Color(0xFF1DB954);
            }

            return _listCard(
              title: title,
              subtitle: '$name · $date',
              icon: icon,
              iconColor: iconColor,
            );
          }).toList(),
        );
      },
    );
  }

  String _formatDate(DateTime dt) {
    final now = DateTime.now();
    final diff = now.difference(dt);
    if (diff.inDays == 0) return 'Today';
    if (diff.inDays == 1) return 'Yesterday';
    if (diff.inDays < 7) return '${diff.inDays} days ago';
    return '${dt.day}/${dt.month}/${dt.year}';
  }

  // ── Reusable sub-widgets ──────────────────────────────────────────────────

  Widget _sectionTitle(String text) => Padding(
        padding: const EdgeInsets.only(bottom: 12),
        child: Text(text,
            style: const TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: Color(0xFF8899AA),
                letterSpacing: 0.5)),
      );

  Widget _buildSectionTitle(String text) => Text(
        text,
        style: const TextStyle(
          fontSize: 15,
          fontWeight: FontWeight.w600,
          color: Colors.white,
        ),
      );

  Widget _statCard(String label, String value, IconData icon, Color color) {
    return Container(
        width: double.infinity,
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: const Color(0xFF152232),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: const Color(0xFF1E3347), width: 1),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: 36,
              height: 36,
              decoration: BoxDecoration(
                color: color.withOpacity(0.12),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(icon, color: color, size: 18),
            ),
            const SizedBox(height: 12),
            _statsLoaded
                ? Text(value,
                    style: const TextStyle(
                        fontSize: 24,
                        fontWeight: FontWeight.bold,
                        color: Colors.white))
                : const SizedBox(
                    width: 24,
                    height: 24,
                    child: CircularProgressIndicator(
                        strokeWidth: 2, color: Color(0xFF1DB954))),
            const SizedBox(height: 4),
            Text(label,
                style: const TextStyle(
                    fontSize: 12, color: Color(0xFF556677))),
          ],
        ),
    );
  }

  Widget _listCard({
    required String title,
    required String subtitle,
    required IconData icon,
    required Color iconColor,
  }) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFF152232),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFF1E3347), width: 1),
      ),
      child: Row(
        children: [
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              color: iconColor.withOpacity(0.12),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(icon, color: iconColor, size: 18),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title,
                    style: const TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w500,
                        color: Colors.white)),
                if (subtitle.isNotEmpty)
                  Text(subtitle,
                      style: const TextStyle(
                          fontSize: 11, color: Color(0xFF556677))),
              ],
            ),
          ),
          const Icon(Icons.chevron_right_rounded,
              color: Color(0xFF3A5068), size: 18),
        ],
      ),
    );
  }

  Widget _loadingCard() => Container(
        height: 80,
        decoration: BoxDecoration(
          color: const Color(0xFF152232),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: const Color(0xFF1E3347)),
        ),
        child: const Center(
          child: CircularProgressIndicator(
              strokeWidth: 2, color: Color(0xFF1DB954)),
        ),
      );

  Widget _emptyCard(String msg, IconData icon) => Container(
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          color: const Color(0xFF152232),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: const Color(0xFF1E3347)),
        ),
        child: Column(
          children: [
            Icon(icon, color: const Color(0xFF3A5068), size: 32),
            const SizedBox(height: 8),
            Text(msg,
                style: const TextStyle(
                    fontSize: 13, color: Color(0xFF556677))),
          ],
        ),
      );
}