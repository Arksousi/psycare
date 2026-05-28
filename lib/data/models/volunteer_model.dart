import 'package:cloud_firestore/cloud_firestore.dart';

class VolunteerModel {
  final String volunteerId;
  final String name;
  final String email;
  final String profilePhoto;
  final String university;
  final String specialization;
  final String yearOfStudy;
  final String bio;
  final int volunteerHours;
  final double rating;
  final int ratingCount;
  final List<String> connectedPatients;
  final bool isAvailable;
  final DateTime joinedAt;

  const VolunteerModel({
    required this.volunteerId,
    required this.name,
    required this.email,
    this.profilePhoto = '',
    this.university = '',
    this.specialization = '',
    this.yearOfStudy = '',
    this.bio = '',
    this.volunteerHours = 0,
    this.rating = 0.0,
    this.ratingCount = 0,
    this.connectedPatients = const [],
    this.isAvailable = false,
    required this.joinedAt,
  });

  factory VolunteerModel.fromMap(String id, Map<String, dynamic> map) {
    return VolunteerModel(
      volunteerId: id,
      name: map['name'] as String? ?? '',
      email: map['email'] as String? ?? '',
      profilePhoto: map['profilePhoto'] as String? ?? '',
      university: map['university'] as String? ?? '',
      specialization: map['specialization'] as String? ?? '',
      yearOfStudy: map['yearOfStudy'] as String? ?? '',
      bio: map['bio'] as String? ?? '',
      volunteerHours: (map['volunteerHours'] as num?)?.toInt() ?? 0,
      rating: (map['rating'] as num?)?.toDouble() ?? 0.0,
      ratingCount: (map['ratingCount'] as num?)?.toInt() ?? 0,
      connectedPatients: List<String>.from(map['connectedPatients'] ?? []),
      isAvailable: map['isAvailable'] as bool? ?? false,
      joinedAt: map['joinedAt'] is Timestamp
          ? (map['joinedAt'] as Timestamp).toDate()
          : DateTime.now(),
    );
  }

  Map<String, dynamic> toMap() => {
        'volunteerId': volunteerId,
        'name': name,
        'email': email,
        'profilePhoto': profilePhoto,
        'university': university,
        'specialization': specialization,
        'yearOfStudy': yearOfStudy,
        'bio': bio,
        'volunteerHours': volunteerHours,
        'rating': rating,
        'ratingCount': ratingCount,
        'connectedPatients': connectedPatients,
        'isAvailable': isAvailable,
        'joinedAt': Timestamp.fromDate(joinedAt),
      };

  VolunteerModel copyWith({
    String? volunteerId,
    String? name,
    String? email,
    String? profilePhoto,
    String? university,
    String? specialization,
    String? yearOfStudy,
    String? bio,
    int? volunteerHours,
    double? rating,
    int? ratingCount,
    List<String>? connectedPatients,
    bool? isAvailable,
    DateTime? joinedAt,
  }) =>
      VolunteerModel(
        volunteerId: volunteerId ?? this.volunteerId,
        name: name ?? this.name,
        email: email ?? this.email,
        profilePhoto: profilePhoto ?? this.profilePhoto,
        university: university ?? this.university,
        specialization: specialization ?? this.specialization,
        yearOfStudy: yearOfStudy ?? this.yearOfStudy,
        bio: bio ?? this.bio,
        volunteerHours: volunteerHours ?? this.volunteerHours,
        rating: rating ?? this.rating,
        ratingCount: ratingCount ?? this.ratingCount,
        connectedPatients: connectedPatients ?? this.connectedPatients,
        isAvailable: isAvailable ?? this.isAvailable,
        joinedAt: joinedAt ?? this.joinedAt,
      );

  String get initials {
    final parts = name.trim().split(' ');
    if (parts.length >= 2) return '${parts[0][0]}${parts[1][0]}'.toUpperCase();
    if (parts[0].isNotEmpty) return parts[0][0].toUpperCase();
    return '?';
  }
}
