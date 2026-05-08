import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_text_styles.dart';
import '../../../core/utils/formatters.dart';
import '../../../core/router/app_router.dart';
import '../../../shared/models/category_model.dart';
import '../../../shared/models/customer_model.dart';
import '../../../shared/models/menu_item_model.dart';
import '../../../shared/repositories/customer_repository.dart';
import '../../../shared/repositories/menu_repository.dart';
import '../../../shared/repositories/settings_repository.dart';
import '../application/pos_checkout_service.dart';
import '../application/pos_order_controller.dart';
import '../domain/pos_cart_item.dart';
import '../domain/pos_order_state.dart';
import 'widgets/invoice_preview_dialog.dart';

final posCustomerProvider = FutureProvider.family<CustomerModel?, int?>((
  ref,
  customerId,
) async {
  if (customerId == null) return null;
  return ref.watch(customerRepositoryProvider).findById(customerId);
});

final posCategoriesProvider = FutureProvider<List<CategoryModel>>((ref) {
  return ref.watch(menuRepositoryProvider).getCategories(activeOnly: true);
});

final posMenuItemsProvider = FutureProvider<List<MenuItemModel>>((ref) {
  return ref.watch(menuRepositoryProvider).getMenuItems(availableOnly: true);
});

final posVatSettingsProvider = FutureProvider<({bool enabled, double percent})>(
  (ref) async {
    final settings = await ref.watch(settingsRepositoryProvider).getAll();
    final enabled = (settings['vat_enabled'] ?? 'true').toLowerCase() == 'true';
    final percent = double.tryParse(settings['vat_percent'] ?? '') ?? 14;
    return (enabled: enabled, percent: percent);
  },
);

enum _PosLayoutMode { desktop, tablet, mobile }

class PosScreen extends ConsumerStatefulWidget {
  const PosScreen({super.key, this.customerId});

  final int? customerId;

  @override
  ConsumerState<PosScreen> createState() => _PosScreenState();
}

class _PosScreenState extends ConsumerState<PosScreen> {
  final _searchController = TextEditingController();
  final _tableController = TextEditingController();
  final _discountController = TextEditingController();

