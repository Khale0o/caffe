import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/router/app_router.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_text_styles.dart';
import '../../../core/utils/formatters.dart';
import '../../../shared/models/category_model.dart';
import '../../../shared/models/menu_item_model.dart';
import '../../../shared/repositories/menu_repository.dart';
import '../../../shared/repositories/settings_repository.dart';
import '../../pos/presentation/pos_screen.dart';
import '../application/admin_providers.dart';
import '../application/admin_validators.dart';

class AdminScreen extends ConsumerStatefulWidget {
  const AdminScreen({super.key});

  @override
  ConsumerState<AdminScreen> createState() => _AdminScreenState();
}

class _AdminScreenState extends ConsumerState<AdminScreen> {
  final _pinController = TextEditingController();
  bool _isUnlocked = false;
  bool _isVerifyingPin = false;

  @override
  void dispose() {
    _pinController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (!_isUnlocked) {
      return _PinGate(
        controller: _pinController,
        isVerifying: _isVerifyingPin,
        onBack: _goBack,
        onSubmit: _verifyPin,
      );
    }

    return DefaultTabController(
      length: 3,
      child: Scaffold(
        appBar: AppBar(
          leading: IconButton(
            onPressed: _goBack,
            icon: const Icon(Icons.arrow_forward_rounded),
            tooltip: 'رجوع',
          ),
          title: const Text('لوحة الإدارة'),
          bottom: const TabBar(
            tabs: [
              Tab(text: 'الأقسام', icon: Icon(Icons.category_rounded)),
              Tab(text: 'الأصناف', icon: Icon(Icons.local_cafe_rounded)),
              Tab(text: 'إعدادات الكافيه', icon: Icon(Icons.settings_rounded)),
            ],
          ),
        ),
        body: const TabBarView(
          children: [_CategoriesPanel(), _MenuItemsPanel(), _SettingsPanel()],
        ),
      ),
    );
  }

  Future<void> _verifyPin() async {
    if (_isVerifyingPin) return;
    FocusScope.of(context).unfocus();

    final enteredPin = _pinController.text.trim();
    if (enteredPin.isEmpty) {
      _showMessage('من فضلك أدخل الرقم السري', isError: true);
      return;
    }

    setState(() => _isVerifyingPin = true);
    try {
      final savedPin = await ref.read(adminPinProvider.future);
      if (!mounted) return;
      if (enteredPin == savedPin) {
        setState(() => _isUnlocked = true);
        _pinController.clear();
        return;
      }

      _showMessage('الرقم السري غير صحيح', isError: true);
    } finally {
      if (mounted) setState(() => _isVerifyingPin = false);
    }
  }

  void _goBack() {
    if (context.canPop()) {
      context.pop();
      return;
    }
    context.go(AppRoutes.welcome);
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
}

class _PinGate extends ConsumerWidget {
  const _PinGate({
    required this.controller,
    required this.isVerifying,
    required this.onBack,
    required this.onSubmit,
  });

  final TextEditingController controller;
  final bool isVerifying;
  final VoidCallback onBack;
  final VoidCallback onSubmit;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final pinAsync = ref.watch(adminPinProvider);

    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          onPressed: onBack,
          icon: const Icon(Icons.arrow_forward_rounded),
          tooltip: 'رجوع',
        ),
        title: const Text('دخول الإدارة'),
      ),
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(20),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 460),
            child: _AdminPanel(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const Icon(
                    Icons.admin_panel_settings_rounded,
                    color: AppColors.primaryGold,
                    size: 52,
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'أدخل الرقم السري لإدارة المنيو',
                    style: Theme.of(context).textTheme.headlineSmall,
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 18),
                  TextField(
                    controller: controller,
                    obscureText: true,
                    keyboardType: TextInputType.number,
                    inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                    textInputAction: TextInputAction.done,
                    enabled: !pinAsync.isLoading && !isVerifying,
                    onSubmitted: (_) => onSubmit(),
                    decoration: _adminInputDecoration(
                      label: 'الرقم السري',
                      icon: Icons.lock_rounded,
                    ),
                  ),
                  const SizedBox(height: 18),
                  FilledButton.icon(
                    onPressed: pinAsync.isLoading || isVerifying
                        ? null
                        : onSubmit,
                    icon: pinAsync.isLoading || isVerifying
                        ? const SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Icon(Icons.login_rounded),
                    label: const Text('دخول'),
                  ),
                  if (pinAsync.hasError) ...[
                    const SizedBox(height: 12),
                    const Text(
                      'تعذر تحميل إعدادات الدخول',
                      style: TextStyle(color: AppColors.danger),
                      textAlign: TextAlign.center,
                    ),
                  ],
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _CategoriesPanel extends ConsumerWidget {
  const _CategoriesPanel();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final categoriesAsync = ref.watch(adminCategoriesProvider);

    return _AdminScroll(
      child: _AdminPanel(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _SectionHeader(
              title: 'إدارة الأقسام',
              actionLabel: 'إضافة قسم',
              icon: Icons.add_rounded,
              onAction: () => _openCategoryDialog(context, ref),
            ),
            const SizedBox(height: 16),
            categoriesAsync.when(
              data: (categories) {
                if (categories.isEmpty) {
                  return const _EmptyState(message: 'لا توجد أقسام حتى الآن');
                }
                return ListView.separated(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  itemCount: categories.length,
                  separatorBuilder: (context, index) =>
                      const SizedBox(height: 10),
                  itemBuilder: (context, index) {
                    final category = categories[index];
                    return _CategoryTile(category: category);
                  },
                );
              },
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (error, stackTrace) =>
                  const _LoadError(message: 'تعذر تحميل الأقسام'),
            ),
          ],
        ),
      ),
    );
  }
}

