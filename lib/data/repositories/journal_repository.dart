import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/services/firebase_service.dart';
import '../models/journal_model.dart';

class JournalRepository {
  final FirebaseFirestore _db;

  JournalRepository({FirebaseFirestore? db})
      : _db = db ?? FirebaseService.instance.firestore;

  Future<void> addEntry({
    required String patientId,
    required String therapistId,
    required String content,
    required String mood,
  }) async {
    await _db.collection('journal_entries').add({
      'patientId': patientId,
      'therapistId': therapistId,
      'content': content,
      'mood': mood,
      'createdAt': FieldValue.serverTimestamp(),
    });
  }

  Stream<List<JournalEntry>> streamEntries({
    required String patientId,
    required String therapistId,
  }) {
    return _db
        .collection('journal_entries')
        .where('patientId', isEqualTo: patientId)
        .where('therapistId', isEqualTo: therapistId)
        .snapshots()
        .map((snap) {
      final entries = snap.docs
          .map((d) => JournalEntry.fromMap(d.id, d.data()))
          .toList();
      entries.sort((a, b) => b.createdAt.compareTo(a.createdAt));
      return entries;
    });
  }
}

final journalRepositoryProvider =
    Provider<JournalRepository>((ref) => JournalRepository());
