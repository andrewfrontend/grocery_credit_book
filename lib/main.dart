import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'package:path/path.dart';
import 'package:sqflite/sqflite.dart';

final GlobalKey<ScaffoldMessengerState> rootScaffoldMessengerKey =
    GlobalKey<ScaffoldMessengerState>();

final GlobalKey<NavigatorState> rootNavigatorKey = GlobalKey<NavigatorState>();

void showAppSnackBar(String message) {
  rootScaffoldMessengerKey.currentState?.clearSnackBars();
  rootScaffoldMessengerKey.currentState?.showSnackBar(
    SnackBar(content: Text(message)),
  );
}

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const GroceryCreditBookApp());
}

String formatMoney(double amount) {
  return NumberFormat.currency(symbol: 'MK ', decimalDigits: 0).format(amount);
}

String formatTime(String isoDate) {
  final date = DateTime.parse(isoDate);
  return DateFormat('hh:mm a').format(date);
}

String formatDate(String isoDate) {
  final date = DateTime.parse(isoDate);
  return DateFormat('EEEE, dd MMM yyyy').format(date);
}

class GroceryCreditBookApp extends StatelessWidget {
  const GroceryCreditBookApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Grocery Credit Book',
      debugShowCheckedModeBanner: false,
      scaffoldMessengerKey: rootScaffoldMessengerKey,
      navigatorKey: rootNavigatorKey,
      theme: ThemeData(
        useMaterial3: true,
        textTheme: GoogleFonts.poppinsTextTheme(),
        colorScheme: ColorScheme.fromSeed(seedColor: const Color(0xFF0F766E)),
        scaffoldBackgroundColor: const Color(0xFFF6F8FA),
      ),
      home: const DashboardScreen(),
    );
  }
}

/* =========================
   MODELS
========================= */

class Customer {
  final int? id;
  final String name;
  final String phone;
  final String location;
  final String createdAt;

  Customer({
    this.id,
    required this.name,
    required this.phone,
    required this.location,
    required this.createdAt,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'name': name,
      'phone': phone,
      'location': location,
      'createdAt': createdAt,
    };
  }

  factory Customer.fromMap(Map<String, dynamic> map) {
    return Customer(
      id: map['id'],
      name: map['name'] ?? '',
      phone: map['phone'] ?? '',
      location: map['location'] ?? '',
      createdAt: map['createdAt'] ?? '',
    );
  }
}

class CustomerSummary {
  final Customer customer;
  final double totalCredit;
  final double totalPaid;
  final double balance;
  final int itemCount;

  CustomerSummary({
    required this.customer,
    required this.totalCredit,
    required this.totalPaid,
    required this.balance,
    required this.itemCount,
  });
}

class CreditItem {
  final int? id;
  final int customerId;
  final String itemName;
  final double quantity;
  final double unitPrice;
  final String createdAt;

  CreditItem({
    this.id,
    required this.customerId,
    required this.itemName,
    required this.quantity,
    required this.unitPrice,
    required this.createdAt,
  });

  double get total => quantity * unitPrice;

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'customerId': customerId,
      'itemName': itemName,
      'quantity': quantity,
      'unitPrice': unitPrice,
      'createdAt': createdAt,
      'paid': 0,
    };
  }

  factory CreditItem.fromMap(Map<String, dynamic> map) {
    return CreditItem(
      id: map['id'],
      customerId: map['customerId'],
      itemName: map['itemName'] ?? '',
      quantity: (map['quantity'] as num).toDouble(),
      unitPrice: (map['unitPrice'] as num).toDouble(),
      createdAt: map['createdAt'] ?? '',
    );
  }
}

class Payment {
  final int? id;
  final int customerId;
  final double amount;
  final String note;
  final String createdAt;

  Payment({
    this.id,
    required this.customerId,
    required this.amount,
    required this.note,
    required this.createdAt,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'customerId': customerId,
      'amount': amount,
      'note': note,
      'createdAt': createdAt,
    };
  }

  factory Payment.fromMap(Map<String, dynamic> map) {
    return Payment(
      id: map['id'],
      customerId: map['customerId'],
      amount: (map['amount'] as num).toDouble(),
      note: map['note'] ?? '',
      createdAt: map['createdAt'] ?? '',
    );
  }
}

/* =========================
   DATABASE
========================= */

class DatabaseHelper {
  DatabaseHelper._privateConstructor();

  static final DatabaseHelper instance = DatabaseHelper._privateConstructor();

  static Database? _database;

  Future<Database> get database async {
    if (_database != null) return _database!;

    _database = await _initDatabase();
    return _database!;
  }

  Future<Database> _initDatabase() async {
    final databasePath = await getDatabasesPath();
    final path = join(databasePath, 'grocery_credit_book.db');

    return await openDatabase(
      path,
      version: 2,
      onConfigure: (db) async {
        await db.execute('PRAGMA foreign_keys = ON');
      },
      onCreate: _onCreate,
      onUpgrade: _onUpgrade,
    );
  }

  Future<void> _onCreate(Database db, int version) async {
    await db.execute('''
      CREATE TABLE customers (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        name TEXT NOT NULL,
        phone TEXT,
        location TEXT,
        createdAt TEXT NOT NULL
      )
    ''');

    await db.execute('''
      CREATE TABLE credit_items (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        customerId INTEGER NOT NULL,
        itemName TEXT NOT NULL,
        quantity REAL NOT NULL,
        unitPrice REAL NOT NULL,
        createdAt TEXT NOT NULL,
        paid INTEGER NOT NULL DEFAULT 0,
        FOREIGN KEY (customerId) REFERENCES customers (id) ON DELETE CASCADE
      )
    ''');

    await db.execute('''
      CREATE TABLE payments (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        customerId INTEGER NOT NULL,
        amount REAL NOT NULL,
        note TEXT,
        createdAt TEXT NOT NULL,
        FOREIGN KEY (customerId) REFERENCES customers (id) ON DELETE CASCADE
      )
    ''');
  }

  Future<void> _onUpgrade(Database db, int oldVersion, int newVersion) async {
    if (oldVersion < 2) {
      await db.execute('''
        CREATE TABLE IF NOT EXISTS payments (
          id INTEGER PRIMARY KEY AUTOINCREMENT,
          customerId INTEGER NOT NULL,
          amount REAL NOT NULL,
          note TEXT,
          createdAt TEXT NOT NULL,
          FOREIGN KEY (customerId) REFERENCES customers (id) ON DELETE CASCADE
        )
      ''');
    }
  }