  int? _selectedCategoryId;
  String _paymentMethod = 'كاش';
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    _searchController.addListener(() => setState(() {}));
  }

  @override
  void dispose() {
    _searchController.dispose();
    _tableController.dispose();
    _discountController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    ref.listen(posVatSettingsProvider, (previous, next) {
      next.whenData((settings) {
        ref
            .read(posOrderControllerProvider.notifier)
            .configureVat(enabled: settings.enabled, percent: settings.percent);
      });
    });

    final customerAsync = ref.watch(posCustomerProvider(widget.customerId));
    final categoriesAsync = ref.watch(posCategoriesProvider);
    final menuItemsAsync = ref.watch(posMenuItemsProvider);
    final itemCount = ref.watch(
      posOrderControllerProvider.select((state) => state.itemCount),
    );

    return Scaffold(
      body: SafeArea(
        child: customerAsync.when(
          data: (customer) => LayoutBuilder(
            builder: (context, constraints) {
              final mode = _layoutModeForWidth(constraints.maxWidth);
              final content = _buildContent(
                mode: mode,
                customer: customer,
                categoriesAsync: categoriesAsync,
                menuItemsAsync: menuItemsAsync,
              );

              return Column(
                children: [
                  _Header(
                    customer: customer,
                    itemCount: itemCount,
                    compact: mode == _PosLayoutMode.mobile,
                    onBack: _goBack,
                  ),
                  Expanded(child: content),
                ],
              );
            },
          ),
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (error, stackTrace) => _LoadError(
            message: 'تعذر تحميل بيانات العميل',
            onRetry: () =>
                ref.invalidate(posCustomerProvider(widget.customerId)),
          ),
        ),
      ),
    );
  }

  _PosLayoutMode _layoutModeForWidth(double width) {
    if (width >= 1100) return _PosLayoutMode.desktop;
    if (width >= 700) return _PosLayoutMode.tablet;
    return _PosLayoutMode.mobile;
  }

  Widget _buildContent({
    required _PosLayoutMode mode,
    required CustomerModel? customer,
    required AsyncValue<List<CategoryModel>> categoriesAsync,
    required AsyncValue<List<MenuItemModel>> menuItemsAsync,
  }) {
    final menuSection = _MenuSection(
      layoutMode: mode,
      categoriesAsync: categoriesAsync,
      menuItemsAsync: menuItemsAsync,
      selectedCategoryId: _selectedCategoryId,
      searchText: _searchController.text,
      searchController: _searchController,
      onCategorySelected: (id) => setState(() => _selectedCategoryId = id),
      onItemTap: (item) {
        ref.read(posOrderControllerProvider.notifier).addItem(item);
        _showMessage('تمت إضافة ${item.name}');
      },
    );

    final cartSection = _CartPanel(
      customer: customer,
      tableController: _tableController,
      discountController: _discountController,
      paymentMethod: _paymentMethod,
      onPaymentChanged: (value) => setState(() => _paymentMethod = value),
      onDiscountChanged: (value) {
        final parsed = double.tryParse(value.trim()) ?? 0;
        ref.read(posOrderControllerProvider.notifier).setDiscountValue(parsed);
      },
      onDiscountTypeChanged: (type) {
        ref.read(posOrderControllerProvider.notifier).setDiscountType(type);
        _discountController.text = ref
            .read(posOrderControllerProvider)
            .discountValue
            .toStringAsFixed(0);
      },
      onIncrease: (id) =>
          ref.read(posOrderControllerProvider.notifier).increaseQuantity(id),
      onDecrease: (id) =>
          ref.read(posOrderControllerProvider.notifier).decreaseQuantity(id),
      onClear: () {
        ref.read(posOrderControllerProvider.notifier).clearCart();
        _showMessage('تم تفريغ السلة');
      },
      isSaving: _isSaving,
      onReview: () => _reviewOrder(customer),
    );

    if (mode == _PosLayoutMode.desktop) {
      return Padding(
        padding: const EdgeInsets.fromLTRB(24, 18, 24, 24),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: Scrollbar(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: menuSection,
                ),
              ),
            ),
            const SizedBox(width: 18),
            SizedBox(
              width: 410,
              child: Scrollbar(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: cartSection,
                ),
              ),
            ),
          ],
        ),
      );
    }

    if (mode == _PosLayoutMode.tablet) {
      return SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(18, 14, 18, 24),
        child: Column(
          children: [menuSection, const SizedBox(height: 18), cartSection],
        ),
      );
    }

    return Stack(
      children: [
        SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(12, 12, 12, 96),
          child: menuSection,
        ),
        Positioned(
          left: 12,
          right: 12,
          bottom: 12,
          child: _MobileCartSummaryButton(
            customer: customer,
            tableController: _tableController,
            discountController: _discountController,
            paymentMethod: _paymentMethod,
            onPaymentChanged: (value) => setState(() => _paymentMethod = value),
            onDiscountChanged: (value) {
              final parsed = double.tryParse(value.trim()) ?? 0;
              ref
                  .read(posOrderControllerProvider.notifier)
                  .setDiscountValue(parsed);
            },
            onDiscountTypeChanged: (type) {
              ref
                  .read(posOrderControllerProvider.notifier)
                  .setDiscountType(type);
              _discountController.text = ref
                  .read(posOrderControllerProvider)
                  .discountValue
                  .toStringAsFixed(0);
            },
            onIncrease: (id) => ref
                .read(posOrderControllerProvider.notifier)
                .increaseQuantity(id),
            onDecrease: (id) => ref
                .read(posOrderControllerProvider.notifier)
                .decreaseQuantity(id),
            onClear: () {
              ref.read(posOrderControllerProvider.notifier).clearCart();
              _showMessage('تم تفريغ السلة');
            },
            isSaving: _isSaving,
            onReview: () => _reviewOrder(customer),
          ),
        ),
      ],
    );
  }

  Future<void> _reviewOrder(CustomerModel? customer) async {
    final orderState = ref.read(posOrderControllerProvider);
    if (orderState.items.isEmpty) {
      _showMessage('لا يمكن مراجعة الطلب قبل إضافة أصناف', isError: true);
      return;
    }

    await showDialog<void>(
      context: context,
      builder: (context) {
        return _OrderReviewDialog(
          customerName: customer?.name ?? 'عميل عادي',
          tableNumber: _tableController.text.trim(),
          paymentMethod: _paymentMethod,
          items: orderState.items,
          totals: orderState.totals,
          onConfirmOrder: () => _confirmOrder(customer, orderState),
        );
      },
    );
  }

  Future<void> _confirmOrder(
    CustomerModel? customer,
    PosOrderState orderState,
  ) async {
    Navigator.of(context).pop();

    if (orderState.items.isEmpty) {
      _showMessage('لا يمكن حفظ طلب بدون أصناف', isError: true);
      return;
    }

    setState(() => _isSaving = true);
    try {
      final invoice = await ref
          .read(posCheckoutServiceProvider)
          .saveOrder(
            customer: customer,
            orderState: orderState,
            tableNumber: _tableController.text,
            paymentMethod: _paymentMethod,
          );

      if (!mounted) return;
      ref.read(posOrderControllerProvider.notifier).resetForNextOrder();
      _tableController.clear();
      _discountController.clear();
      setState(() => _paymentMethod = 'كاش');
      if (customer?.id != null) {
        ref.invalidate(posCustomerProvider(customer!.id));
      }
      _showMessage('تم حفظ الطلب بنجاح');

      try {
        await showDialog<void>(
          context: context,
          builder: (context) => InvoicePreviewDialog(invoice: invoice),
        );
      } catch (_) {
        if (!mounted) return;
        _showMessage('تم حفظ الطلب ولكن تعذر فتح الفاتورة', isError: true);
      }
    } on PosCheckoutException catch (error) {
      if (!mounted) return;
      _showMessage(error.message, isError: true);
    } catch (_) {
      if (!mounted) return;
      _showMessage('تعذر حفظ الطلب، حاول مرة أخرى', isError: true);
    } finally {
      if (mounted) {
        setState(() => _isSaving = false);
      }
    }
  }

  void _showMessage(String message, {bool isError = false}) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message, textDirection: TextDirection.rtl),
        backgroundColor: isError ? AppColors.danger : AppColors.success,
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  void _goBack() {
    if (context.canPop()) {
      context.pop();
      return;
    }
    context.go(AppRoutes.welcome);
  }
}

