import 'package:cloud_firestore/cloud_firestore.dart';
import '../../data/models/therapist_connection_model.dart';

class TherapistConnectionService {
  final _db = FirebaseFirestore.instance;

  // ── Send connection request ───────────────────────────────────────────────

  Future<void> sendConnectionRequest({
    required String patientId,
    required String therapistId,
    required String patientName,
    required String therapistName,
    required String initiatedBy, // 'patient' | 'therapist'
    bool consentGiven = false,
  }) async {
    // Prevent duplicate requests
    final existing = await getExistingConnection(patientId, therapistId);
    if (existing != null && existing.status != 'declined') return;

    await _db.collection('therapistConnections').add({
      'patientId': patientId,
      'therapistId': therapistId,
      'patientName': patientName,
      'therapistName': therapistName,
      'status': 'pending',
      'initiatedBy': initiatedBy,
      'connectedAt': FieldValue.serverTimestamp(),
      'chatId': '',
      'consentGiven': consentGiven,
    });
  }

  // ── Accept connection request ─────────────────────────────────────────────

  Future<String> acceptConnectionRequest({
    required String connectionId,
    required String patientId,
    required String therapistId,
  }) async {
    final batch = _db.batch();

    // Create chat session
    final sessionRef = _db.collection('chat_sessions').doc();
    batch.set(sessionRef, {
      'patientId': patientId,
      'therapistId': therapistId,
      'type': 'direct',
      'status': 'active',
      'createdAt': FieldValue.serverTimestamp(),
      'patientSummary': '',
      'clinicalReport': '',
      'deletedByPatient': false,
      'deletedByTherapist': false,
    });

    // Update connection → active + chatId
    final connectionRef =
        _db.collection('therapistConnections').doc(connectionId);
    batch.update(connectionRef, {
      'status': 'active',
      'chatId': sessionRef.id,
      'consentGiven': true,
    });

    // Stamp therapistId on patient document
    final patientRef = _db.collection('patients').doc(patientId);
    batch.update(patientRef, {'therapistId': therapistId});

    // Add patient to therapist's patients array
    final therapistRef = _db.collection('therapists').doc(therapistId);
    batch.update(therapistRef, {
      'patients': FieldValue.arrayUnion([patientId]),
    });

    await batch.commit();
    return sessionRef.id;
  }

  // ── Decline connection request ────────────────────────────────────────────

  Future<void> declineConnectionRequest(String connectionId) async {
    await _db
        .collection('therapistConnections')
        .doc(connectionId)
        .update({'status': 'declined'});
  }

  // ── End connection ────────────────────────────────────────────────────────

  Future<void> endConnection({
    required String connectionId,
    required String patientId,
    required String therapistId,
  }) async {
    final batch = _db.batch();

    batch.update(
      _db.collection('therapistConnections').doc(connectionId),
      {'status': 'ended'},
    );

    // Clear therapistId from patient
    batch.update(
      _db.collection('patients').doc(patientId),
      {'therapistId': ''},
    );

    // Remove patient from therapist's patients array
    batch.update(
      _db.collection('therapists').doc(therapistId),
      {'patients': FieldValue.arrayRemove([patientId])},
    );

    await batch.commit();
  }

  // ── Queries ───────────────────────────────────────────────────────────────

  Future<TherapistConnectionModel?> getExistingConnection(
      String patientId, String therapistId) async {
    final snap = await _db
        .collection('therapistConnections')
        .where('patientId', isEqualTo: patientId)
        .where('therapistId', isEqualTo: therapistId)
        .limit(1)
        .get();
    if (snap.docs.isEmpty) return null;
    return TherapistConnectionModel.fromMap(
        snap.docs.first.id, snap.docs.first.data());
  }

  // Incoming for patient = therapist initiated
  Stream<List<TherapistConnectionModel>> getPendingRequestsForPatient(
      String patientId) {
    return _db
        .collection('therapistConnections')
        .where('patientId', isEqualTo: patientId)
        .where('status', isEqualTo: 'pending')
        .where('initiatedBy', isEqualTo: 'therapist')
        .snapshots()
        .map((s) => s.docs
            .map((d) => TherapistConnectionModel.fromMap(d.id, d.data()))
            .toList());
  }

  // Incoming for therapist = patient initiated
  Stream<List<TherapistConnectionModel>> getPendingRequestsForTherapist(
      String therapistId) {
    return _db
        .collection('therapistConnections')
        .where('therapistId', isEqualTo: therapistId)
        .where('status', isEqualTo: 'pending')
        .where('initiatedBy', isEqualTo: 'patient')
        .snapshots()
        .map((s) => s.docs
            .map((d) => TherapistConnectionModel.fromMap(d.id, d.data()))
            .toList());
  }

  Stream<List<TherapistConnectionModel>> watchPatientConnections(
      String patientId) {
    return _db
        .collection('therapistConnections')
        .where('patientId', isEqualTo: patientId)
        .snapshots()
        .map((s) => s.docs
            .map((d) => TherapistConnectionModel.fromMap(d.id, d.data()))
            .toList());
  }

  Stream<List<TherapistConnectionModel>> watchTherapistConnections(
      String therapistId) {
    return _db
        .collection('therapistConnections')
        .where('therapistId', isEqualTo: therapistId)
        .where('status', isEqualTo: 'active')
        .snapshots()
        .map((s) => s.docs
            .map((d) => TherapistConnectionModel.fromMap(d.id, d.data()))
            .toList());
  }

  // All patients (for therapist browse screen)
  Stream<List<Map<String, dynamic>>> getAllPatients() {
    return _db
        .collection('users')
        .where('role', isEqualTo: 'patient')
        .snapshots()
        .map((s) => s.docs.map((d) => {'uid': d.id, ...d.data()}).toList());
  }
}
