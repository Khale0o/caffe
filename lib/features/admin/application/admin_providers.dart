import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../shared/models/category_model.dart';
import '../../../shared/models/menu_item_model.dart';
import '../../../shared/repositories/menu_repository.dart';
import '../../../shared/repositories/settings_repository.dart';

final adminPinProvider = FutureProvider<String>((ref) async {
  return await ref.watch(settingsRepositoryProvider).getValue('admin_pin') ??
      '1234';
});

final adminCategoriesProvider = FutureProvider<List<CategoryModel>>((ref) {
  return ref.watch(menuRepositoryProvider).getCategories();
});

final adminMenuCategoryFilterProvider =
    NotifierProvider<AdminMenuCategoryFilter, int?>(
      AdminMenuCategoryFilter.new,
    );

class AdminMenuCategoryFilter extends Notifier<int?> {
  @override
  int? build() => null;

  set value(int? categoryId) => state = categoryId;
}

final adminMenuSearchProvider = NotifierProvider<AdminMenuSearch, String>(
  AdminMenuSearch.new,
);

class AdminMenuSearch extends Notifier<String> {
  @override
  String build() => '';

  set value(String searchText) => state = searchText;
}

final adminMenuItemsProvider = FutureProvider<List<MenuItemModel>>((ref) {
  final categoryId = ref.watch(adminMenuCategoryFilterProvider);
  final searchText = ref.watch(adminMenuSearchProvider);
  return ref
      .watch(menuRepositoryProvider)
      .getMenuItems(categoryId: categoryId, searchText: searchText);
});

final adminSettingsProvider = FutureProvider<Map<String, String?>>((ref) {
  return ref.watch(settingsRepositoryProvider).getAll();
});