class _CategoryTile extends ConsumerWidget {
  const _CategoryTile({required this.category});

  final CategoryModel category;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return _AdminTile(
      leading: Text(
        category.icon?.isNotEmpty == true ? category.icon! : '☕',
        style: const TextStyle(fontSize: 26),
      ),
      title: category.name,
      subtitle:
          'ترتيب: ${category.sortOrder} | لون: ${category.color?.isNotEmpty == true ? category.color : '-'}',
      trailing: Wrap(
        spacing: 6,
        runSpacing: 6,
        alignment: WrapAlignment.end,
        children: [
          _StatusPill(
            label: category.isActive ? 'نشط' : 'متوقف',
            active: category.isActive,
          ),
          IconButton.filledTonal(
            onPressed: () => _openCategoryDialog(context, ref, category),
            icon: const Icon(Icons.edit_rounded),
            tooltip: 'تعديل',
          ),
          IconButton.filledTonal(
            onPressed: () => _toggleCategory(context, ref, category),
            icon: Icon(
              category.isActive
                  ? Icons.visibility_off_rounded
                  : Icons.visibility_rounded,
            ),
            tooltip: category.isActive ? 'إيقاف' : 'تفعيل',
          ),
          IconButton.filledTonal(
            onPressed: () => _deleteCategory(context, ref, category),
            icon: const Icon(Icons.delete_outline_rounded),
            tooltip: 'حذف',
          ),
        ],
      ),
    );
  }
}

class _MenuItemsPanel extends ConsumerStatefulWidget {
  const _MenuItemsPanel();

  @override
  ConsumerState<_MenuItemsPanel> createState() => _MenuItemsPanelState();
}

class _MenuItemsPanelState extends ConsumerState<_MenuItemsPanel> {
  final _searchController = TextEditingController();

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final categoriesAsync = ref.watch(adminCategoriesProvider);
    final itemsAsync = ref.watch(adminMenuItemsProvider);
    final selectedCategoryId = ref.watch(adminMenuCategoryFilterProvider);

    return _AdminScroll(
      child: _AdminPanel(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _SectionHeader(
              title: 'إدارة الأصناف',
              actionLabel: 'إضافة صنف',
              icon: Icons.add_rounded,
              onAction: () => _openMenuItemDialog(context, ref),
            ),
            const SizedBox(height: 14),
            LayoutBuilder(
              builder: (context, constraints) {
                final compact = constraints.maxWidth < 760;
                final search = TextField(
                  controller: _searchController,
                  onChanged: (value) =>
                      ref.read(adminMenuSearchProvider.notifier).value = value,
                  decoration: _adminInputDecoration(
                    label: 'بحث باسم الصنف',
                    icon: Icons.search_rounded,
                  ),
                );
                final filter = categoriesAsync.when(
                  data: (categories) => DropdownButtonFormField<int?>(
                    initialValue: selectedCategoryId,
                    decoration: _adminInputDecoration(
                      label: 'فلترة حسب القسم',
                      icon: Icons.category_rounded,
                    ),
                    items: [
                      const DropdownMenuItem<int?>(
                        value: null,
                        child: Text('كل الأقسام'),
                      ),
                      ...categories.map(
                        (category) => DropdownMenuItem<int?>(
                          value: category.id,
                          child: Text(category.name),
                        ),
                      ),
                    ],
                    onChanged: (value) =>
                        ref
                                .read(adminMenuCategoryFilterProvider.notifier)
                                .value =
                            value,
                  ),
                  loading: () => const LinearProgressIndicator(),
                  error: (error, stackTrace) =>
                      const Text('تعذر تحميل الأقسام'),
                );

                if (compact) {
                  return Column(
                    children: [search, const SizedBox(height: 10), filter],
                  );
                }

                return Row(
                  children: [
                    Expanded(child: search),
                    const SizedBox(width: 12),
                    SizedBox(width: 280, child: filter),
                  ],
                );
              },
            ),
            const SizedBox(height: 16),
            itemsAsync.when(
              data: (items) {
                if (items.isEmpty) {
                  return const _EmptyState(
                    message: 'لا توجد أصناف مطابقة للبحث الحالي',
                  );
                }
                return ListView.separated(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  itemCount: items.length,
                  separatorBuilder: (context, index) =>
                      const SizedBox(height: 10),
                  itemBuilder: (context, index) =>
                      _MenuItemTile(item: items[index]),
                );
              },
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (error, stackTrace) =>
                  const _LoadError(message: 'تعذر تحميل الأصناف'),
            ),
          ],
        ),
      ),
    );
  }
}

