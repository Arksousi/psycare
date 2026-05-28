import 'package:cloud_firestore/cloud_firestore.dart';
import '../../data/models/volunteer_connection_model.dart';
import '../../data/models/volunteer_model.dart';

class VolunteerService {
  final FirebaseFirestore _db;

  VolunteerService({FirebaseFirestore? db})
      : _db = db ?? FirebaseFirestore.instance;

  // ── Volunteer profile ────────────────────────────────────────────────────

  Stream<VolunteerModel?> watchVolunteer(String volunteerId) {
    return _db
        .collection('volunteers')
        .doc(volunteerId)
        .snapshots()
        .map((s) => s.exists
            ? VolunteerModel.fromMap(s.id, s.data()!)
            : null);
  }

  Future<void> updateVolunteerProfile(
      String volunteerId, Map<String, dynamic> data) async {
    await _db
        .collection('volunteers')
        .doc(volunteerId)
        .set(data, SetOptions(merge: true));
  }

  Future<void> updateAvailability(
      String volunteerId, bool isAvailable) async {
    await _db
        .collection('volunteers')
        .doc(volunteerId)
        .update({'isAvailable': isAvailable});
  }

  // ── Browse ───────────────────────────────────────────────────────────────

  Stream<List<VolunteerModel>> getAvailableVolunteers() {
    return _db
        .collection('volunteers')
        .snapshots()
        .map((s) {
          final list = s.docs
              .map((d) => VolunteerModel.fromMap(d.id, d.data()))
              .toList()
            ..sort((a, b) => b.rating.compareTo(a.rating));
          return list;
        });
  }

  // ── Connections ──────────────────────────────────────────────────────────

  Stream<List<VolunteerConnectionModel>> getPatientConnections(
      String patientId) {
    return _db
        .collection('volunteerConnections')
        .where('patientId', isEqualTo: patientId)
        .where('status', isEqualTo: 'active')
        .snapshots()
        .map((s) => s.docs
            .map((d) =>
                VolunteerConnectionModel.fromMap(d.id, d.data()))
            .toList());
  }

  /// All connections for a patient regardless of status (active, pending, declined).
  Stream<List<VolunteerConnectionModel>> getAllPatientConnections(
      String patientId) {
    return _db
        .collection('volunteerConnections')
        .where('patientId', isEqualTo: patientId)
        .snapshots()
        .map((s) => s.docs
            .map((d) =>
                VolunteerConnectionModel.fromMap(d.id, d.data()))
            .toList());
  }

  Stream<List<VolunteerConnectionModel>> getVolunteerConnections(
      String volunteerId) {
    return _db
        .collection('volunteerConnections')
        .where('volunteerId', isEqualTo: volunteerId)
        .snapshots()
        .map((s) => s.docs
            .map((d) =>
                VolunteerConnectionModel.fromMap(d.id, d.data()))
            .toList());
  }

  Future<VolunteerConnectionModel?> getExistingConnection(
      String patientId, String volunteerId) async {
    final snap = await _db
        .collection('volunteerConnections')
        .where('patientId', isEqualTo: patientId)
        .where('volunteerId', isEqualTo: volunteerId)
        .where('status', isEqualTo: 'active')
        .limit(1)
        .get();
    if (snap.docs.isEmpty) return null;
    return VolunteerConnectionModel.fromMap(
        snap.docs.first.id, snap.docs.first.data());
  }

  /// Returns any non-ended connection (active, pending, declined) between pair.
  Future<VolunteerConnectionModel?> getExistingConnectionAny(
      String patientId, String volunteerId) async {
    final snap = await _db
        .collection('volunteerConnections')
        .where('patientId', isEqualTo: patientId)
        .where('volunteerId', isEqualTo: volunteerId)
        .limit(1)
        .get();
    if (snap.docs.isEmpty) return null;
    return VolunteerConnectionModel.fromMap(
        snap.docs.first.id, snap.docs.first.data());
  }

  /// Sends a pending connection request without creating a chat yet.
  Future<void> sendConnectionRequest({
    required String patientId,
    required String volunteerId,
    required String therapistId,
    required String patientName,
    required String volunteerName,
    required String initiatedBy, // 'volunteer' | 'patient'
  }) async {
    final existing =
        await getExistingConnectionAny(patientId, volunteerId);
    if (existing != null && !existing.isDeclined) return;

    final connRef = _db.collection('volunteerConnections').doc();
    await connRef.set({
      'connectionId': connRef.id,
      'patientId': patientId,
      'volunteerId': volunteerId,
      'patientName': patientName,
      'volunteerName': volunteerName,
      'therapistId': therapistId,
      'status': 'pending',
      'initiatedBy': initiatedBy,
      'connectedAt': FieldValue.serverTimestamp(),
      'chatId': '',
    });
  }

