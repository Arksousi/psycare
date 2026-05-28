// booking_repository.dart
// Handles Firestore operations for booking requests.

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/services/firebase_service.dart';
import '../models/booking_model.dart';

class BookingRepository {
  final FirebaseService _firebase;

  BookingRepository({FirebaseService? firebase})
      : _firebase = firebase ?? FirebaseService.instance;

  Future<void> createBookingRequest(BookingRequest booking) async {
    await _firebase.firestore
        .collection('booking_requests')
        .doc(booking.id)
        .set(booking.toMap());
  }

  Stream<List<BookingRequest>> streamPendingBookings(String therapistId) {
    return _firebase.firestore
        .collection('booking_requests')
        .where('therapistId', isEqualTo: therapistId)
        .where('status', isEqualTo: 'pending')
        .snapshots()
        .map((snap) {
      final bookings =
          snap.docs.map((d) => BookingRequest.fromMap(d.id, d.data())).toList();
      bookings.sort((a, b) => a.requestedAt.compareTo(b.requestedAt));
      return bookings;
    });
  }

  Future<void> acceptBooking(
    String bookingId, {
    required String patientId,
    required String therapistId,
  }) async {
    final firestore = _firebase.firestore;

    // Check whether a direct session already exists for this pair.
    final existingSession = await firestore
        .collection('chat_sessions')
        .where('patientId', isEqualTo: patientId)
        .where('therapistId', isEqualTo: therapistId)
        .where('type', isEqualTo: 'direct')
        .limit(1)
        .get();

    final batch = firestore.batch();

    batch.update(
      firestore.collection('booking_requests').doc(bookingId),
      {'status': 'confirmed'},
    );

    // Stamp therapistId on the patient document so they appear in
    // watchPatientsForTherapist() and their assessment is visible.
    batch.update(
      firestore.collection('patients').doc(patientId),
      {'therapistId': therapistId},
    );

    // Keep therapist.patients array in sync for the stats counter.
    batch.update(
      firestore.collection('therapists').doc(therapistId),
      {'patients': FieldValue.arrayUnion([patientId])},
    );

    // Create the direct chat session if one doesn't exist yet.
    if (existingSession.docs.isEmpty) {
      final sessionDoc = firestore.collection('chat_sessions').doc();
      batch.set(sessionDoc, {
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
    }

    await batch.commit();
  }

  Future<void> declineBooking(String bookingId) async {
    await _firebase.firestore
        .collection('booking_requests')
        .doc(bookingId)
        .update({'status': 'declined'});
  }

  Future<void> cancelBooking(String bookingId,
      {required String cancelledBy, String? reason}) async {
    await _firebase.firestore
        .collection('booking_requests')
        .doc(bookingId)
        .update({
      'status': 'cancelled_by_$cancelledBy',
      if (reason != null && reason.isNotEmpty) 'cancelReason': reason,
    });
  }

  Future<void> requestReschedule(String bookingId, String note) async {
    await _firebase.firestore
        .collection('booking_requests')
        .doc(bookingId)
        .update({
      'status': 'reschedule_requested',
      'rescheduleNote': note,
    });
  }

  Future<void> confirmReschedule(String bookingId) async {
    await _firebase.firestore
        .collection('booking_requests')
        .doc(bookingId)
        .update({'status': 'confirmed'});
  }

  Stream<List<BookingRequest>> streamConfirmedBookings(String therapistId) {
    return _firebase.firestore
        .collection('booking_requests')
        .where('therapistId', isEqualTo: therapistId)
        .where('status', isEqualTo: 'confirmed')
        .snapshots()
        .map((snap) {
      final bookings =
          snap.docs.map((d) => BookingRequest.fromMap(d.id, d.data())).toList();
      bookings.sort((a, b) => b.requestedAt.compareTo(a.requestedAt));
      return bookings;
    });
  }

  Stream<List<BookingRequest>> streamPatientBookings(String patientId) {
    return _firebase.firestore
        .collection('booking_requests')
        .where('patientId', isEqualTo: patientId)
        .snapshots()
        .map((snap) {
      final bookings =
          snap.docs.map((d) => BookingRequest.fromMap(d.id, d.data())).toList();
      bookings.sort((a, b) => b.requestedAt.compareTo(a.requestedAt));
      return bookings;
    });
  }
}

final bookingRepositoryProvider =
    Provider<BookingRepository>((ref) => BookingRepository());