class _Header extends StatelessWidget {
  const _Header({
    required this.customer,
    required this.itemCount,
    required this.compact,
    required this.onBack,
  });

  final CustomerModel? customer;
  final int itemCount;
  final bool compact;
  final VoidCallback onBack;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
      decoration: const BoxDecoration(
        color: AppColors.surface,
        border: Border(bottom: BorderSide(color: AppColors.accentBrown)),
      ),
      child: Row(
        children: [
          IconButton.filledTonal(
            onPressed: onBack,
            icon: const Icon(Icons.arrow_forward_rounded),
            tooltip: 'رجوع',
          ),
          const SizedBox(width: 12),
          const Icon(Icons.local_cafe_rounded, color: AppColors.primaryGold),
          const SizedBox(width: 8),
          if (!compact) ...[
            Text(
              'كافيه النيل',
              style: Theme.of(context).textTheme.headlineSmall,
            ),
            const SizedBox(width: 18),
          ],
          Expanded(
            child: Text(
              compact
                  ? customer?.name ?? 'عميل عادي'
                  : customer == null
                  ? 'العميل: عميل عادي'
                  : 'العميل: ${customer!.name}  |  ${customer!.phone ?? '-'}',
              style: AppTextStyles.muted,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
            decoration: BoxDecoration(
              color: AppColors.primaryGold.withValues(alpha: 0.14),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Text(
              '$itemCount صنف',
              style: AppTextStyles.body.copyWith(color: AppColors.primaryGold),
            ),
          ),
        ],
      ),
    );
  }
}

