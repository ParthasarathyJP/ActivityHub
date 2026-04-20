import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'screens/login_screen.dart';
import 'screens/client_dashboard.dart';
import 'screens/staff_dashboard.dart';
import 'screens/student_dashboard.dart';

class AuthGate extends StatelessWidget {
  const AuthGate({super.key});

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<User?>(
      stream: FirebaseAuth.instance.authStateChanges(),
      builder: (context, authSnapshot) {

        if (authSnapshot.connectionState == ConnectionState.waiting) {
          return const _SplashScreen();
        }

        if (!authSnapshot.hasData || authSnapshot.data == null) {
          return const LoginScreen();
        }

        final uid = authSnapshot.data!.uid;
        return FutureBuilder<DocumentSnapshot>(
          future: FirebaseFirestore.instance
              .collection('ClientAuthorizedUsers')
              .doc(uid)
              .get(),
          builder: (context, userSnapshot) {

            if (userSnapshot.connectionState == ConnectionState.waiting) {
              return const _SplashScreen();
            }

            if (!userSnapshot.hasData || !userSnapshot.data!.exists) {
              return _UserNotFoundScreen(uid: uid);
            }

            final data           = userSnapshot.data!.data() as Map<String, dynamic>;
            final userType       = data['UserType'] as String? ?? '';
            final clientId       = data['ClientID'] as String? ?? '';
            final branchId       = data['BranchID'] as String? ?? '';
            final adminName      = data['AdminName'] as String? ?? '';
            final email          = data['Email'] as String? ?? '';
            final mustChange     = data['MustChangePassword'] as bool? ?? false;
            final linkedId       = data['LinkedID'] as String? ?? '';
            final enrollNo       = data['StaffEnrollmentNo'] as String?
                ?? data['StudentEnrollmentNo'] as String? ?? '';

            switch (userType) {
              case 'Client':
                return ClientDashboard(
                  clientId:  clientId,
                  branchId:  branchId,
                  adminName: adminName,
                  email:     email,
                  uid:       uid,
                  userType:  userType,
                );

              case 'Staff':
                // Force password change on first login
                if (mustChange) {
                  return ForcePasswordChangeScreen(
                    uid:       uid,
                    clientId:  clientId,
                    enrollNo:  enrollNo,
                    userType:  'Staff',
                  );
                }
                return StaffDashboard(
                  uid:        uid,
                  clientId:   clientId,
                  branchId:   branchId,
                  staffDocId: linkedId,
                  enrollNo:   enrollNo,
                  staffName:  adminName,
                  email:      email,
                );

              case 'Student':
                if (mustChange) {
                  return ForcePasswordChangeScreen(
                    uid:      uid,
                    clientId: clientId,
                    enrollNo: enrollNo,
                    userType: 'Student',
                  );
                }
                // TODO: return StudentDashboard(...)
                return StudentDashboard(
                  uid:         uid,
                  clientId:    clientId,
                  enrollNo:    enrollNo,
                  studentName: adminName,
                  email:       email,
                );

              default:
                return _UserNotFoundScreen(uid: uid);
            }
          },
        );
      },
    );
  }
}

// ── Force Password Change Screen ─────────────────────────────────────────────
class ForcePasswordChangeScreen extends StatefulWidget {
  final String uid;
  final String clientId;
  final String enrollNo;
  final String userType;

  const ForcePasswordChangeScreen({
    super.key,
    required this.uid,
    required this.clientId,
    required this.enrollNo,
    required this.userType,
  });

  @override
  State<ForcePasswordChangeScreen> createState() =>
      _ForcePasswordChangeScreenState();
}

