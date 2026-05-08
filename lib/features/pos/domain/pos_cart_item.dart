import '../../../shared/models/menu_item_model.dart';

class PosCartItem {
  const PosCartItem({
    required this.menuItemId,
    required this.name,
    required this.unitPrice,
    required this.quantity,
  });

  final int menuItemId;
  final String name;
  final double unitPrice;
  final int quantity;

  double get total => unitPrice * quantity;

  factory PosCartItem.fromMenuItem(MenuItemModel item) {
    return PosCartItem(
      menuItemId: item.id ?? 0,
      name: item.name,
      unitPrice: item.price,
      quantity: 1,
    );
  }

  PosCartItem copyWith({
    int? menuItemId,
    String? name,
    double? unitPrice,
    int? quantity,
  }) {
    return PosCartItem(
      menuItemId: menuItemId ?? this.menuItemId,
      name: name ?? this.name,
      unitPrice: unitPrice ?? this.unitPrice,
      quantity: quantity ?? this.quantity,
    );
  }
}
