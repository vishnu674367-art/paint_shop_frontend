import 'package:flutter/material.dart';

import 'app_toast.dart';
import 'responsive_ui.dart';
import 'api_service.dart';
import 'app_input_formatters.dart';

class CustomersPage extends StatefulWidget {
  final String token;
  final String? apiBaseUrl;

  const CustomersPage({super.key, required this.token, this.apiBaseUrl});

  @override
  State<CustomersPage> createState() => _CustomersPageState();
}

class _CustomersPageState extends State<CustomersPage> {
  late final ApiService _api;
  bool _isLoading = true;
  String? _errorMessage;
  List<dynamic> _customers = [];
  List<dynamic> _sales = [];

  String _searchQuery = '';
  String _typeFilter = 'All';
  String _statusFilter = 'All';
  final TextEditingController _searchCtrl = TextEditingController();

  static const Color sidebarBlue = Color(0xFF1E40AF);
  static const Color navyDark = Color(0xFF0F172A);
  static const Color primaryGreen = Color(0xFF10B981);
  static const Color background = Color(0xFFF5F5F5);

  @override
  void initState() {
    super.initState();
    _api = ApiService(token: widget.token, customBaseUrl: widget.apiBaseUrl);
    _loadCustomers();
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  Future<void> _loadCustomers() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final results = await Future.wait([
        _api.get('/customers'),
        _api.get('/sales').catchError((_) => {'data': []}),
      ]);
      if (!mounted) return;
      setState(() {
        _customers = results[0]['data'] is List ? results[0]['data'] : [];
        _sales = results[1]['data'] is List ? results[1]['data'] : [];
        _isLoading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _errorMessage = e.toString().replaceAll('Exception: ', '');
        _isLoading = false;
      });
    }
  }

  String _custCode(dynamic c) {
    final id = (c['id'] ?? '').toString();
    return 'CUST-${id.padLeft(3, '0')}';
  }

  String _custType(dynamic c) {
    final t = (c['customer_type'] ?? '').toString().trim();
    return t.isNotEmpty ? t : 'Retail';
  }

  bool _isActive(dynamic c) {
    final status = (c['status'] ?? 'Active').toString().toLowerCase();
    return status != 'inactive';
  }

  int _ordersForCustomer(dynamic c) {
    final cid = c['id'];
    if (cid == null) return 0;
    return _sales.where((s) => s['customer_id'] == cid).length;
  }

  double _balanceForCustomer(dynamic c) {
    final cid = c['id'];
    if (cid == null) return 0;
    return _sales
        .where((s) => s['customer_id'] == cid)
        .fold(
          0.0,
          (sum, s) =>
              sum +
              (double.tryParse(s['balance_amount']?.toString() ?? '0') ?? 0),
        );
  }

  double get _totalOutstanding {
    return _filteredCustomers.fold(
      0.0,
      (sum, c) => sum + _balanceForCustomer(c),
    );
  }

  int get _activeCount {
    return _filteredCustomers.where(_isActive).length;
  }

  List<dynamic> get _filteredCustomers {
    final q = _searchQuery.trim().toLowerCase();
    return _customers.where((c) {
      final idStr = _custCode(c).toLowerCase();
      final name = (c['name'] ?? '').toString().toLowerCase();
      final phone = (c['phone'] ?? '').toString().toLowerCase();
      final email = (c['email'] ?? '').toString().toLowerCase();
      final address = (c['address'] ?? '').toString().toLowerCase();

      final matchesQuery =
          q.isEmpty ||
          idStr.contains(q) ||
          name.contains(q) ||
          phone.contains(q) ||
          email.contains(q) ||
          address.contains(q);

      final matchesType =
          _typeFilter == 'All' ||
          _custType(c).toLowerCase() == _typeFilter.toLowerCase();
      final active = _isActive(c);
      final matchesStatus =
          _statusFilter == 'All' ||
          (_statusFilter == 'Active' && active) ||
          (_statusFilter == 'Inactive' && !active);

      return matchesQuery && matchesType && matchesStatus;
    }).toList();
  }

  void _clearFilters() {
    _searchCtrl.clear();
    setState(() {
      _searchQuery = '';
      _typeFilter = 'All';
      _statusFilter = 'All';
    });
  }

  String _currency(double amount) {
    return '₹${amount % 1 == 0 ? amount.toInt() : amount.toStringAsFixed(2)}';
  }

  void _showCustomerDetail(dynamic c) {
    final orders = _ordersForCustomer(c);
    final bal = _balanceForCustomer(c);
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        title: Row(
          children: [
            const Icon(Icons.person_rounded, color: sidebarBlue),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                c['name']?.toString() ?? 'Customer',
                style: const TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 17,
                  color: navyDark,
                ),
              ),
            ),
          ],
        ),
        content: SizedBox(
          width: 380,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _detailRow('Customer ID', _custCode(c)),
              const SizedBox(height: 8),
              _detailRow('Mobile Number', (c['phone'] ?? '-').toString()),
              const SizedBox(height: 8),
              _detailRow('Email Address', (c['email'] ?? '-').toString()),
              const SizedBox(height: 8),
              _detailRow('Address', (c['address'] ?? '-').toString()),
              const SizedBox(height: 8),
              _detailRow('Total Orders', '$orders'),
              const SizedBox(height: 8),
              _detailRow('Balance Due', _currency(bal)),
            ],
          ),
        ),
        actions: [
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx),
            style: ElevatedButton.styleFrom(
              backgroundColor: sidebarBlue,
              foregroundColor: Colors.white,
            ),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }

  Widget _detailRow(String label, String value) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          label,
          style: const TextStyle(fontSize: 12.5, color: Color(0xFF64748B)),
        ),
        Flexible(
          child: Text(
            value.isEmpty ? '-' : value,
            textAlign: TextAlign.right,
            style: const TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: navyDark,
            ),
          ),
        ),
      ],
    );
  }

  void _showCustomerDialog({Map<String, dynamic>? customer}) {
    final isEditing = customer != null;
    final custIdCtrl = TextEditingController(
      text: isEditing ? _custCode(customer) : '',
    );
    final nameCtrl = TextEditingController(
      text: customer?['name']?.toString() ?? '',
    );
    final phoneCtrl = TextEditingController(
      text: customer?['phone']?.toString() ?? '',
    );
    final emailCtrl = TextEditingController(
      text: customer?['email']?.toString() ?? '',
    );
    final cityCtrl = TextEditingController();
    final addressCtrl = TextEditingController(
      text: customer?['address']?.toString() ?? '',
    );

    String customerType = _custType(customer ?? {});
    bool isActiveAccount = customer != null ? _isActive(customer) : true;
    bool isSaving = false;

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => StatefulBuilder(
        builder: (dialogCtx, setDialogState) {
          final isNarrow = MediaQuery.sizeOf(dialogCtx).width < 560;

          Widget fieldBox(String label, Widget child) {
            Widget formattedChild = child;
            if (child is TextField) {
              formattedChild = TextField(
                controller: child.controller,
                focusNode: child.focusNode,
                decoration: child.decoration,
                keyboardType: child.keyboardType,
                textInputAction: child.textInputAction,
                textCapitalization: child.textCapitalization,
                style: child.style,
                readOnly: child.readOnly,
                autofocus: child.autofocus,
                obscureText: child.obscureText,
                maxLines: child.maxLines,
                minLines: child.minLines,
                onChanged: child.onChanged,
                onTap: child.onTap,
                onSubmitted: child.onSubmitted,
                inputFormatters: [
                  const NoLeadingSpaceFormatter(),
                  ...?child.inputFormatters,
                ],
                enabled: child.enabled,
              );
            }
            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: Color(0xFF475569),
                  ),
                ),
                const SizedBox(height: 6),
                formattedChild,
              ],
            );
          }

          InputDecoration inputDec(String hint) => InputDecoration(
            hintText: hint,
            hintStyle: const TextStyle(
              fontSize: 12.5,
              color: Color(0xFF94A3B8),
            ),
            filled: true,
            fillColor: const Color(0xFFF8FAFC),
            isDense: true,
            contentPadding: const EdgeInsets.symmetric(
              horizontal: 12,
              vertical: 11,
            ),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
              borderSide: const BorderSide(color: Color(0xFFE2E8F0)),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
              borderSide: const BorderSide(color: Color(0xFFE2E8F0)),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
              borderSide: const BorderSide(color: sidebarBlue, width: 1.4),
            ),
          );

          return Dialog(
            backgroundColor: Colors.white,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
            ),
            insetPadding: const EdgeInsets.symmetric(
              horizontal: 16,
              vertical: 20,
            ),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 560),
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(24),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          isEditing ? 'Edit Customer' : 'Add New Customer',
                          style: const TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.w800,
                            color: navyDark,
                          ),
                        ),
                        IconButton(
                          onPressed: isSaving
                              ? null
                              : () => Navigator.pop(dialogCtx),
                          icon: const Icon(
                            Icons.close_rounded,
                            color: Color(0xFF64748B),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),

                    if (isNarrow) ...[
                      fieldBox(
                        'Customer ID',
                        TextField(
                          controller: custIdCtrl,
                          readOnly: isEditing,
                          decoration: inputDec('Auto-generates if empty'),
                        ),
                      ),
                      const SizedBox(height: 12),
                      fieldBox(
                        'Customer Name *',
                        TextField(
                          controller: nameCtrl,
                          decoration: inputDec('Enter customer name'),
                        ),
                      ),
                      const SizedBox(height: 12),
                      fieldBox(
                        'Mobile Number *',
                        TextField(
                          controller: phoneCtrl,
                          keyboardType: TextInputType.phone,
                          inputFormatters: const [PhoneNumberFormatter()],
                          decoration: inputDec('Enter 10-digit mobile number'),
                        ),
                      ),
                      const SizedBox(height: 12),
                      fieldBox(
                        'Email Address',
                        TextField(
                          controller: emailCtrl,
                          keyboardType: TextInputType.emailAddress,
                          decoration: inputDec('client@gmail.com'),
                        ),
                      ),
                      const SizedBox(height: 12),
                      fieldBox(
                        'Customer Type *',
                        DropdownButtonFormField<String>(
                          initialValue: customerType,
                          decoration: inputDec('Retail'),
                          items: ['Retail', 'Dealer', 'Contractor', 'Wholesale']
                              .map(
                                (t) =>
                                    DropdownMenuItem(value: t, child: Text(t)),
                              )
                              .toList(),
                          onChanged: (val) {
                            if (val != null) {
                              setDialogState(() => customerType = val);
                            }
                          },
                        ),
                      ),
                      const SizedBox(height: 12),
                      fieldBox(
                        'City *',
                        TextField(
                          controller: cityCtrl,
                          decoration: inputDec('Enter city name'),
                        ),
                      ),
                    ] else ...[
                      Row(
                        children: [
                          Expanded(
                            child: fieldBox(
                              'Customer ID',
                              TextField(
                                controller: custIdCtrl,
                                readOnly: isEditing,
                                decoration: inputDec('Auto-generates if empty'),
                              ),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: fieldBox(
                              'Customer Name *',
                              TextField(
                                controller: nameCtrl,
                                decoration: inputDec('Enter customer name'),
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      Row(
                        children: [
                          Expanded(
                            child: fieldBox(
                              'Mobile Number *',
                              TextField(
                                controller: phoneCtrl,
                                keyboardType: TextInputType.phone,
                                inputFormatters: const [PhoneNumberFormatter()],
                                decoration: inputDec(
                                  'Enter 10-digit mobile number',
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: fieldBox(
                              'Email Address',
                              TextField(
                                controller: emailCtrl,
                                keyboardType: TextInputType.emailAddress,
                                decoration: inputDec('client@gmail.com'),
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      Row(
                        children: [
                          Expanded(
                            child: fieldBox(
                              'Customer Type *',
                              DropdownButtonFormField<String>(
                                initialValue: customerType,
                                decoration: inputDec('Retail'),
                                items:
                                    [
                                          'Retail',
                                          'Dealer',
                                          'Contractor',
                                          'Wholesale',
                                        ]
                                        .map(
                                          (t) => DropdownMenuItem(
                                            value: t,
                                            child: Text(t),
                                          ),
                                        )
                                        .toList(),
                                onChanged: (val) {
                                  if (val != null) {
                                    setDialogState(() => customerType = val);
                                  }
                                },
                              ),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: fieldBox(
                              'City *',
                              TextField(
                                controller: cityCtrl,
                                decoration: inputDec('Enter city name'),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                    const SizedBox(height: 12),
                    fieldBox(
                      'Full Address',
                      TextField(
                        controller: addressCtrl,
                        maxLines: 2,
                        decoration: inputDec('Street, area, landmark...'),
                      ),
                    ),
                    const SizedBox(height: 12),
                    InkWell(
                      onTap: () => setDialogState(
                        () => isActiveAccount = !isActiveAccount,
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Checkbox(
                            value: isActiveAccount,
                            activeColor: sidebarBlue,
                            onChanged: (v) => setDialogState(
                              () => isActiveAccount = v ?? true,
                            ),
                          ),
                          const Text(
                            'Active Customer Account',
                            style: TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w600,
                              color: navyDark,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 16),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.end,
                      children: [
                        TextButton(
                          onPressed: isSaving
                              ? null
                              : () => Navigator.pop(dialogCtx),
                          child: const Text(
                            'Cancel',
                            style: TextStyle(
                              color: Color(0xFF475569),
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                        const SizedBox(width: 10),
                        ElevatedButton(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: sidebarBlue,
                            foregroundColor: Colors.white,
                            elevation: 0,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(8),
                            ),
                            padding: const EdgeInsets.symmetric(
                              horizontal: 18,
                              vertical: 12,
                            ),
                          ),
                          onPressed: isSaving
                              ? null
                              : () async {
                                  final name = nameCtrl.text.trim();
                                  if (name.isEmpty || name.length < 2) {
                                    AppToast.showWarning(
                                      context,
                                      title: 'Invalid Name',
                                      message:
                                          'Please enter a valid customer name.',
                                    );
                                    return;
                                  }

                                  final phone = phoneCtrl.text.trim();
                                  if (phone.length != 10 ||
                                      RegExp(r"^(\d)\1{9}$").hasMatch(phone)) {
                                    AppToast.showWarning(
                                      context,
                                      title: 'Invalid Mobile Number',
                                      message: 'Please enter a valid 10-digit mobile number.',
                                    );
                                    return;
                                  }

                                  final email = emailCtrl.text.trim();
                                  if (email.isNotEmpty &&
                                      !RegExp(
                                        r"^[a-zA-Z0-9._%+-]+@[a-zA-Z0-9.-]+\.[a-zA-Z]{2,}$",
                                      ).hasMatch(email)) {
                                    AppToast.showWarning(
                                      context,
                                      title: 'Invalid Email',
                                      message:
                                          'Please enter a valid email address.',
                                    );
                                    return;
                                  }

                                  final addrText = addressCtrl.text.trim();
                                  final cityText = cityCtrl.text.trim();
                                  final fullAddress =
                                      cityText.isNotEmpty &&
                                          !addrText.toLowerCase().contains(
                                            cityText.toLowerCase(),
                                          )
                                      ? (addrText.isEmpty
                                            ? cityText
                                            : '$addrText, $cityText')
                                      : addrText;

                                  setDialogState(() => isSaving = true);
                                  final payload = {
                                    'name': name,
                                    'phone': phoneCtrl.text.trim(),
                                    'email': emailCtrl.text.trim(),
                                    'address': fullAddress,
                                  };

                                  try {
                                    if (isEditing) {
                                      await _api.put(
                                        '/customers/${customer['id']}',
                                        payload,
                                      );
                                    } else {
                                      await _api.post('/customers', payload);
                                    }
                                    if (!dialogCtx.mounted) return;
                                    Navigator.pop(dialogCtx);
                                    if (!mounted) return;
                                    AppToast.showSuccess(
                                      context,
                                      title: isEditing
                                          ? 'Customer Updated!'
                                          : 'Customer Created!',
                                      message: isEditing
                                          ? '$name profile details updated successfully.'
                                          : '$name has been added as a customer.',
                                    );
                                    _loadCustomers();
                                  } catch (e) {
                                    setDialogState(() => isSaving = false);
                                    if (!mounted) return;
                                    AppToast.showError(
                                      context,
                                      title: isEditing
                                          ? 'Update Failed'
                                          : 'Save Failed',
                                      message: e.toString().replaceAll(
                                        'Exception: ',
                                        '',
                                      ),
                                    );
                                  }
                                },
                          child: Text(
                            isSaving
                                ? 'Saving...'
                                : (isEditing
                                      ? 'Update Customer'
                                      : 'Save Customer'),
                            style: const TextStyle(fontWeight: FontWeight.w700),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  Future<void> _deleteCustomer(dynamic customer) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        title: const Text(
          'Delete Customer',
          style: TextStyle(fontWeight: FontWeight.bold, color: navyDark),
        ),
        content: Text('Are you sure you want to delete "${customer['name']}"?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel', style: TextStyle(color: Colors.grey)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
              foregroundColor: Colors.white,
            ),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );

    if (confirm != true) return;

    try {
      await _api.delete('/customers/${customer['id']}');
      if (mounted) {
        AppToast.showSuccess(
          context,
          title: 'Customer Deleted',
          message: 'Customer record removed successfully.',
        );
        _loadCustomers();
      }
    } catch (e) {
      if (mounted) {
        AppToast.showError(
          context,
          title: 'Delete Failed',
          message: e.toString().replaceAll('Exception: ', ''),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final width = MediaQuery.sizeOf(context).width;
    final isCompactFilter = width < 920;

    return Container(
      color: background,
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(20, 18, 20, 30),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // 1. TOP HEADER (Customers / Manage your customers + Add Customer)
            Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                const Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Customers',
                        style: TextStyle(
                          fontSize: 26,
                          fontWeight: FontWeight.w800,
                          color: navyDark,
                        ),
                      ),
                      SizedBox(height: 2),
                      Text(
                        'Manage your customers and their purchase history',
                        style: TextStyle(
                          fontSize: 13,
                          color: Color(0xFF64748B),
                        ),
                      ),
                    ],
                  ),
                ),
                ElevatedButton.icon(
                  onPressed: () => _showCustomerDialog(),
                  icon: const Icon(Icons.person_add_alt_1_rounded, size: 17),
                  label: const Text(
                    'Add Customer',
                    style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700),
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: sidebarBlue,
                    foregroundColor: Colors.white,
                    elevation: 0,
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 12,
                    ),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),

            // 2. THREE SUMMARY METRIC CARDS
            ResponsiveSummaryGrid(
              spacing: 12,
              desktopBreakpoint: 820,
              tabletBreakpoint: 480,
              children: [
                _buildSummaryBox(
                  title: 'MATCHING CUSTOMERS',
                  value: '${_filteredCustomers.length}',
                  subtitle: 'Across the selected filters',
                  icon: Icons.groups_outlined,
                  accentColor: sidebarBlue,
                ),
                _buildSummaryBox(
                  title: 'ACTIVE ACCOUNTS',
                  value: '$_activeCount',
                  subtitle: 'Currently active clients',
                  icon: Icons.verified_user_outlined,
                  accentColor: primaryGreen,
                ),
                _buildSummaryBox(
                  title: 'TOTAL OUTSTANDING',
                  value: _currency(_totalOutstanding),
                  subtitle: 'Combined balance due',
                  icon: Icons.account_balance_wallet_outlined,
                  accentColor: const Color(0xFFF59E0B),
                ),
              ],
            ),
            const SizedBox(height: 14),

            // 3. FILTER BAR CARD
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: const Color(0xFFE2E8F0)),
              ),
              child: Builder(
                builder: (_) {
                  final searchField = SizedBox(
                    height: 40,
                    child: TextField(
                      controller: _searchCtrl,
                      inputFormatters: const [NoLeadingSpaceFormatter()],
                      onChanged: (val) => setState(() => _searchQuery = val),
                      style: const TextStyle(color: navyDark, fontSize: 13),
                      decoration: InputDecoration(
                        hintText:
                            'Search by ID, Name, Phone, Email, or City...',
                        hintStyle: const TextStyle(
                          color: Color(0xFF94A3B8),
                          fontSize: 12.5,
                        ),
                        prefixIcon: const Icon(
                          Icons.search_rounded,
                          size: 18,
                          color: Color(0xFF64748B),
                        ),
                        filled: true,
                        fillColor: const Color(0xFFF8FAFC),
                        isDense: true,
                        contentPadding: const EdgeInsets.symmetric(
                          vertical: 10,
                          horizontal: 12,
                        ),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(8),
                          borderSide: const BorderSide(
                            color: Color(0xFFE2E8F0),
                          ),
                        ),
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(8),
                          borderSide: const BorderSide(
                            color: Color(0xFFE2E8F0),
                          ),
                        ),
                      ),
                    ),
                  );

                  final typeDropdown = SizedBox(
                    height: 40,
                    child: DropdownButtonFormField<String>(
                      initialValue: _typeFilter,
                      isExpanded: true,
                      decoration: InputDecoration(
                        filled: true,
                        fillColor: const Color(0xFFF8FAFC),
                        isDense: true,
                        contentPadding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 9,
                        ),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(8),
                          borderSide: const BorderSide(
                            color: Color(0xFFE2E8F0),
                          ),
                        ),
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(8),
                          borderSide: const BorderSide(
                            color: Color(0xFFE2E8F0),
                          ),
                        ),
                      ),
                      style: const TextStyle(color: navyDark, fontSize: 13),
                      items: const [
                        DropdownMenuItem(
                          value: 'All',
                          child: Text('All Types'),
                        ),
                        DropdownMenuItem(
                          value: 'Retail',
                          child: Text('Retail'),
                        ),
                        DropdownMenuItem(
                          value: 'Dealer',
                          child: Text('Dealer'),
                        ),
                        DropdownMenuItem(
                          value: 'Contractor',
                          child: Text('Contractor'),
                        ),
                        DropdownMenuItem(
                          value: 'Wholesale',
                          child: Text('Wholesale'),
                        ),
                      ],
                      onChanged: (val) {
                        if (val != null) setState(() => _typeFilter = val);
                      },
                    ),
                  );

                  final statusDropdown = SizedBox(
                    height: 40,
                    child: DropdownButtonFormField<String>(
                      initialValue: _statusFilter,
                      isExpanded: true,
                      decoration: InputDecoration(
                        filled: true,
                        fillColor: const Color(0xFFF8FAFC),
                        isDense: true,
                        contentPadding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 9,
                        ),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(8),
                          borderSide: const BorderSide(
                            color: Color(0xFFE2E8F0),
                          ),
                        ),
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(8),
                          borderSide: const BorderSide(
                            color: Color(0xFFE2E8F0),
                          ),
                        ),
                      ),
                      style: const TextStyle(color: navyDark, fontSize: 13),
                      items: const [
                        DropdownMenuItem(
                          value: 'All',
                          child: Text('All Status'),
                        ),
                        DropdownMenuItem(
                          value: 'Active',
                          child: Text('Active'),
                        ),
                        DropdownMenuItem(
                          value: 'Inactive',
                          child: Text('Inactive'),
                        ),
                      ],
                      onChanged: (val) {
                        if (val != null) setState(() => _statusFilter = val);
                      },
                    ),
                  );

                  final clearBtn = SizedBox(
                    height: 40,
                    child: TextButton.icon(
                      onPressed: _clearFilters,
                      icon: const Icon(
                        Icons.close_rounded,
                        size: 15,
                        color: Color(0xFF475569),
                      ),
                      label: const Text(
                        'Clear Filters',
                        style: TextStyle(
                          fontSize: 12.5,
                          fontWeight: FontWeight.w600,
                          color: Color(0xFF475569),
                        ),
                      ),
                    ),
                  );

                  if (isCompactFilter) {
                    return Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        searchField,
                        const SizedBox(height: 10),
                        Row(
                          children: [
                            Expanded(child: typeDropdown),
                            const SizedBox(width: 8),
                            Expanded(child: statusDropdown),
                          ],
                        ),
                        const SizedBox(height: 6),
                        Align(
                          alignment: Alignment.centerRight,
                          child: clearBtn,
                        ),
                      ],
                    );
                  }

                  return Row(
                    children: [
                      Expanded(flex: 4, child: searchField),
                      const SizedBox(width: 10),
                      Expanded(flex: 2, child: typeDropdown),
                      const SizedBox(width: 10),
                      Expanded(flex: 2, child: statusDropdown),
                      const SizedBox(width: 8),
                      clearBtn,
                    ],
                  );
                },
              ),
            ),
            const SizedBox(height: 14),

            // 4. CUSTOMER DIRECTORY TABLE CARD
            Container(
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: const Color(0xFFE2E8F0)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Padding(
                    padding: const EdgeInsets.fromLTRB(18, 14, 18, 14),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text(
                          'Customer Directory',
                          style: TextStyle(
                            fontSize: 17,
                            fontWeight: FontWeight.w800,
                            color: navyDark,
                          ),
                        ),
                        OutlinedButton.icon(
                          onPressed: _loadCustomers,
                          icon: const Icon(Icons.refresh_rounded, size: 16),
                          label: const Text(
                            'Refresh',
                            style: TextStyle(
                              fontSize: 12.5,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          style: OutlinedButton.styleFrom(
                            foregroundColor: navyDark,
                            side: const BorderSide(color: Color(0xFFE2E8F0)),
                            padding: const EdgeInsets.symmetric(
                              horizontal: 12,
                              vertical: 8,
                            ),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(8),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const Divider(height: 1, color: Color(0xFFE2E8F0)),

                  if (_isLoading)
                    const SizedBox(
                      height: 220,
                      child: Center(child: CircularProgressIndicator()),
                    )
                  else if (_errorMessage != null)
                    Padding(
                      padding: const EdgeInsets.all(28),
                      child: Column(
                        children: [
                          const Icon(
                            Icons.error_outline,
                            size: 38,
                            color: Colors.red,
                          ),
                          const SizedBox(height: 8),
                          Text(
                            _errorMessage!,
                            style: const TextStyle(color: navyDark),
                          ),
                          const SizedBox(height: 12),
                          ElevatedButton(
                            onPressed: _loadCustomers,
                            child: const Text('Try Again'),
                          ),
                        ],
                      ),
                    )
                  else if (_filteredCustomers.isEmpty)
                    Padding(
                      padding: const EdgeInsets.all(36),
                      child: Column(
                        children: [
                          const Icon(
                            Icons.people_outline,
                            size: 44,
                            color: Colors.grey,
                          ),
                          const SizedBox(height: 10),
                          const Text(
                            'No customers found',
                            style: TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const SizedBox(height: 4),
                          const Text(
                            'Add regular painters, contractors, and walk-in clients here.',
                            style: TextStyle(fontSize: 12, color: Colors.grey),
                          ),
                          const SizedBox(height: 14),
                          ElevatedButton.icon(
                            onPressed: () => _showCustomerDialog(),
                            icon: const Icon(Icons.person_add),
                            label: const Text('Add First Customer'),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: sidebarBlue,
                              foregroundColor: Colors.white,
                            ),
                          ),
                        ],
                      ),
                    )
                  else
                    Builder(
                      builder: (_) {
                        final isNarrow = width < 940;
                        final tableBody = Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            Container(
                              color: const Color(0xFFF8FAFC),
                              padding: const EdgeInsets.symmetric(
                                horizontal: 18,
                                vertical: 12,
                              ),
                              child: const Row(
                                children: [
                                  Expanded(
                                    flex: 2,
                                    child: Text(
                                      'CUST ID',
                                      style: TextStyle(
                                        fontSize: 11,
                                        fontWeight: FontWeight.w700,
                                        letterSpacing: 0.6,
                                        color: Color(0xFF64748B),
                                      ),
                                    ),
                                  ),
                                  Expanded(
                                    flex: 3,
                                    child: Text(
                                      'NAME',
                                      style: TextStyle(
                                        fontSize: 11,
                                        fontWeight: FontWeight.w700,
                                        letterSpacing: 0.6,
                                        color: Color(0xFF64748B),
                                      ),
                                    ),
                                  ),
                                  Expanded(
                                    flex: 3,
                                    child: Text(
                                      'CONTACT',
                                      style: TextStyle(
                                        fontSize: 11,
                                        fontWeight: FontWeight.w700,
                                        letterSpacing: 0.6,
                                        color: Color(0xFF64748B),
                                      ),
                                    ),
                                  ),
                                  Expanded(
                                    flex: 2,
                                    child: Text(
                                      'TYPE',
                                      style: TextStyle(
                                        fontSize: 11,
                                        fontWeight: FontWeight.w700,
                                        letterSpacing: 0.6,
                                        color: Color(0xFF64748B),
                                      ),
                                    ),
                                  ),
                                  Expanded(
                                    flex: 2,
                                    child: Text(
                                      'TOTAL ORDERS',
                                      style: TextStyle(
                                        fontSize: 11,
                                        fontWeight: FontWeight.w700,
                                        letterSpacing: 0.6,
                                        color: Color(0xFF64748B),
                                      ),
                                    ),
                                  ),
                                  Expanded(
                                    flex: 2,
                                    child: Text(
                                      'BALANCE DUE',
                                      style: TextStyle(
                                        fontSize: 11,
                                        fontWeight: FontWeight.w700,
                                        letterSpacing: 0.6,
                                        color: Color(0xFF64748B),
                                      ),
                                    ),
                                  ),
                                  Expanded(
                                    flex: 2,
                                    child: Text(
                                      'STATUS',
                                      style: TextStyle(
                                        fontSize: 11,
                                        fontWeight: FontWeight.w700,
                                        letterSpacing: 0.6,
                                        color: Color(0xFF64748B),
                                      ),
                                    ),
                                  ),
                                  SizedBox(
                                    width: 116,
                                    child: Text(
                                      'ACTIONS',
                                      textAlign: TextAlign.center,
                                      style: TextStyle(
                                        fontSize: 11,
                                        fontWeight: FontWeight.w700,
                                        letterSpacing: 0.6,
                                        color: Color(0xFF64748B),
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            const Divider(height: 1, color: Color(0xFFE2E8F0)),

                            ...List.generate(_filteredCustomers.length, (idx) {
                              final c = _filteredCustomers[idx];
                              final orders = _ordersForCustomer(c);
                              final bal = _balanceForCustomer(c);
                              final active = _isActive(c);
                              final typeLabel = _custType(c);

                              return Container(
                                decoration: BoxDecoration(
                                  color: Colors.white,
                                  border: Border(
                                    bottom: BorderSide(
                                      color:
                                          idx == _filteredCustomers.length - 1
                                          ? Colors.transparent
                                          : const Color(0xFFF1F5F9),
                                    ),
                                  ),
                                ),
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 18,
                                  vertical: 13,
                                ),
                                child: Row(
                                  children: [
                                    Expanded(
                                      flex: 2,
                                      child: Text(
                                        _custCode(c),
                                        style: const TextStyle(
                                          fontSize: 12.5,
                                          fontWeight: FontWeight.w600,
                                          color: Color(0xFF475569),
                                        ),
                                      ),
                                    ),
                                    Expanded(
                                      flex: 3,
                                      child: Text(
                                        c['name'] ?? '-',
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                        style: const TextStyle(
                                          fontSize: 13.5,
                                          fontWeight: FontWeight.w700,
                                          color: navyDark,
                                        ),
                                      ),
                                    ),
                                    Expanded(
                                      flex: 3,
                                      child: Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                            (c['phone'] ?? '-').toString(),
                                            maxLines: 1,
                                            overflow: TextOverflow.ellipsis,
                                            style: const TextStyle(
                                              fontSize: 12.5,
                                              fontWeight: FontWeight.w600,
                                              color: navyDark,
                                            ),
                                          ),
                                          if ((c['address'] ?? '')
                                              .toString()
                                              .trim()
                                              .isNotEmpty)
                                            Text(
                                              c['address'].toString(),
                                              maxLines: 1,
                                              overflow: TextOverflow.ellipsis,
                                              style: const TextStyle(
                                                fontSize: 11,
                                                color: Color(0xFF64748B),
                                              ),
                                            ),
                                        ],
                                      ),
                                    ),
                                    Expanded(
                                      flex: 2,
                                      child: Align(
                                        alignment: Alignment.centerLeft,
                                        child: Container(
                                          padding: const EdgeInsets.symmetric(
                                            horizontal: 10,
                                            vertical: 4,
                                          ),
                                          decoration: BoxDecoration(
                                            color: const Color(0xFFF1F5F9),
                                            borderRadius: BorderRadius.circular(
                                              6,
                                            ),
                                          ),
                                          child: Text(
                                            typeLabel,
                                            style: const TextStyle(
                                              fontSize: 11.5,
                                              fontWeight: FontWeight.w600,
                                              color: Color(0xFF334155),
                                            ),
                                          ),
                                        ),
                                      ),
                                    ),
                                    Expanded(
                                      flex: 2,
                                      child: Text(
                                        '$orders',
                                        style: const TextStyle(
                                          fontSize: 13,
                                          fontWeight: FontWeight.w600,
                                          color: navyDark,
                                        ),
                                      ),
                                    ),
                                    Expanded(
                                      flex: 2,
                                      child: Text(
                                        _currency(bal),
                                        style: TextStyle(
                                          fontSize: 13,
                                          fontWeight: bal > 0
                                              ? FontWeight.w700
                                              : FontWeight.w500,
                                          color: bal > 0
                                              ? Colors.red.shade600
                                              : const Color(0xFF475569),
                                        ),
                                      ),
                                    ),
                                    Expanded(
                                      flex: 2,
                                      child: Align(
                                        alignment: Alignment.centerLeft,
                                        child: Container(
                                          padding: const EdgeInsets.symmetric(
                                            horizontal: 10,
                                            vertical: 4,
                                          ),
                                          decoration: BoxDecoration(
                                            color: active
                                                ? const Color(0xFFECFDF5)
                                                : const Color(0xFFFEF2F2),
                                            borderRadius: BorderRadius.circular(
                                              999,
                                            ),
                                          ),
                                          child: Text(
                                            active ? 'Active' : 'Inactive',
                                            style: TextStyle(
                                              fontSize: 11,
                                              fontWeight: FontWeight.w700,
                                              color: active
                                                  ? const Color(0xFF047857)
                                                  : Colors.red.shade700,
                                            ),
                                          ),
                                        ),
                                      ),
                                    ),
                                    SizedBox(
                                      width: 116,
                                      child: Row(
                                        mainAxisAlignment:
                                            MainAxisAlignment.center,
                                        children: [
                                          IconButton(
                                            tooltip: 'View',
                                            icon: const Icon(
                                              Icons.visibility_outlined,
                                              size: 17,
                                              color: Color(0xFF475569),
                                            ),
                                            onPressed: () =>
                                                _showCustomerDetail(c),
                                            constraints: const BoxConstraints(),
                                            padding: const EdgeInsets.all(6),
                                          ),
                                          IconButton(
                                            tooltip: 'Edit',
                                            icon: const Icon(
                                              Icons.edit_outlined,
                                              size: 17,
                                              color: sidebarBlue,
                                            ),
                                            onPressed: () =>
                                                _showCustomerDialog(
                                                  customer: c,
                                                ),
                                            constraints: const BoxConstraints(),
                                            padding: const EdgeInsets.all(6),
                                          ),
                                          IconButton(
                                            tooltip: 'Delete',
                                            icon: const Icon(
                                              Icons.delete_outline_rounded,
                                              size: 17,
                                              color: Colors.red,
                                            ),
                                            onPressed: () => _deleteCustomer(c),
                                            constraints: const BoxConstraints(),
                                            padding: const EdgeInsets.all(6),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ],
                                ),
                              );
                            }),
                          ],
                        );

                        if (isNarrow) {
                          return SingleChildScrollView(
                            scrollDirection: Axis.horizontal,
                            child: SizedBox(width: 900, child: tableBody),
                          );
                        }
                        return tableBody;
                      },
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSummaryBox({
    required String title,
    required String value,
    required String subtitle,
    required IconData icon,
    required Color accentColor,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              color: accentColor.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(icon, color: accentColor, size: 19),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 10.5,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 0.7,
                    color: Color(0xFF64748B),
                  ),
                ),
                const SizedBox(height: 6),
                FittedBox(
                  fit: BoxFit.scaleDown,
                  alignment: Alignment.centerLeft,
                  child: Text(
                    value,
                    style: const TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.w800,
                      color: navyDark,
                    ),
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  subtitle,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 11.5,
                    color: Color(0xFF64748B),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
