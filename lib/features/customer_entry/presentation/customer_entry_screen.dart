import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/router/app_router.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_text_styles.dart';
import '../../../shared/models/customer_model.dart';
import '../../../shared/repositories/customer_repository.dart';

class CustomerEntryScreen extends ConsumerStatefulWidget {
  const CustomerEntryScreen({super.key});

  @override
  ConsumerState<CustomerEntryScreen> createState() =>
      _CustomerEntryScreenState();
}

class _CustomerEntryScreenState extends ConsumerState<CustomerEntryScreen> {
  final _searchController = TextEditingController();
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _phoneController = TextEditingController();
  final _addressController = TextEditingController();
  final _notesController = TextEditingController();

  CustomerModel? _foundCustomer;
  bool _showCreateForm = false;
  bool _isSearching = false;
  bool _isSaving = false;

  @override
  void dispose() {
    _searchController.dispose();
    _nameController.dispose();
    _phoneController.dispose();
    _addressController.dispose();
    _notesController.dispose();
    super.dispose();
  }

  Future<void> _searchCustomer() async {
    if (_isSearching || _isSaving) return;
    FocusScope.of(context).unfocus();

    final phone = _searchController.text.trim();
    if (phone.isEmpty) {
      _showMessage('ادخل رقم التليفون للبحث', isError: true);
      return;
    }

    setState(() {
      _isSearching = true;
      _foundCustomer = null;
      _showCreateForm = false;
    });

    try {
      final customer = await ref
          .read(customerRepositoryProvider)
          .findByPhone(phone);
      if (!mounted) return;

      setState(() {
        _foundCustomer = customer;
        _showCreateForm = customer == null;
        _phoneController.text = phone;
      });

      if (customer == null) {
        _showMessage('العميل غير مسجل، يمكنك إضافته الآن');
      }
    } catch (_) {
      if (!mounted) return;
      _showMessage('تعذر البحث عن العميل، حاول مرة أخرى', isError: true);
    } finally {
      if (mounted) {
        setState(() => _isSearching = false);
      }
    }
  }

  Future<void> _createCustomer() async {
    if (_isSaving || _isSearching) return;
    FocusScope.of(context).unfocus();

    if (!(_formKey.currentState?.validate() ?? false)) return;

    setState(() => _isSaving = true);
    final now = DateTime.now();
    final customer = CustomerModel(
      name: _nameController.text.trim(),
      phone: _phoneController.text.trim(),
      address: _emptyToNull(_addressController.text),
      notes: _emptyToNull(_notesController.text),
      createdAt: now,
    );

    try {
      final id = await ref.read(customerRepositoryProvider).create(customer);
      if (!mounted) return;
      _showMessage('تم تسجيل العميل بنجاح');
      _goToPos(customerId: id);
    } catch (_) {
      if (!mounted) return;
      _showMessage(
        'تعذر حفظ العميل، تأكد أن رقم التليفون غير مسجل',
        isError: true,
      );
    } finally {
      if (mounted) {
        setState(() => _isSaving = false);
      }
    }
  }

  String? _emptyToNull(String value) {
    final trimmed = value.trim();
    return trimmed.isEmpty ? null : trimmed;
  }

