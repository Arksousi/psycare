import 'package:cloud_firestore/cloud_firestore.dart';

class VolunteerConnectionModel {
  final String connectionId;
  final String patientId;
  final String volunteerId;
  final String patientName;
  final String volunteerName;
  final String therapistId;
  final String status; // 'pending' | 'active' | 'ended' | 'declined'
  final DateTime connectedAt;
  final String chatId;
  final String initiatedBy; // 'volunteer' | 'patient'

  const VolunteerConnectionModel({
    required this.connectionId,
    required this.patientId,
    required this.volunteerId,
    required this.patientName,
    required this.volunteerName,
    required this.therapistId,
    required this.status,
    required this.connectedAt,
    required this.chatId,
    this.initiatedBy = 'patient',
  });

  factory VolunteerConnectionModel.fromMap(
      String id, Map<String, dynamic> map) {
    return VolunteerConnectionModel(
      connectionId: id,
      patientId: map['patientId'] as String? ?? '',
      volunteerId: map['volunteerId'] as String? ?? '',
      patientName: map['patientName'] as String? ?? '',
      volunteerName: map['volunteerName'] as String? ?? '',
      therapistId: map['therapistId'] as String? ?? '',
      status: map['status'] as String? ?? 'active',
      connectedAt: map['connectedAt'] is Timestamp
          ? (map['connectedAt'] as Timestamp).toDate()
          : DateTime.now(),
      chatId: map['chatId'] as String? ?? '',
      initiatedBy: map['initiatedBy'] as String? ?? 'patient',
    );
  }

  Map<String, dynamic> toMap() => {
        'connectionId': connectionId,
        'patientId': patientId,
        'volunteerId': volunteerId,
        'patientName': patientName,
        'volunteerName': volunteerName,
        'therapistId': therapistId,
        'status': status,
        'connectedAt': Timestamp.fromDate(connectedAt),
        'chatId': chatId,
        'initiatedBy': initiatedBy,
      };

  String get patientFirstName {
    final parts = patientName.trim().split(' ');
    return parts.isNotEmpty ? parts[0] : patientName;
  }

  String get volunteerFirstName {
    final parts = volunteerName.trim().split(' ');
    return parts.isNotEmpty ? parts[0] : volunteerName;
  }

  bool get isActive => status == 'active';
  bool get isEnded => status == 'ended';
  bool get isPending => status == 'pending';
  bool get isDeclined => status == 'declined';
  bool get isIncomingForPatient => initiatedBy == 'volunteer';
  bool get isIncomingForVolunteer => initiatedBy == 'patient';
}
