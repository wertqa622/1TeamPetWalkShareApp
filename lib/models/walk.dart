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
      'createdAt': createdAt,
    };
  }

  factory Walk.fromJson(Map<String, dynamic> json) {
    return Walk(
      id: json['id'] as String,
      userId: json['userId'] as String,
      petId: json['petId'] as String,
      startTime: DateTime.parse(json['startTime'] as String),
      endTime: json['endTime'] != null
          ? DateTime.parse(json['endTime'] as String)
          : null,
      distance: json['distance'] as double?,
      duration: json['duration'] as int?,
      route: json['route'] as String?,
      notes: json['notes'] as String?,
      createdAt: json['createdAt'] as String,
    );
  }
}


