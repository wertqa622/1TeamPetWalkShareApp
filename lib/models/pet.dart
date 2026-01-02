class Pet {
  final String id;
  final String userId;
  final String name;
  final String species;
  final String breed;
  final int age;
  final String? imageUrl;
  final String createdAt;
<<<<<<< HEAD
=======
  final DateTime? dateOfBirth;
  final String? gender; // '수컷' or '암컷'
  final double? weight; // kg
  final bool isNeutered;
>>>>>>> 773bdf40970e0a49ac658aa7c2583ae758645030

  Pet({
    required this.id,
    required this.userId,
    required this.name,
    required this.species,
    required this.breed,
    required this.age,
    this.imageUrl,
    required this.createdAt,
<<<<<<< HEAD
=======
    this.dateOfBirth,
    this.gender,
    this.weight,
    this.isNeutered = false,
>>>>>>> 773bdf40970e0a49ac658aa7c2583ae758645030
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
<<<<<<< HEAD
=======
      'dateOfBirth': dateOfBirth?.toIso8601String(),
      'gender': gender,
      'weight': weight,
      'isNeutered': isNeutered,
>>>>>>> 773bdf40970e0a49ac658aa7c2583ae758645030
    };
  }

  factory Pet.fromJson(Map<String, dynamic> json) {
    return Pet(
      id: json['id'] as String,
      userId: json['userId'] as String,
      name: json['name'] as String,
      species: json['species'] as String,
      breed: json['breed'] as String,
      age: json['age'] as int,
      imageUrl: json['imageUrl'] as String?,
      createdAt: json['createdAt'] as String,
<<<<<<< HEAD
=======
      dateOfBirth: json['dateOfBirth'] != null
          ? DateTime.parse(json['dateOfBirth'] as String)
          : null,
      gender: json['gender'] as String?,
      weight: json['weight'] != null ? (json['weight'] as num).toDouble() : null,
      isNeutered: json['isNeutered'] as bool? ?? false,
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
    };
  }

  factory Pet.fromFirestore(Map<String, dynamic> json) {
    return Pet(
      id: json['id'] as String,
      userId: json['userId'] as String,
      name: json['name'] as String,
      species: json['species'] as String,
      breed: json['breed'] as String,
      age: json['age'] as int,
      imageUrl: json['imageUrl'] as String?,
      createdAt: json['createdAt'] as String,
      dateOfBirth: json['dateOfBirth'] != null
          ? DateTime.parse(json['dateOfBirth'] as String)
          : null,
      gender: json['gender'] as String?,
      weight: json['weight'] != null ? (json['weight'] as num).toDouble() : null,
      isNeutered: json['isNeutered'] as bool? ?? false,
>>>>>>> 773bdf40970e0a49ac658aa7c2583ae758645030
    );
  }
}


