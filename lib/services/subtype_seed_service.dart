import 'package:cloud_firestore/cloud_firestore.dart';

/// Seeds default SubTypes for a newly registered client.
/// Called once during institution registration — never again.
class SubTypeSeedService {
  static final _db = FirebaseFirestore.instance;

  /// All default SubTypes seeded for every new client.
  /// 'Course' is intentionally empty — client fills their own activities.
  static List<Map<String, dynamic>> _defaults(String clientId) => [

    // ── Timings ───────────────────────────────────────────────────────────────
    _row(clientId, 'Timings', '6 AM to 7 AM',   '6 AM to 7 AM'),
    _row(clientId, 'Timings', '7 AM to 8 AM',   '7 AM to 8 AM'),
    _row(clientId, 'Timings', '8 AM to 9 AM',   '8 AM to 9 AM'),
    _row(clientId, 'Timings', '9 AM to 10 AM',  '9 AM to 10 AM'),
    _row(clientId, 'Timings', '10 AM to 11 AM', '10 AM to 11 AM'),
    _row(clientId, 'Timings', '11 AM to 12 PM', '11 AM to 12 PM'),
    _row(clientId, 'Timings', '4 PM to 5 PM',   '4 PM to 5 PM'),
    _row(clientId, 'Timings', '5 PM to 6 PM',   '5 PM to 6 PM'),
    _row(clientId, 'Timings', '6 PM to 7 PM',   '6 PM to 7 PM'),
    _row(clientId, 'Timings', '7 PM to 8 PM',   '7 PM to 8 PM'),

    // ── Course Duration ───────────────────────────────────────────────────────
    _row(clientId, 'CourseDuration', 'Annual',   '12 Months'),
    _row(clientId, 'CourseDuration', '6 Months', '6 Months'),
    _row(clientId, 'CourseDuration', '3 Months', '3 Months'),
    _row(clientId, 'CourseDuration', 'Monthly',  '1 Month'),

    // ── Payment Cycle ─────────────────────────────────────────────────────────
    _row(clientId, 'PaymentCycle', 'Annual',   '12 Months'),
    _row(clientId, 'PaymentCycle', '6 Months', '6 Months'),
    _row(clientId, 'PaymentCycle', '3 Months', '3 Months'),
    _row(clientId, 'PaymentCycle', 'Monthly',  '1 Month'),

    // ── Revenue Share Models ──────────────────────────────────────────────────
    _row(clientId, 'RevenueShare', '100% Institution', 'Full revenue to institution'),
    _row(clientId, 'RevenueShare', '90-10',            '90% Institution / 10% Staff'),
    _row(clientId, 'RevenueShare', '80-20',            '80% Institution / 20% Staff'),
    _row(clientId, 'RevenueShare', '70-30',            '70% Institution / 30% Staff'),
    _row(clientId, 'RevenueShare', '60-40',            '60% Institution / 40% Staff'),
    _row(clientId, 'RevenueShare', '50-50',            '50% Institution / 50% Staff'),

    // ── Course (intentionally empty — client adds their own activities) ────────
    // No defaults for 'Course' SubTypeCode
  ];

  static Map<String, dynamic> _row(
    String clientId,
    String subTypeCode,
    String subTypeName,
    String subTypeDescription,
  ) =>
      {
        'ClientID': clientId,
        'SubTypeCode': subTypeCode,
        'SubTypeName': subTypeName,
        'SubTypeDescription': subTypeDescription,
        'IsActive': true,
        'IsDefault': true,
        'CreatedAt': FieldValue.serverTimestamp(),
      };

  /// Seeds all default SubTypes for [clientId] in batches of 500.
  /// Firestore batch writes are limited to 500 operations per batch.
  static Future<void> seedDefaults(String clientId) async {
    final rows = _defaults(clientId);

    // Split into chunks of 400 to stay safely under Firestore's 500 limit
    const chunkSize = 400;
    for (int i = 0; i < rows.length; i += chunkSize) {
      final chunk = rows.sublist(
          i, i + chunkSize > rows.length ? rows.length : i + chunkSize);
      final batch = _db.batch();
      for (final row in chunk) {
        final docRef = _db.collection('SubType').doc();
        batch.set(docRef, row);
      }
      await batch.commit();
    }
  }

  /// Fetches all active SubTypes for a client, grouped by SubTypeCode.
  /// Returns a map like: { 'Timings': [...], 'CourseDuration': [...], ... }
  static Future<Map<String, List<Map<String, dynamic>>>> getGrouped(
      String clientId) async {
    final snap = await _db
        .collection('SubType')
        .where('ClientID', isEqualTo: clientId)
        .where('IsActive', isEqualTo: true)
        .orderBy('CreatedAt')
        .get();

    final Map<String, List<Map<String, dynamic>>> grouped = {};
    for (final doc in snap.docs) {
      final data = {...doc.data(), 'DocID': doc.id};
      final code = data['SubTypeCode'] as String? ?? 'Other';
      grouped.putIfAbsent(code, () => []).add(data);
    }
    return grouped;
  }

  /// Fetches SubTypes for a specific SubTypeCode.
  static Future<List<Map<String, dynamic>>> getByCode(
      String clientId, String subTypeCode) async {
    final snap = await _db
        .collection('SubType')
        .where('ClientID', isEqualTo: clientId)
        .where('SubTypeCode', isEqualTo: subTypeCode)
        .where('IsActive', isEqualTo: true)
        .orderBy('CreatedAt')
        .get();
    return snap.docs
        .map((d) => {...d.data(), 'DocID': d.id})
        .toList();
  }

  /// Adds a new SubType for a client.
  static Future<String> add({
    required String clientId,
    required String subTypeCode,
    required String subTypeName,
    required String subTypeDescription,
  }) async {
    final docRef = _db.collection('SubType').doc();
    await docRef.set({
      'ClientID': clientId,
      'SubTypeCode': subTypeCode,
      'SubTypeName': subTypeName,
      'SubTypeDescription': subTypeDescription,
      'IsActive': true,
      'IsDefault': false,
      'CreatedAt': FieldValue.serverTimestamp(),
    });
    return docRef.id;
  }

  /// Updates an existing SubType.
  static Future<void> update({
    required String docId,
    required String subTypeName,
    required String subTypeDescription,
  }) async {
    await _db.collection('SubType').doc(docId).update({
      'SubTypeName': subTypeName,
      'SubTypeDescription': subTypeDescription,
      'UpdatedAt': FieldValue.serverTimestamp(),
    });
  }

  /// Soft-deletes a SubType (marks IsActive = false).
  /// Never hard-deletes since existing courses may reference it.
  static Future<void> deactivate(String docId) async {
    await _db.collection('SubType').doc(docId).update({
      'IsActive': false,
      'DeactivatedAt': FieldValue.serverTimestamp(),
    });
  }

  /// Reactivates a previously deactivated SubType.
  static Future<void> reactivate(String docId) async {
    await _db.collection('SubType').doc(docId).update({
      'IsActive': true,
      'DeactivatedAt': FieldValue.delete(),
    });
  }
}