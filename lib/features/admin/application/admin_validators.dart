class AdminValidators {
  const AdminValidators._();

  static String? requiredText(String? value, String message) {
    return value == null || value.trim().isEmpty ? message : null;
  }

  static String? positivePrice(String? value) {
    final price = double.tryParse(value?.trim() ?? '');
    if (price == null) return 'السعر مطلوب';
    if (price <= 0) return 'السعر يجب أن يكون أكبر من صفر';
    return null;
  }

  static String? vatPercent(String? value) {
    final percent = double.tryParse(value?.trim() ?? '') ?? -1;
    if (percent < 0 || percent > 100) {
      return 'نسبة الضريبة يجب أن تكون بين 0 و 100';
    }
    return null;
  }

  static String? requiredCategory(int? value) {
    return value == null ? 'القسم مطلوب' : null;
  }
}
