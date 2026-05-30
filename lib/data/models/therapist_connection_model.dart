import 'package:cloud_firestore/cloud_firestore.dart';

class TherapistConnectionModel {
  final String connectionId;
  final String patientId;
  final String therapistId;
  final String patientName;
  final String therapistName;
  final String status; // 'pending' | 'active' | 'ended' | 'declined'
  final String initiatedBy; // 'patient' | 'therapist'
  final DateTime connectedAt;
  final String chatId;
  final bool consentGiven;

  const TherapistConnectionModel({
    required this.connectionId,
    required this.patientId,
    required this.therapistId,
    required this.patientName,
    required this.therapistName,
    required this.status,
    required this.initiatedBy,
    required this.connectedAt,
    required this.chatId,
    required this.consentGiven,
  });

  bool get isActive => status == 'active';
  bool get isPending => status == 'pending';
  bool get isDeclined => status == 'declined';
  bool get isEnded => status == 'ended';

  // Incoming for patient = therapist initiated the request
  bool get isIncomingForPatient => initiatedBy == 'therapist';

  // Incoming for therapist = patient initiated the request
  bool get isIncomingForTherapist => initiatedBy == 'patient';

  String get patientFirstName => patientName.split(' ').first;
  String get therapistFirstName => therapistName.split(' ').first;

  factory TherapistConnectionModel.fromMap(
      String id, Map<String, dynamic> map) {
    return TherapistConnectionModel(
      connectionId: id,
      patientId: map['patientId'] as String? ?? '',
      therapistId: map['therapistId'] as String? ?? '',
      patientName: map['patientName'] as String? ?? '',
      therapistName: map['therapistName'] as String? ?? '',
      status: map['status'] as String? ?? 'pending',
      initiatedBy: map['initiatedBy'] as String? ?? 'patient',
      connectedAt: map['connectedAt'] is Timestamp
          ? (map['connectedAt'] as Timestamp).toDate()
          : DateTime.now(),
      chatId: map['chatId'] as String? ?? '',
      consentGiven: map['consentGiven'] as bool? ?? false,
    );
  }

  Map<String, dynamic> toMap() => {
        'patientId': patientId,
        'therapistId': therapistId,
        'patientName': patientName,
        'therapistName': therapistName,
        'status': status,
        'initiatedBy': initiatedBy,
        'connectedAt': FieldValue.serverTimestamp(),
        'chatId': chatId,
        'consentGiven': consentGiven,
      };
}
