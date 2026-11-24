import 'package:flutter/material.dart';

import 'app_date_picker.dart';
import 'api_service.dart';
import 'app_toast.dart';
import 'slip_downloader.dart';

class SalesPage extends StatefulWidget {
  final String token;
  final String? apiBaseUrl;

  const SalesPage({super.key, required this.token, this.apiBaseUrl});

  @override
  State<SalesPage> createState() => _SalesPageState();
}

class _SalesPageState extends State<SalesPage> {
  late final ApiService _api;
  bool _isLoading = true;
  String? _errorMessage;
  List<dynamic> _sales = [];
  List<dynamic> _customers = [];
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
    _loadSales();
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  Future<void> _loadSales() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final results = await Future.wait([
        _api.get('/sales'),
        _api.get('/customers'),
        _api.get('/products'),
      ]);
      if (!mounted) return;
      setState(() {
        _sales = results[0]['data'] is List ? results[0]['data'] : [];
        _customers = results[1]['data'] is List ? results[1]['data'] : [];
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

  List<dynamic> get _filteredSales {
    return _sales.where((s) {
      final inv = (s['invoice_no'] ?? '').toString().toLowerCase();
      final cust = (s['customer_name'] ?? '').toString().toLowerCase();
      final phone = (s['customer_phone'] ?? s['phone'] ?? '')
          .toString()
          .toLowerCase();
      final method = (s['payment_method'] ?? '').toString().toLowerCase();
      final query = _searchQuery.trim().toLowerCase();

      final matchesQuery =
          query.isEmpty ||
          inv.contains(query) ||
          cust.contains(query) ||
          phone.contains(query) ||
          method.contains(query);

      final status = (s['payment_status'] ?? 'Paid').toString();
      final matchesStatus =
          _statusFilter == 'All' ||
          status.toLowerCase() == _statusFilter.toLowerCase();

      bool matchesDate = true;
      final rawDate = s['sale_date']?.toString().split('T').first;
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

  double get _totalSalesAmount {
    return _filteredSales.fold(0.0, (sum, s) {
      final amt = double.tryParse(s['total_amount']?.toString() ?? '0') ?? 0;
      return sum + amt;
    });
  }

  double get _totalPaidAmount {
    return _filteredSales.fold(0.0, (sum, s) {
      final amt = double.tryParse(s['paid_amount']?.toString() ?? '0') ?? 0;
      return sum + amt;
    });
  }

  double get _totalBalanceAmount {
    return _filteredSales.fold(0.0, (sum, s) {
      final amt = double.tryParse(s['balance_amount']?.toString() ?? '0') ?? 0;
      return sum + amt;
    });
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

  String _formatPrettyDate(dynamic dateStr) {
    if (dateStr == null) return '-';
    final s = dateStr.toString().split('T').first;
    final parsed = DateTime.tryParse(s);
    if (parsed == null) return s;
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
    return '${parsed.day.toString().padLeft(2, '0')} ${months[parsed.month - 1]} ${parsed.year}';
  }

  // ignore: unused_element
  void _showNewSaleDialog() {
    if (_products.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('No products available to create a sale'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    int? selectedCustomerId;
    dynamic selectedProduct = _products.first;
    final qtyCtrl = TextEditingController(text: '1');
    String paymentMethod = 'Cash';
    bool saving = false;

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (dCtx, setDState) {
          final unitPrice =
              double.tryParse(
                selectedProduct['selling_price']?.toString() ?? '0',
              ) ??
              0.0;
          final qty = double.tryParse(qtyCtrl.text.trim()) ?? 1.0;
          final total = unitPrice * qty;

          return AlertDialog(
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(14),
            ),
            title: const Row(
              children: [
                Icon(Icons.add_shopping_cart_rounded, color: sidebarBlue),
                SizedBox(width: 8),
                Text(
                  'New Sale',
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 17),
                ),
              ],
            ),
            content: SizedBox(
              width: 420,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  DropdownButtonFormField<int?>(
                    initialValue: selectedCustomerId,
                    isExpanded: true,
                    decoration: const InputDecoration(
                      labelText: 'Customer (Optional)',
                      border: OutlineInputBorder(),
                      isDense: true,
                    ),
                    items: [
                      const DropdownMenuItem<int?>(
                        value: null,
                        child: Text('Walk-in Customer'),
                      ),
                      ..._customers.map(
                        (c) => DropdownMenuItem<int?>(
                          value: c['id'] as int,
                          child: Text(
                            '${c['name']} (${c['phone'] ?? 'No phone'})',
                          ),
                        ),
                      ),
                    ],
                    onChanged: (v) => setDState(() => selectedCustomerId = v),
                  ),
                  const SizedBox(height: 12),
                  DropdownButtonFormField<dynamic>(
                    initialValue: selectedProduct,
                    isExpanded: true,
                    decoration: const InputDecoration(
                      labelText: 'Product',
                      border: OutlineInputBorder(),
                      isDense: true,
                    ),
                    items: _products
                        .map(
                          (p) => DropdownMenuItem<dynamic>(
                            value: p,
                            child: Text(
                              '${p['product_name']} (₹${p['selling_price']} • Stock: ${p['stock_qty']})',
                            ),
                          ),
                        )
                        .toList(),
                    onChanged: (v) {
                      if (v != null) setDState(() => selectedProduct = v);
                    },
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(
                        child: TextField(
                          controller: qtyCtrl,
                          keyboardType: TextInputType.number,
                          onChanged: (_) => setDState(() {}),
                          decoration: const InputDecoration(
                            labelText: 'Quantity',
                            border: OutlineInputBorder(),
                            isDense: true,
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: DropdownButtonFormField<String>(
                          initialValue: paymentMethod,
                          decoration: const InputDecoration(
                            labelText: 'Payment Method',
                            border: OutlineInputBorder(),
                            isDense: true,
                          ),
                          items:
                              ['Cash', 'UPI', 'Card', 'Bank Transfer', 'Other']
                                  .map(
                                    (m) => DropdownMenuItem(
                                      value: m,
                                      child: Text(m),
                                    ),
                                  )
                                  .toList(),
                          onChanged: (v) {
                            if (v != null) setDState(() => paymentMethod = v);
                          },
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 14),
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: const Color(0xFFF8FAFC),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: const Color(0xFFE2E8F0)),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text(
                          'Total Amount',
                          style: TextStyle(fontWeight: FontWeight.w600),
                        ),
                        Text(
                          _currency(total),
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w800,
                            color: sidebarBlue,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            actions: [
              TextButton(
                onPressed: saving ? null : () => Navigator.pop(ctx),
                child: const Text('Cancel'),
              ),
              ElevatedButton(
                onPressed: saving
                    ? null
                    : () async {
                        final q = double.tryParse(qtyCtrl.text.trim()) ?? 0;
                        if (q <= 0) return;
                        setDState(() => saving = true);
                        try {
                          await _api.post('/billing/invoices', {
                            'customer_id': selectedCustomerId,
                            'items': [
                              {
                                'product_id': selectedProduct['id'],
                                'quantity': q,
                                'price': unitPrice,
                              },
                            ],
                            'discount': 0,
                            'tax_amount': 0,
                            'paid_amount': total,
                            'payment_method': paymentMethod,
                          });
                          if (!dCtx.mounted) return;
                          Navigator.pop(dCtx);
                          await _loadSales();
                          if (!mounted) return;
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              content: Text('New sale recorded successfully!'),
                              backgroundColor: primaryGreen,
                            ),
                          );
                        } catch (e) {
                          setDState(() => saving = false);
                          if (!mounted) return;
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text(
                                e.toString().replaceAll('Exception: ', ''),
                              ),
                              backgroundColor: Colors.red,
                            ),
                          );
                        }
                      },
                style: ElevatedButton.styleFrom(
                  backgroundColor: sidebarBlue,
                  foregroundColor: Colors.white,
                ),
                child: Text(saving ? 'Saving...' : 'Save Sale'),
              ),
            ],
          );
        },
      ),
    );
  }

  String _currency(dynamic amount) {
    if (amount == null) return '₹0.00';
    final val = (amount is num)
        ? amount.toDouble()
        : double.tryParse(amount.toString()) ?? 0.0;
    return '₹${val.toStringAsFixed(val.truncateToDouble() == val ? 0 : 2)}';
  }

  String _formatDate(dynamic dateStr) {
    if (dateStr == null) return '-';
    try {
      final s = dateStr.toString().split('T').first;
      return s;
    } catch (_) {
      return dateStr.toString();
    }
  }

  void _showSaleDetail(dynamic sale) async {
    dynamic detail;
    try {
      final res = await _api.get('/sales/${sale['id']}');
      detail = res['data'];
    } catch (_) {
      detail = sale;
    }

    if (!mounted) return;

    final isPaid = (detail['payment_status'] ?? 'Paid') == 'Paid';

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        titlePadding: const EdgeInsets.fromLTRB(20, 20, 20, 0),
        contentPadding: const EdgeInsets.fromLTRB(20, 16, 20, 20),
        actionsPadding: const EdgeInsets.fromLTRB(20, 0, 20, 16),
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: const Color(0xFFEFF6FF),
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Icon(
                Icons.receipt_long_rounded,
                color: sidebarBlue,
                size: 20,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Invoice #${detail['invoice_no'] ?? '-'}',
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
                      color: Colors.black,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    'Customer: ${detail['customer_name'] ?? 'Walk-in'} • Date: ${_formatDate(detail['sale_date'])}',
                    style: const TextStyle(
                      fontSize: 11,
                      color: Color(0xFF6B7280),
                    ),
                  ),
                ],
              ),
            ),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
              decoration: BoxDecoration(
                color: isPaid
                    ? const Color(0xFFECFDF5)
                    : const Color(0xFFFEF2F2),
                borderRadius: BorderRadius.circular(6),
                border: Border.all(
                  color: isPaid
                      ? const Color(0xFFA7F3D0)
                      : const Color(0xFFFECACA),
                ),
              ),
              child: Text(
                isPaid ? 'PAID' : 'UNPAID',
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.bold,
                  color: isPaid ? const Color(0xFF059669) : Colors.red,
                ),
              ),
            ),
          ],
        ),
        content: SizedBox(
          width: 520,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Purchased Paint Items:',
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  color: Colors.black,
                  fontSize: 13,
                ),
              ),
              const SizedBox(height: 10),
              if (detail['items'] is List &&
                  (detail['items'] as List).isNotEmpty)
                Container(
                  decoration: BoxDecoration(
                    color: const Color(0xFFF9FAFB),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: const Color(0xFFE5E7EB)),
                  ),
                  padding: const EdgeInsets.all(12),
                  child: Column(
                    children: (detail['items'] as List).map<Widget>((it) {
                      return Padding(
                        padding: const EdgeInsets.symmetric(vertical: 4),
                        child: Row(
                          children: [
                            Expanded(
                              child: Text(
                                it['product_name'] ?? 'Item',
                                style: const TextStyle(
                                  fontWeight: FontWeight.w600,
                                  color: Colors.black,
                                  fontSize: 13,
                                ),
                              ),
                            ),
                            Text(
                              '${it['quantity']} x ${_currency(it['unit_price'])}',
                              style: const TextStyle(
                                color: Color(0xFF4B5563),
                                fontSize: 12,
                              ),
                            ),
                            const SizedBox(width: 16),
                            Text(
                              _currency(it['line_total']),
                              style: const TextStyle(
                                fontWeight: FontWeight.bold,
                                color: Colors.black,
                                fontSize: 13,
                              ),
                            ),
                          ],
                        ),
                      );
                    }).toList(),
                  ),
                )
              else
                const Text(
                  'No itemized breakdown recorded.',
                  style: TextStyle(color: Colors.grey, fontSize: 12),
                ),
              const Divider(height: 24, color: Color(0xFFE5E7EB)),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text(
                    'Subtotal / Total Amount:',
                    style: TextStyle(color: Color(0xFF4B5563), fontSize: 13),
                  ),
                  Text(
                    _currency(detail['total_amount']),
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      color: Colors.black,
                      fontSize: 14,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 6),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text(
                    'Paid Amount:',
                    style: TextStyle(color: Color(0xFF4B5563), fontSize: 13),
                  ),
                  Text(
                    _currency(detail['paid_amount']),
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      color: primaryGreen,
                      fontSize: 14,
                    ),
                  ),
                ],
              ),
              if ((double.tryParse(
                        detail['balance_amount']?.toString() ?? '0',
                      ) ??
                      0) >
                  0) ...[
                const SizedBox(height: 6),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text(
                      'Remaining Balance Due:',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        color: Colors.red,
                        fontSize: 13,
                      ),
                    ),
                    Text(
                      _currency(detail['balance_amount']),
                      style: const TextStyle(
                        fontWeight: FontWeight.w900,
                        color: Colors.red,
                        fontSize: 15,
                      ),
                    ),
                  ],
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

  double _numVal(dynamic v) {
    if (v == null) return 0.0;
    if (v is num) return v.toDouble();
    return double.tryParse(v.toString()) ?? 0.0;
  }

  Widget _buildSalesActionMenu(dynamic s) {
    return PopupMenuButton<String>(
      tooltip: 'Sales Actions',
      color: const Color(0xFF0F172A), // Dark slate matching user mockup
      surfaceTintColor: Colors.transparent,
      elevation: 10,
      offset: const Offset(0, 36),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(10),
        side: const BorderSide(color: Color(0xFF334155), width: 1),
      ),
      icon: const Icon(
        Icons.more_vert_rounded,
        size: 19,
        color: Color(0xFF475569),
      ),
      onSelected: (val) {
        switch (val) {
          case 'view':
            _showSaleDetail(s);
            break;
          case 'edit':
            _showEditInvoiceDialog(s);
            break;
          case 'payment':
            _showRecordPaymentDialog(s);
            break;
          case 'history':
            _showPaymentHistoryDialog(s);
            break;
          case 'print':
            _printInvoiceSlip(s, isA4: false);
            break;
          case 'pdf':
            _printInvoiceSlip(s, isA4: true);
            break;
          case 'return':
            _showSalesReturnDialog(s);
            break;
          case 'cancel':
            _showCancelInvoiceDialog(s);
            break;
        }
      },
      itemBuilder: (ctx) => [
        _buildActionMenuItem('view', Icons.visibility_outlined, 'View Invoice'),
        _buildActionMenuItem('edit', Icons.edit_outlined, 'Edit Invoice'),
        _buildActionMenuItem(
          'payment',
          Icons.account_balance_wallet_outlined,
          'Record Payment',
        ),
        _buildActionMenuItem(
          'history',
          Icons.history_rounded,
          'Payment History',
        ),
        _buildActionMenuItem('print', Icons.print_outlined, 'Print Invoice'),
        _buildActionMenuItem(
          'pdf',
          Icons.file_download_outlined,
          'Download PDF',
        ),
        _buildActionMenuItem('return', Icons.replay_rounded, 'Sales Return'),
        _buildActionMenuItem(
          'cancel',
          Icons.delete_outline_rounded,
          'Cancel Invoice',
          isDestructive: true,
        ),
      ],
    );
  }

  PopupMenuItem<String> _buildActionMenuItem(
    String value,
    IconData icon,
    String title, {
    bool isDestructive = false,
  }) {
    final color = isDestructive ? const Color(0xFFEF4444) : Colors.white;
    return PopupMenuItem<String>(
      value: value,
      height: 38,
      padding: const EdgeInsets.symmetric(horizontal: 14),
      child: Row(
        children: [
          Icon(icon, size: 16, color: color),
          const SizedBox(width: 12),
          Text(
            title,
            style: TextStyle(
              color: color,
              fontSize: 13,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }

  void _showEditInvoiceDialog(dynamic s) {
    String selectedMethod = s['payment_method']?.toString() ?? 'Cash';
    String selectedStatus = s['payment_status']?.toString() ?? 'Paid';
    final notesCtrl = TextEditingController(text: s['notes']?.toString() ?? '');
    bool isSaving = false;

    final methods = ['Cash', 'UPI', 'Card', 'Net Banking', 'Cheque'];
    final statuses = ['Paid', 'Partial', 'Unpaid'];
    if (!methods.contains(selectedMethod)) {
      methods.add(selectedMethod);
    }
    if (!statuses.contains(selectedStatus)) {
      statuses.add(selectedStatus);
    }

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDlgState) => AlertDialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          titlePadding: const EdgeInsets.fromLTRB(20, 20, 20, 12),
          contentPadding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
          title: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: sidebarBlue.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(
                  Icons.edit_outlined,
                  color: sidebarBlue,
                  size: 20,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Edit Invoice',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: navyDark,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      'Invoice #${s['invoice_no'] ?? '-'} • ${s['customer_name'] ?? 'Walk-in'}',
                      style: const TextStyle(
                        fontSize: 12,
                        color: Color(0xFF64748B),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          content: SizedBox(
            width: 440,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const SizedBox(height: 12),
                const Text(
                  'Payment Method',
                  style: TextStyle(
                    fontSize: 12.5,
                    fontWeight: FontWeight.w600,
                    color: navyDark,
                  ),
                ),
                const SizedBox(height: 6),
                DropdownButtonFormField<String>(
                  initialValue: selectedMethod,
                  decoration: InputDecoration(
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: 14,
                      vertical: 12,
                    ),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(10),
                      borderSide: const BorderSide(color: Color(0xFFCBD5E1)),
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(10),
                      borderSide: const BorderSide(color: Color(0xFFCBD5E1)),
                    ),
                  ),
                  items: methods
                      .map(
                        (m) => DropdownMenuItem(
                          value: m,
                          child: Text(
                            m,
                            style: const TextStyle(fontSize: 13.5),
                          ),
                        ),
                      )
                      .toList(),
                  onChanged: (v) {
                    if (v != null) setDlgState(() => selectedMethod = v);
                  },
                ),
                const SizedBox(height: 14),
                const Text(
                  'Payment Status',
                  style: TextStyle(
                    fontSize: 12.5,
                    fontWeight: FontWeight.w600,
                    color: navyDark,
                  ),
                ),
                const SizedBox(height: 6),
                DropdownButtonFormField<String>(
                  initialValue: selectedStatus,
                  decoration: InputDecoration(
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: 14,
                      vertical: 12,
                    ),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(10),
                      borderSide: const BorderSide(color: Color(0xFFCBD5E1)),
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(10),
                      borderSide: const BorderSide(color: Color(0xFFCBD5E1)),
                    ),
                  ),
                  items: statuses
                      .map(
                        (st) => DropdownMenuItem(
                          value: st,
                          child: Text(
                            st,
                            style: const TextStyle(fontSize: 13.5),
                          ),
                        ),
                      )
                      .toList(),
                  onChanged: (v) {
                    if (v != null) setDlgState(() => selectedStatus = v);
                  },
                ),
                const SizedBox(height: 14),
                const Text(
                  'Invoice Notes / Remarks',
                  style: TextStyle(
                    fontSize: 12.5,
                    fontWeight: FontWeight.w600,
                    color: navyDark,
                  ),
                ),
                const SizedBox(height: 6),
                TextField(
                  controller: notesCtrl,
                  maxLines: 2,
                  decoration: InputDecoration(
                    hintText: 'Add invoice notes or terms...',
                    hintStyle: const TextStyle(
                      fontSize: 12.5,
                      color: Color(0xFF94A3B8),
                    ),
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: 14,
                      vertical: 12,
                    ),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(10),
                      borderSide: const BorderSide(color: Color(0xFFCBD5E1)),
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(10),
                      borderSide: const BorderSide(color: Color(0xFFCBD5E1)),
                    ),
                  ),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text(
                'Cancel',
                style: TextStyle(color: Color(0xFF64748B)),
              ),
            ),
            ElevatedButton(
              onPressed: isSaving
                  ? null
                  : () async {
                      setDlgState(() => isSaving = true);
                      try {
                        await _api.put('/sales/${s['id']}', {
                          'payment_method': selectedMethod,
                          'payment_status': selectedStatus,
                          'notes': notesCtrl.text.trim(),
                        });
                        if (ctx.mounted) Navigator.pop(ctx);
                        if (mounted) {
                          AppToast.show(
                            context,
                            message: 'Invoice updated successfully',
                            title: 'Success',
                            type: ToastType.success,
                          );
                          _loadSales();
                        }
                      } catch (e) {
                        setDlgState(() => isSaving = false);
                        if (mounted) {
                          AppToast.show(
                            context,
                            message: 'Update failed: $e',
                            title: 'Error',
                            type: ToastType.error,
                          );
                        }
                      }
                    },
              style: ElevatedButton.styleFrom(
                backgroundColor: sidebarBlue,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
                padding: const EdgeInsets.symmetric(
                  horizontal: 18,
                  vertical: 11,
                ),
              ),
              child: isSaving
                  ? const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Colors.white,
                      ),
                    )
                  : const Text(
                      'Save Changes',
                      style: TextStyle(fontWeight: FontWeight.w600),
                    ),
            ),
          ],
        ),
      ),
    );
  }

  void _showRecordPaymentDialog(dynamic s) {
    final total = _numVal(s['total_amount']);
    final paid = _numVal(s['paid_amount']);
    final balance = _numVal(s['balance_amount'] ?? (total - paid));
    final defaultAmt = balance > 0 ? balance : 0.0;

    final amtCtrl = TextEditingController(
      text: defaultAmt > 0 ? defaultAmt.toStringAsFixed(2) : '',
    );
    final refCtrl = TextEditingController();
    final notesCtrl = TextEditingController();
    String selectedMethod = 'Cash';
    bool isSaving = false;

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDlgState) => AlertDialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          titlePadding: const EdgeInsets.fromLTRB(20, 20, 20, 12),
          contentPadding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
          title: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: primaryGreen.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(
                  Icons.account_balance_wallet_outlined,
                  color: primaryGreen,
                  size: 20,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Record Payment',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: navyDark,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      'Invoice #${s['invoice_no'] ?? '-'} • ${s['customer_name'] ?? 'Walk-in'}',
                      style: const TextStyle(
                        fontSize: 12,
                        color: Color(0xFF64748B),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          content: SizedBox(
            width: 440,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 14,
                    vertical: 10,
                  ),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF8FAFC),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: const Color(0xFFE2E8F0)),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'Total Bill',
                            style: TextStyle(
                              fontSize: 11,
                              color: Color(0xFF64748B),
                            ),
                          ),
                          Text(
                            _currency(total),
                            style: const TextStyle(
                              fontSize: 13.5,
                              fontWeight: FontWeight.bold,
                              color: navyDark,
                            ),
                          ),
                        ],
                      ),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'Paid so far',
                            style: TextStyle(
                              fontSize: 11,
                              color: Color(0xFF64748B),
                            ),
                          ),
                          Text(
                            _currency(paid),
                            style: const TextStyle(
                              fontSize: 13.5,
                              fontWeight: FontWeight.bold,
                              color: Color(0xFF059669),
                            ),
                          ),
                        ],
                      ),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          const Text(
                            'Balance Due',
                            style: TextStyle(
                              fontSize: 11,
                              color: Color(0xFF64748B),
                            ),
                          ),
                          Text(
                            _currency(balance),
                            style: TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w800,
                              color: balance > 0
                                  ? const Color(0xFFDC2626)
                                  : const Color(0xFF059669),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 14),
                const Text(
                  'Payment Amount *',
                  style: TextStyle(
                    fontSize: 12.5,
                    fontWeight: FontWeight.w600,
                    color: navyDark,
                  ),
                ),
                const SizedBox(height: 6),
                TextField(
                  controller: amtCtrl,
                  keyboardType: const TextInputType.numberWithOptions(
                    decimal: true,
                  ),
                  decoration: InputDecoration(
                    prefixText: '₹ ',
                    prefixStyle: const TextStyle(
                      fontWeight: FontWeight.bold,
                      color: navyDark,
                    ),
                    hintText: '0.00',
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: 14,
                      vertical: 12,
                    ),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(10),
                      borderSide: const BorderSide(color: Color(0xFFCBD5E1)),
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(10),
                      borderSide: const BorderSide(color: Color(0xFFCBD5E1)),
                    ),
                  ),
                ),
                const SizedBox(height: 14),
                const Text(
                  'Payment Method',
                  style: TextStyle(
                    fontSize: 12.5,
                    fontWeight: FontWeight.w600,
                    color: navyDark,
                  ),
                ),
                const SizedBox(height: 6),
                DropdownButtonFormField<String>(
                  initialValue: selectedMethod,
                  decoration: InputDecoration(
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: 14,
                      vertical: 12,
                    ),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(10),
                      borderSide: const BorderSide(color: Color(0xFFCBD5E1)),
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(10),
                      borderSide: const BorderSide(color: Color(0xFFCBD5E1)),
                    ),
                  ),
                  items: const [
                    DropdownMenuItem(value: 'Cash', child: Text('Cash')),
                    DropdownMenuItem(
                      value: 'UPI',
                      child: Text('UPI / QR Code'),
                    ),
                    DropdownMenuItem(
                      value: 'Card',
                      child: Text('Debit / Credit Card'),
                    ),
                    DropdownMenuItem(
                      value: 'Net Banking',
                      child: Text('Net Banking'),
                    ),
                    DropdownMenuItem(value: 'Cheque', child: Text('Cheque')),
                  ],
                  onChanged: (v) {
                    if (v != null) setDlgState(() => selectedMethod = v);
                  },
                ),
                const SizedBox(height: 14),
                const Text(
                  'Reference / Transaction No (Optional)',
                  style: TextStyle(
                    fontSize: 12.5,
                    fontWeight: FontWeight.w600,
                    color: navyDark,
                  ),
                ),
                const SizedBox(height: 6),
                TextField(
                  controller: refCtrl,
                  decoration: InputDecoration(
                    hintText: 'e.g. UPI Ref / Cheque No / Txn ID',
                    hintStyle: const TextStyle(
                      fontSize: 12.5,
                      color: Color(0xFF94A3B8),
                    ),
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: 14,
                      vertical: 12,
                    ),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(10),
                      borderSide: const BorderSide(color: Color(0xFFCBD5E1)),
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(10),
                      borderSide: const BorderSide(color: Color(0xFFCBD5E1)),
                    ),
                  ),
                ),
                const SizedBox(height: 14),
                const Text(
                  'Notes (Optional)',
                  style: TextStyle(
                    fontSize: 12.5,
                    fontWeight: FontWeight.w600,
                    color: navyDark,
                  ),
                ),
                const SizedBox(height: 6),
                TextField(
                  controller: notesCtrl,
                  decoration: InputDecoration(
                    hintText: 'Additional remarks...',
                    hintStyle: const TextStyle(
                      fontSize: 12.5,
                      color: Color(0xFF94A3B8),
                    ),
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: 14,
                      vertical: 12,
                    ),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(10),
                      borderSide: const BorderSide(color: Color(0xFFCBD5E1)),
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(10),
                      borderSide: const BorderSide(color: Color(0xFFCBD5E1)),
                    ),
                  ),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text(
                'Cancel',
                style: TextStyle(color: Color(0xFF64748B)),
              ),
            ),
            ElevatedButton(
              onPressed: isSaving
                  ? null
                  : () async {
                      final enteredAmt =
                          double.tryParse(amtCtrl.text.trim()) ?? 0;
                      if (enteredAmt <= 0) {
                        AppToast.showError(
                          context,
                          title: 'Error',
                          message: 'Please enter a valid payment amount',
                        );
                        return;
                      }
                      setDlgState(() => isSaving = true);
                      try {
                        await _api.post(
                          '/billing/invoices/${s['id']}/payments',
                          {
                            'amount': enteredAmt,
                            'payment_method': selectedMethod,
                            'reference_no': refCtrl.text.trim(),
                            'notes': notesCtrl.text.trim(),
                          },
                        );
                        if (ctx.mounted) Navigator.pop(ctx);
                        if (mounted) {
                          AppToast.showSuccess(
                            context,
                            title: 'Success',
                            message:
                                'Payment of ₹${enteredAmt.toStringAsFixed(2)} recorded successfully',
                          );
                          _loadSales();
                        }
                      } catch (e) {
                        setDlgState(() => isSaving = false);
                        if (mounted) {
                          AppToast.showError(
                            context,
                            title: 'Error',
                            message: 'Payment failed: $e',
                          );
                        }
                      }
                    },
              style: ElevatedButton.styleFrom(
                backgroundColor: primaryGreen,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
                padding: const EdgeInsets.symmetric(
                  horizontal: 18,
                  vertical: 11,
                ),
              ),
              child: isSaving
                  ? const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Colors.white,
                      ),
                    )
                  : const Text(
                      'Confirm Payment',
                      style: TextStyle(fontWeight: FontWeight.w600),
                    ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _showPaymentHistoryDialog(dynamic s) async {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) =>
          const Center(child: CircularProgressIndicator(color: sidebarBlue)),
    );

    List<dynamic> payments = [];
    dynamic invoiceData = s;
    try {
      final res = await _api.get('/billing/invoices/${s['id']}');
      if (res['data'] != null) {
        invoiceData = res['data'];
        if (invoiceData['payments'] is List) {
          payments = invoiceData['payments'];
        }
      }
    } catch (_) {}

    if (mounted) Navigator.pop(context);

    if (!mounted) return;

    final total = _numVal(invoiceData['total_amount']);
    final paid = _numVal(invoiceData['paid_amount']);
    final balance = _numVal(invoiceData['balance_amount'] ?? (total - paid));

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        titlePadding: const EdgeInsets.fromLTRB(20, 20, 20, 12),
        contentPadding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: const Color(0xFF6366F1).withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(10),
              ),
              child: const Icon(
                Icons.history_rounded,
                color: Color(0xFF6366F1),
                size: 20,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Payment History',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: navyDark,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    'Invoice #${invoiceData['invoice_no'] ?? '-'} • ${invoiceData['customer_name'] ?? 'Walk-in'}',
                    style: const TextStyle(
                      fontSize: 12,
                      color: Color(0xFF64748B),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
        content: SizedBox(
          width: 500,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 14,
                  vertical: 10,
                ),
                decoration: BoxDecoration(
                  color: const Color(0xFFF8FAFC),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: const Color(0xFFE2E8F0)),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Total Billed',
                          style: TextStyle(
                            fontSize: 11,
                            color: Color(0xFF64748B),
                          ),
                        ),
                        Text(
                          _currency(total),
                          style: const TextStyle(
                            fontSize: 13.5,
                            fontWeight: FontWeight.bold,
                            color: navyDark,
                          ),
                        ),
                      ],
                    ),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Total Paid',
                          style: TextStyle(
                            fontSize: 11,
                            color: Color(0xFF64748B),
                          ),
                        ),
                        Text(
                          _currency(paid),
                          style: const TextStyle(
                            fontSize: 13.5,
                            fontWeight: FontWeight.bold,
                            color: Color(0xFF059669),
                          ),
                        ),
                      ],
                    ),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        const Text(
                          'Balance Due',
                          style: TextStyle(
                            fontSize: 11,
                            color: Color(0xFF64748B),
                          ),
                        ),
                        Text(
                          _currency(balance),
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w800,
                            color: balance > 0
                                ? const Color(0xFFDC2626)
                                : const Color(0xFF059669),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
              const Text(
                'Transactions Log',
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                  color: navyDark,
                ),
              ),
              const SizedBox(height: 8),
              if (payments.isEmpty)
                Container(
                  padding: const EdgeInsets.all(20),
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: const Color(0xFFF1F5F9),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Column(
                    children: [
                      Icon(
                        Icons.receipt_long_outlined,
                        size: 36,
                        color: Color(0xFF94A3B8),
                      ),
                      SizedBox(height: 6),
                      Text(
                        'No payment records logged yet',
                        style: TextStyle(
                          fontSize: 13,
                          color: Color(0xFF64748B),
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                      SizedBox(height: 2),
                      Text(
                        'Payments recorded via Record Payment will appear here.',
                        style: TextStyle(
                          fontSize: 11.5,
                          color: Color(0xFF94A3B8),
                        ),
                      ),
                    ],
                  ),
                )
              else
                ConstrainedBox(
                  constraints: const BoxConstraints(maxHeight: 280),
                  child: ListView.separated(
                    shrinkWrap: true,
                    itemCount: payments.length,
                    separatorBuilder: (_, _) => const SizedBox(height: 8),
                    itemBuilder: (ctx, i) {
                      final p = payments[i];
                      final pDate =
                          p['payment_date']?.toString().split('T').first ??
                          p['created_at']?.toString().split('T').first ??
                          '-';
                      final pMethod = p['payment_method']?.toString() ?? 'Cash';
                      final pAmount = _currency(p['amount']);
                      final pRef = p['reference_no']?.toString();
                      final pNotes = p['notes']?.toString();

                      return Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 14,
                          vertical: 10,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: const Color(0xFFE2E8F0)),
                        ),
                        child: Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 8,
                                vertical: 4,
                              ),
                              decoration: BoxDecoration(
                                color: const Color(0xFFEFF6FF),
                                borderRadius: BorderRadius.circular(6),
                              ),
                              child: Text(
                                pMethod,
                                style: const TextStyle(
                                  fontSize: 11,
                                  fontWeight: FontWeight.bold,
                                  color: sidebarBlue,
                                ),
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    'Date: $pDate',
                                    style: const TextStyle(
                                      fontSize: 12,
                                      fontWeight: FontWeight.w600,
                                      color: navyDark,
                                    ),
                                  ),
                                  if (pRef != null && pRef.isNotEmpty)
                                    Text(
                                      'Ref: $pRef',
                                      style: const TextStyle(
                                        fontSize: 11,
                                        color: Color(0xFF64748B),
                                      ),
                                    ),
                                  if (pNotes != null && pNotes.isNotEmpty)
                                    Text(
                                      'Notes: $pNotes',
                                      style: const TextStyle(
                                        fontSize: 11,
                                        color: Color(0xFF64748B),
                                      ),
                                    ),
                                ],
                              ),
                            ),
                            Text(
                              '+ $pAmount',
                              style: const TextStyle(
                                fontSize: 13.5,
                                fontWeight: FontWeight.bold,
                                color: Color(0xFF059669),
                              ),
                            ),
                          ],
                        ),
                      );
                    },
                  ),
                ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text(
              'Close',
              style: TextStyle(color: Color(0xFF64748B)),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _printInvoiceSlip(dynamic inv, {bool isA4 = false}) async {
    final invNo = inv['invoice_no']?.toString() ?? 'INVOICE';
    final date = inv['sale_date']?.toString().split('T').first ?? '-';
    final customer = inv['customer_name']?.toString() ?? 'Walk-in Customer';
    final customerPhone = inv['customer_phone']?.toString() ?? '';
    final mode = inv['payment_method']?.toString() ?? 'Cash';
    final status = inv['payment_status']?.toString() ?? 'Paid';
    final subtotal = _numVal(inv['subtotal'] ?? inv['total_amount']);
    final disc = _numVal(inv['discount']);
    final tax = _numVal(inv['tax_amount']);
    final total = _numVal(inv['total_amount']);
    final paid = _numVal(inv['paid_amount'] ?? inv['total_amount']);
    final bal = _numVal(inv['balance_amount'] ?? (total - paid));

    List<Map<String, dynamic>> itemsList = [];
    if (inv['items'] is List && (inv['items'] as List).isNotEmpty) {
      itemsList = (inv['items'] as List)
          .whereType<Map>()
          .map((e) => Map<String, dynamic>.from(e))
          .toList();
    } else if (inv['id'] != null) {
      try {
        final res = await _api.get('/billing/invoices/${inv['id']}');
        if (res['data'] != null && res['data']['items'] is List) {
          itemsList = (res['data']['items'] as List)
              .whereType<Map>()
              .map((e) => Map<String, dynamic>.from(e))
              .toList();
        }
      } catch (_) {}
    }

    if (itemsList.isEmpty) {
      final itemsCount = _numVal(inv['items_count']) > 0
          ? _numVal(inv['items_count']).toInt()
          : 1;
      itemsList = [
        {
          'product_name': 'Paint & Store Retail Items',
          'quantity': itemsCount,
          'unit_price': (total / itemsCount).toStringAsFixed(2),
          'line_total': total.toStringAsFixed(2),
        },
      ];
    }

    String html;
    if (isA4) {
      html = _buildA4TaxInvoiceHtml(
        invoiceNo: invNo,
        date: date,
        customerName: customer,
        customerPhone: customerPhone,
        paymentMethod: mode,
        paymentStatus: status,
        items: itemsList,
        subtotal: subtotal,
        discount: disc,
        taxAmount: tax,
        totalAmount: total,
        paidAmount: paid,
        balanceAmount: bal,
      );
    } else {
      html = buildReceiptSlipHtml(
        shopName: 'ColorCraft Paint Shop',
        shopAddress: '123 Paint Street, Chennai - 600001',
        shopPhone: '98765 43210',
        shopGst: 'GSTIN1234567890',
        invoiceNo: invNo,
        date: date,
        customerName: customer,
        customerPhone: customerPhone,
        paymentMethod: mode,
        paymentStatus: status,
        items: itemsList,
        subtotal: subtotal,
        discount: disc,
        taxAmount: tax,
        totalAmount: total,
        paidAmount: paid,
        balanceAmount: bal,
        footerText: 'Thank you for your business! Visit again.',
      );
    }

    final safeFileName =
        '${isA4 ? 'TaxInvoice' : 'Slip'}_${invNo.replaceAll(RegExp(r'[^a-zA-Z0-9_-]'), '_')}.html';
    await downloadReceiptSlip(fileName: safeFileName, htmlContent: html);
    if (mounted) {
      AppToast.showSuccess(
        context,
        title: 'Success',
        message: isA4
            ? 'A4 Tax Invoice ready for download / print'
            : 'Thermal Invoice Slip ready',
      );
    }
  }

  String _buildA4TaxInvoiceHtml({
    required String invoiceNo,
    required String date,
    required String customerName,
    required String customerPhone,
    required String paymentMethod,
    required String paymentStatus,
    required List<Map<String, dynamic>> items,
    required double subtotal,
    required double discount,
    required double taxAmount,
    required double totalAmount,
    required double paidAmount,
    required double balanceAmount,
  }) {
    String esc(String s) => s
        .replaceAll('&', '&amp;')
        .replaceAll('<', '&lt;')
        .replaceAll('>', '&gt;')
        .replaceAll('"', '&quot;')
        .replaceAll("'", '&#39;');

    final itemsRows = StringBuffer();
    for (int i = 0; i < items.length; i++) {
      final it = items[i];
      final name = esc(it['product_name']?.toString() ?? 'Item');
      final qty = it['quantity']?.toString() ?? '1';
      final rate = _currency(it['unit_price'] ?? 0);
      final total = _currency(it['line_total'] ?? 0);
      itemsRows.writeln('''
        <tr>
          <td style="text-align: center;">${i + 1}</td>
          <td><b>$name</b></td>
          <td style="text-align: center;">$qty</td>
          <td style="text-align: right;">$rate</td>
          <td style="text-align: right; font-weight: bold;">$total</td>
        </tr>
      ''');
    }

    return '''<!DOCTYPE html>
<html>
<head>
  <meta charset="utf-8">
  <title>Tax Invoice - ${esc(invoiceNo)}</title>
  <style>
    body { font-family: -apple-system, BlinkMacSystemFont, "Segoe UI", Roboto, sans-serif; padding: 32px; color: #0f172a; margin: 0; background: #fff; }
    .invoice-box { max-width: 800px; margin: auto; border: 1px solid #cbd5e1; padding: 28px; border-radius: 8px; }
    .header { display: flex; justify-content: space-between; border-bottom: 2px solid #1e40af; padding-bottom: 16px; margin-bottom: 20px; }
    .shop-name { font-size: 22px; font-weight: 800; color: #1e40af; margin: 0 0 4px; }
    .shop-meta { font-size: 12px; color: #475569; line-height: 1.5; }
    .inv-title { text-align: right; }
    .inv-title h1 { font-size: 20px; margin: 0; color: #0f172a; }
    .inv-badge { display: inline-block; padding: 3px 10px; background: #dcfce7; color: #15803d; font-weight: bold; font-size: 11px; border-radius: 4px; margin-top: 6px; }
    .grid-2 { display: flex; justify-content: space-between; margin-bottom: 20px; font-size: 12.5px; }
    .bill-to { flex: 1; }
    .inv-meta { flex: 1; text-align: right; }
    table { width: 100%; border-collapse: collapse; font-size: 12.5px; margin-top: 10px; }
    th { background: #f1f5f9; border: 1px solid #cbd5e1; padding: 8px 10px; color: #334155; font-weight: 700; }
    td { border: 1px solid #e2e8f0; padding: 8px 10px; }
    .totals-area { display: flex; justify-content: flex-end; margin-top: 16px; }
    .totals-table { width: 320px; font-size: 12.5px; }
    .totals-table td { border: none; padding: 5px 8px; }
    .grand-total { font-size: 15px; font-weight: bold; color: #1e40af; border-top: 2px solid #cbd5e1 !important; border-bottom: 2px solid #cbd5e1 !important; }
    .footer { margin-top: 36px; padding-top: 16px; border-top: 1px solid #e2e8f0; display: flex; justify-content: space-between; font-size: 11px; color: #64748b; }
    @media print {
      body { padding: 0; }
      .invoice-box { border: none; padding: 0; }
    }
  </style>
</head>
<body>
  <div class="invoice-box">
    <div class="header">
      <div>
        <div class="shop-name">ColorCraft Paint Shop</div>
        <div class="shop-meta">
          123 Paint Street, Chennai - 600001<br>
          GSTIN: <b>GSTIN1234567890</b> | Phone: +91 98765 43210
        </div>
      </div>
      <div class="inv-title">
        <h1>TAX INVOICE</h1>
        <div class="inv-badge">${paymentStatus.toUpperCase()}</div>
      </div>
    </div>

    <div class="grid-2">
      <div class="bill-to">
        <div style="font-size: 11px; color: #64748b; font-weight: bold; text-transform: uppercase;">Billed To Customer:</div>
        <div style="font-size: 14px; font-weight: bold; margin-top: 3px;">${esc(customerName)}</div>
        <div style="color: #475569;">${customerPhone.isNotEmpty ? 'Phone: $customerPhone' : ''}</div>
      </div>
      <div class="inv-meta">
        <div>Invoice No: <b>${esc(invoiceNo)}</b></div>
        <div>Date: <b>$date</b></div>
        <div>Payment Mode: <b>$paymentMethod</b></div>
      </div>
    </div>

    <table>
      <thead>
        <tr>
          <th style="width: 40px;">#</th>
          <th style="text-align: left;">Description of Goods</th>
          <th style="width: 60px;">Qty</th>
          <th style="text-align: right; width: 100px;">Rate</th>
          <th style="text-align: right; width: 110px;">Amount</th>
        </tr>
      </thead>
      <tbody>
        $itemsRows
      </tbody>
    </table>

    <div class="totals-area">
      <table class="totals-table">
        <tr>
          <td>Subtotal:</td>
          <td style="text-align: right;">${_currency(subtotal)}</td>
        </tr>
        ${discount > 0 ? '<tr><td>Discount:</td><td style="text-align: right; color: red;">- ${_currency(discount)}</td></tr>' : ''}
        ${taxAmount > 0 ? '<tr><td>GST / Tax:</td><td style="text-align: right;">+ ${_currency(taxAmount)}</td></tr>' : ''}
        <tr class="grand-total">
          <td>Grand Total:</td>
          <td style="text-align: right;">${_currency(totalAmount)}</td>
        </tr>
        <tr>
          <td>Paid Amount:</td>
          <td style="text-align: right;">${_currency(paidAmount)}</td>
        </tr>
        ${balanceAmount > 0 ? '<tr><td>Balance Due:</td><td style="text-align: right; color: red; font-weight: bold;">${_currency(balanceAmount)}</td></tr>' : ''}
      </table>
    </div>

    <div class="footer">
      <div>
        <b>Terms & Conditions:</b><br>
        Goods once sold cannot be returned after 7 days.<br>
        Subject to Chennai jurisdiction.
      </div>
      <div style="text-align: right;">
        <br><br>
        <b>Authorized Signatory</b><br>
        ColorCraft Paint Shop
      </div>
    </div>
  </div>

  <script>window.onload = function() { window.print(); };</script>
</body>
</html>''';
  }

  void _showSalesReturnDialog(dynamic s) {
    String selectedReason = 'Customer Return';
    final customReasonCtrl = TextEditingController();
    bool isProcessing = false;

    final presetReasons = [
      'Customer Return',
      'Wrong Paint Shade / Color',
      'Excess Cans Remaining',
      'Damaged Tin / Container Leakage',
      'Customer Canceled Job',
    ];

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDlgState) => AlertDialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          titlePadding: const EdgeInsets.fromLTRB(20, 20, 20, 12),
          contentPadding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
          title: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: const Color(0xFFD97706).withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(
                  Icons.replay_rounded,
                  color: Color(0xFFD97706),
                  size: 20,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Process Sales Return',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: navyDark,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      'Invoice #${s['invoice_no'] ?? '-'} • ${s['customer_name'] ?? 'Walk-in'}',
                      style: const TextStyle(
                        fontSize: 12,
                        color: Color(0xFF64748B),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          content: SizedBox(
            width: 440,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: const Color(0xFFFFFBEB),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: const Color(0xFFFDE68A)),
                  ),
                  child: const Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Icon(
                        Icons.info_outline_rounded,
                        color: Color(0xFFD97706),
                        size: 18,
                      ),
                      SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          'Processing this return will restore the purchased paint products back to the store inventory and mark this bill status as Returned.',
                          style: TextStyle(
                            fontSize: 12,
                            color: Color(0xFF92400E),
                            height: 1.4,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
                const Text(
                  'Select Return Reason',
                  style: TextStyle(
                    fontSize: 12.5,
                    fontWeight: FontWeight.w600,
                    color: navyDark,
                  ),
                ),
                const SizedBox(height: 6),
                DropdownButtonFormField<String>(
                  initialValue: selectedReason,
                  decoration: InputDecoration(
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: 14,
                      vertical: 12,
                    ),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(10),
                      borderSide: const BorderSide(color: Color(0xFFCBD5E1)),
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(10),
                      borderSide: const BorderSide(color: Color(0xFFCBD5E1)),
                    ),
                  ),
                  items: presetReasons
                      .map(
                        (r) => DropdownMenuItem(
                          value: r,
                          child: Text(r, style: const TextStyle(fontSize: 13)),
                        ),
                      )
                      .toList(),
                  onChanged: (v) {
                    if (v != null) setDlgState(() => selectedReason = v);
                  },
                ),
                const SizedBox(height: 14),
                const Text(
                  'Additional Notes / Reason',
                  style: TextStyle(
                    fontSize: 12.5,
                    fontWeight: FontWeight.w600,
                    color: navyDark,
                  ),
                ),
                const SizedBox(height: 6),
                TextField(
                  controller: customReasonCtrl,
                  decoration: InputDecoration(
                    hintText: 'e.g. Returned 2 unused 4L cans...',
                    hintStyle: const TextStyle(
                      fontSize: 12.5,
                      color: Color(0xFF94A3B8),
                    ),
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: 14,
                      vertical: 12,
                    ),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(10),
                      borderSide: const BorderSide(color: Color(0xFFCBD5E1)),
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(10),
                      borderSide: const BorderSide(color: Color(0xFFCBD5E1)),
                    ),
                  ),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text(
                'Cancel',
                style: TextStyle(color: Color(0xFF64748B)),
              ),
            ),
            ElevatedButton(
              onPressed: isProcessing
                  ? null
                  : () async {
                      setDlgState(() => isProcessing = true);
                      final reason = customReasonCtrl.text.trim().isNotEmpty
                          ? '$selectedReason - ${customReasonCtrl.text.trim()}'
                          : selectedReason;
                      try {
                        await _api.post('/sales/${s['id']}/return', {
                          'return_reason': reason,
                        });
                        if (ctx.mounted) Navigator.pop(ctx);
                        if (mounted) {
                          AppToast.showSuccess(
                            context,
                            title: 'Success',
                            message: 'Sales return processed & inventory stock restored',
                          );
                          _loadSales();
                        }
                      } catch (e) {
                        setDlgState(() => isProcessing = false);
                        if (mounted) {
                          AppToast.showError(
                            context,
                            title: 'Error',
                            message: 'Return failed: $e',
                          );
                        }
                      }
                    },
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFFD97706),
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
                padding: const EdgeInsets.symmetric(
                  horizontal: 18,
                  vertical: 11,
                ),
              ),
              child: isProcessing
                  ? const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Colors.white,
                      ),
                    )
                  : const Text(
                      'Confirm Return & Restock',
                      style: TextStyle(fontWeight: FontWeight.w600),
                    ),
            ),
          ],
        ),
      ),
    );
  }

  void _showCancelInvoiceDialog(dynamic s) {
    bool isCancelling = false;

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDlgState) => AlertDialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          titlePadding: const EdgeInsets.fromLTRB(20, 20, 20, 12),
          contentPadding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
          title: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: const Color(0xFFFEE2E2),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(
                  Icons.delete_outline_rounded,
                  color: Color(0xFFEF4444),
                  size: 22,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Cancel Invoice',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFFDC2626),
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      'Invoice #${s['invoice_no'] ?? '-'}',
                      style: const TextStyle(
                        fontSize: 12,
                        color: Color(0xFF64748B),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          content: SizedBox(
            width: 420,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Are you sure you want to cancel this invoice? This action will:',
                  style: TextStyle(
                    fontSize: 13.5,
                    color: navyDark,
                    height: 1.4,
                  ),
                ),
                const SizedBox(height: 10),
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: const Color(0xFFFEF2F2),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: const Color(0xFFFECACA)),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Row(
                        children: [
                          Icon(
                            Icons.check_circle_outline,
                            size: 15,
                            color: Color(0xFFDC2626),
                          ),
                          SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              'Restore all item quantities back into product stock.',
                              style: TextStyle(
                                fontSize: 12,
                                color: Color(0xFF991B1B),
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 6),
                      const Row(
                        children: [
                          Icon(
                            Icons.check_circle_outline,
                            size: 15,
                            color: Color(0xFFDC2626),
                          ),
                          SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              'Mark invoice status permanently as Cancelled.',
                              style: TextStyle(
                                fontSize: 12,
                                color: Color(0xFF991B1B),
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'Total Bill Amount: ${_currency(s['total_amount'])}',
                        style: const TextStyle(
                          fontSize: 12.5,
                          fontWeight: FontWeight.bold,
                          color: Color(0xFF991B1B),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text(
                'Keep Invoice',
                style: TextStyle(color: Color(0xFF64748B)),
              ),
            ),
            ElevatedButton(
              onPressed: isCancelling
                  ? null
                  : () async {
                      setDlgState(() => isCancelling = true);
                      try {
                        await _api.post('/sales/${s['id']}/cancel', {});
                        if (ctx.mounted) Navigator.pop(ctx);
                        if (mounted) {
                          AppToast.showSuccess(
                            context,
                            title: 'Success',
                            message: 'Invoice cancelled & stock restored',
                          );
                          _loadSales();
                        }
                      } catch (e) {
                        setDlgState(() => isCancelling = false);
                        if (mounted) {
                          AppToast.showError(
                            context,
                            title: 'Error',
                            message: 'Cancel failed: $e',
                          );
                        }
                      }
                    },
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFFEF4444),
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
                padding: const EdgeInsets.symmetric(
                  horizontal: 18,
                  vertical: 11,
                ),
              ),
              child: isCancelling
                  ? const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Colors.white,
                      ),
                    )
                  : const Text(
                      'Yes, Cancel Invoice',
                      style: TextStyle(fontWeight: FontWeight.w600),
                    ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final width = MediaQuery.sizeOf(context).width;
    final isNarrowHeader = width < 720;
    final isCompactFilter = width < 960;

    return Container(
      color: background,
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(20, 18, 20, 30),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // 1. TOP HEADER (Sales & invoices)
            if (isNarrowHeader) ...[
              const Text(
                'Sales & invoices',
                style: TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.w800,
                  color: navyDark,
                ),
              ),
              const SizedBox(height: 4),
              const Text(
                'Track every sale, review invoice details, and manage returns with confidence.',
                style: TextStyle(fontSize: 13, color: Color(0xFF64748B)),
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
                          'Sales & invoices',
                          style: TextStyle(
                            fontSize: 26,
                            fontWeight: FontWeight.w800,
                            color: navyDark,
                          ),
                        ),
                        SizedBox(height: 3),
                        Text(
                          'Track every sale, review invoice details, and manage returns with confidence.',
                          style: TextStyle(
                            fontSize: 13,
                            color: Color(0xFF64748B),
                          ),
                        ),
                      ],
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
                    title: 'MATCHING INVOICES',
                    amount: '${_filteredSales.length}',
                    percentage: 'Total',
                    icon: Icons.receipt_long_rounded,
                    colors: const [Color(0xFF6250F4), Color(0xFF4033C7)],
                  ),
                  _StatCard(
                    title: 'PAGE SALES',
                    amount: _currency(_totalSalesAmount),
                    percentage: 'Total',
                    icon: Icons.point_of_sale_rounded,
                    colors: const [Color(0xFF22C981), Color(0xFF079B63)],
                  ),
                  _StatCard(
                    title: 'PAGE COLLECTIONS',
                    amount: _currency(_totalPaidAmount),
                    percentage: 'Paid',
                    icon: Icons.check_circle_outline_rounded,
                    colors: const [Color(0xFFFFAC16), Color(0xFFFF8C00)],
                  ),
                  _StatCard(
                    title: 'PAGE OUTSTANDING',
                    amount: _currency(_totalBalanceAmount),
                    percentage: 'Due',
                    icon: Icons.warning_amber_rounded,
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
                        hintText: 'Search invoice or customer...',
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
                        DropdownMenuItem(value: 'Paid', child: Text('Paid')),
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

            // 4. INVOICE REGISTER TABLE CARD
            Container(
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: const Color(0xFFE2E8F0)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // Card Header
                  Padding(
                    padding: const EdgeInsets.fromLTRB(18, 16, 18, 14),
                    child: Wrap(
                      spacing: 10,
                      runSpacing: 10,
                      alignment: WrapAlignment.spaceBetween,
                      crossAxisAlignment: WrapCrossAlignment.center,
                      children: [
                        const Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Invoice register',
                              style: TextStyle(
                                fontSize: 17,
                                fontWeight: FontWeight.w800,
                                color: navyDark,
                              ),
                            ),
                            SizedBox(height: 2),
                            Text(
                              'Live records from your store',
                              style: TextStyle(
                                fontSize: 12,
                                color: Color(0xFF64748B),
                              ),
                            ),
                          ],
                        ),
                        Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            OutlinedButton.icon(
                              onPressed: _loadSales,
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
                                side: const BorderSide(
                                  color: Color(0xFFE2E8F0),
                                ),
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
                            onPressed: _loadSales,
                            child: const Text('Try Again'),
                          ),
                        ],
                      ),
                    )
                  else if (_filteredSales.isEmpty)
                    const Padding(
                      padding: EdgeInsets.all(36),
                      child: Column(
                        children: [
                          Icon(
                            Icons.receipt_long_outlined,
                            size: 44,
                            color: Colors.grey,
                          ),
                          SizedBox(height: 10),
                          Text(
                            'No sales records found',
                            style: TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          SizedBox(height: 4),
                          Text(
                            'Completed billing entries will display here.',
                            style: TextStyle(fontSize: 12, color: Colors.grey),
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
                                      'INVOICE',
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
                                      'CUSTOMER',
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
                                      'TOTAL',
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
                                      'PAID',
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
                                      'DUE',
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
                            ...List.generate(_filteredSales.length, (idx) {
                              final s = _filteredSales[idx];
                              final status = (s['payment_status'] ?? 'Paid')
                                  .toString();
                              final isPaid = status.toLowerCase() == 'paid';
                              final isPartial =
                                  status.toLowerCase() == 'partial';
                              final bal =
                                  double.tryParse(
                                    s['balance_amount']?.toString() ?? '0',
                                  ) ??
                                  0;

                              return Container(
                                decoration: BoxDecoration(
                                  color: Colors.white,
                                  border: Border(
                                    bottom: BorderSide(
                                      color: idx == _filteredSales.length - 1
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
                                        s['invoice_no'] ?? '-',
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
                                        s['customer_name'] ?? 'Walk-in',
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
                                        _formatPrettyDate(s['sale_date']),
                                        style: const TextStyle(
                                          fontSize: 12.5,
                                          color: Color(0xFF64748B),
                                        ),
                                      ),
                                    ),
                                    Expanded(
                                      flex: 2,
                                      child: Text(
                                        _currency(s['total_amount']),
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
                                        _currency(s['paid_amount']),
                                        style: const TextStyle(
                                          fontSize: 13,
                                          color: Color(0xFF475569),
                                        ),
                                      ),
                                    ),
                                    Expanded(
                                      flex: 2,
                                      child: Text(
                                        _currency(s['balance_amount']),
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
                                            color: isPaid
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
                                              color: isPaid
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
                                        child: _buildSalesActionMenu(s),
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