class _MenuItemTile extends ConsumerWidget {
  const _MenuItemTile({required this.item});

  final MenuItemModel item;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final categories = ref.watch(adminCategoriesProvider).value ?? const [];
    final categoryName = categories
        .where((category) => category.id == item.categoryId)
        .map((category) => category.name)
        .firstOrNull;

    return _AdminTile(
      leading: const Icon(
        Icons.local_cafe_rounded,
        color: AppColors.primaryGold,
        size: 28,
      ),
      title: item.name,
      subtitle:
          '${categoryName ?? 'قسم غير معروف'} | ${AppFormatters.currency(item.price)}${item.description?.isNotEmpty == true ? ' | ${item.description}' : ''}',
      trailing: Wrap(
        spacing: 6,
        runSpacing: 6,
        alignment: WrapAlignment.end,
        children: [
          _StatusPill(
            label: item.isAvailable ? 'متاح' : 'غير متاح',
            active: item.isAvailable,
          ),
          IconButton.filledTonal(
            onPressed: () => _openMenuItemDialog(context, ref, item),
            icon: const Icon(Icons.edit_rounded),
            tooltip: 'تعديل',
          ),
          IconButton.filledTonal(
            onPressed: () => _toggleMenuItem(context, ref, item),
            icon: Icon(
              item.isAvailable
                  ? Icons.visibility_off_rounded
                  : Icons.visibility_rounded,
            ),
            tooltip: item.isAvailable ? 'جعله غير متاح' : 'جعله متاح',
          ),
          IconButton.filledTonal(
            onPressed: () => _deleteMenuItem(context, ref, item),
            icon: const Icon(Icons.delete_outline_rounded),
            tooltip: 'حذف',
          ),
        ],
      ),
    );
  }
}

class _SettingsPanel extends ConsumerStatefulWidget {
  const _SettingsPanel();

  @override
  ConsumerState<_SettingsPanel> createState() => _SettingsPanelState();
}

class _SettingsPanelState extends ConsumerState<_SettingsPanel> {
  final _formKey = GlobalKey<FormState>();
  final _cafeNameController = TextEditingController();
  final _phoneController = TextEditingController();
  final _addressController = TextEditingController();
  final _vatPercentController = TextEditingController();
  final _footerController = TextEditingController();
  final _pinController = TextEditingController();
  bool _vatEnabled = true;
  bool _didLoad = false;
  bool _isSaving = false;

