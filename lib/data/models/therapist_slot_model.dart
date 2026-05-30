import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';

class TherapistSlotModel {
  final String slotId;
  final String therapistId;
  final DateTime dateTime;
  final int durationMinutes;
  final bool isAvailable;
  final String bookedByPatientId;

  const TherapistSlotModel({
    required this.slotId,
    required this.therapistId,
    required this.dateTime,
    required this.durationMinutes,
    required this.isAvailable,
    required this.bookedByPatientId,
  });

  String get formattedDate => DateFormat('EEE d MMM').format(dateTime);
  String get formattedTime => DateFormat('h:mm a').format(dateTime);
  String get formattedDateTime => '$formattedDate · $formattedTime';

  factory TherapistSlotModel.fromMap(String id, Map<String, dynamic> map) {
    return TherapistSlotModel(
      slotId: id,
      therapistId: map['therapistId'] as String? ?? '',
      dateTime: map['dateTime'] is Timestamp
          ? (map['dateTime'] as Timestamp).toDate()
          : DateTime.now(),
      durationMinutes: (map['durationMinutes'] as num?)?.toInt() ?? 60,
      isAvailable: map['isAvailable'] as bool? ?? true,
      bookedByPatientId: map['bookedByPatientId'] as String? ?? '',
    );
  }

  Map<String, dynamic> toMap() => {
        'therapistId': therapistId,
        'dateTime': Timestamp.fromDate(dateTime),
        'durationMinutes': durationMinutes,
        'isAvailable': isAvailable,
        'bookedByPatientId': bookedByPatientId,
      };
}
