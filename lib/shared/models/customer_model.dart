class CustomerModel {
  const CustomerModel({
    this.id,
    required this.name,
    this.phone,
    this.address,
    this.notes,
    this.orderCount = 0,
    required this.createdAt,
    this.updatedAt,
  });

  final int? id;
  final String name;
  final String? phone;
  final String? address;
  final String? notes;
  final int orderCount;
  final DateTime createdAt;
  final DateTime? updatedAt;

  factory CustomerModel.fromMap(Map<String, Object?> map) {
    return CustomerModel(
      id: map['id'] as int?,
      name: map['name'] as String,
      phone: map['phone'] as String?,
      address: map['address'] as String?,
      notes: map['notes'] as String?,
      orderCount: (map['order_count'] as int?) ?? 0,
      createdAt: DateTime.parse(map['created_at'] as String),
      updatedAt: map['updated_at'] == null
          ? null
          : DateTime.parse(map['updated_at'] as String),
    );
  }

  Map<String, Object?> toMap() {
    return {
      'id': id,
      'name': name,
      'phone': phone,
      'address': address,
      'notes': notes,
      'order_count': orderCount,
      'created_at': createdAt.toIso8601String(),
      'updated_at': updatedAt?.toIso8601String(),
    };
  }

  CustomerModel copyWith({
    int? id,
    String? name,
    String? phone,
    String? address,
    String? notes,
    int? orderCount,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return CustomerModel(
      id: id ?? this.id,
      name: name ?? this.name,
      phone: phone ?? this.phone,
      address: address ?? this.address,
      notes: notes ?? this.notes,
      orderCount: orderCount ?? this.orderCount,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }
}