class _MenuSection extends StatelessWidget {
  const _MenuSection({
    required this.layoutMode,
    required this.categoriesAsync,
    required this.menuItemsAsync,
    required this.selectedCategoryId,
    required this.searchText,
    required this.searchController,
    required this.onCategorySelected,
    required this.onItemTap,
  });

  final _PosLayoutMode layoutMode;
  final AsyncValue<List<CategoryModel>> categoriesAsync;
  final AsyncValue<List<MenuItemModel>> menuItemsAsync;
  final int? selectedCategoryId;
  final String searchText;
  final TextEditingController searchController;
  final ValueChanged<int?> onCategorySelected;
  final ValueChanged<MenuItemModel> onItemTap;

  @override
  Widget build(BuildContext context) {
    return _Panel(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          LayoutBuilder(
            builder: (context, constraints) {
              final compact = constraints.maxWidth < 620;
              final title = Text(
                'اختيار الأصناف',
                style: Theme.of(context).textTheme.headlineSmall,
              );
              final search = TextField(
                controller: searchController,
                decoration: _inputDecoration(
                  label: 'بحث باسم الصنف',
                  icon: Icons.search_rounded,
                ),
              );

              if (compact) {
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [title, const SizedBox(height: 12), search],
                );
              }

              return Row(
                children: [
                  Expanded(child: title),
                  SizedBox(width: 260, child: search),
                ],
              );
            },
          ),
          const SizedBox(height: 16),
          categoriesAsync.when(
            data: (categories) => _CategoryFilter(
              categories: categories,
              selectedCategoryId: selectedCategoryId,
              onSelected: onCategorySelected,
            ),
            loading: () => const LinearProgressIndicator(),
            error: (error, stackTrace) =>
                const Text('تعذر تحميل التصنيفات', style: AppTextStyles.muted),
          ),
          const SizedBox(height: 16),
          menuItemsAsync.when(
            data: (items) {
              final filtered = items.where((item) {
                final matchesCategory =
                    selectedCategoryId == null ||
                    item.categoryId == selectedCategoryId;
                final matchesSearch =
                    searchText.trim().isEmpty ||
                    item.name.contains(searchText.trim());
                return matchesCategory && matchesSearch;
              }).toList();

              return _MenuGrid(
                layoutMode: layoutMode,
                items: filtered,
                categories: categoriesAsync.value ?? const [],
                onItemTap: onItemTap,
              );
            },
            loading: () => const SizedBox(
              height: 280,
              child: Center(child: CircularProgressIndicator()),
            ),
            error: (error, stackTrace) =>
                _LoadError(message: 'تعذر تحميل الأصناف', onRetry: () {}),
          ),
        ],
      ),
    );
  }
}

class _CategoryFilter extends StatelessWidget {
  const _CategoryFilter({
    required this.categories,
    required this.selectedCategoryId,
    required this.onSelected,
  });

  final List<CategoryModel> categories;
  final int? selectedCategoryId;
  final ValueChanged<int?> onSelected;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 48,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        itemCount: categories.length + 1,
        separatorBuilder: (context, index) => const SizedBox(width: 8),
        itemBuilder: (context, index) {
          if (index == 0) {
            return ChoiceChip(
              label: const Text('الكل'),
              selected: selectedCategoryId == null,
              onSelected: (_) => onSelected(null),
            );
          }

          final category = categories[index - 1];
          return ChoiceChip(
            avatar: Text(category.icon ?? ''),
            label: Text(category.name),
            selected: selectedCategoryId == category.id,
            onSelected: (_) => onSelected(category.id),
          );
        },
      ),
    );
  }
}

class _MenuGrid extends StatelessWidget {
  const _MenuGrid({
    required this.layoutMode,
    required this.items,
    required this.categories,
    required this.onItemTap,
  });

  final _PosLayoutMode layoutMode;
  final List<MenuItemModel> items;
  final List<CategoryModel> categories;
  final ValueChanged<MenuItemModel> onItemTap;

