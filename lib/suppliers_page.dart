import 'package:flutter/material.dart';

import 'app_toast.dart';
import 'responsive_ui.dart';
import 'api_service.dart';
import 'app_input_formatters.dart';

class SuppliersPage extends StatefulWidget {
  final String token;
  final String? apiBaseUrl;

  const SuppliersPage({super.key, required this.token, this.apiBaseUrl});

  @override
  State<SuppliersPage> createState() => _SuppliersPageState();
}

class _SuppliersPageState extends State<SuppliersPage> {
  late final ApiService _api;
  bool _isLoading = true;
  String? _errorMessage;
  List<dynamic> _suppliers = [];
  String _searchQuery = '';

  static const Color sidebarBlue = Color(0xFF1E40AF);
  static const Color primaryGreen = Color(0xFF10B981);
  static const Color background = Color(0xFFF5F5F5); // White Smoke

  @override
  void initState() {
    super.initState();
    _api = ApiService(token: widget.token, customBaseUrl: widget.apiBaseUrl);
    _loadSuppliers();
  }

  Future<void> _loadSuppliers() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final res = await _api.get('/suppliers');
      if (!mounted) return;
      setState(() {
        _suppliers = res['data'] is List ? res['data'] : [];
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

  List<dynamic> get _filteredSuppliers {
    if (_searchQuery.trim().isEmpty) return _suppliers;
    final q = _searchQuery.toLowerCase();
    return _suppliers.where((s) {
      final name = (s['name'] ?? '').toString().toLowerCase();
      final phone = (s['phone'] ?? '').toString().toLowerCase();
      final gst = (s['gst_number'] ?? '').toString().toLowerCase();
      final email = (s['email'] ?? '').toString().toLowerCase();
      final contact = (s['contact_person'] ?? '').toString().toLowerCase();
      final address = (s['address'] ?? '').toString().toLowerCase();
      return name.contains(q) ||
          phone.contains(q) ||
          gst.contains(q) ||
          email.contains(q) ||
          contact.contains(q) ||
          address.contains(q);
    }).toList();
  }

  void _showSupplierDialog({Map<String, dynamic>? supplier}) {
    final isEditing = supplier != null;
    final nameCtrl = TextEditingController(
      text: supplier?['name']?.toString() ?? '',
    );
    final phoneCtrl = TextEditingController(
      text: supplier?['phone']?.toString() ?? '',
    );
    final emailCtrl = TextEditingController(
      text: supplier?['email']?.toString() ?? '',
    );
    final gstCtrl = TextEditingController(
      text: supplier?['gst_number']?.toString() ?? '',
    );
    final addressCtrl = TextEditingController(
      text: supplier?['address']?.toString() ?? '',
    );

    showDialog(
      context: context,
      barrierDismissible: false,
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
                Icons.local_shipping_rounded,
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
                    isEditing ? 'Edit Supplier' : 'Add New Supplier',
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
                      color: Colors.black,
                    ),
                  ),
                  const SizedBox(height: 2),
                  const Text(
                    'Register paint manufacturer or wholesale distributor.',
                    style: TextStyle(fontSize: 11, color: Color(0xFF6B7280)),
                  ),
                ],
              ),
            ),
            IconButton(
              icon: const Icon(
                Icons.close_rounded,
                size: 20,
                color: Colors.black45,
              ),
              onPressed: () => Navigator.pop(ctx),
            ),
          ],
        ),
        content: SizedBox(
          width: 480,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: nameCtrl,
                inputFormatters: const [NoLeadingSpaceFormatter()],
                decoration: const InputDecoration(
                  labelText: 'Supplier / Company Name *',
                  hintText: 'Enter supplier / company name',
                  prefixIcon: Icon(Icons.business_rounded, size: 18),
                ),
              ),
              const SizedBox(height: 14),
              Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: phoneCtrl,
                      keyboardType: TextInputType.phone,
                      inputFormatters: const [PhoneNumberFormatter()],
                      decoration: const InputDecoration(
                        labelText: 'Contact Phone',
                        hintText: '10-digit mobile number',
                        prefixIcon: Icon(Icons.phone_rounded, size: 18),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: TextField(
                      controller: gstCtrl,
                      inputFormatters: const [NoLeadingSpaceFormatter()],
                      decoration: const InputDecoration(
                        labelText: 'GSTIN Number',
                        hintText: '33AAAAA0000A1Z5',
                        prefixIcon: Icon(Icons.verified_user_rounded, size: 18),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 14),
              TextField(
                controller: emailCtrl,
                keyboardType: TextInputType.emailAddress,
                inputFormatters: const [NoLeadingSpaceFormatter()],
                decoration: const InputDecoration(
                  labelText: 'Supplier Email',
                  hintText: 'vendor@paintcompany.com',
                  prefixIcon: Icon(Icons.email_rounded, size: 18),
                ),
              ),
              const SizedBox(height: 14),
              TextField(
                controller: addressCtrl,
                maxLines: 2,
                inputFormatters: const [NoLeadingSpaceFormatter()],
                decoration: const InputDecoration(
                  labelText: 'Warehouse / Supply Office Address',
                  hintText: 'Unit 4, Industrial Estate, Chennai, TN',
                  prefixIcon: Icon(Icons.location_on_rounded, size: 18),
                ),
              ),
            ],
          ),
        ),
        actions: [
          OutlinedButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
          ElevatedButton.icon(
            style: ElevatedButton.styleFrom(
              backgroundColor: sidebarBlue,
              foregroundColor: Colors.white,
            ),
            icon: const Icon(Icons.check_rounded, size: 16),
            label: Text(isEditing ? 'Update Supplier' : 'Save Supplier'),
            onPressed: () async {
              final name = nameCtrl.text.trim();
              if (name.isEmpty || name.length < 2) {
                AppToast.showWarning(
                  context,
                  title: 'Invalid Name',
                  message: 'Please enter a valid supplier name.',
                );
                return;
              }

              final phone = phoneCtrl.text.trim();
              if (phone.isNotEmpty &&
                  (phone.length != 10 ||
                      RegExp(r"^(\d)\1{9}$").hasMatch(phone))) {
                AppToast.showWarning(
                  context,
                  title: 'Invalid Mobile Number',
                  message: 'Please enter a valid 10-digit mobile number.',
                );
                return;
              }

              final email = emailCtrl.text.trim();
              if (email.isNotEmpty &&
                  !RegExp(r"^[a-zA-Z0-9._%+-]+@[a-zA-Z0-9.-]+\.[a-zA-Z]{2,}$")
                      .hasMatch(email)) {
                AppToast.showWarning(
                  context,
                  title: 'Invalid Email',
                  message: 'Please enter a valid email address.',
                );
                return;
              }

              final payload = {
                'name': name,
                'phone': phone,
                'email': email,
                'address': addressCtrl.text.trim(),
                'gst_number': gstCtrl.text.trim(),
              };

              Navigator.pop(ctx);
              try {
                if (isEditing) {
                  await _api.put('/suppliers/${supplier['id']}', payload);
                } else {
                  await _api.post('/suppliers', payload);
                }
                if (mounted) {
                  AppToast.showSuccess(
                    context,
                    title: isEditing
                        ? 'Supplier Updated!'
                        : 'Supplier Created!',
                    message: isEditing
                        ? '$name details updated successfully.'
                        : '$name has been added as a supplier.',
                  );
                  _loadSuppliers();
                }
              } catch (e) {
                if (mounted) {
                  AppToast.showError(
                    context,
                    title: isEditing ? 'Update Failed' : 'Save Failed',
                    message: e.toString().replaceAll('Exception: ', ''),
                  );
                }
              }
            },
          ),
        ],
      ),
    );
  }

  Future<void> _deleteSupplier(dynamic supplier) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        title: const Text(
          'Delete Supplier',
          style: TextStyle(fontWeight: FontWeight.bold, color: Colors.black),
        ),
        content: Text('Are you sure you want to delete "${supplier['name']}"?'),
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
      await _api.delete('/suppliers/${supplier['id']}');
      if (mounted) {
        AppToast.showSuccess(
          context,
          title: 'Supplier Deleted',
          message: 'Supplier record removed successfully.',
        );
        _loadSuppliers();
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
    return Container(
      color: background, // White Smoke (0xFFF5F5F5)
      child: SingleChildScrollView(
        padding: const EdgeInsets.only(bottom: 30),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // 1. TOP SUMMARY METRICS
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
              child: ResponsiveSummaryGrid(
                spacing: 10,
                desktopBreakpoint: 900,
                tabletBreakpoint: 480,
                children: [
                  _buildSummaryBox(
                    title: 'Total Suppliers',
                    value: '${_suppliers.length} Vendors',
                    subtitle: 'Registered paint brands & dealers',
                    icon: Icons.local_shipping_rounded,
                    accentColor: sidebarBlue,
                  ),
                  _buildSummaryBox(
                    title: 'GST Registered',
                    value:
                        '${_suppliers.where((s) => (s['gst_number'] ?? '').toString().isNotEmpty).length} Registered',
                    subtitle: 'Suppliers with valid GSTIN',
                    icon: Icons.verified_user_rounded,
                    accentColor: primaryGreen,
                  ),
                  _buildSummaryBox(
                    title: 'Contact Reachable',
                    value:
                        '${_suppliers.where((s) => (s['phone'] ?? '').toString().isNotEmpty).length} Active Phone',
                    subtitle: 'Vendors with direct phone line',
                    icon: Icons.phone_in_talk_rounded,
                    accentColor: const Color(0xFFF59E0B),
                  ),
                ],
              ),
            ),

            // 2. SEARCH & ACTION BAR
            Container(
              margin: const EdgeInsets.all(16),
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: const Color(0xFFE5E7EB)),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.02),
                    blurRadius: 8,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: Builder(
                builder: (context) {
                  final compact = MediaQuery.sizeOf(context).width < 700;
                  final searchBox = TextField(
                    onChanged: (val) => setState(() => _searchQuery = val),
                    inputFormatters: const [NoLeadingSpaceFormatter()],
                    style: const TextStyle(color: Colors.black, fontSize: 13),
                    decoration: InputDecoration(
                      hintText:
                          'Search suppliers by name, GSTIN, phone, or email...',
                      hintStyle: const TextStyle(
                        color: Color(0xFF9CA3AF),
                        fontSize: 13,
                      ),
                      prefixIcon: const Icon(
                        Icons.search,
                        size: 20,
                        color: Colors.black54,
                      ),
                      filled: true,
                      fillColor: const Color(0xFFF9FAFB),
                      isDense: true,
                      contentPadding: const EdgeInsets.symmetric(
                        vertical: 10,
                        horizontal: 12,
                      ),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8),
                        borderSide: const BorderSide(color: Color(0xFFE5E7EB)),
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8),
                        borderSide: const BorderSide(color: Color(0xFFE5E7EB)),
                      ),
                    ),
                  );
                  final addBtn = ElevatedButton.icon(
                    onPressed: () => _showSupplierDialog(),
                    icon: const Icon(Icons.add_business_rounded, size: 17),
                    label: const Text('Add Supplier'),
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
                  );
                  final refreshBtn = IconButton(
                    tooltip: 'Refresh',
                    onPressed: _loadSuppliers,
                    icon: const Icon(
                      Icons.refresh_rounded,
                      color: Colors.black87,
                      size: 20,
                    ),
                  );
                  if (compact) {
                    return Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        searchBox,
                        const SizedBox(height: 10),
                        Row(
                          children: [
                            Expanded(child: addBtn),
                            const SizedBox(width: 8),
                            refreshBtn,
                          ],
                        ),
                      ],
                    );
                  }
                  return Row(
                    children: [
                      Expanded(child: searchBox),
                      const SizedBox(width: 14),
                      addBtn,
                      const SizedBox(width: 8),
                      refreshBtn,
                    ],
                  );
                },
              ),
            ),

            // 3. TABLE CARD (100% FULL WIDTH, ZERO EMPTY VOID)
            if (_isLoading)
              Container(
                height: 250,
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
                  border: Border.all(color: const Color(0xFFE5E7EB)),
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
                    Text(
                      _errorMessage!,
                      style: const TextStyle(color: Colors.black87),
                    ),
                    const SizedBox(height: 12),
                    ElevatedButton(
                      onPressed: _loadSuppliers,
                      child: const Text('Try Again'),
                    ),
                  ],
                ),
              )
            else if (_filteredSuppliers.isEmpty)
              Container(
                margin: const EdgeInsets.symmetric(horizontal: 16),
                padding: const EdgeInsets.all(36),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: const Color(0xFFE5E7EB)),
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(
                      Icons.local_shipping_outlined,
                      size: 48,
                      color: Colors.grey,
                    ),
                    const SizedBox(height: 10),
                    const Text(
                      'No suppliers recorded yet',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: Colors.black87,
                      ),
                    ),
                    const SizedBox(height: 6),
                    const Text(
                      'Add paint suppliers & wholesale distributors to record inventory purchases.',
                      style: TextStyle(fontSize: 12, color: Colors.grey),
                    ),
                    const SizedBox(height: 14),
                    ElevatedButton.icon(
                      onPressed: () => _showSupplierDialog(),
                      icon: const Icon(Icons.add),
                      label: const Text('Add First Supplier'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: sidebarBlue,
                        foregroundColor: Colors.white,
                      ),
                    ),
                  ],
                ),
              )
            else
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Container(
                  decoration: BoxDecoration(
                    color: Colors.white, // Pure White Box
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: const Color(0xFFE5E7EB)),
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
                            MediaQuery.sizeOf(context).width < 1080;
                        final content = Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            // HEADER
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
                                      'Supplier Name',
                                      style: TextStyle(
                                        fontWeight: FontWeight.bold,
                                        color: Colors.black,
                                        fontSize: 13,
                                      ),
                                    ),
                                  ),
                                  Expanded(
                                    flex: 2,
                                    child: Text(
                                      'Phone',
                                      style: TextStyle(
                                        fontWeight: FontWeight.bold,
                                        color: Colors.black,
                                        fontSize: 13,
                                      ),
                                    ),
                                  ),
                                  Expanded(
                                    flex: 2,
                                    child: Text(
                                      'GST Number',
                                      style: TextStyle(
                                        fontWeight: FontWeight.bold,
                                        color: Colors.black,
                                        fontSize: 13,
                                      ),
                                    ),
                                  ),
                                  Expanded(
                                    flex: 3,
                                    child: Text(
                                      'Email',
                                      style: TextStyle(
                                        fontWeight: FontWeight.bold,
                                        color: Colors.black,
                                        fontSize: 13,
                                      ),
                                    ),
                                  ),
                                  Expanded(
                                    flex: 3,
                                    child: Text(
                                      'Address',
                                      style: TextStyle(
                                        fontWeight: FontWeight.bold,
                                        color: Colors.black,
                                        fontSize: 13,
                                      ),
                                    ),
                                  ),
                                  SizedBox(
                                    width: 90,
                                    child: Text(
                                      'Actions',
                                      textAlign: TextAlign.center,
                                      style: TextStyle(
                                        fontWeight: FontWeight.bold,
                                        color: Colors.black,
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

                            // ROWS
                            ...List.generate(_filteredSuppliers.length, (idx) {
                              final s = _filteredSuppliers[idx];
                              return Container(
                                decoration: BoxDecoration(
                                  color: Colors.white,
                                  border: Border(
                                    bottom: BorderSide(
                                      color:
                                          idx == _filteredSuppliers.length - 1
                                          ? Colors.transparent
                                          : const Color(0xFFF3F4F6),
                                    ),
                                  ),
                                ),
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 20,
                                  vertical: 14,
                                ),
                                child: Row(
                                  children: [
                                    // Name
                                    Expanded(
                                      flex: 3,
                                      child: Row(
                                        children: [
                                          CircleAvatar(
                                            radius: 14,
                                            backgroundColor: const Color(
                                              0xFFFEF3C7,
                                            ),
                                            child: Text(
                                              (s['name'] ?? 'S')
                                                  .toString()
                                                  .substring(0, 1)
                                                  .toUpperCase(),
                                              style: const TextStyle(
                                                fontSize: 11,
                                                fontWeight: FontWeight.bold,
                                                color: Color(0xFFD97706),
                                              ),
                                            ),
                                          ),
                                          const SizedBox(width: 10),
                                          Flexible(
                                            child: Text(
                                              s['name'] ?? '-',
                                              style: const TextStyle(
                                                fontWeight: FontWeight.bold,
                                                color: Colors.black,
                                                fontSize: 13,
                                              ),
                                              overflow: TextOverflow.ellipsis,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                    // Phone
                                    Expanded(
                                      flex: 2,
                                      child: Text(
                                        s['phone'] ?? '-',
                                        style: const TextStyle(
                                          color: Colors.black87,
                                          fontSize: 13,
                                        ),
                                      ),
                                    ),
                                    // GST
                                    Expanded(
                                      flex: 2,
                                      child: Text(
                                        s['gst_number'] ?? '-',
                                        style: const TextStyle(
                                          color: Color(0xFF4B5563),
                                          fontSize: 12,
                                        ),
                                      ),
                                    ),
                                    // Email
                                    Expanded(
                                      flex: 3,
                                      child: Text(
                                        s['email'] ?? '-',
                                        style: const TextStyle(
                                          color: Color(0xFF4B5563),
                                          fontSize: 13,
                                        ),
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                    ),
                                    // Address
                                    Expanded(
                                      flex: 3,
                                      child: Text(
                                        s['address'] ?? '-',
                                        style: const TextStyle(
                                          color: Color(0xFF4B5563),
                                          fontSize: 12,
                                        ),
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                    ),
                                    // Actions
                                    SizedBox(
                                      width: 90,
                                      child: Row(
                                        mainAxisAlignment:
                                            MainAxisAlignment.center,
                                        children: [
                                          IconButton(
                                            tooltip: 'Edit',
                                            icon: const Icon(
                                              Icons.edit_outlined,
                                              size: 16,
                                              color: sidebarBlue,
                                            ),
                                            onPressed: () =>
                                                _showSupplierDialog(
                                                  supplier: s,
                                                ),
                                          ),
                                          IconButton(
                                            tooltip: 'Delete',
                                            icon: const Icon(
                                              Icons.delete_outline,
                                              size: 16,
                                              color: Colors.red,
                                            ),
                                            onPressed: () => _deleteSupplier(s),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ],
                                ),
                              );
                            }),

                            // FOOTER
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 20,
                                vertical: 12,
                              ),
                              decoration: const BoxDecoration(
                                color: Color(0xFFF9FAFB),
                                border: Border(
                                  top: BorderSide(color: Color(0xFFE5E7EB)),
                                ),
                              ),
                              child: Row(
                                mainAxisAlignment:
                                    MainAxisAlignment.spaceBetween,
                                children: [
                                  Text(
                                    'Showing ${_filteredSuppliers.length} of ${_suppliers.length} suppliers',
                                    style: const TextStyle(
                                      fontSize: 12,
                                      color: Color(0xFF6B7280),
                                    ),
                                  ),
                                  Text(
                                    'Total Registered: ${_suppliers.length}',
                                    style: const TextStyle(
                                      fontSize: 12,
                                      fontWeight: FontWeight.bold,
                                      color: Colors.black,
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
                            child: SizedBox(width: 850, child: content),
                          );
                        }
                        return content;
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

  Widget _buildSummaryBox({
    required String title,
    required String value,
    required String subtitle,
    required IconData icon,
    required Color accentColor,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: Colors.white, // White Box
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: const Color(0xFFE5E7EB)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.02),
            blurRadius: 6,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            width: 32,
            height: 32,
            decoration: BoxDecoration(
              color: accentColor.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(icon, color: accentColor, size: 18),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                FittedBox(
                  fit: BoxFit.scaleDown,
                  alignment: Alignment.centerLeft,
                  child: Text(
                    value,
                    style: const TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.bold,
                      color: Colors.black, // Black Text
                    ),
                  ),
                ),
                const SizedBox(height: 1),
                Text(
                  title,
                  style: const TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    color: Colors.black87, // Black Text
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
