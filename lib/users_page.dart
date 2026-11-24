import 'dart:convert';

import 'package:flutter/material.dart';

import 'app_toast.dart';
import 'responsive_ui.dart';
import 'api_service.dart';

class UsersPage extends StatefulWidget {
  final String token;
  final String? apiBaseUrl;

  const UsersPage({super.key, required this.token, this.apiBaseUrl});

  @override
  State<UsersPage> createState() => _UsersPageState();
}

class _UsersPageState extends State<UsersPage> {
  late final ApiService _api;
  bool _isLoading = true;
  String? _errorMessage;
  List<dynamic> _users = [];
  String _searchQuery = '';

  static const Color sidebarBlue = Color(0xFF1E40AF);
  static const Color background = Color(0xFFF5F5F5); // White Smoke

  // 10 Core Application Modules
  static const List<Map<String, dynamic>> allModules = [
    {
      'index': 0,
      'id': 'dashboard',
      'name': 'Dashboard',
      'icon': Icons.dashboard_rounded,
    },
    {
      'index': 1,
      'id': 'billing',
      'name': 'Billing (POS)',
      'icon': Icons.receipt_long_rounded,
    },
    {
      'index': 2,
      'id': 'sales',
      'name': 'Sales & Invoices',
      'icon': Icons.bar_chart_rounded,
    },
    {
      'index': 3,
      'id': 'purchase',
      'name': 'Purchase (Stock In)',
      'icon': Icons.shopping_cart_rounded,
    },
    {
      'index': 4,
      'id': 'products',
      'name': 'Products & Stock',
      'icon': Icons.inventory_2_rounded,
    },
    {
      'index': 5,
      'id': 'customers',
      'name': 'Customers',
      'icon': Icons.people_alt_rounded,
    },
    {
      'index': 6,
      'id': 'suppliers',
      'name': 'Suppliers',
      'icon': Icons.local_shipping_rounded,
    },
    {
      'index': 7,
      'id': 'reports',
      'name': 'Reports & Analytics',
      'icon': Icons.analytics_rounded,
    },
    {
      'index': 8,
      'id': 'users',
      'name': 'Users & Staff',
      'icon': Icons.group_rounded,
    },
    {
      'index': 9,
      'id': 'settings',
      'name': 'Settings',
      'icon': Icons.settings_rounded,
    },
  ];

  static List<int> getModuleIndicesForRole(String? roleStr) {
    final roleKey = (roleStr ?? 'staff').toLowerCase().trim();
    switch (roleKey) {
      case 'admin':
        // Master Admin: Full unrestricted access to all 10 modules
        return [0, 1, 2, 3, 4, 5, 6, 7, 8, 9];
      case 'manager':
        // Store Manager: Store operations (No sensitive Users or Settings)
        return [0, 1, 2, 3, 4, 5, 6, 7];
      case 'cashier':
        // Cashier / Billing Staff: Counter POS billing, invoices & customers
        return [1, 2, 5];
      case 'stock_manager':
        // Stock / Inventory Manager: Inventory, purchase orders, vendors & dashboard
        return [0, 3, 4, 6];
      case 'accountant':
        // Accountant: Financial ledgers, sales audits, purchase records & reports
        return [0, 2, 3, 7];
      case 'sales':
        // Sales Executive: Counter billing, sales orders, customers & dashboard
        return [0, 1, 2, 5];
      case 'staff':
      default:
        // General Staff: Counter POS billing, product lookup & customers
        return [1, 4, 5];
    }
  }

  static List<int> getUserAllowedModuleIndices(Map<String, dynamic> u) {
    final permsRaw = u['permissions'];
    if (permsRaw != null) {
      if (permsRaw is List) {
        final list = permsRaw
            .map((e) => int.tryParse(e.toString()))
            .whereType<int>()
            .where((i) => i >= 0 && i <= 9)
            .toSet()
            .toList();
        if (list.isNotEmpty) {
          list.sort();
          return list;
        }
      } else if (permsRaw is String && permsRaw.trim().isNotEmpty) {
        try {
          final decoded = jsonDecode(permsRaw);
          if (decoded is List) {
            final list = decoded
                .map((e) => int.tryParse(e.toString()))
                .whereType<int>()
                .where((i) => i >= 0 && i <= 9)
                .toSet()
                .toList();
            if (list.isNotEmpty) {
              list.sort();
              return list;
            }
          }
        } catch (_) {}
      }
    }
    return getModuleIndicesForRole(u['role']?.toString());
  }

  static const List<Map<String, dynamic>> systemRoles = [
    {
      'id': 'admin',
      'label': 'Admin',
      'shortLabel': 'Admin',
      'tag': 'Full Access',
      'description': 'Full access to all 10 modules, users & system settings',
      'color': Color(0xFF7C3AED),
      'bgColor': Color(0xFFF3E8FF),
      'borderColor': Color(0xFFDDD6FE),
      'icon': Icons.admin_panel_settings_rounded,
    },
    {
      'id': 'manager',
      'label': 'Store Manager',
      'shortLabel': 'Manager',
      'tag': 'Store Ops',
      'description':
          'Store operations, inventory, sales & reports (No Users or Settings)',
      'color': Color(0xFF2563EB),
      'bgColor': Color(0xFFEFF6FF),
      'borderColor': Color(0xFFBFDBFE),
      'icon': Icons.manage_accounts_rounded,
    },
    {
      'id': 'cashier',
      'label': 'Cashier / Billing',
      'shortLabel': 'Cashier',
      'tag': 'POS Counter',
      'description': 'POS counter billing, customer sales bills & receipts',
      'color': Color(0xFF059669),
      'bgColor': Color(0xFFECFDF5),
      'borderColor': Color(0xFFA7F3D0),
      'icon': Icons.point_of_sale_rounded,
    },
    {
      'id': 'stock_manager',
      'label': 'Stock / Inventory Manager',
      'shortLabel': 'Stock Mgr',
      'tag': 'Inventory',
      'description':
          'Products & paint catalogue, stock adjustments & supplier purchases',
      'color': Color(0xFFD97706),
      'bgColor': Color(0xFFFEF3C7),
      'borderColor': Color(0xFFFDE68A),
      'icon': Icons.inventory_2_rounded,
    },
    {
      'id': 'accountant',
      'label': 'Accountant',
      'shortLabel': 'Accountant',
      'tag': 'Audit & Tax',
      'description':
          'Financial ledgers, sales audits, purchase records & tax reports',
      'color': Color(0xFF0D9488),
      'bgColor': Color(0xFFCCFBF1),
      'borderColor': Color(0xFF99F6E4),
      'icon': Icons.account_balance_rounded,
    },
    {
      'id': 'sales',
      'label': 'Sales Executive',
      'shortLabel': 'Sales',
      'tag': 'Sales Ops',
      'description': 'Customer orders, counter billing & price inquiries',
      'color': Color(0xFFE11D48),
      'bgColor': Color(0xFFFFE4E6),
      'borderColor': Color(0xFFFECDD3),
      'icon': Icons.campaign_rounded,
    },
    {
      'id': 'staff',
      'label': 'General Staff',
      'shortLabel': 'Staff',
      'tag': 'Store Staff',
      'description':
          'Counter billing assistance, product lookup & customer support',
      'color': Color(0xFF475569),
      'bgColor': Color(0xFFF1F5F9),
      'borderColor': Color(0xFFE2E8F0),
      'icon': Icons.badge_rounded,
    },
  ];