  @override
  Widget build(BuildContext context) {
    if (items.isEmpty) {
      return const SizedBox(
        height: 260,
        child: Center(
          child: Text('لا توجد أصناف مطابقة', style: AppTextStyles.muted),
        ),
      );
    }

    return LayoutBuilder(
      builder: (context, constraints) {
        final width = constraints.maxWidth;
        final crossAxisCount = switch (layoutMode) {
          _PosLayoutMode.desktop => width >= 980 ? 4 : 3,
          _PosLayoutMode.tablet => width >= 820 ? 3 : 2,
          _PosLayoutMode.mobile => width < 520 ? 1 : 2,
        };
        final aspectRatio = switch (layoutMode) {
          _PosLayoutMode.desktop => 1.12,
          _PosLayoutMode.tablet => 1.18,
          _PosLayoutMode.mobile => width < 520 ? 1.7 : 1.1,
        };

        return GridView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          itemCount: items.length,
          gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: crossAxisCount,
            crossAxisSpacing: 12,
            mainAxisSpacing: 12,
            childAspectRatio: aspectRatio,
          ),
          itemBuilder: (context, index) {
            final item = items[index];
            final category = categories
                .where((category) => category.id == item.categoryId)
                .firstOrNull;

            return InkWell(
              onTap: () => onItemTap(item),
              borderRadius: BorderRadius.circular(8),
              child: Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: AppColors.surfaceElevated,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(
                    color: AppColors.accentBrown.withValues(alpha: 0.38),
                  ),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Text(
                          category?.icon ?? '☕',
                          style: const TextStyle(fontSize: 28),
                        ),
                        const Spacer(),
                        Flexible(
                          child: Text(
                            AppFormatters.currency(item.price),
                            textAlign: TextAlign.end,
                            overflow: TextOverflow.ellipsis,
                            style: AppTextStyles.body.copyWith(
                              color: AppColors.primaryGold,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    Text(
                      item.name,
                      style: Theme.of(context).textTheme.headlineSmall,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 8),
                    Expanded(
                      child: Text(
                        item.description?.trim().isNotEmpty == true
                            ? item.description!
                            : 'صنف متاح للبيع',
                        style: AppTextStyles.muted,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    const SizedBox(height: 10),
                    const Align(
                      alignment: Alignment.centerLeft,
                      child: Icon(
                        Icons.add_circle_rounded,
                        color: AppColors.primaryGold,
                        size: 28,
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }
}

class _CartPanel extends StatelessWidget {
  const _CartPanel({
    required this.customer,
    required this.tableController,
    required this.discountController,
    required this.paymentMethod,
    required this.onPaymentChanged,
    required this.onDiscountChanged,
    required this.onDiscountTypeChanged,
    required this.onIncrease,
    required this.onDecrease,
    required this.onClear,
    required this.isSaving,
    required this.onReview,
  });

  final CustomerModel? customer;
  final TextEditingController tableController;
  final TextEditingController discountController;
  final String paymentMethod;
  final ValueChanged<String> onPaymentChanged;
  final ValueChanged<String> onDiscountChanged;
  final ValueChanged<DiscountType> onDiscountTypeChanged;
  final ValueChanged<int> onIncrease;
  final ValueChanged<int> onDecrease;
  final VoidCallback onClear;
  final bool isSaving;
  final VoidCallback onReview;

  @override
  Widget build(BuildContext context) {
    return Consumer(
      builder: (context, ref, child) {
        final orderState = ref.watch(posOrderControllerProvider);
        return _CartPanelBody(
          customer: customer,
          orderState: orderState,
          tableController: tableController,
          discountController: discountController,
          paymentMethod: paymentMethod,
          onPaymentChanged: onPaymentChanged,
          onDiscountChanged: onDiscountChanged,
          onDiscountTypeChanged: onDiscountTypeChanged,
          onIncrease: onIncrease,
          onDecrease: onDecrease,
          onClear: onClear,
          isSaving: isSaving,
          onReview: onReview,
        );
      },
    );
  }
}

class _CartPanelBody extends StatelessWidget {
  const _CartPanelBody({
    required this.customer,
    required this.orderState,
    required this.tableController,
    required this.discountController,
    required this.paymentMethod,
    required this.onPaymentChanged,
    required this.onDiscountChanged,
    required this.onDiscountTypeChanged,
    required this.onIncrease,
    required this.onDecrease,
    required this.onClear,
    required this.isSaving,
    required this.onReview,
  });

  final CustomerModel? customer;
  final PosOrderState orderState;
  final TextEditingController tableController;
  final TextEditingController discountController;
  final String paymentMethod;
  final ValueChanged<String> onPaymentChanged;
  final ValueChanged<String> onDiscountChanged;
  final ValueChanged<DiscountType> onDiscountTypeChanged;
  final ValueChanged<int> onIncrease;
  final ValueChanged<int> onDecrease;
  final VoidCallback onClear;
  final bool isSaving;
  final VoidCallback onReview;

  @override
  Widget build(BuildContext context) {
    final totals = orderState.totals;

    return _Panel(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  'السلة',
                  style: Theme.of(context).textTheme.headlineSmall,
                ),
              ),
              TextButton.icon(
                onPressed: orderState.items.isEmpty ? null : onClear,
                icon: const Icon(Icons.delete_sweep_rounded),
                label: const Text('تفريغ'),
              ),
            ],
          ),
          const SizedBox(height: 12),
          if (orderState.items.isEmpty)
            const _EmptyCart()
          else
            ...orderState.items.map(
              (item) => _CartItemTile(
                item: item,
                onIncrease: () => onIncrease(item.menuItemId),
                onDecrease: () => onDecrease(item.menuItemId),
              ),
            ),
          const Divider(height: 28),
          TextField(
            controller: tableController,
            decoration: _inputDecoration(
              label: 'رقم الترابيزة (اختياري)',
              icon: Icons.table_restaurant_rounded,
            ),
          ),
          const SizedBox(height: 12),
          DropdownButtonFormField<String>(
            initialValue: paymentMethod,
            decoration: _inputDecoration(
              label: 'طريقة الدفع',
              icon: Icons.payments_rounded,
            ),
            items: const [
              DropdownMenuItem(value: 'كاش', child: Text('كاش')),
              DropdownMenuItem(value: 'فيزا', child: Text('فيزا')),
              DropdownMenuItem(
                value: 'فودافون كاش',
                child: Text('فودافون كاش'),
              ),
              DropdownMenuItem(value: 'إنستا باي', child: Text('إنستا باي')),
            ],
            onChanged: (value) {
              if (value != null) onPaymentChanged(value);
            },
          ),
          const SizedBox(height: 12),
          SegmentedButton<DiscountType>(
            segments: DiscountType.values
                .map(
                  (type) => ButtonSegment<DiscountType>(
                    value: type,
                    label: Text(type.label),
                  ),
                )
                .toList(),
            selected: {orderState.discountType},
            onSelectionChanged: (value) => onDiscountTypeChanged(value.first),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: discountController,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            inputFormatters: [
              FilteringTextInputFormatter.allow(RegExp(r'[0-9.]')),
            ],
            onChanged: onDiscountChanged,
            decoration: _inputDecoration(
              label: 'الخصم',
              icon: Icons.discount_rounded,
            ),
          ),
          const SizedBox(height: 16),
          _TotalsSection(totals: totals),
          const SizedBox(height: 16),
          FilledButton.icon(
            onPressed: isSaving ? null : onReview,
            icon: isSaving
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.fact_check_rounded),
            label: Text(isSaving ? 'جاري حفظ الطلب' : 'مراجعة الطلب'),
          ),
        ],
      ),
    );
  }
}

class _MobileCartSummaryButton extends ConsumerWidget {
  const _MobileCartSummaryButton({
    required this.customer,
    required this.tableController,
    required this.discountController,
    required this.paymentMethod,
    required this.onPaymentChanged,
    required this.onDiscountChanged,
    required this.onDiscountTypeChanged,
    required this.onIncrease,
    required this.onDecrease,
    required this.onClear,
    required this.isSaving,
    required this.onReview,
  });

  final CustomerModel? customer;
  final TextEditingController tableController;
  final TextEditingController discountController;
  final String paymentMethod;
  final ValueChanged<String> onPaymentChanged;
  final ValueChanged<String> onDiscountChanged;
  final ValueChanged<DiscountType> onDiscountTypeChanged;
  final ValueChanged<int> onIncrease;
  final ValueChanged<int> onDecrease;
  final VoidCallback onClear;
  final bool isSaving;
  final VoidCallback onReview;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final summary = ref.watch(
      posOrderControllerProvider.select(
        (state) => (count: state.itemCount, total: state.totals.grandTotal),
      ),
    );

    return FilledButton(
      onPressed: () => _openCartSheet(context),
      style: FilledButton.styleFrom(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      ),
      child: Row(
        children: [
          const Icon(Icons.shopping_cart_rounded),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              summary.count == 0
                  ? 'السلة فارغة'
                  : '${summary.count} صنف | ${AppFormatters.currency(summary.total)}',
              overflow: TextOverflow.ellipsis,
            ),
          ),
          const Icon(Icons.keyboard_arrow_up_rounded),
        ],
      ),
    );
  }