  Future<int> addCustomer(Customer customer) async {
    final db = await database;
    return await db.insert('customers', customer.toMap());
  }

  Future<int> updateCustomer(Customer customer) async {
    final db = await database;

    return await db.update(
      'customers',
      customer.toMap(),
      where: 'id = ?',
      whereArgs: [customer.id],
    );
  }

  Future<int> deleteCustomer(int customerId) async {
    final db = await database;

    return await db.delete(
      'customers',
      where: 'id = ?',
      whereArgs: [customerId],
    );
  }

  Future<List<CustomerSummary>> getCustomerSummaries() async {
    final db = await database;

    final customerRows = await db.query(
      'customers',
      orderBy: 'name COLLATE NOCASE ASC',
    );

    final List<CustomerSummary> summaries = [];

    for (final customerMap in customerRows) {
      final customer = Customer.fromMap(customerMap);
      final customerId = customer.id!;

      final totalCredit = await getTotalCreditForCustomer(customerId);
      final totalPaid = await getTotalPaidForCustomer(customerId);
      final balance = await getLedgerBalanceForCustomer(customerId);

      final itemCountResult = await db.rawQuery(
        '''
        SELECT COALESCE(COUNT(*), 0) AS total
        FROM credit_items
        WHERE customerId = ?
        ''',
        [customerId],
      );

      summaries.add(
        CustomerSummary(
          customer: customer,
          totalCredit: totalCredit,
          totalPaid: totalPaid,
          balance: balance,
          itemCount: (itemCountResult.first['total'] as num).toInt(),
        ),
      );
    }

    return summaries;
  }

  Future<double> getGrandBalance() async {
    final db = await database;

    final customerRows = await db.query('customers');

    double totalBalance = 0;

    for (final customerMap in customerRows) {
      final customerId = customerMap['id'] as int;
      totalBalance += await getLedgerBalanceForCustomer(customerId);
    }

    return totalBalance;
  }

  Future<int> addCreditItem(CreditItem item) async {
    final db = await database;
    return await db.insert('credit_items', item.toMap());
  }

  Future<int> updateCreditItem(CreditItem item) async {
    final db = await database;

    return await db.update(
      'credit_items',
      item.toMap(),
      where: 'id = ?',
      whereArgs: [item.id],
    );
  }

  Future<List<CreditItem>> getCreditItemsForCustomer(int customerId) async {
    final db = await database;

    final result = await db.query(
      'credit_items',
      where: 'customerId = ?',
      whereArgs: [customerId],
      orderBy: 'createdAt DESC',
    );

    return result.map((map) => CreditItem.fromMap(map)).toList();
  }

  Future<int> deleteCreditItem(int itemId) async {
    final db = await database;

    return await db.delete(
      'credit_items',
      where: 'id = ?',
      whereArgs: [itemId],
    );
  }

  Future<int> addPayment(Payment payment) async {
    final db = await database;
    return await db.insert('payments', payment.toMap());
  }

  Future<int> updatePayment(Payment payment) async {
    final db = await database;

    return await db.update(
      'payments',
      payment.toMap(),
      where: 'id = ?',
      whereArgs: [payment.id],
    );
  }

  Future<List<Payment>> getPaymentsForCustomer(int customerId) async {
    final db = await database;

    final result = await db.query(
      'payments',
      where: 'customerId = ?',
      whereArgs: [customerId],
      orderBy: 'createdAt DESC',
    );

    return result.map((map) => Payment.fromMap(map)).toList();
  }

  Future<int> deletePayment(int paymentId) async {
    final db = await database;

    return await db.delete('payments', where: 'id = ?', whereArgs: [paymentId]);
  }

  Future<double> getTotalCreditForCustomer(int customerId) async {
    final db = await database;

    final result = await db.rawQuery(
      '''
      SELECT COALESCE(SUM(quantity * unitPrice), 0) AS total
      FROM credit_items
      WHERE customerId = ?
      ''',
      [customerId],
    );

    return (result.first['total'] as num).toDouble();
  }

  Future<double> getTotalPaidForCustomer(int customerId) async {
    final db = await database;

    final result = await db.rawQuery(
      '''
      SELECT COALESCE(SUM(amount), 0) AS total
      FROM payments
      WHERE customerId = ?
      ''',
      [customerId],
    );

    return (result.first['total'] as num).toDouble();
  }

  Future<double> getLedgerBalanceForCustomer(int customerId) async {
    final db = await database;

    final creditRows = await db.query(
      'credit_items',
      columns: ['id', 'createdAt', 'quantity', 'unitPrice'],
      where: 'customerId = ?',
      whereArgs: [customerId],
    );

    final paymentRows = await db.query(
      'payments',
      columns: ['id', 'createdAt', 'amount'],
      where: 'customerId = ?',
      whereArgs: [customerId],
    );

    final List<Map<String, dynamic>> ledgerEvents = [];

    for (final row in creditRows) {
      ledgerEvents.add({
        'type': 'credit',
        'createdAt': row['createdAt'] as String,
        'amount':
            (row['quantity'] as num).toDouble() *
            (row['unitPrice'] as num).toDouble(),
      });
    }

    for (final row in paymentRows) {
      ledgerEvents.add({
        'type': 'payment',
        'createdAt': row['createdAt'] as String,
        'amount': (row['amount'] as num).toDouble(),
      });
    }

    ledgerEvents.sort((a, b) {
      final dateCompare = (a['createdAt'] as String).compareTo(
        b['createdAt'] as String,
      );

      if (dateCompare != 0) {
        return dateCompare;
      }

      if (a['type'] == b['type']) {
        return 0;
      }

      return a['type'] == 'credit' ? -1 : 1;
    });

    double runningBalance = 0;

    for (final event in ledgerEvents) {
      final amount = event['amount'] as double;

      if (event['type'] == 'credit') {
        runningBalance += amount;
      } else {
        runningBalance -= amount;

        if (runningBalance < 0) {
          runningBalance = 0;
        }
      }
    }

    return runningBalance;
  }
}

/* =========================
   DASHBOARD SCREEN
========================= */

class DashboardScreen extends StatefulWidget {
  const DashboardScreen({super.key});

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  final TextEditingController searchController = TextEditingController();

  List<CustomerSummary> customers = [];
  List<CustomerSummary> filteredCustomers = [];

