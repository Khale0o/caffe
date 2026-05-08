class CategoryModel {
  const CategoryModel({
    this.id,
    required this.name,
    this.icon,
    this.color,
    this.sortOrder = 0,
    this.isActive = true,
  });

  final int? id;
  final String name;
  final String? icon;
  final String? color;
  final int sortOrder;
  final bool isActive;

  factory CategoryModel.fromMap(Map<String, Object?> map) {
    return CategoryModel(
      id: map['id'] as int?,
      name: map['name'] as String,
      icon: map['icon'] as String?,
      color: map['color'] as String?,
      sortOrder: (map['sort_order'] as int?) ?? 0,
      isActive: ((map['is_active'] as int?) ?? 1) == 1,
    );
  }

  Map<String, Object?> toMap() {
    return {
      'id': id,
      'name': name,
      'icon': icon,
      'color': color,
      'sort_order': sortOrder,
      'is_active': isActive ? 1 : 0,
    };
  }

  CategoryModel copyWith({
    int? id,
    String? name,
    String? icon,
    String? color,
    int? sortOrder,
    bool? isActive,
  }) {
    return CategoryModel(
      id: id ?? this.id,
      name: name ?? this.name,
      icon: icon ?? this.icon,
      color: color ?? this.color,
      sortOrder: sortOrder ?? this.sortOrder,
      isActive: isActive ?? this.isActive,
    );
  }
}
