import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../services/firestore_seed_service.dart';
import '../services/subtype_seed_service.dart';
// ── Institution type options (from TypeMaster TypeCode = 'ClientType') ────────
const List<String> kInstitutionTypes = [
  'Academy',
  'Gym',
  'Tuition',
  'Academics',
  'Arts',
  'Fitness',
  'Sports Club',
  'Other',
];

class RegisterInstitutionScreen extends StatefulWidget {
  const RegisterInstitutionScreen({super.key});

  @override
  State<RegisterInstitutionScreen> createState() =>
      _RegisterInstitutionScreenState();
}

class _RegisterInstitutionScreenState extends State<RegisterInstitutionScreen>
    with TickerProviderStateMixin {
  // ── Step tracking ──────────────────────────────────────────────────────────
  int _currentStep = 0;
  final int _totalSteps = 3;

  // ── Controllers: Step 1 – Institution Details ──────────────────────────────
  final _institutionNameController = TextEditingController();
  final _contactEmailController = TextEditingController();
  final _contactPhoneController = TextEditingController();
  String? _selectedType;
  bool _hasBranches = false;

  // ── Controllers: Step 2 – Branch / Location ────────────────────────────────
  final _branchAddressController = TextEditingController();
  final _branchContactController = TextEditingController();
  final _businessTimingsController = TextEditingController();

  // ── Controllers: Step 3 – Admin Account ───────────────────────────────────
  final _adminNameController = TextEditingController();
  final _adminEmailController = TextEditingController();
  final _adminPasswordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();
  bool _obscurePassword = true;
  bool _obscureConfirm = true;

  bool _isLoading = false;

  // ── Animations ─────────────────────────────────────────────────────────────
  late AnimationController _fadeController;
  late AnimationController _slideController;
  late Animation<double> _fadeAnim;
  late Animation<Offset> _slideAnim;

  @override
  void initState() {
    super.initState();
    _fadeController = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 900));
    _slideController = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 800));
    _fadeAnim =
        CurvedAnimation(parent: _fadeController, curve: Curves.easeOut);
    _slideAnim = Tween<Offset>(begin: const Offset(0, 0.08), end: Offset.zero)
        .animate(
            CurvedAnimation(parent: _slideController, curve: Curves.easeOut));
    _fadeController.forward();
    _slideController.forward();
  }

  @override
  void dispose() {
    _fadeController.dispose();
    _slideController.dispose();
    _institutionNameController.dispose();
    _contactEmailController.dispose();
    _contactPhoneController.dispose();
    _branchAddressController.dispose();
    _branchContactController.dispose();
    _businessTimingsController.dispose();
    _adminNameController.dispose();
    _adminEmailController.dispose();
    _adminPasswordController.dispose();
    _confirmPasswordController.dispose();
    super.dispose();
  }

  // ── Validation ─────────────────────────────────────────────────────────────
  bool _validateStep1() {
    if (_institutionNameController.text.trim().isEmpty) {
      _showSnack('Institution name is required.');
      return false;
    }
    if (_contactEmailController.text.trim().isEmpty ||
        !_contactEmailController.text.contains('@')) {
      _showSnack('Enter a valid contact email.');
      return false;
    }
    if (_contactPhoneController.text.trim().isEmpty) {
      _showSnack('Contact phone number is required.');
      return false;
    }
    if (_selectedType == null) {
      _showSnack('Please select an institution type.');
      return false;
    }
    return true;
  }

  bool _validateStep2() {
    if (_branchAddressController.text.trim().isEmpty) {
      _showSnack('Branch address is required.');
      return false;
    }
    if (_branchContactController.text.trim().isEmpty) {
      _showSnack('Branch contact number is required.');
      return false;
    }
    if (_businessTimingsController.text.trim().isEmpty) {
      _showSnack('Business timings are required.');
      return false;
    }
    return true;
  }

  bool _validateStep3() {
    if (_adminNameController.text.trim().isEmpty) {
      _showSnack('Admin name is required.');
      return false;
    }
    if (_adminEmailController.text.trim().isEmpty ||
        !_adminEmailController.text.contains('@')) {
      _showSnack('Enter a valid admin email.');
      return false;
    }
    if (_adminPasswordController.text.length < 8) {
      _showSnack('Password must be at least 8 characters.');
      return false;
    }
    if (_adminPasswordController.text != _confirmPasswordController.text) {
      _showSnack('Passwords do not match.');
      return false;
    }
    return true;
  }

  // ── Navigation between steps ───────────────────────────────────────────────
  void _nextStep() {
    bool valid = false;
    if (_currentStep == 0) valid = _validateStep1();
    if (_currentStep == 1) valid = _validateStep2();
    if (!valid) return;
    setState(() => _currentStep++);
    _animateStep();
  }

  void _prevStep() {
    if (_currentStep > 0) {
      setState(() => _currentStep--);
      _animateStep();
    }
  }

  void _animateStep() {
    _fadeController.reset();
    _slideController.reset();
    _fadeController.forward();
    _slideController.forward();
  }

  // ── Firebase submission ────────────────────────────────────────────────────
  // ─────────────────────────────────────────────────────────────────────────────
  // INSTRUCTIONS:
  // 1. Add this import at the TOP of register_institution_screen.dart (line 4):
  //      import '../services/firestore_seed_service.dart';
  //      import '../services/subtype_seed_service.dart';
  //
  // 2. REPLACE the entire _submit() method with the one below.
  //    Find:  // ── Firebase submission ──
  //    Until: void _showSnack(
  // ─────────────────────────────────────────────────────────────────────────────

  // ── Firebase submission ────────────────────────────────────────────────────
  Future<void> _submit() async {
    if (!_validateStep3()) return;
    setState(() => _isLoading = true);

    try {
      final db = FirebaseFirestore.instance;

      // ── Step 1: Look up TypeMaster for Role='Client' → RoleTypeID ──────────
      final clientRoleTypeID =
          await FirestoreSeedService.getTypeID('Role', 'Client');
      if (clientRoleTypeID == null) {
        _showSnack('System error: TypeMaster not seeded. Please restart app.');
        setState(() => _isLoading = false);
        return;
      }

      // ── Step 2: Look up TypeMaster for selected institution type ────────────
      final clientTypeID =
          await FirestoreSeedService.getTypeID('ClientType', _selectedType!);

      // ── Step 3: Create Firebase Auth user ───────────────────────────────────
      final credential =
          await FirebaseAuth.instance.createUserWithEmailAndPassword(
        email: _adminEmailController.text.trim(),
        password: _adminPasswordController.text.trim(),
      );
      final uid = credential.user!.uid;

      // ── Step 4: Generate document references ────────────────────────────────
      final clientRef = db.collection('ClientMaster').doc();
      final clientId  = clientRef.id;
      final branchRef = db.collection('Branch').doc();
      final branchId  = branchRef.id;

      // ── Step 5: Atomic batch — ClientMaster + Branch + ClientAuthorizedUsers ─
      final batch = db.batch();

      // ClientMaster
      batch.set(clientRef, {
        'ClientID':        clientId,
        'ClientName':      _institutionNameController.text.trim(),
        'ContactInfo': {
          'email': _contactEmailController.text.trim(),
          'phone': _contactPhoneController.text.trim(),
        },
        'HasBranches':     _hasBranches,
        'InstitutionType': _selectedType,
        'ClientTypeID':    clientTypeID,
        'CreatedAt':       FieldValue.serverTimestamp(),
      });

      // Branch (primary)
      batch.set(branchRef, {
        'BranchID':                  branchId,
        'ClientID':                  clientId,
        'BranchAddress':             _branchAddressController.text.trim(),
        'ContactNo':                 _branchContactController.text.trim(),
        'BusinessTimings':           _businessTimingsController.text.trim(),
        'IsPrimary':                 true,
        'IsActive':                  true,
        'BranchRevenueSharePercent': 0.0,
        'CreatedAt':                 FieldValue.serverTimestamp(),
      });

      // ClientAuthorizedUsers
      batch.set(db.collection('ClientAuthorizedUsers').doc(uid), {
        'AuthUserID':  uid,
        'ClientID':    clientId,
        'BranchID':    branchId,
        'FirebaseUID': uid,
        'AdminName':   _adminNameController.text.trim(),
        'Email':       _adminEmailController.text.trim(),
        'UserType':    'Client',
        'RoleTypeID':  clientRoleTypeID,
        'LinkedID':    clientId,
        'IsActive':    true,
        'CreatedAt':   FieldValue.serverTimestamp(),
      });

      await batch.commit();

      // ── Step 6: Seed default SubTypes for this client ───────────────────────
      // Done AFTER main batch so a SubType seed failure doesn't block registration.
      // SubTypes can be re-seeded or added manually from the More → Sub Types screen.
      _showSnack('Setting up your account...', success: true);

      try {
        await SubTypeSeedService.seedDefaults(clientId);
      } catch (e) {
        // Non-fatal — client can configure SubTypes manually later
        debugPrint('SubType seed failed (non-fatal): $e');
      }

      _showSnack(
        'Welcome to ActivityHub, ${_adminNameController.text.trim().split(' ').first}! '
        'Your institution is ready.',
        success: true,
      );

      await Future.delayed(const Duration(milliseconds: 1500));
      if (mounted) Navigator.of(context).pop();

    } on FirebaseAuthException catch (e) {
      switch (e.code) {
        case 'email-already-in-use':
          _showSnack('This email is already registered. Please sign in.');
          break;
        case 'weak-password':
          _showSnack('Password is too weak. Use at least 8 characters.');
          break;
        case 'invalid-email':
          _showSnack('Invalid email address format.');
          break;
        default:
          _showSnack(e.message ?? 'Registration failed. Please try again.');
      }
    } on FirebaseException catch (e) {
      _showSnack(e.message ?? 'Database error. Please try again.');
    } catch (e) {
      _showSnack('An unexpected error occurred.');
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }



  void _showSnack(String msg, {bool success = false}) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(msg,
            style: const TextStyle(
                fontFamily: 'Georgia', color: Colors.white, fontSize: 14)),
        backgroundColor:
            success ? const Color(0xFF2ECC71) : const Color(0xFFE74C3C),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        margin: const EdgeInsets.all(16),
      ),
    );
  }

  // ── Build ──────────────────────────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0D1B2A),
      body: Stack(
        children: [
          // Background decorative circles
          Positioned(
            top: -80,
            right: -60,
            child: Container(
              width: 280,
              height: 280,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: const Color(0xFF1A6B4A).withOpacity(0.18),
              ),
            ),
          ),
          Positioned(
            bottom: -100,
            left: -80,
            child: Container(
              width: 320,
              height: 320,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: const Color(0xFF1A4B6B).withOpacity(0.22),
              ),
            ),
          ),
          Positioned(
            top: 200,
            left: -40,
            child: Container(
              width: 140,
              height: 140,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: const Color(0xFFE8A020).withOpacity(0.08),
              ),
            ),
          ),

          // Main content
          SafeArea(
            child: Column(
              children: [
                // Top bar with back button
                Padding(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  child: Row(
                    children: [
                      GestureDetector(
                        onTap: () {
                          if (_currentStep > 0) {
                            _prevStep();
                          } else {
                            Navigator.of(context).pop();
                          }
                        },
                        child: Container(
                          width: 40,
                          height: 40,
                          decoration: BoxDecoration(
                            color: const Color(0xFF152232),
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(
                                color: const Color(0xFF1E3347), width: 1),
                          ),
                          child: const Icon(Icons.arrow_back_ios_new_rounded,
                              color: Color(0xFF8899AA), size: 18),
                        ),
                      ),
                      const SizedBox(width: 16),
                      const Text(
                        'New Institution',
                        style: TextStyle(
                          fontFamily: 'Georgia',
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                        ),
                      ),
                    ],
                  ),
                ),

                // Step progress indicator
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 28),
                  child: _buildStepIndicator(),
                ),

                const SizedBox(height: 20),

                // Scrollable form
                Expanded(
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.symmetric(horizontal: 28),
                    child: FadeTransition(
                      opacity: _fadeAnim,
                      child: SlideTransition(
                        position: _slideAnim,
                        child: _buildCurrentStep(),
                      ),
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

  // ── Step Progress Bar ──────────────────────────────────────────────────────
  Widget _buildStepIndicator() {
    final labels = ['Institution', 'Branch', 'Admin'];
    return Row(
      children: List.generate(_totalSteps, (i) {
        final isCompleted = i < _currentStep;
        final isActive = i == _currentStep;
        return Expanded(
          child: Row(
            children: [
              Expanded(
                child: Column(
                  children: [
                    Row(
                      children: [
                        if (i > 0)
                          Expanded(
                            child: Container(
                              height: 2,
                              color: isCompleted
                                  ? const Color(0xFF1DB954)
                                  : const Color(0xFF1E3347),
                            ),
                          ),
                        Container(
                          width: 28,
                          height: 28,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: isCompleted
                                ? const Color(0xFF1DB954)
                                : isActive
                                    ? const Color(0xFF1DB954).withOpacity(0.2)
                                    : const Color(0xFF152232),
                            border: Border.all(
                              color: isActive || isCompleted
                                  ? const Color(0xFF1DB954)
                                  : const Color(0xFF1E3347),
                              width: 1.5,
                            ),
                          ),
                          child: Center(
                            child: isCompleted
                                ? const Icon(Icons.check_rounded,
                                    color: Colors.white, size: 14)
                                : Text(
                                    '${i + 1}',
                                    style: TextStyle(
                                      fontSize: 11,
                                      fontWeight: FontWeight.bold,
                                      color: isActive
                                          ? const Color(0xFF1DB954)
                                          : const Color(0xFF556677),
                                    ),
                                  ),
                          ),
                        ),
                        if (i < _totalSteps - 1)
                          Expanded(
                            child: Container(
                              height: 2,
                              color: isCompleted
                                  ? const Color(0xFF1DB954)
                                  : const Color(0xFF1E3347),
                            ),
                          ),
                      ],
                    ),
                    const SizedBox(height: 6),
                    Text(
                      labels[i],
                      style: TextStyle(
                        fontSize: 10,
                        color: isActive || isCompleted
                            ? const Color(0xFF1DB954)
                            : const Color(0xFF556677),
                        fontWeight:
                            isActive ? FontWeight.w600 : FontWeight.normal,
                        letterSpacing: 0.5,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        );
      }),
    );
  }

  // ── Route to correct step ──────────────────────────────────────────────────
  Widget _buildCurrentStep() {
    switch (_currentStep) {
      case 0:
        return _buildStep1();
      case 1:
        return _buildStep2();
      case 2:
        return _buildStep3();
      default:
        return const SizedBox.shrink();
    }
  }

  // ── Step 1: Institution Details ────────────────────────────────────────────
  Widget _buildStep1() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(14),
                gradient: const LinearGradient(
                  colors: [Color(0xFF1DB954), Color(0xFF17A847)],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
              ),
              child:
                  const Icon(Icons.hub_rounded, color: Colors.white, size: 24),
            ),
            const SizedBox(width: 14),
            const Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'ActivityHub',
                  style: TextStyle(
                    fontFamily: 'Georgia',
                    fontSize: 22,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                    letterSpacing: -0.3,
                  ),
                ),
                Text(
                  'Institution Registration',
                  style: TextStyle(
                    fontSize: 12,
                    color: Color(0xFF8899AA),
                    letterSpacing: 0.2,
                  ),
                ),
              ],
            ),
          ],
        ),

        const SizedBox(height: 28),

        Container(
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            color: const Color(0xFF152232),
            borderRadius: BorderRadius.circular(24),
            border: Border.all(color: const Color(0xFF1E3347), width: 1),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Institution Details',
                style: TextStyle(
                  fontFamily: 'Georgia',
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                ),
              ),
              const SizedBox(height: 4),
              const Text(
                'Tell us about your institution',
                style: TextStyle(fontSize: 12, color: Color(0xFF556677)),
              ),
              const SizedBox(height: 24),

              _buildLabel('Institution Name'),
              const SizedBox(height: 8),
              _buildTextField(
                controller: _institutionNameController,
                hint: 'e.g. SarathyBee Academy',
                icon: Icons.business_rounded,
              ),

              const SizedBox(height: 18),

              _buildLabel('Institution Type'),
              const SizedBox(height: 8),
              _buildDropdown(),

              const SizedBox(height: 18),

              _buildLabel('Contact Email'),
              const SizedBox(height: 8),
              _buildTextField(
                controller: _contactEmailController,
                hint: 'contact@institution.com',
                icon: Icons.email_outlined,
                keyboardType: TextInputType.emailAddress,
              ),

              const SizedBox(height: 18),

              _buildLabel('Contact Phone'),
              const SizedBox(height: 8),
              _buildTextField(
                controller: _contactPhoneController,
                hint: '+91 98765 43210',
                icon: Icons.phone_outlined,
                keyboardType: TextInputType.phone,
              ),

              const SizedBox(height: 18),

              // Multiple branches toggle
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                decoration: BoxDecoration(
                  color: const Color(0xFF0D1B2A),
                  borderRadius: BorderRadius.circular(12),
                  border:
                      Border.all(color: const Color(0xFF1E3347), width: 1),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.account_tree_outlined,
                        color: Color(0xFF3A5068), size: 20),
                    const SizedBox(width: 12),
                    const Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Multiple Branches',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 14,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                          Text(
                            'Does your institution have more than one location?',
                            style: TextStyle(
                                color: Color(0xFF556677), fontSize: 11),
                          ),
                        ],
                      ),
                    ),
                    Switch(
                      value: _hasBranches,
                      onChanged: (v) => setState(() => _hasBranches = v),
                      activeColor: const Color(0xFF1DB954),
                      inactiveTrackColor: const Color(0xFF1E3347),
                      inactiveThumbColor: const Color(0xFF556677),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 28),

              _buildPrimaryButton(
                label: 'Continue',
                onTap: _nextStep,
                trailingIcon: Icons.arrow_forward_rounded,
              ),
            ],
          ),
        ),

        const SizedBox(height: 24),
        _buildBackToLogin(),
        const SizedBox(height: 40),
      ],
    );
  }

  // ── Step 2: Branch / Location ──────────────────────────────────────────────
  Widget _buildStep2() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            color: const Color(0xFF152232),
            borderRadius: BorderRadius.circular(24),
            border: Border.all(color: const Color(0xFF1E3347), width: 1),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    width: 36,
                    height: 36,
                    decoration: BoxDecoration(
                      color: const Color(0xFF1DB954).withOpacity(0.12),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: const Icon(Icons.location_on_outlined,
                        color: Color(0xFF1DB954), size: 20),
                  ),
                  const SizedBox(width: 12),
                  const Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Primary Branch',
                        style: TextStyle(
                          fontFamily: 'Georgia',
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                        ),
                      ),
                      Text(
                        'Main location details',
                        style:
                            TextStyle(fontSize: 12, color: Color(0xFF556677)),
                      ),
                    ],
                  ),
                ],
              ),

              const SizedBox(height: 24),

              _buildLabel('Branch Address'),
              const SizedBox(height: 8),
              _buildTextField(
                controller: _branchAddressController,
                hint: '123, Main Street, City, State – 600001',
                icon: Icons.location_city_outlined,
                maxLines: 2,
              ),

              const SizedBox(height: 18),

              _buildLabel('Branch Contact Number'),
              const SizedBox(height: 8),
              _buildTextField(
                controller: _branchContactController,
                hint: '+91 98765 43210',
                icon: Icons.phone_outlined,
                keyboardType: TextInputType.phone,
              ),

              const SizedBox(height: 18),

              _buildLabel('Business Timings'),
              const SizedBox(height: 8),
              _buildTextField(
                controller: _businessTimingsController,
                hint: 'e.g. Mon–Sat: 9 AM – 7 PM',
                icon: Icons.access_time_rounded,
              ),

              const SizedBox(height: 10),

              // Quick-fill timing chips
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  'Mon–Fri: 9AM–6PM',
                  'Mon–Sat: 8AM–8PM',
                  'All days: 6AM–9PM',
                ].map((t) => _buildTimingChip(t)).toList(),
              ),

              const SizedBox(height: 28),

              Row(
                children: [
                  Expanded(
                    child: _buildSecondaryButton(
                      label: 'Back',
                      onTap: _prevStep,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    flex: 2,
                    child: _buildPrimaryButton(
                      label: 'Continue',
                      onTap: _nextStep,
                      trailingIcon: Icons.arrow_forward_rounded,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
        const SizedBox(height: 40),
      ],
    );
  }

  // ── Step 3: Admin Account ──────────────────────────────────────────────────
  Widget _buildStep3() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            color: const Color(0xFF152232),
            borderRadius: BorderRadius.circular(24),
            border: Border.all(color: const Color(0xFF1E3347), width: 1),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    width: 36,
                    height: 36,
                    decoration: BoxDecoration(
                      color: const Color(0xFF1DB954).withOpacity(0.12),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: const Icon(Icons.admin_panel_settings_outlined,
                        color: Color(0xFF1DB954), size: 20),
                  ),
                  const SizedBox(width: 12),
                  const Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Admin Account',
                        style: TextStyle(
                          fontFamily: 'Georgia',
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                        ),
                      ),
                      Text(
                        'Owner / primary administrator',
                        style:
                            TextStyle(fontSize: 12, color: Color(0xFF556677)),
                      ),
                    ],
                  ),
                ],
              ),

              const SizedBox(height: 24),

              _buildLabel('Full Name'),
              const SizedBox(height: 8),
              _buildTextField(
                controller: _adminNameController,
                hint: 'Admin full name',
                icon: Icons.person_outline_rounded,
              ),

              const SizedBox(height: 18),

              _buildLabel('Admin Email'),
              const SizedBox(height: 8),
              _buildTextField(
                controller: _adminEmailController,
                hint: 'admin@institution.com',
                icon: Icons.email_outlined,
                keyboardType: TextInputType.emailAddress,
              ),

              const SizedBox(height: 18),

              _buildLabel('Password'),
              const SizedBox(height: 8),
              _buildTextField(
                controller: _adminPasswordController,
                hint: '••••••••',
                icon: Icons.lock_outline_rounded,
                obscure: _obscurePassword,
                suffix: IconButton(
                  icon: Icon(
                    _obscurePassword
                        ? Icons.visibility_off_outlined
                        : Icons.visibility_outlined,
                    color: const Color(0xFF556677),
                    size: 20,
                  ),
                  onPressed: () =>
                      setState(() => _obscurePassword = !_obscurePassword),
                ),
              ),

              const SizedBox(height: 18),

              _buildLabel('Confirm Password'),
              const SizedBox(height: 8),
              _buildTextField(
                controller: _confirmPasswordController,
                hint: '••••••••',
                icon: Icons.lock_outline_rounded,
                obscure: _obscureConfirm,
                suffix: IconButton(
                  icon: Icon(
                    _obscureConfirm
                        ? Icons.visibility_off_outlined
                        : Icons.visibility_outlined,
                    color: const Color(0xFF556677),
                    size: 20,
                  ),
                  onPressed: () =>
                      setState(() => _obscureConfirm = !_obscureConfirm),
                ),
              ),

              const SizedBox(height: 8),

              const Row(
                children: [
                  Icon(Icons.info_outline_rounded,
                      color: Color(0xFF3A5068), size: 14),
                  SizedBox(width: 6),
                  Text(
                    'Minimum 8 characters.',
                    style: TextStyle(color: Color(0xFF3A5068), fontSize: 12),
                  ),
                ],
              ),

              const SizedBox(height: 28),

              // Terms notice
              Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: const Color(0xFF1DB954).withOpacity(0.06),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                      color: const Color(0xFF1DB954).withOpacity(0.2),
                      width: 1),
                ),
                child: const Row(
                  children: [
                    Icon(Icons.verified_outlined,
                        color: Color(0xFF1DB954), size: 18),
                    SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        'By registering, you agree to ActivityHub\'s Terms of Service and Privacy Policy.',
                        style: TextStyle(
                            color: Color(0xFF8899AA),
                            fontSize: 12,
                            height: 1.5),
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 24),

              Row(
                children: [
                  Expanded(
                    child: _buildSecondaryButton(
                      label: 'Back',
                      onTap: _prevStep,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    flex: 2,
                    child: SizedBox(
                      height: 52,
                      child: ElevatedButton(
                        onPressed: _isLoading ? null : _submit,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF1DB954),
                          foregroundColor: Colors.white,
                          disabledBackgroundColor:
                              const Color(0xFF1DB954).withOpacity(0.5),
                          elevation: 0,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(14),
                          ),
                        ),
                        child: _isLoading
                            ? const SizedBox(
                                width: 22,
                                height: 22,
                                child: CircularProgressIndicator(
                                  color: Colors.white,
                                  strokeWidth: 2.5,
                                ),
                              )
                            : const Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Icon(Icons.check_circle_outline_rounded,
                                      size: 18),
                                  SizedBox(width: 8),
                                  Text(
                                    'Complete Registration',
                                    style: TextStyle(
                                      fontSize: 15,
                                      fontWeight: FontWeight.w600,
                                      letterSpacing: 0.2,
                                    ),
                                  ),
                                ],
                              ),
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
        const SizedBox(height: 40),
      ],
    );
  }

  // ── Reusable Widgets ───────────────────────────────────────────────────────

  Widget _buildLabel(String text) {
    return Text(
      text,
      style: const TextStyle(
        fontSize: 13,
        fontWeight: FontWeight.w500,
        color: Color(0xFF8899AA),
        letterSpacing: 0.3,
      ),
    );
  }

  Widget _buildTextField({
    required TextEditingController controller,
    required String hint,
    required IconData icon,
    bool obscure = false,
    TextInputType keyboardType = TextInputType.text,
    Widget? suffix,
    int maxLines = 1,
  }) {
    return TextField(
      controller: controller,
      obscureText: obscure,
      keyboardType: keyboardType,
      maxLines: maxLines,
      style: const TextStyle(color: Colors.white, fontSize: 15),
      cursorColor: const Color(0xFF1DB954),
      decoration: InputDecoration(
        hintText: hint,
        hintStyle: const TextStyle(color: Color(0xFF3A5068), fontSize: 15),
        prefixIcon: Icon(icon, color: const Color(0xFF3A5068), size: 20),
        suffixIcon: suffix,
        filled: true,
        fillColor: const Color(0xFF0D1B2A),
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: Color(0xFF1E3347), width: 1),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: Color(0xFF1E3347), width: 1),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: Color(0xFF1DB954), width: 1.5),
        ),
      ),
    );
  }

  Widget _buildDropdown() {
    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFF0D1B2A),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
            color: _selectedType != null
                ? const Color(0xFF1DB954)
                : const Color(0xFF1E3347),
            width: _selectedType != null ? 1.5 : 1),
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<String>(
          value: _selectedType,
          hint: const Padding(
            padding: EdgeInsets.only(left: 16),
            child: Row(
              children: [
                Icon(Icons.category_outlined,
                    color: Color(0xFF3A5068), size: 20),
                SizedBox(width: 12),
                Text('Select institution type',
                    style:
                        TextStyle(color: Color(0xFF3A5068), fontSize: 15)),
              ],
            ),
          ),
          isExpanded: true,
          dropdownColor: const Color(0xFF152232),
          icon: const Padding(
            padding: EdgeInsets.only(right: 12),
            child: Icon(Icons.keyboard_arrow_down_rounded,
                color: Color(0xFF556677)),
          ),
          items: kInstitutionTypes
              .map(
                (type) => DropdownMenuItem(
                  value: type,
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    child: Row(
                      children: [
                        Icon(_iconForType(type),
                            color: const Color(0xFF1DB954), size: 18),
                        const SizedBox(width: 12),
                        Text(type,
                            style: const TextStyle(
                                color: Colors.white, fontSize: 15)),
                      ],
                    ),
                  ),
                ),
              )
              .toList(),
          onChanged: (v) => setState(() => _selectedType = v),
        ),
      ),
    );
  }

  IconData _iconForType(String type) {
    switch (type) {
      case 'Gym':
        return Icons.fitness_center_rounded;
      case 'Tuition':
        return Icons.menu_book_rounded;
      case 'Arts':
        return Icons.palette_outlined;
      case 'Fitness':
        return Icons.self_improvement_rounded;
      case 'Sports Club':
        return Icons.sports_soccer_rounded;
      case 'Academics':
        return Icons.school_outlined;
      default:
        return Icons.account_balance_outlined;
    }
  }

  Widget _buildTimingChip(String label) {
    return GestureDetector(
      onTap: () => _businessTimingsController.text = label,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: const Color(0xFF1DB954).withOpacity(0.08),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
              color: const Color(0xFF1DB954).withOpacity(0.25), width: 1),
        ),
        child: Text(
          label,
          style: const TextStyle(
              fontSize: 11,
              color: Color(0xFF1DB954),
              fontWeight: FontWeight.w500),
        ),
      ),
    );
  }

  Widget _buildPrimaryButton({
    required String label,
    required VoidCallback onTap,
    IconData? trailingIcon,
  }) {
    return SizedBox(
      width: double.infinity,
      height: 52,
      child: ElevatedButton(
        onPressed: onTap,
        style: ElevatedButton.styleFrom(
          backgroundColor: const Color(0xFF1DB954),
          foregroundColor: Colors.white,
          elevation: 0,
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              label,
              style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  letterSpacing: 0.3),
            ),
            if (trailingIcon != null) ...[
              const SizedBox(width: 8),
              Icon(trailingIcon, size: 18),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildSecondaryButton({
    required String label,
    required VoidCallback onTap,
  }) {
    return SizedBox(
      height: 52,
      child: OutlinedButton(
        onPressed: onTap,
        style: OutlinedButton.styleFrom(
          foregroundColor: const Color(0xFF8899AA),
          side: const BorderSide(color: Color(0xFF1E3347), width: 1),
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        ),
        child: Text(label,
            style:
                const TextStyle(fontSize: 15, fontWeight: FontWeight.w500)),
      ),
    );
  }

  Widget _buildBackToLogin() {
    return Center(
      child: GestureDetector(
        onTap: () => Navigator.of(context).pop(),
        child: RichText(
          text: const TextSpan(
            style: TextStyle(fontSize: 14, color: Color(0xFF556677)),
            children: [
              TextSpan(text: 'Already registered? '),
              TextSpan(
                text: 'Sign in here',
                style: TextStyle(
                  color: Color(0xFF1DB954),
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}