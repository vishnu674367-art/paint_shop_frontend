import 'package:flutter/material.dart';

import 'app_toast.dart';
import 'app_date_picker.dart';
import 'api_service.dart';

class PurchasePage extends StatefulWidget {
  final String token;
  final String? apiBaseUrl;

  const PurchasePage({super.key, required this.token, this.apiBaseUrl});

  @override
  State<PurchasePage> createState() => _PurchasePageState();
}

class _PurchasePageState extends State<PurchasePage> {
  late final ApiService _api;
  bool _isLoading = true;
  String? _errorMessage;

  List<dynamic> _purchases = [];
  List<dynamic> _suppliers = [];
  List<dynamic> _products = [];
  String _searchQuery = '';
  String _statusFilter = 'All';
  DateTime? _fromDate;
  DateTime? _toDate;
  final TextEditingController _searchCtrl = TextEditingController();

  static const Color sidebarBlue = Color(0xFF1E40AF);
  static const Color navyDark = Color(0xFF0F172A);
  static const Color primaryGreen = Color(0xFF10B981);
  static const Color background = Color(0xFFF5F5F5); // White Smoke

  @override
  void initState() {
    super.initState();
    _api = ApiService(token: widget.token, customBaseUrl: widget.apiBaseUrl);
    _loadData();
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  Future<void> _loadData() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final results = await Future.wait([
        _api.get('/purchases'),
        _api.get('/suppliers'),
        _api.get('/products'),
      ]);

      if (!mounted) return;

      setState(() {
        _purchases = results[0]['data'] is List ? results[0]['data'] : [];
        _suppliers = results[1]['data'] is List ? results[1]['data'] : [];
        _products = results[2]['data'] is List ? results[2]['data'] : [];
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

  List<dynamic> get _filteredPurchases {
    final q = _searchQuery.trim().toLowerCase();
    return _purchases.where((p) {
      final no = (p['purchase_no'] ?? '').toString().toLowerCase();
      final supp = (p['supplier_name'] ?? '').toString().toLowerCase();
      final notes = (p['notes'] ?? '').toString().toLowerCase();
      final matchesQuery =
          q.isEmpty || no.contains(q) || supp.contains(q) || notes.contains(q);

      final paid =
          double.tryParse(p['paid_amount']?.toString() ?? '') ??
          double.tryParse(p['total_amount']?.toString() ?? '0') ??
          0;
      final total = double.tryParse(p['total_amount']?.toString() ?? '0') ?? 0;
      final derivedStatus =
          (p['payment_status']?.toString().trim().isNotEmpty == true)
          ? p['payment_status'].toString()
          : (paid >= total ? 'Received' : (paid > 0 ? 'Partial' : 'Unpaid'));
      final matchesStatus =
          _statusFilter == 'All' ||
          derivedStatus.toLowerCase() == _statusFilter.toLowerCase() ||
          (_statusFilter == 'Paid' &&
              derivedStatus.toLowerCase() == 'received');

      bool matchesDate = true;
      final rawDate = p['purchase_date']?.toString().split('T').first;
      if (rawDate != null && (_fromDate != null || _toDate != null)) {
        final parsed = DateTime.tryParse(rawDate);
        if (parsed != null) {
          if (_fromDate != null &&
              parsed.isBefore(
                DateTime(_fromDate!.year, _fromDate!.month, _fromDate!.day),
              )) {
            matchesDate = false;
          }
          if (_toDate != null &&
              parsed.isAfter(
                DateTime(_toDate!.year, _toDate!.month, _toDate!.day),
              )) {
            matchesDate = false;
          }
        }
      }

      return matchesQuery && matchesStatus && matchesDate;
    }).toList();
  }

  double get _totalPurchaseAmount {
    return _filteredPurchases.fold<double>(0.0, (sum, p) {
      final amt = double.tryParse(p['total_amount']?.toString() ?? '0') ?? 0;
      return sum + amt;
    });
  }

  double get _totalPendingPayments {
    return _filteredPurchases.fold<double>(0.0, (sum, p) {
      final total = double.tryParse(p['total_amount']?.toString() ?? '0') ?? 0;
      final paid = double.tryParse(p['paid_amount']?.toString() ?? '') ?? total;
      final bal =
          double.tryParse(p['balance_amount']?.toString() ?? '') ??
          (total - paid);
      return sum + (bal > 0 ? bal : 0);
    });
  }

  int get _uniqueSuppliersCount {
    final ids = <String>{};
    for (final p in _filteredPurchases) {
      final sid = (p['supplier_id'] ?? p['supplier_name'] ?? '')
          .toString()
          .trim();
      if (sid.isNotEmpty && sid != '-') ids.add(sid);
    }
    return ids.isNotEmpty ? ids.length : _suppliers.length;
  }

  Future<void> _pickDate({required bool isFrom}) async {
    final now = DateTime.now();
    final picked = await showAppDatePicker(
      context: context,
      initialDate: (isFrom ? _fromDate : _toDate) ?? now,
      firstDate: DateTime(2020),
      lastDate: DateTime(2035),
      helpText: isFrom ? 'SELECT FROM DATE' : 'SELECT TO DATE',
    );
    if (picked == null) return;
    setState(() {
      if (isFrom) {
        _fromDate = picked;
      } else {
        _toDate = picked;
      }
    });
  }

  void _clearFilters() {
    _searchCtrl.clear();
    setState(() {
      _searchQuery = '';
      _statusFilter = 'All';
      _fromDate = null;
      _toDate = null;
    });
  }

  String _formatDateLabel(DateTime? d, String placeholder) {
    if (d == null) return placeholder;
    const months = [
      'Jan',
      'Feb',
      'Mar',
      'Apr',
      'May',
      'Jun',
      'Jul',
      'Aug',
      'Sep',
      'Oct',
      'Nov',
      'Dec',
    ];
    return '${d.day.toString().padLeft(2, '0')} ${months[d.month - 1]} ${d.year}';
  }

  String _currency(dynamic value) {
    final amount = value is num
        ? value.toDouble()
        : double.tryParse(value?.toString() ?? '') ?? 0.0;
    final fixed = amount.toStringAsFixed(2);
    final parts = fixed.split('.');
    final whole = parts[0];
    final isNegative = whole.startsWith('-');
    final digits = isNegative ? whole.substring(1) : whole;

    String formatted;
    if (digits.length <= 3) {
      formatted = digits;
    } else {
      final lastThree = digits.substring(digits.length - 3);
      var remaining = digits.substring(0, digits.length - 3);
      final groups = <String>[];
      while (remaining.length > 2) {
        groups.insert(0, remaining.substring(remaining.length - 2));
        remaining = remaining.substring(0, remaining.length - 2);
      }
      if (remaining.isNotEmpty) groups.insert(0, remaining);
      formatted = '${groups.join(',')},$lastThree';
    }
    return '₹${isNegative ? '-' : ''}$formatted.${parts[1]}';
  }

  String _formatDate(dynamic value) {
    if (value == null) return '-';
    final raw = value.toString();
    final parsed = DateTime.tryParse(raw);
    if (parsed == null) return raw.split('T').first;
    const months = [
      'Jan',
      'Feb',
      'Mar',
      'Apr',
      'May',
      'Jun',
      'Jul',
      'Aug',
      'Sep',
      'Oct',
      'Nov',
      'Dec',
    ];
    return '${parsed.day.toString().padLeft(2, '0')} ${months[(parsed.month - 1) % 12]} ${parsed.year}';
  }

  void _showNewPurchaseDialog() {
    final supplierIdCtrl = TextEditingController();
    final supplierNameCtrl = TextEditingController();
    final supplierMobileCtrl = TextEditingController();
    final supplierAddressCtrl = TextEditingController();

    final prodNameCtrl = TextEditingController();
    final prodQtyCtrl = TextEditingController(text: '1');
    final prodCostCtrl = TextEditingController();
    final amountPaidCtrl = TextEditingController(text: '0');

    int? selectedSupplierId;
    int? selectedProductId;
    String paymentMethod = 'BANK';
    bool isSaving = false;
    final List<Map<String, dynamic>> items = [];

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => StatefulBuilder(
        builder: (dialogCtx, setDialogState) {
          double totalPurchase = 0;
          for (final it in items) {
            totalPurchase +=
                (it['price'] as double) * (it['quantity'] as double);
          }
          final amountPaid = double.tryParse(amountPaidCtrl.text.trim()) ?? 0.0;
          final balanceDue = (totalPurchase - amountPaid).clamp(
            0.0,
            double.infinity,
          );
          final isNarrow = MediaQuery.sizeOf(dialogCtx).width < 700;

          void addProductRow() {
            final name = prodNameCtrl.text.trim();
            final qty = double.tryParse(prodQtyCtrl.text.trim()) ?? 0;
            final cost = double.tryParse(prodCostCtrl.text.trim()) ?? -1;
            if (name.isEmpty) {
              AppToast.showWarning(
                context,
                title: 'Product Required',
                message: 'Please select or enter a product name.',
              );
              return;
            }
            if (qty <= 0) {
              AppToast.showWarning(
                context,
                title: 'Invalid Quantity',
                message: 'Please enter a quantity greater than 0.',
              );
              return;
            }
            if (cost < 0) {
              AppToast.showWarning(
                context,
                title: 'Invalid Unit Cost',
                message: 'Please enter a valid unit purchase cost.',
              );
              return;
            }
            setDialogState(() {
              items.add({
                'product_id': selectedProductId,
                'product_name': name,
                'quantity': qty,
                'price': cost,
              });
              selectedProductId = null;
              prodNameCtrl.clear();
              prodQtyCtrl.text = '1';
              prodCostCtrl.clear();
            });
          }

          Widget fieldBox({
            required String label,
            required Widget child,
            bool isRequired = false,
          }) {
            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Row(
                  children: [
                    Text(
                      label,
                      style: const TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: Color(0xFF334155),
                      ),
                    ),
                    if (isRequired)
                      const Text(
                        ' *',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                          color: Colors.red,
                        ),
                      ),
                  ],
                ),
                const SizedBox(height: 5),
                child,
              ],
            );
          }

          InputDecoration inputDec({
            required String hint,
            Widget? prefixIcon,
            Widget? suffixIcon,
            String? prefixText,
          }) => InputDecoration(
            hintText: hint,
            hintStyle: const TextStyle(
              fontSize: 12.5,
              color: Color(0xFF94A3B8),
            ),
            prefixIcon: prefixIcon,
            prefixText: prefixText,
            prefixStyle: const TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w700,
              color: navyDark,
            ),
            suffixIcon: suffixIcon,
            filled: true,
            fillColor: Colors.white,
            isDense: true,
            contentPadding: const EdgeInsets.symmetric(
              horizontal: 12,
              vertical: 11,
            ),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(9),
              borderSide: const BorderSide(color: Color(0xFFCBD5E1)),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(9),
              borderSide: const BorderSide(color: Color(0xFFE2E8F0)),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(9),
              borderSide: const BorderSide(color: sidebarBlue, width: 1.4),
            ),
          );