  @override
  void dispose() {
    _cafeNameController.dispose();
    _phoneController.dispose();
    _addressController.dispose();
    _vatPercentController.dispose();
    _footerController.dispose();
    _pinController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final settingsAsync = ref.watch(adminSettingsProvider);

    return _AdminScroll(
      child: _AdminPanel(
        child: settingsAsync.when(
          data: (settings) {
            _loadOnce(settings);
            return Form(
              key: _formKey,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text(
                    'إعدادات الكافيه',
                    style: Theme.of(context).textTheme.headlineSmall,
                  ),
                  const SizedBox(height: 16),
                  _ResponsiveFormGrid(
                    children: [
                      TextFormField(
                        controller: _cafeNameController,
                        textInputAction: TextInputAction.next,
                        decoration: _adminInputDecoration(
                          label: 'اسم الكافيه',
                          icon: Icons.store_rounded,
                        ),
                        validator: (value) => AdminValidators.requiredText(
                          value,
                          'اسم الكافيه مطلوب',
                        ),
                      ),
                      TextFormField(
                        controller: _phoneController,
                        keyboardType: TextInputType.phone,
                        textInputAction: TextInputAction.next,
                        decoration: _adminInputDecoration(
                          label: 'رقم التليفون',
                          icon: Icons.phone_rounded,
                        ),
                      ),
                      TextFormField(
                        controller: _addressController,
                        textInputAction: TextInputAction.next,
                        decoration: _adminInputDecoration(
                          label: 'العنوان',
                          icon: Icons.location_on_rounded,
                        ),
                      ),
                      TextFormField(
                        controller: _footerController,
                        textInputAction: TextInputAction.next,
                        decoration: _adminInputDecoration(
                          label: 'نص نهاية الفاتورة',
                          icon: Icons.receipt_long_rounded,
                        ),
                      ),
                      TextFormField(
                        controller: _vatPercentController,
                        keyboardType: const TextInputType.numberWithOptions(
                          decimal: true,
                        ),
                        textInputAction: TextInputAction.next,
                        inputFormatters: [
                          FilteringTextInputFormatter.allow(RegExp(r'[0-9.]')),
                        ],
                        decoration: _adminInputDecoration(
                          label: 'نسبة الضريبة',
                          icon: Icons.percent_rounded,
                        ),
                        validator: (value) {
                          return AdminValidators.vatPercent(value);
                        },
                      ),
                      TextFormField(
                        controller: _pinController,
                        obscureText: true,
                        keyboardType: TextInputType.number,
                        textInputAction: TextInputAction.done,
                        inputFormatters: [
                          FilteringTextInputFormatter.digitsOnly,
                        ],
                        onFieldSubmitted: (_) => _saveSettings(),
                        decoration: _adminInputDecoration(
                          label: 'الرقم السري للإدارة',
                          icon: Icons.lock_rounded,
                        ),
                        validator: (value) => AdminValidators.requiredText(
                          value,
                          'الرقم السري مطلوب',
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  SwitchListTile(
                    value: _vatEnabled,
                    onChanged: (value) => setState(() => _vatEnabled = value),
                    title: const Text('تفعيل ضريبة القيمة المضافة'),
                    activeThumbColor: AppColors.primaryGold,
                    contentPadding: EdgeInsets.zero,
                  ),
                  const SizedBox(height: 16),
                  Align(
                    alignment: Alignment.centerLeft,
                    child: FilledButton.icon(
                      onPressed: _isSaving ? null : _saveSettings,
                      icon: _isSaving
                          ? const SizedBox(
                              width: 18,
                              height: 18,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : const Icon(Icons.save_rounded),
                      label: const Text('حفظ الإعدادات'),
                    ),
                  ),
                ],
              ),
            );
          },
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (error, stackTrace) =>
              const _LoadError(message: 'تعذر تحميل الإعدادات'),
        ),
      ),
    );
  }

  void _loadOnce(Map<String, String?> settings) {
    if (_didLoad) return;
    _cafeNameController.text = settings['cafe_name'] ?? 'كافيه النيل';
    _phoneController.text = settings['cafe_phone'] ?? '';
    _addressController.text = settings['cafe_address'] ?? '';
    _vatPercentController.text = settings['vat_percent'] ?? '14';
    _footerController.text = settings['invoice_footer'] ?? '';
    _pinController.text = settings['admin_pin'] ?? '1234';
    _vatEnabled = (settings['vat_enabled'] ?? 'true').toLowerCase() == 'true';
    _didLoad = true;
  }

  Future<void> _saveSettings() async {
    if (_isSaving) return;
    FocusScope.of(context).unfocus();

    if (!_formKey.currentState!.validate()) return;
    setState(() => _isSaving = true);
    try {
      await ref.read(settingsRepositoryProvider).setValues({
        'cafe_name': _cafeNameController.text.trim(),
        'cafe_phone': _phoneController.text.trim(),
        'cafe_address': _addressController.text.trim(),
        'vat_enabled': _vatEnabled.toString(),
        'vat_percent': _vatPercentController.text.trim(),
        'invoice_footer': _footerController.text.trim(),
        'admin_pin': _pinController.text.trim(),
      });
      ref.invalidate(adminSettingsProvider);
      ref.invalidate(adminPinProvider);
      ref.invalidate(posVatSettingsProvider);
      if (!mounted) return;
      _showMessage(context, 'تم حفظ إعدادات الكافيه');
    } catch (_) {
      if (!mounted) return;
      _showMessage(context, 'تعذر حفظ الإعدادات', isError: true);
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }
}

class _SectionHeader extends StatelessWidget {
  const _SectionHeader({
    required this.title,
    required this.actionLabel,
    required this.icon,
    required this.onAction,
  });

  final String title;
  final String actionLabel;
  final IconData icon;
  final VoidCallback onAction;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final compact = constraints.maxWidth < 540;
        final titleWidget = Text(
          title,
          style: Theme.of(context).textTheme.headlineSmall,
        );
        final action = FilledButton.icon(
          onPressed: onAction,
          icon: Icon(icon),
          label: Text(actionLabel),
        );

        if (compact) {
          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [titleWidget, const SizedBox(height: 12), action],
          );
        }

        return Row(
          children: [
            Expanded(child: titleWidget),
            action,
          ],
        );
      },
    );
  }
}

