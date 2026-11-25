import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'api_service.dart';
import 'slip_downloader.dart';
import 'app_input_formatters.dart';

enum ReportView { sales, purchase, stock, collections, profit }

class ReportsPage extends StatefulWidget {
  final String token;
  final String? apiBaseUrl;

  const ReportsPage({super.key, required this.token, this.apiBaseUrl});

  @override
  State<ReportsPage> createState() => _ReportsPageState();
}

class _ReportsPageState extends State<ReportsPage> {
  late final ApiService _api;

  bool _isLoading = true;
  String? _errorMessage;

  // Raw data from backend
  List<dynamic> _allInvoices = [];
  List<dynamic> _filteredInvoices = [];
  List<dynamic> _purchases = [];
  List<dynamic> _products = [];

  // Active View State (Controlled by clicking the 5 cards)
  ReportView _activeView = ReportView.sales;

  // Module-specific search
  String _reportSearch = '';
  final TextEditingController _reportSearchCtrl = TextEditingController();

  // Pagination state
  int _currentPage = 1;
  int _rowsPerPage = 10;

  static const Color navy = Color(0xFF151B3B);
  static const Color primaryBlue = Color(0xFF1E40AF);
  static const Color cardBorder = Color(0xFFE2E8F0);
  static const Color primaryGreen = Color(0xFF16A34A);

  @override
  void initState() {
    super.initState();
    _api = ApiService(token: widget.token, customBaseUrl: widget.apiBaseUrl);
    _loadData();
  }

  @override
  void dispose() {
    _reportSearchCtrl.dispose();
    super.dispose();
  }

  Future<void> _loadData() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final results = await Future.wait([
        _api.get('/billing/invoices').catchError((_) => {'data': []}),
        _api.get('/purchases').catchError((_) => {'data': []}),
        _api.get('/products').catchError((_) => {'data': []}),
      ]);

      if (!mounted) return;