  double grandBalance = 0;
  bool loading = true;

  @override
  void initState() {
    super.initState();
    loadDashboard();
    searchController.addListener(filterCustomers);
  }

  @override
  void dispose() {
    searchController.dispose();
    super.dispose();
  }

  Future<void> loadDashboard() async {
    if (!mounted) return;

    setState(() {
      loading = true;
    });

    final customerData = await DatabaseHelper.instance.getCustomerSummaries();
    final total = await DatabaseHelper.instance.getGrandBalance();

    if (!mounted) return;

    setState(() {
      customers = customerData;
      filteredCustomers = customerData;
      grandBalance = total;
      loading = false;
    });
  }

  void filterCustomers() {
    final searchText = searchController.text.toLowerCase();

    setState(() {
      filteredCustomers = customers.where((summary) {
        final customer = summary.customer;

        return customer.name.toLowerCase().contains(searchText) ||
            customer.phone.toLowerCase().contains(searchText) ||
            customer.location.toLowerCase().contains(searchText);
      }).toList();
    });
  }

  void openAddCustomerSheet(BuildContext pageContext) {
    final nameController = TextEditingController();
    final phoneController = TextEditingController();
    final locationController = TextEditingController();

    showModalBottomSheet(
      context: pageContext,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      builder: (sheetContext) {
        return Padding(
          padding: EdgeInsets.only(
            left: 20,
            right: 20,
            top: 20,
            bottom: MediaQuery.of(sheetContext).viewInsets.bottom + 20,
          ),
          child: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Center(
                  child: SizedBox(width: 45, child: Divider(thickness: 4)),
                ),
                const SizedBox(height: 16),
                const Text(
                  'Add New Customer',
                  style: TextStyle(fontSize: 22, fontWeight: FontWeight.w800),
                ),
                const SizedBox(height: 6),
                Text(
                  'Create a credit account for the customer.',
                  style: TextStyle(color: Colors.grey.shade600),
                ),
                const SizedBox(height: 20),
                CustomTextField(
                  controller: nameController,
                  label: 'Customer name',
                  icon: Icons.person_outline,
                ),
                const SizedBox(height: 14),
                CustomTextField(
                  controller: phoneController,
                  label: 'Phone number',
                  icon: Icons.phone_outlined,
                  keyboardType: TextInputType.phone,
                ),
                const SizedBox(height: 14),
                CustomTextField(
                  controller: locationController,
                  label: 'Location / Area',
                  icon: Icons.location_on_outlined,
                ),
                const SizedBox(height: 22),
                SizedBox(
                  width: double.infinity,
                  height: 52,
                  child: FilledButton.icon(
                    onPressed: () {
                      final name = nameController.text.trim();

                      if (name.isEmpty) {
                        showAppSnackBar('Please enter customer name');
                        return;
                      }

                      final customer = Customer(
                        name: name,
                        phone: phoneController.text.trim(),
                        location: locationController.text.trim(),
                        createdAt: DateTime.now().toIso8601String(),
                      );

                      Navigator.of(sheetContext).pop();

                      DatabaseHelper.instance.addCustomer(customer).then((_) {
                        if (!mounted) return;
                        loadDashboard();
                      });
                    },
                    icon: const Icon(Icons.save_outlined),
                    label: const Text('Save Customer'),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  int get totalCustomers => customers.length;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () {
          openAddCustomerSheet(context);
        },
        icon: const Icon(Icons.person_add_alt_1),
        label: const Text('Add Customer'),
      ),
      body: SafeArea(
        child: loading
            ? const Center(child: CircularProgressIndicator())
            : RefreshIndicator(
                onRefresh: loadDashboard,
                child: CustomScrollView(
                  slivers: [
                    SliverToBoxAdapter(
                      child: Padding(
                        padding: const EdgeInsets.all(18),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            buildHeader(),
                            const SizedBox(height: 18),
                            buildStatsSection(),
                            const SizedBox(height: 18),
                            buildSearchBox(),
                            const SizedBox(height: 18),
                            const Text(
                              'Customers',
                              style: TextStyle(
                                fontSize: 22,
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    if (filteredCustomers.isEmpty)
                      SliverToBoxAdapter(child: buildEmptyCustomers())
                    else
                      SliverList(
                        delegate: SliverChildBuilderDelegate((context, index) {
                          final summary = filteredCustomers[index];

                          return CustomerCard(
                            summary: summary,
                            onTap: () {
                              Navigator.of(context)
                                  .push(
                                    MaterialPageRoute(
                                      builder: (_) => CustomerDetailsScreen(
                                        customer: summary.customer,
                                      ),
                                    ),
                                  )
                                  .then((_) {
                                    if (!mounted) return;
                                    loadDashboard();
                                  });
                            },
                          );
                        }, childCount: filteredCustomers.length),
                      ),
                    const SliverToBoxAdapter(child: SizedBox(height: 90)),
                  ],
                ),
              ),
      ),
    );
  }

  Widget buildHeader() {
    return Row(
      children: [
        Container(
          height: 54,
          width: 54,
          decoration: BoxDecoration(
            color: const Color(0xFF0F766E),
            borderRadius: BorderRadius.circular(18),
          ),
          child: const Icon(
            Icons.storefront_outlined,
            color: Colors.white,
            size: 30,
          ),
        ),
        const SizedBox(width: 14),
        const Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Grocery Credit Book',
                style: TextStyle(fontSize: 22, fontWeight: FontWeight.w900),
              ),
              SizedBox(height: 3),
              Text(
                'Manage customer debts professionally',
                style: TextStyle(color: Colors.grey),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget buildStatsSection() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(22),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF0F766E), Color(0xFF115E59)],
        ),
        borderRadius: BorderRadius.circular(28),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withAlpha(20),
            blurRadius: 18,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Total Balance Owed',
            style: TextStyle(color: Colors.white.withAlpha(220), fontSize: 14),
          ),
          const SizedBox(height: 8),
          Text(
            formatMoney(grandBalance),
            style: const TextStyle(
              color: Colors.white,
              fontSize: 34,
              fontWeight: FontWeight.w900,
            ),
          ),
          const SizedBox(height: 14),
          Row(
            children: [
              const Icon(
                Icons.people_alt_outlined,
                color: Colors.white70,
                size: 19,
              ),
              const SizedBox(width: 8),
              Text(
                '$totalCustomers customers recorded',
                style: const TextStyle(color: Colors.white70),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget buildSearchBox() {
    return TextField(
      controller: searchController,
      decoration: InputDecoration(
        hintText: 'Search by name, phone, or location',
        prefixIcon: const Icon(Icons.search),
        filled: true,
        fillColor: Colors.white,
        contentPadding: const EdgeInsets.symmetric(horizontal: 18),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(18),
          borderSide: BorderSide.none,
        ),
      ),
    );
  }

  Widget buildEmptyCustomers() {
    return Padding(
      padding: const EdgeInsets.all(30),
      child: Column(
        children: [
          Icon(Icons.people_outline, size: 75, color: Colors.grey.shade400),
          const SizedBox(height: 12),
          const Text(
            'No customers found',
            style: TextStyle(fontWeight: FontWeight.w800, fontSize: 18),
          ),
          const SizedBox(height: 6),
          Text(
            'Tap “Add Customer” to create your first credit account.',
            textAlign: TextAlign.center,
            style: TextStyle(color: Colors.grey.shade600),
          ),
        ],
      ),
    );
  }
}

/* =========================
   CUSTOMER CARD
========================= */

class CustomerCard extends StatelessWidget {
  final CustomerSummary summary;
  final VoidCallback onTap;

  const CustomerCard({super.key, required this.summary, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final customer = summary.customer;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 7),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(22),
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(22),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withAlpha(10),
                blurRadius: 12,
                offset: const Offset(0, 6),
              ),
            ],
          ),
          child: Row(
            children: [
              CircleAvatar(
                radius: 27,
                backgroundColor: const Color(0xFFE0F2F1),
                child: Text(
                  customer.name.isNotEmpty
                      ? customer.name[0].toUpperCase()
                      : '?',
                  style: const TextStyle(
                    color: Color(0xFF0F766E),
                    fontWeight: FontWeight.w900,
                    fontSize: 20,
                  ),
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      customer.name,
                      style: const TextStyle(
                        fontWeight: FontWeight.w800,
                        fontSize: 16,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      customer.phone.isEmpty
                          ? 'No phone number'
                          : customer.phone,
                      style: TextStyle(
                        color: Colors.grey.shade600,
                        fontSize: 13,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '${summary.itemCount} credit item(s)',
                      style: const TextStyle(
                        color: Color(0xFF0F766E),
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                ),
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  const Text(
                    'Balance',
                    style: TextStyle(color: Colors.grey, fontSize: 12),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    formatMoney(summary.balance),
                    style: TextStyle(
                      fontWeight: FontWeight.w900,
                      fontSize: 15,
                      color: summary.balance > 0
                          ? Colors.red.shade700
                          : Colors.green.shade700,
                    ),
                  ),
                ],
              ),
              const SizedBox(width: 4),
              const Icon(Icons.chevron_right),
            ],
          ),
        ),
      ),
    );
  }
}

/* =========================
   CUSTOMER DETAILS SCREEN
========================= */

class CustomerDetailsScreen extends StatefulWidget {
  final Customer customer;

  const CustomerDetailsScreen({super.key, required this.customer});

  @override
  State<CustomerDetailsScreen> createState() => _CustomerDetailsScreenState();
}

class _CustomerDetailsScreenState extends State<CustomerDetailsScreen> {
  Customer? _currentCustomer;

  Customer get currentCustomer => _currentCustomer ?? widget.customer;

  List<CreditItem> items = [];
  List<Payment> payments = [];

  double totalCredit = 0;
  double totalPaid = 0;
  double balance = 0;

  bool loading = true;

  @override
  void initState() {
    super.initState();
    _currentCustomer = widget.customer;
    loadCustomerData();
  }

  Future<void> loadCustomerData() async {
    if (!mounted) return;

    setState(() {
      loading = true;
    });

    final customerId = currentCustomer.id!;

    final creditItems = await DatabaseHelper.instance.getCreditItemsForCustomer(
      customerId,
    );
    final customerPayments = await DatabaseHelper.instance
        .getPaymentsForCustomer(customerId);
    final creditTotal = await DatabaseHelper.instance.getTotalCreditForCustomer(
      customerId,
    );
    final paidTotal = await DatabaseHelper.instance.getTotalPaidForCustomer(
      customerId,
    );
    final currentBalance = await DatabaseHelper.instance
        .getLedgerBalanceForCustomer(customerId);

    if (!mounted) return;

    setState(() {
      items = creditItems;
      payments = customerPayments;
      totalCredit = creditTotal;
      totalPaid = paidTotal;
      balance = currentBalance;
      loading = false;
    });
  }

  void openEditCustomerSheet(BuildContext pageContext) {
    final nameController = TextEditingController(text: currentCustomer.name);
    final phoneController = TextEditingController(text: currentCustomer.phone);
    final locationController = TextEditingController(
      text: currentCustomer.location,
    );

    showModalBottomSheet(
      context: pageContext,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      builder: (sheetContext) {
        return Padding(
          padding: EdgeInsets.only(
            left: 20,
            right: 20,
            top: 20,
            bottom: MediaQuery.of(sheetContext).viewInsets.bottom + 20,
          ),
          child: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Center(
                  child: SizedBox(width: 45, child: Divider(thickness: 4)),
                ),
                const SizedBox(height: 16),
                const Text(
                  'Edit Customer Details',
                  style: TextStyle(fontSize: 22, fontWeight: FontWeight.w800),
                ),
                const SizedBox(height: 6),
                Text(
                  'Update the customer name, phone number, or location.',
                  style: TextStyle(color: Colors.grey.shade600),
                ),
                const SizedBox(height: 20),
                CustomTextField(
                  controller: nameController,
                  label: 'Customer name',
                  icon: Icons.person_outline,
                ),
                const SizedBox(height: 14),
                CustomTextField(
                  controller: phoneController,
                  label: 'Phone number',
                  icon: Icons.phone_outlined,
                  keyboardType: TextInputType.phone,
                ),
                const SizedBox(height: 14),
                CustomTextField(
                  controller: locationController,
                  label: 'Location / Area',
                  icon: Icons.location_on_outlined,
                ),
                const SizedBox(height: 22),
                SizedBox(
                  width: double.infinity,
                  height: 52,
                  child: FilledButton.icon(
                    onPressed: () {
                      final name = nameController.text.trim();

                      if (name.isEmpty) {
                        showAppSnackBar('Customer name cannot be empty');
                        return;
                      }

                      final updatedCustomer = Customer(
                        id: currentCustomer.id,
                        name: name,
                        phone: phoneController.text.trim(),
                        location: locationController.text.trim(),
                        createdAt: currentCustomer.createdAt,
                      );

                      Navigator.of(sheetContext).pop();

                      DatabaseHelper.instance
                          .updateCustomer(updatedCustomer)
                          .then((_) {
                            if (!mounted) return;

                            setState(() {
                              _currentCustomer = updatedCustomer;
                            });

                            loadCustomerData();
                            showAppSnackBar('Customer details updated');
                          });
                    },
                    icon: const Icon(Icons.save_outlined),
                    label: const Text('Save Changes'),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Map<String, List<CreditItem>> groupItemsByDate() {
    final Map<String, List<CreditItem>> grouped = {};

    for (final item in items) {
      final dateKey = DateFormat(
        'yyyy-MM-dd',
      ).format(DateTime.parse(item.createdAt));

      if (!grouped.containsKey(dateKey)) {
        grouped[dateKey] = [];
      }

      grouped[dateKey]!.add(item);
    }

    return grouped;
  }

  double calculateDailyTotal(List<CreditItem> dailyItems) {
    double total = 0;

    for (final item in dailyItems) {
      total += item.total;
    }

    return total;
  }

  void confirmDeleteCustomer(BuildContext pageContext) {
    showDialog<bool>(
      context: pageContext,
      builder: (dialogContext) {
        return AlertDialog(
          title: const Text('Delete Customer?'),
          content: Text(
            'This will permanently delete ${currentCustomer.name}, including all credit items and payment history. This action cannot be undone.',
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.of(dialogContext).pop(false);
              },
              child: const Text('Cancel'),
            ),
            FilledButton.icon(
              style: FilledButton.styleFrom(
                backgroundColor: Colors.red,
                foregroundColor: Colors.white,
              ),
              onPressed: () {
                Navigator.of(dialogContext).pop(true);
              },
              icon: const Icon(Icons.delete_outline),
              label: const Text('Delete'),
            ),
          ],
        );
      },
    ).then((confirm) {
      if (confirm == true) {
        DatabaseHelper.instance.deleteCustomer(currentCustomer.id!).then((_) {
          showAppSnackBar('Customer deleted successfully');
          rootNavigatorKey.currentState?.pop(true);
        });
      }
    });
  }

  void openAddItemSheet(BuildContext pageContext) {
    final itemController = TextEditingController();
    final quantityController = TextEditingController(text: '1');
    final priceController = TextEditingController();

    showModalBottomSheet(
      context: pageContext,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      builder: (sheetContext) {
        return Padding(
          padding: EdgeInsets.only(
            left: 20,
            right: 20,
            top: 20,
            bottom: MediaQuery.of(sheetContext).viewInsets.bottom + 20,
          ),
          child: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Center(
                  child: SizedBox(width: 45, child: Divider(thickness: 4)),
                ),
                const SizedBox(height: 16),
                const Text(
                  'Add Credit Item',
                  style: TextStyle(fontSize: 22, fontWeight: FontWeight.w800),
                ),
                const SizedBox(height: 6),
                Text(
                  'Enter the grocery item bought on credit.',
                  style: TextStyle(color: Colors.grey.shade600),
                ),
                const SizedBox(height: 20),
                CustomTextField(
                  controller: itemController,
                  label: 'Item name e.g. Sugar, Bread, Soap',
                  icon: Icons.shopping_basket_outlined,
                ),
                const SizedBox(height: 14),
                CustomTextField(
                  controller: quantityController,
                  label: 'Quantity',
                  icon: Icons.numbers_outlined,
                  keyboardType: const TextInputType.numberWithOptions(
                    decimal: true,
                  ),
                ),
                const SizedBox(height: 14),
                CustomTextField(
                  controller: priceController,
                  label: 'Price per item',
                  icon: Icons.payments_outlined,
                  keyboardType: const TextInputType.numberWithOptions(
                    decimal: true,
                  ),
                ),
                const SizedBox(height: 22),
                SizedBox(
                  width: double.infinity,
                  height: 52,
                  child: FilledButton.icon(
                    onPressed: () {
                      final itemName = itemController.text.trim();
                      final quantity = double.tryParse(
                        quantityController.text.trim(),
                      );
                      final price = double.tryParse(
                        priceController.text.trim(),
                      );

                      if (itemName.isEmpty ||
                          quantity == null ||
                          price == null ||
                          quantity <= 0 ||
                          price <= 0) {
                        showAppSnackBar(
                          'Please enter item name, quantity and price correctly',
                        );
                        return;
                      }

                      final item = CreditItem(
                        customerId: currentCustomer.id!,
                        itemName: itemName,
                        quantity: quantity,
                        unitPrice: price,
                        createdAt: DateTime.now().toIso8601String(),
                      );

                      Navigator.of(sheetContext).pop();

                      DatabaseHelper.instance.addCreditItem(item).then((_) {
                        if (!mounted) return;
                        loadCustomerData();
                      });
                    },
                    icon: const Icon(Icons.add),
                    label: const Text('Add Item'),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  void openEditItemSheet(BuildContext pageContext, CreditItem item) {
    final itemController = TextEditingController(text: item.itemName);
    final quantityController = TextEditingController(
      text: item.quantity.toString(),
    );
    final priceController = TextEditingController(
      text: item.unitPrice.toString(),
    );

    showModalBottomSheet(
      context: pageContext,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      builder: (sheetContext) {
        return Padding(
          padding: EdgeInsets.only(
            left: 20,
            right: 20,
            top: 20,
            bottom: MediaQuery.of(sheetContext).viewInsets.bottom + 20,
          ),
          child: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Center(
                  child: SizedBox(width: 45, child: Divider(thickness: 4)),
                ),
                const SizedBox(height: 16),
                const Text(
                  'Edit Credit Item',
                  style: TextStyle(fontSize: 22, fontWeight: FontWeight.w800),
                ),
                const SizedBox(height: 6),
                Text(
                  'Correct the item name, quantity, or price.',
                  style: TextStyle(color: Colors.grey.shade600),
                ),
                const SizedBox(height: 20),
                CustomTextField(
                  controller: itemController,
                  label: 'Item name',
                  icon: Icons.shopping_basket_outlined,
                ),
                const SizedBox(height: 14),
                CustomTextField(
                  controller: quantityController,
                  label: 'Quantity',
                  icon: Icons.numbers_outlined,
                  keyboardType: const TextInputType.numberWithOptions(
                    decimal: true,
                  ),
                ),
                const SizedBox(height: 14),
                CustomTextField(
                  controller: priceController,
                  label: 'Price per item',
                  icon: Icons.payments_outlined,
                  keyboardType: const TextInputType.numberWithOptions(
                    decimal: true,
                  ),
                ),
                const SizedBox(height: 22),
                SizedBox(
                  width: double.infinity,
                  height: 52,
                  child: FilledButton.icon(
                    onPressed: () {
                      final itemName = itemController.text.trim();
                      final quantity = double.tryParse(
                        quantityController.text.trim(),
                      );
                      final price = double.tryParse(
                        priceController.text.trim(),
                      );

                      if (itemName.isEmpty ||
                          quantity == null ||
                          price == null ||
                          quantity <= 0 ||
                          price <= 0) {
                        showAppSnackBar(
                          'Please enter item name, quantity and price correctly',
                        );
                        return;
                      }

                      final updatedItem = CreditItem(
                        id: item.id,
                        customerId: item.customerId,
                        itemName: itemName,
                        quantity: quantity,
                        unitPrice: price,
                        createdAt: item.createdAt,
                      );

                      Navigator.of(sheetContext).pop();

                      DatabaseHelper.instance
                          .updateCreditItem(updatedItem)
                          .then((_) {
                            if (!mounted) return;

                            loadCustomerData();
                            showAppSnackBar('Credit item updated successfully');
                          });
                    },
                    icon: const Icon(Icons.save_outlined),
                    label: const Text('Save Changes'),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  void openAddPaymentSheet(BuildContext pageContext) {
    if (balance <= 0) {
      showAppSnackBar('This customer has no balance to pay');
      return;
    }

    final amountController = TextEditingController();
    final noteController = TextEditingController();

    showModalBottomSheet(
      context: pageContext,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      builder: (sheetContext) {
        return Padding(
          padding: EdgeInsets.only(
            left: 20,
            right: 20,
            top: 20,
            bottom: MediaQuery.of(sheetContext).viewInsets.bottom + 20,
          ),
          child: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Center(
                  child: SizedBox(width: 45, child: Divider(thickness: 4)),
                ),
                const SizedBox(height: 16),
                const Text(
                  'Add Payment',
                  style: TextStyle(fontSize: 22, fontWeight: FontWeight.w800),
                ),
                const SizedBox(height: 6),
                Text(
                  'Current balance: ${formatMoney(balance)}',
                  style: TextStyle(color: Colors.grey.shade600),
                ),
                const SizedBox(height: 20),
                CustomTextField(
                  controller: amountController,
                  label: 'Amount paid',
                  icon: Icons.money_outlined,
                  keyboardType: const TextInputType.numberWithOptions(
                    decimal: true,
                  ),
                ),
                const SizedBox(height: 14),
                CustomTextField(
                  controller: noteController,
                  label: 'Payment note e.g. Cash, Airtel Money',
                  icon: Icons.notes_outlined,
                ),
                const SizedBox(height: 22),
                SizedBox(
                  width: double.infinity,
                  height: 52,
                  child: FilledButton.icon(
                    onPressed: () {
                      final amount = double.tryParse(
                        amountController.text.trim(),
                      );

                      if (amount == null || amount <= 0) {
                        showAppSnackBar('Please enter a valid payment amount');
                        return;
                      }

                      if (amount > balance) {
                        showAppSnackBar(
                          'Payment cannot be greater than the current balance',
                        );
                        return;
                      }

                      final payment = Payment(
                        customerId: currentCustomer.id!,
                        amount: amount,
                        note: noteController.text.trim(),
                        createdAt: DateTime.now().toIso8601String(),
                      );

                      Navigator.of(sheetContext).pop();

                      DatabaseHelper.instance.addPayment(payment).then((_) {
                        if (!mounted) return;
                        loadCustomerData();
                        showAppSnackBar('Payment recorded successfully');
                      });
                    },
                    icon: const Icon(Icons.check_circle_outline),
                    label: const Text('Save Payment'),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  void openEditPaymentSheet(BuildContext pageContext, Payment payment) {
    final amountController = TextEditingController(
      text: payment.amount.toString(),
    );
    final noteController = TextEditingController(text: payment.note);

    showModalBottomSheet(
      context: pageContext,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      builder: (sheetContext) {
        return Padding(
          padding: EdgeInsets.only(
            left: 20,
            right: 20,
            top: 20,
            bottom: MediaQuery.of(sheetContext).viewInsets.bottom + 20,
          ),
          child: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Center(
                  child: SizedBox(width: 45, child: Divider(thickness: 4)),
                ),
                const SizedBox(height: 16),
                const Text(
                  'Edit Payment',
                  style: TextStyle(fontSize: 22, fontWeight: FontWeight.w800),
                ),
                const SizedBox(height: 6),
                Text(
                  'Correct the payment amount or note.',
                  style: TextStyle(color: Colors.grey.shade600),
                ),
                const SizedBox(height: 20),
                CustomTextField(
                  controller: amountController,
                  label: 'Amount paid',
                  icon: Icons.money_outlined,
                  keyboardType: const TextInputType.numberWithOptions(
                    decimal: true,
                  ),
                ),
                const SizedBox(height: 14),
                CustomTextField(
                  controller: noteController,
                  label: 'Payment note e.g. Cash, Airtel Money',
                  icon: Icons.notes_outlined,
                ),
                const SizedBox(height: 22),
                SizedBox(
                  width: double.infinity,
                  height: 52,
                  child: FilledButton.icon(
                    onPressed: () {
                      final amount = double.tryParse(
                        amountController.text.trim(),
                      );

                      if (amount == null || amount <= 0) {
                        showAppSnackBar('Please enter a valid payment amount');
                        return;
                      }

                      final otherPaymentsTotal = totalPaid - payment.amount;
                      final maximumAllowed = totalCredit - otherPaymentsTotal;

                      if (maximumAllowed <= 0) {
                        showAppSnackBar(
                          'This payment cannot be increased because the customer has no remaining credit balance',
                        );
                        return;
                      }

                      if (amount > maximumAllowed) {
                        showAppSnackBar(
                          'Payment cannot be greater than ${formatMoney(maximumAllowed)}',
                        );
                        return;
                      }

                      final updatedPayment = Payment(
                        id: payment.id,
                        customerId: payment.customerId,
                        amount: amount,
                        note: noteController.text.trim(),
                        createdAt: payment.createdAt,
                      );

                      Navigator.of(sheetContext).pop();

                      DatabaseHelper.instance
                          .updatePayment(updatedPayment)
                          .then((_) {
                            if (!mounted) return;

                            loadCustomerData();
                            showAppSnackBar('Payment updated successfully');
                          });
                    },
                    icon: const Icon(Icons.save_outlined),
                    label: const Text('Save Changes'),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  void payFullBalance(BuildContext pageContext) {
    if (balance <= 0) {
      showAppSnackBar('This customer has no balance to pay');
      return;
    }

    showDialog<bool>(
      context: pageContext,
      builder: (dialogContext) {
        return AlertDialog(
          title: const Text('Pay Full Balance?'),
          content: Text(
            'This will record a full payment of ${formatMoney(balance)} for ${currentCustomer.name}.',
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.of(dialogContext).pop(false);
              },
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () {
                Navigator.of(dialogContext).pop(true);
              },
              child: const Text('Yes, Pay Full'),
            ),
          ],
        );
      },
    ).then((confirm) {
      if (confirm == true) {
        final payment = Payment(
          customerId: currentCustomer.id!,
          amount: balance,
          note: 'Full balance payment',
          createdAt: DateTime.now().toIso8601String(),
        );

        DatabaseHelper.instance.addPayment(payment).then((_) {
          if (!mounted) return;
          loadCustomerData();
          showAppSnackBar('Full balance payment recorded successfully');
        });
      }
    });
  }

  void deleteSingleItem(CreditItem item) {
    DatabaseHelper.instance.deleteCreditItem(item.id!).then((_) {
      if (!mounted) return;
      loadCustomerData();
      showAppSnackBar('Credit item deleted and balance updated');
    });
  }

  void deleteSinglePayment(Payment payment) {
    DatabaseHelper.instance.deletePayment(payment.id!).then((_) {
      if (!mounted) return;
      loadCustomerData();
      showAppSnackBar('Payment deleted');
    });
  }

  @override
  Widget build(BuildContext context) {
    final groupedItems = groupItemsByDate();
    final groupedKeys = groupedItems.keys.toList();

    return Scaffold(
      appBar: AppBar(
        title: Text(currentCustomer.name),
        actions: [
          IconButton(
            tooltip: 'Edit customer',
            onPressed: () {
              openEditCustomerSheet(context);
            },
            icon: const Icon(Icons.edit_outlined),
          ),
          IconButton(
            tooltip: 'Add credit item',
            onPressed: () {
              openAddItemSheet(context);
            },
            icon: const Icon(Icons.add_circle_outline),
          ),
          PopupMenuButton<String>(
            tooltip: 'More options',
            onSelected: (value) {
              if (value == 'delete_customer') {
                confirmDeleteCustomer(context);
              }
            },
            itemBuilder: (context) {
              return const [
                PopupMenuItem(
                  value: 'delete_customer',
                  child: Text('Delete customer'),
                ),
              ];
            },
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () {
          openAddItemSheet(context);
        },
        icon: const Icon(Icons.add),
        label: const Text('Add Item'),
      ),
      body: loading
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: loadCustomerData,
              child: ListView(
                padding: const EdgeInsets.all(18),
                children: [
                  buildCustomerDebtCard(),
                  const SizedBox(height: 18),
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton.icon(
                          onPressed: () {
                            openAddItemSheet(context);
                          },
                          icon: const Icon(Icons.add_shopping_cart),
                          label: const Text('Add Credit'),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: FilledButton.icon(
                          onPressed: () {
                            openAddPaymentSheet(context);
                          },
                          icon: const Icon(Icons.payments_outlined),
                          label: const Text('Add Payment'),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  SizedBox(
                    width: double.infinity,
                    height: 48,
                    child: FilledButton.tonalIcon(
                      onPressed: () {
                        payFullBalance(context);
                      },
                      icon: const Icon(Icons.done_all),
                      label: const Text('Pay Full Balance'),
                    ),
                  ),
                  const SizedBox(height: 24),
                  const Text(
                    'Credit Records by Date',
                    style: TextStyle(fontSize: 20, fontWeight: FontWeight.w900),
                  ),
                  const SizedBox(height: 12),
                  if (items.isEmpty)
                    buildEmptyItems()
                  else
                    ...groupedKeys.map((dateKey) {
                      final dailyItems = groupedItems[dateKey]!;
                      final dailyTotal = calculateDailyTotal(dailyItems);

                      return buildDailySection(
                        pageContext: context,
                        dateKey: dateKey,
                        dailyItems: dailyItems,
                        dailyTotal: dailyTotal,
                      );
                    }),
                  const SizedBox(height: 24),
                  const Text(
                    'Payment History',
                    style: TextStyle(fontSize: 20, fontWeight: FontWeight.w900),
                  ),
                  const SizedBox(height: 12),
                  if (payments.isEmpty)
                    buildEmptyPayments()
                  else
                    ...payments.map((payment) {
                      return buildPaymentTile(context, payment);
                    }),
                  const SizedBox(height: 90),
                ],
              ),
            ),
    );
  }

  Widget buildCustomerDebtCard() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(22),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(26),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withAlpha(10),
            blurRadius: 14,
            offset: const Offset(0, 7),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              CircleAvatar(
                radius: 29,
                backgroundColor: const Color(0xFFE0F2F1),
                child: Text(
                  currentCustomer.name.isNotEmpty
                      ? currentCustomer.name[0].toUpperCase()
                      : '?',
                  style: const TextStyle(
                    color: Color(0xFF0F766E),
                    fontWeight: FontWeight.w900,
                    fontSize: 22,
                  ),
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      currentCustomer.name,
                      style: const TextStyle(
                        fontSize: 19,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      currentCustomer.phone.isEmpty
                          ? 'No phone number'
                          : currentCustomer.phone,
                      style: TextStyle(color: Colors.grey.shade600),
                    ),
                    if (currentCustomer.location.isNotEmpty)
                      Text(
                        currentCustomer.location,
                        style: TextStyle(color: Colors.grey.shade600),
                      ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 22),
          Text(
            'Current Balance',
            style: TextStyle(color: Colors.grey.shade600),
          ),
          const SizedBox(height: 6),
          Text(
            formatMoney(balance),
            style: TextStyle(
              fontSize: 34,
              fontWeight: FontWeight.w900,
              color: balance > 0 ? Colors.red.shade700 : Colors.green.shade700,
            ),
          ),
          const SizedBox(height: 18),
          Row(
            children: [
              Expanded(
                child: buildMiniStat(
                  title: 'Total Credit',
                  value: formatMoney(totalCredit),
                  icon: Icons.shopping_cart_outlined,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: buildMiniStat(
                  title: 'Total Paid',
                  value: formatMoney(totalPaid),
                  icon: Icons.check_circle_outline,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget buildMiniStat({
    required String title,
    required String value,
    required IconData icon,
  }) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFFF6F8FA),
        borderRadius: BorderRadius.circular(18),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: const Color(0xFF0F766E), size: 22),
          const SizedBox(height: 8),
          Text(
            title,
            style: TextStyle(color: Colors.grey.shade600, fontSize: 12),
          ),
          const SizedBox(height: 4),
          Text(
            value,
            style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 14),
          ),
        ],
      ),
    );
  }

  Widget buildEmptyItems() {
    return Container(
      padding: const EdgeInsets.all(30),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(22),
      ),
      child: Column(
        children: [
          Icon(
            Icons.receipt_long_outlined,
            size: 75,
            color: Colors.grey.shade400,
          ),
          const SizedBox(height: 12),
          const Text(
            'No credit items yet',
            style: TextStyle(fontWeight: FontWeight.w800, fontSize: 18),
          ),
          const SizedBox(height: 6),
          Text(
            'Tap “Add Item” when this customer gets groceries on credit.',
            textAlign: TextAlign.center,
            style: TextStyle(color: Colors.grey.shade600),
          ),
        ],
      ),
    );
  }

  Widget buildEmptyPayments() {
    return Container(
      padding: const EdgeInsets.all(30),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(22),
      ),
      child: Column(
        children: [
          Icon(Icons.payments_outlined, size: 65, color: Colors.grey.shade400),
          const SizedBox(height: 12),
          const Text(
            'No payments recorded',
            style: TextStyle(fontWeight: FontWeight.w800, fontSize: 18),
          ),
          const SizedBox(height: 6),
          Text(
            'Payments will appear here after the customer pays.',
            textAlign: TextAlign.center,
            style: TextStyle(color: Colors.grey.shade600),
          ),
        ],
      ),
    );
  }

  Widget buildDailySection({
    required BuildContext pageContext,
    required String dateKey,
    required List<CreditItem> dailyItems,
    required double dailyTotal,
  }) {
    final date = DateTime.parse(dateKey);

    return Container(
      margin: const EdgeInsets.only(bottom: 14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(22),
      ),
      child: ExpansionTile(
        initiallyExpanded: true,
        tilePadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        childrenPadding: const EdgeInsets.only(bottom: 10),
        title: Text(
          DateFormat('EEEE, dd MMM yyyy').format(date),
          style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 15),
        ),
        subtitle: Text(
          'Daily credit total: ${formatMoney(dailyTotal)}',
          style: const TextStyle(
            color: Color(0xFF0F766E),
            fontWeight: FontWeight.w700,
          ),
        ),
        children: dailyItems.map((item) {
          return buildItemTile(pageContext, item);
        }).toList(),
      ),
    );
  }

  Widget buildItemTile(BuildContext pageContext, CreditItem item) {
    return ListTile(
      leading: const CircleAvatar(
        backgroundColor: Color(0xFFFFF7ED),
        child: Icon(Icons.shopping_bag_outlined, color: Colors.orange),
      ),
      title: Text(
        item.itemName,
        style: const TextStyle(fontWeight: FontWeight.w800),
      ),
      subtitle: Text(
        '${item.quantity} × ${formatMoney(item.unitPrice)} • ${formatTime(item.createdAt)}',
      ),
      trailing: PopupMenuButton<String>(
        onSelected: (value) {
          if (value == 'edit') {
            openEditItemSheet(pageContext, item);
          } else if (value == 'delete') {
            deleteSingleItem(item);
          }
        },
        itemBuilder: (context) {
          return const [
            PopupMenuItem(value: 'edit', child: Text('Edit item')),
            PopupMenuItem(value: 'delete', child: Text('Delete item')),
          ];
        },
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Text(
              formatMoney(item.total),
              style: TextStyle(
                fontWeight: FontWeight.w900,
                color: Colors.red.shade700,
              ),
            ),
            const Text(
              'Credit',
              style: TextStyle(fontSize: 12, color: Colors.grey),
            ),
          ],
        ),
      ),
    );
  }

  Widget buildPaymentTile(BuildContext pageContext, Payment payment) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
      ),
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor: Colors.green.shade50,
          child: const Icon(Icons.check, color: Colors.green),
        ),
        title: Text(
          formatMoney(payment.amount),
          style: const TextStyle(
            fontWeight: FontWeight.w900,
            color: Colors.green,
          ),
        ),
        subtitle: Text(
          '${formatDate(payment.createdAt)} • ${formatTime(payment.createdAt)}'
          '${payment.note.isEmpty ? '' : '\n${payment.note}'}',
        ),
        trailing: PopupMenuButton<String>(
          onSelected: (value) {
            if (value == 'edit') {
              openEditPaymentSheet(pageContext, payment);
            } else if (value == 'delete') {
              deleteSinglePayment(payment);
            }
          },
          itemBuilder: (context) {
            return const [
              PopupMenuItem(value: 'edit', child: Text('Edit payment')),
              PopupMenuItem(value: 'delete', child: Text('Delete payment')),
            ];
          },
        ),
      ),
    );
  }
}

/* =========================
   REUSABLE TEXT FIELD
========================= */

class CustomTextField extends StatelessWidget {
  final TextEditingController controller;
  final String label;
  final IconData icon;
  final TextInputType keyboardType;

  const CustomTextField({
    super.key,
    required this.controller,
    required this.label,
    required this.icon,
    this.keyboardType = TextInputType.text,
  });

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: controller,
      keyboardType: keyboardType,
      decoration: InputDecoration(
        labelText: label,
        prefixIcon: Icon(icon),
        filled: true,
        fillColor: const Color(0xFFF6F8FA),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(18),
          borderSide: BorderSide.none,
        ),
      ),
    );
  }
}
