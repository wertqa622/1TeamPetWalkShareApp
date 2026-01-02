class Pet {
  final String id;
  final String userId;
  final String name;
  final String species;
  final String breed;
  final int age;
  final String? imageUrl;
  final String createdAt;

  Pet({
    required this.id,
    required this.userId,
    required this.name,
    required this.species,
    required this.breed,
    required this.age,
    this.imageUrl,
    required this.createdAt,
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
    );
  }
}


