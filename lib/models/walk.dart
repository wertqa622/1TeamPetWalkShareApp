import 'package:cloud_firestore/cloud_firestore.dart';

class Walk {
  final String id;
  final String userId;
  final String petId;
  final DateTime startTime;
  final DateTime? endTime;
  final double? distance;
  final int? duration; // 초 단위
  final String? route;
  final String? notes;
  final String? mood;
  final String? imageUrl;
  final String createdAt;

  Walk({
    required this.id,
    required this.userId,
    required this.petId,
    required this.startTime,
    this.endTime,
    this.distance,
    this.duration,
    this.route,
    this.notes,
    this.mood,
    this.imageUrl,
    required this.createdAt,
  });

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'userId': userId,
      'petId': petId,
      'startTime': startTime.toIso8601String(),
      'endTime': endTime?.toIso8601String(),
      'distance': distance,
      'duration': duration,
      'route': route,
      'notes': notes,
      'mood': mood,
      'imageUrl': imageUrl,
      'createdAt': createdAt,
    };
  }

  factory Walk.fromJson(Map<String, dynamic> json) {

    DateTime parseDateTime(dynamic value) {
      if (value is Timestamp) return value.toDate();
      if (value is String) return DateTime.tryParse(value) ?? DateTime.now();
      return DateTime.now(); // 데이터가 null일 때 현재 시간으로 방어
    }

    return Walk(
      id: json['id'] as String? ?? '',
      userId: json['userId'] as String? ?? '',
      petId: json['petId'] as String? ?? '',
      startTime: parseDateTime(json['startTime']),
      endTime: json['endTime'] != null ? parseDateTime(json['endTime']) : null,
      distance: (json['distance'] as num?)?.toDouble(),
      duration: json['duration'] as int?,
      route: json['route'] as String?,
      notes: json['notes'] as String?,
      mood: json['mood'] as String?,
      imageUrl: json['imageUrl'] as String?,
      createdAt: json['createdAt']?.toString() ?? '',
    );
  }
}


