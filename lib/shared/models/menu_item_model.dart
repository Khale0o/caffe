class MenuItemModel {
  const MenuItemModel({
    this.id,
    required this.categoryId,
    required this.name,
    required this.price,
    this.description,
    this.isAvailable = true,
    required this.createdAt,
    this.updatedAt,
  });

  final int? id;
  final int categoryId;
  final String name;
  final double price;
  final String? description;
  final bool isAvailable;
  final DateTime createdAt;
  final DateTime? updatedAt;

  factory MenuItemModel.fromMap(Map<String, Object?> map) {
    return MenuItemModel(
      id: map['id'] as int?,
      categoryId: map['category_id'] as int,
      name: map['name'] as String,
      price: (map['price'] as num).toDouble(),
      description: map['description'] as String?,
      isAvailable: ((map['is_available'] as int?) ?? 1) == 1,
      createdAt: DateTime.parse(map['created_at'] as String),
      updatedAt: map['updated_at'] == null
          ? null
          : DateTime.parse(map['updated_at'] as String),
    );
  }

  Map<String, Object?> toMap() {
    return {
      'id': id,
      'category_id': categoryId,
      'name': name,
      'price': price,
      'description': description,
      'is_available': isAvailable ? 1 : 0,
      'created_at': createdAt.toIso8601String(),
      'updated_at': updatedAt?.toIso8601String(),
    };
  }

  MenuItemModel copyWith({
    int? id,
    int? categoryId,
    String? name,
    double? price,
    String? description,
    bool? isAvailable,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return MenuItemModel(
      id: id ?? this.id,
      categoryId: categoryId ?? this.categoryId,
      name: name ?? this.name,
      price: price ?? this.price,
      description: description ?? this.description,
      isAvailable: isAvailable ?? this.isAvailable,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }
}
