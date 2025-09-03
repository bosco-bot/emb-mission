class PrayerCategoryModel {
  final int id;
  final String name;
  final bool isActive;
  final DateTime createdAt;
  final DateTime updatedAt;

  PrayerCategoryModel({
    required this.id,
    required this.name,
    required this.isActive,
    required this.createdAt,
    required this.updatedAt,
  });

  factory PrayerCategoryModel.fromJson(Map<String, dynamic> json) {
    return PrayerCategoryModel(
      id: json['id_prayer_cat'] ?? 0,
      name: json['name'] ?? '',
      isActive: json['is_active'] == 1,
      createdAt: DateTime.tryParse(json['created_at'] ?? '') ?? DateTime.now(),
      updatedAt: DateTime.tryParse(json['updated_at'] ?? '') ?? DateTime.now(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id_prayer_cat': id,
      'name': name,
      'is_active': isActive ? 1 : 0,
      'created_at': createdAt.toIso8601String(),
      'updated_at': updatedAt.toIso8601String(),
    };
  }

  @override
  String toString() {
    return 'PrayerCategoryModel(id: $id, name: $name, isActive: $isActive)';
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is PrayerCategoryModel && other.id == id;
  }

  @override
  int get hashCode => id.hashCode;
} 