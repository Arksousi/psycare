import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/services/volunteer_service.dart';
import '../../data/models/volunteer_connection_model.dart';
import '../../data/models/volunteer_model.dart';
import 'auth_provider.dart';

final volunteerServiceProvider = Provider<VolunteerService>((ref) {
  return VolunteerService();
});

final currentVolunteerProvider =
    StreamProvider.autoDispose<VolunteerModel?>((ref) {
  final user = ref.watch(currentUserProvider);
  if (user == null) return Stream.value(null);
  return ref.read(volunteerServiceProvider).watchVolunteer(user.uid);
});

final volunteerProfileProvider =
    StreamProvider.autoDispose.family<VolunteerModel?, String>((ref, id) {
  if (id.isEmpty) return Stream.value(null);
  return ref.read(volunteerServiceProvider).watchVolunteer(id);
});

final availableVolunteersProvider =
    StreamProvider.autoDispose<List<VolunteerModel>>((ref) {
  return ref.read(volunteerServiceProvider).getAvailableVolunteers();
});

final patientVolunteerConnectionsProvider =
    StreamProvider.autoDispose.family<List<VolunteerConnectionModel>, String>(
        (ref, patientId) {
  if (patientId.isEmpty) return Stream.value([]);
  return ref
      .read(volunteerServiceProvider)
      .getPatientConnections(patientId);
});

final volunteerConnectionsProvider =
    StreamProvider.autoDispose.family<List<VolunteerConnectionModel>, String>(
        (ref, volunteerId) {
  if (volunteerId.isEmpty) return Stream.value([]);
  return ref
      .read(volunteerServiceProvider)
      .getVolunteerConnections(volunteerId);
});

// Incoming requests for a patient (volunteer-initiated pending)
final patientIncomingRequestsProvider =
    StreamProvider.autoDispose.family<List<VolunteerConnectionModel>, String>(
        (ref, patientId) {
  if (patientId.isEmpty) return Stream.value([]);
  return ref
      .read(volunteerServiceProvider)
      .getPendingRequestsForPatient(patientId);
});

// Incoming requests for a volunteer (patient-initiated pending)
final volunteerIncomingRequestsProvider =
    StreamProvider.autoDispose.family<List<VolunteerConnectionModel>, String>(
        (ref, volunteerId) {
  if (volunteerId.isEmpty) return Stream.value([]);
  return ref
      .read(volunteerServiceProvider)
      .getPendingRequestsForVolunteer(volunteerId);
});

// All connections for a patient (active + pending + declined) — used by volunteer profile screen
final patientAllConnectionsProvider =
    StreamProvider.autoDispose.family<List<VolunteerConnectionModel>, String>(
        (ref, patientId) {
  if (patientId.isEmpty) return Stream.value([]);
  return ref
      .read(volunteerServiceProvider)
      .getAllPatientConnections(patientId);
});

// All registered patients (for volunteer to browse)
final allPatientsProvider =
    StreamProvider.autoDispose<List<Map<String, dynamic>>>((ref) {
  return ref.read(volunteerServiceProvider).getAllPatients();
});
