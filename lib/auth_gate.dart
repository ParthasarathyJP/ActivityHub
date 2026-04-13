import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'screens/login_screen.dart';
import 'screens/client_dashboard.dart';
// TODO: import 'screens/staff_dashboard.dart';
// TODO: import 'screens/student_dashboard.dart';

class AuthGate extends StatelessWidget {
  const AuthGate({super.key});

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<User?>(
      stream: FirebaseAuth.instance.authStateChanges(),
      builder: (context, authSnapshot) {

        // ── Still checking auth state ────────────────────────────────────────
        if (authSnapshot.connectionState == ConnectionState.waiting) {
          return const _SplashScreen();
        }

        // ── Not logged in → show Login ───────────────────────────────────────
        if (!authSnapshot.hasData || authSnapshot.data == null) {
          return const LoginScreen();
        }

        // ── Logged in → resolve role from Firestore ──────────────────────────
        final uid = authSnapshot.data!.uid;
        return FutureBuilder<DocumentSnapshot>(
          future: FirebaseFirestore.instance
              .collection('ClientAuthorizedUsers')
              .doc(uid)
              .get(),
          builder: (context, userSnapshot) {

            // Still loading user record
            if (userSnapshot.connectionState == ConnectionState.waiting) {
              return const _SplashScreen();
            }

            // User record not found — show error with sign out option
            if (!userSnapshot.hasData || !userSnapshot.data!.exists) {
              return _UserNotFoundScreen(uid: uid);
            }

            // Read role fields
            final data = userSnapshot.data!.data() as Map<String, dynamic>;
            final userType = data['UserType'] as String? ?? '';
            final clientId = data['ClientID'] as String? ?? '';
            final branchId = data['BranchID'] as String? ?? '';
            final adminName = data['AdminName'] as String? ?? '';
            final email = data['Email'] as String? ?? '';

            // Route based on UserType
            switch (userType) {
              case 'Client':
                return ClientDashboard(
                  clientId: clientId,
                  branchId: branchId,
                  adminName: adminName,
                  email: email,
                  uid: uid,
                  userType: userType,
                );
              case 'Staff':
                // TODO: return StaffDashboard(...)
                return _ComingSoonScreen(role: 'Staff', uid: uid);
              case 'Student':
                // TODO: return StudentDashboard(...)
                return _ComingSoonScreen(role: 'Student', uid: uid);
              default:
                return _UserNotFoundScreen(uid: uid);
            }
          },
        );
      },
    );
  }
}

// ── Splash / Loading screen ───────────────────────────────────────────────────
class _SplashScreen extends StatelessWidget {
  const _SplashScreen();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0D1B2A),
      body: Stack(
        children: [
          Positioned(
            top: -80, right: -60,
            child: Container(
              width: 280, height: 280,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: const Color(0xFF1A6B4A).withOpacity(0.18),
              ),
            ),
          ),
          Positioned(
            bottom: -100, left: -80,
            child: Container(
              width: 320, height: 320,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: const Color(0xFF1A4B6B).withOpacity(0.22),
              ),
            ),
          ),
          Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 64,
                  height: 64,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(20),
                    gradient: const LinearGradient(
                      colors: [Color(0xFF1DB954), Color(0xFF17A847)],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                  ),
                  child: const Icon(Icons.hub_rounded,
                      color: Colors.white, size: 36),
                ),
                const SizedBox(height: 24),
                const Text(
                  'ActivityHub',
                  style: TextStyle(
                    fontFamily: 'Georgia',
                    fontSize: 28,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                    letterSpacing: -0.5,
                  ),
                ),
                const SizedBox(height: 32),
                const SizedBox(
                  width: 24,
                  height: 24,
                  child: CircularProgressIndicator(
                    color: Color(0xFF1DB954),
                    strokeWidth: 2.5,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ── User not found / role error screen ───────────────────────────────────────
class _UserNotFoundScreen extends StatelessWidget {
  final String uid;
  const _UserNotFoundScreen({required this.uid});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0D1B2A),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 64,
                height: 64,
                decoration: BoxDecoration(
                  color: const Color(0xFFE74C3C).withOpacity(0.12),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: const Icon(Icons.error_outline_rounded,
                    color: Color(0xFFE74C3C), size: 32),
              ),
              const SizedBox(height: 20),
              const Text(
                'Account not found',
                style: TextStyle(
                  fontFamily: 'Georgia',
                  fontSize: 22,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                ),
              ),
              const SizedBox(height: 8),
              const Text(
                'Your account is not linked to any institution.\nPlease contact your administrator.',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 14,
                  color: Color(0xFF8899AA),
                  height: 1.5,
                ),
              ),
              const SizedBox(height: 32),
              SizedBox(
                width: double.infinity,
                height: 52,
                child: ElevatedButton(
                  onPressed: () async {
                    await FirebaseAuth.instance.signOut();
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF1DB954),
                    foregroundColor: Colors.white,
                    elevation: 0,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                  ),
                  child: const Text(
                    'Sign Out',
                    style: TextStyle(
                        fontSize: 16, fontWeight: FontWeight.w600),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ── Coming soon screen for Staff / Student dashboards ─────────────────────────
class _ComingSoonScreen extends StatelessWidget {
  final String role;
  final String uid;
  const _ComingSoonScreen({required this.role, required this.uid});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0D1B2A),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 64,
                height: 64,
                decoration: BoxDecoration(
                  color: const Color(0xFF1DB954).withOpacity(0.12),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: const Icon(Icons.construction_rounded,
                    color: Color(0xFF1DB954), size: 32),
              ),
              const SizedBox(height: 20),
              Text(
                '$role Dashboard',
                style: const TextStyle(
                  fontFamily: 'Georgia',
                  fontSize: 22,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                ),
              ),
              const SizedBox(height: 8),
              const Text(
                'Coming soon! This dashboard\nis currently being built.',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 14,
                  color: Color(0xFF8899AA),
                  height: 1.5,
                ),
              ),
              const SizedBox(height: 32),
              SizedBox(
                width: double.infinity,
                height: 52,
                child: ElevatedButton(
                  onPressed: () async {
                    await FirebaseAuth.instance.signOut();
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF152232),
                    foregroundColor: const Color(0xFF8899AA),
                    elevation: 0,
                    side: const BorderSide(color: Color(0xFF1E3347)),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                  ),
                  child: const Text(
                    'Sign Out',
                    style: TextStyle(
                        fontSize: 16, fontWeight: FontWeight.w500),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}