  /// Accepts a pending request: creates chat session, marks connection active.
  Future<String> acceptConnectionRequest(String connectionId) async {
    final connDoc = await _db
        .collection('volunteerConnections')
        .doc(connectionId)
        .get();
    final data = connDoc.data()!;
    final patientId = data['patientId'] as String;
    final volunteerId = data['volunteerId'] as String;

    final sessionRef = _db.collection('chat_sessions').doc();
    await sessionRef.set({
      'patientId': patientId,
      'therapistId': volunteerId,
      'type': 'volunteer',
      'status': 'active',
      'createdAt': FieldValue.serverTimestamp(),
      'patientSummary': '',
      'clinicalReport': '',
      'deletedByPatient': false,
      'deletedByTherapist': false,
    });

    await _db
        .collection('volunteerConnections')
        .doc(connectionId)
        .update({'status': 'active', 'chatId': sessionRef.id});

    await _db.collection('volunteers').doc(volunteerId).update({
      'connectedPatients': FieldValue.arrayUnion([patientId]),
    });

    return sessionRef.id;
  }

  /// Declines a pending request.
  Future<void> declineConnectionRequest(String connectionId) async {
    await _db
        .collection('volunteerConnections')
        .doc(connectionId)
        .update({'status': 'declined'});
  }

  /// Streams pending requests sent TO a patient (volunteer-initiated).
  Stream<List<VolunteerConnectionModel>> getPendingRequestsForPatient(
      String patientId) {
    return _db
        .collection('volunteerConnections')
        .where('patientId', isEqualTo: patientId)
        .where('status', isEqualTo: 'pending')
        .where('initiatedBy', isEqualTo: 'volunteer')
        .snapshots()
        .map((s) => s.docs
            .map((d) => VolunteerConnectionModel.fromMap(d.id, d.data()))
            .toList());
  }

  /// Streams pending requests sent TO a volunteer (patient-initiated).
  Stream<List<VolunteerConnectionModel>> getPendingRequestsForVolunteer(
      String volunteerId) {
    return _db
        .collection('volunteerConnections')
        .where('volunteerId', isEqualTo: volunteerId)
        .where('status', isEqualTo: 'pending')
        .where('initiatedBy', isEqualTo: 'patient')
        .snapshots()
        .map((s) => s.docs
            .map((d) => VolunteerConnectionModel.fromMap(d.id, d.data()))
            .toList());
  }

  /// Streams all patients for volunteer browsing (client-side role filter).
  Stream<List<Map<String, dynamic>>> getAllPatients() {
    return _db
        .collection('users')
        .snapshots()
        .map((s) => s.docs
            .where((d) => d.data()['role'] == 'patient')
            .map((d) => {'uid': d.id, ...d.data()})
            .toList());
  }

  /// Creates connection + chat_session doc. Returns [VolunteerConnectionModel].
  Future<VolunteerConnectionModel> connectWithVolunteer({
    required String patientId,
    required String volunteerId,
    required String therapistId,
    required String patientName,
    required String volunteerName,
  }) async {
    // Create chat_session document (type: 'volunteer', therapistId = volunteerId for reuse)
    final sessionRef = _db.collection('chat_sessions').doc();
    await sessionRef.set({
      'patientId': patientId,
      'therapistId': volunteerId,
      'type': 'volunteer',
      'status': 'active',
      'createdAt': FieldValue.serverTimestamp(),
      'patientSummary': '',
      'clinicalReport': '',
      'deletedByPatient': false,
      'deletedByTherapist': false,
    });

    // Create volunteerConnections document
    final connRef = _db.collection('volunteerConnections').doc();
    final conn = VolunteerConnectionModel(
      connectionId: connRef.id,
      patientId: patientId,
      volunteerId: volunteerId,
      patientName: patientName,
      volunteerName: volunteerName,
      therapistId: therapistId,
      status: 'active',
      connectedAt: DateTime.now(),
      chatId: sessionRef.id,
    );
    await connRef.set(conn.toMap());

    // Add patientId to volunteer's connectedPatients
    await _db.collection('volunteers').doc(volunteerId).update({
      'connectedPatients': FieldValue.arrayUnion([patientId]),
    });

    return conn;
  }

  Future<void> endConnection({
    required String connectionId,
    required String volunteerId,
    required String patientId,
    required String chatId,
  }) async {
    await _db
        .collection('volunteerConnections')
        .doc(connectionId)
        .update({'status': 'ended'});
    await _db.collection('volunteers').doc(volunteerId).update({
      'connectedPatients': FieldValue.arrayRemove([patientId]),
    });
    // Mark chat session ended
    await _db
        .collection('chat_sessions')
        .doc(chatId)
        .update({'status': 'ended'});
  }