  Future<void> _openCartSheet(BuildContext context) {
    return showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppColors.surface,
      builder: (context) {
        return SafeArea(
          child: DraggableScrollableSheet(
            expand: false,
            initialChildSize: 0.82,
            minChildSize: 0.45,
            maxChildSize: 0.95,
            builder: (context, scrollController) {
              return SingleChildScrollView(
                controller: scrollController,
                padding: const EdgeInsets.all(16),
                child: _CartPanel(
                  customer: customer,
                  tableController: tableController,
                  discountController: discountController,
                  paymentMethod: paymentMethod,
                  onPaymentChanged: onPaymentChanged,
                  onDiscountChanged: onDiscountChanged,
                  onDiscountTypeChanged: onDiscountTypeChanged,
                  onIncrease: onIncrease,
                  onDecrease: onDecrease,
                  onClear: onClear,
                  isSaving: isSaving,
                  onReview: onReview,
                ),
              );
            },
          ),
        );
      },
    );
  }
}

class _CartItemTile extends StatelessWidget {
  const _CartItemTile({
    required this.item,
    required this.onIncrease,
    required this.onDecrease,
  });

  final PosCartItem item;
  final VoidCallback onIncrease;
  final VoidCallback onDecrease;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.background.withValues(alpha: 0.48),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(item.name, style: Theme.of(context).textTheme.bodyLarge),
                const SizedBox(height: 4),
                Text(
                  AppFormatters.currency(item.total),
                  style: AppTextStyles.muted,
                ),
              ],
            ),
          ),
          IconButton.filledTonal(
            onPressed: onDecrease,
            icon: const Icon(Icons.remove_rounded),
          ),
          SizedBox(
            width: 42,
            child: Text(
              item.quantity.toString(),
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.bodyLarge,
            ),
          ),
          IconButton.filled(
            onPressed: onIncrease,
            icon: const Icon(Icons.add_rounded),
          ),
        ],
      ),
    );
  }
}

