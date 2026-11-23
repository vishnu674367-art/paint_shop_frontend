import 'package:flutter/material.dart';

const Color primaryGreen = Color(0xFF267A4B);
const Color darkGreen = Color(0xFF173D32);
const Color accentGold = Color(0xFFE6A23C);
const Color pageBg = Color(0xFFF5F7FA);

class ModulePage extends StatefulWidget {
  final String title;
  final String subtitle;
  final IconData icon;
  final List<String> fields;
  final List<List<String>> initialData;

  const ModulePage({
    super.key,
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.fields,
    required this.initialData,
  });

  @override
  State<ModulePage> createState() => _ModulePageState();
}

class _ModulePageState extends State<ModulePage> {
  late List<List<String>> records;
  String search = '';

  @override
  void initState() {
    super.initState();
    records = widget.initialData.map((e) => List<String>.from(e)).toList();
  }

  List<List<String>> get filteredRecords {
    return records.where((row) {
      return row.any(
        (value) => value.toLowerCase().contains(search.toLowerCase()),
      );
    }).toList();
  }

  void showRecordDialog({int? index}) {
    final controllers = List.generate(
      widget.fields.length,
      (i) =>
          TextEditingController(text: index != null ? records[index][i] : ''),
    );

    showDialog(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(
          index == null ? 'Add ${widget.title}' : 'Edit ${widget.title}',
        ),
        content: SizedBox(
          width: 420,
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: List.generate(widget.fields.length, (i) {
                return Padding(
                  padding: const EdgeInsets.only(bottom: 14),
                  child: TextField(
                    controller: controllers[i],
                    decoration: InputDecoration(
                      labelText: widget.fields[i],
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(10),
                      ),
                    ),
                  ),
                );
              }),
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('Cancel'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: primaryGreen),
            onPressed: () {
              final values = controllers.map((c) => c.text.trim()).toList();

              if (values.any((v) => v.isEmpty)) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Please fill all fields')),
                );
                return;
              }

              setState(() {
                if (index == null) {
                  records.add(values);
                } else {
                  records[index] = values;
                }
              });

              Navigator.pop(dialogContext);
            },
            child: const Text('Save'),
          ),
        ],
      ),
    );
  }

  void deleteRecord(int index) {
    showDialog(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Delete Record?'),
        content: const Text('Are you sure you want to delete this record?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('Cancel'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () {
              setState(() => records.removeAt(index));
              Navigator.pop(dialogContext);
            },
            child: const Text('Delete'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final data = filteredRecords;

    return Scaffold(
      backgroundColor: pageBg,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(13),
                    decoration: BoxDecoration(
                      color: primaryGreen.withValues(alpha: 0.10),
                      borderRadius: BorderRadius.circular(13),
                    ),
                    child: Icon(widget.icon, color: primaryGreen, size: 27),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          widget.title,
                          style: const TextStyle(
                            fontSize: 25,
                            fontWeight: FontWeight.bold,
                            color: darkGreen,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          widget.subtitle,
                          style: const TextStyle(
                            color: Colors.black54,
                            fontSize: 13,
                          ),
                        ),
                      ],
                    ),
                  ),
                  FilledButton.icon(
                    onPressed: () => showRecordDialog(),
                    icon: const Icon(Icons.add),
                    label: const Text('Add New'),
                    style: FilledButton.styleFrom(
                      backgroundColor: primaryGreen,
                      padding: const EdgeInsets.symmetric(
                        horizontal: 18,
                        vertical: 15,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 24),

              Row(
                children: [
                  Expanded(
                    child: _summaryCard(
                      'Total Records',
                      '${records.length}',
                      Icons.inventory_2_outlined,
                    ),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: _summaryCard(
                      'Search Results',
                      '${data.length}',
                      Icons.search,
                    ),
                  ),
                ],
              ),

              const SizedBox(height: 22),

              TextField(
                onChanged: (value) {
                  setState(() => search = value);
                },
                decoration: InputDecoration(
                  hintText: 'Search ${widget.title}...',
                  prefixIcon: const Icon(Icons.search),
                  filled: true,
                  fillColor: Colors.white,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide.none,
                  ),
                ),
              ),

              const SizedBox(height: 20),

              Expanded(
                child: Container(
                  width: double.infinity,
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: const Color(0xFFE8EDF0)),
                  ),
                  child: data.isEmpty
                      ? const Center(child: Text('No records found'))
                      : SingleChildScrollView(
                          child: SingleChildScrollView(
                            scrollDirection: Axis.horizontal,
                            child: DataTable(
                              headingRowColor: const WidgetStatePropertyAll(
                                Color(0xFFF0F5F2),
                              ),
                              columnSpacing: 28,
                              columns: [
                                ...widget.fields.map(
                                  (field) => DataColumn(
                                    label: Text(
                                      field,
                                      style: const TextStyle(
                                        fontWeight: FontWeight.bold,
                                        color: darkGreen,
                                      ),
                                    ),
                                  ),
                                ),
                                const DataColumn(label: Text('Actions')),
                              ],
                              rows: data.map((row) {
                                final actualIndex = records.indexOf(row);

                                return DataRow(
                                  cells: [
                                    ...row.map(
                                      (value) => DataCell(Text(value)),
                                    ),
                                    DataCell(
                                      Row(
                                        children: [
                                          IconButton(
                                            tooltip: 'Edit',
                                            icon: const Icon(
                                              Icons.edit_outlined,
                                              color: primaryGreen,
                                            ),
                                            onPressed: () => showRecordDialog(
                                              index: actualIndex,
                                            ),
                                          ),
                                          IconButton(
                                            tooltip: 'Delete',
                                            icon: const Icon(
                                              Icons.delete_outline,
                                              color: Colors.red,
                                            ),
                                            onPressed: () =>
                                                deleteRecord(actualIndex),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ],
                                );
                              }).toList(),
                            ),
                          ),
                        ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _summaryCard(String title, String value, IconData icon) {
    return Container(
      padding: const EdgeInsets.all(17),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(13),
        border: Border.all(color: const Color(0xFFE8EDF0)),
      ),
      child: Row(
        children: [
          Icon(icon, color: primaryGreen, size: 25),
          const SizedBox(width: 12),
          Flexible(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(color: Colors.black54, fontSize: 12),
                ),
                const SizedBox(height: 5),
                Text(
                  value,
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 21,
                    color: darkGreen,
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

// CUSTOMERS
class CustomersPage extends StatelessWidget {
  const CustomersPage({super.key});

  @override
  Widget build(BuildContext context) => const ModulePage(
    title: 'Customers',
    subtitle: 'Manage your paint shop customers',
    icon: Icons.people_outline,
    fields: ['Customer ID', 'Name', 'Phone', 'Email'],
    initialData: [],
  );
}

// PRODUCTS
class ProductsPage extends StatelessWidget {
  const ProductsPage({super.key});

  @override
  Widget build(BuildContext context) => const ModulePage(
    title: 'Products',
    subtitle: 'Manage products and inventory',
    icon: Icons.inventory_2_outlined,
    fields: ['Product ID', 'Product Name', 'Category', 'Price', 'Stock'],
    initialData: [],
  );
}

// SUPPLIERS
class SuppliersPage extends StatelessWidget {
  const SuppliersPage({super.key});

  @override
  Widget build(BuildContext context) => const ModulePage(
    title: 'Suppliers',
    subtitle: 'Manage supplier information',
    icon: Icons.local_shipping_outlined,
    fields: ['Supplier ID', 'Name', 'Phone', 'Email'],
    initialData: [],
  );
}

// SALES
class SalesPage extends StatelessWidget {
  const SalesPage({super.key});

  @override
  Widget build(BuildContext context) => const ModulePage(
    title: 'Sales',
    subtitle: 'View and manage sales records',
    icon: Icons.point_of_sale,
    fields: ['Invoice ID', 'Customer', 'Date', 'Amount', 'Status'],
    initialData: [],
  );
}

// PURCHASE
class PurchasePage extends StatelessWidget {
  const PurchasePage({super.key});

  @override
  Widget build(BuildContext context) => const ModulePage(
    title: 'Purchases',
    subtitle: 'Manage purchase records',
    icon: Icons.shopping_cart_outlined,
    fields: ['Purchase ID', 'Supplier', 'Date', 'Amount', 'Status'],
    initialData: [],
  );
}

// USERS
class UsersPage extends StatelessWidget {
  const UsersPage({super.key});

  @override
  Widget build(BuildContext context) => const ModulePage(
    title: 'Users',
    subtitle: 'Manage staff and user accounts',
    icon: Icons.manage_accounts_outlined,
    fields: ['User ID', 'Name', 'Email', 'Role'],
    initialData: [],
  );
}

class BillingPage extends StatefulWidget {
  const BillingPage({super.key});

  @override
  State<BillingPage> createState() => _BillingPageState();
}

class _BillingPageState extends State<BillingPage> {
  final customer = TextEditingController();
  final product = TextEditingController();
  final quantity = TextEditingController(text: '1');
  final price = TextEditingController();
  final discount = TextEditingController(text: '0');

  double get total {
    final q = double.tryParse(quantity.text) ?? 0;
    final p = double.tryParse(price.text) ?? 0;
    final d = double.tryParse(discount.text) ?? 0;
    return (q * p - d).clamp(0, double.infinity);
  }

  @override
  void dispose() {
    customer.dispose();
    product.dispose();
    quantity.dispose();
    price.dispose();
    discount.dispose();
    super.dispose();
  }

  Widget field(
    String label,
    TextEditingController controller, {
    bool number = false,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 15),
      child: TextField(
        controller: controller,
        keyboardType: number
            ? const TextInputType.numberWithOptions(decimal: true)
            : TextInputType.text,
        onChanged: (_) => setState(() {}),
        decoration: InputDecoration(
          labelText: label,
          filled: true,
          fillColor: Colors.white,
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(11)),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: pageBg,
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Create Invoice',
                style: TextStyle(
                  fontSize: 26,
                  fontWeight: FontWeight.bold,
                  color: darkGreen,
                ),
              ),
              const SizedBox(height: 5),
              const Text('Create a new paint shop sales invoice'),
              const SizedBox(height: 25),
              Card(
                color: Colors.white,
                child: Padding(
                  padding: const EdgeInsets.all(22),
                  child: Column(
                    children: [
                      field('Customer Name', customer),
                      field('Product Name', product),
                      Row(
                        children: [
                          Expanded(
                            child: field('Quantity', quantity, number: true),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: field('Unit Price', price, number: true),
                          ),
                        ],
                      ),
                      field('Discount Amount', discount, number: true),
                      Container(
                        padding: const EdgeInsets.all(20),
                        decoration: BoxDecoration(
                          color: const Color(0xFFF0F5F2),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            const Text(
                              'Grand Total',
                              style: TextStyle(
                                fontSize: 17,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            Text(
                              '₹${total.toStringAsFixed(2)}',
                              style: const TextStyle(
                                color: primaryGreen,
                                fontSize: 23,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 20),
                      SizedBox(
                        width: double.infinity,
                        height: 48,
                        child: FilledButton.icon(
                          onPressed: () {
                            if (customer.text.trim().isEmpty ||
                                product.text.trim().isEmpty ||
                                (double.tryParse(quantity.text) ?? 0) <= 0 ||
                                (double.tryParse(price.text) ?? -1) < 0 ||
                                (double.tryParse(discount.text) ?? -1) < 0) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(
                                  content: Text('Enter valid invoice details'),
                                ),
                              );
                              return;
                            }

                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                content: Text(
                                  'Invoice preview calculated. Save through backend integration next.',
                                ),
                              ),
                            );
                          },
                          icon: const Icon(Icons.receipt_long),
                          label: const Text('Calculate Invoice'),
                          style: FilledButton.styleFrom(
                            backgroundColor: primaryGreen,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class ReportsPage extends StatelessWidget {
  const ReportsPage({super.key});

  @override
  Widget build(BuildContext context) {
    final reports = [
      ('Sales Report', Icons.trending_up, 'View sales performance'),
      ('Purchase Report', Icons.shopping_bag_outlined, 'View purchases'),
      (
        'Profit Report',
        Icons.account_balance_wallet_outlined,
        'View profit and expenses',
      ),
      ('Stock Report', Icons.inventory_2_outlined, 'View current inventory'),
    ];

    return Scaffold(
      backgroundColor: pageBg,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Reports',
                style: TextStyle(
                  fontSize: 26,
                  fontWeight: FontWeight.bold,
                  color: darkGreen,
                ),
              ),
              const SizedBox(height: 6),
              const Text('Business reports and analytics'),
              const SizedBox(height: 25),
              Expanded(
                child: GridView.builder(
                  itemCount: reports.length,
                  gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
                    maxCrossAxisExtent: 320,
                    mainAxisExtent: 150,
                    crossAxisSpacing: 16,
                    mainAxisSpacing: 16,
                  ),
                  itemBuilder: (context, index) {
                    final report = reports[index];
                    return Card(
                      color: Colors.white,
                      child: Padding(
                        padding: const EdgeInsets.all(18),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Icon(report.$2, color: primaryGreen, size: 30),
                            const Spacer(),
                            Text(
                              report.$1,
                              style: const TextStyle(
                                fontSize: 17,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            Text(
                              report.$3,
                              style: const TextStyle(
                                color: Colors.black54,
                                fontSize: 12,
                              ),
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class SettingsPage extends StatefulWidget {
  const SettingsPage({super.key});

  @override
  State<SettingsPage> createState() => _SettingsPageState();
}

class _SettingsPageState extends State<SettingsPage> {
  final shopName = TextEditingController(text: 'ColorCraft Paint Shop');
  final phone = TextEditingController();
  final email = TextEditingController();
  final address = TextEditingController();
  final tax = TextEditingController(text: '18');

  @override
  void dispose() {
    shopName.dispose();
    phone.dispose();
    email.dispose();
    address.dispose();
    tax.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final fields = [
      ('Shop Name', shopName),
      ('Phone Number', phone),
      ('Email Address', email),
      ('Shop Address', address),
      ('GST Percentage', tax),
    ];

    return Scaffold(
      backgroundColor: pageBg,
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Settings',
                style: TextStyle(
                  fontSize: 26,
                  fontWeight: FontWeight.bold,
                  color: darkGreen,
                ),
              ),
              const SizedBox(height: 6),
              const Text('Configure your shop information'),
              const SizedBox(height: 25),
              Card(
                color: Colors.white,
                child: Padding(
                  padding: const EdgeInsets.all(22),
                  child: Column(
                    children: [
                      ...fields.map(
                        (item) => Padding(
                          padding: const EdgeInsets.only(bottom: 16),
                          child: TextField(
                            controller: item.$2,
                            decoration: InputDecoration(
                              labelText: item.$1,
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(10),
                              ),
                            ),
                          ),
                        ),
                      ),
                      SizedBox(
                        width: double.infinity,
                        height: 48,
                        child: FilledButton(
                          style: FilledButton.styleFrom(
                            backgroundColor: primaryGreen,
                          ),
                          onPressed: () {
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                content: Text(
                                  'Settings validated. Backend saving is not connected yet.',
                                ),
                              ),
                            );
                          },
                          child: const Text('Save Settings'),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
