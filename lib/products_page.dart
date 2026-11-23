import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'app_toast.dart';
import 'api_service.dart';
import 'image_picker_helper.dart';
import 'product_image_widget.dart';
import 'slip_downloader.dart';

class ProductsPage extends StatefulWidget {
  final String token;
  final String? apiBaseUrl;

  const ProductsPage({super.key, required this.token, this.apiBaseUrl});

  @override
  State<ProductsPage> createState() => _ProductsPageState();
}

class _ProductsPageState extends State<ProductsPage> {
  late final ApiService _api;
  bool _isLoading = true;
  String? _errorMessage;

  List<dynamic> _products = [];
  List<dynamic> _categories = [];
  List<dynamic> _brands = [];

  String _searchQuery = '';
  String _barcodeQuery = '';
  String _selectedCategoryFilter = 'All';
  String _stockFilter = 'All'; // All, In Stock, Low Stock, Out of Stock
  final TextEditingController _searchCtrl = TextEditingController();
  final TextEditingController _barcodeCtrl = TextEditingController();

  static const Color sidebarBlue = Color(0xFF1E40AF);
  static const Color navyDark = Color(0xFF0F172A);
  static const Color darkGreen = Color(0xFF16A34A);
  static const Color background = Color(0xFFF8FAFC);
  static const Color cardBorder = Color(0xFFE2E8F0);

  @override
  void initState() {
    super.initState();
    _api = ApiService(token: widget.token, customBaseUrl: widget.apiBaseUrl);
    _loadData();
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    _barcodeCtrl.dispose();
    super.dispose();
  }

  Future<void> _loadData() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final results = await Future.wait([
        _api.get('/products'),
        _api.get('/categories'),
        _api.get('/brands'),
      ]);

      if (!mounted) return;