class _TotalsSection extends StatelessWidget {
  const _TotalsSection({required this.totals});

  final PosTotals totals;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        _TotalRow(label: 'الإجمالي الفرعي', value: totals.subtotal),
        _TotalRow(label: 'الخصم', value: totals.discountAmount),
        _TotalRow(label: 'بعد الخصم', value: totals.afterDiscount),
        _TotalRow(label: 'ضريبة القيمة المضافة', value: totals.vatAmount),
        const Divider(height: 22),
        _TotalRow(
          label: 'الإجمالي النهائي',
          value: totals.grandTotal,
          isGrand: true,
        ),
      ],
    );
  }
}

class _TotalRow extends StatelessWidget {
  const _TotalRow({
    required this.label,
    required this.value,
    this.isGrand = false,
  });

  final String label;
  final double value;
  final bool isGrand;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          Expanded(
            child: Text(
              label,
              style: isGrand
                  ? Theme.of(context).textTheme.headlineSmall
                  : AppTextStyles.muted,
            ),
          ),
          Text(
            AppFormatters.currency(value),
            style:
                (isGrand
                        ? Theme.of(context).textTheme.headlineSmall
                        : Theme.of(context).textTheme.bodyLarge)
                    ?.copyWith(
                      color: isGrand ? AppColors.primaryGold : AppColors.text,
                      fontWeight: isGrand ? FontWeight.w800 : FontWeight.w600,
                    ),
          ),
        ],
      ),
    );
  }
}

