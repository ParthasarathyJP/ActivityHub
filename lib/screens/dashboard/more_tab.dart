import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'subtype_screen.dart';
import 'branch_screen.dart';

class MoreTab extends StatelessWidget {
  final String clientId;
  final String branchId;
  final String adminName;
  final String email;
  final String clientName;
  final String institutionType;
  final bool hasBranches;

  const MoreTab({
    super.key,
    required this.clientId,
    required this.branchId,
    required this.adminName,
    required this.email,
    required this.clientName,
    required this.institutionType,
    required this.hasBranches,
  });

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: 8),

            // Profile card
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: const Color(0xFF152232),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: const Color(0xFF1E3347), width: 1),
              ),
              child: Row(
                children: [
                  Container(
                    width: 52, height: 52,
                    decoration: BoxDecoration(
                      color: const Color(0xFF1DB954).withOpacity(0.15),
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: Center(
                      child: Text(
                        adminName.isNotEmpty ? adminName[0].toUpperCase() : 'A',
                        style: const TextStyle(
                            fontSize: 22,
                            fontWeight: FontWeight.bold,
                            color: Color(0xFF1DB954)),
                      ),
                    ),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(adminName,
                            style: const TextStyle(
                                fontSize: 15,
                                fontWeight: FontWeight.w600,
                                color: Colors.white)),
                        Text(email,
                            style: const TextStyle(
                                fontSize: 12, color: Color(0xFF8899AA))),
                        const SizedBox(height: 4),
                        if (institutionType.isNotEmpty)
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 8, vertical: 3),
                            decoration: BoxDecoration(
                              color: const Color(0xFF1DB954).withOpacity(0.12),
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: Text(institutionType,
                                style: const TextStyle(
                                    fontSize: 10,
                                    color: Color(0xFF1DB954),
                                    fontWeight: FontWeight.w500)),
                          ),
                      ],
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 24),

            _sectionLabel('CONFIGURE'),
            _menuItem(
              context,
              icon: Icons.account_tree_outlined,
              label: 'Branches',
              subtitle: hasBranches
                  ? 'Manage your institution branches'
                  : 'Single branch mode · tap to view',
              color: const Color(0xFF7F77DD),
              trailing: hasBranches
                  ? null
                  : Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 7, vertical: 3),
                      decoration: BoxDecoration(
                        color: const Color(0xFF5BA3D9).withOpacity(0.12),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: const Text('Single',
                          style: TextStyle(
                              fontSize: 9, color: Color(0xFF5BA3D9))),
                    ),
              onTap: () => Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => BranchScreen(
                    clientId: clientId,
                    hasBranches: hasBranches,
                  ),
                ),
              ),
            ),
            _menuItem(
              context,
              icon: Icons.category_outlined,
              label: 'Sub Types',
              subtitle: 'Courses, Timings, Duration, Payment, Revenue',
              color: const Color(0xFF5BA3D9),
              onTap: () => Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => SubTypeScreen(clientId: clientId),
                ),
              ),
            ),
            _menuItem(
              context,
              icon: Icons.event_outlined,
              label: 'Events',
              subtitle: 'Competitions, showcases, exams',
              color: const Color(0xFFE8A020),
              onTap: () {},
            ),

            const SizedBox(height: 16),

            _sectionLabel('REPORTS'),
            _menuItem(
              context,
              icon: Icons.bar_chart_rounded,
              label: 'Reports',
              subtitle: 'Monthly summaries and progress',
              color: const Color(0xFF1DB954),
              onTap: () {},
            ),

            const SizedBox(height: 16),

            _sectionLabel('ACCOUNT'),
            _menuItem(
              context,
              icon: Icons.lock_outline_rounded,
              label: 'Change Password',
              subtitle: 'Update your login credentials',
              color: const Color(0xFF8899AA),
              onTap: () {},
            ),
            _menuItem(
              context,
              icon: Icons.help_outline_rounded,
              label: 'Help & Support',
              subtitle: 'FAQs and contact support',
              color: const Color(0xFF8899AA),
              onTap: () {},
            ),

            const SizedBox(height: 16),

            // Sign out
            GestureDetector(
              onTap: () async {
                final confirm = await showDialog<bool>(
                  context: context,
                  builder: (ctx) => AlertDialog(
                    backgroundColor: const Color(0xFF152232),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(20)),
                    title: const Text('Sign out?',
                        style: TextStyle(
                            color: Colors.white, fontFamily: 'Georgia')),
                    content: const Text(
                        'You will need to sign in again to access ActivityHub.',
                        style: TextStyle(
                            color: Color(0xFF8899AA), height: 1.5)),
                    actions: [
                      TextButton(
                        onPressed: () => Navigator.pop(ctx, false),
                        child: const Text('Cancel',
                            style: TextStyle(color: Color(0xFF8899AA))),
                      ),
                      TextButton(
                        onPressed: () => Navigator.pop(ctx, true),
                        child: const Text('Sign Out',
                            style: TextStyle(color: Color(0xFFE74C3C))),
                      ),
                    ],
                  ),
                );
                if (confirm == true) {
                  await FirebaseAuth.instance.signOut();
                }
              },
              child: Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: const Color(0xFF152232),
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: const Color(0xFF1E3347)),
                ),
                child: Row(
                  children: [
                    Container(
                      width: 36, height: 36,
                      decoration: BoxDecoration(
                        color: const Color(0xFFE74C3C).withOpacity(0.12),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: const Icon(Icons.logout_rounded,
                          color: Color(0xFFE74C3C), size: 18),
                    ),
                    const SizedBox(width: 14),
                    const Text('Sign Out',
                        style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w500,
                            color: Color(0xFFE74C3C))),
                  ],
                ),
              ),
            ),

            const SizedBox(height: 32),
            Center(
              child: Text('ActivityHub · v1.0.0',
                  style: const TextStyle(
                      fontSize: 11, color: Color(0xFF3A5068))),
            ),
            const SizedBox(height: 16),
          ],
        ),
      ),
    );
  }

  Widget _sectionLabel(String text) => Padding(
        padding: const EdgeInsets.only(bottom: 10),
        child: Text(text,
            style: const TextStyle(
                fontSize: 11,
                color: Color(0xFF3A5068),
                fontWeight: FontWeight.w600,
                letterSpacing: 1)),
      );

  Widget _menuItem(
    BuildContext context, {
    required IconData icon,
    required String label,
    required String subtitle,
    required Color color,
    required VoidCallback onTap,
    Widget? trailing,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
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
              width: 36, height: 36,
              decoration: BoxDecoration(
                color: color.withOpacity(0.12),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(icon, color: color, size: 18),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(label,
                      style: const TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w500,
                          color: Colors.white)),
                  Text(subtitle,
                      style: const TextStyle(
                          fontSize: 11, color: Color(0xFF556677))),
                ],
              ),
            ),
            if (trailing != null) ...[
              trailing,
              const SizedBox(width: 6),
            ],
            const Icon(Icons.chevron_right_rounded,
                color: Color(0xFF3A5068), size: 18),
          ],
        ),
      ),
    );
  }
}