  Widget _buildRoleBadge(String? roleStr) {
    final roleKey = (roleStr ?? 'staff').toLowerCase().trim();
    final roleInfo = systemRoles.firstWhere(
      (r) => r['id'] == roleKey,
      orElse: () => {
        'id': roleKey,
        'label': roleKey.toUpperCase(),
        'shortLabel': roleKey.toUpperCase(),
        'color': const Color(0xFF475569),
        'bgColor': const Color(0xFFF1F5F9),
        'borderColor': const Color(0xFFE2E8F0),
        'icon': Icons.badge_rounded,
      },
    );

    final displayLabel =
        (roleInfo['shortLabel'] ?? roleInfo['label'] ?? roleKey)
            .toString()
            .toUpperCase();

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3.5),
      decoration: BoxDecoration(
        color: roleInfo['bgColor'] as Color,
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: roleInfo['borderColor'] as Color),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        mainAxisAlignment: MainAxisAlignment.start,
        children: [
          Icon(
            roleInfo['icon'] as IconData,
            size: 12,
            color: roleInfo['color'] as Color,
          ),
          const SizedBox(width: 5),
          Flexible(
            child: Text(
              displayLabel,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontSize: 10.5,
                fontWeight: FontWeight.w700,
                color: roleInfo['color'] as Color,
                letterSpacing: 0.3,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Color _getRoleColor(String? roleStr) {
    final roleKey = (roleStr ?? 'staff').toLowerCase().trim();
    final roleInfo = systemRoles.firstWhere(
      (r) => r['id'] == roleKey,
      orElse: () => {'color': sidebarBlue},
    );
    return roleInfo['color'] as Color;
  }

  @override
  void initState() {
    super.initState();
    _api = ApiService(token: widget.token, customBaseUrl: widget.apiBaseUrl);
    _loadUsers();
  }

  Future<void> _loadUsers() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final res = await _api.get('/users');
      if (!mounted) return;
      setState(() {
        _users = res['data'] is List ? res['data'] : [];
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

  List<dynamic> get _filteredUsers {
    if (_searchQuery.trim().isEmpty) return _users;
    final q = _searchQuery.toLowerCase();
    return _users.where((u) {
      final name = (u['name'] ?? '').toString().toLowerCase();
      final email = (u['email'] ?? '').toString().toLowerCase();
      final role = (u['role'] ?? '').toString().toLowerCase();
      return name.contains(q) || email.contains(q) || role.contains(q);
    }).toList();
  }

  int get _adminCount => _users
      .where(
        (u) => [
          'admin',
          'manager',
        ].contains((u['role'] ?? '').toString().toLowerCase()),
      )
      .length;
  int get _staffCount => _users
      .where(
        (u) => ![
          'admin',
          'manager',
        ].contains((u['role'] ?? '').toString().toLowerCase()),
      )
      .length;

  // --- ADD / EDIT USER & PERMISSIONS DIALOG (ULTRA-PREMIUM TWO-PANEL RBAC SUITE) ---
  void _showUserDialog({Map<String, dynamic>? user, bool accessOnly = false}) {
    final isEditing = user != null;
    final nameCtrl = TextEditingController(
      text: user?['name']?.toString() ?? '',
    );
    final emailCtrl = TextEditingController(
      text: user?['email']?.toString() ?? '',
    );
    final passwordCtrl = TextEditingController();
    String role = (user?['role']?.toString() ?? 'staff').toLowerCase().trim();
    bool obscurePassword = true;

    // Admin can freely toggle/customize every module access for this user
    Set<int> selectedModuleIndices = (user != null)
        ? getUserAllowedModuleIndices(user).toSet()
        : getModuleIndicesForRole(role).toSet();

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => StatefulBuilder(
        builder: (dialogCtx, setDialogState) {
          final allowedCount = selectedModuleIndices.length;
          final roleInfo = systemRoles.firstWhere(
            (r) => r['id'] == role,
            orElse: () => systemRoles.last,
          );
          final roleColor = roleInfo['color'] as Color;
          final roleBg = roleInfo['bgColor'] as Color;

          return Dialog(
            backgroundColor: Colors.transparent,
            insetPadding: const EdgeInsets.symmetric(
              horizontal: 16,
              vertical: 24,
            ),
            child: Container(
              constraints: const BoxConstraints(maxWidth: 980, maxHeight: 740),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(20),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.14),
                    blurRadius: 28,
                    offset: const Offset(0, 10),
                  ),
                ],
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // 1. MODAL HEADER
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 24,
                      vertical: 18,
                    ),
                    decoration: const BoxDecoration(
                      border: Border(
                        bottom: BorderSide(color: Color(0xFFF1F5F9)),
                      ),
                    ),
                    child: Row(
                      children: [
                        Container(
                          width: 44,
                          height: 44,
                          decoration: BoxDecoration(
                            gradient: const LinearGradient(
                              colors: [Color(0xFF1E40AF), Color(0xFF3B82F6)],
                              begin: Alignment.topLeft,
                              end: Alignment.bottomRight,
                            ),
                            borderRadius: BorderRadius.circular(12),
                            boxShadow: [
                              BoxShadow(
                                color: const Color(0xFF1E40AF)
                                    .withValues(alpha: 0.25),
                                blurRadius: 8,
                                offset: const Offset(0, 3),
                              ),
                            ],
                          ),
                          child: const Icon(
                            Icons.shield_rounded,
                            color: Colors.white,
                            size: 24,
                          ),
                        ),
                        const SizedBox(width: 14),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                isEditing
                                    ? (accessOnly
                                          ? 'Manage User Role & Custom Access'
                                          : 'Edit User Account & Custom Permissions')
                                    : 'Add New User & Assign Custom Access',
                                style: const TextStyle(
                                  fontWeight: FontWeight.w800,
                                  fontSize: 18,
                                  color: Color(0xFF0F172A),
                                  letterSpacing: -0.3,
                                ),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                isEditing
                                    ? 'Personally check/uncheck module permissions for ${user['name'] ?? 'User'}.'
                                    : 'Create staff credentials and choose exactly which modules this user can access.',
                                style: const TextStyle(
                                  fontSize: 12,
                                  color: Color(0xFF64748B),
                                ),
                              ),
                            ],
                          ),
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 10,
                            vertical: 4,
                          ),
                          decoration: BoxDecoration(
                            color: roleBg,
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(
                              color: roleInfo['borderColor'] as Color,
                            ),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(
                                roleInfo['icon'] as IconData,
                                size: 14,
                                color: roleColor,
                              ),
                              const SizedBox(width: 6),
                              Text(
                                (roleInfo['label'] as String).toUpperCase(),
                                style: TextStyle(
                                  fontSize: 11,
                                  fontWeight: FontWeight.w800,
                                  color: roleColor,
                                  letterSpacing: 0.5,
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(width: 12),
                        IconButton(
                          icon: const Icon(
                            Icons.close_rounded,
                            size: 20,
                            color: Color(0xFF94A3B8),
                          ),
                          onPressed: () => Navigator.pop(dialogCtx),
                        ),
                      ],
                    ),
                  ),

                  // 2. MODAL BODY (TWO-PANEL MASTER WORKSPACE)
                  Expanded(
                    child: LayoutBuilder(
                      builder: (context, constraints) {
                        final isDesktop = constraints.maxWidth >= 720;

                        if (isDesktop) {
                          // SIDE-BY-SIDE SPLIT VIEW
                          return Row(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              // LEFT PANEL: CREDENTIALS & ROLES SELECTOR
                              Expanded(
                                flex: 5,
                                child: Container(
                                  padding: const EdgeInsets.all(22),
                                  decoration: const BoxDecoration(
                                    border: Border(
                                      right: BorderSide(
                                        color: Color(0xFFF1F5F9),
                                      ),
                                    ),
                                  ),
                                  child: SingleChildScrollView(
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.stretch,
                                      children: [
                                        if (!accessOnly) ...[
                                          _buildSectionTitle(
                                            '1. Staff Credentials',
                                            Icons.badge_rounded,
                                          ),
                                          const SizedBox(height: 12),
                                          _buildCustomField(
                                            controller: nameCtrl,
                                            label: 'Full Name *',
                                            hint: 'e.g. Ramesh Kumar',
                                            icon: Icons.person_outline_rounded,
                                          ),
                                          const SizedBox(height: 12),
                                          _buildCustomField(
                                            controller: emailCtrl,
                                            label: 'Email Address (Used for Login) *',
                                            hint: 'e.g. staff@paintshop.com',
                                            icon: Icons.alternate_email_rounded,
                                            keyboardType:
                                                TextInputType.emailAddress,
                                          ),
                                          const SizedBox(height: 12),
                                          _buildCustomField(
                                            controller: passwordCtrl,
                                            label: isEditing
                                                ? 'Reset Password (optional)'
                                                : 'Login Password *',
                                            hint: '••••••••',
                                            icon: Icons.lock_outline_rounded,
                                            obscureText: obscurePassword,
                                            suffixIcon: IconButton(
                                              icon: Icon(
                                                obscurePassword
                                                    ? Icons
                                                          .visibility_off_rounded
                                                    : Icons.visibility_rounded,
                                                size: 18,
                                                color: const Color(0xFF94A3B8),
                                              ),
                                              onPressed: () => setDialogState(
                                                () => obscurePassword =
                                                    !obscurePassword,
                                              ),
                                            ),
                                          ),
                                          const SizedBox(height: 20),
                                        ],

                                        _buildSectionTitle(
                                          '2. System Role Preset',
                                          Icons.security_rounded,
                                        ),
                                        const SizedBox(height: 6),
                                        const Text(
                                          'Select a preset role below to auto-fill permissions, or customize each module manually on the right:',
                                          style: TextStyle(
                                            fontSize: 11,
                                            color: Color(0xFF64748B),
                                          ),
                                        ),
                                        const SizedBox(height: 10),

                                        // COMPACT ROLE PICKER TILES
                                        ...systemRoles.map((r) {
                                          final isSelected = r['id'] == role;
                                          final rColor = r['color'] as Color;
                                          final rBg = r['bgColor'] as Color;

                                          return Padding(
                                            padding: const EdgeInsets.only(
                                              bottom: 7,
                                            ),
                                            child: InkWell(
                                              onTap: () => setDialogState(() {
                                                role = r['id'] as String;
                                                selectedModuleIndices =
                                                    getModuleIndicesForRole(
                                                      role,
                                                    ).toSet();
                                              }),
                                              borderRadius:
                                                  BorderRadius.circular(10),
                                              child: AnimatedContainer(
                                                duration: const Duration(
                                                  milliseconds: 180,
                                                ),
                                                padding:
                                                    const EdgeInsets.symmetric(
                                                      horizontal: 12,
                                                      vertical: 9,
                                                    ),
                                                decoration: BoxDecoration(
                                                  color: isSelected
                                                      ? rBg.withValues(
                                                          alpha: 0.4,
                                                        )
                                                      : const Color(0xFFF8FAFC),
                                                  borderRadius:
                                                      BorderRadius.circular(10),
                                                  border: Border.all(
                                                    color: isSelected
                                                        ? rColor
                                                        : const Color(
                                                            0xFFE2E8F0,
                                                          ),
                                                    width: isSelected ? 1.6 : 1,
                                                  ),
                                                ),
                                                child: Row(
                                                  children: [
                                                    Container(
                                                      width: 32,
                                                      height: 32,
                                                      decoration: BoxDecoration(
                                                        color: isSelected
                                                            ? rColor
                                                            : Colors.white,
                                                        borderRadius:
                                                            BorderRadius.circular(
                                                              8,
                                                            ),
                                                        border: isSelected
                                                            ? null
                                                            : Border.all(
                                                                color:
                                                                    const Color(
                                                                      0xFFE2E8F0,
                                                                    ),
                                                              ),
                                                      ),
                                                      child: Icon(
                                                        r['icon'] as IconData,
                                                        size: 16,
                                                        color: isSelected
                                                            ? Colors.white
                                                            : rColor,
                                                      ),
                                                    ),
                                                    const SizedBox(width: 10),
                                                    Expanded(
                                                      child: Column(
                                                        crossAxisAlignment:
                                                            CrossAxisAlignment
                                                                .start,
                                                        children: [
                                                          Row(
                                                            children: [
                                                              Text(
                                                                r['label']
                                                                    as String,
                                                                style: TextStyle(
                                                                  fontWeight:
                                                                      FontWeight
                                                                          .w700,
                                                                  fontSize:
                                                                      12.5,
                                                                  color:
                                                                      isSelected
                                                                      ? const Color(
                                                                          0xFF0F172A,
                                                                        )
                                                                      : const Color(
                                                                          0xFF334155,
                                                                        ),
                                                                ),
                                                              ),
                                                              const SizedBox(
                                                                width: 6,
                                                              ),
                                                              Container(
                                                                padding:
                                                                    const EdgeInsets.symmetric(
                                                                      horizontal:
                                                                          5,
                                                                      vertical:
                                                                          1,
                                                                    ),
                                                                decoration: BoxDecoration(
                                                                  color: rBg,
                                                                  borderRadius:
                                                                      BorderRadius.circular(
                                                                        4,
                                                                      ),
                                                                  border: Border.all(
                                                                    color:
                                                                        r['borderColor']
                                                                            as Color,
                                                                  ),
                                                                ),
                                                                child: Text(
                                                                  (r['tag']
                                                                          as String)
                                                                      .toUpperCase(),
                                                                  style: TextStyle(
                                                                    fontSize:
                                                                        8.5,
                                                                    fontWeight:
                                                                        FontWeight
                                                                            .w800,
                                                                    color:
                                                                        rColor,
                                                                  ),
                                                                ),
                                                              ),
                                                            ],
                                                          ),
                                                          Text(
                                                            r['description']
                                                                as String,
                                                            maxLines: 1,
                                                            overflow:
                                                                TextOverflow
                                                                    .ellipsis,
                                                            style:
                                                                const TextStyle(
                                                                  fontSize:
                                                                      10.5,
                                                                  color: Color(
                                                                    0xFF64748B,
                                                                  ),
                                                                ),
                                                          ),
                                                        ],
                                                      ),
                                                    ),
                                                    Container(
                                                      width: 18,
                                                      height: 18,
                                                      decoration: BoxDecoration(
                                                        shape: BoxShape.circle,
                                                        color: isSelected
                                                            ? rColor
                                                            : Colors
                                                                  .transparent,
                                                        border: Border.all(
                                                          color: isSelected
                                                              ? rColor
                                                              : const Color(
                                                                  0xFFCBD5E1,
                                                                ),
                                                          width: 1.5,
                                                        ),
                                                      ),
                                                      child: isSelected
                                                          ? const Icon(
                                                              Icons.check,
                                                              size: 12,
                                                              color:
                                                                  Colors.white,
                                                            )
                                                          : null,
                                                    ),
                                                  ],
                                                ),
                                              ),
                                            ),
                                          );
                                        }),
                                      ],
                                    ),
                                  ),
                                ),
                              ),

                              // RIGHT PANEL: INTERACTIVE MODULE ACCESS CONTROLLER
                              Expanded(
                                flex: 6,
                                child: Container(
                                  padding: const EdgeInsets.all(22),
                                  color: const Color(0xFFF8FAFC),
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.stretch,
                                    children: [
                                      // Module Access Header & Quick Presets
                                      Container(
                                        padding: const EdgeInsets.all(14),
                                        decoration: BoxDecoration(
                                          color: Colors.white,
                                          borderRadius: BorderRadius.circular(
                                            12,
                                          ),
                                          border: Border.all(
                                            color: const Color(0xFFE2E8F0),
                                          ),
                                          boxShadow: [
                                            BoxShadow(
                                              color: Colors.black.withValues(
                                                alpha: 0.02,
                                              ),
                                              blurRadius: 6,
                                              offset: const Offset(0, 2),
                                            ),
                                          ],
                                        ),
                                        child: Column(
                                          crossAxisAlignment:
                                              CrossAxisAlignment.start,
                                          children: [
                                            Row(
                                              mainAxisAlignment:
                                                  MainAxisAlignment
                                                      .spaceBetween,
                                              children: [
                                                Expanded(
                                                  child: Row(
                                                    children: [
                                                      const Icon(
                                                        Icons.tune_rounded,
                                                        size: 17,
                                                        color: Color(
                                                          0xFF1E40AF,
                                                        ),
                                                      ),
                                                      const SizedBox(width: 6),
                                                      const Flexible(
                                                        child: Text(
                                                          'Module Permissions',
                                                          style: TextStyle(
                                                            fontWeight:
                                                                FontWeight.w800,
                                                            fontSize: 13,
                                                            color: Color(
                                                              0xFF0F172A,
                                                            ),
                                                          ),
                                                          overflow: TextOverflow
                                                              .ellipsis,
                                                        ),
                                                      ),
                                                      const SizedBox(width: 6),
                                                      Container(
                                                        padding:
                                                            const EdgeInsets.symmetric(
                                                              horizontal: 6,
                                                              vertical: 2,
                                                            ),
                                                        decoration: BoxDecoration(
                                                          color:
                                                              allowedCount == 10
                                                              ? const Color(
                                                                  0xFFDCFCE7,
                                                                )
                                                              : (allowedCount ==
                                                                        0
                                                                    ? const Color(
                                                                        0xFFFEE2E2,
                                                                      )
                                                                    : const Color(
                                                                        0xFFEFF6FF,
                                                                      )),
                                                          borderRadius:
                                                              BorderRadius.circular(
                                                                6,
                                                              ),
                                                          border: Border.all(
                                                            color:
                                                                allowedCount ==
                                                                    10
                                                                ? const Color(
                                                                    0xFF86EFAC,
                                                                  )
                                                                : (allowedCount ==
                                                                          0
                                                                      ? const Color(
                                                                          0xFFFCA5A5,
                                                                        )
                                                                      : const Color(
                                                                          0xFFBFDBFE,
                                                                        )),
                                                          ),
                                                        ),
                                                        child: Text(
                                                          '$allowedCount / 10 Allowed',
                                                          style: TextStyle(
                                                            fontSize: 10,
                                                            fontWeight:
                                                                FontWeight.w800,
                                                            color:
                                                                allowedCount ==
                                                                    10
                                                                ? const Color(
                                                                    0xFF15803D,
                                                                  )
                                                                : (allowedCount ==
                                                                          0
                                                                      ? const Color(
                                                                          0xFFB91C1C,
                                                                        )
                                                                      : const Color(
                                                                          0xFF1D4ED8,
                                                                        )),
                                                          ),
                                                        ),
                                                      ),
                                                    ],
                                                  ),
                                                ),
                                                const SizedBox(width: 8),
                                                // Quick Selection Chips
                                                Row(
                                                  mainAxisSize:
                                                      MainAxisSize.min,
                                                  children: [
                                                    InkWell(
                                                      onTap: () => setDialogState(() {
                                                        selectedModuleIndices =
                                                            List.generate(
                                                              allModules.length,
                                                              (i) => i,
                                                            ).toSet();
                                                      }),
                                                      borderRadius:
                                                          BorderRadius.circular(
                                                            6,
                                                          ),
                                                      child: Container(
                                                        padding:
                                                            const EdgeInsets.symmetric(
                                                              horizontal: 7,
                                                              vertical: 3.5,
                                                            ),
                                                        decoration: BoxDecoration(
                                                          color: const Color(
                                                            0xFFEFF6FF,
                                                          ),
                                                          borderRadius:
                                                              BorderRadius.circular(
                                                                6,
                                                              ),
                                                          border: Border.all(
                                                            color: const Color(
                                                              0xFFBFDBFE,
                                                            ),
                                                          ),
                                                        ),
                                                        child: const Text(
                                                          'Select All',
                                                          style: TextStyle(
                                                            fontSize: 10,
                                                            fontWeight:
                                                                FontWeight.bold,
                                                            color: Color(
                                                              0xFF1D4ED8,
                                                            ),
                                                          ),
                                                        ),
                                                      ),
                                                    ),
                                                    const SizedBox(width: 5),
                                                    InkWell(
                                                      onTap: () =>
                                                          setDialogState(() {
                                                            selectedModuleIndices
                                                                .clear();
                                                          }),
                                                      borderRadius:
                                                          BorderRadius.circular(
                                                            6,
                                                          ),
                                                      child: Container(
                                                        padding:
                                                            const EdgeInsets.symmetric(
                                                              horizontal: 7,
                                                              vertical: 3.5,
                                                            ),
                                                        decoration: BoxDecoration(
                                                          color: const Color(
                                                            0xFFF1F5F9,
                                                          ),
                                                          borderRadius:
                                                              BorderRadius.circular(
                                                                6,
                                                              ),
                                                          border: Border.all(
                                                            color: const Color(
                                                              0xFFCBD5E1,
                                                            ),
                                                          ),
                                                        ),
                                                        child: const Text(
                                                          'Clear All',
                                                          style: TextStyle(
                                                            fontSize: 10,
                                                            fontWeight:
                                                                FontWeight.bold,
                                                            color: Color(
                                                              0xFF475569,
                                                            ),
                                                          ),
                                                        ),
                                                      ),
                                                    ),
                                                  ],
                                                ),
                                              ],
                                            ),
                                            const SizedBox(height: 4),
                                            const Text(
                                              'Click on any module card below to personally check/uncheck access for this user.',
                                              style: TextStyle(
                                                fontSize: 11,
                                                color: Color(0xFF64748B),
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                      const SizedBox(height: 12),

                                      // 10 MODULES INTERACTIVE GRID (Clickable with Checkboxes)
                                      Expanded(
                                        child: GridView.builder(
                                          itemCount: allModules.length,
                                          gridDelegate:
                                              const SliverGridDelegateWithFixedCrossAxisCount(
                                                crossAxisCount: 2,
                                                crossAxisSpacing: 10,
                                                mainAxisSpacing: 10,
                                                childAspectRatio: 2.8,
                                              ),
                                          itemBuilder: (context, index) {
                                            final mod = allModules[index];
                                            final idx = mod['index'] as int;
                                            final isAllowed =
                                                selectedModuleIndices.contains(
                                                  idx,
                                                );

                                            return Material(
                                              color: Colors.transparent,
                                              child: InkWell(
                                                onTap: () {
                                                  setDialogState(() {
                                                    if (isAllowed) {
                                                      selectedModuleIndices
                                                          .remove(idx);
                                                    } else {
                                                      selectedModuleIndices.add(
                                                        idx,
                                                      );
                                                    }
                                                  });
                                                },
                                                borderRadius:
                                                    BorderRadius.circular(10),
                                                child: AnimatedContainer(
                                                  duration: const Duration(
                                                    milliseconds: 180,
                                                  ),
                                                  padding:
                                                      const EdgeInsets.symmetric(
                                                        horizontal: 10,
                                                        vertical: 8,
                                                      ),
                                                  decoration: BoxDecoration(
                                                    color: isAllowed
                                                        ? Colors.white
                                                        : const Color(
                                                            0xFFF8FAFC,
                                                          ),
                                                    borderRadius:
                                                        BorderRadius.circular(
                                                          10,
                                                        ),
                                                    border: Border.all(
                                                      color: isAllowed
                                                          ? const Color(
                                                              0xFF10B981,
                                                            )
                                                          : const Color(
                                                              0xFFE2E8F0,
                                                            ),
                                                      width: isAllowed
                                                          ? 1.6
                                                          : 1,
                                                    ),
                                                    boxShadow: isAllowed
                                                        ? [
                                                            BoxShadow(
                                                              color:
                                                                  const Color(
                                                                    0xFF10B981,
                                                                  ).withValues(
                                                                    alpha: 0.10,
                                                                  ),
                                                              blurRadius: 6,
                                                              offset:
                                                                  const Offset(
                                                                    0,
                                                                    2,
                                                                  ),
                                                            ),
                                                          ]
                                                        : null,
                                                  ),
                                                  child: Row(
                                                    children: [
                                                      // Module Icon
                                                      Container(
                                                        width: 28,
                                                        height: 28,
                                                        decoration: BoxDecoration(
                                                          color: isAllowed
                                                              ? const Color(
                                                                  0xFFECFDF5,
                                                                )
                                                              : const Color(
                                                                  0xFFE2E8F0,
                                                                ),
                                                          borderRadius:
                                                              BorderRadius.circular(
                                                                6,
                                                              ),
                                                        ),
                                                        child: Icon(
                                                          mod['icon']
                                                              as IconData,
                                                          size: 15,
                                                          color: isAllowed
                                                              ? const Color(
                                                                  0xFF059669,
                                                                )
                                                              : const Color(
                                                                  0xFF94A3B8,
                                                                ),
                                                        ),
                                                      ),
                                                      const SizedBox(width: 8),
                                                      // Module Title & State
                                                      Expanded(
                                                        child: Column(
                                                          mainAxisAlignment:
                                                              MainAxisAlignment
                                                                  .center,
                                                          crossAxisAlignment:
                                                              CrossAxisAlignment
                                                                  .start,
                                                          children: [
                                                            Text(
                                                              mod['name']
                                                                  as String,
                                                              style: TextStyle(
                                                                fontSize: 11.5,
                                                                fontWeight:
                                                                    isAllowed
                                                                    ? FontWeight
                                                                          .w700
                                                                    : FontWeight
                                                                          .w500,
                                                                color: isAllowed
                                                                    ? const Color(
                                                                        0xFF0F172A,
                                                                      )
                                                                    : const Color(
                                                                        0xFF94A3B8,
                                                                      ),
                                                              ),
                                                              overflow:
                                                                  TextOverflow
                                                                      .ellipsis,
                                                            ),
                                                            Text(
                                                              isAllowed
                                                                  ? 'Allowed'
                                                                  : 'Restricted',
                                                              style: TextStyle(
                                                                fontSize: 9.5,
                                                                fontWeight:
                                                                    FontWeight
                                                                        .w700,
                                                                color: isAllowed
                                                                    ? const Color(
                                                                        0xFF059669,
                                                                      )
                                                                    : const Color(
                                                                        0xFF94A3B8,
                                                                      ),
                                                              ),
                                                            ),
                                                          ],
                                                        ),
                                                      ),
                                                      // Interactive Checkbox
                                                      Container(
                                                        width: 20,
                                                        height: 20,
                                                        decoration: BoxDecoration(
                                                          color: isAllowed
                                                              ? const Color(
                                                                  0xFF10B981,
                                                                )
                                                              : Colors.white,
                                                          borderRadius:
                                                              BorderRadius.circular(
                                                                5,
                                                              ),
                                                          border: Border.all(
                                                            color: isAllowed
                                                                ? const Color(
                                                                    0xFF10B981,
                                                                  )
                                                                : const Color(
                                                                    0xFFCBD5E1,
                                                                  ),
                                                            width: 1.5,
                                                          ),
                                                        ),
                                                        child: isAllowed
                                                            ? const Icon(
                                                                Icons.check,
                                                                size: 14,
                                                                color: Colors
                                                                    .white,
                                                              )
                                                            : null,
                                                      ),
                                                    ],
                                                  ),
                                                ),
                                              ),
                                            );
                                          },
                                        ),
                                      ),

                                      // Bottom Security Callout
                                      Container(
                                        padding: const EdgeInsets.symmetric(
                                          horizontal: 12,
                                          vertical: 8,
                                        ),
                                        decoration: BoxDecoration(
                                          color: const Color(0xFFEFF6FF),
                                          borderRadius: BorderRadius.circular(
                                            8,
                                          ),
                                          border: Border.all(
                                            color: const Color(0xFFBFDBFE),
                                          ),
                                        ),
                                        child: Row(
                                          children: const [
                                            Icon(
                                              Icons.lock_person_rounded,
                                              size: 16,
                                              color: Color(0xFF1E40AF),
                                            ),
                                            SizedBox(width: 8),
                                            Expanded(
                                              child: Text(
                                                'Sidebar Enforcement: Only checked modules will be shown in this user\'s menu.',
                                                style: TextStyle(
                                                  fontSize: 11,
                                                  fontWeight: FontWeight.w600,
                                                  color: Color(0xFF1E40AF),
                                                ),
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            ],
                          );
                        }

                        // COMPACT MOBILE VIEW
                        return SingleChildScrollView(
                          padding: const EdgeInsets.all(16),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              if (!accessOnly) ...[
                                _buildCustomField(
                                  controller: nameCtrl,
                                  label: 'Full Name *',
                                  hint: 'Staff name',
                                  icon: Icons.person_outline_rounded,
                                ),
                                const SizedBox(height: 10),
                                _buildCustomField(
                                  controller: emailCtrl,
                                  label: 'Email Address *',
                                  hint: 'staff@gmail.com',
                                  icon: Icons.alternate_email_rounded,
                                ),
                                const SizedBox(height: 10),
                                _buildCustomField(
                                  controller: passwordCtrl,
                                  label: 'Password *',
                                  hint: '••••••••',
                                  icon: Icons.lock_outline_rounded,
                                  obscureText: true,
                                ),
                                const SizedBox(height: 16),
                              ],
                              const Text(
                                'Select Role Preset:',
                                style: TextStyle(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 13,
                                ),
                              ),
                              const SizedBox(height: 8),
                              ...systemRoles.map((r) {
                                final isSelected = r['id'] == role;
                                return ListTile(
                                  dense: true,
                                  tileColor: isSelected
                                      ? const Color(0xFFEFF6FF)
                                      : null,
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  leading: Icon(
                                    r['icon'] as IconData,
                                    color: r['color'] as Color,
                                  ),
                                  title: Text(
                                    r['label'] as String,
                                    style: const TextStyle(
                                      fontWeight: FontWeight.bold,
                                      fontSize: 13,
                                    ),
                                  ),
                                  subtitle: Text(
                                    r['description'] as String,
                                    style: const TextStyle(fontSize: 11),
                                  ),
                                  trailing: isSelected
                                      ? const Icon(
                                          Icons.check_circle,
                                          color: Color(0xFF1E40AF),
                                        )
                                      : null,
                                  onTap: () => setDialogState(() {
                                    role = r['id'] as String;
                                    selectedModuleIndices =
                                        getModuleIndicesForRole(role).toSet();
                                  }),
                                );
                              }),
                              const SizedBox(height: 16),
                              Row(
                                mainAxisAlignment:
                                    MainAxisAlignment.spaceBetween,
                                children: [
                                  const Text(
                                    'Custom Module Access:',
                                    style: TextStyle(
                                      fontWeight: FontWeight.bold,
                                      fontSize: 13,
                                    ),
                                  ),
                                  Text(
                                    '${selectedModuleIndices.length} / 10 Allowed',
                                    style: const TextStyle(
                                      fontWeight: FontWeight.bold,
                                      fontSize: 11,
                                      color: Color(0xFF1E40AF),
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 8),
                              Wrap(
                                spacing: 8,
                                runSpacing: 8,
                                children: allModules.map((mod) {
                                  final idx = mod['index'] as int;
                                  final isAllowed = selectedModuleIndices
                                      .contains(idx);
                                  return FilterChip(
                                    selected: isAllowed,
                                    avatar: Icon(
                                      mod['icon'] as IconData,
                                      size: 14,
                                      color: isAllowed
                                          ? Colors.white
                                          : Colors.black54,
                                    ),
                                    label: Text(
                                      mod['name'] as String,
                                      style: TextStyle(
                                        fontSize: 11,
                                        color: isAllowed
                                            ? Colors.white
                                            : Colors.black87,
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                    selectedColor: const Color(0xFF10B981),
                                    checkmarkColor: Colors.white,
                                    onSelected: (val) {
                                      setDialogState(() {
                                        if (val) {
                                          selectedModuleIndices.add(idx);
                                        } else {
                                          selectedModuleIndices.remove(idx);
                                        }
                                      });
                                    },
                                  );
                                }).toList(),
                              ),
                            ],
                          ),
                        );
                      },
                    ),
                  ),

                  // 3. MODAL FOOTER ACTIONS
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 24,
                      vertical: 14,
                    ),
                    decoration: const BoxDecoration(
                      color: Color(0xFFF8FAFC),
                      borderRadius: BorderRadius.only(
                        bottomLeft: Radius.circular(20),
                        bottomRight: Radius.circular(20),
                      ),
                      border: Border(top: BorderSide(color: Color(0xFFE2E8F0))),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Flexible(
                          child: Text(
                            '$allowedCount of 10 Modules Allowed (${role.toUpperCase()})',
                            style: const TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                              color: Color(0xFF64748B),
                            ),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        Row(
                          children: [
                            TextButton(
                              onPressed: () => Navigator.pop(dialogCtx),
                              child: const Text(
                                'Cancel',
                                style: TextStyle(
                                  color: Color(0xFF64748B),
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ),
                            const SizedBox(width: 10),
                            ElevatedButton.icon(
                              style: ElevatedButton.styleFrom(
                                backgroundColor: const Color(0xFF1E40AF),
                                foregroundColor: Colors.white,
                                elevation: 1,
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(10),
                                ),
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 20,
                                  vertical: 12,
                                ),
                              ),
                              icon: const Icon(Icons.check_rounded, size: 16),
                              onPressed: () async {
                                final name = nameCtrl.text.trim();
                                final email = emailCtrl.text.trim();
                                final pass = passwordCtrl.text.trim();

                                if (!accessOnly) {
                                  if (name.isEmpty || name.length < 2) {
                                    AppToast.showWarning(
                                      context,
                                      title: 'Invalid Name',
                                      message:
                                          'Please enter a valid full name.',
                                    );
                                    return;
                                  }

                                  if (email.isEmpty ||
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

                                  if (!isEditing && pass.length < 6) {
                                    AppToast.showWarning(
                                      context,
                                      title: 'Invalid Password',
                                      message: 'Password must be at least 6 characters.',
                                    );
                                    return;
                                  }
                                }

                                final sortedPerms =
                                    selectedModuleIndices.toList()..sort();
                                final payload = <String, dynamic>{
                                  'name': name.isEmpty
                                      ? (user?['name'] ?? 'User')
                                      : name,
                                  'email': email.isEmpty
                                      ? (user?['email'] ?? 'user@gmail.com')
                                      : email,
                                  'role': role,
                                  'permissions': sortedPerms,
                                };
                                if (pass.isNotEmpty) payload['password'] = pass;

                                Navigator.pop(dialogCtx);
                                try {
                                  if (isEditing) {
                                    await _api.put(
                                      '/users/${user['id']}',
                                      payload,
                                    );
                                  } else {
                                    await _api.post('/users', payload);
                                  }
                                  if (mounted) {
                                    AppToast.showSuccess(
                                      context,
                                      title: isEditing
                                          ? 'Access Updated!'
                                          : 'User Registered!',
                                      message: isEditing
                                          ? '$name custom access updated (${sortedPerms.length}/10 modules granted).'
                                          : '$name registered with ${sortedPerms.length}/10 modules granted.',
                                      duration: const Duration(
                                        milliseconds: 2200,
                                      ),
                                    );
                                    _loadUsers();
                                  }
                                } catch (e) {
                                  if (mounted) {
                                    AppToast.showError(
                                      context,
                                      title: isEditing
                                          ? 'Update Failed'
                                          : 'Creation Failed',
                                      message: e.toString().replaceAll(
                                        'Exception: ',
                                        '',
                                      ),
                                    );
                                  }
                                }
                              },
                              label: Text(
                                isEditing
                                    ? 'Save Role & Access'
                                    : 'Create User & Assign Access',
                                style: const TextStyle(
                                  fontWeight: FontWeight.bold,
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
          );
        },
      ),
    );
  }

  static Widget _buildSectionTitle(String title, IconData icon) {
    return Row(
      children: [
        Icon(icon, size: 16, color: const Color(0xFF1E40AF)),
        const SizedBox(width: 8),
        Text(
          title,
          style: const TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w800,
            color: Color(0xFF0F172A),
            letterSpacing: 0.2,
          ),
        ),
      ],
    );
  }

  static Widget _buildCustomField({
    required TextEditingController controller,
    required String label,
    required String hint,
    required IconData icon,
    TextInputType? keyboardType,
    bool obscureText = false,
    Widget? suffixIcon,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(
            fontSize: 11.5,
            fontWeight: FontWeight.w600,
            color: Color(0xFF334155),
          ),
        ),
        const SizedBox(height: 5),
        TextField(
          controller: controller,
          keyboardType: keyboardType,
          obscureText: obscureText,
          style: const TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w600,
            color: Color(0xFF0F172A),
          ),
          decoration: InputDecoration(
            hintText: hint,
            hintStyle: const TextStyle(fontSize: 12, color: Color(0xFF94A3B8)),
            prefixIcon: Icon(icon, size: 17, color: const Color(0xFF64748B)),
            suffixIcon: suffixIcon,
            filled: true,
            fillColor: const Color(0xFFF8FAFC),
            isDense: true,
            contentPadding: const EdgeInsets.symmetric(
              horizontal: 12,
              vertical: 11,
            ),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(9),
              borderSide: const BorderSide(color: Color(0xFFE2E8F0)),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(9),
              borderSide: const BorderSide(color: Color(0xFFE2E8F0)),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(9),
              borderSide: const BorderSide(
                color: Color(0xFF1E40AF),
                width: 1.5,
              ),
            ),
          ),
        ),
      ],
    );
  }

  // --- FULL ROLE & MODULE ACCESS PERMISSIONS GUIDE MODAL ---
  void _showRolePermissionsGuide() {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        titlePadding: const EdgeInsets.fromLTRB(20, 20, 20, 0),
        contentPadding: const EdgeInsets.fromLTRB(20, 16, 20, 16),
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
                Icons.security_rounded,
                color: sidebarBlue,
                size: 20,
              ),
            ),
            const SizedBox(width: 12),
            const Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Role Permissions & Access Guide',
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
                      color: Colors.black,
                    ),
                  ),
                  SizedBox(height: 2),
                  Text(
                    'Staff members strictly see and access only their assigned modules in sidebar.',
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
          width: 650,
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: systemRoles.map((r) {
                final roleId = r['id'] as String;
                final allowedIndices = getModuleIndicesForRole(roleId);
                final roleColor = r['color'] as Color;
                final roleBg = r['bgColor'] as Color;

                return Container(
                  margin: const EdgeInsets.only(bottom: 12),
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF8FAFC),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: const Color(0xFFE2E8F0)),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 10,
                              vertical: 4,
                            ),
                            decoration: BoxDecoration(
                              color: roleBg,
                              borderRadius: BorderRadius.circular(6),
                              border: Border.all(
                                color: r['borderColor'] as Color,
                              ),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(
                                  r['icon'] as IconData,
                                  size: 14,
                                  color: roleColor,
                                ),
                                const SizedBox(width: 6),
                                Text(
                                  r['label'] as String,
                                  style: TextStyle(
                                    fontSize: 12,
                                    fontWeight: FontWeight.bold,
                                    color: roleColor,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 8,
                              vertical: 2,
                            ),
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(
                                color: const Color(0xFFCBD5E1),
                              ),
                            ),
                            child: Text(
                              '${allowedIndices.length} / 10 Modules',
                              style: const TextStyle(
                                fontSize: 10.5,
                                fontWeight: FontWeight.bold,
                                color: Color(0xFF334155),
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 6),
                      Text(
                        r['description'] as String,
                        style: const TextStyle(
                          fontSize: 11.5,
                          color: Color(0xFF64748B),
                        ),
                      ),
                      const SizedBox(height: 8),
                      Wrap(
                        spacing: 6,
                        runSpacing: 6,
                        children: allModules.map((mod) {
                          final idx = mod['index'] as int;
                          final isAllowed = allowedIndices.contains(idx);

                          return Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 8,
                              vertical: 3,
                            ),
                            decoration: BoxDecoration(
                              color: isAllowed
                                  ? Colors.white
                                  : const Color(0xFFF1F5F9),
                              borderRadius: BorderRadius.circular(4),
                              border: Border.all(
                                color: isAllowed
                                    ? const Color(0xFF10B981)
                                    : const Color(0xFFCBD5E1),
                              ),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(
                                  isAllowed
                                      ? Icons.check_circle_rounded
                                      : Icons.lock_outline_rounded,
                                  size: 11,
                                  color: isAllowed
                                      ? const Color(0xFF10B981)
                                      : const Color(0xFF94A3B8),
                                ),
                                const SizedBox(width: 4),
                                Text(
                                  mod['name'] as String,
                                  style: TextStyle(
                                    fontSize: 10.5,
                                    fontWeight: isAllowed
                                        ? FontWeight.bold
                                        : FontWeight.normal,
                                    color: isAllowed
                                        ? const Color(0xFF0F172A)
                                        : const Color(0xFF94A3B8),
                                  ),
                                ),
                              ],
                            ),
                          );
                        }).toList(),
                      ),
                    ],
                  ),
                );
              }).toList(),
            ),
          ),
        ),
        actions: [
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: sidebarBlue,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
              ),
            ),
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Close Guide'),
          ),
        ],
      ),
    );
  }

  void _deleteUser(Map<String, dynamic> user) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        title: const Text(
          'Delete User Account?',
          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
        ),
        content: Text(
          'Are you sure you want to delete "${user['name']}"? This user will immediately lose system access.',
          style: const TextStyle(fontSize: 13, color: Colors.black87),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel', style: TextStyle(color: Colors.grey)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
              ),
            ),
            onPressed: () async {
              Navigator.pop(ctx);
              try {
                await _api.delete('/users/${user['id']}');
                if (mounted) {
                  AppToast.showSuccess(
                    context,
                    title: 'User Deleted',
                    message:
                        '${user['name']} has been removed from the system.',
                  );
                  _loadUsers();
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
            },
            child: const Text('Delete'),
          ),
        ],
      ),
    );
  }

  String _formatDate(dynamic dateVal) {
    if (dateVal == null) return '-';
    try {
      final str = dateVal.toString();
      if (str.length >= 10) return str.substring(0, 10);
      return str;
    } catch (_) {
      return '-';
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      color: background,
      child: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // 1. TOP SUMMARY METRIC CARDS
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
              child: ResponsiveSummaryGrid(
                spacing: 10,
                desktopBreakpoint: 900,
                tabletBreakpoint: 480,
                children: [
                  _buildSummaryBox(
                    title: 'Total Users',
                    value: '${_users.length} Accounts',
                    subtitle: '${systemRoles.length} Available roles',
                    icon: Icons.people_alt_rounded,
                    accentColor: sidebarBlue,
                  ),
                  _buildSummaryBox(
                    title: 'Admin & Managers',
                    value: '$_adminCount Leaders',
                    subtitle: 'Full system & store control',
                    icon: Icons.admin_panel_settings_rounded,
                    accentColor: const Color(0xFF7C3AED),
                  ),
                  _buildSummaryBox(
                    title: 'Operational Staff',
                    value: '$_staffCount Staff',
                    subtitle: 'Billing, stock, sales & accounts',
                    icon: Icons.badge_rounded,
                    accentColor: const Color(0xFF059669),
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
                  final compact = MediaQuery.sizeOf(context).width < 720;
                  final searchBox = TextField(
                    onChanged: (val) => setState(() => _searchQuery = val),
                    style: const TextStyle(color: Colors.black, fontSize: 13),
                    decoration: InputDecoration(
                      hintText: 'Search users by name, email, or role...',
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
                    onPressed: () => _showUserDialog(),
                    icon: const Icon(Icons.person_add_rounded, size: 17),
                    label: const Text('Add User'),
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
                  final guideBtn = OutlinedButton.icon(
                    onPressed: _showRolePermissionsGuide,
                    icon: const Icon(
                      Icons.shield_outlined,
                      size: 16,
                      color: sidebarBlue,
                    ),
                    label: const Text('Permissions Matrix'),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: sidebarBlue,
                      side: const BorderSide(color: Color(0xFFBFDBFE)),
                      backgroundColor: const Color(0xFFEFF6FF),
                      elevation: 0,
                      padding: const EdgeInsets.symmetric(
                        horizontal: 14,
                        vertical: 12,
                      ),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                    ),
                  );
                  final refreshBtn = IconButton(
                    tooltip: 'Refresh',
                    onPressed: _loadUsers,
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
                        Wrap(
                          spacing: 8,
                          runSpacing: 8,
                          children: [addBtn, guideBtn, refreshBtn],
                        ),
                      ],
                    );
                  }
                  return Row(
                    children: [
                      Expanded(child: searchBox),
                      const SizedBox(width: 12),
                      guideBtn,
                      const SizedBox(width: 8),
                      addBtn,
                      const SizedBox(width: 8),
                      refreshBtn,
                    ],
                  );
                },
              ),
            ),

            // 3. TABLE CARD WITH ACCESSIBLE MODULES COLUMN
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
                      Icons.error_outline_rounded,
                      color: Colors.red,
                      size: 36,
                    ),
                    const SizedBox(height: 12),
                    Text(
                      _errorMessage!,
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        color: Colors.black87,
                        fontSize: 13,
                      ),
                    ),
                    const SizedBox(height: 16),
                    ElevatedButton.icon(
                      onPressed: _loadUsers,
                      icon: const Icon(Icons.refresh_rounded, size: 16),
                      label: const Text('Try Again'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: sidebarBlue,
                        foregroundColor: Colors.white,
                      ),
                    ),
                  ],
                ),
              )
            else if (_filteredUsers.isEmpty)
              Container(
                margin: const EdgeInsets.symmetric(horizontal: 16),
                padding: const EdgeInsets.all(32),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: const Color(0xFFE5E7EB)),
                ),
                child: Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(
                        Icons.group_off_rounded,
                        size: 48,
                        color: Colors.black26,
                      ),
                      const SizedBox(height: 12),
                      const Text(
                        'No user accounts found',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 15,
                          color: Colors.black,
                        ),
                      ),
                      const SizedBox(height: 4),
                      const Text(
                        'Add staff or admin accounts to manage shop operations.',
                        style: TextStyle(fontSize: 12, color: Colors.grey),
                      ),
                      const SizedBox(height: 16),
                      ElevatedButton.icon(
                        onPressed: () => _showUserDialog(),
                        icon: const Icon(Icons.person_add_rounded, size: 16),
                        label: const Text('Create User'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: sidebarBlue,
                          foregroundColor: Colors.white,
                        ),
                      ),
                    ],
                  ),
                ),
              )
            else
              Container(
                margin: const EdgeInsets.fromLTRB(16, 0, 16, 24),
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
                clipBehavior: Clip.antiAlias,
                child: LayoutBuilder(
                  builder: (context, constraints) {
                    final isNarrow = constraints.maxWidth < 800;

                    if (isNarrow) {
                      // MOBILE / COMPACT CARD LIST
                      return Column(
                        children: List.generate(_filteredUsers.length, (idx) {
                          final u = _filteredUsers[idx];
                          final role = (u['role'] ?? 'staff')
                              .toString()
                              .toLowerCase();
                          final allowedIndices = getUserAllowedModuleIndices(u);

                          return Container(
                            padding: const EdgeInsets.all(14),
                            decoration: BoxDecoration(
                              border: Border(
                                bottom: BorderSide(
                                  color: idx == _filteredUsers.length - 1
                                      ? Colors.transparent
                                      : const Color(0xFFF1F5F9),
                                ),
                              ),
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  children: [
                                    CircleAvatar(
                                      radius: 16,
                                      backgroundColor: _getRoleColor(role)
                                          .withValues(alpha: 0.15),
                                      child: Text(
                                        (u['name'] ?? 'U')
                                            .toString()
                                            .substring(0, 1)
                                            .toUpperCase(),
                                        style: TextStyle(
                                          fontSize: 12,
                                          fontWeight: FontWeight.bold,
                                          color: _getRoleColor(role),
                                        ),
                                      ),
                                    ),
                                    const SizedBox(width: 10),
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                            u['name'] ?? '-',
                                            style: const TextStyle(
                                              fontWeight: FontWeight.bold,
                                              fontSize: 13.5,
                                            ),
                                          ),
                                          Text(
                                            u['email'] ?? '-',
                                            style: const TextStyle(
                                              fontSize: 12,
                                              color: Color(0xFF64748B),
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                    _buildRoleBadge(role),
                                  ],
                                ),
                                const SizedBox(height: 8),
                                Row(
                                  mainAxisAlignment:
                                      MainAxisAlignment.spaceBetween,
                                  children: [
                                    Flexible(
                                      child: Text(
                                        'Access: ${allowedIndices.length} of 10 Modules',
                                        style: const TextStyle(
                                          fontSize: 11,
                                          fontWeight: FontWeight.bold,
                                          color: Color(0xFF0F172A),
                                        ),
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                    ),
                                    Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        IconButton(
                                          constraints: const BoxConstraints(),
                                          padding: const EdgeInsets.all(6),
                                          splashRadius: 16,
                                          tooltip: 'Change Access',
                                          icon: const Icon(
                                            Icons.shield_rounded,
                                            size: 16,
                                            color: sidebarBlue,
                                          ),
                                          onPressed: () => _showUserDialog(
                                            user: u,
                                            accessOnly: true,
                                          ),
                                        ),
                                        const SizedBox(width: 4),
                                        IconButton(
                                          constraints: const BoxConstraints(),
                                          padding: const EdgeInsets.all(6),
                                          splashRadius: 16,
                                          tooltip: 'Edit User',
                                          icon: const Icon(
                                            Icons.edit_outlined,
                                            size: 16,
                                            color: sidebarBlue,
                                          ),
                                          onPressed: () =>
                                              _showUserDialog(user: u),
                                        ),
                                        const SizedBox(width: 4),
                                        IconButton(
                                          constraints: const BoxConstraints(),
                                          padding: const EdgeInsets.all(6),
                                          splashRadius: 16,
                                          tooltip: 'Delete User',
                                          icon: const Icon(
                                            Icons.delete_outline,
                                            size: 16,
                                            color: Colors.red,
                                          ),
                                          onPressed: () => _deleteUser(u),
                                        ),
                                      ],
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          );
                        }),
                      );
                    }

                    // DESKTOP FULL TABLE
                    return Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        // TABLE HEADER
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 20,
                            vertical: 12,
                          ),
                          decoration: const BoxDecoration(
                            color: Color(0xFFF9FAFB),
                            border: Border(
                              bottom: BorderSide(color: Color(0xFFE5E7EB)),
                            ),
                          ),
                          child: const Row(
                            children: [
                              Expanded(
                                flex: 3,
                                child: Text(
                                  'User',
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
                                flex: 2,
                                child: Text(
                                  'Role',
                                  style: TextStyle(
                                    fontWeight: FontWeight.bold,
                                    color: Colors.black,
                                    fontSize: 13,
                                  ),
                                ),
                              ),
                              Expanded(
                                flex: 4,
                                child: Text(
                                  'Accessible Modules',
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
                                  'Created At',
                                  style: TextStyle(
                                    fontWeight: FontWeight.bold,
                                    color: Colors.black,
                                    fontSize: 13,
                                  ),
                                ),
                              ),
                              SizedBox(
                                width: 124,
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

                        // DATA ROWS
                        ...List.generate(_filteredUsers.length, (idx) {
                          final u = _filteredUsers[idx];
                          final role = (u['role'] ?? 'staff')
                              .toString()
                              .toLowerCase();
                          final allowedIndices = getUserAllowedModuleIndices(u);

                          return Container(
                            decoration: BoxDecoration(
                              color: Colors.white,
                              border: Border(
                                bottom: BorderSide(
                                  color: idx == _filteredUsers.length - 1
                                      ? Colors.transparent
                                      : const Color(0xFFF3F4F6),
                                ),
                              ),
                            ),
                            padding: const EdgeInsets.symmetric(
                              horizontal: 20,
                              vertical: 12,
                            ),
                            child: Row(
                              children: [
                                // 1. User Avatar & Name
                                Expanded(
                                  flex: 3,
                                  child: Row(
                                    children: [
                                      CircleAvatar(
                                        radius: 14,
                                        backgroundColor: _getRoleColor(role)
                                            .withValues(alpha: 0.15),
                                        child: Text(
                                          (u['name'] ?? 'U')
                                              .toString()
                                              .substring(0, 1)
                                              .toUpperCase(),
                                          style: TextStyle(
                                            fontSize: 11,
                                            fontWeight: FontWeight.bold,
                                            color: _getRoleColor(role),
                                          ),
                                        ),
                                      ),
                                      const SizedBox(width: 10),
                                      Flexible(
                                        child: Text(
                                          u['name'] ?? '-',
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

                                // 2. Email
                                Expanded(
                                  flex: 3,
                                  child: Row(
                                    children: [
                                      const Icon(
                                        Icons.mail_outline_rounded,
                                        size: 14,
                                        color: Colors.black45,
                                      ),
                                      const SizedBox(width: 6),
                                      Flexible(
                                        child: Text(
                                          u['email'] ?? '-',
                                          style: const TextStyle(
                                            color: Colors.black87,
                                            fontSize: 13,
                                          ),
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),

                                // 3. Role Badge
                                Expanded(
                                  flex: 2,
                                  child: Align(
                                    alignment: Alignment.centerLeft,
                                    child: _buildRoleBadge(role),
                                  ),
                                ),

                                // 4. ACCESSIBLE MODULES CHIPS
                                Expanded(
                                  flex: 4,
                                  child: InkWell(
                                    onTap: () => _showUserDialog(
                                      user: u,
                                      accessOnly: true,
                                    ),
                                    borderRadius: BorderRadius.circular(6),
                                    child: Container(
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 6,
                                        vertical: 4,
                                      ),
                                      child: _buildAccessibleModulesSummary(
                                        allowedIndices,
                                      ),
                                    ),
                                  ),
                                ),

                                // 5. Created At
                                Expanded(
                                  flex: 2,
                                  child: Text(
                                    _formatDate(u['created_at']),
                                    style: const TextStyle(
                                      color: Color(0xFF4B5563),
                                      fontSize: 12,
                                    ),
                                    overflow: TextOverflow.ellipsis,
                                    maxLines: 1,
                                  ),
                                ),

                                // 6. Actions (Access, Edit, Delete)
                                SizedBox(
                                  width: 124,
                                  child: Row(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      IconButton(
                                        constraints: const BoxConstraints(),
                                        padding: const EdgeInsets.all(6),
                                        splashRadius: 16,
                                        tooltip: 'Role & Module Access',
                                        icon: const Icon(
                                          Icons.shield_rounded,
                                          size: 16,
                                          color: sidebarBlue,
                                        ),
                                        onPressed: () => _showUserDialog(
                                          user: u,
                                          accessOnly: true,
                                        ),
                                      ),
                                      const SizedBox(width: 4),
                                      IconButton(
                                        constraints: const BoxConstraints(),
                                        padding: const EdgeInsets.all(6),
                                        splashRadius: 16,
                                        tooltip: 'Edit Account',
                                        icon: const Icon(
                                          Icons.edit_outlined,
                                          size: 16,
                                          color: Color(0xFF475569),
                                        ),
                                        onPressed: () =>
                                            _showUserDialog(user: u),
                                      ),
                                      const SizedBox(width: 4),
                                      IconButton(
                                        constraints: const BoxConstraints(),
                                        padding: const EdgeInsets.all(6),
                                        splashRadius: 16,
                                        tooltip: 'Delete User',
                                        icon: const Icon(
                                          Icons.delete_outline,
                                          size: 16,
                                          color: Colors.red,
                                        ),
                                        onPressed: () => _deleteUser(u),
                                      ),
                                    ],
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
                            color: Color(0xFFF9FAFB),
                            border: Border(
                              top: BorderSide(color: Color(0xFFE5E7EB)),
                            ),
                          ),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text(
                                'Showing ${_filteredUsers.length} of ${_users.length} user accounts',
                                style: const TextStyle(
                                  fontSize: 12,
                                  color: Color(0xFF6B7280),
                                ),
                              ),
                              Text(
                                'Roles: ${systemRoles.length} configured | 10 Modules Enforced',
                                style: const TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.black87,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    );
                  },
                ),
              ),
          ],
        ),
      ),
    );
  }

  // Visual Module Access summary pills in table row
  Widget _buildAccessibleModulesSummary(List<int> allowedIndices) {
    if (allowedIndices.length == 10) {
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
        decoration: BoxDecoration(
          color: const Color(0xFFF3E8FF),
          borderRadius: BorderRadius.circular(6),
          border: Border.all(color: const Color(0xFFDDD6FE)),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: const [
            Icon(Icons.stars_rounded, size: 13, color: Color(0xFF7C3AED)),
            SizedBox(width: 5),
            Text(
              'Full Access (All 10 Modules)',
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.bold,
                color: Color(0xFF7C3AED),
              ),
            ),
          ],
        ),
      );
    }

    final moduleNames = allowedIndices
        .map((i) => allModules[i]['name'] as String)
        .toList();
    final firstThree = moduleNames.take(3).join(', ');
    final remaining = moduleNames.length - 3;

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2.5),
          decoration: BoxDecoration(
            color: const Color(0xFFECFDF5),
            borderRadius: BorderRadius.circular(6),
            border: Border.all(color: const Color(0xFFA7F3D0)),
          ),
          child: Text(
            '${allowedIndices.length} Modules',
            style: const TextStyle(
              fontSize: 10.5,
              fontWeight: FontWeight.w800,
              color: Color(0xFF059669),
            ),
          ),
        ),
        const SizedBox(width: 6),
        Flexible(
          child: Text(
            remaining > 0 ? '$firstThree +$remaining' : firstThree,
            style: const TextStyle(
              fontSize: 11.5,
              color: Color(0xFF334155),
              fontWeight: FontWeight.w500,
            ),
            overflow: TextOverflow.ellipsis,
          ),
        ),
      ],
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
      padding: const EdgeInsets.all(16),
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
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: accentColor.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(icon, color: accentColor, size: 24),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: Color(0xFF6B7280),
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  value,
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: Colors.black,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  subtitle,
                  style: TextStyle(
                    fontSize: 11,
                    color: accentColor,
                    fontWeight: FontWeight.w500,
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