  void _goToPos({int? customerId}) {
    final route = customerId == null
        ? AppRoutes.pos
        : '${AppRoutes.pos}?customerId=$customerId';
    context.go(route);
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

  @override
  Widget build(BuildContext context) {
    final viewInsets = MediaQuery.viewInsetsOf(context);
    return Scaffold(
      appBar: AppBar(
        title: const Text('بيانات العميل'),
        leading: IconButton(
          onPressed: () => context.go(AppRoutes.welcome),
          icon: const Icon(Icons.arrow_forward_rounded),
          tooltip: 'رجوع',
        ),
      ),
      body: SafeArea(
        child: LayoutBuilder(
          builder: (context, constraints) {
            final isWide = constraints.maxWidth >= 900;
            return SingleChildScrollView(
              padding: EdgeInsets.symmetric(
                horizontal: isWide ? 48 : 20,
                vertical: isWide ? 32 : 20,
              ).copyWith(bottom: (isWide ? 32 : 20) + viewInsets.bottom),
              keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
              child: Center(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 1120),
                  child: isWide
                      ? Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Expanded(
                              child: _buildSearchPanel(isBusy: _isSearching),
                            ),
                            const SizedBox(width: 18),
                            Expanded(child: _buildResultPanel()),
                          ],
                        )
                      : Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            _buildSearchPanel(isBusy: _isSearching),
                            const SizedBox(height: 18),
                            _buildResultPanel(),
                          ],
                        ),
                ),
              ),
            );
          },
        ),
      ),
    );
  }

  Widget _buildSearchPanel({required bool isBusy}) {
    return _Panel(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const _SectionHeader(
            icon: Icons.phone_android_rounded,
            title: 'البحث عن عميل',
            subtitle: 'ابحث برقم التليفون قبل فتح الطلب',
          ),
          const SizedBox(height: 22),
          TextField(
            controller: _searchController,
            keyboardType: TextInputType.phone,
            textInputAction: TextInputAction.search,
            inputFormatters: [
              FilteringTextInputFormatter.allow(RegExp(r'[0-9+\-\s]')),
            ],
            onSubmitted: (_) => _searchCustomer(),
            decoration: _inputDecoration(
              label: 'رقم التليفون',
              icon: Icons.search_rounded,
            ),
          ),
          const SizedBox(height: 14),
          FilledButton.icon(
            onPressed: isBusy ? null : _searchCustomer,
            icon: isBusy
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.manage_search_rounded),
            label: const Text('بحث'),
          ),
          const SizedBox(height: 12),
          OutlinedButton.icon(
            onPressed: isBusy ? null : () => _goToPos(),
            icon: const Icon(Icons.person_outline_rounded),
            label: const Text('متابعة كعميل عادي'),
          ),
        ],
      ),
    );
  }

  Widget _buildResultPanel() {
    if (_foundCustomer != null) {
      return _ExistingCustomerCard(
        customer: _foundCustomer!,
        onContinue: () => _goToPos(customerId: _foundCustomer!.id),
      );
    }

    if (_showCreateForm) {
      return _CreateCustomerForm(
        formKey: _formKey,
        nameController: _nameController,
        phoneController: _phoneController,
        addressController: _addressController,
        notesController: _notesController,
        isSaving: _isSaving,
        onSave: _createCustomer,
      );
    }

    return const _Panel(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _SectionHeader(
            icon: Icons.badge_rounded,
            title: 'جاهز لتسجيل الطلب',
            subtitle:
                'سيظهر العميل هنا عند العثور عليه، أو نموذج تسجيل سريع إذا كان جديداً',
          ),
          SizedBox(height: 18),
          Text(
            'يمكنك أيضاً المتابعة كعميل عادي للطلبات السريعة بدون حفظ بيانات عميل.',
            style: AppTextStyles.muted,
          ),
        ],
      ),
    );
  }
}

class _ExistingCustomerCard extends StatelessWidget {
  const _ExistingCustomerCard({
    required this.customer,
    required this.onContinue,
  });

  final CustomerModel customer;
  final VoidCallback onContinue;

  @override
  Widget build(BuildContext context) {
    return _Panel(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const _SectionHeader(
            icon: Icons.verified_user_rounded,
            title: 'تم العثور على العميل',
            subtitle: 'راجع البيانات ثم تابع فتح الطلب',
          ),
          const SizedBox(height: 20),
          _InfoRow(label: 'الاسم', value: customer.name),
          _InfoRow(label: 'رقم التليفون', value: customer.phone ?? '-'),
          _InfoRow(label: 'العنوان', value: customer.address ?? '-'),
          _InfoRow(label: 'الملاحظات', value: customer.notes ?? '-'),
          _InfoRow(
            label: 'عدد الطلبات السابقة',
            value: customer.orderCount.toString(),
          ),
          const SizedBox(height: 18),
          FilledButton.icon(
            onPressed: onContinue,
            icon: const Icon(Icons.arrow_back_rounded),
            label: const Text('متابعة الطلب'),
          ),
        ],
      ),
    );
  }
}