class _ResponsiveFormGrid extends StatelessWidget {
  const _ResponsiveFormGrid({required this.children});

  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final columns = constraints.maxWidth >= 900 ? 2 : 1;
        return GridView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          itemCount: children.length,
          gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: columns,
            crossAxisSpacing: 12,
            mainAxisSpacing: 12,
            childAspectRatio: columns == 1 ? 5.6 : 5.2,
          ),
          itemBuilder: (context, index) => children[index],
        );
      },
    );
  }
}

class _AdminScroll extends StatelessWidget {
  const _AdminScroll({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    final viewInsets = MediaQuery.viewInsetsOf(context);
    return SingleChildScrollView(
      keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
      padding: EdgeInsets.fromLTRB(18, 18, 18, 18 + viewInsets.bottom),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 1180),
          child: child,
        ),
      ),
    );
  }
}

class _AdminPanel extends StatelessWidget {
  const _AdminPanel({required this.child});

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

class _AdminTile extends StatelessWidget {
  const _AdminTile({
    required this.leading,
    required this.title,
    required this.subtitle,
    required this.trailing,
  });

  final Widget leading;
  final String title;
  final String subtitle;
  final Widget trailing;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.background.withValues(alpha: 0.42),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: AppColors.accentBrown.withValues(alpha: 0.2)),
      ),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final compact = constraints.maxWidth < 680;
          final details = Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              SizedBox(width: 42, child: Center(child: leading)),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Text(title, style: Theme.of(context).textTheme.bodyLarge),
                    const SizedBox(height: 4),
                    Text(
                      subtitle,
                      style: AppTextStyles.muted,
                      maxLines: compact ? 3 : 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
            ],
          );

          if (compact) {
            return Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                details,
                const SizedBox(height: 12),
                Align(alignment: Alignment.centerLeft, child: trailing),
              ],
            );
          }

          return Row(
            children: [
              Expanded(child: details),
              const SizedBox(width: 12),
              trailing,
            ],
          );
        },
      ),
    );
  }
}

class _StatusPill extends StatelessWidget {
  const _StatusPill({required this.label, required this.active});

  final String label;
  final bool active;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: (active ? AppColors.success : AppColors.danger).withValues(
          alpha: 0.14,
        ),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(
        label,
        style: AppTextStyles.body.copyWith(
          color: active ? AppColors.success : AppColors.danger,
        ),
      ),
    );
  }
}

class _EmptyState extends StatelessWidget {
  const _EmptyState({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: AppColors.background.withValues(alpha: 0.45),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(
        message,
        style: AppTextStyles.muted,
        textAlign: TextAlign.center,
      ),
    );
  }
}

