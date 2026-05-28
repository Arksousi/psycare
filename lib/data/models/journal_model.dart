import 'package:cloud_firestore/cloud_firestore.dart';

class JournalEntry {
  final String id;
  final String patientId;
  final String therapistId;
  final String content;
  final String mood; // 'great' | 'okay' | 'sad' | 'anxious' | 'angry'
  final DateTime createdAt;

  const JournalEntry({
    required this.id,
    required this.patientId,
    required this.therapistId,
    required this.content,
    required this.mood,
    required this.createdAt,
  });

  factory JournalEntry.fromMap(String id, Map<String, dynamic> map) =>
      JournalEntry(
        id: id,
        patientId: map['patientId'] as String? ?? '',
        therapistId: map['therapistId'] as String? ?? '',
        content: map['content'] as String? ?? '',
        mood: map['mood'] as String? ?? 'okay',
        createdAt:
            (map['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
      );

  Map<String, dynamic> toMap() => {
        'patientId': patientId,
        'therapistId': therapistId,
        'content': content,
        'mood': mood,
        'createdAt': FieldValue.serverTimestamp(),
      };

  static String moodEmoji(String mood) {
    switch (mood) {
      case 'great':   return '😊';
      case 'okay':    return '😐';
      case 'sad':     return '😔';
      case 'anxious': return '😰';
      case 'angry':   return '😤';
      default:        return '😐';
    }
  }
}
