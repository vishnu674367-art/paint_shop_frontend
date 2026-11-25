import 'package:flutter/material.dart';

import 'app_toast.dart';
import 'responsive_ui.dart';
import 'api_service.dart';
import 'product_image_widget.dart';
import 'slip_downloader.dart';
import 'app_input_formatters.dart';

class BillingPage extends StatefulWidget {
  final String token;
  final String? apiBaseUrl;
  final TextEditingController? catalogSearchCtrl;
  const BillingPage({
    super.key,
    required this.token,
    this.apiBaseUrl,
    this.catalogSearchCtrl,
  });
  @override
  State<BillingPage> createState() => _BillingPageState();
}

class _BillingPageState extends State<BillingPage> {
  late final ApiService _api;
  bool _isLoading = true;
  String? _errorMessage;
  Map<String, dynamic> _summary = {};
  List<dynamic> _invoices = [];
  List<dynamic> _customers = [];
  List<dynamic> _products = [];
  Map<String, dynamic> _shopSettings = {};
  String _searchQuery = '';
  String _statusFilter = 'All'; // All, Paid, Partial, Unpaid

  // POS Billing state
  final int _activeTab = 0; // 0 = POS Billing, 1 = Invoices History
  String _catalogSearch = '';
  late final TextEditingController _internalCatalogSearchCtrl;
  TextEditingController get _catalogSearchCtrl =>
      widget.catalogSearchCtrl ?? _internalCatalogSearchCtrl;
  final TextEditingController _posCustomerNameCtrl = TextEditingController();
  final TextEditingController _posCustomerPhoneCtrl = TextEditingController();
  final TextEditingController _posCustomerAddressCtrl = TextEditingController();
  final TextEditingController _posPaymentRefCtrl = TextEditingController();
  final TextEditingController _posPaidAmountCtrl = TextEditingController();
  final List<Map<String, dynamic>> _cart = [];
  int? _selectedCustomerId;
  final bool _applyGst = true;
  String _posPaymentMethod = 'Cash';
  bool _isSubmittingSale = false;

  String get _paymentRefHint {
    switch (_posPaymentMethod) {
      case 'UPI':
        return 'UPI Transaction ID / UTR #';
      case 'Card':
        return 'Card Last 4 Digits / Auth Code';
      case 'Bank Transfer':
        return 'Bank Transfer / NEFT / UTR No';
      default:
        return 'Payment Reference / Note';
    }
  }

  IconData get _paymentRefIcon {
    switch (_posPaymentMethod) {
      case 'UPI':
        return Icons.qr_code_rounded;
      case 'Card':
        return Icons.credit_card_rounded;
      case 'Bank Transfer':
        return Icons.account_balance_rounded;
      default:
        return Icons.receipt_long_rounded;
    }
  }

  static const Color navy = Color(0xFF151B3B);
  static const Color posBlue = Color(0xFF1E40AF);
  static const Color purple = Color(0xFF5945E8);
  static const Color primaryGreen = Color(0xFF267A4B);
  static const Color warningOrange = Color(0xFFF59E0B);

  @override
  void dispose() {
    _catalogSearchCtrl.removeListener(_onCatalogSearchChanged);
    _internalCatalogSearchCtrl.dispose();
    _posCustomerNameCtrl.dispose();
    _posCustomerPhoneCtrl.dispose();
    _posCustomerAddressCtrl.dispose();
    _posPaymentRefCtrl.dispose();
    _posPaidAmountCtrl.dispose();
    super.dispose();
  }

  @override
  void initState() {
    super.initState();
    _internalCatalogSearchCtrl = TextEditingController();
    _catalogSearchCtrl.addListener(_onCatalogSearchChanged);
    _catalogSearch = _catalogSearchCtrl.text;
    _api = ApiService(token: widget.token, customBaseUrl: widget.apiBaseUrl);
    _loadBillingData();
  }

  void _onCatalogSearchChanged() {
    if (mounted) {
      setState(() {
        _catalogSearch = _catalogSearchCtrl.text;
      });
    }
  }

