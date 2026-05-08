import 'pos_cart_item.dart';

enum DiscountType {
  percent,
  fixed;

  String get storageValue => switch (this) {
    DiscountType.percent => 'percent',
    DiscountType.fixed => 'fixed',
  };

  String get label => switch (this) {
    DiscountType.percent => 'نسبة %',
    DiscountType.fixed => 'مبلغ ج',
  };
}

class PosTotals {
  const PosTotals({
    required this.subtotal,
    required this.discountAmount,
    required this.afterDiscount,
    required this.vatAmount,
    required this.grandTotal,
  });

  final double subtotal;
  final double discountAmount;
  final double afterDiscount;
  final double vatAmount;
  final double grandTotal;
}

class PosOrderState {
  const PosOrderState({
    this.items = const [],
    this.discountValue = 0,
    this.discountType = DiscountType.percent,
    this.vatEnabled = true,
    this.vatPercent = 14,
  });

  final List<PosCartItem> items;
  final double discountValue;
  final DiscountType discountType;
  final bool vatEnabled;
  final double vatPercent;

  int get itemCount => items.fold(0, (sum, item) => sum + item.quantity);

  double get subtotal => items.fold(0, (sum, item) => sum + item.total);

  PosTotals get totals => calculateTotals(
    subtotal: subtotal,
    discountValue: discountValue,
    discountType: discountType,
    vatEnabled: vatEnabled,
    vatPercent: vatPercent,
  );

  PosOrderState copyWith({
    List<PosCartItem>? items,
    double? discountValue,
    DiscountType? discountType,
    bool? vatEnabled,
    double? vatPercent,
  }) {
    return PosOrderState(
      items: items ?? this.items,
      discountValue: discountValue ?? this.discountValue,
      discountType: discountType ?? this.discountType,
      vatEnabled: vatEnabled ?? this.vatEnabled,
      vatPercent: vatPercent ?? this.vatPercent,
    );
  }

  static PosTotals calculateTotals({
    required double subtotal,
    required double discountValue,
    required DiscountType discountType,
    required bool vatEnabled,
    required double vatPercent,
  }) {
    final safeSubtotal = subtotal < 0 ? 0.0 : subtotal;
    final safeDiscountValue = discountValue < 0 ? 0.0 : discountValue;
    final discountAmount = switch (discountType) {
      DiscountType.percent =>
        safeSubtotal *
            (safeDiscountValue > 100 ? 100 : safeDiscountValue) /
            100,
      DiscountType.fixed =>
        safeDiscountValue > safeSubtotal ? safeSubtotal : safeDiscountValue,
    };
    final afterDiscount = (safeSubtotal - discountAmount).clamp(
      0.0,
      double.infinity,
    );
    final safeVatPercent = vatPercent < 0 ? 0.0 : vatPercent;
    final vatAmount = vatEnabled ? afterDiscount * safeVatPercent / 100 : 0.0;
    final grandTotal = (afterDiscount + vatAmount).clamp(0.0, double.infinity);

    return PosTotals(
      subtotal: safeSubtotal,
      discountAmount: discountAmount,
      afterDiscount: afterDiscount,
      vatAmount: vatAmount,
      grandTotal: grandTotal,
    );
  }
}