      setState(() {
        _allInvoices = results[0]['data'] is List
            ? List.from(results[0]['data'])
            : [];
        _purchases = results[1]['data'] is List
            ? List.from(results[1]['data'])
            : [];
        _products = results[2]['data'] is List
            ? List.from(results[2]['data'])
            : [];
        _filteredInvoices = List.from(_allInvoices);
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

  double _numVal(dynamic v) =>
      v is num ? v.toDouble() : double.tryParse('${v ?? 0}') ?? 0.0;

  String _currency(dynamic amount) {
    final val = _numVal(amount);
    return '₹ ${val.toStringAsFixed(2)}';
  }

  double _invoiceProfit(dynamic inv) {
    final net = _numVal(inv['total_amount']);
    final cost = _numVal(inv['total_cost']);
    if (cost > 0 && net >= cost) {
      return (net - cost);
    }
    // Standard retail margin when individual product cost isn't set (22%)
    return (net * 0.22);
  }

  // --- Computed Metrics (Dynamic with Filtered Invoices) ---
  double get _totalSales {
    return _filteredInvoices.fold<double>(
      0.0,
      (sum, inv) => sum + _numVal(inv['total_amount']),
    );
  }

  double get _totalPurchases {
    return _purchases.fold<double>(
      0.0,
      (sum, p) => sum + _numVal(p['total_amount']),
    );
  }

  double get _stockValue {
    double sum = 0.0;
    for (final p in _products) {
      final qty = _numVal(p['stock_qty']);
      final price = _numVal(p['cost_price'] ?? p['selling_price'] ?? 0);
      sum += (qty * price);
    }
    return sum;
  }

  double get _cashCollection {
    return _filteredInvoices.fold<double>(
      0.0,
      (sum, inv) => sum + _numVal(inv['paid_amount']),
    );
  }

  double get _totalProfit {
    return _filteredInvoices.fold<double>(
      0.0,
      (sum, inv) => sum + _invoiceProfit(inv),
    );
  }

  // --- Active View Filtered Lists & Labels ---
  List<dynamic> get _filteredPurchases => _purchases;

  List<dynamic> get _filteredProducts => _products;

  List<dynamic> get _currentActiveList {
    final query = _reportSearch.trim().toLowerCase();
    List<dynamic> baseList;
    switch (_activeView) {
      case ReportView.sales:
      case ReportView.collections:
      case ReportView.profit:
        baseList = _filteredInvoices;
        break;
      case ReportView.purchase:
        baseList = _filteredPurchases;
        break;
      case ReportView.stock:
        baseList = _filteredProducts;
        break;
    }

    if (query.isEmpty) return baseList;

    switch (_activeView) {
      case ReportView.sales:
        return baseList.where((inv) {
          final no = (inv['invoice_no'] ?? '').toString().toLowerCase();
          final cust = (inv['customer_name'] ?? '').toString().toLowerCase();
          final mode = (inv['payment_method'] ?? '').toString().toLowerCase();
          return no.contains(query) ||
              cust.contains(query) ||
              mode.contains(query);
        }).toList();

      case ReportView.purchase:
        return baseList.where((p) {
          final no = (p['purchase_no'] ?? '').toString().toLowerCase();
          final supp = (p['supplier_name'] ?? '').toString().toLowerCase();
          final notes = (p['notes'] ?? '').toString().toLowerCase();
          return no.contains(query) ||
              supp.contains(query) ||
              notes.contains(query);
        }).toList();

      case ReportView.stock:
        return baseList.where((prod) {
          final name = (prod['product_name'] ?? '').toString().toLowerCase();
          final sku = (prod['sku'] ?? prod['barcode'] ?? '')
              .toString()
              .toLowerCase();
          final cat = (prod['category_name'] ?? '').toString().toLowerCase();
          return name.contains(query) ||
              sku.contains(query) ||
              cat.contains(query);
        }).toList();

      case ReportView.collections:
        return baseList.where((inv) {
          final no = (inv['invoice_no'] ?? '').toString().toLowerCase();
          final cust = (inv['customer_name'] ?? '').toString().toLowerCase();
          final mode = (inv['payment_method'] ?? '').toString().toLowerCase();
          return no.contains(query) ||
              cust.contains(query) ||
              mode.contains(query);
        }).toList();

      case ReportView.profit:
        return baseList.where((inv) {
          final no = (inv['invoice_no'] ?? '').toString().toLowerCase();
          final cust = (inv['customer_name'] ?? '').toString().toLowerCase();
          return no.contains(query) || cust.contains(query);
        }).toList();
    }
  }

  String get _viewTitle {
    switch (_activeView) {
      case ReportView.sales:
        return 'Sales Register';
      case ReportView.purchase:
        return 'Purchase Orders Register';
      case ReportView.stock:
        return 'Inventory Stock Valuation';
      case ReportView.collections:
        return 'Payment Collections Register';
      case ReportView.profit:
        return 'Net Profit & Margins Analysis';
    }
  }

  // --- Dynamic Export & Print Handlers ---
  Future<void> _exportCurrentReport() async {
    final buffer = StringBuffer();
    String fileName = '';

    switch (_activeView) {
      case ReportView.sales:
        fileName =
            'Sales_Register_${DateTime.now().toIso8601String().substring(0, 10)}.csv';
        buffer.writeln(
          'Date,Invoice No,Customer,Items,Payment Mode,Gross Amount,Discount,Net Amount,Profit,Status',
        );
        for (final inv in _filteredInvoices) {
          final date = inv['sale_date']?.toString().split('T').first ?? '-';
          final invNo = inv['invoice_no']?.toString() ?? '-';
          final customer =
              (inv['customer_name']?.toString() ?? 'Walk-in Customer')
                  .replaceAll(',', ' ');
          final itemsCount = _numVal(inv['items_count']) > 0
              ? _numVal(inv['items_count']).toInt()
              : 1;
          final mode = inv['payment_method']?.toString() ?? 'Cash';
          final gross = _numVal(inv['subtotal'] ?? inv['total_amount']);
          final disc = _numVal(inv['discount']);
          final net = _numVal(inv['total_amount']);
          final profit = _invoiceProfit(inv);
          final status = inv['payment_status']?.toString() ?? 'Paid';
          buffer.writeln(
            '$date,$invNo,"$customer",$itemsCount,$mode,$gross,$disc,$net,$profit,$status',
          );
        }
        break;

      case ReportView.purchase:
        fileName =
            'Purchase_Orders_${DateTime.now().toIso8601String().substring(0, 10)}.csv';
        buffer.writeln(
          'Date,Purchase No,Supplier,Subtotal,Tax Amount,Total Amount,Status,Notes',
        );
        for (final p in _filteredPurchases) {
          final date = p['purchase_date']?.toString().split('T').first ?? '-';
          final pNo = p['purchase_no']?.toString() ?? '-';
          final supplier =
              (p['supplier_name']?.toString() ?? 'General Supplier').replaceAll(
                ',',
                ' ',
              );
          final subtotal = _numVal(p['subtotal']);
          final tax = _numVal(p['tax_amount']);
          final total = _numVal(p['total_amount']);
          final status = 'Received';
          final notes = (p['notes']?.toString() ?? '').replaceAll(',', ' ');
          buffer.writeln(
            '$date,$pNo,"$supplier",$subtotal,$tax,$total,$status,"$notes"',
          );
        }
        break;

      case ReportView.stock:
        fileName =
            'Stock_Valuation_${DateTime.now().toIso8601String().substring(0, 10)}.csv';
        buffer.writeln(
          'Product Name,SKU,Category,Stock Qty,Unit,Cost Price,Selling Price,Total Valuation,Status',
        );
        for (final prod in _filteredProducts) {
          final name = (prod['product_name']?.toString() ?? '-').replaceAll(
            ',',
            ' ',
          );
          final sku = prod['sku']?.toString() ?? '-';
          final cat = (prod['category_name']?.toString() ?? '-').replaceAll(
            ',',
            ' ',
          );
          final qty = _numVal(prod['stock_qty']);
          final unit = prod['unit']?.toString() ?? '';
          final cost = _numVal(prod['cost_price'] ?? 0);
          final sell = _numVal(prod['selling_price'] ?? 0);
          final val = qty * (cost > 0 ? cost : sell);
          final status = qty <= _numVal(prod['reorder_level'])
              ? 'Low Stock'
              : 'In Stock';
          buffer.writeln(
            '"$name",$sku,"$cat",$qty,$unit,$cost,$sell,$val,$status',
          );
        }
        break;

      case ReportView.collections:
        fileName =
            'Collections_Report_${DateTime.now().toIso8601String().substring(0, 10)}.csv';
        buffer.writeln(
          'Date,Invoice No,Customer,Payment Mode,Total Billed,Collected Amount,Balance Due,Status',
        );
        for (final inv in _filteredInvoices) {
          final date = inv['sale_date']?.toString().split('T').first ?? '-';
          final invNo = inv['invoice_no']?.toString() ?? '-';
          final customer =
              (inv['customer_name']?.toString() ?? 'Walk-in Customer')
                  .replaceAll(',', ' ');
          final mode = inv['payment_method']?.toString() ?? 'Cash';
          final billed = _numVal(inv['total_amount']);
          final collected = _numVal(inv['paid_amount']);
          final balance = (billed - collected).clamp(0.0, double.infinity);
          final status = inv['payment_status']?.toString() ?? 'Paid';
          buffer.writeln(
            '$date,$invNo,"$customer",$mode,$billed,$collected,$balance,$status',
          );
        }
        break;

      case ReportView.profit:
        fileName =
            'Profit_Analysis_${DateTime.now().toIso8601String().substring(0, 10)}.csv';
        buffer.writeln(
          'Date,Invoice No,Customer,Revenue,Estimated Cost,Net Profit,Margin %',
        );
        for (final inv in _filteredInvoices) {
          final date = inv['sale_date']?.toString().split('T').first ?? '-';
          final invNo = inv['invoice_no']?.toString() ?? '-';
          final customer =
              (inv['customer_name']?.toString() ?? 'Walk-in Customer')
                  .replaceAll(',', ' ');
          final rev = _numVal(inv['total_amount']);
          final profit = _invoiceProfit(inv);
          final cost = (rev - profit).clamp(0.0, double.infinity);
          final marginPct = rev > 0
              ? ((profit / rev) * 100).toStringAsFixed(1)
              : '0';
          buffer.writeln(
            '$date,$invNo,"$customer",$rev,$cost,$profit,$marginPct%',
          );
        }
        break;
    }

    final ok = await downloadReceiptSlip(
      fileName: fileName,
      htmlContent: buffer.toString(),
    );
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          ok
              ? '$_viewTitle exported successfully!'
              : 'Export is supported in browser mode.',
        ),
        backgroundColor: ok ? primaryGreen : Colors.orange,
      ),
    );
  }

  Future<void> _printCurrentReport() async {
    final buffer = StringBuffer();
    final nowStr = DateTime.now().toString().split('.').first;

    buffer.writeln('''<!DOCTYPE html>
<html>
<head>
  <meta charset="utf-8">
  <title>$_viewTitle</title>
  <style>
    body { font-family: -apple-system, BlinkMacSystemFont, "Segoe UI", Roboto, sans-serif; padding: 24px; color: #1e293b; }
    h2 { margin: 0 0 4px 0; color: #0f172a; }
    .subtitle { font-size: 13px; color: #64748b; margin-bottom: 20px; }
    .summary-grid { display: flex; margin-bottom: 20px; }
    .selected-card {
      border: 2px solid #1e40af;
      border-radius: 8px;
      padding: 12px 18px;
      background: #eff6ff;
      display: inline-block;
      min-width: 260px;
    }
    .card-title { font-size: 11px; color: #1e40af; text-transform: uppercase; font-weight: 700; letter-spacing: 0.5px; }
    .card-value { font-size: 20px; font-weight: bold; color: #0f172a; margin-top: 4px; }
    .card-sub { font-size: 11.5px; color: #64748b; margin-top: 3px; }
    table { width: 100%; border-collapse: collapse; font-size: 12px; margin-top: 10px; }
    th { background: #f1f5f9; padding: 8px 10px; text-align: left; border-bottom: 2px solid #cbd5e1; color: #475569; }
    td { padding: 8px 10px; border-bottom: 1px solid #e2e8f0; }
    .right { text-align: right; }
    .profit { color: #16a34a; font-weight: bold; }
    @media print { button { display: none; } }
  </style>
</head>
<body>
  <h2>ColorCraft Paint Shop - $_viewTitle</h2>
  <div class="subtitle">Generated on $nowStr | Report View: $_viewTitle</div>
''');

    String selectedMetricBoxHtml;
    switch (_activeView) {
      case ReportView.sales:
        selectedMetricBoxHtml =
            '''
    <div class="selected-card">
      <div class="card-title">Total Sales (Selected Register)</div>
      <div class="card-value">${_currency(_totalSales)}</div>
      <div class="card-sub">${_filteredInvoices.length} Invoices Recorded</div>
    </div>
''';
        break;
      case ReportView.purchase:
        selectedMetricBoxHtml =
            '''
    <div class="selected-card">
      <div class="card-title">Total Purchase (Selected Register)</div>
      <div class="card-value">${_currency(_totalPurchases)}</div>
      <div class="card-sub">${_filteredPurchases.length} Purchase Orders</div>
    </div>
''';
        break;
      case ReportView.stock:
        selectedMetricBoxHtml =
            '''
    <div class="selected-card">
      <div class="card-title">Total Stock Valuation (Selected Register)</div>
      <div class="card-value">${_currency(_stockValue)}</div>
      <div class="card-sub">${_filteredProducts.length} Inventory Items in Stock</div>
    </div>
''';
        break;
      case ReportView.collections:
        selectedMetricBoxHtml =
            '''
    <div class="selected-card">
      <div class="card-title">Cash Collection (Selected Register)</div>
      <div class="card-value">${_currency(_cashCollection)}</div>
      <div class="card-sub">Collected against Billed Sales</div>
    </div>
''';
        break;
      case ReportView.profit:
        selectedMetricBoxHtml =
            '''
    <div class="selected-card">
      <div class="card-title">Total Net Profit (Selected Register)</div>
      <div class="card-value">${_currency(_totalProfit)}</div>
      <div class="card-sub">Estimated Net Margin</div>
    </div>
''';
        break;
    }

    buffer.writeln('''
  <div class="summary-grid">
    $selectedMetricBoxHtml
  </div>
''');

    switch (_activeView) {
      case ReportView.sales:
        buffer.writeln(
          '<table><thead><tr><th>#</th><th>Date</th><th>Invoice No</th><th>Customer</th><th>Items</th><th>Mode</th><th class="right">Gross</th><th class="right">Discount</th><th class="right">Net Amount</th><th class="right">Profit</th></tr></thead><tbody>',
        );
        for (int i = 0; i < _filteredInvoices.length; i++) {
          final inv = _filteredInvoices[i];
          final date = inv['sale_date']?.toString().split('T').first ?? '-';
          final invNo = inv['invoice_no']?.toString() ?? '-';
          final customer =
              inv['customer_name']?.toString() ?? 'Walk-in Customer';
          final items = _numVal(inv['items_count']) > 0
              ? _numVal(inv['items_count']).toInt()
              : 1;
          final mode = inv['payment_method']?.toString() ?? 'Cash';
          final gross = _currency(
            _numVal(inv['subtotal'] ?? inv['total_amount']),
          );
          final disc = _currency(_numVal(inv['discount']));
          final net = _currency(_numVal(inv['total_amount']));
          final profit = _currency(_invoiceProfit(inv));
          buffer.writeln(
            '<tr><td>${i + 1}</td><td>$date</td><td>$invNo</td><td>$customer</td><td>$items</td><td>$mode</td><td class="right">$gross</td><td class="right">$disc</td><td class="right"><b>$net</b></td><td class="right profit">$profit</td></tr>',
          );
        }
        buffer.writeln('</tbody></table>');
        break;

      case ReportView.purchase:
        buffer.writeln(
          '<table><thead><tr><th>#</th><th>Date</th><th>Purchase No</th><th>Supplier</th><th class="right">Subtotal</th><th class="right">Tax</th><th class="right">Total Cost</th><th>Status</th><th>Notes</th></tr></thead><tbody>',
        );
        for (int i = 0; i < _filteredPurchases.length; i++) {
          final p = _filteredPurchases[i];
          final date = p['purchase_date']?.toString().split('T').first ?? '-';
          final pNo = p['purchase_no']?.toString() ?? '-';
          final supplier = p['supplier_name']?.toString() ?? 'General Supplier';
          final sub = _currency(p['subtotal']);
          final tax = _currency(p['tax_amount']);
          final tot = _currency(p['total_amount']);
          final notes = p['notes']?.toString() ?? '-';
          buffer.writeln(
            '<tr><td>${i + 1}</td><td>$date</td><td>$pNo</td><td>$supplier</td><td class="right">$sub</td><td class="right">$tax</td><td class="right"><b>$tot</b></td><td>Received</td><td>$notes</td></tr>',
          );
        }
        buffer.writeln('</tbody></table>');
        break;

      case ReportView.stock:
        buffer.writeln(
          '<table><thead><tr><th>#</th><th>Product Name</th><th>SKU</th><th>Category</th><th>Stock</th><th class="right">Cost</th><th class="right">Selling Price</th><th class="right">Valuation</th><th>Status</th></tr></thead><tbody>',
        );
        for (int i = 0; i < _filteredProducts.length; i++) {
          final prod = _filteredProducts[i];
          final name = prod['product_name']?.toString() ?? '-';
          final sku = prod['sku']?.toString() ?? '-';
          final cat = prod['category_name']?.toString() ?? '-';
          final qty = _numVal(prod['stock_qty']);
          final unit = prod['unit']?.toString() ?? '';
          final cost = _currency(prod['cost_price'] ?? 0);
          final sell = _currency(prod['selling_price'] ?? 0);
          final val = _currency(
            qty * _numVal(prod['cost_price'] ?? prod['selling_price'] ?? 0),
          );
          final status = qty <= _numVal(prod['reorder_level'])
              ? 'Low Stock'
              : 'In Stock';
          buffer.writeln(
            '<tr><td>${i + 1}</td><td>$name</td><td>$sku</td><td>$cat</td><td>$qty $unit</td><td class="right">$cost</td><td class="right">$sell</td><td class="right"><b>$val</b></td><td>$status</td></tr>',
          );
        }
        buffer.writeln('</tbody></table>');
        break;

      case ReportView.collections:
        buffer.writeln(
          '<table><thead><tr><th>#</th><th>Date</th><th>Invoice No</th><th>Customer</th><th>Mode</th><th class="right">Total Billed</th><th class="right">Collected</th><th class="right">Balance Due</th><th>Status</th></tr></thead><tbody>',
        );
        for (int i = 0; i < _filteredInvoices.length; i++) {
          final inv = _filteredInvoices[i];
          final date = inv['sale_date']?.toString().split('T').first ?? '-';
          final invNo = inv['invoice_no']?.toString() ?? '-';
          final customer =
              inv['customer_name']?.toString() ?? 'Walk-in Customer';
          final mode = inv['payment_method']?.toString() ?? 'Cash';
          final billed = _currency(_numVal(inv['total_amount']));
          final coll = _currency(_numVal(inv['paid_amount']));
          final bal = _currency(
            (_numVal(inv['total_amount']) - _numVal(inv['paid_amount'])).clamp(
              0.0,
              double.infinity,
            ),
          );
          final status = inv['payment_status']?.toString() ?? 'Paid';
          buffer.writeln(
            '<tr><td>${i + 1}</td><td>$date</td><td>$invNo</td><td>$customer</td><td>$mode</td><td class="right">$billed</td><td class="right profit">$coll</td><td class="right">$bal</td><td>$status</td></tr>',
          );
        }
        buffer.writeln('</tbody></table>');
        break;

      case ReportView.profit:
        buffer.writeln(
          '<table><thead><tr><th>#</th><th>Date</th><th>Invoice No</th><th>Customer</th><th class="right">Revenue</th><th class="right">Est. Cost</th><th class="right">Net Profit</th><th class="right">Margin %</th></tr></thead><tbody>',
        );
        for (int i = 0; i < _filteredInvoices.length; i++) {
          final inv = _filteredInvoices[i];
          final date = inv['sale_date']?.toString().split('T').first ?? '-';
          final invNo = inv['invoice_no']?.toString() ?? '-';
          final customer =
              inv['customer_name']?.toString() ?? 'Walk-in Customer';
          final rev = _numVal(inv['total_amount']);
          final prof = _invoiceProfit(inv);
          final cost = (rev - prof).clamp(0.0, double.infinity);
          final pct = rev > 0 ? ((prof / rev) * 100).toStringAsFixed(1) : '0';
          buffer.writeln(
            '<tr><td>${i + 1}</td><td>$date</td><td>$invNo</td><td>$customer</td><td class="right">${_currency(rev)}</td><td class="right">${_currency(cost)}</td><td class="right profit">${_currency(prof)}</td><td class="right"><b>$pct%</b></td></tr>',
          );
        }
        buffer.writeln('</tbody></table>');
        break;
    }

    buffer.writeln('''
  <script>window.onload = function() { window.print(); }</script>
</body>
</html>''');

    final safeFileName =
        'Print_${_viewTitle.replaceAll(' ', '_')}_${DateTime.now().toIso8601String().substring(0, 10)}.html';
    await downloadReceiptSlip(
      fileName: safeFileName,
      htmlContent: buffer.toString(),
    );
  }

  // --- Clipboard Copy Helper ---
  Future<void> _copyToClipboard(String text, String label) async {
    if (text.isEmpty || text == '-') return;
    await Clipboard.setData(ClipboardData(text: text));
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            const Icon(
              Icons.check_circle_rounded,
              color: Colors.white,
              size: 18,
            ),
            const SizedBox(width: 8),
            Text('$label copied to clipboard!'),
          ],
        ),
        backgroundColor: const Color(0xFF16A34A),
        duration: const Duration(seconds: 2),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      ),
    );
  }

  // --- Customer Info Modal ---
  void _showCustomerInfoDialog(dynamic inv) {
    final name = inv['customer_name']?.toString() ?? 'Walk-in Customer';
    final phone = inv['customer_phone']?.toString() ?? 'Not Provided';
    final email = inv['customer_email']?.toString() ?? 'Not Provided';
    final address =
        inv['customer_address']?.toString() ??
        inv['address']?.toString() ??
        'Not Provided';

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: const Color(0xFFEFF6FF),
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Icon(
                Icons.person_outline_rounded,
                color: primaryBlue,
                size: 20,
              ),
            ),
            const SizedBox(width: 10),
            const Text(
              'Customer Details',
              style: TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 16,
                color: navy,
              ),
            ),
          ],
        ),
        content: SizedBox(
          width: 400,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _detailRow('Customer Name', name, isBold: true),
              const SizedBox(height: 10),
              _detailRow('Phone Number', phone),
              const SizedBox(height: 10),
              _detailRow('Email Address', email),
              const SizedBox(height: 10),
              _detailRow('Delivery / Shop Address', address),
            ],
          ),
        ),
        actions: [
          if (phone != 'Not Provided' && phone.isNotEmpty)
            TextButton.icon(
              icon: const Icon(Icons.copy_rounded, size: 15),
              label: const Text('Copy Phone'),
              onPressed: () {
                Navigator.pop(ctx);
                _copyToClipboard(phone, 'Customer Phone');
              },
            ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: primaryBlue,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
              ),
            ),
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }

  // --- Supplier Info Modal ---
  void _showSupplierInfoDialog(dynamic p) {
    final name = p['supplier_name']?.toString() ?? 'General Supplier';
    final phone =
        p['supplier_phone']?.toString() ??
        p['phone']?.toString() ??
        'Not Provided';
    final email = p['supplier_email']?.toString() ?? 'Not Provided';
    final notes = p['notes']?.toString() ?? 'Stock replenishments';

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: const Color(0xFFDCFCE7),
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Icon(
                Icons.local_shipping_outlined,
                color: primaryGreen,
                size: 20,
              ),
            ),
            const SizedBox(width: 10),
            const Text(
              'Supplier Details',
              style: TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 16,
                color: navy,
              ),
            ),
          ],
        ),
        content: SizedBox(
          width: 400,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _detailRow('Supplier / Vendor', name, isBold: true),
              const SizedBox(height: 10),
              _detailRow('Phone Number', phone),
              const SizedBox(height: 10),
              _detailRow('Email Address', email),
              const SizedBox(height: 10),
              _detailRow('Purchase Notes', notes),
            ],
          ),
        ),
        actions: [
          if (phone != 'Not Provided' && phone.isNotEmpty)
            TextButton.icon(
              icon: const Icon(Icons.copy_rounded, size: 15),
              label: const Text('Copy Phone'),
              onPressed: () {
                Navigator.pop(ctx);
                _copyToClipboard(phone, 'Supplier Phone');
              },
            ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: primaryGreen,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
              ),
            ),
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }

  // --- Print / Download Single Invoice (Thermal Slip or A4 Tax Invoice) ---
  Future<void> _printSingleInvoiceSlip(dynamic inv, {bool isA4 = false}) async {
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
    final bal = _numVal(inv['balance_amount'] ?? 0);

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
  }

  // --- Print / Download Single Purchase Voucher ---
  Future<void> _printSinglePurchaseVoucher(dynamic p) async {
    final pNo = p['purchase_no']?.toString() ?? 'PO-VOUCHER';
    final date = p['purchase_date']?.toString().split('T').first ?? '-';
    final supplier = p['supplier_name']?.toString() ?? 'General Supplier';
    final sub = _numVal(p['subtotal']);
    final tax = _numVal(p['tax_amount']);
    final total = _numVal(p['total_amount']);
    final notes = p['notes']?.toString() ?? 'Stock replenishments';

    final html = _buildPurchaseVoucherHtml(
      poNo: pNo,
      date: date,
      supplierName: supplier,
      subtotal: sub,
      taxAmount: tax,
      totalAmount: total,
      notes: notes,
    );

    final safeFileName =
        'Voucher_${pNo.replaceAll(RegExp(r'[^a-zA-Z0-9_-]'), '_')}.html';
    await downloadReceiptSlip(fileName: safeFileName, htmlContent: html);
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

  String _buildPurchaseVoucherHtml({
    required String poNo,
    required String date,
    required String supplierName,
    required double subtotal,
    required double taxAmount,
    required double totalAmount,
    required String notes,
  }) {
    String esc(String s) => s
        .replaceAll('&', '&amp;')
        .replaceAll('<', '&lt;')
        .replaceAll('>', '&gt;')
        .replaceAll('"', '&quot;')
        .replaceAll("'", '&#39;');

    return '''<!DOCTYPE html>
<html>
<head>
  <meta charset="utf-8">
  <title>Purchase Voucher - ${esc(poNo)}</title>
  <style>
    body { font-family: -apple-system, BlinkMacSystemFont, "Segoe UI", Roboto, sans-serif; padding: 32px; color: #0f172a; margin: 0; background: #fff; }
    .box { max-width: 700px; margin: auto; border: 1px solid #cbd5e1; padding: 24px; border-radius: 8px; }
    .header { border-bottom: 2px solid #16a34a; padding-bottom: 12px; margin-bottom: 16px; display: flex; justify-content: space-between; }
    .title { font-size: 20px; font-weight: bold; color: #16a34a; }
    .grid { display: flex; justify-content: space-between; margin-bottom: 16px; font-size: 13px; }
    .totals { width: 280px; margin-left: auto; font-size: 13px; border-collapse: collapse; }
    .totals td { padding: 5px 8px; }
    .grand { font-size: 15px; font-weight: bold; color: #16a34a; border-top: 1px solid #cbd5e1 !important; }
    @media print { body { padding: 0; } .box { border: none; padding: 0; } }
  </style>
</head>
<body>
  <div class="box">
    <div class="header">
      <div>
        <div style="font-size: 18px; font-weight: 800; color: #0f172a;">ColorCraft Paint Shop</div>
        <div style="font-size: 12px; color: #64748b;">Inventory Inward Management</div>
      </div>
      <div style="text-align: right;">
        <div class="title">PURCHASE VOUCHER</div>
        <div style="font-size: 12px; color: #15803d; font-weight: bold;">STOCK RECEIVED</div>
      </div>
    </div>

    <div class="grid">
      <div>
        <b>Supplier:</b> ${esc(supplierName)}<br>
        <b>Remarks:</b> ${esc(notes)}
      </div>
      <div style="text-align: right;">
        <b>PO No:</b> ${esc(poNo)}<br>
        <b>Date:</b> $date
      </div>
    </div>

    <table class="totals">
      <tr><td>Subtotal:</td><td style="text-align: right;">${_currency(subtotal)}</td></tr>
      <tr><td>Tax (GST):</td><td style="text-align: right;">${_currency(taxAmount)}</td></tr>
      <tr class="grand"><td>Total Inward Cost:</td><td style="text-align: right;">${_currency(totalAmount)}</td></tr>
    </table>

    <div style="margin-top: 40px; display: flex; justify-content: space-between; font-size: 11px; color: #64748b;">
      <div>Stock Verified & Entered in System</div>
      <div style="text-align: right;">Store Manager / Stock Inward Officer</div>
    </div>
  </div>
  <script>window.onload = function() { window.print(); };</script>
</body>
</html>''';
  }

  // --- Rich Action Menu for Invoices (Sales, Collections, Profit) ---
  Widget _buildInvoiceActionsMenu(dynamic inv) {
    return PopupMenuButton<String>(
      padding: EdgeInsets.zero,
      tooltip: 'Invoice Actions',
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      elevation: 6,
      icon: const Icon(
        Icons.more_vert_rounded,
        size: 18,
        color: Color(0xFF64748B),
      ),
      onSelected: (val) {
        switch (val) {
          case 'view':
            _showInvoiceDetailDialog(inv);
            break;
          case 'print_slip':
            _printSingleInvoiceSlip(inv, isA4: false);
            break;
          case 'print_a4':
            _printSingleInvoiceSlip(inv, isA4: true);
            break;
          case 'copy_no':
            _copyToClipboard(
              inv['invoice_no']?.toString() ?? '',
              'Invoice Number',
            );
            break;
          case 'customer':
            _showCustomerInfoDialog(inv);
            break;
        }
      },
      itemBuilder: (ctx) => [
        const PopupMenuItem(
          value: 'view',
          child: Row(
            children: [
              Icon(Icons.visibility_outlined, size: 16, color: primaryBlue),
              SizedBox(width: 10),
              Text(
                'View Details',
                style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w600),
              ),
            ],
          ),
        ),
        const PopupMenuDivider(height: 1),
        const PopupMenuItem(
          value: 'print_slip',
          child: Row(
            children: [
              Icon(Icons.receipt_long_rounded, size: 16, color: primaryGreen),
              SizedBox(width: 10),
              Text(
                'Print Thermal Slip (80mm)',
                style: TextStyle(fontSize: 12.5),
              ),
            ],
          ),
        ),
        const PopupMenuItem(
          value: 'print_a4',
          child: Row(
            children: [
              Icon(Icons.print_outlined, size: 16, color: Color(0xFF7C3AED)),
              SizedBox(width: 10),
              Text('Print Tax Invoice (A4)', style: TextStyle(fontSize: 12.5)),
            ],
          ),
        ),
        const PopupMenuDivider(height: 1),
        const PopupMenuItem(
          value: 'copy_no',
          child: Row(
            children: [
              Icon(Icons.copy_rounded, size: 16, color: Color(0xFFD97706)),
              SizedBox(width: 10),
              Text('Copy Invoice No', style: TextStyle(fontSize: 12.5)),
            ],
          ),
        ),
        const PopupMenuItem(
          value: 'customer',
          child: Row(
            children: [
              Icon(
                Icons.person_outline_rounded,
                size: 16,
                color: Color(0xFF475569),
              ),
              SizedBox(width: 10),
              Text('Customer Info', style: TextStyle(fontSize: 12.5)),
            ],
          ),
        ),
      ],
    );
  }

  // --- Rich Action Menu for Purchases ---
  Widget _buildPurchaseActionsMenu(dynamic p) {
    return PopupMenuButton<String>(
      padding: EdgeInsets.zero,
      tooltip: 'Purchase Actions',
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      elevation: 6,
      icon: const Icon(
        Icons.more_vert_rounded,
        size: 18,
        color: Color(0xFF64748B),
      ),
      onSelected: (val) {
        switch (val) {
          case 'view':
            _showPurchaseDetailDialog(p);
            break;
          case 'print_voucher':
            _printSinglePurchaseVoucher(p);
            break;
          case 'copy_po':
            _copyToClipboard(
              p['purchase_no']?.toString() ?? '',
              'Purchase PO Number',
            );
            break;
          case 'supplier':
            _showSupplierInfoDialog(p);
            break;
        }
      },
      itemBuilder: (ctx) => [
        const PopupMenuItem(
          value: 'view',
          child: Row(
            children: [
              Icon(Icons.visibility_outlined, size: 16, color: primaryGreen),
              SizedBox(width: 10),
              Text(
                'View Details',
                style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w600),
              ),
            ],
          ),
        ),
        const PopupMenuDivider(height: 1),
        const PopupMenuItem(
          value: 'print_voucher',
          child: Row(
            children: [
              Icon(Icons.print_outlined, size: 16, color: primaryBlue),
              SizedBox(width: 10),
              Text('Print Inward Voucher', style: TextStyle(fontSize: 12.5)),
            ],
          ),
        ),
        const PopupMenuDivider(height: 1),
        const PopupMenuItem(
          value: 'copy_po',
          child: Row(
            children: [
              Icon(Icons.copy_rounded, size: 16, color: Color(0xFFD97706)),
              SizedBox(width: 10),
              Text('Copy PO Number', style: TextStyle(fontSize: 12.5)),
            ],
          ),
        ),
        const PopupMenuItem(
          value: 'supplier',
          child: Row(
            children: [
              Icon(
                Icons.local_shipping_outlined,
                size: 16,
                color: Color(0xFF475569),
              ),
              SizedBox(width: 10),
              Text('Supplier Info', style: TextStyle(fontSize: 12.5)),
            ],
          ),
        ),
      ],
    );
  }

  void _showInvoiceDetailDialog(dynamic inv) {
    final invNo = inv['invoice_no']?.toString() ?? '-';
    final date = inv['sale_date']?.toString().split('T').first ?? '-';
    final customer = inv['customer_name']?.toString() ?? 'Walk-in Customer';
    final mode = inv['payment_method']?.toString() ?? 'Cash';
    final gross = _numVal(inv['subtotal'] ?? inv['total_amount']);
    final disc = _numVal(inv['discount']);
    final tax = _numVal(inv['tax_amount']);
    final net = _numVal(inv['total_amount']);
    final paid = _numVal(inv['paid_amount']);
    final profit = _invoiceProfit(inv);
    final itemsCount = _numVal(inv['items_count']) > 0
        ? _numVal(inv['items_count']).toInt()
        : 1;

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: const Color(0xFFE0EDFF),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Icon(
                    Icons.receipt_long_rounded,
                    color: primaryBlue,
                    size: 22,
                  ),
                ),
                const SizedBox(width: 12),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Invoice $invNo',
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: navy,
                      ),
                    ),
                    Text(
                      'Date: $date',
                      style: const TextStyle(
                        fontSize: 12,
                        color: Color(0xFF64748B),
                      ),
                    ),
                  ],
                ),
              ],
            ),
            IconButton(
              icon: const Icon(
                Icons.close_rounded,
                size: 20,
                color: Color(0xFF64748B),
              ),
              onPressed: () => Navigator.pop(ctx),
            ),
          ],
        ),
        content: SizedBox(
          width: 480,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: const Color(0xFFF8FAFC),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: cardBorder),
                ),
                child: Column(
                  children: [
                    _detailRow('Customer', customer),
                    const SizedBox(height: 8),
                    _detailRow('Payment Mode', mode),
                    const SizedBox(height: 8),
                    _detailRow('Total Items', '$itemsCount item(s)'),
                    const Divider(height: 20, color: cardBorder),
                    _detailRow('Gross Subtotal', _currency(gross)),
                    if (disc > 0) ...[
                      const SizedBox(height: 6),
                      _detailRow(
                        'Discount',
                        '- ${_currency(disc)}',
                        valueColor: Colors.red,
                      ),
                    ],
                    if (tax > 0) ...[
                      const SizedBox(height: 6),
                      _detailRow('GST / Tax', '+ ${_currency(tax)}'),
                    ],
                    const SizedBox(height: 6),
                    _detailRow('Net Total', _currency(net), isBold: true),
                    const SizedBox(height: 6),
                    _detailRow('Paid Amount', _currency(paid)),
                    const Divider(height: 20, color: cardBorder),
                    _detailRow(
                      'Estimated Margin / Profit',
                      _currency(profit),
                      valueColor: primaryGreen,
                      isBold: true,
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        actions: [
          OutlinedButton(
            onPressed: () => Navigator.pop(ctx),
            style: OutlinedButton.styleFrom(
              side: const BorderSide(color: cardBorder),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
              ),
            ),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }

  void _showPurchaseDetailDialog(dynamic p) {
    final pNo = p['purchase_no']?.toString() ?? '-';
    final date = p['purchase_date']?.toString().split('T').first ?? '-';
    final supplier = p['supplier_name']?.toString() ?? 'General Supplier';
    final sub = _numVal(p['subtotal']);
    final tax = _numVal(p['tax_amount']);
    final total = _numVal(p['total_amount']);
    final notes = p['notes']?.toString() ?? 'Stock replenishment';

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: const Color(0xFFDCFCE7),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Icon(
                    Icons.shopping_cart_outlined,
                    color: primaryGreen,
                    size: 22,
                  ),
                ),
                const SizedBox(width: 12),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Purchase Order $pNo',
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: navy,
                      ),
                    ),
                    Text(
                      'Date: $date',
                      style: const TextStyle(
                        fontSize: 12,
                        color: Color(0xFF64748B),
                      ),
                    ),
                  ],
                ),
              ],
            ),
            IconButton(
              icon: const Icon(
                Icons.close_rounded,
                size: 20,
                color: Color(0xFF64748B),
              ),
              onPressed: () => Navigator.pop(ctx),
            ),
          ],
        ),
        content: SizedBox(
          width: 480,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: const Color(0xFFF8FAFC),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: cardBorder),
                ),
                child: Column(
                  children: [
                    _detailRow('Supplier', supplier),
                    const SizedBox(height: 8),
                    _detailRow(
                      'Status',
                      'Received / In Stock',
                      valueColor: primaryGreen,
                    ),
                    const SizedBox(height: 8),
                    _detailRow('Notes', notes),
                    const Divider(height: 20, color: cardBorder),
                    _detailRow('Subtotal', _currency(sub)),
                    if (tax > 0) ...[
                      const SizedBox(height: 6),
                      _detailRow('Tax / GST', '+ ${_currency(tax)}'),
                    ],
                    const Divider(height: 20, color: cardBorder),
                    _detailRow(
                      'Total Cost',
                      _currency(total),
                      isBold: true,
                      valueColor: navy,
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        actions: [
          OutlinedButton(
            onPressed: () => Navigator.pop(ctx),
            style: OutlinedButton.styleFrom(
              side: const BorderSide(color: cardBorder),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
              ),
            ),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }

  Widget _detailRow(
    String label,
    String value, {
    bool isBold = false,
    Color? valueColor,
  }) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          label,
          style: const TextStyle(fontSize: 13, color: Color(0xFF64748B)),
        ),
        Text(
          value,
          style: TextStyle(
            fontSize: 13,
            fontWeight: isBold ? FontWeight.bold : FontWeight.w600,
            color: valueColor ?? navy,
          ),
        ),
      ],
    );
  }

  // --- Main Build ---
  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator(color: primaryBlue));
    }

    if (_errorMessage != null) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.error_outline, size: 48, color: Colors.red),
            const SizedBox(height: 12),
            Text(_errorMessage!, style: const TextStyle(color: Colors.red)),
            const SizedBox(height: 12),
            ElevatedButton(
              onPressed: _loadData,
              style: ElevatedButton.styleFrom(
                backgroundColor: primaryBlue,
                foregroundColor: Colors.white,
              ),
              child: const Text('Retry'),
            ),
          ],
        ),
      );
    }

    return Container(
      color: const Color(0xFFF8FAFC),
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _buildTopHeader(),
            const SizedBox(height: 16),
            _buildFiveMetricCards(),
            const SizedBox(height: 16),
            _buildSalesRegisterTableCard(),
            const SizedBox(height: 24),
          ],
        ),
      ),
    );
  }

  // 1. TOP HEADER
  Widget _buildTopHeader() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          _viewTitle,
          style: const TextStyle(
            fontSize: 22,
            fontWeight: FontWeight.w800,
            color: navy,
            letterSpacing: -0.3,
          ),
        ),
        Row(
          children: [
            OutlinedButton.icon(
              onPressed: _exportCurrentReport,
              icon: const Icon(Icons.file_download_outlined, size: 16),
              label: const Text(
                'Export CSV',
                style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
              ),
              style: OutlinedButton.styleFrom(
                foregroundColor: navy,
                side: const BorderSide(color: cardBorder),
                backgroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(
                  horizontal: 14,
                  vertical: 10,
                ),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
            ),
            const SizedBox(width: 8),
            OutlinedButton.icon(
              onPressed: _printCurrentReport,
              icon: const Icon(Icons.print_outlined, size: 16),
              label: const Text(
                'Print Report',
                style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
              ),
              style: OutlinedButton.styleFrom(
                foregroundColor: navy,
                side: const BorderSide(color: cardBorder),
                backgroundColor: Colors.white,
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
    );
  }

  Color get _activeColor {
    switch (_activeView) {
      case ReportView.sales:
        return const Color(0xFF2563EB);
      case ReportView.purchase:
        return const Color(0xFF16A34A);
      case ReportView.stock:
        return const Color(0xFFD97706);
      case ReportView.collections:
        return const Color(0xFF9333EA);
      case ReportView.profit:
        return const Color(0xFF0D9488);
    }
  }

  IconData get _activeIcon {
    switch (_activeView) {
      case ReportView.sales:
        return Icons.local_mall_outlined;
      case ReportView.purchase:
        return Icons.shopping_cart_outlined;
      case ReportView.stock:
        return Icons.inventory_2_outlined;
      case ReportView.collections:
        return Icons.account_balance_wallet_outlined;
      case ReportView.profit:
        return Icons.trending_up_rounded;
    }
  }

  void _switchView(ReportView view) {
    setState(() {
      _activeView = view;
      _reportSearch = '';
      _reportSearchCtrl.clear();
      _currentPage = 1;
    });
  }

  // 3. THE 5 METRIC CARDS (INTERACTIVE TABS)
  Widget _buildFiveMetricCards() {
    return LayoutBuilder(
      builder: (context, constraints) {
        int columns;
        if (constraints.maxWidth < 640) {
          columns = 1;
        } else if (constraints.maxWidth < 980) {
          columns = 2;
        } else {
          columns = 5;
        }

        final double totalSpacing = (columns - 1) * 12.0;
        final double cardWidth =
            (constraints.maxWidth - totalSpacing) / columns;

        final cards = [
          _buildClickableMetricCard(
            title: 'Total Sales',
            value: _currency(_totalSales),
            trend: '${_filteredInvoices.length} invoices',
            icon: Icons.local_mall_outlined,
            iconBg: const Color(0xFFE0EDFF),
            iconColor: const Color(0xFF2563EB),
            isActive: _activeView == ReportView.sales,
            onTap: () => _switchView(ReportView.sales),
          ),
          _buildClickableMetricCard(
            title: 'Total Purchase',
            value: _currency(_totalPurchases),
            trend: '${_filteredPurchases.length} orders recorded',
            icon: Icons.shopping_cart_outlined,
            iconBg: const Color(0xFFDCFCE7),
            iconColor: const Color(0xFF16A34A),
            isActive: _activeView == ReportView.purchase,
            onTap: () => _switchView(ReportView.purchase),
          ),
          _buildClickableMetricCard(
            title: 'Stock Value',
            value: _currency(_stockValue),
            trend: '${_filteredProducts.length} products in stock',
            icon: Icons.inventory_2_outlined,
            iconBg: const Color(0xFFFEF3C7),
            iconColor: const Color(0xFFD97706),
            isActive: _activeView == ReportView.stock,
            onTap: () => _switchView(ReportView.stock),
          ),
          _buildClickableMetricCard(
            title: 'Cash Collection',
            value: _currency(_cashCollection),
            trend:
                '${_totalSales > 0 ? ((_cashCollection / _totalSales) * 100).toStringAsFixed(0) : 100}% collected',
            icon: Icons.account_balance_wallet_outlined,
            iconBg: const Color(0xFFF3E8FF),
            iconColor: const Color(0xFF9333EA),
            isActive: _activeView == ReportView.collections,
            onTap: () => _switchView(ReportView.collections),
          ),
          _buildClickableMetricCard(
            title: 'Total Profit',
            value: _currency(_totalProfit),
            trend:
                '${_totalSales > 0 ? ((_totalProfit / _totalSales) * 100).toStringAsFixed(1) : 0}% net margin',
            icon: Icons.trending_up_rounded,
            iconBg: const Color(0xFFCCFBF1),
            iconColor: const Color(0xFF0D9488),
            isActive: _activeView == ReportView.profit,
            onTap: () => _switchView(ReportView.profit),
          ),
        ];

        return Wrap(
          spacing: 12,
          runSpacing: 12,
          children: cards
              .map((c) => SizedBox(width: cardWidth, child: c))
              .toList(),
        );
      },
    );
  }

  Widget _buildClickableMetricCard({
    required String title,
    required String value,
    required String trend,
    required IconData icon,
    required Color iconBg,
    required Color iconColor,
    required bool isActive,
    required VoidCallback onTap,
  }) {
    return Material(
      color: isActive ? iconBg.withValues(alpha: 0.35) : Colors.white,
      borderRadius: BorderRadius.circular(12),
      elevation: isActive ? 2 : 0,
      shadowColor: iconColor.withValues(alpha: 0.25),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        hoverColor: iconBg.withValues(alpha: 0.2),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: isActive ? iconColor : cardBorder,
              width: isActive ? 2 : 1,
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Row(
                children: [
                  Container(
                    width: 28,
                    height: 28,
                    decoration: BoxDecoration(
                      color: iconBg,
                      shape: BoxShape.circle,
                    ),
                    child: Icon(icon, color: iconColor, size: 15),
                  ),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 11.5,
                        fontWeight: isActive
                            ? FontWeight.w800
                            : FontWeight.w600,
                        color: isActive ? navy : const Color(0xFF64748B),
                      ),
                    ),
                  ),
                  if (isActive) ...[
                    const SizedBox(width: 4),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 5,
                        vertical: 1.5,
                      ),
                      decoration: BoxDecoration(
                        color: iconColor,
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: const Text(
                        'ACTIVE',
                        style: TextStyle(
                          fontSize: 7.5,
                          fontWeight: FontWeight.w800,
                          color: Colors.white,
                          letterSpacing: 0.3,
                        ),
                      ),
                    ),
                  ],
                ],
              ),
              const SizedBox(height: 6),
              Text(
                value,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  fontSize: 15.5,
                  fontWeight: FontWeight.w800,
                  color: navy,
                  letterSpacing: -0.3,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                trend,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontSize: 10,
                  fontWeight: FontWeight.w600,
                  color: isActive ? iconColor : primaryGreen,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // 4. DETAILED REGISTER TABLE & PAGINATION (SWITCHES WITH ACTIVE VIEW)
  Widget _buildSalesRegisterTableCard() {
    final activeList = _currentActiveList;
    final totalEntries = activeList.length;
    final startIndex = (_currentPage - 1) * _rowsPerPage;
    final endIndex = (startIndex + _rowsPerPage).clamp(0, totalEntries);
    final pageItems = totalEntries > 0
        ? activeList.sublist(startIndex, endIndex)
        : [];

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: cardBorder),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // View Header Bar
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: const BoxDecoration(
              border: Border(bottom: BorderSide(color: cardBorder)),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(6),
                      decoration: BoxDecoration(
                        color: _activeColor.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Icon(_activeIcon, color: _activeColor, size: 18),
                    ),
                    const SizedBox(width: 10),
                    Text(
                      _viewTitle,
                      style: const TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.bold,
                        color: navy,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 2,
                      ),
                      decoration: BoxDecoration(
                        color: const Color(0xFFF1F5F9),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Text(
                        '$totalEntries entries',
                        style: const TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.bold,
                          color: Color(0xFF64748B),
                        ),
                      ),
                    ),
                  ],
                ),
                SizedBox(
                  width: 250,
                  height: 36,
                  child: TextField(
                    controller: _reportSearchCtrl,
                    inputFormatters: const [NoLeadingSpaceFormatter()],
                    onChanged: (val) => setState(() {
                      _reportSearch = val;
                      _currentPage = 1;
                    }),
                    style: const TextStyle(fontSize: 12.5, color: navy),
                    decoration: InputDecoration(
                      hintText: 'Search $_viewTitle...',
                      hintStyle: const TextStyle(
                        fontSize: 12,
                        color: Color(0xFF94A3B8),
                      ),
                      prefixIcon: const Icon(
                        Icons.search_rounded,
                        size: 17,
                        color: Color(0xFF64748B),
                      ),
                      suffixIcon: _reportSearch.isNotEmpty
                          ? IconButton(
                              icon: const Icon(
                                Icons.clear_rounded,
                                size: 15,
                                color: Color(0xFF64748B),
                              ),
                              padding: EdgeInsets.zero,
                              onPressed: () {
                                _reportSearchCtrl.clear();
                                setState(() {
                                  _reportSearch = '';
                                  _currentPage = 1;
                                });
                              },
                            )
                          : null,
                      filled: true,
                      fillColor: const Color(0xFFF8FAFC),
                      isDense: true,
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 8,
                      ),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8),
                        borderSide: const BorderSide(color: cardBorder),
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8),
                        borderSide: const BorderSide(color: cardBorder),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8),
                        borderSide: const BorderSide(
                          color: primaryBlue,
                          width: 1.5,
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),

          // Responsive Table
          LayoutBuilder(
            builder: (context, constraints) {
              const minWidth = 1000.0;
              final tableWidth = constraints.maxWidth > minWidth
                  ? constraints.maxWidth
                  : minWidth;

              return SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: SizedBox(
                  width: tableWidth,
                  child: Column(
                    children: [
                      _buildActiveTableHeader(),
                      _buildActiveTableRows(pageItems, startIndex),
                    ],
                  ),
                ),
              );
            },
          ),
          if (pageItems.isEmpty)
            Padding(
              padding: const EdgeInsets.all(32),
              child: Center(
                child: Text(
                  'No entries found for $_viewTitle',
                  style: const TextStyle(color: Color(0xFF64748B)),
                ),
              ),
            ),
          const Divider(height: 1, color: cardBorder),

          // Footer & Pagination Bar
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  totalEntries == 0
                      ? 'Showing 0 entries'
                      : 'Showing ${startIndex + 1} to $endIndex of $totalEntries entries',
                  style: const TextStyle(
                    fontSize: 12.5,
                    color: Color(0xFF64748B),
                  ),
                ),
                Row(
                  children: [
                    Container(
                      height: 32,
                      padding: const EdgeInsets.symmetric(horizontal: 8),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(6),
                        border: Border.all(color: cardBorder),
                      ),
                      child: DropdownButtonHideUnderline(
                        child: DropdownButton<int>(
                          value: _rowsPerPage,
                          style: const TextStyle(
                            fontSize: 12,
                            color: navy,
                            fontWeight: FontWeight.w500,
                          ),
                          items: [10, 25, 50]
                              .map(
                                (n) => DropdownMenuItem(
                                  value: n,
                                  child: Text('$n per page'),
                                ),
                              )
                              .toList(),
                          onChanged: (v) {
                            if (v != null) {
                              setState(() {
                                _rowsPerPage = v;
                                _currentPage = 1;
                              });
                            }
                          },
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    IconButton(
                      icon: const Icon(Icons.chevron_left_rounded, size: 20),
                      onPressed: _currentPage > 1
                          ? () => setState(() => _currentPage--)
                          : null,
                      color: const Color(0xFF64748B),
                    ),
                    Container(
                      width: 28,
                      height: 28,
                      alignment: Alignment.center,
                      decoration: BoxDecoration(
                        color: _activeColor,
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Text(
                        '$_currentPage',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.chevron_right_rounded, size: 20),
                      onPressed: endIndex < totalEntries
                          ? () => setState(() => _currentPage++)
                          : null,
                      color: const Color(0xFF64748B),
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

  // --- Active Table Headers ---
  Widget _buildActiveTableHeader() {
    switch (_activeView) {
      case ReportView.sales:
        return _buildSalesHeader();
      case ReportView.purchase:
        return _buildPurchaseHeader();
      case ReportView.stock:
        return _buildStockHeader();
      case ReportView.collections:
        return _buildCollectionsHeader();
      case ReportView.profit:
        return _buildProfitHeader();
    }
  }

  Widget _buildSalesHeader() {
    return Container(
      height: 44,
      padding: const EdgeInsets.symmetric(horizontal: 16),
      decoration: const BoxDecoration(
        color: Color(0xFFF8FAFC),
        border: Border(bottom: BorderSide(color: cardBorder)),
      ),
      child: const Row(
        children: [
          SizedBox(
            width: 32,
            child: Text(
              '#',
              style: TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 12,
                color: Color(0xFF64748B),
              ),
            ),
          ),
          SizedBox(
            width: 90,
            child: Text(
              'Date',
              style: TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 12,
                color: Color(0xFF64748B),
              ),
            ),
          ),
          Expanded(
            flex: 3,
            child: Text(
              'Invoice No.',
              style: TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 12,
                color: Color(0xFF64748B),
              ),
            ),
          ),
          Expanded(
            flex: 3,
            child: Text(
              'Customer',
              style: TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 12,
                color: Color(0xFF64748B),
              ),
            ),
          ),
          SizedBox(
            width: 55,
            child: Text(
              'Items',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 12,
                color: Color(0xFF64748B),
              ),
            ),
          ),
          SizedBox(
            width: 80,
            child: Text(
              'Mode',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 12,
                color: Color(0xFF64748B),
              ),
            ),
          ),
          Expanded(
            flex: 2,
            child: Text(
              'Gross',
              textAlign: TextAlign.right,
              style: TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 12,
                color: Color(0xFF64748B),
              ),
            ),
          ),
          Expanded(
            flex: 2,
            child: Text(
              'Discount',
              textAlign: TextAlign.right,
              style: TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 12,
                color: Color(0xFF64748B),
              ),
            ),
          ),
          Expanded(
            flex: 2,
            child: Text(
              'Net Amount',
              textAlign: TextAlign.right,
              style: TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 12,
                color: Color(0xFF64748B),
              ),
            ),
          ),
          Expanded(
            flex: 2,
            child: Text(
              'Profit',
              textAlign: TextAlign.right,
              style: TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 12,
                color: Color(0xFF64748B),
              ),
            ),
          ),
          SizedBox(width: 14),
          SizedBox(
            width: 44,
            child: Text(
              'Action',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 12,
                color: Color(0xFF64748B),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPurchaseHeader() {
    return Container(
      height: 44,
      padding: const EdgeInsets.symmetric(horizontal: 16),
      decoration: const BoxDecoration(
        color: Color(0xFFF8FAFC),
        border: Border(bottom: BorderSide(color: cardBorder)),
      ),
      child: const Row(
        children: [
          SizedBox(
            width: 32,
            child: Text(
              '#',
              style: TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 12,
                color: Color(0xFF64748B),
              ),
            ),
          ),
          SizedBox(
            width: 90,
            child: Text(
              'Date',
              style: TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 12,
                color: Color(0xFF64748B),
              ),
            ),
          ),
          Expanded(
            flex: 3,
            child: Text(
              'Purchase No.',
              style: TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 12,
                color: Color(0xFF64748B),
              ),
            ),
          ),
          Expanded(
            flex: 3,
            child: Text(
              'Supplier',
              style: TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 12,
                color: Color(0xFF64748B),
              ),
            ),
          ),
          Expanded(
            flex: 2,
            child: Text(
              'Subtotal',
              textAlign: TextAlign.right,
              style: TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 12,
                color: Color(0xFF64748B),
              ),
            ),
          ),
          Expanded(
            flex: 2,
            child: Text(
              'Tax',
              textAlign: TextAlign.right,
              style: TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 12,
                color: Color(0xFF64748B),
              ),
            ),
          ),
          Expanded(
            flex: 2,
            child: Text(
              'Total Cost',
              textAlign: TextAlign.right,
              style: TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 12,
                color: Color(0xFF64748B),
              ),
            ),
          ),
          SizedBox(
            width: 90,
            child: Text(
              'Status',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 12,
                color: Color(0xFF64748B),
              ),
            ),
          ),
          Expanded(
            flex: 3,
            child: Text(
              'Notes / Remarks',
              style: TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 12,
                color: Color(0xFF64748B),
              ),
            ),
          ),
          SizedBox(width: 14),
          SizedBox(
            width: 44,
            child: Text(
              'Action',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 12,
                color: Color(0xFF64748B),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStockHeader() {
    return Container(
      height: 44,
      padding: const EdgeInsets.symmetric(horizontal: 16),
      decoration: const BoxDecoration(
        color: Color(0xFFF8FAFC),
        border: Border(bottom: BorderSide(color: cardBorder)),
      ),
      child: const Row(
        children: [
          SizedBox(
            width: 32,
            child: Text(
              '#',
              style: TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 12,
                color: Color(0xFF64748B),
              ),
            ),
          ),
          Expanded(
            flex: 4,
            child: Text(
              'Product Name',
              style: TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 12,
                color: Color(0xFF64748B),
              ),
            ),
          ),
          Expanded(
            flex: 3,
            child: Text(
              'SKU / Barcode',
              style: TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 12,
                color: Color(0xFF64748B),
              ),
            ),
          ),
          Expanded(
            flex: 3,
            child: Text(
              'Category',
              style: TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 12,
                color: Color(0xFF64748B),
              ),
            ),
          ),
          SizedBox(
            width: 75,
            child: Text(
              'Stock Qty',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 12,
                color: Color(0xFF64748B),
              ),
            ),
          ),
          SizedBox(
            width: 60,
            child: Text(
              'Unit',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 12,
                color: Color(0xFF64748B),
              ),
            ),
          ),
          Expanded(
            flex: 2,
            child: Text(
              'Cost Price',
              textAlign: TextAlign.right,
              style: TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 12,
                color: Color(0xFF64748B),
              ),
            ),
          ),
          Expanded(
            flex: 2,
            child: Text(
              'Selling Price',
              textAlign: TextAlign.right,
              style: TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 12,
                color: Color(0xFF64748B),
              ),
            ),
          ),
          Expanded(
            flex: 3,
            child: Text(
              'Total Valuation',
              textAlign: TextAlign.right,
              style: TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 12,
                color: Color(0xFF64748B),
              ),
            ),
          ),
          SizedBox(width: 14),
          SizedBox(
            width: 95,
            child: Text(
              'Status',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 12,
                color: Color(0xFF64748B),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCollectionsHeader() {
    return Container(
      height: 44,
      padding: const EdgeInsets.symmetric(horizontal: 16),
      decoration: const BoxDecoration(
        color: Color(0xFFF8FAFC),
        border: Border(bottom: BorderSide(color: cardBorder)),
      ),
      child: const Row(
        children: [
          SizedBox(
            width: 32,
            child: Text(
              '#',
              style: TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 12,
                color: Color(0xFF64748B),
              ),
            ),
          ),
          SizedBox(
            width: 90,
            child: Text(
              'Date',
              style: TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 12,
                color: Color(0xFF64748B),
              ),
            ),
          ),
          Expanded(
            flex: 3,
            child: Text(
              'Invoice No.',
              style: TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 12,
                color: Color(0xFF64748B),
              ),
            ),
          ),
          Expanded(
            flex: 3,
            child: Text(
              'Customer',
              style: TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 12,
                color: Color(0xFF64748B),
              ),
            ),
          ),
          SizedBox(
            width: 80,
            child: Text(
              'Mode',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 12,
                color: Color(0xFF64748B),
              ),
            ),
          ),
          Expanded(
            flex: 2,
            child: Text(
              'Total Billed',
              textAlign: TextAlign.right,
              style: TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 12,
                color: Color(0xFF64748B),
              ),
            ),
          ),
          Expanded(
            flex: 2,
            child: Text(
              'Collected',
              textAlign: TextAlign.right,
              style: TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 12,
                color: Color(0xFF64748B),
              ),
            ),
          ),
          Expanded(
            flex: 2,
            child: Text(
              'Balance Due',
              textAlign: TextAlign.right,
              style: TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 12,
                color: Color(0xFF64748B),
              ),
            ),
          ),
          SizedBox(
            width: 90,
            child: Text(
              'Status',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 12,
                color: Color(0xFF64748B),
              ),
            ),
          ),
          SizedBox(width: 14),
          SizedBox(
            width: 44,
            child: Text(
              'Action',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 12,
                color: Color(0xFF64748B),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildProfitHeader() {
    return Container(
      height: 44,
      padding: const EdgeInsets.symmetric(horizontal: 16),
      decoration: const BoxDecoration(
        color: Color(0xFFF8FAFC),
        border: Border(bottom: BorderSide(color: cardBorder)),
      ),
      child: const Row(
        children: [
          SizedBox(
            width: 32,
            child: Text(
              '#',
              style: TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 12,
                color: Color(0xFF64748B),
              ),
            ),
          ),
          SizedBox(
            width: 90,
            child: Text(
              'Date',
              style: TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 12,
                color: Color(0xFF64748B),
              ),
            ),
          ),
          Expanded(
            flex: 3,
            child: Text(
              'Invoice No.',
              style: TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 12,
                color: Color(0xFF64748B),
              ),
            ),
          ),
          Expanded(
            flex: 3,
            child: Text(
              'Customer',
              style: TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 12,
                color: Color(0xFF64748B),
              ),
            ),
          ),
          SizedBox(
            width: 55,
            child: Text(
              'Items',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 12,
                color: Color(0xFF64748B),
              ),
            ),
          ),
          Expanded(
            flex: 2,
            child: Text(
              'Revenue',
              textAlign: TextAlign.right,
              style: TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 12,
                color: Color(0xFF64748B),
              ),
            ),
          ),
          Expanded(
            flex: 2,
            child: Text(
              'Est. Cost',
              textAlign: TextAlign.right,
              style: TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 12,
                color: Color(0xFF64748B),
              ),
            ),
          ),
          Expanded(
            flex: 2,
            child: Text(
              'Net Profit',
              textAlign: TextAlign.right,
              style: TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 12,
                color: Color(0xFF64748B),
              ),
            ),
          ),
          SizedBox(
            width: 85,
            child: Text(
              'Margin %',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 12,
                color: Color(0xFF64748B),
              ),
            ),
          ),
          SizedBox(width: 14),
          SizedBox(
            width: 44,
            child: Text(
              'Action',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 12,
                color: Color(0xFF64748B),
              ),
            ),
          ),
        ],
      ),
    );
  }

  // --- Active Table Rows ---
  Widget _buildActiveTableRows(List<dynamic> items, int startIndex) {
    return Column(
      children: List.generate(items.length, (idx) {
        final item = items[idx];
        final rowNum = startIndex + idx + 1;
        final isLast = idx == items.length - 1;

        switch (_activeView) {
          case ReportView.sales:
            return _buildSalesRow(item, rowNum, isLast);
          case ReportView.purchase:
            return _buildPurchaseRow(item, rowNum, isLast);
          case ReportView.stock:
            return _buildStockRow(item, rowNum, isLast);
          case ReportView.collections:
            return _buildCollectionsRow(item, rowNum, isLast);
          case ReportView.profit:
            return _buildProfitRow(item, rowNum, isLast);
        }
      }),
    );
  }

  Widget _buildSalesRow(dynamic inv, int rowNum, bool isLast) {
    final date = inv['sale_date']?.toString().split('T').first ?? '-';
    final invNo = inv['invoice_no']?.toString() ?? '-';
    final customer = inv['customer_name']?.toString() ?? 'Walk-in Customer';
    final itemsCount = _numVal(inv['items_count']) > 0
        ? _numVal(inv['items_count']).toInt()
        : ((inv['items'] is List) ? (inv['items'] as List).length : 1);
    final mode = inv['payment_method']?.toString() ?? 'Cash';
    final gross = _numVal(inv['subtotal'] ?? inv['total_amount']);
    final discount = _numVal(inv['discount']);
    final net = _numVal(inv['total_amount']);
    final profit = _invoiceProfit(inv);

    return Container(
      height: 48,
      padding: const EdgeInsets.symmetric(horizontal: 16),
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border(
          bottom: BorderSide(
            color: isLast ? Colors.transparent : const Color(0xFFF1F5F9),
          ),
        ),
      ),
      child: Row(
        children: [
          SizedBox(
            width: 32,
            child: Text(
              '$rowNum',
              style: const TextStyle(fontSize: 12, color: Color(0xFF64748B)),
            ),
          ),
          SizedBox(
            width: 90,
            child: Text(date, style: const TextStyle(fontSize: 12)),
          ),
          Expanded(
            flex: 3,
            child: Text(
              invNo,
              style: const TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: navy,
              ),
              overflow: TextOverflow.ellipsis,
            ),
          ),
          Expanded(
            flex: 3,
            child: Text(
              customer,
              style: const TextStyle(fontSize: 12),
              overflow: TextOverflow.ellipsis,
            ),
          ),
          SizedBox(
            width: 55,
            child: Center(
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                decoration: BoxDecoration(
                  color: const Color(0xFFF1F5F9),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Text(
                  '$itemsCount',
                  style: const TextStyle(
                    fontSize: 11.5,
                    fontWeight: FontWeight.w600,
                    color: navy,
                  ),
                ),
              ),
            ),
          ),
          SizedBox(width: 80, child: Center(child: _buildPaymentBadge(mode))),
          Expanded(
            flex: 2,
            child: Text(
              _currency(gross),
              textAlign: TextAlign.right,
              style: const TextStyle(fontSize: 12),
            ),
          ),
          Expanded(
            flex: 2,
            child: Text(
              discount > 0 ? _currency(discount) : '₹0.00',
              textAlign: TextAlign.right,
              style: TextStyle(
                fontSize: 12,
                color: discount > 0 ? Colors.red : const Color(0xFF64748B),
              ),
            ),
          ),
          Expanded(
            flex: 2,
            child: Text(
              _currency(net),
              textAlign: TextAlign.right,
              style: const TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.bold,
                color: navy,
              ),
            ),
          ),
          Expanded(
            flex: 2,
            child: Text(
              _currency(profit),
              textAlign: TextAlign.right,
              style: const TextStyle(
                fontSize: 12,
                color: primaryGreen,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
          const SizedBox(width: 14),
          SizedBox(
            width: 44,
            child: Center(child: _buildInvoiceActionsMenu(inv)),
          ),
        ],
      ),
    );
  }

  Widget _buildPurchaseRow(dynamic p, int rowNum, bool isLast) {
    final date = p['purchase_date']?.toString().split('T').first ?? '-';
    final pNo = p['purchase_no']?.toString() ?? '-';
    final supplier = p['supplier_name']?.toString() ?? 'General Supplier';
    final subtotal = _numVal(p['subtotal']);
    final tax = _numVal(p['tax_amount']);
    final total = _numVal(p['total_amount']);
    final notes = p['notes']?.toString() ?? '-';

    return Container(
      height: 48,
      padding: const EdgeInsets.symmetric(horizontal: 16),
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border(
          bottom: BorderSide(
            color: isLast ? Colors.transparent : const Color(0xFFF1F5F9),
          ),
        ),
      ),
      child: Row(
        children: [
          SizedBox(
            width: 32,
            child: Text(
              '$rowNum',
              style: const TextStyle(fontSize: 12, color: Color(0xFF64748B)),
            ),
          ),
          SizedBox(
            width: 90,
            child: Text(date, style: const TextStyle(fontSize: 12)),
          ),
          Expanded(
            flex: 3,
            child: Text(
              pNo,
              style: const TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: navy,
              ),
              overflow: TextOverflow.ellipsis,
            ),
          ),
          Expanded(
            flex: 3,
            child: Text(
              supplier,
              style: const TextStyle(fontSize: 12),
              overflow: TextOverflow.ellipsis,
            ),
          ),
          Expanded(
            flex: 2,
            child: Text(
              _currency(subtotal),
              textAlign: TextAlign.right,
              style: const TextStyle(fontSize: 12),
            ),
          ),
          Expanded(
            flex: 2,
            child: Text(
              _currency(tax),
              textAlign: TextAlign.right,
              style: const TextStyle(fontSize: 12),
            ),
          ),
          Expanded(
            flex: 2,
            child: Text(
              _currency(total),
              textAlign: TextAlign.right,
              style: const TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.bold,
                color: navy,
              ),
            ),
          ),
          SizedBox(
            width: 90,
            child: Center(
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                decoration: BoxDecoration(
                  color: const Color(0xFFDCFCE7),
                  borderRadius: BorderRadius.circular(4),
                ),
                child: const Text(
                  'Received',
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF16A34A),
                  ),
                ),
              ),
            ),
          ),
          Expanded(
            flex: 3,
            child: Text(
              notes,
              style: const TextStyle(fontSize: 12, color: Color(0xFF64748B)),
              overflow: TextOverflow.ellipsis,
            ),
          ),
          const SizedBox(width: 14),
          SizedBox(
            width: 44,
            child: Center(child: _buildPurchaseActionsMenu(p)),
          ),
        ],
      ),
    );
  }

  Widget _buildStockRow(dynamic prod, int rowNum, bool isLast) {
    final name = prod['product_name']?.toString() ?? '-';
    final sku = prod['sku']?.toString() ?? '-';
    final cat = prod['category_name']?.toString() ?? 'Uncategorized';
    final qty = _numVal(prod['stock_qty']);
    final unit = prod['unit']?.toString() ?? '';
    final cost = _numVal(prod['cost_price'] ?? 0);
    final sell = _numVal(prod['selling_price'] ?? 0);
    final val = qty * (cost > 0 ? cost : sell);
    final isLowStock = qty <= _numVal(prod['reorder_level']);

    return Container(
      height: 48,
      padding: const EdgeInsets.symmetric(horizontal: 16),
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border(
          bottom: BorderSide(
            color: isLast ? Colors.transparent : const Color(0xFFF1F5F9),
          ),
        ),
      ),
      child: Row(
        children: [
          SizedBox(
            width: 32,
            child: Text(
              '$rowNum',
              style: const TextStyle(fontSize: 12, color: Color(0xFF64748B)),
            ),
          ),
          Expanded(
            flex: 4,
            child: Text(
              name,
              style: const TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: navy,
              ),
              overflow: TextOverflow.ellipsis,
            ),
          ),
          Expanded(
            flex: 3,
            child: Row(
              children: [
                const Icon(
                  Icons.qr_code_2_rounded,
                  size: 14,
                  color: Color(0xFF94A3B8),
                ),
                const SizedBox(width: 4),
                Expanded(
                  child: Text(
                    sku,
                    style: const TextStyle(
                      fontSize: 11.5,
                      fontFamily: 'monospace',
                      color: Color(0xFF475569),
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
          ),
          Expanded(
            flex: 3,
            child: Text(
              cat,
              style: const TextStyle(fontSize: 12, color: Color(0xFF64748B)),
              overflow: TextOverflow.ellipsis,
            ),
          ),
          SizedBox(
            width: 75,
            child: Center(
              child: Text(
                '${qty % 1 == 0 ? qty.toInt() : qty}',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                  color: isLowStock ? Colors.red : navy,
                ),
              ),
            ),
          ),
          SizedBox(
            width: 60,
            child: Center(
              child: Text(
                unit,
                style: const TextStyle(
                  fontSize: 11.5,
                  color: Color(0xFF64748B),
                ),
              ),
            ),
          ),
          Expanded(
            flex: 2,
            child: Text(
              _currency(cost),
              textAlign: TextAlign.right,
              style: const TextStyle(fontSize: 12),
            ),
          ),
          Expanded(
            flex: 2,
            child: Text(
              _currency(sell),
              textAlign: TextAlign.right,
              style: const TextStyle(fontSize: 12),
            ),
          ),
          Expanded(
            flex: 3,
            child: Text(
              _currency(val),
              textAlign: TextAlign.right,
              style: const TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.bold,
                color: Color(0xFFD97706),
              ),
            ),
          ),
          const SizedBox(width: 14),
          SizedBox(
            width: 95,
            child: Center(
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                decoration: BoxDecoration(
                  color: isLowStock
                      ? const Color(0xFFFEE2E2)
                      : const Color(0xFFDCFCE7),
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Text(
                  isLowStock ? 'Low Stock' : 'In Stock',
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.bold,
                    color: isLowStock ? Colors.red : const Color(0xFF16A34A),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCollectionsRow(dynamic inv, int rowNum, bool isLast) {
    final date = inv['sale_date']?.toString().split('T').first ?? '-';
    final invNo = inv['invoice_no']?.toString() ?? '-';
    final customer = inv['customer_name']?.toString() ?? 'Walk-in Customer';
    final mode = inv['payment_method']?.toString() ?? 'Cash';
    final billed = _numVal(inv['total_amount']);
    final collected = _numVal(inv['paid_amount']);
    final balance = (billed - collected).clamp(0.0, double.infinity);
    final status = inv['payment_status']?.toString() ?? 'Paid';

    return Container(
      height: 48,
      padding: const EdgeInsets.symmetric(horizontal: 16),
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border(
          bottom: BorderSide(
            color: isLast ? Colors.transparent : const Color(0xFFF1F5F9),
          ),
        ),
      ),
      child: Row(
        children: [
          SizedBox(
            width: 32,
            child: Text(
              '$rowNum',
              style: const TextStyle(fontSize: 12, color: Color(0xFF64748B)),
            ),
          ),
          SizedBox(
            width: 90,
            child: Text(date, style: const TextStyle(fontSize: 12)),
          ),
          Expanded(
            flex: 3,
            child: Text(
              invNo,
              style: const TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: navy,
              ),
              overflow: TextOverflow.ellipsis,
            ),
          ),
          Expanded(
            flex: 3,
            child: Text(
              customer,
              style: const TextStyle(fontSize: 12),
              overflow: TextOverflow.ellipsis,
            ),
          ),
          SizedBox(width: 80, child: Center(child: _buildPaymentBadge(mode))),
          Expanded(
            flex: 2,
            child: Text(
              _currency(billed),
              textAlign: TextAlign.right,
              style: const TextStyle(fontSize: 12),
            ),
          ),
          Expanded(
            flex: 2,
            child: Text(
              _currency(collected),
              textAlign: TextAlign.right,
              style: const TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.bold,
                color: primaryGreen,
              ),
            ),
          ),
          Expanded(
            flex: 2,
            child: Text(
              balance > 0 ? _currency(balance) : '₹0.00',
              textAlign: TextAlign.right,
              style: TextStyle(
                fontSize: 12,
                fontWeight: balance > 0 ? FontWeight.bold : FontWeight.normal,
                color: balance > 0 ? Colors.red : const Color(0xFF64748B),
              ),
            ),
          ),
          SizedBox(
            width: 90,
            child: Center(
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                decoration: BoxDecoration(
                  color: status.toLowerCase() == 'paid'
                      ? const Color(0xFFDCFCE7)
                      : const Color(0xFFFEF3C7),
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Text(
                  status,
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.bold,
                    color: status.toLowerCase() == 'paid'
                        ? const Color(0xFF16A34A)
                        : const Color(0xFFD97706),
                  ),
                ),
              ),
            ),
          ),
          const SizedBox(width: 14),
          SizedBox(
            width: 44,
            child: Center(child: _buildInvoiceActionsMenu(inv)),
          ),
        ],
      ),
    );
  }

  Widget _buildProfitRow(dynamic inv, int rowNum, bool isLast) {
    final date = inv['sale_date']?.toString().split('T').first ?? '-';
    final invNo = inv['invoice_no']?.toString() ?? '-';
    final customer = inv['customer_name']?.toString() ?? 'Walk-in Customer';
    final itemsCount = _numVal(inv['items_count']) > 0
        ? _numVal(inv['items_count']).toInt()
        : ((inv['items'] is List) ? (inv['items'] as List).length : 1);
    final revenue = _numVal(inv['total_amount']);
    final profit = _invoiceProfit(inv);
    final cost = (revenue - profit).clamp(0.0, double.infinity);
    final marginPct = revenue > 0
        ? ((profit / revenue) * 100).toStringAsFixed(1)
        : '0';

    return Container(
      height: 48,
      padding: const EdgeInsets.symmetric(horizontal: 16),
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border(
          bottom: BorderSide(
            color: isLast ? Colors.transparent : const Color(0xFFF1F5F9),
          ),
        ),
      ),
      child: Row(
        children: [
          SizedBox(
            width: 32,
            child: Text(
              '$rowNum',
              style: const TextStyle(fontSize: 12, color: Color(0xFF64748B)),
            ),
          ),
          SizedBox(
            width: 90,
            child: Text(date, style: const TextStyle(fontSize: 12)),
          ),
          Expanded(
            flex: 3,
            child: Text(
              invNo,
              style: const TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: navy,
              ),
              overflow: TextOverflow.ellipsis,
            ),
          ),
          Expanded(
            flex: 3,
            child: Text(
              customer,
              style: const TextStyle(fontSize: 12),
              overflow: TextOverflow.ellipsis,
            ),
          ),
          SizedBox(
            width: 55,
            child: Center(
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                decoration: BoxDecoration(
                  color: const Color(0xFFF1F5F9),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Text(
                  '$itemsCount',
                  style: const TextStyle(
                    fontSize: 11.5,
                    fontWeight: FontWeight.w600,
                    color: navy,
                  ),
                ),
              ),
            ),
          ),
          Expanded(
            flex: 2,
            child: Text(
              _currency(revenue),
              textAlign: TextAlign.right,
              style: const TextStyle(fontSize: 12),
            ),
          ),
          Expanded(
            flex: 2,
            child: Text(
              _currency(cost),
              textAlign: TextAlign.right,
              style: const TextStyle(fontSize: 12, color: Color(0xFF64748B)),
            ),
          ),
          Expanded(
            flex: 2,
            child: Text(
              _currency(profit),
              textAlign: TextAlign.right,
              style: const TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.bold,
                color: primaryGreen,
              ),
            ),
          ),
          SizedBox(
            width: 85,
            child: Center(
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                decoration: BoxDecoration(
                  color: const Color(0xFFCCFBF1),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Text(
                  '$marginPct%',
                  style: const TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF0D9488),
                  ),
                ),
              ),
            ),
          ),
          const SizedBox(width: 14),
          SizedBox(
            width: 44,
            child: Center(child: _buildInvoiceActionsMenu(inv)),
          ),
        ],
      ),
    );
  }

  Widget _buildPaymentBadge(String mode) {
    Color bg = const Color(0xFFDCFCE7);
    Color fg = const Color(0xFF16A34A);

    final m = mode.toLowerCase();
    if (m.contains('upi')) {
      bg = const Color(0xFFE0EDFF);
      fg = const Color(0xFF2563EB);
    } else if (m.contains('card')) {
      bg = const Color(0xFFF3E8FF);
      fg = const Color(0xFF9333EA);
    } else if (m.contains('bank')) {
      bg = const Color(0xFFFEF3C7);
      fg = const Color(0xFFD97706);
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(4),
      ),
      child: Text(
        mode,
        style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: fg),
      ),
    );
  }
}