class _LoadError extends StatelessWidget {
  const _LoadError({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    return Text(
      message,
      style: AppTextStyles.body.copyWith(color: AppColors.danger),
      textAlign: TextAlign.center,
    );
  }
}

Future<void> _openCategoryDialog(
  BuildContext context,
  WidgetRef ref, [
  CategoryModel? category,
]) async {
  final formKey = GlobalKey<FormState>();
  final nameController = TextEditingController(text: category?.name ?? '');
  final iconController = TextEditingController(text: category?.icon ?? '');
  final colorController = TextEditingController(text: category?.color ?? '');
  final sortController = TextEditingController(
    text: (category?.sortOrder ?? 0).toString(),
  );
  var isActive = category?.isActive ?? true;
  var isSaving = false;

  await showDialog<void>(
    context: context,
    builder: (dialogContext) => StatefulBuilder(
      builder: (context, setDialogState) {
        return AlertDialog(
          backgroundColor: AppColors.surface,
          title: Text(category == null ? 'إضافة قسم' : 'تعديل قسم'),
          content: ConstrainedBox(
            constraints: BoxConstraints(
              maxWidth: 520,
              maxHeight: MediaQuery.sizeOf(context).height * 0.72,
            ),
            child: SingleChildScrollView(
              child: Form(
                key: formKey,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    TextFormField(
                      controller: nameController,
                      textInputAction: TextInputAction.next,
                      decoration: _adminInputDecoration(
                        label: 'اسم القسم',
                        icon: Icons.category_rounded,
                      ),
                      validator: (value) => AdminValidators.requiredText(
                        value,
                        'اسم القسم مطلوب',
                      ),
                    ),
                    const SizedBox(height: 12),
                    TextFormField(
                      controller: iconController,
                      textInputAction: TextInputAction.next,
                      decoration: _adminInputDecoration(
                        label: 'الأيقونة',
                        icon: Icons.emoji_symbols_rounded,
                      ),
                    ),
                    const SizedBox(height: 12),
                    TextFormField(
                      controller: colorController,
                      textInputAction: TextInputAction.next,
                      decoration: _adminInputDecoration(
                        label: 'اللون',
                        icon: Icons.palette_rounded,
                      ),
                    ),
                    const SizedBox(height: 12),
                    TextFormField(
                      controller: sortController,
                      keyboardType: TextInputType.number,
                      textInputAction: TextInputAction.done,
                      inputFormatters: [
                        FilteringTextInputFormatter.allow(RegExp(r'-?[0-9]')),
                      ],
                      decoration: _adminInputDecoration(
                        label: 'ترتيب العرض',
                        icon: Icons.sort_rounded,
                      ),
                    ),
                    const SizedBox(height: 8),
                    SwitchListTile(
                      value: isActive,
                      onChanged: (value) =>
                          setDialogState(() => isActive = value),
                      title: const Text('القسم نشط'),
                      contentPadding: EdgeInsets.zero,
                      activeThumbColor: AppColors.primaryGold,
                    ),
                  ],
                ),
              ),
            ),
          ),
          actions: [
            OutlinedButton(
              onPressed: isSaving
                  ? null
                  : () => Navigator.of(dialogContext).pop(),
              child: const Text('إلغاء'),
            ),
            FilledButton(
              onPressed: isSaving
                  ? null
                  : () async {
                      if (!formKey.currentState!.validate()) return;
                      FocusScope.of(context).unfocus();
                      setDialogState(() => isSaving = true);
                      final repository = ref.read(menuRepositoryProvider);
                      final model = CategoryModel(
                        id: category?.id,
                        name: nameController.text.trim(),
                        icon: iconController.text.trim().isEmpty
                            ? null
                            : iconController.text.trim(),
                        color: colorController.text.trim().isEmpty
                            ? null
                            : colorController.text.trim(),
                        sortOrder:
                            int.tryParse(sortController.text.trim()) ?? 0,
                        isActive: isActive,
                      );
                      try {
                        if (category == null) {
                          await repository.createCategory(model);
                        } else {
                          await repository.updateCategory(model);
                        }
                        _invalidateMenuData(ref);
                        if (dialogContext.mounted) {
                          Navigator.of(dialogContext).pop();
                        }
                        if (context.mounted) {
                          _showMessage(
                            context,
                            category == null
                                ? 'تمت إضافة القسم'
                                : 'تم تعديل القسم',
                          );
                        }
                      } catch (_) {
                        if (context.mounted) {
                          _showMessage(
                            context,
                            'تعذر حفظ القسم',
                            isError: true,
                          );
                        }
                      } finally {
                        if (dialogContext.mounted) {
                          setDialogState(() => isSaving = false);
                        }
                      }
                    },
              child: isSaving
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Text('حفظ'),
            ),
          ],
        );
      },
    ),
  );
}

Future<void> _toggleCategory(
  BuildContext context,
  WidgetRef ref,
  CategoryModel category,
) async {
  if (category.id == null) return;
  try {
    await ref
        .read(menuRepositoryProvider)
        .setCategoryActive(category.id!, !category.isActive);
    _invalidateMenuData(ref);
    if (context.mounted) {
      _showMessage(
        context,
        category.isActive ? 'تم إيقاف القسم' : 'تم تفعيل القسم',
      );
    }
  } catch (_) {
    if (context.mounted) {
      _showMessage(context, 'تعذر تحديث حالة القسم', isError: true);
    }
  }
}