          Widget stepBadge(
            String number,
            String title, {
            Widget? badge,
            String? subtitle,
          }) {
            return Row(
              children: [
                Container(
                  width: 24,
                  height: 24,
                  decoration: const BoxDecoration(
                    color: sidebarBlue,
                    shape: BoxShape.circle,
                  ),
                  alignment: Alignment.center,
                  child: Text(
                    number,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Text(
                  title,
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                    color: navyDark,
                  ),
                ),
                if (badge != null) ...[const SizedBox(width: 8), badge],
                const Spacer(),
                if (subtitle != null)
                  Text(
                    subtitle,
                    style: const TextStyle(
                      fontSize: 11.5,
                      color: Color(0xFF64748B),
                    ),
                  ),
              ],
            );
          }

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
              constraints: const BoxConstraints(maxWidth: 780),
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(22),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    // HEADER
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: [
                        Container(
                          width: 44,
                          height: 44,
                          decoration: BoxDecoration(
                            color: const Color(0xFFEFF6FF),
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: const Color(0xFFDBEAFE)),
                          ),
                          child: const Icon(
                            Icons.inventory_2_rounded,
                            color: sidebarBlue,
                            size: 22,
                          ),
                        ),
                        const SizedBox(width: 12),
                        const Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Record New Purchase',
                                style: TextStyle(
                                  fontSize: 19,
                                  fontWeight: FontWeight.w800,
                                  color: navyDark,
                                  letterSpacing: -0.3,
                                ),
                              ),
                              SizedBox(height: 2),
                              Text(
                                'Receive products from suppliers. Inventory stock levels update automatically upon saving.',
                                style: TextStyle(
                                  fontSize: 12,
                                  color: Color(0xFF64748B),
                                ),
                              ),
                            ],
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
                          tooltip: 'Close',
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),

                    // 1. SUPPLIER DETAILS CARD
                    Container(
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        color: const Color(0xFFF8FAFC),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: const Color(0xFFE2E8F0)),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          stepBadge(
                            '1',
                            'Supplier Information',
                            badge: Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 7,
                                vertical: 2,
                              ),
                              decoration: BoxDecoration(
                                color: const Color(0xFFEFF6FF),
                                borderRadius: BorderRadius.circular(6),
                              ),
                              child: const Text(
                                'Select or Create New',
                                style: TextStyle(
                                  fontSize: 10.5,
                                  fontWeight: FontWeight.w600,
                                  color: sidebarBlue,
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(height: 12),
                          if (isNarrow) ...[
                            fieldBox(
                              label: 'Supplier Name',
                              isRequired: true,
                              child: Autocomplete<Map<String, dynamic>>(
                                displayStringForOption: (o) =>
                                    o['name']?.toString() ?? '',
                                optionsBuilder: (textEditingValue) {
                                  final q = textEditingValue.text
                                      .trim()
                                      .toLowerCase();
                                  if (q.isEmpty) {
                                    return _suppliers
                                        .cast<Map<String, dynamic>>();
                                  }
                                  return _suppliers
                                      .cast<Map<String, dynamic>>()
                                      .where(
                                        (s) => (s['name'] ?? '')
                                            .toString()
                                            .toLowerCase()
                                            .contains(q),
                                      );
                                },
                                onSelected: (opt) {
                                  selectedSupplierId = opt['id'] as int?;
                                  supplierIdCtrl.text =
                                      opt['id']?.toString() ?? '';
                                  supplierNameCtrl.text =
                                      opt['name']?.toString() ?? '';
                                  supplierMobileCtrl.text =
                                      opt['phone']?.toString() ?? '';
                                  supplierAddressCtrl.text =
                                      opt['address']?.toString() ?? '';
                                },
                                fieldViewBuilder: (_, textCtrl, focusNode, _) {
                                  return TextField(
                                    controller: textCtrl,
                                    focusNode: focusNode,
                                    onChanged: (v) {
                                      supplierNameCtrl.text = v;
                                      selectedSupplierId = null;
                                    },
                                    decoration: inputDec(
                                      hint: 'Type supplier name or select',
                                      prefixIcon: const Icon(
                                        Icons.business_rounded,
                                        size: 18,
                                        color: sidebarBlue,
                                      ),
                                    ),
                                  );
                                },
                              ),
                            ),
                            const SizedBox(height: 10),
                            fieldBox(
                              label: 'Mobile Number',
                              isRequired: true,
                              child: TextField(
                                controller: supplierMobileCtrl,
                                keyboardType: TextInputType.phone,
                                decoration: inputDec(
                                  hint: 'Enter mobile number',
                                  prefixIcon: const Icon(
                                    Icons.phone_outlined,
                                    size: 18,
                                    color: Color(0xFF64748B),
                                  ),
                                ),
                              ),
                            ),
                            const SizedBox(height: 10),
                            fieldBox(
                              label: 'Address',
                              child: TextField(
                                controller: supplierAddressCtrl,
                                decoration: inputDec(
                                  hint: 'Shop / street address, city',
                                  prefixIcon: const Icon(
                                    Icons.location_on_outlined,
                                    size: 18,
                                    color: Color(0xFF64748B),
                                  ),
                                ),
                              ),
                            ),
                            const SizedBox(height: 10),
                            fieldBox(
                              label: 'Supplier ID (Optional)',
                              child: TextField(
                                controller: supplierIdCtrl,
                                decoration: inputDec(
                                  hint: 'Leave blank to auto-generate',
                                  prefixIcon: const Icon(
                                    Icons.tag_rounded,
                                    size: 18,
                                    color: Color(0xFF64748B),
                                  ),
                                ),
                              ),
                            ),
                          ] else ...[
                            Row(
                              children: [
                                Expanded(
                                  flex: 3,
                                  child: fieldBox(
                                    label: 'Supplier Name',
                                    isRequired: true,
                                    child: Autocomplete<Map<String, dynamic>>(
                                      displayStringForOption: (o) =>
                                          o['name']?.toString() ?? '',
                                      optionsBuilder: (textEditingValue) {
                                        final q = textEditingValue.text
                                            .trim()
                                            .toLowerCase();
                                        if (q.isEmpty) {
                                          return _suppliers
                                              .cast<Map<String, dynamic>>();
                                        }
                                        return _suppliers
                                            .cast<Map<String, dynamic>>()
                                            .where(
                                              (s) => (s['name'] ?? '')
                                                  .toString()
                                                  .toLowerCase()
                                                  .contains(q),
                                            );
                                      },
                                      onSelected: (opt) {
                                        selectedSupplierId = opt['id'] as int?;
                                        supplierIdCtrl.text =
                                            opt['id']?.toString() ?? '';
                                        supplierNameCtrl.text =
                                            opt['name']?.toString() ?? '';
                                        supplierMobileCtrl.text =
                                            opt['phone']?.toString() ?? '';
                                        supplierAddressCtrl.text =
                                            opt['address']?.toString() ?? '';
                                      },
                                      optionsViewBuilder: (context, onSelected, options) {
                                        return Align(
                                          alignment: Alignment.topLeft,
                                          child: Material(
                                            elevation: 6,
                                            borderRadius: BorderRadius.circular(
                                              10,
                                            ),
                                            color: Colors.white,
                                            child: Container(
                                              width: 340,
                                              constraints: const BoxConstraints(
                                                maxHeight: 220,
                                              ),
                                              decoration: BoxDecoration(
                                                borderRadius:
                                                    BorderRadius.circular(10),
                                                border: Border.all(
                                                  color: const Color(
                                                    0xFFE2E8F0,
                                                  ),
                                                ),
                                              ),
                                              child: ListView.separated(
                                                padding:
                                                    const EdgeInsets.symmetric(
                                                      vertical: 4,
                                                    ),
                                                shrinkWrap: true,
                                                itemCount: options.length,
                                                separatorBuilder: (_, _) =>
                                                    const Divider(
                                                      height: 1,
                                                      color: Color(0xFFF1F5F9),
                                                    ),
                                                itemBuilder: (context, index) {
                                                  final option = options
                                                      .elementAt(index);
                                                  return InkWell(
                                                    onTap: () =>
                                                        onSelected(option),
                                                    child: Padding(
                                                      padding:
                                                          const EdgeInsets.symmetric(
                                                            horizontal: 14,
                                                            vertical: 9,
                                                          ),
                                                      child: Row(
                                                        children: [
                                                          const Icon(
                                                            Icons
                                                                .business_rounded,
                                                            size: 17,
                                                            color: sidebarBlue,
                                                          ),
                                                          const SizedBox(
                                                            width: 10,
                                                          ),
                                                          Expanded(
                                                            child: Column(
                                                              crossAxisAlignment:
                                                                  CrossAxisAlignment
                                                                      .start,
                                                              children: [
                                                                Text(
                                                                  option['name']
                                                                          ?.toString() ??
                                                                      '',
                                                                  style: const TextStyle(
                                                                    fontSize:
                                                                        13,
                                                                    fontWeight:
                                                                        FontWeight
                                                                            .w600,
                                                                    color:
                                                                        navyDark,
                                                                  ),
                                                                ),
                                                                Text(
                                                                  option['phone']
                                                                          ?.toString() ??
                                                                      'No phone',
                                                                  style: const TextStyle(
                                                                    fontSize:
                                                                        11,
                                                                    color: Color(
                                                                      0xFF64748B,
                                                                    ),
                                                                  ),
                                                                ),
                                                              ],
                                                            ),
                                                          ),
                                                        ],
                                                      ),
                                                    ),
                                                  );
                                                },
                                              ),
                                            ),
                                          ),
                                        );
                                      },
                                      fieldViewBuilder:
                                          (_, textCtrl, focusNode, _) {
                                            return TextField(
                                              controller: textCtrl,
                                              focusNode: focusNode,
                                              onChanged: (v) {
                                                supplierNameCtrl.text = v;
                                                selectedSupplierId = null;
                                              },
                                              decoration: inputDec(
                                                hint: 'Type supplier name or select existing',
                                                prefixIcon: const Icon(
                                                  Icons.business_rounded,
                                                  size: 18,
                                                  color: sidebarBlue,
                                                ),
                                              ),
                                            );
                                          },
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  flex: 2,
                                  child: fieldBox(
                                    label: 'Mobile Number',
                                    isRequired: true,
                                    child: TextField(
                                      controller: supplierMobileCtrl,
                                      keyboardType: TextInputType.phone,
                                      decoration: inputDec(
                                        hint: 'Mobile number',
                                        prefixIcon: const Icon(
                                          Icons.phone_outlined,
                                          size: 18,
                                          color: Color(0xFF64748B),
                                        ),
                                      ),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 10),
                            Row(
                              children: [
                                Expanded(
                                  flex: 3,
                                  child: fieldBox(
                                    label: 'Address',
                                    child: TextField(
                                      controller: supplierAddressCtrl,
                                      decoration: inputDec(
                                        hint: 'Shop / street address, city',
                                        prefixIcon: const Icon(
                                          Icons.location_on_outlined,
                                          size: 18,
                                          color: Color(0xFF64748B),
                                        ),
                                      ),
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  flex: 1,
                                  child: fieldBox(
                                    label: 'Supplier ID',
                                    child: TextField(
                                      controller: supplierIdCtrl,
                                      decoration: inputDec(
                                        hint: 'Auto-generate',
                                        prefixIcon: const Icon(
                                          Icons.tag_rounded,
                                          size: 18,
                                          color: Color(0xFF64748B),
                                        ),
                                      ),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ],
                      ),
                    ),

                    const SizedBox(height: 14),

                    // 2. PRODUCTS RECEIVED CARD
                    Container(
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        color: const Color(0xFFF8FAFC),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: const Color(0xFFE2E8F0)),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          stepBadge(
                            '2',
                            'Products Received',
                            badge: Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 8,
                                vertical: 2,
                              ),
                              decoration: BoxDecoration(
                                color: items.isNotEmpty
                                    ? const Color(0xFFDCFCE7)
                                    : const Color(0xFFEFF6FF),
                                borderRadius: BorderRadius.circular(6),
                              ),
                              child: Text(
                                '${items.length} product${items.length == 1 ? '' : 's'} added',
                                style: TextStyle(
                                  fontSize: 11,
                                  fontWeight: FontWeight.w700,
                                  color: items.isNotEmpty
                                      ? const Color(0xFF166534)
                                      : sidebarBlue,
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(height: 12),

                          // Product Input Bar
                          if (isNarrow) ...[
                            fieldBox(
                              label: 'Product Name',
                              isRequired: true,
                              child: Autocomplete<Map<String, dynamic>>(
                                displayStringForOption: (o) =>
                                    o['product_name']?.toString() ?? '',
                                optionsBuilder: (textEditingValue) {
                                  final q = textEditingValue.text
                                      .trim()
                                      .toLowerCase();
                                  if (q.isEmpty) {
                                    return _products
                                        .cast<Map<String, dynamic>>();
                                  }
                                  return _products
                                      .cast<Map<String, dynamic>>()
                                      .where(
                                        (p) => (p['product_name'] ?? '')
                                            .toString()
                                            .toLowerCase()
                                            .contains(q),
                                      );
                                },
                                onSelected: (opt) {
                                  selectedProductId = opt['id'] as int?;
                                  prodNameCtrl.text =
                                      opt['product_name']?.toString() ?? '';
                                  final cost =
                                      opt['cost_price']?.toString() ?? '';
                                  if (cost.isNotEmpty) prodCostCtrl.text = cost;
                                },
                                fieldViewBuilder: (_, textCtrl, focusNode, _) {
                                  return TextField(
                                    controller: textCtrl,
                                    focusNode: focusNode,
                                    onChanged: (v) {
                                      prodNameCtrl.text = v;
                                      selectedProductId = null;
                                    },
                                    decoration: inputDec(
                                      hint: 'Type or select product name',
                                      prefixIcon: const Icon(
                                        Icons.inventory_2_outlined,
                                        size: 18,
                                        color: sidebarBlue,
                                      ),
                                    ),
                                  );
                                },
                              ),
                            ),
                            const SizedBox(height: 10),
                            Row(
                              children: [
                                Expanded(
                                  child: fieldBox(
                                    label: 'Qty',
                                    isRequired: true,
                                    child: TextField(
                                      controller: prodQtyCtrl,
                                      keyboardType:
                                          const TextInputType.numberWithOptions(
                                            decimal: true,
                                          ),
                                      decoration: inputDec(
                                        hint: '1',
                                        prefixIcon: const Icon(
                                          Icons.numbers_rounded,
                                          size: 18,
                                          color: Color(0xFF64748B),
                                        ),
                                      ),
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 10),
                                Expanded(
                                  child: fieldBox(
                                    label: 'Unit Cost (₹)',
                                    isRequired: true,
                                    child: TextField(
                                      controller: prodCostCtrl,
                                      keyboardType:
                                          const TextInputType.numberWithOptions(
                                            decimal: true,
                                          ),
                                      decoration: inputDec(
                                        hint: '0.00',
                                        prefixIcon: const Icon(
                                          Icons.currency_rupee_rounded,
                                          size: 18,
                                          color: Color(0xFF64748B),
                                        ),
                                      ),
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 10),
                                Padding(
                                  padding: const EdgeInsets.only(top: 22),
                                  child: ElevatedButton.icon(
                                    onPressed: addProductRow,
                                    icon: const Icon(
                                      Icons.add_shopping_cart_rounded,
                                      size: 17,
                                    ),
                                    label: const Text('Add'),
                                    style: ElevatedButton.styleFrom(
                                      backgroundColor: sidebarBlue,
                                      foregroundColor: Colors.white,
                                      elevation: 0,
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 16,
                                        vertical: 12,
                                      ),
                                      shape: RoundedRectangleBorder(
                                        borderRadius: BorderRadius.circular(9),
                                      ),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ] else
                            Row(
                              crossAxisAlignment: CrossAxisAlignment.end,
                              children: [
                                Expanded(
                                  flex: 4,
                                  child: fieldBox(
                                    label: 'Product Name',
                                    isRequired: true,
                                    child: Autocomplete<Map<String, dynamic>>(
                                      displayStringForOption: (o) =>
                                          o['product_name']?.toString() ?? '',
                                      optionsBuilder: (textEditingValue) {
                                        final q = textEditingValue.text
                                            .trim()
                                            .toLowerCase();
                                        if (q.isEmpty) {
                                          return _products
                                              .cast<Map<String, dynamic>>();
                                        }
                                        return _products
                                            .cast<Map<String, dynamic>>()
                                            .where(
                                              (p) => (p['product_name'] ?? '')
                                                  .toString()
                                                  .toLowerCase()
                                                  .contains(q),
                                            );
                                      },
                                      onSelected: (opt) {
                                        selectedProductId = opt['id'] as int?;
                                        prodNameCtrl.text =
                                            opt['product_name']?.toString() ??
                                            '';
                                        final cost =
                                            opt['cost_price']?.toString() ?? '';
                                        if (cost.isNotEmpty) {
                                          prodCostCtrl.text = cost;
                                        }
                                      },
                                      optionsViewBuilder: (context, onSelected, options) {
                                        return Align(
                                          alignment: Alignment.topLeft,
                                          child: Material(
                                            elevation: 6,
                                            borderRadius: BorderRadius.circular(
                                              10,
                                            ),
                                            color: Colors.white,
                                            child: Container(
                                              width: 320,
                                              constraints: const BoxConstraints(
                                                maxHeight: 220,
                                              ),
                                              decoration: BoxDecoration(
                                                borderRadius:
                                                    BorderRadius.circular(10),
                                                border: Border.all(
                                                  color: const Color(
                                                    0xFFE2E8F0,
                                                  ),
                                                ),
                                              ),
                                              child: ListView.separated(
                                                padding:
                                                    const EdgeInsets.symmetric(
                                                      vertical: 4,
                                                    ),
                                                shrinkWrap: true,
                                                itemCount: options.length,
                                                separatorBuilder: (_, _) =>
                                                    const Divider(
                                                      height: 1,
                                                      color: Color(0xFFF1F5F9),
                                                    ),
                                                itemBuilder: (context, index) {
                                                  final option = options
                                                      .elementAt(index);
                                                  final stock =
                                                      option['stock_qty'] ?? 0;
                                                  final cost =
                                                      double.tryParse(
                                                        option['cost_price']
                                                                ?.toString() ??
                                                            '0',
                                                      ) ??
                                                      0;
                                                  return InkWell(
                                                    onTap: () =>
                                                        onSelected(option),
                                                    child: Padding(
                                                      padding:
                                                          const EdgeInsets.symmetric(
                                                            horizontal: 14,
                                                            vertical: 9,
                                                          ),
                                                      child: Row(
                                                        children: [
                                                          const Icon(
                                                            Icons
                                                                .inventory_2_outlined,
                                                            size: 17,
                                                            color: sidebarBlue,
                                                          ),
                                                          const SizedBox(
                                                            width: 10,
                                                          ),
                                                          Expanded(
                                                            child: Column(
                                                              crossAxisAlignment:
                                                                  CrossAxisAlignment
                                                                      .start,
                                                              children: [
                                                                Text(
                                                                  option['product_name']
                                                                          ?.toString() ??
                                                                      '',
                                                                  style: const TextStyle(
                                                                    fontSize:
                                                                        13,
                                                                    fontWeight:
                                                                        FontWeight
                                                                            .w600,
                                                                    color:
                                                                        navyDark,
                                                                  ),
                                                                ),
                                                                Text(
                                                                  'Stock: $stock units  •  Cost: ${_currency(cost)}',
                                                                  style: const TextStyle(
                                                                    fontSize:
                                                                        11,
                                                                    color: Color(
                                                                      0xFF64748B,
                                                                    ),
                                                                  ),
                                                                ),
                                                              ],
                                                            ),
                                                          ),
                                                        ],
                                                      ),
                                                    ),
                                                  );
                                                },
                                              ),
                                            ),
                                          ),
                                        );
                                      },
                                      fieldViewBuilder:
                                          (_, textCtrl, focusNode, _) {
                                            return TextField(
                                              controller: textCtrl,
                                              focusNode: focusNode,
                                              onChanged: (v) {
                                                prodNameCtrl.text = v;
                                                selectedProductId = null;
                                              },
                                              decoration: inputDec(
                                                hint: 'Type or search product name',
                                                prefixIcon: const Icon(
                                                  Icons.search_rounded,
                                                  size: 18,
                                                  color: sidebarBlue,
                                                ),
                                              ),
                                            );
                                          },
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 10),
                                Expanded(
                                  flex: 1,
                                  child: fieldBox(
                                    label: 'Qty',
                                    isRequired: true,
                                    child: TextField(
                                      controller: prodQtyCtrl,
                                      keyboardType:
                                          const TextInputType.numberWithOptions(
                                            decimal: true,
                                          ),
                                      decoration: inputDec(
                                        hint: '1',
                                        prefixIcon: const Icon(
                                          Icons.numbers_rounded,
                                          size: 18,
                                          color: Color(0xFF64748B),
                                        ),
                                      ),
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 10),
                                Expanded(
                                  flex: 2,
                                  child: fieldBox(
                                    label: 'Unit Cost',
                                    isRequired: true,
                                    child: TextField(
                                      controller: prodCostCtrl,
                                      keyboardType:
                                          const TextInputType.numberWithOptions(
                                            decimal: true,
                                          ),
                                      decoration: inputDec(
                                        hint: '0.00',
                                        prefixIcon: const Icon(
                                          Icons.currency_rupee_rounded,
                                          size: 18,
                                          color: Color(0xFF64748B),
                                        ),
                                      ),
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 10),
                                ElevatedButton.icon(
                                  onPressed: addProductRow,
                                  icon: const Icon(
                                    Icons.add_shopping_cart_rounded,
                                    size: 18,
                                  ),
                                  label: const Text(
                                    'Add Item',
                                    style: TextStyle(
                                      fontWeight: FontWeight.w700,
                                    ),
                                  ),
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: sidebarBlue,
                                    foregroundColor: Colors.white,
                                    elevation: 0,
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 18,
                                      vertical: 12.5,
                                    ),
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(9),
                                    ),
                                  ),
                                ),
                              ],
                            ),

                          const SizedBox(height: 12),

                          // Items List Container
                          if (items.isEmpty)
                            Container(
                              width: double.infinity,
                              padding: const EdgeInsets.symmetric(
                                vertical: 22,
                                horizontal: 16,
                              ),
                              decoration: BoxDecoration(
                                color: Colors.white,
                                borderRadius: BorderRadius.circular(10),
                                border: Border.all(
                                  color: const Color(0xFFE2E8F0),
                                ),
                              ),
                              child: const Column(
                                children: [
                                  Icon(
                                    Icons.shopping_bag_outlined,
                                    size: 32,
                                    color: Color(0xFF94A3B8),
                                  ),
                                  SizedBox(height: 8),
                                  Text(
                                    'No products added yet',
                                    style: TextStyle(
                                      fontSize: 13.5,
                                      fontWeight: FontWeight.w600,
                                      color: navyDark,
                                    ),
                                  ),
                                  SizedBox(height: 3),
                                  Text(
                                    'Search or type a product name above, enter quantity & unit cost, then click "Add Item".',
                                    textAlign: TextAlign.center,
                                    style: TextStyle(
                                      fontSize: 11.5,
                                      color: Color(0xFF64748B),
                                    ),
                                  ),
                                ],
                              ),
                            )
                          else
                            Container(
                              decoration: BoxDecoration(
                                color: Colors.white,
                                borderRadius: BorderRadius.circular(10),
                                border: Border.all(
                                  color: const Color(0xFFE2E8F0),
                                ),
                              ),
                              child: Column(
                                children: [
                                  // Table Header
                                  Container(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 14,
                                      vertical: 9,
                                    ),
                                    decoration: const BoxDecoration(
                                      color: Color(0xFFF1F5F9),
                                      borderRadius: BorderRadius.vertical(
                                        top: Radius.circular(9),
                                      ),
                                    ),
                                    child: const Row(
                                      children: [
                                        Expanded(
                                          flex: 4,
                                          child: Text(
                                            'PRODUCT / ITEM',
                                            style: TextStyle(
                                              fontSize: 11,
                                              fontWeight: FontWeight.w700,
                                              color: Color(0xFF475569),
                                            ),
                                          ),
                                        ),
                                        Expanded(
                                          flex: 2,
                                          child: Text(
                                            'QUANTITY',
                                            style: TextStyle(
                                              fontSize: 11,
                                              fontWeight: FontWeight.w700,
                                              color: Color(0xFF475569),
                                            ),
                                          ),
                                        ),
                                        Expanded(
                                          flex: 2,
                                          child: Text(
                                            'UNIT COST',
                                            style: TextStyle(
                                              fontSize: 11,
                                              fontWeight: FontWeight.w700,
                                              color: Color(0xFF475569),
                                            ),
                                          ),
                                        ),
                                        Expanded(
                                          flex: 2,
                                          child: Text(
                                            'TOTAL',
                                            textAlign: TextAlign.right,
                                            style: TextStyle(
                                              fontSize: 11,
                                              fontWeight: FontWeight.w700,
                                              color: Color(0xFF475569),
                                            ),
                                          ),
                                        ),
                                        SizedBox(width: 44),
                                      ],
                                    ),
                                  ),
                                  // Item Rows
                                  ...List.generate(items.length, (i) {
                                    final it = items[i];
                                    final lineTotal =
                                        (it['price'] as double) *
                                        (it['quantity'] as double);
                                    return Container(
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 14,
                                        vertical: 8,
                                      ),
                                      decoration: BoxDecoration(
                                        border: Border(
                                          top: BorderSide(
                                            color: i == 0
                                                ? Colors.transparent
                                                : const Color(0xFFF1F5F9),
                                          ),
                                        ),
                                      ),
                                      child: Row(
                                        children: [
                                          Expanded(
                                            flex: 4,
                                            child: Row(
                                              children: [
                                                const Icon(
                                                  Icons.circle,
                                                  size: 7,
                                                  color: sidebarBlue,
                                                ),
                                                const SizedBox(width: 8),
                                                Expanded(
                                                  child: Text(
                                                    it['product_name']
                                                        .toString(),
                                                    style: const TextStyle(
                                                      fontSize: 13,
                                                      fontWeight:
                                                          FontWeight.w600,
                                                      color: navyDark,
                                                    ),
                                                  ),
                                                ),
                                              ],
                                            ),
                                          ),
                                          Expanded(
                                            flex: 2,
                                            child: Container(
                                              padding:
                                                  const EdgeInsets.symmetric(
                                                    horizontal: 8,
                                                    vertical: 3,
                                                  ),
                                              decoration: BoxDecoration(
                                                color: const Color(0xFFF1F5F9),
                                                borderRadius:
                                                    BorderRadius.circular(6),
                                              ),
                                              child: Text(
                                                '${it['quantity']} Units',
                                                style: const TextStyle(
                                                  fontSize: 12,
                                                  fontWeight: FontWeight.w600,
                                                  color: Color(0xFF334155),
                                                ),
                                              ),
                                            ),
                                          ),
                                          Expanded(
                                            flex: 2,
                                            child: Text(
                                              _currency(it['price']),
                                              style: const TextStyle(
                                                fontSize: 12.5,
                                                color: Color(0xFF475569),
                                              ),
                                            ),
                                          ),
                                          Expanded(
                                            flex: 2,
                                            child: Text(
                                              _currency(lineTotal),
                                              textAlign: TextAlign.right,
                                              style: const TextStyle(
                                                fontSize: 13,
                                                fontWeight: FontWeight.w700,
                                                color: navyDark,
                                              ),
                                            ),
                                          ),
                                          SizedBox(
                                            width: 44,
                                            child: IconButton(
                                              icon: const Icon(
                                                Icons.delete_outline_rounded,
                                                size: 19,
                                                color: Colors.red,
                                              ),
                                              tooltip: 'Remove',
                                              onPressed: () => setDialogState(
                                                () => items.removeAt(i),
                                              ),
                                            ),
                                          ),
                                        ],
                                      ),
                                    );
                                  }),
                                ],
                              ),
                            ),
                        ],
                      ),
                    ),

                    const SizedBox(height: 14),

                    // 3. PAYMENT & SUMMARY CARD
                    Container(
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        color: const Color(0xFFF8FAFC),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: const Color(0xFFE2E8F0)),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          stepBadge('3', 'Payment & Financial Reconciliation'),
                          const SizedBox(height: 12),
                          Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    fieldBox(
                                      label: 'Amount Paid (₹)',
                                      isRequired: true,
                                      child: TextField(
                                        controller: amountPaidCtrl,
                                        keyboardType:
                                            const TextInputType.numberWithOptions(
                                              decimal: true,
                                            ),
                                        onChanged: (_) => setDialogState(() {}),
                                        decoration: inputDec(
                                          hint: '0.00',
                                          prefixIcon: const Icon(
                                            Icons.currency_rupee_rounded,
                                            size: 18,
                                            color: sidebarBlue,
                                          ),
                                        ),
                                      ),
                                    ),
                                    const SizedBox(height: 6),
                                    Row(
                                      children: [
                                        InkWell(
                                          onTap: () {
                                            amountPaidCtrl.text = totalPurchase
                                                .toStringAsFixed(2);
                                            setDialogState(() {});
                                          },
                                          borderRadius: BorderRadius.circular(
                                            6,
                                          ),
                                          child: Container(
                                            padding: const EdgeInsets.symmetric(
                                              horizontal: 7,
                                              vertical: 3,
                                            ),
                                            decoration: BoxDecoration(
                                              color: const Color(0xFFEFF6FF),
                                              borderRadius:
                                                  BorderRadius.circular(6),
                                              border: Border.all(
                                                color: const Color(0xFFBFDBFE),
                                              ),
                                            ),
                                            child: const Text(
                                              '⚡ Pay in Full',
                                              style: TextStyle(
                                                fontSize: 10.5,
                                                fontWeight: FontWeight.w700,
                                                color: sidebarBlue,
                                              ),
                                            ),
                                          ),
                                        ),
                                        const SizedBox(width: 8),
                                        InkWell(
                                          onTap: () {
                                            amountPaidCtrl.text = '0';
                                            setDialogState(() {});
                                          },
                                          borderRadius: BorderRadius.circular(
                                            6,
                                          ),
                                          child: Container(
                                            padding: const EdgeInsets.symmetric(
                                              horizontal: 7,
                                              vertical: 3,
                                            ),
                                            decoration: BoxDecoration(
                                              color: const Color(0xFFF1F5F9),
                                              borderRadius:
                                                  BorderRadius.circular(6),
                                              border: Border.all(
                                                color: const Color(0xFFCBD5E1),
                                              ),
                                            ),
                                            child: const Text(
                                              'Credit / Unpaid',
                                              style: TextStyle(
                                                fontSize: 10.5,
                                                fontWeight: FontWeight.w600,
                                                color: Color(0xFF475569),
                                              ),
                                            ),
                                          ),
                                        ),
                                      ],
                                    ),
                                  ],
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: fieldBox(
                                  label: 'Payment Method',
                                  child: DropdownButtonFormField<String>(
                                    initialValue: paymentMethod,
                                    decoration: inputDec(
                                      hint: 'BANK',
                                      prefixIcon: const Icon(
                                        Icons.payment_rounded,
                                        size: 18,
                                        color: sidebarBlue,
                                      ),
                                    ),
                                    items:
                                        [
                                              'BANK',
                                              'CASH',
                                              'UPI',
                                              'CARD',
                                              'CHEQUE',
                                            ]
                                            .map(
                                              (m) => DropdownMenuItem(
                                                value: m,
                                                child: Text(
                                                  m,
                                                  style: const TextStyle(
                                                    fontSize: 13,
                                                    fontWeight: FontWeight.w600,
                                                  ),
                                                ),
                                              ),
                                            )
                                            .toList(),
                                    onChanged: (val) {
                                      if (val != null) {
                                        setDialogState(
                                          () => paymentMethod = val,
                                        );
                                      }
                                    },
                                  ),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 14),

                          // 3-Card Summary Container
                          Container(
                            padding: const EdgeInsets.all(14),
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(10),
                              border: Border.all(
                                color: const Color(0xFFE2E8F0),
                              ),
                            ),
                            child: Row(
                              children: [
                                // Total Purchase
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      const Row(
                                        children: [
                                          Icon(
                                            Icons.receipt_long_rounded,
                                            size: 15,
                                            color: Color(0xFF64748B),
                                          ),
                                          SizedBox(width: 5),
                                          Text(
                                            'Total Purchase',
                                            style: TextStyle(
                                              fontSize: 11.5,
                                              color: Color(0xFF64748B),
                                            ),
                                          ),
                                        ],
                                      ),
                                      const SizedBox(height: 4),
                                      Text(
                                        _currency(totalPurchase),
                                        style: const TextStyle(
                                          fontSize: 16,
                                          fontWeight: FontWeight.w800,
                                          color: navyDark,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                Container(
                                  width: 1,
                                  height: 38,
                                  color: const Color(0xFFE2E8F0),
                                ),
                                // Amount Paid
                                Expanded(
                                  child: Padding(
                                    padding: const EdgeInsets.only(left: 14),
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        const Row(
                                          children: [
                                            Icon(
                                              Icons.payments_outlined,
                                              size: 15,
                                              color: primaryGreen,
                                            ),
                                            SizedBox(width: 5),
                                            Text(
                                              'Amount Paid',
                                              style: TextStyle(
                                                fontSize: 11.5,
                                                color: Color(0xFF64748B),
                                              ),
                                            ),
                                          ],
                                        ),
                                        const SizedBox(height: 4),
                                        Text(
                                          _currency(amountPaid),
                                          style: const TextStyle(
                                            fontSize: 16,
                                            fontWeight: FontWeight.w800,
                                            color: primaryGreen,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                                Container(
                                  width: 1,
                                  height: 38,
                                  color: const Color(0xFFE2E8F0),
                                ),
                                // Balance Due
                                Expanded(
                                  child: Padding(
                                    padding: const EdgeInsets.only(left: 14),
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Row(
                                          children: [
                                            Icon(
                                              Icons
                                                  .account_balance_wallet_outlined,
                                              size: 15,
                                              color: balanceDue > 0
                                                  ? const Color(0xFFD97706)
                                                  : primaryGreen,
                                            ),
                                            const SizedBox(width: 5),
                                            Text(
                                              'Balance Due',
                                              style: TextStyle(
                                                fontSize: 11.5,
                                                color: balanceDue > 0
                                                    ? const Color(0xFFD97706)
                                                    : primaryGreen,
                                                fontWeight: FontWeight.w600,
                                              ),
                                            ),
                                          ],
                                        ),
                                        const SizedBox(height: 4),
                                        Text(
                                          _currency(balanceDue),
                                          style: TextStyle(
                                            fontSize: 16,
                                            fontWeight: FontWeight.w800,
                                            color: balanceDue > 0
                                                ? const Color(0xFFDC2626)
                                                : primaryGreen,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),

                    const SizedBox(height: 20),

                    // FOOTER ACTIONS
                    Row(
                      mainAxisAlignment: MainAxisAlignment.end,
                      children: [
                        OutlinedButton(
                          onPressed: isSaving
                              ? null
                              : () => Navigator.pop(dialogCtx),
                          style: OutlinedButton.styleFrom(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 20,
                              vertical: 13,
                            ),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(9),
                            ),
                            side: const BorderSide(color: Color(0xFFCBD5E1)),
                          ),
                          child: const Text(
                            'Cancel',
                            style: TextStyle(
                              color: Color(0xFF475569),
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        ElevatedButton.icon(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: sidebarBlue,
                            foregroundColor: Colors.white,
                            elevation: 1,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(9),
                            ),
                            padding: const EdgeInsets.symmetric(
                              horizontal: 24,
                              vertical: 13,
                            ),
                          ),
                          onPressed: isSaving
                              ? null
                              : () async {
                                  final suppName = supplierNameCtrl.text.trim();
                                  final suppMobile = supplierMobileCtrl.text
                                      .trim();
                                  if (suppName.isEmpty || suppMobile.isEmpty) {
                                    AppToast.showWarning(
                                      context,
                                      title: 'Missing Details',
                                      message: 'Please enter Supplier Name and Mobile Number.',
                                    );
                                    return;
                                  }
                                  if (items.isEmpty) {
                                    AppToast.showWarning(
                                      context,
                                      title: 'No Products Added',
                                      message: 'Please add at least one product before saving.',
                                    );
                                    return;
                                  }

                                  setDialogState(() => isSaving = true);
                                  try {
                                    int? supplierId = selectedSupplierId;
                                    if (supplierId == null) {
                                      final existingSupp = _suppliers.where(
                                        (s) =>
                                            (s['name'] ?? '')
                                                .toString()
                                                .trim()
                                                .toLowerCase() ==
                                            suppName.toLowerCase(),
                                      );
                                      if (existingSupp.isNotEmpty) {
                                        supplierId = int.tryParse(
                                          existingSupp.first['id']
                                                  ?.toString() ??
                                              '',
                                        );
                                      } else {
                                        final suppRes = await _api.post(
                                          '/suppliers',
                                          {
                                            'name': suppName,
                                            'phone': suppMobile,
                                            'address': supplierAddressCtrl.text
                                                .trim(),
                                          },
                                        );
                                        if (suppRes is Map) {
                                          if (suppRes['id'] != null) {
                                            supplierId = int.tryParse(
                                              suppRes['id'].toString(),
                                            );
                                          } else if (suppRes['data'] is Map &&
                                              suppRes['data']['id'] != null) {
                                            supplierId = int.tryParse(
                                              suppRes['data']['id'].toString(),
                                            );
                                          }
                                        }
                                      }
                                    }

                                    final resolvedItems =
                                        <Map<String, dynamic>>[];
                                    for (final it in items) {
                                      int? pid = it['product_id'] != null
                                          ? int.tryParse(
                                              it['product_id'].toString(),
                                            )
                                          : null;
                                      final pName = it['product_name']
                                          .toString()
                                          .trim();
                                      final cleanName = pName
                                          .toLowerCase()
                                          .replaceAll(' ', '');

                                      if (pid == null) {
                                        final existingProd = _products.where((
                                          p,
                                        ) {
                                          final name = (p['product_name'] ?? '')
                                              .toString()
                                              .trim()
                                              .toLowerCase();
                                          return name == pName.toLowerCase() ||
                                              name.replaceAll(' ', '') ==
                                                  cleanName;
                                        });
                                        if (existingProd.isNotEmpty) {
                                          pid = int.tryParse(
                                            existingProd.first['id']
                                                    ?.toString() ??
                                                '',
                                          );
                                        } else {
                                          final pRes = await _api.post(
                                            '/products',
                                            {
                                              'product_name': pName,
                                              'cost_price': it['price'],
                                              'selling_price':
                                                  (it['price'] is num &&
                                                      (it['price'] as num) > 0)
                                                  ? (it['price'] as num) * 1.15
                                                  : it['price'],
                                              'stock_qty': 0,
                                            },
                                          );
                                          if (pRes is Map) {
                                            if (pRes['id'] != null) {
                                              pid = int.tryParse(
                                                pRes['id'].toString(),
                                              );
                                            } else if (pRes['data'] is Map &&
                                                pRes['data']['id'] != null) {
                                              pid = int.tryParse(
                                                pRes['data']['id'].toString(),
                                              );
                                            }
                                          }
                                        }
                                      }
                                      resolvedItems.add({
                                        if (pid != null && pid > 0)
                                          'product_id': pid,
                                        'product_name': pName,
                                        'quantity': it['quantity'],
                                        'price': it['price'],
                                      });
                                    }

                                    final now = DateTime.now();
                                    final purchaseNo =
                                        'PO-${now.year}${now.month.toString().padLeft(2, '0')}${now.day.toString().padLeft(2, '0')}-${now.millisecondsSinceEpoch.toString().substring(7)}';

                                    await _api.post('/purchases', {
                                      'purchase_no': purchaseNo,
                                      'supplier_id': supplierId,
                                      'tax_amount': 0,
                                      'purchase_date': now
                                          .toIso8601String()
                                          .substring(0, 10),
                                      'notes':
                                          'Paid: ${_currency(amountPaid)} via $paymentMethod | Balance Due: ${_currency(balanceDue)}',
                                      'items': resolvedItems,
                                    });

                                    if (!dialogCtx.mounted) return;
                                    Navigator.pop(dialogCtx);
                                    if (!mounted) return;
                                    AppToast.showSuccess(
                                      context,
                                      title: 'Purchase Recorded!',
                                      message: 'Purchase saved and inventory stock updated successfully.',
                                    );
                                    _loadData();
                                  } catch (e) {
                                    setDialogState(() => isSaving = false);
                                    if (!mounted) return;
                                    AppToast.showError(
                                      context,
                                      title: 'Purchase Failed',
                                      message: e.toString().replaceAll(
                                        'Exception: ',
                                        '',
                                      ),
                                    );
                                  }
                                },
                          icon: isSaving
                              ? const SizedBox(
                                  width: 18,
                                  height: 18,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                    color: Colors.white,
                                  ),
                                )
                              : const Icon(
                                  Icons.check_circle_rounded,
                                  size: 19,
                                ),
                          label: Text(
                            isSaving
                                ? 'Updating Inventory...'
                                : 'Save & Update Stock',
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

  void _showPurchaseDetail(dynamic purchase) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        title: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              'Purchase Order: ${purchase['purchase_no'] ?? '-'}',
              style: const TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 16,
                color: Colors.black,
              ),
            ),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
              decoration: BoxDecoration(
                color: const Color(0xFFEFF6FF),
                borderRadius: BorderRadius.circular(6),
                border: Border.all(color: const Color(0xFFBFDBFE)),
              ),
              child: const Text(
                'Received',
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.bold,
                  color: sidebarBlue,
                ),
              ),
            ),
          ],
        ),
        content: SizedBox(
          width: 480,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _detailRow(
                'Supplier',
                purchase['supplier_name'] ?? 'Direct / Local Supplier',
              ),
              const SizedBox(height: 8),
              _detailRow(
                'Purchase Date',
                _formatDate(purchase['purchase_date']),
              ),
              const SizedBox(height: 8),
              _detailRow('Subtotal', _currency(purchase['subtotal'])),
              const SizedBox(height: 8),
              _detailRow('Tax Amount', _currency(purchase['tax_amount'])),
              const Divider(height: 24),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text(
                    'Total Amount',
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 15,
                      color: Colors.black,
                    ),
                  ),
                  Text(
                    _currency(purchase['total_amount']),
                    style: const TextStyle(
                      fontWeight: FontWeight.w900,
                      fontSize: 17,
                      color: primaryGreen,
                    ),
                  ),
                ],
              ),
              if (purchase['notes'] != null &&
                  purchase['notes'].toString().isNotEmpty) ...[
                const SizedBox(height: 12),
                Text(
                  'Notes: ${purchase['notes']}',
                  style: const TextStyle(fontSize: 12, color: Colors.grey),
                ),
              ],
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Close', style: TextStyle(color: Colors.black87)),
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
          style: const TextStyle(color: Color(0xFF6B7280), fontSize: 13),
        ),
        Text(
          value,
          style: const TextStyle(
            fontWeight: FontWeight.w600,
            color: Colors.black,
            fontSize: 13,
          ),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final width = MediaQuery.sizeOf(context).width;
    final isNarrowHeader = width < 760;
    final isCompactFilter = width < 960;

    return Container(
      color: background,
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(20, 18, 20, 30),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // 1. TOP HEADER (Purchases)
            if (isNarrowHeader) ...[
              const Text(
                'Purchases',
                style: TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.w800,
                  color: navyDark,
                ),
              ),
              const SizedBox(height: 4),
              const Text(
                'Receive stock, reconcile supplier invoices, and keep every purchase traceable.',
                style: TextStyle(fontSize: 13, color: Color(0xFF64748B)),
              ),
              const SizedBox(height: 12),
              ElevatedButton.icon(
                onPressed: _showNewPurchaseDialog,
                icon: const Icon(Icons.add_rounded, size: 18),
                label: const Text(
                  'Record purchase',
                  style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700),
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: sidebarBlue,
                  foregroundColor: Colors.white,
                  elevation: 0,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 11,
                  ),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
              ),
            ] else
              Row(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  const Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Purchases',
                          style: TextStyle(
                            fontSize: 26,
                            fontWeight: FontWeight.w800,
                            color: navyDark,
                          ),
                        ),
                        SizedBox(height: 3),
                        Text(
                          'Receive stock, reconcile supplier invoices, and keep every purchase traceable.',
                          style: TextStyle(
                            fontSize: 13,
                            color: Color(0xFF64748B),
                          ),
                        ),
                      ],
                    ),
                  ),
                  ElevatedButton.icon(
                    onPressed: _showNewPurchaseDialog,
                    icon: const Icon(Icons.add_rounded, size: 18),
                    label: const Text(
                      'Record purchase',
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: sidebarBlue,
                      foregroundColor: Colors.white,
                      elevation: 0,
                      padding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 11,
                      ),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                    ),
                  ),
                ],
              ),
            const SizedBox(height: 16),

            // 2. FOUR METRIC CARDS
            LayoutBuilder(
              builder: (context, constraints) {
                final w = constraints.maxWidth;
                final cards = <Widget>[
                  _StatCard(
                    title: 'PURCHASE RECORDS',
                    amount: '${_filteredPurchases.length}',
                    percentage: 'Matches',
                    icon: Icons.inventory_2_outlined,
                    colors: const [Color(0xFF6250F4), Color(0xFF4033C7)],
                  ),
                  _StatCard(
                    title: 'PURCHASE VALUE',
                    amount: _currency(_totalPurchaseAmount),
                    percentage: 'Total',
                    icon: Icons.currency_rupee_rounded,
                    colors: const [Color(0xFF22C981), Color(0xFF079B63)],
                  ),
                  _StatCard(
                    title: 'PENDING PAYMENTS',
                    amount: _currency(_totalPendingPayments),
                    percentage: 'Due',
                    icon: Icons.warning_amber_rounded,
                    colors: const [Color(0xFFFFAC16), Color(0xFFFF8C00)],
                  ),
                  _StatCard(
                    title: 'SUPPLIERS',
                    amount: '$_uniqueSuppliersCount',
                    percentage: 'Unique',
                    icon: Icons.groups_outlined,
                    colors: const [Color(0xFFFF4C72), Color(0xFFE52F59)],
                  ),
                ];

                if (w >= 700) {
                  return Row(
                    children: [
                      for (int i = 0; i < cards.length; i++) ...[
                        if (i > 0) const SizedBox(width: 10),
                        Expanded(child: cards[i]),
                      ],
                    ],
                  );
                } else if (w >= 450) {
                  return Column(
                    children: [
                      Row(
                        children: [
                          Expanded(child: cards[0]),
                          const SizedBox(width: 10),
                          Expanded(child: cards[1]),
                        ],
                      ),
                      const SizedBox(height: 10),
                      Row(
                        children: [
                          Expanded(child: cards[2]),
                          const SizedBox(width: 10),
                          Expanded(child: cards[3]),
                        ],
                      ),
                    ],
                  );
                } else {
                  return Column(
                    children: [
                      for (int i = 0; i < cards.length; i++) ...[
                        if (i > 0) const SizedBox(height: 12),
                        cards[i],
                      ],
                    ],
                  );
                }
              },
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
                      onChanged: (val) => setState(() => _searchQuery = val),
                      style: const TextStyle(color: navyDark, fontSize: 13),
                      decoration: InputDecoration(
                        hintText: 'Search purchase or supplier...',
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

                  final fromDateBtn = _buildDatePickerChip(
                    label: _formatDateLabel(_fromDate, 'From date'),
                    hasValue: _fromDate != null,
                    onTap: () => _pickDate(isFrom: true),
                    onClear: () => setState(() => _fromDate = null),
                  );

                  final toDateBtn = _buildDatePickerChip(
                    label: _formatDateLabel(_toDate, 'To date'),
                    hasValue: _toDate != null,
                    onTap: () => _pickDate(isFrom: false),
                    onClear: () => setState(() => _toDate = null),
                  );

                  final statusDropdown = SizedBox(
                    height: 40,
                    child: DropdownButtonFormField<String>(
                      initialValue: _statusFilter,
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
                          child: Text('All payment states'),
                        ),
                        DropdownMenuItem(
                          value: 'Paid',
                          child: Text('Received / Paid'),
                        ),
                        DropdownMenuItem(
                          value: 'Partial',
                          child: Text('Partial'),
                        ),
                        DropdownMenuItem(
                          value: 'Unpaid',
                          child: Text('Unpaid'),
                        ),
                      ],
                      onChanged: (val) {
                        if (val != null) setState(() => _statusFilter = val);
                      },
                    ),
                  );

                  final clearBtn = SizedBox(
                    height: 40,
                    child: OutlinedButton(
                      onPressed: _clearFilters,
                      style: OutlinedButton.styleFrom(
                        foregroundColor: const Color(0xFF475569),
                        side: const BorderSide(color: Color(0xFFE2E8F0)),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                        padding: const EdgeInsets.symmetric(horizontal: 14),
                      ),
                      child: const Text(
                        'Clear filters',
                        style: TextStyle(
                          fontSize: 12.5,
                          fontWeight: FontWeight.w600,
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
                            Expanded(child: fromDateBtn),
                            const SizedBox(width: 8),
                            Expanded(child: toDateBtn),
                          ],
                        ),
                        const SizedBox(height: 10),
                        Row(
                          children: [
                            Expanded(child: statusDropdown),
                            const SizedBox(width: 8),
                            clearBtn,
                          ],
                        ),
                      ],
                    );
                  }

                  return Row(
                    children: [
                      Expanded(flex: 3, child: searchField),
                      const SizedBox(width: 10),
                      Expanded(flex: 2, child: fromDateBtn),
                      const SizedBox(width: 10),
                      Expanded(flex: 2, child: toDateBtn),
                      const SizedBox(width: 10),
                      Expanded(flex: 2, child: statusDropdown),
                      const SizedBox(width: 10),
                      clearBtn,
                    ],
                  );
                },
              ),
            ),
            const SizedBox(height: 14),

            // 4. PURCHASE REGISTER TABLE CARD
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
                    padding: const EdgeInsets.fromLTRB(18, 16, 18, 14),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Purchase register',
                                style: TextStyle(
                                  fontSize: 17,
                                  fontWeight: FontWeight.w800,
                                  color: navyDark,
                                ),
                              ),
                              SizedBox(height: 2),
                              Text(
                                'Review supplier invoices and received stock.',
                                style: TextStyle(
                                  fontSize: 12,
                                  color: Color(0xFF64748B),
                                ),
                              ),
                            ],
                          ),
                        ),
                        OutlinedButton.icon(
                          onPressed: _loadData,
                          icon: const Icon(Icons.refresh_rounded, size: 16),
                          label: const Text(
                            'Refresh',
                            style: TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          style: OutlinedButton.styleFrom(
                            foregroundColor: navyDark,
                            side: const BorderSide(color: Color(0xFFE2E8F0)),
                            padding: const EdgeInsets.symmetric(
                              horizontal: 14,
                              vertical: 10,
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
                            onPressed: _loadData,
                            child: const Text('Try Again'),
                          ),
                        ],
                      ),
                    )
                  else if (_filteredPurchases.isEmpty)
                    Padding(
                      padding: const EdgeInsets.all(36),
                      child: Column(
                        children: [
                          const Icon(
                            Icons.shopping_bag_outlined,
                            size: 44,
                            color: Colors.grey,
                          ),
                          const SizedBox(height: 10),
                          const Text(
                            'No purchase orders found',
                            style: TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const SizedBox(height: 4),
                          const Text(
                            'Record stock additions from paint suppliers to track purchases.',
                            style: TextStyle(fontSize: 12, color: Colors.grey),
                          ),
                          const SizedBox(height: 14),
                          ElevatedButton.icon(
                            onPressed: _showNewPurchaseDialog,
                            icon: const Icon(Icons.add),
                            label: const Text('Record First Purchase'),
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
                        final isNarrow = width < 960;
                        final tableBody = Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            // Table Header
                            Container(
                              color: const Color(0xFFF8FAFC),
                              padding: const EdgeInsets.symmetric(
                                horizontal: 18,
                                vertical: 12,
                              ),
                              child: const Row(
                                children: [
                                  Expanded(
                                    flex: 3,
                                    child: Text(
                                      'PURCHASE NO.',
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
                                      'SUPPLIER',
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
                                      'DATE',
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
                                      'TOTAL COST',
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
                                      'AMOUNT PAID',
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
                                      'BALANCE',
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
                                    width: 60,
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

                            // Rows
                            ...List.generate(_filteredPurchases.length, (idx) {
                              final p = _filteredPurchases[idx];
                              final total =
                                  double.tryParse(
                                    p['total_amount']?.toString() ?? '0',
                                  ) ??
                                  0;
                              final paid =
                                  double.tryParse(
                                    p['paid_amount']?.toString() ?? '',
                                  ) ??
                                  total;
                              final bal =
                                  double.tryParse(
                                    p['balance_amount']?.toString() ?? '',
                                  ) ??
                                  (total - paid);
                              final status =
                                  (p['payment_status']
                                          ?.toString()
                                          .trim()
                                          .isNotEmpty ==
                                      true)
                                  ? p['payment_status'].toString()
                                  : (bal <= 0
                                        ? 'Received'
                                        : (paid > 0 ? 'Partial' : 'Unpaid'));
                              final isReceived =
                                  status.toLowerCase() == 'received' ||
                                  status.toLowerCase() == 'paid';
                              final isPartial =
                                  status.toLowerCase() == 'partial';
                              final supplierName = (p['supplier_name'] ?? '')
                                  .toString()
                                  .trim();

                              return Container(
                                decoration: BoxDecoration(
                                  color: Colors.white,
                                  border: Border(
                                    bottom: BorderSide(
                                      color:
                                          idx == _filteredPurchases.length - 1
                                          ? Colors.transparent
                                          : const Color(0xFFF1F5F9),
                                    ),
                                  ),
                                ),
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 18,
                                  vertical: 14,
                                ),
                                child: Row(
                                  children: [
                                    Expanded(
                                      flex: 3,
                                      child: Text(
                                        p['purchase_no'] ?? '-',
                                        style: const TextStyle(
                                          fontSize: 13,
                                          fontWeight: FontWeight.w700,
                                          color: navyDark,
                                        ),
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                    ),
                                    Expanded(
                                      flex: 3,
                                      child: Text(
                                        supplierName.isNotEmpty &&
                                                supplierName != '-'
                                            ? supplierName
                                            : 'Direct / Local Vendor',
                                        style: const TextStyle(
                                          fontSize: 13,
                                          color: Color(0xFF334155),
                                        ),
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                    ),
                                    Expanded(
                                      flex: 2,
                                      child: Text(
                                        _formatDate(p['purchase_date']),
                                        style: const TextStyle(
                                          fontSize: 12.5,
                                          color: Color(0xFF64748B),
                                        ),
                                      ),
                                    ),
                                    Expanded(
                                      flex: 2,
                                      child: Text(
                                        _currency(total),
                                        style: const TextStyle(
                                          fontSize: 13,
                                          fontWeight: FontWeight.w700,
                                          color: navyDark,
                                        ),
                                      ),
                                    ),
                                    Expanded(
                                      flex: 2,
                                      child: Text(
                                        _currency(paid),
                                        style: const TextStyle(
                                          fontSize: 13,
                                          color: Color(0xFF475569),
                                        ),
                                      ),
                                    ),
                                    Expanded(
                                      flex: 2,
                                      child: Text(
                                        _currency(bal > 0 ? bal : 0),
                                        style: TextStyle(
                                          fontSize: 13,
                                          fontWeight: bal > 0
                                              ? FontWeight.w700
                                              : FontWeight.normal,
                                          color: bal > 0
                                              ? Colors.red.shade600
                                              : const Color(0xFF64748B),
                                        ),
                                      ),
                                    ),
                                    Expanded(
                                      flex: 2,
                                      child: Align(
                                        alignment: Alignment.centerLeft,
                                        child: Container(
                                          padding: const EdgeInsets.symmetric(
                                            horizontal: 9,
                                            vertical: 4,
                                          ),
                                          decoration: BoxDecoration(
                                            color: isReceived
                                                ? const Color(0xFFECFDF5)
                                                : isPartial
                                                ? const Color(0xFFFFFBEB)
                                                : const Color(0xFFFEF2F2),
                                            borderRadius: BorderRadius.circular(
                                              999,
                                            ),
                                          ),
                                          child: Text(
                                            status.toUpperCase(),
                                            style: TextStyle(
                                              fontSize: 10.5,
                                              fontWeight: FontWeight.w700,
                                              color: isReceived
                                                  ? const Color(0xFF047857)
                                                  : isPartial
                                                  ? const Color(0xFFB45309)
                                                  : Colors.red.shade700,
                                            ),
                                          ),
                                        ),
                                      ),
                                    ),
                                    SizedBox(
                                      width: 60,
                                      child: Center(
                                        child: PopupMenuButton<String>(
                                          icon: const Icon(
                                            Icons.more_vert_rounded,
                                            size: 18,
                                            color: Color(0xFF475569),
                                          ),
                                          offset: const Offset(0, 40),
                                          color: const Color(0xFF0F0F0F), // Very dark background like the screenshot
                                          shape: RoundedRectangleBorder(
                                            borderRadius: BorderRadius.circular(
                                              12,
                                            ),
                                            side: const BorderSide(
                                              color: Color(0xFF1F1F1F),
                                              width: 1,
                                            ),
                                          ),
                                          onSelected: (value) {
                                            if (value == 'view') {
                                              _showPurchaseDetail(p);
                                            }
                                            // Handle other actions here...
                                          },
                                          itemBuilder: (_) => [
                                            // Header
                                            const PopupMenuItem<String>(
                                              enabled: false,
                                              child: Row(
                                                mainAxisAlignment:
                                                    MainAxisAlignment
                                                        .spaceBetween,
                                                children: [
                                                  Text(
                                                    'Purchase Actions',
                                                    style: TextStyle(
                                                      color: Colors.white,
                                                      fontWeight:
                                                          FontWeight.bold,
                                                      fontSize: 14,
                                                    ),
                                                  ),
                                                  Icon(
                                                    Icons.more_vert,
                                                    color: Colors.white54,
                                                    size: 16,
                                                  ),
                                                ],
                                              ),
                                            ),
                                            const PopupMenuDivider(height: 1),

                                            // Standard actions
                                            _buildActionMenuItem(
                                              'view',
                                              Icons.visibility_outlined,
                                              'View Purchase Details',
                                              Colors.white,
                                            ),
                                            _buildActionMenuItem(
                                              'edit',
                                              Icons.edit_outlined,
                                              'Edit Purchase',
                                              Colors.white,
                                            ),
                                            _buildActionMenuItem(
                                              'pay',
                                              Icons
                                                  .account_balance_wallet_outlined,
                                              'Record Payment',
                                              Colors.white,
                                            ),
                                            _buildActionMenuItem(
                                              'history',
                                              Icons.history_rounded,
                                              'Payment History',
                                              Colors.white,
                                            ),
                                            _buildActionMenuItem(
                                              'stock',
                                              Icons.inventory_2_outlined,
                                              'View Stock Details',
                                              Colors.white,
                                            ),
                                            _buildActionMenuItem(
                                              'print',
                                              Icons.print_outlined,
                                              'Print Purchase Invoice',
                                              Colors.white,
                                            ),
                                            _buildActionMenuItem(
                                              'download',
                                              Icons.download_outlined,
                                              'Download PDF',
                                              Colors.white,
                                            ),

                                            const PopupMenuDivider(height: 1),

                                            // Destructive actions
                                            _buildActionMenuItem(
                                              'return',
                                              Icons.keyboard_return_rounded,
                                              'Return to Supplier',
                                              const Color(0xFFFF5252),
                                            ),
                                            _buildActionMenuItem(
                                              'cancel',
                                              Icons.block_flipped,
                                              'Cancel Purchase',
                                              const Color(0xFFFF5252),
                                            ),
                                          ],
                                        ),
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
                            child: SizedBox(width: 880, child: tableBody),
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

  PopupMenuItem<String> _buildActionMenuItem(
    String value,
    IconData icon,
    String label,
    Color color,
  ) {
    return PopupMenuItem<String>(
      value: value,
      height: 42,
      child: Row(
        children: [
          Icon(icon, size: 18, color: color),
          const SizedBox(width: 12),
          Text(
            label,
            style: TextStyle(
              color: color,
              fontSize: 13,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDatePickerChip({
    required String label,
    required bool hasValue,
    required VoidCallback onTap,
    VoidCallback? onClear,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(8),
      child: Container(
        height: 40,
        padding: const EdgeInsets.symmetric(horizontal: 12),
        decoration: BoxDecoration(
          color: hasValue ? const Color(0xFFEFF6FF) : const Color(0xFFF8FAFC),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: hasValue ? sidebarBlue : const Color(0xFFE2E8F0),
            width: hasValue ? 1.3 : 1.0,
          ),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Flexible(
              child: Text(
                label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontSize: 12.5,
                  color: hasValue ? sidebarBlue : const Color(0xFF64748B),
                  fontWeight: hasValue ? FontWeight.w700 : FontWeight.normal,
                ),
              ),
            ),
            const SizedBox(width: 6),
            if (hasValue && onClear != null)
              InkWell(
                onTap: onClear,
                borderRadius: BorderRadius.circular(10),
                child: const Padding(
                  padding: EdgeInsets.all(2),
                  child: Icon(Icons.cancel, size: 16, color: Color(0xFF64748B)),
                ),
              )
            else
              Icon(
                Icons.calendar_today_outlined,
                size: 15,
                color: hasValue ? sidebarBlue : const Color(0xFF64748B),
              ),
          ],
        ),
      ),
    );
  }
}

// STATISTICS CARD
class _StatCard extends StatelessWidget {
  final String title;
  final String amount;
  final String percentage;
  final IconData icon;
  final List<Color> colors;

  const _StatCard({
    required this.title,
    required this.amount,
    required this.percentage,
    required this.icon,
    required this.colors,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: colors,
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: colors.first.withValues(alpha: 0.2),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.2),
              shape: BoxShape.circle,
            ),
            child: Icon(icon, color: Colors.white, size: 22),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 2),
                FittedBox(
                  fit: BoxFit.scaleDown,
                  alignment: Alignment.centerLeft,
                  child: Text(
                    amount,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 20,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                ),
                const SizedBox(height: 2),
                Row(
                  children: [
                    const Icon(
                      Icons.arrow_upward,
                      color: Color(0xFF4BFFAA),
                      size: 10,
                    ),
                    Text(
                      ' $percentage',
                      style: const TextStyle(
                        color: Color(0xFF4BFFAA),
                        fontWeight: FontWeight.bold,
                        fontSize: 10,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
