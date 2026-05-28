// chat_repository.dart
// Handles Firestore operations for immediate chat requests and sessions.

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/services/firebase_service.dart';
import '../models/chat_model.dart';

class ChatRepository {
  final FirebaseService _firebase;

  ChatRepository({FirebaseService? firebase})
      : _firebase = firebase ?? FirebaseService.instance;

  Future<String> createImmediateRequest({
    required String patientId,
    required String patientName,
    required String patientSummary,
    required String clinicalReport,
  }) async {
    final doc = _firebase.firestore.collection('immediate_requests').doc();
    await doc.set({
      'patientId': patientId,
      'patientName': patientName,
      'patientSummary': patientSummary,
      'clinicalReport': clinicalReport,
      'status': 'pending',
      'createdAt': FieldValue.serverTimestamp(),
    });
    return doc.id;
  }

  Stream<ImmediateRequest?> watchRequest(String requestId) {
    return _firebase.firestore
        .collection('immediate_requests')
        .doc(requestId)
        .snapshots()
        .map((doc) =>
            doc.exists ? ImmediateRequest.fromMap(doc.id, doc.data()!) : null);
  }

  Stream<List<ImmediateRequest>> streamPendingRequests() {
    return _firebase.firestore
        .collection('immediate_requests')
        .where('status', isEqualTo: 'pending')
        .snapshots()
        .map((snap) {
      final requests =
          snap.docs.map((d) => ImmediateRequest.fromMap(d.id, d.data())).toList();
      requests.sort((a, b) => a.createdAt.compareTo(b.createdAt));
      return requests;
    });
  }

  Future<String> createSession({
    required String patientId,
    required String therapistId,
    required String patientSummary,
    required String clinicalReport,
    String type = 'immediate',
  }) async {
    final doc = _firebase.firestore.collection('chat_sessions').doc();
    await doc.set({
      'patientId': patientId,
      'therapistId': therapistId,
      'status': 'active',
      'type': type,
      'createdAt': FieldValue.serverTimestamp(),
      'patientSummary': patientSummary,
      'clinicalReport': clinicalReport,
    });
    return doc.id;
  }

  Future<String> getOrCreateDirectSession({
    required String patientId,
    required String therapistId,
  }) async {
    final existing = await _firebase.firestore
        .collection('chat_sessions')
        .where('patientId', isEqualTo: patientId)
        .where('therapistId', isEqualTo: therapistId)
        .where('type', isEqualTo: 'direct')
        .limit(1)
        .get();
    if (existing.docs.isNotEmpty) return existing.docs.first.id;

    final doc = _firebase.firestore.collection('chat_sessions').doc();
    await doc.set({
      'patientId': patientId,
      'therapistId': therapistId,
      'type': 'direct',
      'status': 'active',
      'createdAt': FieldValue.serverTimestamp(),
      'patientSummary': '',
      'clinicalReport': '',
    });
    return doc.id;
  }

  Future<String> acceptRequest({
    required String requestId,
    required String therapistId,
    required String patientId,
    required String patientSummary,
    required String clinicalReport,
  }) async {
    // Soft-delete any previous ended immediate sessions for this pair so both
    // sides get a clean slate before the new session starts.
    final existing = await _firebase.firestore
        .collection('chat_sessions')
        .where('patientId', isEqualTo: patientId)
        .where('therapistId', isEqualTo: therapistId)
        .where('type', isEqualTo: 'immediate')
        .get();

    final stale = existing.docs
        .where((doc) => doc.data()['status'] == 'ended')
        .toList();

    if (stale.isNotEmpty) {
      final batch = _firebase.firestore.batch();
      for (final doc in stale) {
        batch.update(doc.reference, {
          'deletedByPatient': true,
          'deletedByTherapist': true,
        });
      }
      await batch.commit();
    }

    // Always create a fresh session.
    final sessionId = await createSession(
      patientId: patientId,
      therapistId: therapistId,
      patientSummary: patientSummary,
      clinicalReport: clinicalReport,
    );

    await _firebase.firestore
        .collection('immediate_requests')
        .doc(requestId)
        .update({
      'status': 'accepted',
      'acceptedByTherapistId': therapistId,
      'chatSessionId': sessionId,
    });
    _firebase.firestore
        .collection('chat_sessions')
        .doc(sessionId)
        .collection('messages')
        .add({
      'senderId': 'system',
      'senderRole': 'system',
      'text': 'Your doctor has joined the session. They will be with you shortly. 💙',
      'timestamp': FieldValue.serverTimestamp(),
    }).then<void>((_) {}, onError: (_) {});
    return sessionId;
  }

  Stream<ChatSession?> watchSession(String sessionId) {
    return _firebase.firestore
        .collection('chat_sessions')
        .doc(sessionId)
        .snapshots()
        .map((doc) =>
            doc.exists ? ChatSession.fromMap(doc.id, doc.data()!) : null);
  }

  Future<void> convertSessionToDirect(String sessionId) async {
    await _firebase.firestore
        .collection('chat_sessions')
        .doc(sessionId)
        .update({'type': 'direct', 'status': 'active'});
  }

  Future<void> endSession(String sessionId) async {
    await _firebase.firestore
        .collection('chat_sessions')
        .doc(sessionId)
        .update({'status': 'ended'});
  }

