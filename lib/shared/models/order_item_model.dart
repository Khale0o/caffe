class OrderItemModel {
  const OrderItemModel({
    this.id,
    required this.orderId,
    this.menuItemId,
    required this.itemName,
    required this.quantity,
    required this.unitPrice,
    required this.total,
  });

  final int? id;
  final int orderId;
  final int? menuItemId;
  final String itemName;
  final int quantity;
  final double unitPrice;
  final double total;

  factory OrderItemModel.fromMap(Map<String, Object?> map) {
    return OrderItemModel(
      id: map['id'] as int?,
      orderId: map['order_id'] as int,
      menuItemId: map['menu_item_id'] as int?,
      itemName: map['item_name'] as String,
      quantity: map['quantity'] as int,
      unitPrice: (map['unit_price'] as num).toDouble(),
      total: (map['total'] as num).toDouble(),
    );
  }

  Map<String, Object?> toMap() {
    return {
      'id': id,
      'order_id': orderId,
      'menu_item_id': menuItemId,
      'item_name': itemName,
      'quantity': quantity,
      'unit_price': unitPrice,
      'total': total,
    };
  }

  OrderItemModel copyWith({
    int? id,
    int? orderId,
    int? menuItemId,
    String? itemName,
    int? quantity,
    double? unitPrice,
    double? total,
  }) {
    return OrderItemModel(
      id: id ?? this.id,
      orderId: orderId ?? this.orderId,
      menuItemId: menuItemId ?? this.menuItemId,
      itemName: itemName ?? this.itemName,
      quantity: quantity ?? this.quantity,
      unitPrice: unitPrice ?? this.unitPrice,
      total: total ?? this.total,
    );
  }
}
