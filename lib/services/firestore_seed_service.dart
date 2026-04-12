import 'package:cloud_firestore/cloud_firestore.dart';

/// Seeds the TypeMaster collection once if it doesn't already exist.
/// Call this from main() after Firebase.initializeApp().
class FirestoreSeedService {
  static final _db = FirebaseFirestore.instance;

  static const List<Map<String, dynamic>> _typeMasterData = [
    // ── Client Types ──────────────────────────────────────────────────────────
    {'TypeID': 1, 'TypeCode': 'ClientType', 'TypeName': 'Academy',     'TypeDescription': 'General education or training institutions'},
    {'TypeID': 2, 'TypeCode': 'ClientType', 'TypeName': 'Gym',         'TypeDescription': 'Fitness centers'},
    {'TypeID': 3, 'TypeCode': 'ClientType', 'TypeName': 'Tuition',     'TypeDescription': 'Subject-specific coaching centers'},
    {'TypeID': 4, 'TypeCode': 'ClientType', 'TypeName': 'Academics',   'TypeDescription': 'Formal study programs (language, math, science)'},
    {'TypeID': 5, 'TypeCode': 'ClientType', 'TypeName': 'Arts',        'TypeDescription': 'Creative fields like drawing, painting, performing arts'},
    {'TypeID': 6, 'TypeCode': 'ClientType', 'TypeName': 'Fitness',     'TypeDescription': 'Physical training beyond gyms (yoga, aerobics)'},
    {'TypeID': 7, 'TypeCode': 'ClientType', 'TypeName': 'Sports Club', 'TypeDescription': 'Badminton, Cricket, Swimming'},
    {'TypeID': 8, 'TypeCode': 'ClientType', 'TypeName': 'Other',       'TypeDescription': 'Other Institutions'},
    // ── Roles ─────────────────────────────────────────────────────────────────
    {'TypeID': 9,  'TypeCode': 'Role', 'TypeName': 'Teacher', 'TypeDescription': 'Delivers courses, guides students, provides feedback.'},
    {'TypeID': 10, 'TypeCode': 'Role', 'TypeName': 'Coach',   'TypeDescription': 'Trains students in sports, fitness, or performance disciplines.'},
    {'TypeID': 11, 'TypeCode': 'Role', 'TypeName': 'Client',  'TypeDescription': 'Institution owner or administrator; manages branches, staff, and operations.'},
    {'TypeID': 12, 'TypeCode': 'Role', 'TypeName': 'Staff',   'TypeDescription': 'General support personnel: assistants, coordinators, admin staff.'},
    // ── Payroll Types ─────────────────────────────────────────────────────────
    {'TypeID': 13, 'TypeCode': 'PayrollType', 'TypeName': 'Monthly Fixed Salary', 'TypeDescription': 'Fixed monthly salary paid to staff.'},
    {'TypeID': 14, 'TypeCode': 'PayrollType', 'TypeName': 'Partnership',          'TypeDescription': 'Revenue sharing arrangement with partner staff.'},
  ];

  /// Seeds TypeMaster if not already seeded.
  /// Uses a sentinel doc '_seeded' to avoid re-seeding on every launch.
  static Future<void> seedTypeMaster() async {
    final sentinelRef = _db.collection('TypeMaster').doc('_seeded');
    final sentinel = await sentinelRef.get();
    if (sentinel.exists) return;

    final batch = _db.batch();
    for (final row in _typeMasterData) {
      final docRef = _db.collection('TypeMaster').doc(row['TypeID'].toString());
      batch.set(docRef, {...row, 'CreatedAt': FieldValue.serverTimestamp()});
    }
    batch.set(sentinelRef, {'seededAt': FieldValue.serverTimestamp()});
    await batch.commit();
  }

  /// Returns the TypeID for a TypeCode + TypeName pair.
  /// e.g. getTypeID('Role', 'Client') → 11
  static Future<int?> getTypeID(String typeCode, String typeName) async {
    final snap = await _db
        .collection('TypeMaster')
        .where('TypeCode', isEqualTo: typeCode)
        .where('TypeName', isEqualTo: typeName)
        .limit(1)
        .get();
    if (snap.docs.isEmpty) return null;
    return snap.docs.first.data()['TypeID'] as int?;
  }

  /// Returns all TypeMaster rows for a given TypeCode, ordered by TypeID.
  static Future<List<Map<String, dynamic>>> getTypesByCode(String typeCode) async {
    final snap = await _db
        .collection('TypeMaster')
        .where('TypeCode', isEqualTo: typeCode)
        .orderBy('TypeID')
        .get();
    return snap.docs.map((d) => d.data()).toList();
  }
}