class _OrderReviewDialog extends StatelessWidget {
  const _OrderReviewDialog({
    required this.customerName,
    required this.tableNumber,
    required this.paymentMethod,
    required this.items,
    required this.totals,
    required this.onConfirmOrder,
  });

  final String customerName;
  final String tableNumber;
  final String paymentMethod;
  final List<PosCartItem> items;
  final PosTotals totals;
  final VoidCallback onConfirmOrder;

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.sizeOf(context);
    return AlertDialog(
      backgroundColor: AppColors.surface,
      title: const Text('مراجعة الطلب'),
      content: ConstrainedBox(
        constraints: BoxConstraints(
          maxWidth: size.width * 0.9,
          maxHeight: size.height * 0.65,
        ),
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text('العميل: $customerName'),
              if (tableNumber.isNotEmpty) Text('الترابيزة: $tableNumber'),
              Text('طريقة الدفع: $paymentMethod'),
              const Divider(height: 24),
              ...items.map(
                (item) => Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: Row(
                    children: [
                      Expanded(child: Text('${item.name} × ${item.quantity}')),
                      Text(AppFormatters.currency(item.total)),
                    ],
                  ),
                ),
              ),
              const Divider(height: 24),
              _TotalRow(label: 'الإجمالي الفرعي', value: totals.subtotal),
              _TotalRow(label: 'الخصم', value: totals.discountAmount),
              _TotalRow(label: 'الضريبة', value: totals.vatAmount),
              _TotalRow(
                label: 'الإجمالي النهائي',
                value: totals.grandTotal,
                isGrand: true,
              ),
            ],
          ),
        ),
      ),
      actions: [
        OutlinedButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('رجوع للتعديل'),
        ),
        FilledButton(
          onPressed: onConfirmOrder,
          child: const Text('تأكيد الطلب'),
        ),
      ],
    );
  }
}

class _EmptyCart extends StatelessWidget {
  const _EmptyCart();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: AppColors.background.withValues(alpha: 0.45),
        borderRadius: BorderRadius.circular(8),
      ),
      child: const Text(
        'اضغط على أي صنف لإضافته إلى السلة',
        style: AppTextStyles.muted,
        textAlign: TextAlign.center,
      ),
    );
  }
}

class _Panel extends StatelessWidget {
  const _Panel({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: AppColors.accentBrown.withValues(alpha: 0.4)),
      ),
      child: child,
    );
  }
}

class _LoadError extends StatelessWidget {
  const _LoadError({required this.message, required this.onRetry});

  final String message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(message, style: Theme.of(context).textTheme.bodyLarge),
          const SizedBox(height: 12),
          OutlinedButton.icon(
            onPressed: onRetry,
            icon: const Icon(Icons.refresh_rounded),
            label: const Text('إعادة المحاولة'),
          ),
        ],
      ),
    );
  }
}

InputDecoration _inputDecoration({
  required String label,
  required IconData icon,
}) {
  return InputDecoration(
    labelText: label,
    prefixIcon: Icon(icon),
    filled: true,
    fillColor: AppColors.background.withValues(alpha: 0.55),
    border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
    enabledBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(8),
      borderSide: BorderSide(
        color: AppColors.accentBrown.withValues(alpha: 0.55),
      ),
    ),
    focusedBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(8),
      borderSide: const BorderSide(color: AppColors.primaryGold, width: 1.4),
    ),
  );
}
