import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'api_service.dart';
import 'app_input_formatters.dart';

class SettingsPage extends StatefulWidget {
  final String token;
  final String? apiBaseUrl;

  const SettingsPage({super.key, required this.token, this.apiBaseUrl});

  @override
  State<SettingsPage> createState() => _SettingsPageState();
}

class _SettingsPageState extends State<SettingsPage> {
  late final ApiService _api;
  bool _isLoading = true;
  bool _isSaving = false;

  // Essential Controllers Only
  final _shopNameCtrl = TextEditingController();
  final _phoneCtrl = TextEditingController();
  final _emailCtrl = TextEditingController();
  final _addressCtrl = TextEditingController();
  final _gstCtrl = TextEditingController();
  final _currencyCtrl = TextEditingController(text: '₹');
  final _invoiceFooterCtrl = TextEditingController();

  // Color Palette
  static const Color navy = Color(0xFF151B3B);
  static const Color primaryBlue = Color(0xFF1E40AF);
  static const Color primaryGreen = Color(0xFF10B981);
  static const Color amberGold = Color(0xFFD97706);
  static const Color purpleAccent = Color(0xFF7C3AED);
  static const Color cardBorder = Color(0xFFE2E8F0);
  static const Color background = Color(0xFFF8FAFC);
  static const Color textMuted = Color(0xFF64748B);

  @override
  void initState() {
    super.initState();
    _api = ApiService(token: widget.token, customBaseUrl: widget.apiBaseUrl);
    _loadSettings();
  }

  @override
  void dispose() {
    _shopNameCtrl.dispose();
    _phoneCtrl.dispose();
    _emailCtrl.dispose();
    _addressCtrl.dispose();
    _gstCtrl.dispose();
    _currencyCtrl.dispose();
    _invoiceFooterCtrl.dispose();
    super.dispose();
  }

  Future<void> _loadSettings() async {
    setState(() => _isLoading = true);

    try {
      final res = await _api.get('/settings');
      if (!mounted) return;

      final data = res['data'] is Map ? res['data'] as Map : {};
      _shopNameCtrl.text = data['shop_name']?.toString() ?? 'My Paint Shop';
      _phoneCtrl.text = data['phone']?.toString() ?? '9876543210';
      _emailCtrl.text = data['email']?.toString() ?? 'admin@gmail.com';
      _addressCtrl.text =
          data['address']?.toString() ??
          '123 Main Road, Paint Market, Tamil Nadu';
      _gstCtrl.text = data['gst_number']?.toString() ?? '33AAAAA0000A1Z5';
      final savedCurrency = data['currency']?.toString().trim() ?? '';
      _currencyCtrl.text = (savedCurrency.isEmpty || savedCurrency == '#')
          ? '₹'
          : savedCurrency;
      _invoiceFooterCtrl.text = data['invoice_footer']?.toString() ?? 'Thank you for choosing ColorCraft! Quality paint & colors for your dream home.';

      setState(() => _isLoading = false);
    } catch (_) {
      if (!mounted) return;
      _shopNameCtrl.text = 'My Paint Shop';
      _phoneCtrl.text = '9876543210';
      _emailCtrl.text = 'admin@gmail.com';
      _addressCtrl.text = '123 Main Road, Paint Market, Tamil Nadu';
      _gstCtrl.text = '33AAAAA0000A1Z5';
      _currencyCtrl.text = '₹';
      _invoiceFooterCtrl.text = 'Thank you for choosing ColorCraft! Quality paint & colors for your dream home.';
      setState(() => _isLoading = false);
    }
  }