      setState(() {
        _products = results[0]['data'] is List ? results[0]['data'] : [];
        _categories = results[1]['data'] is List ? results[1]['data'] : [];
        _brands = results[2]['data'] is List ? results[2]['data'] : [];
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

  List<dynamic> get _filteredProducts {
    return _products.where((item) {
      final name = (item['product_name'] ?? '').toString().toLowerCase();
      final sku = _productBarcode(item).toLowerCase();
      final id = (item['id'] ?? '').toString().toLowerCase();
      final shade = (item['shade_name'] ?? '').toString().toLowerCase();
      final code = (item['shade_code'] ?? '').toString().toLowerCase();
      final cat = (item['category_name'] ?? '').toString().toLowerCase();
      final brand = (item['brand_name'] ?? '').toString().toLowerCase();
      final unit = (item['unit'] ?? '').toString().toLowerCase();

      final query = _searchQuery.trim().toLowerCase();
      final bQuery = _barcodeQuery.trim().toLowerCase();

      final matchesQuery = query.isEmpty ||
          name.contains(query) ||
          sku.contains(query) ||
          id.contains(query) ||
          shade.contains(query) ||
          code.contains(query) ||
          cat.contains(query) ||
          brand.contains(query) ||
          unit.contains(query);

      final matchesBarcode = bQuery.isEmpty || sku.contains(bQuery);

      final matchesCategory = _selectedCategoryFilter == 'All' ||
          (item['category_id']?.toString() == _selectedCategoryFilter);

      final stock = (item['stock_qty'] is num)
          ? (item['stock_qty'] as num).toDouble()
          : double.tryParse(item['stock_qty']?.toString() ?? '0') ?? 0;
      final reorder = (item['reorder_level'] is num)
          ? (item['reorder_level'] as num).toDouble()
          : double.tryParse(item['reorder_level']?.toString() ?? '0') ?? 0;

      bool matchesStock = true;
      if (_stockFilter == 'Out of Stock') {
        matchesStock = stock <= 0;
      } else if (_stockFilter == 'Low Stock') {
        matchesStock = stock > 0 && stock <= reorder;
      } else if (_stockFilter == 'In Stock') {
        matchesStock = stock > 0;
      }

      return matchesQuery && matchesBarcode && matchesCategory && matchesStock;
    }).toList();
  }

  void _clearFilters() {
    _searchCtrl.clear();
    _barcodeCtrl.clear();
    setState(() {
      _searchQuery = '';
      _barcodeQuery = '';
      _selectedCategoryFilter = 'All';
      _stockFilter = 'All';
    });
  }

  String _productBarcode(dynamic p) {
    final sku = (p['sku'] ?? '').toString().trim();
    if (sku.isNotEmpty) return sku;
    final id = (p['id'] ?? '1').toString().padLeft(3, '0');
    return 'PNT-$id';
  }

  String _categoryName(dynamic p) {
    final direct = (p['category_name'] ?? '').toString().trim();
    if (direct.isNotEmpty) return direct;
    final cid = p['category_id'];
    if (cid == null) return '-';
    for (final c in _categories) {
      if (c['id'] == cid) return (c['name'] ?? c['category_name'] ?? '-').toString();
    }
    return '-';
  }

  String _brandName(dynamic p) {
    final direct = (p['brand_name'] ?? '').toString().trim();
    if (direct.isNotEmpty) return direct;
    final bid = p['brand_id'];
    if (bid == null) return '-';
    for (final b in _brands) {
      if (b['id'] == bid) return (b['name'] ?? b['brand_name'] ?? '-').toString();
    }
    return '-';
  }

  String _currency(dynamic amount) {
    if (amount == null) return '₹0.00';
    final val = (amount is num)
        ? amount.toDouble()
        : double.tryParse(amount.toString()) ?? 0.0;
    return '₹${val.toStringAsFixed(val.truncateToDouble() == val ? 0 : 2)}';
  }

  // --- Generate Standard Retail Barcode ---
  String _generateUniqueBarcode() {
    final timeStr = DateTime.now().millisecondsSinceEpoch.toString();
    // 12-digit standard retail format: 890 (India country prefix) + 9 digits
    final randomDigits = timeStr.substring(timeStr.length - 9);
    return '890$randomDigits';
  }

  // --- Show Professional Barcode Price Sticker Dialog ---
  void _showBarcodeDialog(dynamic product) {
    final barcode = _productBarcode(product);
    final name = (product['product_name'] ?? 'Product').toString();
    final price = double.tryParse(product['selling_price']?.toString() ?? '0') ?? 0.0;
    final unit = (product['unit'] ?? 'Litre').toString();
    final brand = _brandName(product);
    final category = _categoryName(product);
    final batchNo = 'BT-${DateTime.now().year}-${(product['id'] ?? '101').toString().padLeft(3, '0')}';
    final pkdDate = '${DateTime.now().day}/${DateTime.now().month}/${DateTime.now().year}';

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        titlePadding: const EdgeInsets.fromLTRB(20, 18, 20, 8),
        contentPadding: const EdgeInsets.fromLTRB(20, 0, 20, 16),
        actionsPadding: const EdgeInsets.fromLTRB(20, 0, 20, 16),
        title: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            const Row(
              children: [
                Icon(Icons.qr_code_2_rounded, color: sidebarBlue, size: 24),
                SizedBox(width: 8),
                Text(
                  'Product Barcode & Price Tag',
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 17, color: navyDark),
                ),
              ],
            ),
            IconButton(
              icon: const Icon(Icons.close_rounded, size: 20, color: Color(0xFF64748B)),
              onPressed: () => Navigator.pop(ctx),
            ),
          ],
        ),
        content: SizedBox(
          width: 380,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // REALISTIC THERMAL ADHESIVE PRICE STICKER PREVIEW
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(18),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: const Color(0xFF94A3B8), width: 1.5),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.04),
                      blurRadius: 10,
                      offset: const Offset(0, 3),
                    ),
                  ],
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    // Shop Header
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Icon(Icons.format_paint_rounded, color: sidebarBlue, size: 16),
                        const SizedBox(width: 6),
                        Text(
                          'PAINT SHOP RETAIL',
                          style: TextStyle(
                            fontSize: 12.5,
                            fontWeight: FontWeight.w900,
                            letterSpacing: 1.2,
                            color: Colors.blue.shade900,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 2),
                    const Text(
                      'AUTHORIZED DEALER • GENUINE QUALITY',
                      style: TextStyle(fontSize: 9.5, letterSpacing: 0.8, color: Color(0xFF64748B), fontWeight: FontWeight.w600),
                    ),
                    const SizedBox(height: 10),
                    const Divider(height: 1, color: Color(0xFFCBD5E1)),
                    const SizedBox(height: 10),

                    // Product Name
                    Text(
                      name,
                      textAlign: TextAlign.center,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w800,
                        color: navyDark,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      '$brand  •  $category  •  $unit',
                      style: const TextStyle(fontSize: 11, color: Color(0xFF64748B), fontWeight: FontWeight.w500),
                    ),
                    const SizedBox(height: 12),

                    // VISUAL SHARP BARCODE WIDGET
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                      decoration: BoxDecoration(
                        color: const Color(0xFFF8FAFC),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: const Color(0xFFE2E8F0)),
                      ),
                      child: Column(
                        children: [
                          CustomPaint(
                            size: const Size(260, 52),
                            painter: BarcodePainter(data: barcode),
                          ),
                          const SizedBox(height: 6),
                          Text(
                            '* $barcode *',
                            style: const TextStyle(
                              fontFamily: 'monospace',
                              fontSize: 13,
                              fontWeight: FontWeight.w800,
                              letterSpacing: 3,
                              color: Colors.black,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 12),

                    // PRICE CONTAINER
                    Container(
                      padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 14),
                      decoration: BoxDecoration(
                        color: const Color(0xFFEFF6FF),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: const Color(0xFFBFDBFE)),
                      ),
                      child: Column(
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              const Text(
                                'MRP: ',
                                style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: Color(0xFF475569)),
                              ),
                              Text(
                                _currency(price),
                                style: const TextStyle(
                                  fontSize: 20,
                                  fontWeight: FontWeight.w900,
                                  color: sidebarBlue,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 2),
                          const Text(
                            '(Inclusive of all taxes)',
                            style: TextStyle(fontSize: 10, color: Color(0xFF64748B)),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 8),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text('Batch: $batchNo', style: const TextStyle(fontSize: 10, color: Color(0xFF94A3B8))),
                        Text('Pkd: $pkdDate', style: const TextStyle(fontSize: 10, color: Color(0xFF94A3B8))),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 12),
              const Text(
                'Ready to print on 50x30mm thermal sticker or standard sticker paper',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 11, color: Color(0xFF64748B)),
              ),
            ],
          ),
        ),
        actions: [
          OutlinedButton.icon(
            onPressed: () {
              Clipboard.setData(ClipboardData(text: barcode));
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text('Barcode $barcode copied to clipboard!'),
                  backgroundColor: darkGreen,
                ),
              );
            },
            icon: const Icon(Icons.copy_rounded, size: 16),
            label: const Text('Copy Barcode'),
            style: OutlinedButton.styleFrom(
              foregroundColor: navyDark,
              side: const BorderSide(color: cardBorder),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
            ),
          ),
          ElevatedButton.icon(
            onPressed: () async {
              final html = _buildPrintableBarcodeHtml(
                productName: name,
                barcode: barcode,
                brand: brand,
                category: category,
                unit: unit,
                price: price,
                batchNo: batchNo,
                pkdDate: pkdDate,
              );
              final fileName = 'Barcode_${barcode.replaceAll(RegExp(r'[^a-zA-Z0-9_-]'), '_')}.html';
              final ok = await downloadReceiptSlip(fileName: fileName, htmlContent: html);
              if (!mounted) return;
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text(ok ? 'Barcode label downloaded & ready to print!' : 'Print label preview loaded.'),
                  backgroundColor: ok ? darkGreen : Colors.orange,
                ),
              );
            },
            icon: const Icon(Icons.print_rounded, size: 16),
            label: const Text('Print Label'),
            style: ElevatedButton.styleFrom(
              backgroundColor: sidebarBlue,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
            ),
          ),
        ],
      ),
    );
  }

  String _buildPrintableBarcodeHtml({
    required String productName,
    required String barcode,
    required String brand,
    required String category,
    required String unit,
    required double price,
    required String batchNo,
    required String pkdDate,
  }) {
    return '''<!DOCTYPE html>
<html>
<head>
  <meta charset="utf-8">
  <title>Barcode Sticker - $barcode</title>
  <style>
    * { box-sizing: border-box; }
    body {
      margin: 0;
      padding: 24px;
      font-family: -apple-system, BlinkMacSystemFont, "Segoe UI", Roboto, Helvetica, Arial, sans-serif;
      background: #f1f5f9;
      display: flex;
      flex-direction: column;
      align-items: center;
    }
    .sticker {
      width: 320px;
      background: #fff;
      border: 2px dashed #94a3b8;
      border-radius: 10px;
      padding: 16px 14px;
      text-align: center;
      box-shadow: 0 4px 12px rgba(0,0,0,0.06);
    }
    .shop-name {
      font-size: 13px;
      font-weight: 900;
      letter-spacing: 1.5px;
      color: #1e3a8a;
      text-transform: uppercase;
      margin: 0 0 2px 0;
    }
    .shop-sub {
      font-size: 9px;
      letter-spacing: 0.8px;
      color: #64748b;
      font-weight: 600;
      margin-bottom: 8px;
    }
    .divider {
      border-top: 1px dashed #cbd5e1;
      margin: 8px 0;
    }
    .prod-name {
      font-size: 14.5px;
      font-weight: 800;
      color: #0f172a;
      margin: 0 0 3px 0;
    }
    .prod-meta {
      font-size: 11px;
      color: #64748b;
      margin-bottom: 8px;
    }
    .barcode-box {
      background: #fafafa;
      padding: 8px 12px;
      border-radius: 6px;
      border: 1px solid #e2e8f0;
      margin: 6px 0;
    }
    .barcode-lines {
      display: flex;
      justify-content: center;
      align-items: flex-end;
      height: 48px;
      gap: 2px;
      margin: 0 auto;
    }
    .bar {
      background: #000;
      height: 100%;
    }
    .barcode-code {
      font-family: "Courier New", Courier, monospace;
      font-size: 13px;
      font-weight: 800;
      letter-spacing: 3px;
      color: #000;
      margin-top: 5px;
    }
    .price-box {
      background: #eff6ff;
      border: 1px solid #bfdbfe;
      border-radius: 6px;
      padding: 6px;
      margin-top: 8px;
    }
    .mrp {
      font-size: 18px;
      font-weight: 900;
      color: #1e40af;
    }
    .tax {
      font-size: 9.5px;
      color: #64748b;
    }
    .footer-meta {
      display: flex;
      justify-content: space-between;
      font-size: 9px;
      color: #94a3b8;
      margin-top: 6px;
    }
    .print-btn-bar {
      margin-top: 18px;
    }
    .print-btn {
      background: #1e40af;
      color: #fff;
      border: none;
      padding: 10px 22px;
      font-size: 14px;
      font-weight: 700;
      border-radius: 8px;
      cursor: pointer;
    }
    @media print {
      body { background: #fff; padding: 0; }
      .print-btn-bar { display: none; }
      .sticker { border: 1px solid #000; box-shadow: none; margin: 0 auto; }
      @page { size: auto; margin: 0; }
    }
  </style>
</head>
<body>
  <div class="sticker">
    <div class="shop-name">PAINT SHOP RETAIL</div>
    <div class="shop-sub">AUTHORIZED DEALER &bull; GENUINE PRODUCT</div>
    <div class="divider"></div>
    <div class="prod-name">$productName</div>
    <div class="prod-meta">$brand &bull; $category &bull; $unit</div>
    <div class="barcode-box">
      <div class="barcode-lines">
        <div class="bar" style="width: 3px;"></div>
        <div class="bar" style="width: 1px;"></div>
        <div class="bar" style="width: 2px;"></div>
        <div class="bar" style="width: 4px;"></div>
        <div class="bar" style="width: 1px;"></div>
        <div class="bar" style="width: 3px;"></div>
        <div class="bar" style="width: 2px;"></div>
        <div class="bar" style="width: 1px;"></div>
        <div class="bar" style="width: 4px;"></div>
        <div class="bar" style="width: 2px;"></div>
        <div class="bar" style="width: 3px;"></div>
        <div class="bar" style="width: 1px;"></div>
        <div class="bar" style="width: 2px;"></div>
        <div class="bar" style="width: 4px;"></div>
        <div class="bar" style="width: 2px;"></div>
        <div class="bar" style="width: 3px;"></div>
        <div class="bar" style="width: 1px;"></div>
        <div class="bar" style="width: 2px;"></div>
        <div class="bar" style="width: 4px;"></div>
        <div class="bar" style="width: 2px;"></div>
      </div>
      <div class="barcode-code">* $barcode *</div>
    </div>
    <div class="price-box">
      <div class="mrp">MRP: &#8377; ${price.toStringAsFixed(2)}</div>
      <div class="tax">(Inclusive of all taxes)</div>
    </div>
    <div class="footer-meta">
      <span>Batch: $batchNo</span>
      <span>Pkd: $pkdDate</span>
    </div>
  </div>

  <div class="print-btn-bar">
    <button class="print-btn" onclick="window.print()">Print Barcode Sticker</button>
  </div>
</body>
</html>''';
  }

  // --- Add / Edit Product Modal (with ⚡ Auto-Generate Barcode & Live Profit Calculator) ---
  void _showProductDialog({Map<String, dynamic>? product}) {
    final isEditing = product != null;
    final nameCtrl = TextEditingController(text: product?['product_name']?.toString() ?? '');
    final productIdCtrl = TextEditingController(text: product?['id']?.toString() ?? '');
    final skuCtrl = TextEditingController(
      text: product?['sku']?.toString() ?? (isEditing ? '' : _generateUniqueBarcode()),
    );
    final shadeCodeCtrl = TextEditingController(text: product?['shade_code']?.toString() ?? '');
    final shadeNameCtrl = TextEditingController(text: product?['shade_name']?.toString() ?? '');
    final packSizeCtrl = TextEditingController(text: product?['pack_size']?.toString() ?? '1L');
    final unitCtrl = TextEditingController(text: product?['unit']?.toString() ?? 'Litre');
    final costCtrl = TextEditingController(text: product?['cost_price']?.toString() ?? '');
    final sellingCtrl = TextEditingController(text: product?['selling_price']?.toString() ?? '');
    final stockCtrl = TextEditingController(text: product?['stock_qty']?.toString() ?? '0');
    final reorderCtrl = TextEditingController(text: product?['reorder_level']?.toString() ?? '5');
    final gstCtrl = TextEditingController(text: '18');
    final descCtrl = TextEditingController(text: product?['description']?.toString() ?? '');

    String initialCategory = '';
    if (product?['category_name'] != null && product!['category_name'].toString().trim().isNotEmpty) {
      initialCategory = product['category_name'].toString().trim();
    } else if (product?['category_id'] != null) {
      final cid = product!['category_id'];
      for (final c in _categories) {
        if (c['id'] == cid) {
          initialCategory = (c['name'] ?? c['category_name'] ?? '').toString();
          break;
        }
      }
    }
    final categoryCtrl = TextEditingController(text: initialCategory);

    String initialBrand = '';
    if (product?['brand_name'] != null && product!['brand_name'].toString().trim().isNotEmpty) {
      initialBrand = product['brand_name'].toString().trim();
    } else if (product?['brand_id'] != null) {
      final bid = product!['brand_id'];
      for (final b in _brands) {
        if (b['id'] == bid) {
          initialBrand = (b['name'] ?? b['brand_name'] ?? '').toString();
          break;
        }
      }
    }
    final brandCtrl = TextEditingController(text: initialBrand);

    String? currentImageUrl = product?['image_url']?.toString();
    bool isPickingImage = false;
    bool isSaving = false;

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (dialogCtx) => StatefulBuilder(
        builder: (ctx, setDialogState) {
          final isNarrow = MediaQuery.sizeOf(ctx).width < 700;

          final costVal = double.tryParse(costCtrl.text.trim()) ?? 0.0;
          final sellingVal = double.tryParse(sellingCtrl.text.trim()) ?? 0.0;
          final profitVal = sellingVal - costVal;
          final marginPct = costVal > 0 ? ((profitVal / costVal) * 100) : 0.0;

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
            hintStyle: const TextStyle(fontSize: 12.5, color: Color(0xFF94A3B8)),
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
            contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 11),
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

          Widget stepBadge(String number, String title, {Widget? badge, String? subtitle}) {
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
                if (badge != null) ...[
                  const SizedBox(width: 8),
                  badge,
                ],
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

          final hasImage = currentImageUrl != null && currentImageUrl!.isNotEmpty;

          final uploadImageBox = Container(
            width: isNarrow ? double.infinity : 130,
            height: isNarrow ? 110 : 130,
            decoration: BoxDecoration(
              color: const Color(0xFFF8FAFC),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: hasImage ? sidebarBlue.withValues(alpha: 0.5) : const Color(0xFFCBD5E1),
                width: hasImage ? 1.5 : 1,
              ),
            ),
            child: InkWell(
              borderRadius: BorderRadius.circular(12),
              onTap: isPickingImage
                  ? null
                  : () async {
                      setDialogState(() => isPickingImage = true);
                      try {
                        final picked = await pickProductImageAsDataUrl();
                        if (picked != null && picked.isNotEmpty) {
                          setDialogState(() {
                            currentImageUrl = picked;
                            isPickingImage = false;
                          });
                        } else {
                          setDialogState(() => isPickingImage = false);
                        }
                      } catch (_) {
                        setDialogState(() => isPickingImage = false);
                      }
                    },
              child: hasImage
                  ? Stack(
                      children: [
                        Positioned.fill(
                          child: ProductImageWidget(
                            imageUrl: currentImageUrl,
                            fit: BoxFit.cover,
                            borderRadius: BorderRadius.circular(11),
                          ),
                        ),
                        Positioned(
                          bottom: 0,
                          left: 0,
                          right: 0,
                          child: Container(
                            padding: const EdgeInsets.symmetric(vertical: 4),
                            decoration: BoxDecoration(
                              color: Colors.black.withValues(alpha: 0.7),
                              borderRadius: const BorderRadius.only(
                                bottomLeft: Radius.circular(11),
                                bottomRight: Radius.circular(11),
                              ),
                            ),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                const Icon(Icons.edit_rounded, size: 12, color: Colors.white),
                                const SizedBox(width: 4),
                                const Text(
                                  'Change',
                                  style: TextStyle(fontSize: 10, color: Colors.white, fontWeight: FontWeight.w600),
                                ),
                                const SizedBox(width: 10),
                                InkWell(
                                  onTap: () {
                                    setDialogState(() => currentImageUrl = null);
                                  },
                                  child: const Icon(Icons.close_rounded, size: 14, color: Colors.white),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ],
                    )
                  : Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        if (isPickingImage)
                          const SizedBox(
                            width: 24,
                            height: 24,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        else ...[
                          const Icon(Icons.add_a_photo_outlined, size: 28, color: sidebarBlue),
                          const SizedBox(height: 6),
                          const Text(
                            'Upload Photo',
                            style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.w700, color: sidebarBlue),
                          ),
                          const SizedBox(height: 2),
                          const Text(
                            'JPG, PNG supported',
                            style: TextStyle(fontSize: 10, color: Color(0xFF64748B)),
                          ),
                        ],
                      ],
                    ),
            ),
          );

          return Dialog(
            backgroundColor: Colors.white,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            insetPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 20),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 800),
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
                            Icons.palette_rounded,
                            color: sidebarBlue,
                            size: 22,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                isEditing ? 'Edit Product Details' : 'Add New Paint Product',
                                style: const TextStyle(
                                  fontSize: 19,
                                  fontWeight: FontWeight.w800,
                                  color: navyDark,
                                  letterSpacing: -0.3,
                                ),
                              ),
                              const SizedBox(height: 2),
                              const Text(
                                'Manage product specifications, barcodes, category, pricing, and initial stock.',
                                style: TextStyle(
                                  fontSize: 12,
                                  color: Color(0xFF64748B),
                                ),
                              ),
                            ],
                          ),
                        ),
                        IconButton(
                          onPressed: isSaving ? null : () => Navigator.pop(dialogCtx),
                          icon: const Icon(Icons.close_rounded, color: Color(0xFF64748B)),
                          tooltip: 'Close',
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),

                    // TOP HERO CARD: IMAGE & BARCODE IDENTIFIERS
                    Container(
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        color: const Color(0xFFF8FAFC),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: const Color(0xFFE2E8F0)),
                      ),
                      child: isNarrow
                          ? Column(
                              children: [
                                uploadImageBox,
                                const SizedBox(height: 12),
                                fieldBox(
                                  label: 'Barcode / SKU',
                                  isRequired: true,
                                  child: TextField(
                                    controller: skuCtrl,
                                    decoration: inputDec(
                                      hint: 'Barcode / SKU',
                                      prefixIcon: const Icon(Icons.qr_code_2_rounded, size: 18, color: sidebarBlue),
                                      suffixIcon: TextButton.icon(
                                        onPressed: () {
                                          setDialogState(() {
                                            skuCtrl.text = _generateUniqueBarcode();
                                          });
                                        },
                                        icon: const Icon(Icons.bolt_rounded, size: 16, color: sidebarBlue),
                                        label: const Text(
                                          'Generate',
                                          style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: sidebarBlue),
                                        ),
                                      ),
                                    ),
                                  ),
                                ),
                              ],
                            )
                          : Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                uploadImageBox,
                                const SizedBox(width: 14),
                                Expanded(
                                  child: Column(
                                    children: [
                                      Row(
                                        children: [
                                          Expanded(
                                            flex: 3,
                                            child: fieldBox(
                                              label: 'Barcode / SKU',
                                              isRequired: true,
                                              child: TextField(
                                                controller: skuCtrl,
                                                decoration: inputDec(
                                                  hint: 'Scan or enter barcode',
                                                  prefixIcon: const Icon(Icons.qr_code_2_rounded, size: 18, color: sidebarBlue),
                                                  suffixIcon: InkWell(
                                                    onTap: () {
                                                      setDialogState(() {
                                                        skuCtrl.text = _generateUniqueBarcode();
                                                      });
                                                    },
                                                    borderRadius: BorderRadius.circular(6),
                                                    child: Container(
                                                      margin: const EdgeInsets.symmetric(horizontal: 6, vertical: 6),
                                                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                                      decoration: BoxDecoration(
                                                        color: const Color(0xFFEFF6FF),
                                                        borderRadius: BorderRadius.circular(6),
                                                        border: Border.all(color: const Color(0xFFBFDBFE)),
                                                      ),
                                                      child: const Row(
                                                        mainAxisSize: MainAxisSize.min,
                                                        children: [
                                                          Icon(Icons.bolt_rounded, size: 14, color: sidebarBlue),
                                                          SizedBox(width: 2),
                                                          Text(
                                                            'Generate',
                                                            style: TextStyle(
                                                              fontSize: 11,
                                                              fontWeight: FontWeight.bold,
                                                              color: sidebarBlue,
                                                            ),
                                                          ),
                                                        ],
                                                      ),
                                                    ),
                                                  ),
                                                ),
                                              ),
                                            ),
                                          ),
                                          const SizedBox(width: 10),
                                          Expanded(
                                            flex: 1,
                                            child: fieldBox(
                                              label: 'Product ID',
                                              child: TextField(
                                                controller: productIdCtrl,
                                                readOnly: isEditing,
                                                decoration: inputDec(
                                                  hint: 'Auto',
                                                  prefixIcon: const Icon(Icons.tag_rounded, size: 18, color: Color(0xFF64748B)),
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
                                            child: fieldBox(
                                              label: 'Shade Code (Optional)',
                                              child: TextField(
                                                controller: shadeCodeCtrl,
                                                decoration: inputDec(
                                                  hint: 'Enter shade code',
                                                  prefixIcon: const Icon(Icons.color_lens_outlined, size: 18, color: Color(0xFF64748B)),
                                                ),
                                              ),
                                            ),
                                          ),
                                          const SizedBox(width: 10),
                                          Expanded(
                                            child: fieldBox(
                                              label: 'Shade Name (Optional)',
                                              child: TextField(
                                                controller: shadeNameCtrl,
                                                decoration: inputDec(
                                                  hint: 'Enter shade name',
                                                  prefixIcon: const Icon(Icons.format_paint_outlined, size: 18, color: Color(0xFF64748B)),
                                                ),
                                              ),
                                            ),
                                          ),
                                        ],
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                    ),

                    const SizedBox(height: 14),

                    // 1. PRODUCT CLASSIFICATION
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
                          stepBadge('1', 'Product Classification & Name'),
                          const SizedBox(height: 12),
                          fieldBox(
                            label: 'Product Name',
                            isRequired: true,
                            child: TextField(
                              controller: nameCtrl,
                              decoration: inputDec(
                                hint: 'Enter product name',
                                prefixIcon: const Icon(Icons.inventory_2_outlined, size: 18, color: sidebarBlue),
                              ),
                            ),
                          ),
                          const SizedBox(height: 10),
                          Row(
                            children: [
                              Expanded(
                                flex: 2,
                                child: fieldBox(
                                  label: 'Category',
                                  isRequired: true,
                                  child: TextField(
                                    controller: categoryCtrl,
                                    decoration: inputDec(
                                      hint: 'Select or enter category',
                                      prefixIcon: const Icon(Icons.category_outlined, size: 18, color: sidebarBlue),
                                      suffixIcon: _categories.isNotEmpty
                                          ? PopupMenuButton<String>(
                                              icon: const Icon(Icons.arrow_drop_down_circle_outlined, size: 18, color: sidebarBlue),
                                              tooltip: 'Select Category',
                                              onSelected: (val) {
                                                setDialogState(() => categoryCtrl.text = val);
                                              },
                                              itemBuilder: (ctx) => _categories
                                                  .map((c) => PopupMenuItem<String>(
                                                        value: (c['name'] ?? c['category_name'] ?? '').toString(),
                                                        child: Text((c['name'] ?? c['category_name'] ?? '').toString()),
                                                      ))
                                                  .toList(),
                                            )
                                          : null,
                                    ),
                                  ),
                                ),
                              ),
                              const SizedBox(width: 10),
                              Expanded(
                                flex: 2,
                                child: fieldBox(
                                  label: 'Brand',
                                  isRequired: true,
                                  child: TextField(
                                    controller: brandCtrl,
                                    decoration: inputDec(
                                      hint: 'Select or enter brand',
                                      prefixIcon: const Icon(Icons.branding_watermark_outlined, size: 18, color: sidebarBlue),
                                      suffixIcon: _brands.isNotEmpty
                                          ? PopupMenuButton<String>(
                                              icon: const Icon(Icons.arrow_drop_down_circle_outlined, size: 18, color: sidebarBlue),
                                              tooltip: 'Select Brand',
                                              onSelected: (val) {
                                                setDialogState(() => brandCtrl.text = val);
                                              },
                                              itemBuilder: (ctx) => _brands
                                                  .map((b) => PopupMenuItem<String>(
                                                        value: (b['name'] ?? b['brand_name'] ?? '').toString(),
                                                        child: Text((b['name'] ?? b['brand_name'] ?? '').toString()),
                                                      ))
                                                  .toList(),
                                            )
                                          : null,
                                    ),
                                  ),
                                ),
                              ),
                              const SizedBox(width: 10),
                              Expanded(
                                flex: 1,
                                child: fieldBox(
                                  label: 'Unit',
                                  isRequired: true,
                                  child: TextField(
                                    controller: unitCtrl,
                                    decoration: inputDec(
                                      hint: 'Litre',
                                      prefixIcon: const Icon(Icons.straighten_rounded, size: 18, color: Color(0xFF64748B)),
                                      suffixIcon: PopupMenuButton<String>(
                                        icon: const Icon(Icons.arrow_drop_down, size: 20, color: Color(0xFF64748B)),
                                        tooltip: 'Select Unit',
                                        onSelected: (u) => setDialogState(() => unitCtrl.text = u),
                                        itemBuilder: (_) => ['Litre', 'Kg', 'Tin', 'Bucket', 'Can', 'Pieces (Pcs)', 'Box', 'Set']
                                            .map((u) => PopupMenuItem(value: u, child: Text(u)))
                                            .toList(),
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),

                    const SizedBox(height: 14),

                    // 2. PRICING & PROFITABILITY (WITH LIVE MARGIN CALCULATOR)
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
                          stepBadge('2', 'Pricing & Live Profit Margin'),
                          const SizedBox(height: 12),
                          Row(
                            children: [
                              Expanded(
                                child: fieldBox(
                                  label: 'Purchase Cost Price (₹)',
                                  isRequired: true,
                                  child: TextField(
                                    controller: costCtrl,
                                    keyboardType: const TextInputType.numberWithOptions(decimal: true),
                                    onChanged: (_) => setDialogState(() {}),
                                    decoration: inputDec(
                                      hint: '0.00',
                                      prefixIcon: const Icon(Icons.currency_rupee_rounded, size: 18, color: sidebarBlue),
                                    ),
                                  ),
                                ),
                              ),
                              const SizedBox(width: 10),
                              Expanded(
                                child: fieldBox(
                                  label: 'Selling Price (₹)',
                                  isRequired: true,
                                  child: TextField(
                                    controller: sellingCtrl,
                                    keyboardType: const TextInputType.numberWithOptions(decimal: true),
                                    onChanged: (_) => setDialogState(() {}),
                                    decoration: inputDec(
                                      hint: '0.00',
                                      prefixIcon: const Icon(Icons.sell_outlined, size: 18, color: darkGreen),
                                    ),
                                  ),
                                ),
                              ),
                              const SizedBox(width: 10),
                              Expanded(
                                child: fieldBox(
                                  label: 'Applicable GST %',
                                  child: TextField(
                                    controller: gstCtrl,
                                    keyboardType: const TextInputType.numberWithOptions(decimal: true),
                                    decoration: inputDec(
                                      hint: '18',
                                      prefixIcon: const Icon(Icons.percent_rounded, size: 18, color: Color(0xFF64748B)),
                                    ),
                                  ),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 12),

                          // LIVE PROFIT CARD
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
                            decoration: BoxDecoration(
                              color: profitVal >= 0 ? const Color(0xFFF0FDF4) : const Color(0xFFFEF2F2),
                              borderRadius: BorderRadius.circular(10),
                              border: Border.all(
                                color: profitVal >= 0 ? const Color(0xFFBBF7D0) : const Color(0xFFFECACA),
                              ),
                            ),
                            child: Row(
                              children: [
                                Icon(
                                  profitVal >= 0 ? Icons.trending_up_rounded : Icons.trending_down_rounded,
                                  color: profitVal >= 0 ? darkGreen : Colors.red,
                                  size: 20,
                                ),
                                const SizedBox(width: 10),
                                Expanded(
                                  child: Text(
                                    profitVal >= 0
                                        ? 'Estimated Gross Profit: ${_currency(profitVal)} per unit (${marginPct.toStringAsFixed(1)}% Markup)'
                                        : 'Warning: Selling price is lower than cost price (Loss: ${_currency(profitVal.abs())})',
                                    style: TextStyle(
                                      fontSize: 12.5,
                                      fontWeight: FontWeight.w700,
                                      color: profitVal >= 0 ? const Color(0xFF166534) : const Color(0xFF991B1B),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),

                    const SizedBox(height: 14),

                    // 3. INVENTORY & WAREHOUSE SETTINGS
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
                          stepBadge('3', 'Stock Levels & Warehouse Notes'),
                          const SizedBox(height: 12),
                          Row(
                            children: [
                              Expanded(
                                child: fieldBox(
                                  label: 'Opening Stock Quantity',
                                  isRequired: true,
                                  child: TextField(
                                    controller: stockCtrl,
                                    keyboardType: const TextInputType.numberWithOptions(decimal: true),
                                    decoration: inputDec(
                                      hint: '0',
                                      prefixIcon: const Icon(Icons.warehouse_outlined, size: 18, color: sidebarBlue),
                                    ),
                                  ),
                                ),
                              ),
                              const SizedBox(width: 10),
                              Expanded(
                                child: fieldBox(
                                  label: 'Low Stock Alert Level',
                                  child: TextField(
                                    controller: reorderCtrl,
                                    keyboardType: const TextInputType.numberWithOptions(decimal: true),
                                    decoration: inputDec(
                                      hint: '5',
                                      prefixIcon: const Icon(Icons.notifications_active_outlined, size: 18, color: Color(0xFF64748B)),
                                    ),
                                  ),
                                ),
                              ),
                              const SizedBox(width: 10),
                              Expanded(
                                child: fieldBox(
                                  label: 'Pack Size',
                                  child: TextField(
                                    controller: packSizeCtrl,
                                    decoration: inputDec(
                                      hint: '1L, 4L, 20L',
                                      prefixIcon: const Icon(Icons.aspect_ratio_rounded, size: 18, color: Color(0xFF64748B)),
                                    ),
                                  ),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 10),
                          fieldBox(
                            label: 'Description / Surface Details',
                            child: TextField(
                              controller: descCtrl,
                              maxLines: 2,
                              decoration: inputDec(
                                hint: 'Optional paint notes (finish, surface, formula, etc.)',
                                prefixIcon: const Icon(Icons.notes_rounded, size: 18, color: Color(0xFF64748B)),
                              ),
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
                          onPressed: isSaving ? null : () => Navigator.pop(dialogCtx),
                          style: OutlinedButton.styleFrom(
                            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 13),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(9)),
                            side: const BorderSide(color: Color(0xFFCBD5E1)),
                          ),
                          child: const Text(
                            'Cancel',
                            style: TextStyle(color: Color(0xFF475569), fontWeight: FontWeight.w600),
                          ),
                        ),
                        const SizedBox(width: 12),
                        ElevatedButton.icon(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: sidebarBlue,
                            foregroundColor: Colors.white,
                            elevation: 1,
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(9)),
                            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 13),
                          ),
                          onPressed: isSaving
                              ? null
                              : () async {
                                  final name = nameCtrl.text.trim();
                                  if (name.isEmpty) {
                                    AppToast.showWarning(
                                      context,
                                      title: 'Product Name Required',
                                      message: 'Please enter a name for the product.',
                                    );
                                    return;
                                  }

                                  setDialogState(() => isSaving = true);
                                  final barcodeVal = skuCtrl.text.trim().isEmpty ? _generateUniqueBarcode() : skuCtrl.text.trim();

                                  int? finalCategoryId;
                                  final catName = categoryCtrl.text.trim();
                                  if (catName.isNotEmpty) {
                                    final match = _categories.cast<Map<String, dynamic>?>().firstWhere(
                                      (c) => (c?['name'] ?? c?['category_name'] ?? '').toString().trim().toLowerCase() == catName.toLowerCase(),
                                      orElse: () => null,
                                    );
                                    if (match != null && match['id'] != null) {
                                      finalCategoryId = int.tryParse(match['id'].toString());
                                    } else {
                                      try {
                                        final res = await _api.post('/categories', {
                                          'name': catName,
                                          'description': 'Created automatically via Product modal',
                                        });
                                        if (res is Map && res['id'] != null) {
                                          finalCategoryId = int.tryParse(res['id'].toString());
                                          _categories.add({'id': finalCategoryId, 'name': catName});
                                        }
                                      } catch (_) {}
                                    }
                                  }

                                  int? finalBrandId;
                                  final brandName = brandCtrl.text.trim();
                                  if (brandName.isNotEmpty) {
                                    final match = _brands.cast<Map<String, dynamic>?>().firstWhere(
                                      (b) => (b?['name'] ?? b?['brand_name'] ?? '').toString().trim().toLowerCase() == brandName.toLowerCase(),
                                      orElse: () => null,
                                    );
                                    if (match != null && match['id'] != null) {
                                      finalBrandId = int.tryParse(match['id'].toString());
                                    } else {
                                      try {
                                        final res = await _api.post('/brands', {
                                          'name': brandName,
                                          'description': 'Created automatically via Product modal',
                                        });
                                        if (res is Map && res['id'] != null) {
                                          finalBrandId = int.tryParse(res['id'].toString());
                                          _brands.add({'id': finalBrandId, 'name': brandName});
                                        }
                                      } catch (_) {}
                                    }
                                  }

                                  final payload = {
                                    'product_name': name,
                                    'sku': barcodeVal,
                                    'category_id': finalCategoryId,
                                    'brand_id': finalBrandId,
                                    'shade_code': shadeCodeCtrl.text.trim(),
                                    'shade_name': shadeNameCtrl.text.trim(),
                                    'pack_size': packSizeCtrl.text.trim().isEmpty ? '1L' : packSizeCtrl.text.trim(),
                                    'unit': unitCtrl.text.trim().isEmpty ? 'Litre' : unitCtrl.text.trim(),
                                    'cost_price': double.tryParse(costCtrl.text.trim()) ?? 0,
                                    'selling_price': double.tryParse(sellingCtrl.text.trim()) ?? 0,
                                    'stock_qty': double.tryParse(stockCtrl.text.trim()) ?? 0,
                                    'reorder_level': int.tryParse(reorderCtrl.text.trim()) ?? (product?['reorder_level'] ?? 5),
                                    'description': descCtrl.text.trim(),
                                    'image_url': currentImageUrl ?? '',
                                  };

                                  try {
                                    if (isEditing) {
                                      await _api.put('/products/${product['id']}', payload);
                                    } else {
                                      await _api.post('/products', payload);
                                    }
                                    if (!dialogCtx.mounted) return;
                                    Navigator.pop(dialogCtx);
                                    if (!mounted) return;
                                    AppToast.showSuccess(
                                      context,
                                      title: isEditing ? 'Product Updated!' : 'Product Created!',
                                      message: isEditing
                                          ? '$name details updated successfully.'
                                          : '$name created successfully with barcode $barcodeVal.',
                                    );
                                    _loadData();
                                  } catch (e) {
                                    setDialogState(() => isSaving = false);
                                    if (!mounted) return;
                                    AppToast.showError(
                                      context,
                                      title: isEditing ? 'Update Failed' : 'Save Failed',
                                      message: e.toString().replaceAll('Exception: ', ''),
                                    );
                                  }
                                },
                          icon: isSaving
                              ? const SizedBox(
                                  width: 18,
                                  height: 18,
                                  child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                                )
                              : const Icon(Icons.check_circle_rounded, size: 19),
                          label: Text(
                            isSaving
                                ? 'Saving...'
                                : (isEditing ? 'Update Product' : 'Save Product & Barcode'),
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

  Future<void> _deleteProduct(dynamic product) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        title: const Text('Delete Product', style: TextStyle(fontWeight: FontWeight.bold, color: Colors.black)),
        content: Text('Are you sure you want to delete "${product['product_name']}"?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel', style: TextStyle(color: Colors.grey))),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red, foregroundColor: Colors.white),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );

    if (confirm != true) return;

    try {
      await _api.delete('/products/${product['id']}');
      if (mounted) {
        AppToast.showSuccess(
          context,
          title: 'Product Deleted',
          message: 'Product "${product['product_name'] ?? ''}" removed successfully.',
        );
        _loadData();
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
    final isCompactFilter = width < 960;

    return Container(
      color: background,
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(20, 18, 20, 30),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // 1. TOP HEADER (Products / Manage your product catalog + Add Product)
            Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                const Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Products & Inventory',
                        style: TextStyle(fontSize: 24, fontWeight: FontWeight.w800, color: navyDark),
                      ),
                      SizedBox(height: 2),
                      Text(
                        'Manage paint catalog, pricing, and retail barcodes',
                        style: TextStyle(fontSize: 13, color: Color(0xFF64748B)),
                      ),
                    ],
                  ),
                ),
                ElevatedButton.icon(
                  onPressed: () => _showProductDialog(),
                  icon: const Icon(Icons.add_rounded, size: 18),
                  label: const Text('Add Product', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700)),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: sidebarBlue,
                    foregroundColor: Colors.white,
                    elevation: 0,
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),

            // 2. FILTER & BARCODE QUICK LOOKUP CARD
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: cardBorder),
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
                        hintText: 'Search by Name, ID, or SKU...',
                        hintStyle: const TextStyle(color: Color(0xFF94A3B8), fontSize: 12),
                        prefixIcon: const Icon(Icons.search_rounded, size: 18, color: Color(0xFF64748B)),
                        filled: true,
                        fillColor: const Color(0xFFF8FAFC),
                        isDense: true,
                        contentPadding: const EdgeInsets.symmetric(vertical: 10, horizontal: 12),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(8),
                          borderSide: const BorderSide(color: cardBorder),
                        ),
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(8),
                          borderSide: const BorderSide(color: cardBorder),
                        ),
                      ),
                    ),
                  );

                  final barcodeScanField = SizedBox(
                    height: 40,
                    child: TextField(
                      controller: _barcodeCtrl,
                      onChanged: (val) => setState(() => _barcodeQuery = val),
                      style: const TextStyle(color: navyDark, fontSize: 13, fontFamily: 'monospace', fontWeight: FontWeight.w600),
                      decoration: InputDecoration(
                        hintText: 'Scan Barcode / SKU...',
                        hintStyle: const TextStyle(color: Color(0xFF94A3B8), fontSize: 12, fontFamily: 'sans-serif'),
                        prefixIcon: const Icon(Icons.qr_code_scanner_rounded, size: 18, color: sidebarBlue),
                        suffixIcon: _barcodeQuery.isNotEmpty
                            ? IconButton(
                                icon: const Icon(Icons.clear, size: 16, color: Color(0xFF94A3B8)),
                                onPressed: () {
                                  _barcodeCtrl.clear();
                                  setState(() => _barcodeQuery = '');
                                },
                              )
                            : null,
                        filled: true,
                        fillColor: const Color(0xFFEFF6FF),
                        isDense: true,
                        contentPadding: const EdgeInsets.symmetric(vertical: 10, horizontal: 12),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(8),
                          borderSide: const BorderSide(color: Color(0xFFBFDBFE)),
                        ),
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(8),
                          borderSide: const BorderSide(color: Color(0xFFBFDBFE)),
                        ),
                      ),
                    ),
                  );

                  final categoryDropdown = SizedBox(
                    height: 40,
                    child: DropdownButtonFormField<String>(
                      initialValue: _selectedCategoryFilter,
                      isExpanded: true,
                      decoration: InputDecoration(
                        filled: true,
                        fillColor: const Color(0xFFF8FAFC),
                        isDense: true,
                        contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(8),
                          borderSide: const BorderSide(color: cardBorder),
                        ),
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(8),
                          borderSide: const BorderSide(color: cardBorder),
                        ),
                      ),
                      style: const TextStyle(color: navyDark, fontSize: 13),
                      items: [
                        const DropdownMenuItem(value: 'All', child: Text('All Categories')),
                        ..._categories.map(
                          (c) => DropdownMenuItem(
                            value: c['id'].toString(),
                            child: Text((c['name'] ?? c['category_name'] ?? 'Category').toString()),
                          ),
                        ),
                      ],
                      onChanged: (val) {
                        if (val != null) setState(() => _selectedCategoryFilter = val);
                      },
                    ),
                  );

                  final stockDropdown = SizedBox(
                    height: 40,
                    child: DropdownButtonFormField<String>(
                      initialValue: _stockFilter,
                      isExpanded: true,
                      decoration: InputDecoration(
                        filled: true,
                        fillColor: const Color(0xFFF8FAFC),
                        isDense: true,
                        contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(8),
                          borderSide: const BorderSide(color: cardBorder),
                        ),
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(8),
                          borderSide: const BorderSide(color: cardBorder),
                        ),
                      ),
                      style: const TextStyle(color: navyDark, fontSize: 13),
                      items: const [
                        DropdownMenuItem(value: 'All', child: Text('All Stock Status')),
                        DropdownMenuItem(value: 'In Stock', child: Text('In Stock')),
                        DropdownMenuItem(value: 'Low Stock', child: Text('Low Stock')),
                        DropdownMenuItem(value: 'Out of Stock', child: Text('Out of Stock')),
                      ],
                      onChanged: (val) {
                        if (val != null) setState(() => _stockFilter = val);
                      },
                    ),
                  );

                  final clearBtn = SizedBox(
                    height: 40,
                    width: 40, // Match height to make it a perfect square box
                    child: OutlinedButton(
                      onPressed: _clearFilters,
                      style: OutlinedButton.styleFrom(
                        padding: EdgeInsets.zero, // Remove inner padding so icon centers
                        side: const BorderSide(color: Color(0xFFE2E8F0)),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                      ),
                      child: const Icon(Icons.close_rounded, size: 18, color: Color(0xFF475569)),
                    ),
                  );

                  if (isCompactFilter) {
                    return Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Row(
                          children: [
                            Expanded(child: searchField),
                            const SizedBox(width: 8),
                            Expanded(child: barcodeScanField),
                          ],
                        ),
                        const SizedBox(height: 10),
                        Row(
                          children: [
                            Expanded(child: categoryDropdown),
                            const SizedBox(width: 8),
                            Expanded(child: stockDropdown),
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
                      Expanded(flex: 2, child: barcodeScanField),
                      const SizedBox(width: 10),
                      Expanded(flex: 2, child: categoryDropdown),
                      const SizedBox(width: 10),
                      Expanded(flex: 2, child: stockDropdown),
                      const SizedBox(width: 8),
                      clearBtn,
                    ],
                  );
                },
              ),
            ),
            const SizedBox(height: 14),

            // 3. PRODUCTS TABLE CARD
            Container(
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: cardBorder),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // Top-right Refresh Catalog row
                  Padding(
                    padding: const EdgeInsets.fromLTRB(18, 12, 18, 12),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          'Showing ${_filteredProducts.length} of ${_products.length} products',
                          style: const TextStyle(fontSize: 12.5, color: Color(0xFF64748B), fontWeight: FontWeight.w500),
                        ),
                        TextButton.icon(
                          onPressed: _loadData,
                          icon: const Icon(Icons.refresh_rounded, size: 16, color: navyDark),
                          label: const Text(
                            'Refresh Catalog',
                            style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w600, color: navyDark),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const Divider(height: 1, color: cardBorder),

                  if (_isLoading)
                    const SizedBox(
                      height: 240,
                      child: Center(child: CircularProgressIndicator(color: sidebarBlue)),
                    )
                  else if (_errorMessage != null)
                    Padding(
                      padding: const EdgeInsets.all(28),
                      child: Column(
                        children: [
                          const Icon(Icons.error_outline, size: 38, color: Colors.red),
                          const SizedBox(height: 8),
                          Text(_errorMessage!, style: const TextStyle(color: navyDark)),
                          const SizedBox(height: 12),
                          ElevatedButton(onPressed: _loadData, child: const Text('Try Again')),
                        ],
                      ),
                    )
                  else if (_filteredProducts.isEmpty)
                    Padding(
                      padding: const EdgeInsets.all(36),
                      child: Column(
                        children: [
                          const Icon(Icons.inventory_2_outlined, size: 44, color: Colors.grey),
                          const SizedBox(height: 10),
                          const Text('No paint products found', style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold)),
                          const SizedBox(height: 4),
                          const Text('Add wall paints, enamels, primers, or tools to your shop catalog.', style: TextStyle(fontSize: 12, color: Colors.grey)),
                          const SizedBox(height: 14),
                          ElevatedButton.icon(
                            onPressed: () => _showProductDialog(),
                            icon: const Icon(Icons.add),
                            label: const Text('Add First Product'),
                            style: ElevatedButton.styleFrom(backgroundColor: sidebarBlue, foregroundColor: Colors.white),
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
                              padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
                              child: const Row(
                                children: [
                                  SizedBox(width: 52, child: Text('Image', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: Color(0xFF475569)))),
                                  Expanded(flex: 4, child: Text('Product Name', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: Color(0xFF475569)))),
                                  Expanded(flex: 3, child: Text('Barcode / Label', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: Color(0xFF475569)))),
                                  Expanded(flex: 2, child: Text('Category', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: Color(0xFF475569)))),
                                  Expanded(flex: 2, child: Text('Brand', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: Color(0xFF475569)))),
                                  Expanded(flex: 1, child: Text('Unit', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: Color(0xFF475569)))),
                                  Expanded(flex: 1, child: Text('Stock', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: Color(0xFF475569)))),
                                  Expanded(flex: 2, child: Text('Price', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: Color(0xFF475569)))),
                                  SizedBox(width: 120, child: Text('Action', textAlign: TextAlign.center, style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: Color(0xFF475569)))),
                                ],
                              ),
                            ),
                            const Divider(height: 1, color: cardBorder),

                            // Rows
                            ...List.generate(_filteredProducts.length, (idx) {
                              final p = _filteredProducts[idx];
                              final stock = (p['stock_qty'] is num)
                                  ? (p['stock_qty'] as num).toDouble()
                                  : double.tryParse(p['stock_qty']?.toString() ?? '0') ?? 0;
                              final reorder = (p['reorder_level'] is num)
                                  ? (p['reorder_level'] as num).toDouble()
                                  : double.tryParse(p['reorder_level']?.toString() ?? '0') ?? 0;
                              final isLow = stock <= reorder;
                              final barcode = _productBarcode(p);

                              return Container(
                                decoration: BoxDecoration(
                                  color: Colors.white,
                                  border: Border(
                                    bottom: BorderSide(
                                      color: idx == _filteredProducts.length - 1
                                          ? Colors.transparent
                                          : const Color(0xFFF1F5F9),
                                    ),
                                  ),
                                ),
                                padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
                                child: Row(
                                  children: [
                                    // Image
                                    SizedBox(
                                      width: 52,
                                      child: Align(
                                        alignment: Alignment.centerLeft,
                                        child: ProductImageWidget(
                                          imageUrl: p['image_url']?.toString(),
                                          width: 36,
                                          height: 36,
                                          borderRadius: BorderRadius.circular(8),
                                          fallback: Container(
                                            width: 36,
                                            height: 36,
                                            decoration: BoxDecoration(
                                              color: const Color(0xFFEFF6FF),
                                              borderRadius: BorderRadius.circular(8),
                                            ),
                                            child: const Icon(Icons.format_paint_rounded, size: 18, color: sidebarBlue),
                                          ),
                                        ),
                                      ),
                                    ),

                                    // Product Name
                                    Expanded(
                                      flex: 4,
                                      child: Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                            p['product_name'] ?? '-',
                                            maxLines: 1,
                                            overflow: TextOverflow.ellipsis,
                                            style: const TextStyle(fontSize: 13.5, fontWeight: FontWeight.w700, color: navyDark),
                                          ),
                                          const SizedBox(height: 2),
                                          Text(
                                            'ID: #${p['id'] ?? '-'}',
                                            style: const TextStyle(fontSize: 11, color: Color(0xFF64748B)),
                                          ),
                                        ],
                                      ),
                                    ),

                                    // Barcode Interactive Pill
                                    Expanded(
                                      flex: 3,
                                      child: Align(
                                        alignment: Alignment.centerLeft,
                                        child: InkWell(
                                          onTap: () => _showBarcodeDialog(p),
                                          borderRadius: BorderRadius.circular(6),
                                          child: Container(
                                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                            decoration: BoxDecoration(
                                              color: const Color(0xFFF8FAFC),
                                              borderRadius: BorderRadius.circular(6),
                                              border: Border.all(color: const Color(0xFFCBD5E1)),
                                            ),
                                            child: Row(
                                              mainAxisSize: MainAxisSize.min,
                                              children: [
                                                const Icon(Icons.qr_code_2_rounded, size: 16, color: sidebarBlue),
                                                const SizedBox(width: 6),
                                                Flexible(
                                                  child: Text(
                                                    barcode,
                                                    maxLines: 1,
                                                    overflow: TextOverflow.ellipsis,
                                                    style: const TextStyle(
                                                      fontFamily: 'monospace',
                                                      fontSize: 11.5,
                                                      fontWeight: FontWeight.w700,
                                                      color: navyDark,
                                                    ),
                                                  ),
                                                ),
                                              ],
                                            ),
                                          ),
                                        ),
                                      ),
                                    ),

                                    // Category
                                    Expanded(
                                      flex: 2,
                                      child: Text(
                                        _categoryName(p),
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                        style: const TextStyle(fontSize: 13, color: Color(0xFF334155)),
                                      ),
                                    ),

                                    // Brand
                                    Expanded(
                                      flex: 2,
                                      child: Text(
                                        _brandName(p),
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                        style: const TextStyle(fontSize: 13, color: Color(0xFF334155)),
                                      ),
                                    ),

                                    // Unit
                                    Expanded(
                                      flex: 1,
                                      child: Text(
                                        (p['unit'] ?? '-').toString(),
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                        style: const TextStyle(fontSize: 13, color: Color(0xFF475569)),
                                      ),
                                    ),

                                    // Stock
                                    Expanded(
                                      flex: 1,
                                      child: Text(
                                        stock.toStringAsFixed(stock.truncateToDouble() == stock ? 0 : 1),
                                        style: TextStyle(
                                          fontSize: 13,
                                          fontWeight: FontWeight.w700,
                                          color: stock <= 0
                                              ? Colors.red.shade600
                                              : isLow
                                                  ? const Color(0xFFD97706)
                                                  : navyDark,
                                        ),
                                      ),
                                    ),

                                    // Price
                                    Expanded(
                                      flex: 2,
                                      child: Text(
                                        _currency(p['selling_price']),
                                        style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: navyDark),
                                      ),
                                    ),

                                    // Action Buttons (Print Barcode, Edit, Delete)
                                    SizedBox(
                                      width: 120,
                                      child: Row(
                                        mainAxisAlignment: MainAxisAlignment.center,
                                        children: [
                                          IconButton(
                                            tooltip: 'Print Barcode Label',
                                            icon: const Icon(Icons.qr_code_2_rounded, size: 18, color: darkGreen),
                                            onPressed: () => _showBarcodeDialog(p),
                                          ),
                                          IconButton(
                                            tooltip: 'Edit',
                                            icon: const Icon(Icons.edit_outlined, size: 17, color: sidebarBlue),
                                            onPressed: () => _showProductDialog(product: p),
                                          ),
                                          IconButton(
                                            tooltip: 'Delete',
                                            icon: const Icon(Icons.delete_outline_rounded, size: 17, color: Colors.red),
                                            onPressed: () => _deleteProduct(p),
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
                            child: SizedBox(width: 980, child: tableBody),
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
}

// --- High-Resolution Barcode Custom Painter ---
class BarcodePainter extends CustomPainter {
  final String data;
  final Color color;

  BarcodePainter({required this.data, this.color = Colors.black});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.fill;

    final pattern = _generatePattern(data);
    final totalUnits = pattern.fold<int>(0, (sum, w) => sum + w);
    if (totalUnits == 0) return;

    final unitWidth = size.width / totalUnits;
    double currentX = 0;
    bool isBar = true;

    for (final widthUnits in pattern) {
      final barWidth = widthUnits * unitWidth;
      if (isBar) {
        canvas.drawRect(Rect.fromLTWH(currentX, 0, barWidth, size.height), paint);
      }
      currentX += barWidth;
      isBar = !isBar;
    }
  }

  List<int> _generatePattern(String text) {
    // Start guard: bar, space, bar
    final list = <int>[2, 1, 2, 1];

    for (int i = 0; i < text.length; i++) {
      final code = text.codeUnitAt(i);
      list.add((code % 3) + 1);
      list.add(((code ~/ 3) % 3) + 1);
      list.add(((code ~/ 9) % 3) + 1);
      list.add(1);
    }

    // Stop guard: bar, space, bar, space, bar
    list.addAll([2, 1, 2, 1, 2]);
    return list;
  }

  @override
  bool shouldRepaint(covariant BarcodePainter oldDelegate) =>
      oldDelegate.data != data || oldDelegate.color != color;
}