class _ForcePasswordChangeScreenState
    extends State<ForcePasswordChangeScreen> {
  final _newPassCtrl    = TextEditingController();
  final _confirmCtrl    = TextEditingController();
  final _emailCtrl      = TextEditingController();
  bool _obscureNew      = true;
  bool _obscureConfirm  = true;
  bool _isSaving        = false;
  bool _showEmail       = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    // Pre-fill email field with current auth email
    final user = FirebaseAuth.instance.currentUser;
    if (user?.email != null) _emailCtrl.text = user!.email!;
    // Show email field only if email is synthetic
    _showEmail = (user?.email?.contains('@activityhub.app') ?? false) ||
        (user?.email?.contains('.activityhub.app') ?? false);
  }

  @override
  void dispose() {
    _newPassCtrl.dispose();
    _confirmCtrl.dispose();
    _emailCtrl.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    setState(() { _error = null; _isSaving = true; });

    final newPass = _newPassCtrl.text.trim();
    final confirm = _confirmCtrl.text.trim();
    final newEmail = _emailCtrl.text.trim();

    // Validate
    if (newPass.length < 6) {
      setState(() { _error = 'Password must be at least 6 characters.'; _isSaving = false; });
      return;
    }
    if (newPass == widget.enrollNo) {
      setState(() { _error = 'New password cannot be same as enrollment number.'; _isSaving = false; });
      return;
    }
    if (newPass != confirm) {
      setState(() { _error = 'Passwords do not match.'; _isSaving = false; });
      return;
    }
    if (_showEmail && newEmail.isEmpty) {
      setState(() { _error = 'Please enter your email address.'; _isSaving = false; });
      return;
    }

    try {
      final user = FirebaseAuth.instance.currentUser!;

      // Update password
      await user.updatePassword(newPass);

      // Update email if changed from synthetic
      if (_showEmail) {
        final currentEmail = user.email ?? '';
        if (newEmail != currentEmail && newEmail.isNotEmpty) {
          await user.verifyBeforeUpdateEmail(newEmail);
        }
      }

      // Update Firestore — MustChangePassword = false
      final db    = FirebaseFirestore.instance;
      final batch = db.batch();

      batch.update(db.collection('ClientAuthorizedUsers').doc(widget.uid), {
        'MustChangePassword': false,
        if (_showEmail && _emailCtrl.text.trim().isNotEmpty)
          'Email': _emailCtrl.text.trim(),
        'UpdatedAt': FieldValue.serverTimestamp(),
      });

      // Also update Staff/Student collection email
      if (widget.userType == 'Staff') {
        final staffSnap = await db.collection('Staff')
            .where('FirebaseUID', isEqualTo: widget.uid)
            .limit(1).get();
        if (staffSnap.docs.isNotEmpty) {
          batch.update(staffSnap.docs.first.reference, {
            if (_showEmail && _emailCtrl.text.trim().isNotEmpty)
              'StaffContact.email': _emailCtrl.text.trim(),
            'UpdatedAt': FieldValue.serverTimestamp(),
          });
        }
      }

      await batch.commit();

      // AuthGate will automatically re-route after MustChangePassword = false
      // Force refresh by signing out and back in with new password
      final email = _showEmail ? _emailCtrl.text.trim() : user.email!;
      await FirebaseAuth.instance.signOut();
      await FirebaseAuth.instance.signInWithEmailAndPassword(
          email: email, password: newPass);

    } on FirebaseAuthException catch (e) {
      String msg = 'Failed to update. Please try again.';
      if (e.code == 'requires-recent-login') {
        msg = 'Session expired. Please sign out and sign in again.';
      } else if (e.code == 'email-already-in-use') {
        msg = 'This email is already in use by another account.';
      } else if (e.code == 'invalid-email') {
        msg = 'Please enter a valid email address.';
      }
      setState(() { _error = msg; _isSaving = false; });
    } catch (e) {
      setState(() { _error = 'Error: ${e.toString()}'; _isSaving = false; });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0D1B2A),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SizedBox(height: 40),
              // Icon
              Center(child: Container(
                width: 72, height: 72,
                decoration: BoxDecoration(
                  color: const Color(0xFF1DB954).withOpacity(0.12),
                  borderRadius: BorderRadius.circular(20)),
                child: const Icon(Icons.lock_outline_rounded,
                    color: Color(0xFF1DB954), size: 36))),
              const SizedBox(height: 24),
              const Center(child: Text('Set New Password',
                  style: TextStyle(fontFamily: 'Georgia', fontSize: 24,
                      fontWeight: FontWeight.bold, color: Colors.white))),
              const SizedBox(height: 8),
              Center(child: Text(
                'Welcome! Please set a new password\nfor your account (${widget.enrollNo}).',
                textAlign: TextAlign.center,
                style: const TextStyle(fontSize: 13,
                    color: Color(0xFF556677), height: 1.5))),
              const SizedBox(height: 32),

              // Email field (only if synthetic email)
              if (_showEmail) ...[
                _lbl('Your Email Address'),
                const SizedBox(height: 8),
                _tf(ctrl: _emailCtrl, hint: 'your@email.com',
                    icon: Icons.email_outlined,
                    kb: TextInputType.emailAddress),
                const SizedBox(height: 6),
                const Text(
                  'This will be your new login email.',
                  style: TextStyle(fontSize: 11, color: Color(0xFF556677))),
                const SizedBox(height: 16),
              ],

              // New password
              _lbl('New Password'),
              const SizedBox(height: 8),
              _passField(ctrl: _newPassCtrl,
                  hint: 'Min. 6 characters',
                  obscure: _obscureNew,
                  toggle: () => setState(() => _obscureNew = !_obscureNew)),
              const SizedBox(height: 16),

              // Confirm password
              _lbl('Confirm Password'),
              const SizedBox(height: 8),
              _passField(ctrl: _confirmCtrl,
                  hint: 'Re-enter new password',
                  obscure: _obscureConfirm,
                  toggle: () => setState(() => _obscureConfirm = !_obscureConfirm)),

              // Error
              if (_error != null) ...[
                const SizedBox(height: 14),
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: const Color(0xFFE74C3C).withOpacity(0.08),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: const Color(0xFFE74C3C).withOpacity(0.3))),
                  child: Row(children: [
                    const Icon(Icons.error_outline_rounded,
                        color: Color(0xFFE74C3C), size: 16),
                    const SizedBox(width: 8),
                    Expanded(child: Text(_error!,
                        style: const TextStyle(fontSize: 12,
                            color: Color(0xFFE74C3C), height: 1.4))),
                  ])),
              ],

              const SizedBox(height: 24),
              SizedBox(width: double.infinity,
                child: ElevatedButton(
                  onPressed: _isSaving ? null : _save,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF1DB954),
                    foregroundColor: Colors.white,
                    elevation: 0,
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14)),
                    padding: const EdgeInsets.symmetric(vertical: 16)),
                  child: _isSaving
                      ? const SizedBox(width: 22, height: 22,
                          child: CircularProgressIndicator(
                              color: Colors.white, strokeWidth: 2))
                      : const Text('Save & Continue',
                          style: TextStyle(fontSize: 16,
                              fontWeight: FontWeight.w600)))),

              const SizedBox(height: 16),
              Center(child: TextButton(
                onPressed: () async => FirebaseAuth.instance.signOut(),
                child: const Text('Sign out',
                    style: TextStyle(color: Color(0xFF556677), fontSize: 13)))),
            ],
          ),
        ),
      ),
    );
  }

  Widget _lbl(String t) => Text(t,
      style: const TextStyle(fontSize: 13,
          fontWeight: FontWeight.w500, color: Color(0xFF8899AA)));

  Widget _tf({required TextEditingController ctrl, required String hint,
      required IconData icon, TextInputType kb = TextInputType.text}) =>
    TextField(controller: ctrl, keyboardType: kb,
      style: const TextStyle(color: Colors.white, fontSize: 15),
      cursorColor: const Color(0xFF1DB954),
      decoration: InputDecoration(hintText: hint,
        hintStyle: const TextStyle(color: Color(0xFF3A5068)),
        prefixIcon: Icon(icon, color: const Color(0xFF3A5068), size: 20),
        filled: true, fillColor: const Color(0xFF152232),
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12),
            borderSide: const BorderSide(color: Color(0xFF1E3347))),
        enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12),
            borderSide: const BorderSide(color: Color(0xFF1E3347))),
        focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12),
            borderSide: const BorderSide(color: Color(0xFF1DB954), width: 1.5))));

  Widget _passField({required TextEditingController ctrl, required String hint,
      required bool obscure, required VoidCallback toggle}) =>
    TextField(controller: ctrl, obscureText: obscure,
      style: const TextStyle(color: Colors.white, fontSize: 15),
      cursorColor: const Color(0xFF1DB954),
      decoration: InputDecoration(hintText: hint,
        hintStyle: const TextStyle(color: Color(0xFF3A5068)),
        prefixIcon: const Icon(Icons.lock_outline_rounded,
            color: Color(0xFF3A5068), size: 20),
        suffixIcon: GestureDetector(onTap: toggle,
          child: Icon(obscure ? Icons.visibility_outlined
              : Icons.visibility_off_outlined,
              color: const Color(0xFF3A5068), size: 20)),
        filled: true, fillColor: const Color(0xFF152232),
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12),
            borderSide: const BorderSide(color: Color(0xFF1E3347))),
        enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12),
            borderSide: const BorderSide(color: Color(0xFF1E3347))),
        focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12),
            borderSide: const BorderSide(color: Color(0xFF1DB954), width: 1.5))));
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