import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'dashboard/home_tab.dart';
import 'dashboard/courses_tab.dart';
import 'dashboard/people_tab.dart';
import 'dashboard/finance_tab.dart';
import 'dashboard/more_tab.dart';

class ClientDashboard extends StatefulWidget {
  final String clientId;
  final String branchId;
  final String adminName;
  final String email;
  final String uid;

  const ClientDashboard({
    super.key,
    required this.clientId,
    required this.branchId,
    required this.adminName,
    required this.email,
    required this.uid,
  });

  @override
  State<ClientDashboard> createState() => _ClientDashboardState();
}

class _ClientDashboardState extends State<ClientDashboard>
    with TickerProviderStateMixin {
  int _currentIndex = 0;
  late PageController _pageController;
  late AnimationController _fadeController;
  late Animation<double> _fadeAnim;

  // Client info
  String _clientName      = '';
  String _institutionType = '';
  bool   _hasBranches     = false;
  bool   _isLoadingClient = true;

  @override
  void initState() {
    super.initState();
    _pageController = PageController();
    _fadeController = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 400));
    _fadeAnim =
        CurvedAnimation(parent: _fadeController, curve: Curves.easeOut);
    _fadeController.forward();
    _loadClientInfo();
  }

  @override
  void dispose() {
    _pageController.dispose();
    _fadeController.dispose();
    super.dispose();
  }

  Future<void> _loadClientInfo() async {
    try {
      final doc = await FirebaseFirestore.instance
          .collection('ClientMaster')
          .doc(widget.clientId)
          .get();
      if (doc.exists && mounted) {
        final data = doc.data()!;
        setState(() {
          _clientName      = data['ClientName']      ?? '';
          _institutionType = data['InstitutionType'] ?? '';
          _hasBranches     = data['HasBranches']     == true;
          _isLoadingClient = false;
        });
      }
    } catch (e) {
      if (mounted) setState(() => _isLoadingClient = false);
    }
  }

  void _onTabTapped(int index) {
    setState(() => _currentIndex = index);
    _pageController.jumpToPage(index);
    _fadeController.reset();
    _fadeController.forward();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0D1B2A),
      body: FadeTransition(
        opacity: _fadeAnim,
        child: PageView(
          controller: _pageController,
          physics: const NeverScrollableScrollPhysics(),
          children: [
            HomeTab(
              clientId:        widget.clientId,
              branchId:        widget.branchId,
              adminName:       widget.adminName,
              clientName:      _clientName,
              institutionType: _institutionType,
              isLoading:       _isLoadingClient,
            ),
            CoursesTab(
              clientId: widget.clientId,
              branchId: widget.branchId,
            ),
            PeopleTab(
              clientId: widget.clientId,
              branchId: widget.branchId,
            ),
            FinanceTab(
              clientId: widget.clientId,
              branchId: widget.branchId,
            ),
            MoreTab(
              clientId:        widget.clientId,
              branchId:        widget.branchId,
              adminName:       widget.adminName,
              email:           widget.email,
              clientName:      _clientName,
              institutionType: _institutionType,
              hasBranches:     _hasBranches,
            ),
          ],
        ),
      ),
      bottomNavigationBar: _buildBottomNav(),
    );
  }

  Widget _buildBottomNav() {
    return Container(
      decoration: const BoxDecoration(
        color: Color(0xFF0D1B2A),
        border: Border(top: BorderSide(color: Color(0xFF1E3347), width: 1)),
      ),
      child: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              _navItem(0, Icons.grid_view_rounded,
                  Icons.grid_view_outlined, 'Home'),
              _navItem(1, Icons.menu_book_rounded,
                  Icons.menu_book_outlined, 'Courses'),
              _navItem(2, Icons.people_rounded,
                  Icons.people_outline_rounded, 'People'),
              _navItem(3, Icons.account_balance_wallet_rounded,
                  Icons.account_balance_wallet_outlined, 'Finance'),
              _navItem(4, Icons.more_horiz_rounded,
                  Icons.more_horiz_rounded, 'More'),
            ],
          ),
        ),
      ),
    );
  }

  Widget _navItem(int index, IconData activeIcon,
      IconData inactiveIcon, String label) {
    final isActive = _currentIndex == index;
    return GestureDetector(
      onTap: () => _onTabTapped(index),
      behavior: HitTestBehavior.opaque,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        decoration: BoxDecoration(
          color: isActive
              ? const Color(0xFF1DB954).withOpacity(0.12)
              : Colors.transparent,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              isActive ? activeIcon : inactiveIcon,
              color: isActive
                  ? const Color(0xFF1DB954)
                  : const Color(0xFF556677),
              size: 22,
            ),
            const SizedBox(height: 3),
            Text(
              label,
              style: TextStyle(
                fontSize: 10,
                fontWeight:
                    isActive ? FontWeight.w600 : FontWeight.normal,
                color: isActive
                    ? const Color(0xFF1DB954)
                    : const Color(0xFF556677),
              ),
            ),
          ],
        ),
      ),
    );
  }
}