class _CreateCustomerForm extends StatelessWidget {
  const _CreateCustomerForm({
    required this.formKey,
    required this.nameController,
    required this.phoneController,
    required this.addressController,
    required this.notesController,
    required this.isSaving,
    required this.onSave,
  });

  final GlobalKey<FormState> formKey;
  final TextEditingController nameController;
  final TextEditingController phoneController;
  final TextEditingController addressController;
  final TextEditingController notesController;
  final bool isSaving;
  final VoidCallback onSave;

  @override
  Widget build(BuildContext context) {
    return _Panel(
      child: Form(
        key: formKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const _SectionHeader(
              icon: Icons.person_add_alt_1_rounded,
              title: 'تسجيل عميل جديد',
              subtitle: 'أدخل البيانات الأساسية ثم تابع الطلب',
            ),
            const SizedBox(height: 20),
            TextFormField(
              controller: nameController,
              textInputAction: TextInputAction.next,
              decoration: _inputDecoration(
                label: 'الاسم',
                icon: Icons.person_rounded,
              ),
              validator: (value) {
                if (value == null || value.trim().isEmpty) {
                  return 'اسم العميل مطلوب';
                }
                return null;
              },
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: phoneController,
              keyboardType: TextInputType.phone,
              textInputAction: TextInputAction.next,
              inputFormatters: [
                FilteringTextInputFormatter.allow(RegExp(r'[0-9+\-\s]')),
              ],
              decoration: _inputDecoration(
                label: 'رقم التليفون',
                icon: Icons.phone_rounded,
              ),
              validator: (value) {
                if (value == null || value.trim().isEmpty) {
                  return 'رقم التليفون مطلوب';
                }
                if (value.trim().length < 7) {
                  return 'رقم التليفون قصير جداً';
                }
                return null;
              },
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: addressController,
              textInputAction: TextInputAction.next,
              decoration: _inputDecoration(
                label: 'العنوان',
                icon: Icons.location_on_rounded,
              ),
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: notesController,
              minLines: 3,
              maxLines: 4,
              textInputAction: TextInputAction.done,
              onFieldSubmitted: (_) => FocusScope.of(context).unfocus(),
              decoration: _inputDecoration(
                label: 'ملاحظات',
                icon: Icons.notes_rounded,
              ),
            ),
            const SizedBox(height: 18),
            FilledButton.icon(
              onPressed: isSaving ? null : onSave,
              icon: isSaving
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.save_rounded),
              label: const Text('حفظ ومتابعة الطلب'),
            ),
          ],
        ),
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
      padding: const EdgeInsets.all(22),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: AppColors.accentBrown.withValues(alpha: 0.42),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.22),
            blurRadius: 24,
            offset: const Offset(0, 16),
          ),
        ],
      ),
      child: child,
    );
  }
}

class _SectionHeader extends StatelessWidget {
  const _SectionHeader({
    required this.icon,
    required this.title,
    required this.subtitle,
  });

  final IconData icon;
  final String title;
  final String subtitle;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: 46,
          height: 46,
          decoration: BoxDecoration(
            color: AppColors.primaryGold.withValues(alpha: 0.14),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Icon(icon, color: AppColors.primaryGold),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(title, style: Theme.of(context).textTheme.headlineSmall),
              const SizedBox(height: 5),
              Text(subtitle, style: AppTextStyles.muted),
            ],
          ),
        ),
      ],
    );
  }
}

class _InfoRow extends StatelessWidget {
  const _InfoRow({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(width: 150, child: Text(label, style: AppTextStyles.muted)),
          Expanded(
            child: Text(value, style: Theme.of(context).textTheme.bodyLarge),
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