Future<void> _deleteCategory(
  BuildContext context,
  WidgetRef ref,
  CategoryModel category,
) async {
  if (category.id == null) return;
  final repository = ref.read(menuRepositoryProvider);
  final hasItems = await repository.categoryHasMenuItems(category.id!);
  if (!context.mounted) return;
  if (hasItems) {
    _showMessage(
      context,
      'لا يمكن حذف قسم يحتوي على أصناف. يمكنك إيقافه بدلاً من ذلك.',
      isError: true,
    );
    return;
  }

  final confirmed = await _confirm(
    context,
    title: 'حذف القسم',
    message: 'هل تريد حذف هذا القسم؟',
  );
  if (confirmed != true) return;

  try {
    await repository.deleteCategory(category.id!);
    _invalidateMenuData(ref);
    if (context.mounted) _showMessage(context, 'تم حذف القسم');
  } catch (_) {
    if (context.mounted) {
      _showMessage(context, 'تعذر حذف القسم', isError: true);
    }
  }
}

Future<void> _openMenuItemDialog(
  BuildContext context,
  WidgetRef ref, [
  MenuItemModel? item,
]) async {
  final categories = await ref.read(adminCategoriesProvider.future);
  if (!context.mounted) return;
  if (categories.isEmpty) {
    _showMessage(context, 'أضف قسماً أولاً قبل إضافة الأصناف', isError: true);
    return;
  }

  final formKey = GlobalKey<FormState>();
  final nameController = TextEditingController(text: item?.name ?? '');
  final priceController = TextEditingController(
    text: item == null ? '' : item.price.toStringAsFixed(2),
  );
  final descriptionController = TextEditingController(
    text: item?.description ?? '',
  );
  var selectedCategoryId = item?.categoryId ?? categories.first.id;
  var isAvailable = item?.isAvailable ?? true;
  var isSaving = false;

  await showDialog<void>(
    context: context,
    builder: (dialogContext) => StatefulBuilder(
      builder: (context, setDialogState) {
        return AlertDialog(
          backgroundColor: AppColors.surface,
          title: Text(item == null ? 'إضافة صنف' : 'تعديل صنف'),
          content: ConstrainedBox(
            constraints: BoxConstraints(
              maxWidth: 560,
              maxHeight: MediaQuery.sizeOf(context).height * 0.76,
            ),
            child: SingleChildScrollView(
              child: Form(
                key: formKey,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    DropdownButtonFormField<int>(
                      initialValue: selectedCategoryId,
                      decoration: _adminInputDecoration(
                        label: 'القسم',
                        icon: Icons.category_rounded,
                      ),
                      items: categories
                          .map(
                            (category) => DropdownMenuItem<int>(
                              value: category.id,
                              child: Text(category.name),
                            ),
                          )
                          .toList(),
                      onChanged: (value) =>
                          setDialogState(() => selectedCategoryId = value),
                      validator: AdminValidators.requiredCategory,
                    ),
                    const SizedBox(height: 12),
                    TextFormField(
                      controller: nameController,
                      textInputAction: TextInputAction.next,
                      decoration: _adminInputDecoration(
                        label: 'اسم الصنف',
                        icon: Icons.local_cafe_rounded,
                      ),
                      validator: (value) => AdminValidators.requiredText(
                        value,
                        'اسم الصنف مطلوب',
                      ),
                    ),
                    const SizedBox(height: 12),
                    TextFormField(
                      controller: priceController,
                      keyboardType: const TextInputType.numberWithOptions(
                        decimal: true,
                      ),
                      textInputAction: TextInputAction.next,
                      inputFormatters: [
                        FilteringTextInputFormatter.allow(RegExp(r'[0-9.]')),
                      ],
                      decoration: _adminInputDecoration(
                        label: 'السعر',
                        icon: Icons.payments_rounded,
                      ),
                      validator: (value) {
                        return AdminValidators.positivePrice(value);
                      },
                    ),
                    const SizedBox(height: 12),
                    TextFormField(
                      controller: descriptionController,
                      minLines: 2,
                      maxLines: 3,
                      textInputAction: TextInputAction.done,
                      onFieldSubmitted: (_) => FocusScope.of(context).unfocus(),
                      decoration: _adminInputDecoration(
                        label: 'الوصف',
                        icon: Icons.notes_rounded,
                      ),
                    ),
                    const SizedBox(height: 8),
                    SwitchListTile(
                      value: isAvailable,
                      onChanged: (value) =>
                          setDialogState(() => isAvailable = value),
                      title: const Text('الصنف متاح للبيع'),
                      contentPadding: EdgeInsets.zero,
                      activeThumbColor: AppColors.primaryGold,
                    ),
                  ],
                ),
              ),
            ),
          ),
          actions: [
            OutlinedButton(
              onPressed: isSaving
                  ? null
                  : () => Navigator.of(dialogContext).pop(),
              child: const Text('إلغاء'),
            ),
            FilledButton(
              onPressed: isSaving
                  ? null
                  : () async {
                      if (!formKey.currentState!.validate()) return;
                      FocusScope.of(context).unfocus();
                      setDialogState(() => isSaving = true);
                      final now = DateTime.now();
                      final model = MenuItemModel(
                        id: item?.id,
                        categoryId: selectedCategoryId!,
                        name: nameController.text.trim(),
                        price: double.parse(priceController.text.trim()),
                        description: descriptionController.text.trim().isEmpty
                            ? null
                            : descriptionController.text.trim(),
                        isAvailable: isAvailable,
                        createdAt: item?.createdAt ?? now,
                        updatedAt: item == null ? null : now,
                      );
                      try {
                        final repository = ref.read(menuRepositoryProvider);
                        if (item == null) {
                          await repository.createMenuItem(model);
                        } else {
                          await repository.updateMenuItem(model);
                        }
                        _invalidateMenuData(ref);
                        if (dialogContext.mounted) {
                          Navigator.of(dialogContext).pop();
                        }
                        if (context.mounted) {
                          _showMessage(
                            context,
                            item == null ? 'تمت إضافة الصنف' : 'تم تعديل الصنف',
                          );
                        }
                      } catch (_) {
                        if (context.mounted) {
                          _showMessage(
                            context,
                            'تعذر حفظ الصنف',
                            isError: true,
                          );
                        }
                      } finally {
                        if (dialogContext.mounted) {
                          setDialogState(() => isSaving = false);
                        }
                      }
                    },
              child: isSaving
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Text('حفظ'),
            ),
          ],
        );
      },
    ),
  );
}

