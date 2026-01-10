class Pet {
  final String id;
  final String userId;
  final String name;
  final String species; // 종류 (예: "강아지", "고양이")
  final String breed;
  final int age;
  final String? imageUrl; // Firebase Storage URL
  final String createdAt;
  final DateTime? dateOfBirth;
  final String? gender; // '수컷' or '암컷'
  final double? weight; // kg
  final bool isNeutered;
  final bool isRepresentative; // 대표 반려동물 여부

  Pet({
    required this.id,
    required this.userId,
    required this.name,
    required this.species,
    required this.breed,
    required this.age,
    this.imageUrl,
    required this.createdAt,
    this.dateOfBirth,
    this.gender,
    this.weight,
    this.isNeutered = false,
    this.isRepresentative = false,
  });

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'userId': userId,
      'name': name,
      'species': species,
      'breed': breed,
      'age': age,
      'imageUrl': imageUrl,
      'createdAt': createdAt,
      'dateOfBirth': dateOfBirth?.toIso8601String(),
      'gender': gender,
      'weight': weight,
      'isNeutered': isNeutered,
      'isRepresentative': isRepresentative,
    };
  }

  factory Pet.fromJson(Map<String, dynamic> json) {
    return Pet(
      id: json['id'] as String,
      userId: json['userId'] as String,
      name: json['name'] as String,
      species: json['species'] as String? ?? '강아지', // 기본값 설정
      breed: json['breed'] as String,
      age: json['age'] as int,
      imageUrl: json['imageUrl'] as String?,
      createdAt: json['createdAt'] as String,
      dateOfBirth: json['dateOfBirth'] != null
          ? DateTime.parse(json['dateOfBirth'] as String)
          : null,
      gender: json['gender'] as String?,
      weight: json['weight'] != null ? (json['weight'] as num).toDouble() : null,
      isNeutered: json['isNeutered'] is bool ? json['isNeutered'] as bool : false,
      isRepresentative: json['isRepresentative'] is bool ? json['isRepresentative'] as bool : false,
    );
  }

  // Firestore용 변환 (Firestore는 DateTime을 Timestamp로 저장)
  Map<String, dynamic> toFirestore() {
    return {
      'id': id,
      'userId': userId,
      'name': name,
      'species': species,
      'breed': breed,
      'age': age,
      'imageUrl': imageUrl,
      'createdAt': createdAt,
      'dateOfBirth': dateOfBirth?.toIso8601String(),
      'gender': gender,
      'weight': weight,
      'isNeutered': isNeutered,
      'isRepresentative': isRepresentative,
    };
  }

  factory Pet.fromFirestore(Map<String, dynamic> json) {
    return Pet(
      id: json['id'] as String,
      userId: json['userId'] as String,
      name: json['name'] as String,
      species: json['species'] as String? ?? '강아지', // 기본값 설정
      breed: json['breed'] as String,
      age: json['age'] as int,
      imageUrl: json['imageUrl'] as String?,
      createdAt: json['createdAt'] as String,
      dateOfBirth: json['dateOfBirth'] != null
          ? DateTime.parse(json['dateOfBirth'] as String)
          : null,
      gender: json['gender'] as String?,
      weight: json['weight'] != null ? (json['weight'] as num).toDouble() : null,
      isNeutered: json['isNeutered'] is bool ? json['isNeutered'] as bool : false,
      isRepresentative: json['isRepresentative'] is bool ? json['isRepresentative'] as bool : false,
    );
  }

  // dateOfBirth로부터 현재 나이를 계산하는 메서드
  int calculateAge() {
    if (dateOfBirth == null) {
      // dateOfBirth가 없으면 저장된 age 반환 (하위 호환성)
      return age;
    }
    final now = DateTime.now();
    int calculatedAge = now.year - dateOfBirth!.year;
    if (now.month < dateOfBirth!.month ||
        (now.month == dateOfBirth!.month && now.day < dateOfBirth!.day)) {
      calculatedAge--;
    }
    return calculatedAge;
  }
}