  // ── Rating ───────────────────────────────────────────────────────────────

  Future<bool> hasRated(String patientId, String volunteerId) async {
    final snap = await _db
        .collection('volunteerRatings')
        .where('patientId', isEqualTo: patientId)
        .where('volunteerId', isEqualTo: volunteerId)
        .limit(1)
        .get();
    return snap.docs.isNotEmpty;
  }

  Future<void> submitRating({
    required String patientId,
    required String volunteerId,
    required int rating,
  }) async {
    // Write rating doc
    final ratingRef = _db.collection('volunteerRatings').doc();
    await ratingRef.set({
      'ratingId': ratingRef.id,
      'patientId': patientId,
      'volunteerId': volunteerId,
      'rating': rating,
      'createdAt': FieldValue.serverTimestamp(),
    });

    // Recalculate average in a transaction
    await _db.runTransaction((tx) async {
      final volRef = _db.collection('volunteers').doc(volunteerId);
      final snap = await tx.get(volRef);
      if (!snap.exists) return;
      final data = snap.data()!;
      final currentCount = (data['ratingCount'] as num?)?.toInt() ?? 0;
      final currentRating = (data['rating'] as num?)?.toDouble() ?? 0.0;
      final newCount = currentCount + 1;
      final newRating =
          ((currentRating * currentCount) + rating) / newCount;
      tx.update(volRef, {
        'rating': double.parse(newRating.toStringAsFixed(1)),
        'ratingCount': newCount,
      });
    });
  }

  // ── Hours tracking ───────────────────────────────────────────────────────

  /// Call after every 10 messages to increment volunteerHours by 1.
  Future<void> incrementVolunteerHours(String volunteerId) async {
    await _db.collection('volunteers').doc(volunteerId).update({
      'volunteerHours': FieldValue.increment(1),
    });
  }

  // ── Red flag alerts ──────────────────────────────────────────────────────

  Future<void> writeRedFlagAlert({
    required String sessionId,
    required String volunteerId,
    required String volunteerName,
    required String therapistId,
    required String patientId,
    required String flaggedMessage,
    required List<String> recentMessages,
  }) async {
    final ref = _db.collection('redFlagAlerts').doc();
    await ref.set({
      'alertId': ref.id,
      'sessionId': sessionId,
      'volunteerId': volunteerId,
      'volunteerName': volunteerName,
      'therapistId': therapistId,
      'patientId': patientId,
      'flaggedMessage': flaggedMessage,
      'recentMessages': recentMessages,
      'source': 'volunteer',
      'isRead': false,
      'createdAt': FieldValue.serverTimestamp(),
    });
  }

  Stream<List<Map<String, dynamic>>> getRedFlagAlertsForTherapist(
      String therapistId) {
    return _db
        .collection('redFlagAlerts')
        .where('therapistId', isEqualTo: therapistId)
        .where('source', isEqualTo: 'volunteer')
        .orderBy('createdAt', descending: true)
        .snapshots()
        .map((s) =>
            s.docs.map((d) => {'id': d.id, ...d.data()}).toList());
  }

  Stream<List<Map<String, dynamic>>> getPatientRedFlagAlerts(
      String patientId) {
    return _db
        .collection('redFlagAlerts')
        .where('patientId', isEqualTo: patientId)
        .where('source', isEqualTo: 'volunteer')
        .snapshots()
        .map((s) =>
            s.docs.map((d) => {'id': d.id, ...d.data()}).toList());
  }

  // ── Meetup suggestions ───────────────────────────────────────────────────

  Future<String> createMeetupSuggestion({
    required String connectionId,
    required String volunteerId,
    required String patientId,
    required String place,
    required String note,
  }) async {
    final ref = _db.collection('meetupSuggestions').doc();
    await ref.set({
      'suggestionId': ref.id,
      'connectionId': connectionId,
      'volunteerId': volunteerId,
      'patientId': patientId,
      'place': place,
      'note': note,
      'status': 'pending',
      'createdAt': FieldValue.serverTimestamp(),
    });
    return ref.id;
  }

  Future<void> updateMeetupStatus(
      String suggestionId, String status) async {
    await _db
        .collection('meetupSuggestions')
        .doc(suggestionId)
        .update({'status': status});
  }

  Stream<Map<String, dynamic>?> watchMeetupSuggestion(
      String suggestionId) {
    return _db
        .collection('meetupSuggestions')
        .doc(suggestionId)
        .snapshots()
        .map((s) =>
            s.exists ? {'id': s.id, ...s.data()!} : null);
  }
}