Future<void> _toggleMenuItem(
  BuildContext context,
  WidgetRef ref,
  MenuItemModel item,
) async {
  if (item.id == null) return;
  try {
    await ref
        .read(menuRepositoryProvider)
        .setMenuItemAvailable(item.id!, !item.isAvailable);
    _invalidateMenuData(ref);
    if (context.mounted) {
      _showMessage(
        context,
        item.isAvailable ? 'تم جعل الصنف غير متاح' : 'تم جعل الصنف متاح',
      );
    }
  } catch (_) {
    if (context.mounted) {
      _showMessage(context, 'تعذر تحديث حالة الصنف', isError: true);
    }
  }
}

Future<void> _deleteMenuItem(
  BuildContext context,
  WidgetRef ref,
  MenuItemModel item,
) async {
  if (item.id == null) return;
  final repository = ref.read(menuRepositoryProvider);
  final hasOrders = await repository.menuItemHasOrders(item.id!);
  if (!context.mounted) return;
  if (hasOrders) {
    _showMessage(
      context,
      'هذا الصنف مستخدم في طلبات سابقة. اجعله غير متاح بدلاً من حذفه.',
      isError: true,
    );
    return;
  }

  final confirmed = await _confirm(
    context,
    title: 'حذف الصنف',
    message: 'هل تريد حذف هذا الصنف؟',
  );
  if (confirmed != true) return;

  try {
    await repository.deleteMenuItem(item.id!);
    _invalidateMenuData(ref);
    if (context.mounted) _showMessage(context, 'تم حذف الصنف');
  } catch (_) {
    if (context.mounted) {
      _showMessage(context, 'تعذر حذف الصنف', isError: true);
    }
  }
}

Future<bool?> _confirm(
  BuildContext context, {
  required String title,
  required String message,
}) {
  return showDialog<bool>(
    context: context,
    builder: (context) => AlertDialog(
      backgroundColor: AppColors.surface,
      title: Text(title),
      content: Text(message),
      actions: [
        OutlinedButton(
          onPressed: () => Navigator.of(context).pop(false),
          child: const Text('إلغاء'),
        ),
        FilledButton(
          onPressed: () => Navigator.of(context).pop(true),
          child: const Text('تأكيد'),
        ),
      ],
    ),
  );
}

void _invalidateMenuData(WidgetRef ref) {
  ref.invalidate(adminCategoriesProvider);
  ref.invalidate(adminMenuItemsProvider);
  ref.invalidate(posCategoriesProvider);
  ref.invalidate(posMenuItemsProvider);
}

void _showMessage(
  BuildContext context,
  String message, {
  bool isError = false,
}) {
  ScaffoldMessenger.of(context).showSnackBar(
    SnackBar(
      content: Text(message, textDirection: TextDirection.rtl),
      backgroundColor: isError ? AppColors.danger : AppColors.success,
      behavior: SnackBarBehavior.floating,
    ),
  );
}

InputDecoration _adminInputDecoration({
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