  Future<void> _saveSettings() async {
    final shopName = _shopNameCtrl.text.trim();
    if (shopName.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please enter Paint Shop Name before saving'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    final currency = _currencyCtrl.text.trim().isEmpty
        ? '₹'
        : _currencyCtrl.text.trim();
    _currencyCtrl.text = currency;

    setState(() => _isSaving = true);

    try {
      final payload = {
        'settings': {
          'shop_name': shopName,
          'phone': _phoneCtrl.text.trim(),
          'email': _emailCtrl.text.trim(),
          'address': _addressCtrl.text.trim(),
          'gst_number': _gstCtrl.text.trim(),
          'currency': currency,
          'invoice_footer': _invoiceFooterCtrl.text.trim(),
        },
      };

      await _api.put('/settings', payload);
      if (!mounted) return;

      setState(() {});

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Row(
            children: [
              Icon(Icons.check_circle_rounded, color: Colors.white, size: 20),
              SizedBox(width: 10),
              Text('Settings saved successfully!'),
            ],
          ),
          backgroundColor: primaryGreen,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Error saving: ${e.toString().replaceAll('Exception: ', '')}',
          ),
          backgroundColor: Colors.red,
          behavior: SnackBarBehavior.floating,
        ),
      );
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return Container(
        color: background,
        child: const Center(
          child: CircularProgressIndicator(color: primaryBlue),
        ),
      );
    }

    return Container(
      color: background,
      child: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // 1. TOP 4 STATUS METRIC CARDS
            _buildStatusCards(),
            const SizedBox(height: 18),

            // 2. MAIN STORE PROFILE & INVOICING CARD
            _buildStoreProfileCard(),
            const SizedBox(height: 24),
          ],
        ),
      ),
    );
  }

  // --- 1. TOP 4 STORE STATUS CARDS ---
  Widget _buildStatusCards() {
    return LayoutBuilder(
      builder: (context, constraints) {
        int columns;
        if (constraints.maxWidth < 620) {
          columns = 1;
        } else if (constraints.maxWidth < 960) {
          columns = 2;
        } else {
          columns = 4;
        }

        final spacing = 12.0;
        final totalSpacing = (columns - 1) * spacing;
        final cardWidth = (constraints.maxWidth - totalSpacing) / columns;

        final cards = [
          _buildStatusTile(
            title: 'Shop Identity',
            value: _shopNameCtrl.text.isNotEmpty
                ? _shopNameCtrl.text
                : 'My Paint Shop',
            subtitle: _gstCtrl.text.isNotEmpty
                ? 'GST: ${_gstCtrl.text}'
                : 'GST Registered',
            icon: Icons.storefront_rounded,
            iconBg: const Color(0xFFEFF6FF),
            iconColor: primaryBlue,
          ),
          _buildStatusTile(
            title: 'Store Phone',
            value: _phoneCtrl.text.isNotEmpty ? _phoneCtrl.text : '9876543210',
            subtitle: 'Primary Contact',
            icon: Icons.phone_rounded,
            iconBg: const Color(0xFFDCFCE7),
            iconColor: primaryGreen,
          ),
          _buildStatusTile(
            title: 'Support Email',
            value: _emailCtrl.text.isNotEmpty
                ? _emailCtrl.text
                : 'admin@gmail.com',
            subtitle: 'Invoicing & Customer Help',
            icon: Icons.email_rounded,
            iconBg: const Color(0xFFF3E8FF),
            iconColor: purpleAccent,
          ),
          _buildStatusTile(
            title: 'Active Currency',
            value: '${_currencyCtrl.text.trim()} INR (Rupees)',
            subtitle: 'Formatted for billing & invoices',
            icon: Icons.currency_rupee_rounded,
            iconBg: const Color(0xFFFEF3C7),
            iconColor: amberGold,
          ),
        ];

        return Wrap(
          spacing: spacing,
          runSpacing: spacing,
          children: cards
              .map((c) => SizedBox(width: cardWidth, child: c))
              .toList(),
        );
      },
    );
  }

  Widget _buildStatusTile({
    required String title,
    required String value,
    required String subtitle,
    required IconData icon,
    required Color iconBg,
    required Color iconColor,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: cardBorder),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withAlpha(5),
            blurRadius: 6,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              color: iconBg,
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(icon, color: iconColor, size: 18),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  value,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 13.5,
                    fontWeight: FontWeight.bold,
                    color: navy,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  subtitle,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(fontSize: 11, color: textMuted),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // --- 2. MAIN STORE PROFILE & INVOICING CARD ---
  Widget _buildStoreProfileCard() {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: cardBorder),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withAlpha(5),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      padding: const EdgeInsets.all(22),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header with Save Button
          LayoutBuilder(
            builder: (context, constraints) {
              final isNarrow = constraints.maxWidth < 640;
              final headerInfo = Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: const Color(0xFFEFF6FF),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: const Icon(
                      Icons.store_rounded,
                      color: primaryBlue,
                      size: 20,
                    ),
                  ),
                  const SizedBox(width: 12),
                  const Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Store Profile & Invoicing Details',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            color: navy,
                          ),
                        ),
                        SizedBox(height: 2),
                        Text(
                          'These details appear on printed invoices, receipts, and orders.',
                          style: TextStyle(fontSize: 12, color: textMuted),
                        ),
                      ],
                    ),
                  ),
                ],
              );

              final saveButton = ElevatedButton.icon(
                onPressed: _isSaving ? null : _saveSettings,
                icon: _isSaving
                    ? const SizedBox(
                        width: 15,
                        height: 15,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.white,
                        ),
                      )
                    : const Icon(Icons.save_rounded, size: 16),
                label: Text(
                  _isSaving ? 'Saving...' : 'Save Settings',
                  style: const TextStyle(
                    fontWeight: FontWeight.w600,
                    fontSize: 13,
                  ),
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: primaryBlue,
                  foregroundColor: Colors.white,
                  elevation: 0,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 20,
                    vertical: 12,
                  ),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
              );

              if (isNarrow) {
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    headerInfo,
                    const SizedBox(height: 12),
                    saveButton,
                  ],
                );
              }

              return Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Expanded(child: headerInfo),
                  const SizedBox(width: 12),
                  saveButton,
                ],
              );
            },
          ),
          const Divider(height: 28, color: Color(0xFFE5E7EB)),

          // Form fields (Responsive: 2-column on desktop, 1-column on mobile)
          LayoutBuilder(
            builder: (context, constraints) {
              final isSmall = constraints.maxWidth < 680;
              if (isSmall) {
                return Column(
                  children: [
                    _buildTextField(
                      controller: _shopNameCtrl,
                      label: 'Paint Shop Name *',
                      hint: 'My Paint Shop',
                      icon: Icons.business_rounded,
                    ),
                    const SizedBox(height: 14),
                    _buildTextField(
                      controller: _gstCtrl,
                      label: 'GSTIN Number',
                      hint: '33AAAAA0000A1Z5',
                      icon: Icons.verified_user_rounded,
                    ),
                    const SizedBox(height: 14),
                    _buildTextField(
                      controller: _phoneCtrl,
                      label: 'Contact Phone Number',
                      hint: '9876543210',
                      icon: Icons.phone_rounded,
                      inputFormatters: const [PhoneNumberFormatter()],
                    ),
                    const SizedBox(height: 14),
                    _buildTextField(
                      controller: _emailCtrl,
                      label: 'Support / Contact Email',
                      hint: 'admin@gmail.com',
                      icon: Icons.email_rounded,
                    ),
                    const SizedBox(height: 14),
                    _buildTextField(
                      controller: _addressCtrl,
                      label: 'Store Address (Printed on Invoices)',
                      hint: '123 Main Road, Paint Market, Tamil Nadu',
                      icon: Icons.location_on_rounded,
                    ),
                    const SizedBox(height: 14),
                    _buildTextField(
                      controller: _currencyCtrl,
                      label: 'Currency Symbol',
                      hint: '₹',
                      icon: Icons.currency_rupee_rounded,
                    ),
                    const SizedBox(height: 14),
                    _buildTextField(
                      controller: _invoiceFooterCtrl,
                      label: 'Invoice Terms / Footer Greeting Note',
                      hint: 'Thank you for choosing ColorCraft! Quality paint & colors for your dream home.',
                      icon: Icons.notes_rounded,
                    ),
                  ],
                );
              }

              return Column(
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: _buildTextField(
                          controller: _shopNameCtrl,
                          label: 'Paint Shop Name *',
                          hint: 'My Paint Shop',
                          icon: Icons.business_rounded,
                        ),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: _buildTextField(
                          controller: _gstCtrl,
                          label: 'GSTIN Number',
                          hint: '33AAAAA0000A1Z5',
                          icon: Icons.verified_user_rounded,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      Expanded(
                        child: _buildTextField(
                          controller: _phoneCtrl,
                          label: 'Contact Phone Number',
                          hint: '9876543210',
                          icon: Icons.phone_rounded,
                        ),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: _buildTextField(
                          controller: _emailCtrl,
                          label: 'Support / Contact Email',
                          hint: 'admin@gmail.com',
                          icon: Icons.email_rounded,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  _buildTextField(
                    controller: _addressCtrl,
                    label: 'Store Address (Printed on Invoices)',
                    hint: '123 Main Road, Paint Market, Tamil Nadu',
                    icon: Icons.location_on_rounded,
                  ),
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      SizedBox(
                        width: 150,
                        child: _buildTextField(
                          controller: _currencyCtrl,
                          label: 'Currency Symbol',
                          hint: '₹',
                          icon: Icons.currency_rupee_rounded,
                        ),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: _buildTextField(
                          controller: _invoiceFooterCtrl,
                          label: 'Invoice Terms / Footer Greeting Note',
                          hint: 'Thank you for choosing ColorCraft! Quality paint & colors for your dream home.',
                          icon: Icons.notes_rounded,
                        ),
                      ),
                    ],
                  ),
                ],
              );
            },
          ),
        ],
      ),
    );
  }

  Widget _buildTextField({
    required TextEditingController controller,
    required String label,
    required String hint,
    required IconData icon,
    List<TextInputFormatter>? inputFormatters,
  }) {
    return TextField(
      controller: controller,
      inputFormatters: [const NoLeadingSpaceFormatter(), ...?inputFormatters],
      style: const TextStyle(
        color: navy,
        fontSize: 13,
        fontWeight: FontWeight.w500,
      ),
      decoration: InputDecoration(
        labelText: label,
        labelStyle: const TextStyle(color: Color(0xFF4B5563), fontSize: 13),
        hintText: hint,
        hintStyle: const TextStyle(color: Color(0xFF9CA3AF), fontSize: 12),
        prefixIcon: Icon(icon, size: 18, color: const Color(0xFF64748B)),
        filled: true,
        fillColor: const Color(0xFFF9FAFB),
        isDense: true,
        contentPadding: const EdgeInsets.symmetric(
          vertical: 12,
          horizontal: 12,
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
          borderSide: const BorderSide(color: primaryBlue, width: 1.5),
        ),
      ),
    );
  }
}