  Future<void> _loadBillingData() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });
    try {
      final query = <String, String>{};
      if (_statusFilter != 'All') query['status'] = _statusFilter;
      if (_searchQuery.trim().isNotEmpty) query['search'] = _searchQuery.trim();
      final results = await Future.wait([
        _api.get('/billing/summary'),
        _api.get('/billing/invoices', queryParams: query),
        _api.get('/customers'),
        _api.get('/products'),
        _api.get('/settings').catchError((_) => <String, dynamic>{}),
      ]);
      if (!mounted) return;
      setState(() {
        _summary = results[0]['data'] is Map ? results[0]['data'] : {};
        _invoices = results[1]['data'] is List ? results[1]['data'] : [];
        _customers = results[2]['data'] is List ? results[2]['data'] : [];
        _products = results[3]['data'] is List ? results[3]['data'] : [];
        _shopSettings = results[4]['data'] is Map
            ? Map<String, dynamic>.from(results[4]['data'])
            : {};
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

  String _currency(dynamic amount) {
    final val = (amount is num)
        ? amount.toDouble()
        : double.tryParse(amount?.toString() ?? '0') ?? 0;
    return '₹${val.toStringAsFixed(2)}';
  }

  void _showCreateInvoiceDialog() {
    int? selectedCustomerId;
    final List<Map<String, dynamic>> items = [];
    double discount = 0;
    double tax = 0;
    String paymentMethod = 'Cash';
    final notesCtrl = TextEditingController();
    final discountCtrl = TextEditingController(text: '0');
    final taxCtrl = TextEditingController(text: '0');
    final paidCtrl = TextEditingController();
    // Add first empty item
    if (_products.isNotEmpty) {
      final firstProd = _products.first;
      items.add({
        'product_id': firstProd['id'],
        'product_name': firstProd['product_name'],
        'price':
            double.tryParse(firstProd['selling_price']?.toString() ?? '0') ?? 0,
        'quantity': 1.0,
        'stock':
            double.tryParse(firstProd['stock_qty']?.toString() ?? '0') ?? 0,
      });
    }
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => StatefulBuilder(
        builder: (dialogCtx, setDialogState) {
          double subtotal = 0;
          for (final it in items) {
            subtotal += (it['price'] as double) * (it['quantity'] as double);
          }
          final grandTotal = (subtotal - discount + tax).clamp(
            0.0,
            double.infinity,
          );
          if (paidCtrl.text.isEmpty) {
            paidCtrl.text = grandTotal.toStringAsFixed(2);
          }
          return AlertDialog(
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
            ),
            title: const Row(
              children: [
                Icon(Icons.receipt_long_rounded, color: navy),
                SizedBox(width: 8),
                Text(
                  'Create New Invoice / Bill',
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
                ),
              ],
            ),
            content: SizedBox(
              width: 720,
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // CUSTOMER SELECTION
                    DropdownButtonFormField<int?>(
                      initialValue: selectedCustomerId,
                      decoration: const InputDecoration(
                        labelText: 'Select Customer (Optional - leave blank for Walk-in)',
                        border: OutlineInputBorder(),
                        isDense: true,
                        prefixIcon: Icon(Icons.person, size: 20),
                      ),
                      items: [
                        const DropdownMenuItem<int?>(
                          value: null,
                          child: Text('Walk-in Customer (General)'),
                        ),
                        ..._customers.map((c) {
                          return DropdownMenuItem<int?>(
                            value: c['id'] as int,
                            child: Text(
                              '${c['name']} (${c['phone'] ?? 'No phone'})',
                            ),
                          );
                        }),
                      ],
                      onChanged: (val) =>
                          setDialogState(() => selectedCustomerId = val),
                    ),
                    const SizedBox(height: 16),
                    // ITEMS TABLE
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text(
                          'Bill Items',
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 15,
                            color: navy,
                          ),
                        ),
                        TextButton.icon(
                          onPressed: () {
                            if (_products.isEmpty) return;
                            final p = _products.first;
                            setDialogState(() {
                              items.add({
                                'product_id': p['id'],
                                'product_name': p['product_name'],
                                'price':
                                    double.tryParse(
                                      p['selling_price']?.toString() ?? '0',
                                    ) ??
                                    0,
                                'quantity': 1.0,
                                'stock':
                                    double.tryParse(
                                      p['stock_qty']?.toString() ?? '0',
                                    ) ??
                                    0,
                              });
                            });
                          },
                          icon: const Icon(Icons.add, size: 16),
                          label: const Text('Add Another Item'),
                        ),
                      ],
                    ),
                    const Divider(),
                    ...List.generate(items.length, (idx) {
                      final item = items[idx];
                      return Padding(
                        padding: const EdgeInsets.only(bottom: 8),
                        child: Row(
                          children: [
                            // Product dropdown
                            Expanded(
                              flex: 3,
                              child: DropdownButtonFormField<int>(
                                initialValue: item['product_id'] as int,
                                isDense: true,
                                decoration: const InputDecoration(
                                  border: OutlineInputBorder(),
                                  contentPadding: EdgeInsets.symmetric(
                                    horizontal: 10,
                                    vertical: 8,
                                  ),
                                ),
                                items: _products.map<DropdownMenuItem<int>>((
                                  p,
                                ) {
                                  return DropdownMenuItem<int>(
                                    value: p['id'] as int,
                                    child: Text(
                                      '${p['product_name']} (Stock: ${p['stock_qty']})',
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  );
                                }).toList(),
                                onChanged: (val) {
                                  if (val == null) return;
                                  final p = _products.firstWhere(
                                    (e) => e['id'] == val,
                                  );
                                  setDialogState(() {
                                    item['product_id'] = val;
                                    item['product_name'] = p['product_name'];
                                    item['price'] =
                                        double.tryParse(
                                          p['selling_price']?.toString() ?? '0',
                                        ) ??
                                        0;
                                    item['stock'] =
                                        double.tryParse(
                                          p['stock_qty']?.toString() ?? '0',
                                        ) ??
                                        0;
                                  });
                                },
                              ),
                            ),
                            const SizedBox(width: 8),
                            // Qty
                            SizedBox(
                              width: 80,
                              child: TextFormField(
                                initialValue: item['quantity'].toString(),
                                keyboardType:
                                    const TextInputType.numberWithOptions(
                                      decimal: true,
                                    ),
                                decoration: const InputDecoration(
                                  labelText: 'Qty',
                                  border: OutlineInputBorder(),
                                  isDense: true,
                                  contentPadding: EdgeInsets.symmetric(
                                    horizontal: 10,
                                    vertical: 8,
                                  ),
                                ),
                                onChanged: (val) {
                                  setDialogState(() {
                                    item['quantity'] =
                                        double.tryParse(val) ?? 1.0;
                                  });
                                },
                              ),
                            ),
                            const SizedBox(width: 8),
                            // Price
                            SizedBox(
                              width: 95,
                              child: TextFormField(
                                initialValue: item['price'].toString(),
                                keyboardType:
                                    const TextInputType.numberWithOptions(
                                      decimal: true,
                                    ),
                                decoration: const InputDecoration(
                                  labelText: 'Price (₹)',
                                  border: OutlineInputBorder(),
                                  isDense: true,
                                  contentPadding: EdgeInsets.symmetric(
                                    horizontal: 10,
                                    vertical: 8,
                                  ),
                                ),
                                onChanged: (val) {
                                  setDialogState(() {
                                    item['price'] = double.tryParse(val) ?? 0.0;
                                  });
                                },
                              ),
                            ),
                            const SizedBox(width: 8),
                            // Total line
                            SizedBox(
                              width: 90,
                              child: Text(
                                '₹${((item['price'] as double) * (item['quantity'] as double)).toStringAsFixed(2)}',
                                style: const TextStyle(
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                            // Delete button
                            if (items.length > 1)
                              IconButton(
                                icon: const Icon(
                                  Icons.delete_outline,
                                  color: Colors.red,
                                  size: 20,
                                ),
                                onPressed: () {
                                  setDialogState(() {
                                    items.removeAt(idx);
                                  });
                                },
                              ),
                          ],
                        ),
                      );
                    }),
                    const Divider(),
                    const SizedBox(height: 8),
                    // TOTALS & PAYMENT SECTION
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(
                          child: Column(
                            children: [
                              DropdownButtonFormField<String>(
                                initialValue: paymentMethod,
                                decoration: const InputDecoration(
                                  labelText: 'Payment Method',
                                  border: OutlineInputBorder(),
                                  isDense: true,
                                ),
                                items: const [
                                  DropdownMenuItem(
                                    value: 'Cash',
                                    child: Text('Cash'),
                                  ),
                                  DropdownMenuItem(
                                    value: 'UPI',
                                    child: Text('UPI / GPay / PhonePe'),
                                  ),
                                  DropdownMenuItem(
                                    value: 'Card',
                                    child: Text('Card'),
                                  ),
                                  DropdownMenuItem(
                                    value: 'Bank Transfer',
                                    child: Text('Bank Transfer'),
                                  ),
                                  DropdownMenuItem(
                                    value: 'Other',
                                    child: Text('Other'),
                                  ),
                                ],
                                onChanged: (val) {
                                  if (val != null) {
                                    setDialogState(() => paymentMethod = val);
                                  }
                                },
                              ),
                              const SizedBox(height: 8),
                              TextField(
                                controller: notesCtrl,
                                decoration: const InputDecoration(
                                  labelText: 'Notes / Remarks',
                                  border: OutlineInputBorder(),
                                  isDense: true,
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(width: 24),
                        // Calculation Box
                        Container(
                          width: 260,
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: const Color(0xFFF8FAFC),
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(color: const Color(0xFFE2E6F0)),
                          ),
                          child: Column(
                            children: [
                              Row(
                                mainAxisAlignment:
                                    MainAxisAlignment.spaceBetween,
                                children: [
                                  const Text('Subtotal:'),
                                  Text(
                                    _currency(subtotal),
                                    style: const TextStyle(
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 6),
                              Row(
                                mainAxisAlignment:
                                    MainAxisAlignment.spaceBetween,
                                children: [
                                  const Text('Discount (₹):'),
                                  SizedBox(
                                    width: 80,
                                    child: TextField(
                                      controller: discountCtrl,
                                      keyboardType:
                                          const TextInputType.numberWithOptions(
                                            decimal: true,
                                          ),
                                      decoration: const InputDecoration(
                                        border: OutlineInputBorder(),
                                        isDense: true,
                                        contentPadding: EdgeInsets.symmetric(
                                          horizontal: 6,
                                          vertical: 4,
                                        ),
                                      ),
                                      onChanged: (val) {
                                        setDialogState(() {
                                          discount = double.tryParse(val) ?? 0;
                                          final newTotal =
                                              (subtotal - discount + tax).clamp(
                                                0.0,
                                                double.infinity,
                                              );
                                          paidCtrl.text = newTotal
                                              .toStringAsFixed(2);
                                        });
                                      },
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 6),
                              Row(
                                mainAxisAlignment:
                                    MainAxisAlignment.spaceBetween,
                                children: [
                                  const Text('Tax (₹):'),
                                  SizedBox(
                                    width: 80,
                                    child: TextField(
                                      controller: taxCtrl,
                                      keyboardType:
                                          const TextInputType.numberWithOptions(
                                            decimal: true,
                                          ),
                                      decoration: const InputDecoration(
                                        border: OutlineInputBorder(),
                                        isDense: true,
                                        contentPadding: EdgeInsets.symmetric(
                                          horizontal: 6,
                                          vertical: 4,
                                        ),
                                      ),
                                      onChanged: (val) {
                                        setDialogState(() {
                                          tax = double.tryParse(val) ?? 0;
                                          final newTotal =
                                              (subtotal - discount + tax).clamp(
                                                0.0,
                                                double.infinity,
                                              );
                                          paidCtrl.text = newTotal
                                              .toStringAsFixed(2);
                                        });
                                      },
                                    ),
                                  ),
                                ],
                              ),
                              const Divider(),
                              Row(
                                mainAxisAlignment:
                                    MainAxisAlignment.spaceBetween,
                                children: [
                                  const Text(
                                    'Grand Total:',
                                    style: TextStyle(
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                  Text(
                                    _currency(grandTotal),
                                    style: const TextStyle(
                                      fontWeight: FontWeight.w900,
                                      fontSize: 16,
                                      color: primaryGreen,
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 6),
                              Row(
                                mainAxisAlignment:
                                    MainAxisAlignment.spaceBetween,
                                children: [
                                  const Text('Amount Paid:'),
                                  SizedBox(
                                    width: 90,
                                    child: TextField(
                                      controller: paidCtrl,
                                      keyboardType:
                                          const TextInputType.numberWithOptions(
                                            decimal: true,
                                          ),
                                      decoration: const InputDecoration(
                                        border: OutlineInputBorder(),
                                        isDense: true,
                                        contentPadding: EdgeInsets.symmetric(
                                          horizontal: 6,
                                          vertical: 4,
                                        ),
                                      ),
                                      onChanged: (val) {},
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(dialogCtx),
                child: const Text('Cancel'),
              ),
              ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: primaryGreen,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 20,
                    vertical: 12,
                  ),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
                onPressed: () async {
                  if (items.isEmpty) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('Please add at least one item'),
                        backgroundColor: Colors.red,
                      ),
                    );
                    return;
                  }
                  final payload = {
                    'customer_id': selectedCustomerId,
                    'discount': discount,
                    'tax_amount': tax,
                    'paid_amount':
                        double.tryParse(paidCtrl.text.trim()) ?? grandTotal,
                    'payment_method': paymentMethod,
                    'sale_date': DateTime.now().toIso8601String().substring(
                      0,
                      10,
                    ),
                    'notes': notesCtrl.text.trim(),
                    'items': items.map((it) {
                      return {
                        'product_id': it['product_id'],
                        'quantity': it['quantity'],
                        'price': it['price'],
                      };
                    }).toList(),
                  };
                  Navigator.pop(dialogCtx);
                  try {
                    await _api.post('/billing/invoices', payload);
                    if (mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text(
                            'Invoice generated and stock updated successfully!',
                          ),
                          backgroundColor: primaryGreen,
                        ),
                      );
                      _loadBillingData();
                    }
                  } catch (e) {
                    if (mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text(
                            'Failed to save invoice: ${e.toString().replaceAll('Exception: ', '')}',
                          ),
                          backgroundColor: Colors.red,
                        ),
                      );
                    }
                  }
                },
                child: const Text('Save & Print Invoice'),
              ),
            ],
          );
        },
      ),
    );
  }

  Future<bool> _triggerSlipDownload(Map<String, dynamic> fullInvoice) async {
    final invoiceNo = fullInvoice['invoice_no']?.toString() ?? 'RECEIPT';
    final rawDate =
        fullInvoice['sale_date']?.toString() ??
        DateTime.now().toIso8601String();
    final date = rawDate.split('T').first;
    final itemsList = (fullInvoice['items'] is List)
        ? (fullInvoice['items'] as List)
              .whereType<Map>()
              .map((e) => Map<String, dynamic>.from(e))
              .toList()
        : <Map<String, dynamic>>[];

    final refNo =
        fullInvoice['reference_no']?.toString() ??
        (fullInvoice['payments'] is List &&
                (fullInvoice['payments'] as List).isNotEmpty
            ? (fullInvoice['payments'][0]['reference_no']?.toString() ?? '')
            : '');

    final html = buildReceiptSlipHtml(
      shopName:
          (_shopSettings['shop_name']?.toString().trim().isNotEmpty == true)
          ? _shopSettings['shop_name'].toString().trim()
          : 'Paint Shop',
      shopAddress: _shopSettings['address']?.toString().trim() ?? '',
      shopPhone: _shopSettings['phone']?.toString().trim() ?? '',
      shopGst: _shopSettings['gst_number']?.toString().trim() ?? '',
      invoiceNo: invoiceNo,
      date: date,
      customerName:
          fullInvoice['customer_name']?.toString() ?? 'Walk-in Customer',
      customerPhone: fullInvoice['customer_phone']?.toString() ?? '',
      customerAddress:
          fullInvoice['customer_address']?.toString() ??
          fullInvoice['address']?.toString() ??
          '',
      paymentRef: refNo,
      paymentMethod:
          fullInvoice['payment_method']?.toString() ?? _posPaymentMethod,
      paymentStatus: fullInvoice['payment_status']?.toString() ?? 'Paid',
      items: itemsList,
      subtotal:
          double.tryParse(fullInvoice['subtotal']?.toString() ?? '0') ?? 0,
      discount:
          double.tryParse(fullInvoice['discount']?.toString() ?? '0') ?? 0,
      taxAmount:
          double.tryParse(fullInvoice['tax_amount']?.toString() ?? '0') ?? 0,
      totalAmount:
          double.tryParse(fullInvoice['total_amount']?.toString() ?? '0') ?? 0,
      paidAmount:
          double.tryParse(fullInvoice['paid_amount']?.toString() ?? '0') ?? 0,
      balanceAmount:
          double.tryParse(fullInvoice['balance_amount']?.toString() ?? '0') ??
          0,
      footerText:
          (_shopSettings['invoice_footer']?.toString().trim().isNotEmpty ==
              true)
          ? _shopSettings['invoice_footer'].toString().trim()
          : 'Thank you for your business!',
    );

    final safeFileName =
        'Receipt_${invoiceNo.replaceAll(RegExp(r'[^a-zA-Z0-9_-]'), '_')}.html';
    return await downloadReceiptSlip(fileName: safeFileName, htmlContent: html);
  }

  Future<void> _showReceiptSlipDialog(
    dynamic invoice, {
    bool isNewSale = false,
  }) async {
    Map<String, dynamic> fullInvoice = invoice is Map
        ? Map<String, dynamic>.from(invoice)
        : {};
    if (fullInvoice['id'] != null) {
      try {
        final res = await _api.get('/billing/invoices/${fullInvoice['id']}');
        if (res is Map && res['data'] is Map) {
          fullInvoice = Map<String, dynamic>.from(res['data']);
        }
      } catch (_) {}
    }
    if (!mounted) return;

    final shopName =
        (_shopSettings['shop_name']?.toString().trim().isNotEmpty == true)
        ? _shopSettings['shop_name'].toString().trim()
        : 'Paint Shop';
    final shopAddress = _shopSettings['address']?.toString().trim() ?? '';
    final shopPhone = _shopSettings['phone']?.toString().trim() ?? '';
    final shopGst = _shopSettings['gst_number']?.toString().trim() ?? '';
    final footerText =
        (_shopSettings['invoice_footer']?.toString().trim().isNotEmpty == true)
        ? _shopSettings['invoice_footer'].toString().trim()
        : 'Thank you for your business!';

    final invoiceNo = fullInvoice['invoice_no']?.toString() ?? '-';
    final date =
        (fullInvoice['sale_date']?.toString() ??
                DateTime.now().toIso8601String())
            .split('T')
            .first;
    final customerName =
        fullInvoice['customer_name']?.toString() ?? 'Walk-in Customer';
    final customerPhone = fullInvoice['customer_phone']?.toString() ?? '';
    final customerAddress =
        fullInvoice['customer_address']?.toString() ??
        fullInvoice['address']?.toString() ??
        '';
    final refNo =
        fullInvoice['reference_no']?.toString() ??
        (fullInvoice['payments'] is List &&
                (fullInvoice['payments'] as List).isNotEmpty
            ? (fullInvoice['payments'][0]['reference_no']?.toString() ?? '')
            : '');
    final paymentMethod =
        fullInvoice['payment_method']?.toString() ?? _posPaymentMethod;
    final paymentStatus = fullInvoice['payment_status']?.toString() ?? 'Paid';
    final items = (fullInvoice['items'] is List)
        ? fullInvoice['items'] as List
        : [];

    final subtotal =
        double.tryParse(fullInvoice['subtotal']?.toString() ?? '0') ?? 0;
    final discount =
        double.tryParse(fullInvoice['discount']?.toString() ?? '0') ?? 0;
    final taxAmount =
        double.tryParse(fullInvoice['tax_amount']?.toString() ?? '0') ?? 0;
    final totalAmount =
        double.tryParse(fullInvoice['total_amount']?.toString() ?? '0') ?? 0;
    final paidAmount =
        double.tryParse(fullInvoice['paid_amount']?.toString() ?? '0') ?? 0;
    final balanceAmount =
        double.tryParse(fullInvoice['balance_amount']?.toString() ?? '0') ?? 0;

    final bool? downloaded = await showDialog<bool>(
      context: context,
      barrierDismissible: !isNewSale,
      builder: (ctx) => Dialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        backgroundColor: Colors.white,
        child: Container(
          width: 420,
          constraints: const BoxConstraints(maxHeight: 680),
          padding: const EdgeInsets.all(20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Row(
                    children: [
                      Icon(
                        Icons.receipt_long_rounded,
                        color: posBlue,
                        size: 20,
                      ),
                      SizedBox(width: 8),
                      Text(
                        'Receipt Slip',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: navy,
                        ),
                      ),
                    ],
                  ),
                  IconButton(
                    icon: const Icon(
                      Icons.close,
                      size: 20,
                      color: Color(0xFF64748B),
                    ),
                    onPressed: () => Navigator.pop(ctx, false),
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Flexible(
                child: SingleChildScrollView(
                  child: Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(18),
                    decoration: BoxDecoration(
                      color: const Color(0xFFF8FAFC),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: const Color(0xFFE2E8F0)),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Text(
                          shopName,
                          textAlign: TextAlign.center,
                          style: const TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.w800,
                            color: navy,
                          ),
                        ),
                        if (shopAddress.isNotEmpty)
                          Padding(
                            padding: const EdgeInsets.only(top: 3),
                            child: Text(
                              shopAddress,
                              textAlign: TextAlign.center,
                              style: const TextStyle(
                                fontSize: 12,
                                color: Color(0xFF64748B),
                              ),
                            ),
                          ),
                        if (shopPhone.isNotEmpty)
                          Text(
                            'Ph: $shopPhone',
                            textAlign: TextAlign.center,
                            style: const TextStyle(
                              fontSize: 12,
                              color: Color(0xFF64748B),
                            ),
                          ),
                        if (shopGst.isNotEmpty)
                          Text(
                            'GSTIN: $shopGst',
                            textAlign: TextAlign.center,
                            style: const TextStyle(
                              fontSize: 12,
                              color: Color(0xFF64748B),
                            ),
                          ),
                        const Padding(
                          padding: EdgeInsets.symmetric(vertical: 12),
                          child: Divider(height: 1, color: Color(0xFFCBD5E1)),
                        ),
                        _slipMetaRow('Invoice No:', invoiceNo),
                        _slipMetaRow('Date:', date),
                        _slipMetaRow('Customer:', customerName),
                        if (customerPhone.isNotEmpty)
                          _slipMetaRow('Phone:', customerPhone),
                        if (customerAddress.isNotEmpty)
                          _slipMetaRow('Address:', customerAddress),
                        _slipMetaRow(
                          'Payment:',
                          '$paymentMethod ($paymentStatus)',
                        ),
                        if (refNo.isNotEmpty)
                          _slipMetaRow('Ref / Txn No:', refNo),
                        const Padding(
                          padding: EdgeInsets.symmetric(vertical: 12),
                          child: Divider(height: 1, color: Color(0xFFCBD5E1)),
                        ),
                        const Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              'ITEM',
                              style: TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.w700,
                                color: Color(0xFF64748B),
                              ),
                            ),
                            Text(
                              'AMOUNT',
                              style: TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.w700,
                                color: Color(0xFF64748B),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        if (items.isEmpty)
                          const Text(
                            'No line items',
                            style: TextStyle(
                              fontSize: 12,
                              color: Color(0xFF64748B),
                            ),
                          )
                        else
                          ...items.map((it) {
                            final name =
                                it['product_name']?.toString() ?? 'Item';
                            final qty = it['quantity']?.toString() ?? '1';
                            final unitPrice =
                                (double.tryParse(
                                          it['unit_price']?.toString() ?? '0',
                                        ) ??
                                        0)
                                    .toStringAsFixed(2);
                            final lineTotal =
                                double.tryParse(
                                  it['line_total']?.toString() ?? '0',
                                ) ??
                                0;
                            return Padding(
                              padding: const EdgeInsets.only(bottom: 8),
                              child: Row(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                mainAxisAlignment:
                                    MainAxisAlignment.spaceBetween,
                                children: [
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          name,
                                          style: const TextStyle(
                                            fontSize: 13,
                                            fontWeight: FontWeight.w600,
                                            color: navy,
                                          ),
                                        ),
                                        Text(
                                          '$qty x ₹$unitPrice',
                                          style: const TextStyle(
                                            fontSize: 11,
                                            color: Color(0xFF64748B),
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                  Text(
                                    _currency(lineTotal),
                                    style: const TextStyle(
                                      fontSize: 13,
                                      fontWeight: FontWeight.w600,
                                      color: navy,
                                    ),
                                  ),
                                ],
                              ),
                            );
                          }),
                        const Padding(
                          padding: EdgeInsets.symmetric(vertical: 10),
                          child: Divider(height: 1, color: Color(0xFFCBD5E1)),
                        ),
                        _slipMetaRow('Subtotal', _currency(subtotal)),
                        if (discount > 0)
                          _slipMetaRow('Discount', '-${_currency(discount)}'),
                        _slipMetaRow('GST / Tax', _currency(taxAmount)),
                        const SizedBox(height: 6),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            const Text(
                              'Grand Total',
                              style: TextStyle(
                                fontSize: 15,
                                fontWeight: FontWeight.w800,
                                color: navy,
                              ),
                            ),
                            Text(
                              _currency(totalAmount),
                              style: const TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.w800,
                                color: posBlue,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 4),
                        _slipMetaRow('Paid Amount', _currency(paidAmount)),
                        if (balanceAmount > 0)
                          _slipMetaRow('Balance Due', _currency(balanceAmount)),
                        const Padding(
                          padding: EdgeInsets.symmetric(vertical: 10),
                          child: Divider(height: 1, color: Color(0xFFCBD5E1)),
                        ),
                        Text(
                          footerText,
                          textAlign: TextAlign.center,
                          style: const TextStyle(
                            fontSize: 12,
                            color: Color(0xFF64748B),
                            fontStyle: FontStyle.italic,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () => Navigator.pop(ctx, false),
                      style: OutlinedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 13),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10),
                        ),
                      ),
                      child: const Text('Close'),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    flex: 2,
                    child: ElevatedButton.icon(
                      onPressed: () => Navigator.pop(ctx, true),
                      icon: const Icon(Icons.download_rounded, size: 18),
                      label: const Text('Download Slip'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: posBlue,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 13),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );

    if (!mounted) return;

    if (downloaded == true) {
      final ok = await _triggerSlipDownload(fullInvoice);
      if (!mounted) return;
      if (isNewSale) {
        AppToast.showSuccess(
          context,
          title: 'Sale Completed!',
          message: ok
              ? 'Receipt slip downloaded & sale completed successfully.'
              : 'Sale recorded successfully.',
        );
      } else {
        AppToast.showSuccess(
          context,
          title: 'Receipt Downloaded',
          message: ok
              ? 'Receipt slip downloaded successfully.'
              : 'Slip preview generated.',
        );
      }
    } else if (isNewSale) {
      AppToast.showSuccess(
        context,
        title: 'Sale Completed!',
        message: 'Invoice created & saved successfully.',
      );
    }
  }

  Widget _slipMetaRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: const TextStyle(fontSize: 12, color: Color(0xFF64748B)),
          ),
          Flexible(
            child: Text(
              value,
              textAlign: TextAlign.right,
              style: const TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: navy,
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _showInvoiceDetails(dynamic invoice) async {
    dynamic fullInvoice;
    try {
      final res = await _api.get('/billing/invoices/${invoice['id']}');
      fullInvoice = res['data'];
    } catch (_) {
      fullInvoice = invoice;
    }
    if (!mounted) return;
    // Derive balance from total and paid amount so the UI matches backend validation.
    final totalAmount =
        double.tryParse(fullInvoice['total_amount']?.toString() ?? '0') ?? 0;
    final paidAmount =
        double.tryParse(fullInvoice['paid_amount']?.toString() ?? '0') ?? 0;
    final balance = (totalAmount - paidAmount).clamp(0.0, double.infinity);
    final paymentAmountCtrl = TextEditingController(
      text: balance.toStringAsFixed(2),
    );
    String paymentMethod = 'Cash';
    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (dialogCtx, setDialogState) => AlertDialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          title: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Invoice: ${fullInvoice['invoice_no']}',
                style: const TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 18,
                  color: navy,
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 4,
                ),
                decoration: BoxDecoration(
                  color: fullInvoice['payment_status'] == 'Paid'
                      ? Colors.green.shade50
                      : Colors.orange.shade50,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(
                    color: fullInvoice['payment_status'] == 'Paid'
                        ? Colors.green.shade400
                        : Colors.orange.shade400,
                  ),
                ),
                child: Text(
                  fullInvoice['payment_status'] ?? 'Unpaid',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    color: fullInvoice['payment_status'] == 'Paid'
                        ? Colors.green.shade800
                        : Colors.orange.shade800,
                  ),
                ),
              ),
            ],
          ),
          content: SizedBox(
            width: 580,
            child: SingleChildScrollView(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Customer: ${fullInvoice['customer_name'] ?? 'Walk-in Customer'}',
                            style: const TextStyle(fontWeight: FontWeight.bold),
                          ),
                          if (fullInvoice['customer_phone'] != null)
                            Text(
                              'Phone: ${fullInvoice['customer_phone']}',
                              style: const TextStyle(
                                fontSize: 12,
                                color: Colors.grey,
                              ),
                            ),
                        ],
                      ),
                      Text(
                        'Date: ${fullInvoice['sale_date']?.toString().split('T').first ?? '-'}',
                        style: const TextStyle(
                          fontSize: 13,
                          color: Colors.grey,
                        ),
                      ),
                    ],
                  ),
                  const Divider(height: 24),
                  // Line Items
                  const Text(
                    'Items',
                    style: TextStyle(fontWeight: FontWeight.bold, color: navy),
                  ),
                  const SizedBox(height: 8),
                  if (fullInvoice['items'] is List &&
                      (fullInvoice['items'] as List).isNotEmpty)
                    Container(
                      decoration: BoxDecoration(
                        color: const Color(0xFFF8FAFC),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Column(
                        children: (fullInvoice['items'] as List).map<Widget>((
                          it,
                        ) {
                          return Padding(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 12,
                              vertical: 6,
                            ),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Expanded(
                                  child: Text(it['product_name'] ?? 'Item'),
                                ),
                                Text(
                                  '${it['quantity']} x ₹${it['unit_price']}',
                                ),
                                const SizedBox(width: 20),
                                Text(
                                  _currency(it['line_total']),
                                  style: const TextStyle(
                                    fontWeight: FontWeight.bold,
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
                      'No line items available',
                      style: TextStyle(color: Colors.grey),
                    ),
                  const Divider(height: 24),
                  // Financial Breakdown
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text('Total Amount:'),
                      Text(
                        _currency(fullInvoice['total_amount']),
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 16,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text('Paid Amount:'),
                      Text(
                        _currency(fullInvoice['paid_amount']),
                        style: const TextStyle(
                          color: Colors.green,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text('Balance Due:'),
                      Text(
                        _currency(fullInvoice['balance_amount']),
                        style: TextStyle(
                          color: balance > 0 ? Colors.red : Colors.grey,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                  // Record payment section if balance is due
                  if (balance > 0) ...[
                    const Divider(height: 24),
                    const Text(
                      'Record Payment',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        color: navy,
                        fontSize: 15,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        Expanded(
                          child: TextField(
                            controller: paymentAmountCtrl,
                            keyboardType: const TextInputType.numberWithOptions(
                              decimal: true,
                            ),
                            decoration: const InputDecoration(
                              labelText: 'Payment Amount (₹)',
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
                              labelText: 'Method',
                              border: OutlineInputBorder(),
                              isDense: true,
                            ),
                            items: const [
                              DropdownMenuItem(
                                value: 'Cash',
                                child: Text('Cash'),
                              ),
                              DropdownMenuItem(
                                value: 'UPI',
                                child: Text('UPI'),
                              ),
                              DropdownMenuItem(
                                value: 'Card',
                                child: Text('Card'),
                              ),
                            ],
                            onChanged: (val) {
                              if (val != null) {
                                setDialogState(() => paymentMethod = val);
                              }
                            },
                          ),
                        ),
                        const SizedBox(width: 12),
                        ElevatedButton(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: primaryGreen,
                            foregroundColor: Colors.white,
                          ),
                          onPressed: () async {
                            final amt =
                                double.tryParse(
                                  paymentAmountCtrl.text.trim(),
                                ) ??
                                0;
                            if (amt <= 0) return;
                            try {
                              await _api.post(
                                '/billing/invoices/${fullInvoice['id']}/payments',
                                {
                                  'amount': amt,
                                  'payment_method': paymentMethod,
                                },
                              );
                              if (!dialogCtx.mounted) return;
                              Navigator.pop(dialogCtx);
                              if (mounted) {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  const SnackBar(
                                    content: Text('Payment recorded!'),
                                    backgroundColor: primaryGreen,
                                  ),
                                );
                                _loadBillingData();
                              }
                            } catch (e) {
                              if (mounted) {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(
                                    content: Text(
                                      'Error: ${e.toString().replaceAll('Exception: ', '')}',
                                    ),
                                    backgroundColor: Colors.red,
                                  ),
                                );
                              }
                            }
                          },
                          child: const Text('Add Payment'),
                        ),
                      ],
                    ),
                  ],
                ],
              ),
            ),
          ),
          actions: [
            TextButton.icon(
              onPressed: () {
                Navigator.pop(dialogCtx);
                _showReceiptSlipDialog(fullInvoice);
              },
              icon: const Icon(Icons.download_rounded, size: 18),
              label: const Text('Receipt Slip'),
            ),
            TextButton(
              onPressed: () => Navigator.pop(dialogCtx),
              child: const Text('Close'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSummaryCard(
    String title,
    String value,
    IconData icon,
    Color color,
  ) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFE2E6F0)),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(icon, color: color, size: 22),
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
                    fontSize: 12,
                    color: Color(0xFF64748B),
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  value,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w900,
                    color: color,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatusFilterTabs() {
    const statuses = ['All', 'Paid', 'Partial', 'Unpaid'];
    final screenW = MediaQuery.sizeOf(context).width;
    final tabW = screenW < 420 ? 58.0 : 74.0;
    return Container(
      height: 42,
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: const Color(0xFFF1F5F9),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: const Color(0xFFE2E6F0)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: List.generate(statuses.length, (index) {
          final status = statuses[index];
          final isSelected = _statusFilter == status;
          return Padding(
            padding: EdgeInsets.only(
              right: index < statuses.length - 1 ? 4 : 0,
            ),
            child: Material(
              color: Colors.transparent,
              child: InkWell(
                borderRadius: BorderRadius.circular(7),
                onTap: () {
                  if (_statusFilter == status) return;
                  setState(() => _statusFilter = status);
                  _loadBillingData();
                },
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 160),
                  curve: Curves.easeOut,
                  width: tabW,
                  height: double.infinity,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: isSelected
                        ? const Color(0xFF1E40AF)
                        : Colors.white.withValues(alpha: 0.7),
                    borderRadius: BorderRadius.circular(7),
                    boxShadow: isSelected
                        ? [
                            BoxShadow(
                              color: const Color(0xFF1E40AF)
                                  .withValues(alpha: 0.22),
                              blurRadius: 4,
                              offset: const Offset(0, 1),
                            ),
                          ]
                        : null,
                  ),
                  child: Text(
                    status,
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: isSelected
                          ? FontWeight.w600
                          : FontWeight.w500,
                      color: isSelected
                          ? Colors.white
                          : const Color(0xFF334155),
                    ),
                  ),
                ),
              ),
            ),
          );
        }),
      ),
    );
  }

  String _productCode(dynamic p) {
    final sku = (p['sku'] ?? '').toString().trim();
    if (sku.isNotEmpty) return sku;
    final id = (p['id'] ?? '').toString();
    return 'PNT-${id.padLeft(3, '0')}';
  }

  void _addToCart(dynamic product) {
    final stock = double.tryParse(product['stock_qty']?.toString() ?? '0') ?? 0;
    if (stock <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('${product['product_name']} is out of stock'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    final productId = product['id'];
    final existingIdx = _cart.indexWhere(
      (item) => item['product_id'] == productId,
    );

    setState(() {
      if (existingIdx >= 0) {
        final currentQty = _cart[existingIdx]['quantity'] as double;
        if (currentQty + 1 > stock) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                'Only ${stock.toInt()} in stock for ${product['product_name']}',
              ),
              backgroundColor: warningOrange,
            ),
          );
          return;
        }
        _cart[existingIdx]['quantity'] = currentQty + 1;
      } else {
        _cart.add({
          'product_id': productId,
          'product_name': product['product_name']?.toString() ?? 'Product',
          'sku': _productCode(product),
          'price':
              double.tryParse(product['selling_price']?.toString() ?? '0') ??
              0.0,
          'quantity': 1.0,
          'stock': stock,
        });
      }
    });
  }

  void _updateCartQty(int index, double delta) {
    if (index < 0 || index >= _cart.length) return;
    final item = _cart[index];
    final nextQty = (item['quantity'] as double) + delta;
    final stock = item['stock'] as double;

    if (nextQty <= 0) {
      setState(() => _cart.removeAt(index));
      return;
    }
    if (nextQty > stock) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Max available stock is ${stock.toInt()} for ${item['product_name']}',
          ),
          backgroundColor: warningOrange,
        ),
      );
      return;
    }
    setState(() => _cart[index]['quantity'] = nextQty);
  }

  void _showCustomerFormDialog() {
    final nameCtrl = TextEditingController(text: _posCustomerNameCtrl.text);
    final phoneCtrl = TextEditingController(text: _posCustomerPhoneCtrl.text);
    final addressCtrl = TextEditingController(
      text: _posCustomerAddressCtrl.text,
    );
    int? tempSelectedId = _selectedCustomerId;

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (dialogCtx, setDialogState) => Dialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          backgroundColor: Colors.white,
          child: Container(
            width: 440,
            padding: const EdgeInsets.all(22),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // Header
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Row(
                      children: [
                        Icon(
                          Icons.person_add_alt_1_rounded,
                          color: posBlue,
                          size: 22,
                        ),
                        SizedBox(width: 8),
                        Text(
                          'Customer Details',
                          style: TextStyle(
                            fontSize: 16.5,
                            fontWeight: FontWeight.w800,
                            color: navy,
                          ),
                        ),
                      ],
                    ),
                    IconButton(
                      icon: const Icon(
                        Icons.close_rounded,
                        size: 20,
                        color: Color(0xFF64748B),
                      ),
                      onPressed: () => Navigator.pop(dialogCtx),
                      padding: EdgeInsets.zero,
                      constraints: const BoxConstraints(),
                    ),
                  ],
                ),
                const SizedBox(height: 16),

                // Name Field
                const Text(
                  'Customer Name',
                  style: TextStyle(
                    fontSize: 12.5,
                    fontWeight: FontWeight.w600,
                    color: Color(0xFF334155),
                  ),
                ),
                const SizedBox(height: 6),
                SizedBox(
                  height: 42,
                  child: TextField(
                    controller: nameCtrl,
                    textAlignVertical: TextAlignVertical.center,
                    inputFormatters: const [NoLeadingSpaceFormatter()],
                    onChanged: (val) {
                      final match = _customers.firstWhere(
                        (c) =>
                            c['name']?.toString().toLowerCase().trim() ==
                            val.toLowerCase().trim(),
                        orElse: () => {},
                      );
                      if (match.isNotEmpty) {
                        setDialogState(() {
                          tempSelectedId = match['id'] as int?;
                          if (phoneCtrl.text.isEmpty &&
                              match['phone'] != null) {
                            phoneCtrl.text = match['phone'].toString();
                          }
                          if (addressCtrl.text.isEmpty &&
                              match['address'] != null) {
                            addressCtrl.text = match['address'].toString();
                          }
                        });
                      }
                    },
                    decoration: InputDecoration(
                      hintText: 'Customer Name',
                      hintStyle: const TextStyle(
                        fontSize: 12.5,
                        color: Color(0xFF94A3B8),
                      ),
                      prefixIcon: const Icon(
                        Icons.person_outline_rounded,
                        size: 18,
                        color: Color(0xFF64748B),
                      ),
                      suffixIcon: _customers.isNotEmpty
                          ? PopupMenuButton<Map<String, dynamic>>(
                              tooltip: 'Select Existing Customer',
                              icon: const Icon(
                                Icons.arrow_drop_down,
                                size: 22,
                                color: Color(0xFF64748B),
                              ),
                              padding: EdgeInsets.zero,
                              onSelected: (cust) {
                                setDialogState(() {
                                  tempSelectedId = cust['id'] as int?;
                                  nameCtrl.text =
                                      cust['name']?.toString() ?? '';
                                  phoneCtrl.text =
                                      cust['phone']?.toString() ?? '';
                                  addressCtrl.text =
                                      cust['address']?.toString() ?? '';
                                });
                              },
                              itemBuilder: (ctx) => _customers.take(30).map((
                                c,
                              ) {
                                return PopupMenuItem<Map<String, dynamic>>(
                                  value: c,
                                  height: 38,
                                  child: Text(
                                    '${c['name']} ${c['phone'] != null && c['phone'].toString().isNotEmpty ? '(${c['phone']})' : ''}',
                                    style: const TextStyle(fontSize: 12.5),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                );
                              }).toList(),
                            )
                          : null,
                      filled: true,
                      fillColor: const Color(0xFFF8FAFC),
                      isDense: true,
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 10,
                      ),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(9),
                        borderSide: const BorderSide(color: Color(0xFFCBD5E1)),
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(9),
                        borderSide: const BorderSide(color: Color(0xFFCBD5E1)),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(9),
                        borderSide: const BorderSide(
                          color: posBlue,
                          width: 1.5,
                        ),
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 12),

                // Mobile Number
                const Text(
                  'Mobile Number',
                  style: TextStyle(
                    fontSize: 12.5,
                    fontWeight: FontWeight.w600,
                    color: Color(0xFF334155),
                  ),
                ),
                const SizedBox(height: 6),
                SizedBox(
                  height: 42,
                  child: TextField(
                    controller: phoneCtrl,
                    keyboardType: TextInputType.phone,
                    textAlignVertical: TextAlignVertical.center,
                    inputFormatters: const [PhoneNumberFormatter()],
                    onChanged: (val) {
                      if (val.length >= 7) {
                        final match = _customers.firstWhere(
                          (c) =>
                              c['phone']?.toString().replaceAll(
                                RegExp(r'\D'),
                                '',
                              ) ==
                              val.replaceAll(RegExp(r'\D'), ''),
                          orElse: () => {},
                        );
                        if (match.isNotEmpty) {
                          setDialogState(() {
                            tempSelectedId = match['id'] as int?;
                            if (nameCtrl.text.isEmpty &&
                                match['name'] != null) {
                              nameCtrl.text = match['name'].toString();
                            }
                            if (addressCtrl.text.isEmpty &&
                                match['address'] != null) {
                              addressCtrl.text = match['address'].toString();
                            }
                          });
                        }
                      }
                    },
                    decoration: InputDecoration(
                      hintText: 'Mobile Number',
                      hintStyle: const TextStyle(
                        fontSize: 12.5,
                        color: Color(0xFF94A3B8),
                      ),
                      prefixIcon: const Icon(
                        Icons.phone_outlined,
                        size: 18,
                        color: Color(0xFF64748B),
                      ),
                      filled: true,
                      fillColor: const Color(0xFFF8FAFC),
                      isDense: true,
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 10,
                      ),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(9),
                        borderSide: const BorderSide(color: Color(0xFFCBD5E1)),
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(9),
                        borderSide: const BorderSide(color: Color(0xFFCBD5E1)),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(9),
                        borderSide: const BorderSide(
                          color: posBlue,
                          width: 1.5,
                        ),
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 12),

                // Address
                const Text(
                  'Address',
                  style: TextStyle(
                    fontSize: 12.5,
                    fontWeight: FontWeight.w600,
                    color: Color(0xFF334155),
                  ),
                ),
                const SizedBox(height: 6),
                SizedBox(
                  height: 42,
                  child: TextField(
                    controller: addressCtrl,
                    textAlignVertical: TextAlignVertical.center,
                    inputFormatters: const [NoLeadingSpaceFormatter()],
                    decoration: InputDecoration(
                      hintText: 'Customer Address',
                      hintStyle: const TextStyle(
                        fontSize: 12.5,
                        color: Color(0xFF94A3B8),
                      ),
                      prefixIcon: const Icon(
                        Icons.location_on_outlined,
                        size: 18,
                        color: Color(0xFF64748B),
                      ),
                      filled: true,
                      fillColor: const Color(0xFFF8FAFC),
                      isDense: true,
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 10,
                      ),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(9),
                        borderSide: const BorderSide(color: Color(0xFFCBD5E1)),
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(9),
                        borderSide: const BorderSide(color: Color(0xFFCBD5E1)),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(9),
                        borderSide: const BorderSide(
                          color: posBlue,
                          width: 1.5,
                        ),
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 20),

                // Action Buttons
                Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    TextButton(
                      onPressed: () {
                        setState(() {
                          _selectedCustomerId = null;
                          _posCustomerNameCtrl.clear();
                          _posCustomerPhoneCtrl.clear();
                          _posCustomerAddressCtrl.clear();
                        });
                        Navigator.pop(dialogCtx);
                      },
                      style: TextButton.styleFrom(
                        foregroundColor: const Color(0xFF64748B),
                      ),
                      child: const Text('Reset to Walk-in'),
                    ),
                    const SizedBox(width: 8),
                    ElevatedButton.icon(
                      onPressed: () {
                        setState(() {
                          _selectedCustomerId = tempSelectedId;
                          _posCustomerNameCtrl.text = nameCtrl.text.trim();
                          _posCustomerPhoneCtrl.text = phoneCtrl.text.trim();
                          _posCustomerAddressCtrl.text = addressCtrl.text
                              .trim();
                        });
                        Navigator.pop(dialogCtx);
                      },
                      icon: const Icon(Icons.check_rounded, size: 17),
                      label: const Text('Apply to Bill'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: posBlue,
                        foregroundColor: Colors.white,
                        elevation: 0,
                        padding: const EdgeInsets.symmetric(
                          horizontal: 18,
                          vertical: 11,
                        ),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(9),
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  void _clearCart() {
    setState(() {
      _cart.clear();
      _selectedCustomerId = null;
      _posCustomerNameCtrl.clear();
      _posCustomerPhoneCtrl.clear();
      _posCustomerAddressCtrl.clear();
      _posPaymentRefCtrl.clear();
      _posPaidAmountCtrl.clear();
    });
  }

  double get _posSubtotal {
    double sum = 0;
    for (final item in _cart) {
      sum += (item['price'] as double) * (item['quantity'] as double);
    }
    return sum;
  }

  double get _posGst => _applyGst ? _posSubtotal * 0.18 : 0.0;
  double get _posGrandTotal => _posSubtotal + _posGst;

  Future<void> _completePosSale() async {
    if (_cart.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please add at least one product to the bill'),
          backgroundColor: warningOrange,
        ),
      );
      return;
    }

    setState(() => _isSubmittingSale = true);
    try {
      final subtotal = _posSubtotal;
      final gst = _applyGst
          ? double.parse((subtotal * 0.18).toStringAsFixed(2))
          : 0.0;
      final total = double.parse((subtotal + gst).toStringAsFixed(2));

      int? finalCustomerId = _selectedCustomerId;
      final custName = _posCustomerNameCtrl.text.trim();
      final custPhone = _posCustomerPhoneCtrl.text.trim();
      final custAddress = _posCustomerAddressCtrl.text.trim();

      if (custName.isNotEmpty) {
        final match = _customers.firstWhere(
          (c) =>
              (custPhone.isNotEmpty &&
                  (c['phone']?.toString().trim() == custPhone)) ||
              (c['name']?.toString().toLowerCase().trim() ==
                  custName.toLowerCase()),
          orElse: () => {},
        );

        if (match.isNotEmpty && match['id'] != null) {
          finalCustomerId = match['id'] as int;
        } else {
          try {
            final newCustRes = await _api.post('/customers', {
              'name': custName,
              'phone': custPhone,
              'email': '',
              'address': custAddress,
            });
            if (newCustRes is Map && newCustRes['id'] != null) {
              finalCustomerId = newCustRes['id'] as int;
              _customers.insert(0, {
                'id': finalCustomerId,
                'name': custName,
                'phone': custPhone,
                'address': custAddress,
              });
            }
          } catch (_) {}
        }
      }

      final paymentRef = _posPaymentRefCtrl.text.trim();
      final paidText = _posPaidAmountCtrl.text.trim();
      final enteredPaid = double.tryParse(paidText);
      final rawPaidAmount = enteredPaid ?? total;
      final finalPaidAmount = rawPaidAmount.clamp(0.0, total);
      final changeAmount = (rawPaidAmount - total).clamp(0.0, double.infinity);

      final List<String> notesParts = [];
      if (paymentRef.isNotEmpty) notesParts.add('Payment Ref: $paymentRef');
      if (changeAmount > 0) {
        notesParts.add(
          'Tendered: ${_currency(rawPaidAmount)} | Change Returned: ${_currency(changeAmount)}',
        );
      }

      final payload = {
        'customer_id': finalCustomerId,
        'items': _cart
            .map(
              (e) => {
                'product_id': e['product_id'],
                'quantity': e['quantity'],
                'price': e['price'],
              },
            )
            .toList(),
        'discount': 0,
        'tax_amount': gst,
        'paid_amount': finalPaidAmount,
        'payment_method': _posPaymentMethod,
        if (paymentRef.isNotEmpty) 'reference_no': paymentRef,
        if (notesParts.isNotEmpty) 'notes': notesParts.join(' | '),
      };

      final res = await _api.post('/billing/invoices', payload);
      if (!mounted) return;

      setState(() {
        _cart.clear();
        _selectedCustomerId = null;
        _posCustomerNameCtrl.clear();
        _posCustomerPhoneCtrl.clear();
        _posCustomerAddressCtrl.clear();
        _posPaymentRefCtrl.clear();
        _posPaidAmountCtrl.clear();
        _isSubmittingSale = false;
      });

      await _loadBillingData();
      if (!mounted) return;

      if (res is Map && res['data'] is Map && res['data']['id'] != null) {
        _showReceiptSlipDialog(res['data'], isNewSale: true);
      } else {
        AppToast.showSuccess(
          context,
          title: 'Sale Completed!',
          message: 'Invoice created successfully.',
        );
      }
    } catch (e) {
      if (!mounted) return;
      setState(() => _isSubmittingSale = false);
      AppToast.showError(
        context,
        title: 'Sale Failed',
        message:
            'Failed to complete sale: ${e.toString().replaceAll('Exception: ', '')}',
      );
    }
  }

  Widget _buildPosBillingView() {
    final width = MediaQuery.sizeOf(context).width;
    final isDesktop = width >= 920;

    if (_isLoading) {
      return const Padding(
        padding: EdgeInsets.all(48),
        child: Center(child: CircularProgressIndicator()),
      );
    }

    if (_errorMessage != null) {
      return Padding(
        padding: const EdgeInsets.all(32),
        child: Center(
          child: Column(
            children: [
              Text(
                'Error: $_errorMessage',
                style: const TextStyle(color: Colors.red),
              ),
              const SizedBox(height: 12),
              ElevatedButton(
                onPressed: _loadBillingData,
                child: const Text('Retry'),
              ),
            ],
          ),
        ),
      );
    }

    if (!isDesktop) {
      return SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _buildProductCatalogCard(isDesktop: false),
            const SizedBox(height: 16),
            _buildCurrentBillCard(isDesktop: false),
          ],
        ),
      );
    }

    return Padding(
      padding: const EdgeInsets.all(16),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Expanded(flex: 13, child: _buildProductCatalogCard(isDesktop: true)),
          const SizedBox(width: 16),
          Expanded(flex: 8, child: _buildCurrentBillCard(isDesktop: true)),
        ],
      ),
    );
  }

  Widget _buildProductCatalogCard({required bool isDesktop}) {
    final query = _catalogSearch.trim().toLowerCase();
    final filteredProducts = _products.where((p) {
      if (query.isEmpty) return true;
      final name = (p['product_name'] ?? '').toString().toLowerCase();
      final sku = _productCode(p).toLowerCase();
      final id = (p['id'] ?? '').toString().toLowerCase();
      final shade = (p['shade_name'] ?? '').toString().toLowerCase();
      return name.contains(query) ||
          sku.contains(query) ||
          id.contains(query) ||
          shade.contains(query);
    }).toList();

    final screenW = MediaQuery.sizeOf(context).width;
    final int crossAxisCount;
    final double aspectRatio;
    if (screenW >= 1160) {
      crossAxisCount = 3;
      aspectRatio = 1.02;
    } else if (screenW >= 920) {
      crossAxisCount = 2;
      aspectRatio = 1.08;
    } else if (screenW >= 540) {
      crossAxisCount = 2;
      aspectRatio = 1.12;
    } else {
      crossAxisCount = 1;
      aspectRatio = 2.05;
    }

    final contentWidget = filteredProducts.isEmpty
        ? Center(
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 48, horizontal: 16),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    Icons.inventory_2_outlined,
                    size: 42,
                    color: Colors.grey.shade400,
                  ),
                  const SizedBox(height: 10),
                  Text(
                    _products.isEmpty
                        ? 'No products found in inventory'
                        : 'No products match "$_catalogSearch"',
                    style: TextStyle(
                      color: Colors.grey.shade600,
                      fontSize: 13.5,
                    ),
                  ),
                ],
              ),
            ),
          )
        : Scrollbar(
            thumbVisibility: isDesktop,
            child: GridView.builder(
              shrinkWrap: !isDesktop,
              physics: isDesktop
                  ? const AlwaysScrollableScrollPhysics()
                  : const NeverScrollableScrollPhysics(),
              itemCount: filteredProducts.length,
              gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: crossAxisCount,
                crossAxisSpacing: 12,
                mainAxisSpacing: 12,
                childAspectRatio: aspectRatio,
              ),
              itemBuilder: (_, idx) =>
                  _buildCatalogProductTile(filteredProducts[idx]),
            ),
          );

    return Container(
      constraints: BoxConstraints(minHeight: isDesktop ? 0 : 480),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFFE2E8F0)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.025),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Product Catalog',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w800,
                  color: navy,
                ),
              ),
              SizedBox(height: 2),
              Text(
                'Select products to add to bill',
                style: TextStyle(fontSize: 12, color: Color(0xFF64748B)),
              ),
            ],
          ),
          const SizedBox(height: 16),
          if (isDesktop) Expanded(child: contentWidget) else contentWidget,
        ],
      ),
    );
  }

  Widget _buildCatalogProductTile(dynamic p) {
    final stock = double.tryParse(p['stock_qty']?.toString() ?? '0') ?? 0;
    final price = double.tryParse(p['selling_price']?.toString() ?? '0') ?? 0;
    final code = _productCode(p);
    final name = p['product_name']?.toString() ?? 'Unnamed Product';
    final inCartIdx = _cart.indexWhere((c) => c['product_id'] == p['id']);
    final inCartQty = inCartIdx >= 0
        ? (_cart[inCartIdx]['quantity'] as double).toInt()
        : 0;
    final isOutOfStock = stock <= 0;

    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(12),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: isOutOfStock ? null : () => _addToCart(p),
        child: Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: inCartQty > 0
                  ? posBlue.withValues(alpha: 0.65)
                  : const Color(0xFFE2E8F0),
              width: inCartQty > 0 ? 1.5 : 1,
            ),
            color: isOutOfStock ? const Color(0xFFFAFAFA) : Colors.white,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Top icon / badge box
              Expanded(
                child: Container(
                  width: double.infinity,
                  decoration: BoxDecoration(
                    color: isOutOfStock
                        ? const Color(0xFFF1F5F9)
                        : const Color(0xFFEFF6FF),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Stack(
                    children: [
                      Positioned.fill(
                        child: ProductImageWidget(
                          imageUrl: p['image_url']?.toString(),
                          fit: BoxFit.cover,
                          borderRadius: BorderRadius.circular(8),
                          fallback: Center(
                            child: Icon(
                              Icons.format_paint_rounded,
                              size: 28,
                              color: isOutOfStock
                                  ? const Color(0xFF94A3B8)
                                  : posBlue,
                            ),
                          ),
                        ),
                      ),
                      if (inCartQty > 0)
                        Positioned(
                          top: 6,
                          right: 6,
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 7,
                              vertical: 2,
                            ),
                            decoration: BoxDecoration(
                              color: posBlue,
                              borderRadius: BorderRadius.circular(999),
                            ),
                            child: Text(
                              '${inCartQty}x',
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 10.5,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 8),
              Text(
                code,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  fontSize: 10.5,
                  color: Color(0xFF64748B),
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                name,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  fontSize: 13.5,
                  fontWeight: FontWeight.w700,
                  color: Color(0xFF0F172A),
                ),
              ),
              const SizedBox(height: 2),
              Text(
                isOutOfStock
                    ? 'Out of Stock'
                    : 'Stock: ${stock % 1 == 0 ? stock.toInt() : stock}',
                style: TextStyle(
                  fontSize: 11.5,
                  fontWeight: FontWeight.w600,
                  color: isOutOfStock
                      ? Colors.red.shade600
                      : const Color(0xFF475569),
                ),
              ),
              const SizedBox(height: 6),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    '₹${price % 1 == 0 ? price.toInt() : price.toStringAsFixed(2)}',
                    style: TextStyle(
                      fontSize: 14.5,
                      fontWeight: FontWeight.w800,
                      color: isOutOfStock ? const Color(0xFF94A3B8) : posBlue,
                    ),
                  ),
                  Container(
                    width: 26,
                    height: 26,
                    decoration: BoxDecoration(
                      color: isOutOfStock ? const Color(0xFFCBD5E1) : posBlue,
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(
                      Icons.add_rounded,
                      size: 17,
                      color: Colors.white,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildCurrentBillCard({bool isDesktop = false}) {
    final subtotal = _posSubtotal;
    final gst = _posGst;
    final grandTotal = _posGrandTotal;

    final cartListWidget = _cart.isEmpty
        ? Container(
            padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 12),
            decoration: BoxDecoration(
              color: const Color(0xFFF8FAFC),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: const Color(0xFFE2E8F0)),
            ),
            child: const Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  Icons.shopping_cart_outlined,
                  size: 24,
                  color: Color(0xFF94A3B8),
                ),
                SizedBox(width: 10),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      'Cart is empty',
                      style: TextStyle(
                        fontSize: 12.5,
                        fontWeight: FontWeight.w600,
                        color: Color(0xFF475569),
                      ),
                    ),
                    Text(
                      'Select products to start billing',
                      style: TextStyle(fontSize: 11, color: Color(0xFF94A3B8)),
                    ),
                  ],
                ),
              ],
            ),
          )
        : Scrollbar(
            thumbVisibility: _cart.length > 2,
            child: ListView.separated(
              shrinkWrap: !isDesktop,
              itemCount: _cart.length,
              separatorBuilder: (_, _) =>
                  const Divider(height: 10, color: Color(0xFFE2E8F0)),
              itemBuilder: (_, i) {
                final item = _cart[i];
                final qty = item['quantity'] as double;
                final price = item['price'] as double;
                final lineTotal = qty * price;
                return Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            item['product_name']?.toString() ?? '',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w700,
                              color: Color(0xFF0F172A),
                            ),
                          ),
                          const SizedBox(height: 1),
                          Text(
                            '${item['sku']} • ₹${price % 1 == 0 ? price.toInt() : price.toStringAsFixed(2)}',
                            style: const TextStyle(
                              fontSize: 11,
                              color: Color(0xFF64748B),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 6),
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        _qtyIconButton(
                          Icons.remove_rounded,
                          () => _updateCartQty(i, -1),
                        ),
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 6),
                          child: Text(
                            qty % 1 == 0 ? '${qty.toInt()}' : '$qty',
                            style: const TextStyle(
                              fontSize: 12.5,
                              fontWeight: FontWeight.w700,
                              color: Color(0xFF0F172A),
                            ),
                          ),
                        ),
                        _qtyIconButton(
                          Icons.add_rounded,
                          () => _updateCartQty(i, 1),
                        ),
                      ],
                    ),
                    const SizedBox(width: 8),
                    SizedBox(
                      width: 64,
                      child: Text(
                        '₹${lineTotal % 1 == 0 ? lineTotal.toInt() : lineTotal.toStringAsFixed(2)}',
                        textAlign: TextAlign.right,
                        style: const TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w800,
                          color: navy,
                        ),
                      ),
                    ),
                  ],
                );
              },
            ),
          );

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFFE2E8F0)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.025),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisSize: isDesktop ? MainAxisSize.max : MainAxisSize.min,
        children: [
          // Header
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'Current Bill',
                style: TextStyle(
                  fontSize: 15.5,
                  fontWeight: FontWeight.w700,
                  color: Color(0xFF1E293B),
                ),
              ),
              InkWell(
                onTap: _clearCart,
                child: const Text(
                  'Clear All',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: Color(0xFFEF4444),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),

          // Cart Section
          if (isDesktop)
            Expanded(
              child: _cart.isEmpty
                  ? Center(child: cartListWidget)
                  : cartListWidget,
            )
          else
            cartListWidget,

          const SizedBox(height: 8),

          // Customer Details Box
          if (_posCustomerNameCtrl.text.isEmpty)
            InkWell(
              borderRadius: BorderRadius.circular(8),
              onTap: _showCustomerFormDialog,
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 6,
                ),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: const Color(0xFFE2E8F0)),
                ),
                child: Row(
                  children: [
                    const Icon(
                      Icons.person_add_outlined,
                      size: 15,
                      color: Color(0xFF64748B),
                    ),
                    const SizedBox(width: 6),
                    const Expanded(
                      child: Text(
                        'Add Customer Details',
                        style: TextStyle(
                          fontSize: 11.5,
                          fontWeight: FontWeight.w500,
                          color: Color(0xFF64748B),
                        ),
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 6,
                        vertical: 2,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(4),
                        border: Border.all(color: const Color(0xFFCBD5E1)),
                      ),
                      child: const Text(
                        '+ Add',
                        style: TextStyle(
                          fontSize: 10.5,
                          fontWeight: FontWeight.w600,
                          color: Color(0xFF334155),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            )
          else
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
              decoration: BoxDecoration(
                color: const Color(0xFFF8FAFC),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: const Color(0xFFCBD5E1)),
              ),
              child: Row(
                children: [
                  const Icon(Icons.person_rounded, size: 15, color: posBlue),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      '${_posCustomerNameCtrl.text}${_posCustomerPhoneCtrl.text.isNotEmpty ? ' (${_posCustomerPhoneCtrl.text})' : ''}',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 11.5,
                        fontWeight: FontWeight.w700,
                        color: posBlue,
                      ),
                    ),
                  ),
                  InkWell(
                    onTap: _showCustomerFormDialog,
                    child: const Padding(
                      padding: EdgeInsets.symmetric(horizontal: 4, vertical: 2),
                      child: Text(
                        'Edit',
                        style: TextStyle(
                          fontSize: 11,
                          color: posBlue,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 4),
                  InkWell(
                    onTap: () {
                      setState(() {
                        _selectedCustomerId = null;
                        _posCustomerNameCtrl.clear();
                        _posCustomerPhoneCtrl.clear();
                        _posCustomerAddressCtrl.clear();
                      });
                    },
                    child: const Padding(
                      padding: EdgeInsets.symmetric(horizontal: 2, vertical: 2),
                      child: Icon(
                        Icons.close_rounded,
                        size: 15,
                        color: Color(0xFF64748B),
                      ),
                    ),
                  ),
                ],
              ),
            ),

          const SizedBox(height: 8),

          // Subtotal, GST & Grand Total Summary Box
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
            decoration: BoxDecoration(
              color: const Color(0xFFF8FAFC),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: const Color(0xFFE2E8F0)),
            ),
            child: Column(
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'Subtotal: ${_currency(subtotal)}',
                      style: const TextStyle(
                        fontSize: 11.5,
                        color: Color(0xFF64748B),
                      ),
                    ),
                    Text(
                      'GST (18%): ${_currency(gst)}',
                      style: const TextStyle(
                        fontSize: 11.5,
                        color: Color(0xFF64748B),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                const Divider(height: 1, color: Color(0xFFE2E8F0)),
                const SizedBox(height: 4),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text(
                      'Grand Total',
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                        color: Color(0xFF0F172A),
                      ),
                    ),
                    Text(
                      _currency(grandTotal),
                      style: const TextStyle(
                        fontSize: 15.5,
                        fontWeight: FontWeight.w800,
                        color: Color(0xFFEF4444),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),

          const SizedBox(height: 8),

          // Paid Amount & Payment Method side-by-side
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Paid Amount (₹)',
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w500,
                        color: Color(0xFF475569),
                      ),
                    ),
                    const SizedBox(height: 3),
                    SizedBox(
                      height: 36,
                      child: TextField(
                        controller: _posPaidAmountCtrl,
                        keyboardType: const TextInputType.numberWithOptions(
                          decimal: true,
                        ),
                        inputFormatters: const [NoLeadingSpaceFormatter()],
                        style: const TextStyle(fontSize: 12),
                        onChanged: (_) => setState(() {}),
                        decoration: InputDecoration(
                          hintText: '0.00',
                          hintStyle: const TextStyle(
                            fontSize: 11.5,
                            color: Color(0xFF94A3B8),
                          ),
                          filled: true,
                          fillColor: Colors.white,
                          isDense: true,
                          contentPadding: const EdgeInsets.symmetric(
                            horizontal: 10,
                            vertical: 6,
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
                          focusedBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(8),
                            borderSide: const BorderSide(
                              color: Color(0xFFEF4444),
                              width: 1.2,
                            ),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Payment Method',
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w500,
                        color: Color(0xFF475569),
                      ),
                    ),
                    const SizedBox(height: 3),
                    SizedBox(
                      height: 36,
                      child: DropdownButtonFormField<String>(
                        initialValue: _posPaymentMethod,
                        decoration: InputDecoration(
                          filled: true,
                          fillColor: Colors.white,
                          isDense: true,
                          contentPadding: const EdgeInsets.symmetric(
                            horizontal: 10,
                            vertical: 6,
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
                        items: ['Cash', 'UPI', 'Card', 'Bank Transfer', 'Other']
                            .map(
                              (m) => DropdownMenuItem(
                                value: m,
                                child: Text(
                                  m,
                                  style: const TextStyle(fontSize: 12),
                                ),
                              ),
                            )
                            .toList(),
                        onChanged: (val) {
                          if (val != null) {
                            setState(() {
                              _posPaymentMethod = val;
                              if (val == 'Cash') {
                                _posPaymentRefCtrl.clear();
                              }
                            });
                          }
                        },
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),

          if (_posPaymentMethod != 'Cash') ...[
            const SizedBox(height: 6),
            SizedBox(
              height: 34,
              child: TextField(
                controller: _posPaymentRefCtrl,
                textAlignVertical: TextAlignVertical.center,
                inputFormatters: const [NoLeadingSpaceFormatter()],
                style: const TextStyle(fontSize: 11.5),
                onChanged: (_) => setState(() {}),
                decoration: InputDecoration(
                  hintText: _paymentRefHint,
                  hintStyle: const TextStyle(
                    fontSize: 11,
                    color: Color(0xFF94A3B8),
                  ),
                  prefixIcon: Icon(
                    _paymentRefIcon,
                    size: 14,
                    color: const Color(0xFF64748B),
                  ),
                  filled: true,
                  fillColor: Colors.white,
                  isDense: true,
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 4,
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
                    borderSide: const BorderSide(
                      color: Color(0xFFEF4444),
                      width: 1.2,
                    ),
                  ),
                ),
              ),
            ),
          ],

          const SizedBox(height: 8),

          // Change to Return & Remaining to Pay Box
          Builder(
            builder: (context) {
              final rawPaid =
                  double.tryParse(_posPaidAmountCtrl.text.trim()) ?? 0.0;
              final hasInput = _posPaidAmountCtrl.text.trim().isNotEmpty;
              final remainingToPay = (grandTotal - rawPaid).clamp(
                0.0,
                double.infinity,
              );
              final changeToReturn = (rawPaid - grandTotal).clamp(
                0.0,
                double.infinity,
              );

              return Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 6,
                ),
                decoration: BoxDecoration(
                  color: changeToReturn > 0
                      ? const Color(0xFFF0FDF4)
                      : (remainingToPay > 0 && hasInput
                            ? const Color(0xFFFEF2F2)
                            : const Color(0xFFF8FAFC)),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(
                    color: changeToReturn > 0
                        ? const Color(0xFF86EFAC)
                        : (remainingToPay > 0 && hasInput
                              ? const Color(0xFFFECACA)
                              : const Color(0xFFE2E8F0)),
                    width: 1,
                  ),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    // Left: Change to return
                    Row(
                      children: [
                        Icon(
                          Icons.currency_exchange_rounded,
                          size: 13,
                          color: changeToReturn > 0
                              ? const Color(0xFF16A34A)
                              : const Color(0xFF64748B),
                        ),
                        const SizedBox(width: 4),
                        Text(
                          'Change: ',
                          style: TextStyle(
                            fontSize: 11.5,
                            fontWeight: FontWeight.w600,
                            color: changeToReturn > 0
                                ? const Color(0xFF15803D)
                                : const Color(0xFF475569),
                          ),
                        ),
                        Text(
                          _currency(changeToReturn),
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w800,
                            color: changeToReturn > 0
                                ? const Color(0xFF16A34A)
                                : const Color(0xFF64748B),
                          ),
                        ),
                      ],
                    ),
                    // Right: Remaining to pay
                    Row(
                      children: [
                        Icon(
                          remainingToPay > 0
                              ? Icons.pending_actions_rounded
                              : Icons.check_circle_rounded,
                          size: 13,
                          color: remainingToPay > 0
                              ? const Color(0xFFDC2626)
                              : const Color(0xFF16A34A),
                        ),
                        const SizedBox(width: 4),
                        Text(
                          'Due: ',
                          style: TextStyle(
                            fontSize: 11.5,
                            fontWeight: FontWeight.w600,
                            color: remainingToPay > 0
                                ? const Color(0xFFB91C1C)
                                : const Color(0xFF15803D),
                          ),
                        ),
                        Text(
                          remainingToPay == 0 &&
                                  (rawPaid >= grandTotal || !hasInput)
                              ? (hasInput ? '₹0.00 (Paid)' : _currency(0))
                              : _currency(remainingToPay),
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w800,
                            color: remainingToPay > 0
                                ? const Color(0xFFDC2626)
                                : const Color(0xFF16A34A),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              );
            },
          ),

          const SizedBox(height: 8),

          // Complete Sale Button
          SizedBox(
            height: 40,
            child: ElevatedButton(
              onPressed: _isSubmittingSale ? null : _completePosSale,
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFFDC2626),
                foregroundColor: Colors.white,
                elevation: 1,
                shadowColor: const Color(0xFFDC2626).withValues(alpha: 0.35),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
              child: _isSubmittingSale
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Colors.white,
                      ),
                    )
                  : const Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(
                          'Complete Sale',
                          style: TextStyle(
                            fontSize: 13.5,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        SizedBox(width: 8),
                        Icon(Icons.lock_outline_rounded, size: 15),
                      ],
                    ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _qtyIconButton(IconData icon, VoidCallback onTap) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(999),
      child: Container(
        width: 24,
        height: 24,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          border: Border.all(color: const Color(0xFFCBD5E1)),
          color: const Color(0xFFF8FAFC),
        ),
        child: Icon(icon, size: 15, color: const Color(0xFF334155)),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_activeTab == 0) {
      return Container(
        color: const Color(0xFFF5F5F5),
        child: _buildPosBillingView(),
      );
    }

    return Container(
      color: const Color(0xFFF5F5F5),
      child: SingleChildScrollView(
        padding: const EdgeInsets.only(bottom: 24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // SUMMARY CARDS
            Padding(
              padding: const EdgeInsets.only(left: 16, right: 16, top: 16),
              child: ResponsiveSummaryGrid(
                spacing: 12,
                desktopBreakpoint: 980,
                tabletBreakpoint: 480,
                children: [
                  _buildSummaryCard(
                    'Total Invoices',
                    '${_summary['totalInvoices'] ?? _invoices.length}',
                    Icons.receipt_long,
                    navy,
                  ),
                  _buildSummaryCard(
                    'Total Billed',
                    _currency(_summary['totalBilled']),
                    Icons.payments,
                    purple,
                  ),
                  _buildSummaryCard(
                    'Collected Amount',
                    _currency(_summary['totalCollected']),
                    Icons.check_circle_outline,
                    primaryGreen,
                  ),
                  _buildSummaryCard(
                    'Outstanding Balance',
                    _currency(_summary['totalOutstanding']),
                    Icons.hourglass_top,
                    warningOrange,
                  ),
                ],
              ),
            ),

            // ACTION BAR
            Container(
              margin: const EdgeInsets.fromLTRB(16, 14, 16, 14),
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: const Color(0xFFE2E6F0)),
              ),
              child: Builder(
                builder: (context) {
                  final compact = MediaQuery.sizeOf(context).width < 1080;
                  final searchField = SizedBox(
                    height: 42,
                    child: TextField(
                      textAlignVertical: TextAlignVertical.center,
                      inputFormatters: const [NoLeadingSpaceFormatter()],
                      onChanged: (val) {
                        _searchQuery = val;
                        _loadBillingData();
                      },
                      decoration: InputDecoration(
                        hintText:
                            'Search by Invoice #, Customer name or phone...',
                        hintStyle: const TextStyle(
                          fontSize: 13,
                          color: Color(0xFF94A3B8),
                        ),
                        prefixIcon: const Icon(
                          Icons.search_rounded,
                          size: 19,
                          color: Color(0xFF64748B),
                        ),
                        filled: true,
                        fillColor: const Color(0xFFF8FAFC),
                        isDense: true,
                        contentPadding: const EdgeInsets.symmetric(
                          vertical: 11,
                          horizontal: 12,
                        ),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(10),
                          borderSide: const BorderSide(
                            color: Color(0xFFE2E6F0),
                          ),
                        ),
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(10),
                          borderSide: const BorderSide(
                            color: Color(0xFFE2E6F0),
                          ),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(10),
                          borderSide: const BorderSide(
                            color: Color(0xFF1E40AF),
                            width: 1.5,
                          ),
                        ),
                      ),
                    ),
                  );

                  final newInvoiceButton = SizedBox(
                    height: 42,
                    child: ElevatedButton.icon(
                      onPressed: _showCreateInvoiceDialog,
                      icon: const Icon(Icons.add_rounded, size: 18),
                      label: const Text('New Invoice'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: primaryGreen,
                        foregroundColor: Colors.white,
                        elevation: 0,
                        padding: const EdgeInsets.symmetric(horizontal: 18),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10),
                        ),
                        textStyle: const TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  );

                  final refreshButton = Tooltip(
                    message: 'Refresh',
                    child: SizedBox(
                      width: 42,
                      height: 42,
                      child: Material(
                        color: const Color(0xFFF8FAFC),
                        borderRadius: BorderRadius.circular(10),
                        child: InkWell(
                          borderRadius: BorderRadius.circular(10),
                          onTap: _loadBillingData,
                          child: Container(
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(10),
                              border: Border.all(
                                color: const Color(0xFFE2E6F0),
                              ),
                            ),
                            child: const Icon(
                              Icons.refresh_rounded,
                              size: 20,
                              color: navy,
                            ),
                          ),
                        ),
                      ),
                    ),
                  );

                  if (compact) {
                    return Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        searchField,
                        const SizedBox(height: 10),
                        Wrap(
                          spacing: 10,
                          runSpacing: 10,
                          crossAxisAlignment: WrapCrossAlignment.center,
                          children: [
                            _buildStatusFilterTabs(),
                            newInvoiceButton,
                            refreshButton,
                          ],
                        ),
                      ],
                    );
                  }

                  return Row(
                    children: [
                      Expanded(child: searchField),
                      const SizedBox(width: 12),
                      _buildStatusFilterTabs(),
                      const SizedBox(width: 12),
                      newInvoiceButton,
                      const SizedBox(width: 10),
                      refreshButton,
                    ],
                  );
                },
              ),
            ),

            // INVOICES TABLE (100% FULL WIDTH - NO HORIZONTAL SCROLL CUTOFF, NO BOTTOM VOID)
            if (_isLoading)
              Container(
                height: 240,
                alignment: Alignment.center,
                child: const CircularProgressIndicator(),
              )
            else if (_errorMessage != null)
              Container(
                margin: const EdgeInsets.symmetric(horizontal: 16),
                padding: const EdgeInsets.all(24),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: const Color(0xFFE2E6F0)),
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(
                      Icons.error_outline,
                      size: 40,
                      color: Colors.red,
                    ),
                    const SizedBox(height: 8),
                    Text(_errorMessage!),
                    const SizedBox(height: 12),
                    ElevatedButton(
                      onPressed: _loadBillingData,
                      child: const Text('Try Again'),
                    ),
                  ],
                ),
              )
            else if (_invoices.isEmpty)
              Container(
                margin: const EdgeInsets.symmetric(horizontal: 16),
                padding: const EdgeInsets.all(36),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: const Color(0xFFE2E6F0)),
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(
                      Icons.receipt_outlined,
                      size: 48,
                      color: Colors.grey,
                    ),
                    const SizedBox(height: 8),
                    const Text(
                      'No invoices found',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: Colors.black54,
                      ),
                    ),
                    const SizedBox(height: 12),
                    ElevatedButton(
                      onPressed: _showCreateInvoiceDialog,
                      child: const Text('Create First Invoice'),
                    ),
                  ],
                ),
              )
            else
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Container(
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: const Color(0xFFE2E6F0)),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.02),
                        blurRadius: 10,
                        offset: const Offset(0, 3),
                      ),
                    ],
                  ),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(12),
                    child: Builder(
                      builder: (context) {
                        final isNarrow =
                            MediaQuery.sizeOf(context).width < 1140;
                        final tableContent = Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            // TABLE HEADER
                            Container(
                              color: const Color(0xFFF8FAFC),
                              padding: const EdgeInsets.symmetric(
                                horizontal: 20,
                                vertical: 14,
                              ),
                              child: const Row(
                                children: [
                                  Expanded(
                                    flex: 3,
                                    child: Text(
                                      'Invoice No',
                                      style: TextStyle(
                                        fontWeight: FontWeight.bold,
                                        color: Color(0xFF1E293B),
                                        fontSize: 13,
                                      ),
                                    ),
                                  ),
                                  Expanded(
                                    flex: 2,
                                    child: Text(
                                      'Customer',
                                      style: TextStyle(
                                        fontWeight: FontWeight.bold,
                                        color: Color(0xFF1E293B),
                                        fontSize: 13,
                                      ),
                                    ),
                                  ),
                                  Expanded(
                                    flex: 2,
                                    child: Text(
                                      'Date',
                                      style: TextStyle(
                                        fontWeight: FontWeight.bold,
                                        color: Color(0xFF1E293B),
                                        fontSize: 13,
                                      ),
                                    ),
                                  ),
                                  Expanded(
                                    flex: 2,
                                    child: Text(
                                      'Total (₹)',
                                      style: TextStyle(
                                        fontWeight: FontWeight.bold,
                                        color: Color(0xFF1E293B),
                                        fontSize: 13,
                                      ),
                                    ),
                                  ),
                                  Expanded(
                                    flex: 2,
                                    child: Text(
                                      'Paid (₹)',
                                      style: TextStyle(
                                        fontWeight: FontWeight.bold,
                                        color: Color(0xFF1E293B),
                                        fontSize: 13,
                                      ),
                                    ),
                                  ),
                                  Expanded(
                                    flex: 2,
                                    child: Text(
                                      'Balance (₹)',
                                      style: TextStyle(
                                        fontWeight: FontWeight.bold,
                                        color: Color(0xFF1E293B),
                                        fontSize: 13,
                                      ),
                                    ),
                                  ),
                                  Expanded(
                                    flex: 2,
                                    child: Text(
                                      'Method',
                                      style: TextStyle(
                                        fontWeight: FontWeight.bold,
                                        color: Color(0xFF1E293B),
                                        fontSize: 13,
                                      ),
                                    ),
                                  ),
                                  Expanded(
                                    flex: 2,
                                    child: Text(
                                      'Status',
                                      style: TextStyle(
                                        fontWeight: FontWeight.bold,
                                        color: Color(0xFF1E293B),
                                        fontSize: 13,
                                      ),
                                    ),
                                  ),
                                  SizedBox(
                                    width: 86,
                                    child: Text(
                                      'Action',
                                      textAlign: TextAlign.center,
                                      style: TextStyle(
                                        fontWeight: FontWeight.bold,
                                        color: Color(0xFF1E293B),
                                        fontSize: 13,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            const Divider(
                              height: 1,
                              thickness: 1,
                              color: Color(0xFFE5E7EB),
                            ),

                            // DATA ROWS
                            ...List.generate(_invoices.length, (idx) {
                              final inv = _invoices[idx];
                              final status = (inv['payment_status'] ?? 'Paid')
                                  .toString();
                              final isPaid = status == 'Paid';
                              final isPartial = status == 'Partial';
                              final bal =
                                  double.tryParse(
                                    inv['balance_amount']?.toString() ?? '0',
                                  ) ??
                                  0;

                              return Container(
                                decoration: BoxDecoration(
                                  color: Colors.white,
                                  border: Border(
                                    bottom: BorderSide(
                                      color: idx == _invoices.length - 1
                                          ? Colors.transparent
                                          : const Color(0xFFF1F5F9),
                                    ),
                                  ),
                                ),
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 20,
                                  vertical: 14,
                                ),
                                child: Row(
                                  children: [
                                    // 1. Invoice No
                                    Expanded(
                                      flex: 3,
                                      child: Row(
                                        children: [
                                          Container(
                                            padding: const EdgeInsets.all(6),
                                            decoration: BoxDecoration(
                                              color: const Color(0xFFEFF6FF),
                                              borderRadius:
                                                  BorderRadius.circular(6),
                                            ),
                                            child: const Icon(
                                              Icons.receipt_outlined,
                                              size: 14,
                                              color: Color(0xFF1E40AF),
                                            ),
                                          ),
                                          const SizedBox(width: 8),
                                          Flexible(
                                            child: Text(
                                              inv['invoice_no'] ?? '-',
                                              style: const TextStyle(
                                                fontWeight: FontWeight.bold,
                                                color: Color(0xFF0F172A),
                                                fontSize: 13,
                                              ),
                                              overflow: TextOverflow.ellipsis,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),

                                    // 2. Customer
                                    Expanded(
                                      flex: 2,
                                      child: Text(
                                        inv['customer_name'] ?? 'Walk-in',
                                        style: const TextStyle(
                                          color: Color(0xFF334155),
                                          fontSize: 13,
                                        ),
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                    ),

                                    // 3. Date
                                    Expanded(
                                      flex: 2,
                                      child: Text(
                                        inv['sale_date']
                                                ?.toString()
                                                .split('T')
                                                .first ??
                                            '-',
                                        style: const TextStyle(
                                          color: Color(0xFF64748B),
                                          fontSize: 12.5,
                                        ),
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                    ),

                                    // 4. Total
                                    Expanded(
                                      flex: 2,
                                      child: Text(
                                        _currency(inv['total_amount']),
                                        style: const TextStyle(
                                          fontWeight: FontWeight.bold,
                                          color: Color(0xFF0F172A),
                                          fontSize: 13,
                                        ),
                                      ),
                                    ),

                                    // 5. Paid
                                    Expanded(
                                      flex: 2,
                                      child: Text(
                                        _currency(inv['paid_amount']),
                                        style: const TextStyle(
                                          fontWeight: FontWeight.w600,
                                          color: primaryGreen,
                                          fontSize: 13,
                                        ),
                                      ),
                                    ),

                                    // 6. Balance
                                    Expanded(
                                      flex: 2,
                                      child: Text(
                                        _currency(inv['balance_amount']),
                                        style: TextStyle(
                                          fontWeight: bal > 0
                                              ? FontWeight.bold
                                              : FontWeight.normal,
                                          color: bal > 0
                                              ? const Color(0xFFDC2626)
                                              : const Color(0xFF94A3B8),
                                          fontSize: 13,
                                        ),
                                      ),
                                    ),

                                    // 7. Method
                                    Expanded(
                                      flex: 2,
                                      child: Text(
                                        inv['payment_method'] ?? 'Cash',
                                        style: const TextStyle(
                                          color: Color(0xFF334155),
                                          fontSize: 12.5,
                                        ),
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                    ),

                                    // 8. Status
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
                                            color: isPaid
                                                ? const Color(0xFFECFDF5)
                                                : isPartial
                                                ? const Color(0xFFFFFBEB)
                                                : const Color(0xFFFEF2F2),
                                            borderRadius: BorderRadius.circular(
                                              6,
                                            ),
                                            border: Border.all(
                                              color: isPaid
                                                  ? const Color(0xFFA7F3D0)
                                                  : isPartial
                                                  ? const Color(0xFFFDE68A)
                                                  : const Color(0xFFFECACA),
                                            ),
                                          ),
                                          child: Text(
                                            status,
                                            style: TextStyle(
                                              fontSize: 11.5,
                                              fontWeight: FontWeight.w700,
                                              color: isPaid
                                                  ? const Color(0xFF047857)
                                                  : isPartial
                                                  ? const Color(0xFFB45309)
                                                  : const Color(0xFFDC2626),
                                            ),
                                          ),
                                        ),
                                      ),
                                    ),

                                    // 9. Action (ALWAYS 100% VISIBLE)
                                    SizedBox(
                                      width: 86,
                                      child: Center(
                                        child: Material(
                                          color: const Color(0xFFEFF6FF),
                                          borderRadius: BorderRadius.circular(
                                            7,
                                          ),
                                          child: InkWell(
                                            onTap: () =>
                                                _showInvoiceDetails(inv),
                                            borderRadius: BorderRadius.circular(
                                              7,
                                            ),
                                            child: Container(
                                              padding:
                                                  const EdgeInsets.symmetric(
                                                    horizontal: 10,
                                                    vertical: 6,
                                                  ),
                                              decoration: BoxDecoration(
                                                borderRadius:
                                                    BorderRadius.circular(7),
                                                border: Border.all(
                                                  color: const Color(
                                                    0xFFDBEAFE,
                                                  ),
                                                ),
                                              ),
                                              child: const Row(
                                                mainAxisSize: MainAxisSize.min,
                                                children: [
                                                  Icon(
                                                    Icons.visibility_outlined,
                                                    size: 14,
                                                    color: Color(0xFF1E40AF),
                                                  ),
                                                  SizedBox(width: 5),
                                                  Text(
                                                    'View',
                                                    style: TextStyle(
                                                      color: Color(0xFF1E40AF),
                                                      fontSize: 12,
                                                      fontWeight:
                                                          FontWeight.w600,
                                                    ),
                                                  ),
                                                ],
                                              ),
                                            ),
                                          ),
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              );
                            }),

                            // TABLE FOOTER
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 20,
                                vertical: 12,
                              ),
                              decoration: const BoxDecoration(
                                color: Color(0xFFF8FAFC),
                                border: Border(
                                  top: BorderSide(color: Color(0xFFE5E7EB)),
                                ),
                              ),
                              child: Row(
                                mainAxisAlignment:
                                    MainAxisAlignment.spaceBetween,
                                children: [
                                  Text(
                                    'Showing ${_invoices.length} invoices',
                                    style: const TextStyle(
                                      fontSize: 12,
                                      color: Color(0xFF64748B),
                                    ),
                                  ),
                                  Text(
                                    'Total Billed: ${_currency(_summary['totalBilled'])}',
                                    style: const TextStyle(
                                      fontSize: 13,
                                      fontWeight: FontWeight.bold,
                                      color: Color(0xFF0F172A),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        );

                        if (isNarrow) {
                          return SingleChildScrollView(
                            scrollDirection: Axis.horizontal,
                            child: SizedBox(width: 920, child: tableContent),
                          );
                        }
                        return tableContent;
                      },
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
