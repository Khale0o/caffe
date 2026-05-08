class OrderModel {
  const OrderModel({
    this.id,
    required this.orderNumber,
    this.customerId,
    this.customerName,
    this.customerPhone,
    this.tableNumber,
    required this.paymentMethod,
    required this.subtotal,
    this.discountValue = 0,
    this.discountType = 'percent',
    this.discountAmount = 0,
    this.taxAmount = 0,
    required this.total,
    this.status = 'completed',
    required this.createdAt,
  });

  final int? id;
  final int orderNumber;
  final int? customerId;
  final String? customerName;
  final String? customerPhone;
  final String? tableNumber;
  final String paymentMethod;
  final double subtotal;
  final double discountValue;
  final String discountType;
  final double discountAmount;
  final double taxAmount;
  final double total;
  final String status;
  final DateTime createdAt;

  factory OrderModel.fromMap(Map<String, Object?> map) {
    return OrderModel(
      id: map['id'] as int?,
      orderNumber: map['order_number'] as int,
      customerId: map['customer_id'] as int?,
      customerName: map['customer_name'] as String?,
      customerPhone: map['customer_phone'] as String?,
      tableNumber: map['table_number'] as String?,
      paymentMethod: map['payment_method'] as String,
      subtotal: (map['subtotal'] as num).toDouble(),
      discountValue: ((map['discount_value'] as num?) ?? 0).toDouble(),
      discountType: (map['discount_type'] as String?) ?? 'percent',
      discountAmount: ((map['discount_amount'] as num?) ?? 0).toDouble(),
      taxAmount: ((map['tax_amount'] as num?) ?? 0).toDouble(),
      total: (map['total'] as num).toDouble(),
      status: (map['status'] as String?) ?? 'completed',
      createdAt: DateTime.parse(map['created_at'] as String),
    );
  }

  Map<String, Object?> toMap() {
    return {
      'id': id,
      'order_number': orderNumber,
      'customer_id': customerId,
      'customer_name': customerName,
      'customer_phone': customerPhone,
      'table_number': tableNumber,
      'payment_method': paymentMethod,
      'subtotal': subtotal,
      'discount_value': discountValue,
      'discount_type': discountType,
      'discount_amount': discountAmount,
      'tax_amount': taxAmount,
      'total': total,
      'status': status,
      'created_at': createdAt.toIso8601String(),
    };
  }

  OrderModel copyWith({
    int? id,
    int? orderNumber,
    int? customerId,
    String? customerName,
    String? customerPhone,
    String? tableNumber,
    String? paymentMethod,
    double? subtotal,
    double? discountValue,
    String? discountType,
    double? discountAmount,
    double? taxAmount,
    double? total,
    String? status,
    DateTime? createdAt,
  }) {
    return OrderModel(
      id: id ?? this.id,
      orderNumber: orderNumber ?? this.orderNumber,
      customerId: customerId ?? this.customerId,
      customerName: customerName ?? this.customerName,
      customerPhone: customerPhone ?? this.customerPhone,
      tableNumber: tableNumber ?? this.tableNumber,
      paymentMethod: paymentMethod ?? this.paymentMethod,
      subtotal: subtotal ?? this.subtotal,
      discountValue: discountValue ?? this.discountValue,
      discountType: discountType ?? this.discountType,
      discountAmount: discountAmount ?? this.discountAmount,
      taxAmount: taxAmount ?? this.taxAmount,
      total: total ?? this.total,
      status: status ?? this.status,
      createdAt: createdAt ?? this.createdAt,
    );
  }
}