  Stream<List<ChatSession>> streamSessionsForPatient(String patientId) {
    return _firebase.firestore
        .collection('chat_sessions')
        .where('patientId', isEqualTo: patientId)
        .snapshots()
        .map((snap) {
      final sessions = snap.docs
          .map((d) => ChatSession.fromMap(d.id, d.data()))
          .where((s) => !s.deletedByPatient)
          .toList();
      sessions.sort((a, b) => b.createdAt.compareTo(a.createdAt));
      return sessions;
    });
  }

  Stream<List<ChatSession>> streamSessionsForTherapist(String therapistId) {
    return _firebase.firestore
        .collection('chat_sessions')
        .where('therapistId', isEqualTo: therapistId)
        .snapshots()
        .map((snap) {
      final sessions = snap.docs
          .map((d) => ChatSession.fromMap(d.id, d.data()))
          .where((s) => !s.deletedByTherapist)
          .toList();
      sessions.sort((a, b) => b.createdAt.compareTo(a.createdAt));
      return sessions;
    });
  }

  Stream<List<ChatSession>> streamSessionsForPair(
      String patientId, String therapistId) {
    return _firebase.firestore
        .collection('chat_sessions')
        .where('patientId', isEqualTo: patientId)
        .where('therapistId', isEqualTo: therapistId)
        .where('type', isEqualTo: 'immediate')
        .snapshots()
        .map((snap) {
      final sessions = snap.docs
          .map((d) => ChatSession.fromMap(d.id, d.data()))
          .where((s) => !s.deletedByTherapist)
          .toList();
      sessions.sort((a, b) => b.createdAt.compareTo(a.createdAt));
      return sessions;
    });
  }

  Stream<ChatSession?> streamDirectSessionForPatient(String patientId) {
    return _firebase.firestore
        .collection('chat_sessions')
        .where('patientId', isEqualTo: patientId)
        .where('type', isEqualTo: 'direct')
        .limit(1)
        .snapshots()
        .map((snap) => snap.docs.isEmpty
            ? null
            : ChatSession.fromMap(
                snap.docs.first.id, snap.docs.first.data()));
  }

  Stream<List<ChatSession>> streamDirectSessionsForTherapist(
      String therapistId) {
    return _firebase.firestore
        .collection('chat_sessions')
        .where('therapistId', isEqualTo: therapistId)
        .where('type', isEqualTo: 'direct')
        .snapshots()
        .map((snap) {
      final sessions = snap.docs
          .map((d) => ChatSession.fromMap(d.id, d.data()))
          .where((s) => !s.deletedByTherapist)
          .toList();
      sessions.sort((a, b) => b.createdAt.compareTo(a.createdAt));
      return sessions;
    });
  }

  Stream<List<ChatSession>> streamActiveImmediateSessionsForTherapist(
      String therapistId) {
    return _firebase.firestore
        .collection('chat_sessions')
        .where('therapistId', isEqualTo: therapistId)
        .where('type', isEqualTo: 'immediate')
        .where('status', isEqualTo: 'active')
        .snapshots()
        .map((snap) => snap.docs
            .map((d) => ChatSession.fromMap(d.id, d.data()))
            .toList());
  }

  Future<void> deleteSessionForUser({
    required String sessionId,
    required String role,
  }) async {
    final field =
        role == 'therapist' ? 'deletedByTherapist' : 'deletedByPatient';
    await _firebase.firestore
        .collection('chat_sessions')
        .doc(sessionId)
        .update({field: true});
  }

  Future<void> deleteAllSessionsForUser({
    required String userId,
    required String role,
  }) async {
    final idField = role == 'therapist' ? 'therapistId' : 'patientId';
    final flagField =
        role == 'therapist' ? 'deletedByTherapist' : 'deletedByPatient';
    final snap = await _firebase.firestore
        .collection('chat_sessions')
        .where(idField, isEqualTo: userId)
        .get();
    final batch = _firebase.firestore.batch();
    for (final doc in snap.docs) {
      batch.update(doc.reference, {flagField: true});
    }
    await batch.commit();
  }

  Future<void> deleteSessionsForPair({
    required String patientId,
    required String therapistId,
  }) async {
    final snap = await _firebase.firestore
        .collection('chat_sessions')
        .where('patientId', isEqualTo: patientId)
        .where('therapistId', isEqualTo: therapistId)
        .get();
    final batch = _firebase.firestore.batch();
    for (final doc in snap.docs) {
      batch.update(doc.reference, {'deletedByTherapist': true});
    }
    await batch.commit();
  }

  Stream<List<ChatMessage>> watchMessages(String sessionId) {
    return _firebase.firestore
        .collection('chat_sessions')
        .doc(sessionId)
        .collection('messages')
        .snapshots()
        .map((snap) {
      final msgs =
          snap.docs.map((d) => ChatMessage.fromMap(d.id, d.data())).toList();
      msgs.sort((a, b) => a.timestamp.compareTo(b.timestamp));
      return msgs;
    });
  }

  Future<void> sendMessage({
    required String sessionId,
    required String senderId,
    required String senderRole,
    required String text,
  }) async {
    await _firebase.firestore
        .collection('chat_sessions')
        .doc(sessionId)
        .collection('messages')
        .add({
      'senderId': senderId,
      'senderRole': senderRole,
      'text': text,
      'timestamp': FieldValue.serverTimestamp(),
    });
  }
}

final chatRepositoryProvider =
    Provider<ChatRepository>((ref) => ChatRepository());
