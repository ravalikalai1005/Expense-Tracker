
import 'dart:convert';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  runApp(const ExpenseTrackerApp());
}

// ============================================================
// APP
// ============================================================

class ExpenseTrackerApp extends StatefulWidget {
  const ExpenseTrackerApp({super.key});

  @override
  State<ExpenseTrackerApp> createState() => _ExpenseTrackerAppState();
}

class _ExpenseTrackerAppState extends State<ExpenseTrackerApp> {
  ThemeMode themeMode = ThemeMode.system;

  @override
  void initState() {
    super.initState();
    loadTheme();
  }

  Future<void> loadTheme() async {
    final prefs = await SharedPreferences.getInstance();
    final saved = prefs.getString('themeMode');

    if (!mounted) return;
    setState(() {
      themeMode = saved == 'light'
          ? ThemeMode.light
          : saved == 'dark'
          ? ThemeMode.dark
          : ThemeMode.system;
    });
  }

  Future<void> changeTheme(ThemeMode mode) async {
    final prefs = await SharedPreferences.getInstance();
    final value = mode == ThemeMode.light
        ? 'light'
        : mode == ThemeMode.dark
        ? 'dark'
        : 'system';

    await prefs.setString('themeMode', value);

    if (!mounted) return;
    setState(() {
      themeMode = mode;
    });
  }

  @override
  Widget build(BuildContext context) {
    final lightScheme = ColorScheme.fromSeed(
      seedColor: Colors.green,
      brightness: Brightness.light,
    );
    final darkScheme = ColorScheme.fromSeed(
      seedColor: Colors.green,
      brightness: Brightness.dark,
    );

    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'Expense Tracker',
      themeMode: themeMode,
      theme: ThemeData(
        colorScheme: lightScheme,
        useMaterial3: true,
        scaffoldBackgroundColor: const Color(0xFFF7F9F7),
        inputDecorationTheme: InputDecorationTheme(
          filled: true,
          fillColor: Colors.white,
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(14),
          ),
        ),
        cardTheme: CardThemeData(
          elevation: 0,
          margin: EdgeInsets.zero,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(18),
          ),
        ),
      ),
      darkTheme: ThemeData(
        colorScheme: darkScheme,
        useMaterial3: true,
        cardTheme: CardThemeData(
          elevation: 0,
          margin: EdgeInsets.zero,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(18),
          ),
        ),
      ),
      home: HomePage(
        currentTheme: themeMode,
        onThemeChanged: changeTheme,
      ),
    );
  }
}

// ============================================================
// MODEL
// ============================================================

class TransactionItem {
  final String id;
  final String name;
  final double amount;
  final String type;
  final String category;
  final DateTime date;

  TransactionItem({
    required this.id,
    required this.name,
    required this.amount,
    required this.type,
    required this.category,
    required this.date,
  });

  Map<String, dynamic> toMap() => {
    'id': id,
    'name': name,
    'amount': amount,
    'type': type,
    'category': category,
    'date': date.toIso8601String(),
  };

  factory TransactionItem.fromMap(Map<String, dynamic> map) {
    return TransactionItem(
      id: map['id']?.toString() ?? DateTime.now().millisecondsSinceEpoch.toString(),
      name: map['name']?.toString() ?? '',
      amount: (map['amount'] as num).toDouble(),
      type: map['type']?.toString() ?? 'expense',
      category: map['category']?.toString() ?? 'Other',
      date: DateTime.tryParse(map['date']?.toString() ?? '') ?? DateTime.now(),
    );
  }
}

// ============================================================
// HOME PAGE
// ============================================================

class HomePage extends StatefulWidget {
  final ThemeMode currentTheme;
  final Future<void> Function(ThemeMode) onThemeChanged;

  const HomePage({
    super.key,
    required this.currentTheme,
    required this.onThemeChanged,
  });

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  List<TransactionItem> transactions = [];

  List<String> categories = [
    'Food',
    'Travel',
    'Shopping',
    'Entertainment',
    'Bills',
    'Health',
    'Education',
    'Electronics',
    'Other',
  ];

  static const List<String> incomeCategories = [
    'Salary',
    'Pocket Money',
    'Freelance',
    'Business',
    'Other',
  ];

  bool loading = true;
  String searchText = '';
  String selectedCategory = 'All';
  DateTime? selectedMonth;
  double monthlyBudget = 0;

  final currencyFormat = NumberFormat.currency(
    locale: 'en_IN',
    symbol: '₹',
    decimalDigits: 2,
  );

  IconData categoryIcon(String category) {
    switch (category.toLowerCase()) {
      case 'food':
        return Icons.restaurant;
      case 'travel':
        return Icons.flight;
      case 'shopping':
        return Icons.shopping_bag;
      case 'entertainment':
        return Icons.movie;
      case 'bills':
        return Icons.receipt_long;
      case 'health':
        return Icons.medical_services;
      case 'education':
        return Icons.school;
      case 'electronics':
        return Icons.devices;
      case 'salary':
        return Icons.work;
      case 'pocket money':
        return Icons.account_balance_wallet;
      case 'freelance':
        return Icons.laptop_mac;
      case 'business':
        return Icons.business;
      default:
        return Icons.category;
    }
  }

  double get totalIncome => transactions
      .where((t) => t.type == 'income')
      .fold(0, (sum, t) => sum + t.amount);

  double get totalExpense => transactions
      .where((t) => t.type == 'expense')
      .fold(0, (sum, t) => sum + t.amount);

  double get balance => totalIncome - totalExpense;

  DateTime get currentMonth {
    final now = DateTime.now();
    return DateTime(now.year, now.month);
  }

  double get currentMonthExpense => transactions
      .where((t) =>
  t.type == 'expense' &&
      t.date.year == currentMonth.year &&
      t.date.month == currentMonth.month)
      .fold(0, (sum, t) => sum + t.amount);

  double get budgetProgress {
    if (monthlyBudget <= 0) return 0;
    return (currentMonthExpense / monthlyBudget).clamp(0.0, 1.0);
  }

  @override
  void initState() {
    super.initState();
    loadData();
  }

  Future<void> loadData() async {
    final prefs = await SharedPreferences.getInstance();

    final transactionData = prefs.getString('transactions');
    final categoryData = prefs.getString('categories');

    List<TransactionItem> loadedTransactions = [];
    if (transactionData != null) {
      try {
        final List decoded = jsonDecode(transactionData);
        loadedTransactions = decoded
            .map((item) => TransactionItem.fromMap(
          Map<String, dynamic>.from(item),
        ))
            .toList();
      } catch (_) {
        loadedTransactions = [];
      }
    }

    List<String> loadedCategories = List<String>.from(categories);
    if (categoryData != null) {
      try {
        loadedCategories = List<String>.from(jsonDecode(categoryData));
      } catch (_) {}
    }

    if (!mounted) return;
    setState(() {
      transactions = loadedTransactions;
      categories = loadedCategories.isEmpty ? List<String>.from(categories) : loadedCategories;
      monthlyBudget = prefs.getDouble('monthlyBudget') ?? 0;
      loading = false;
    });
  }

  Future<void> saveData() async {
    final prefs = await SharedPreferences.getInstance();

    await prefs.setString(
      'transactions',
      jsonEncode(transactions.map((t) => t.toMap()).toList()),
    );
    await prefs.setString('categories', jsonEncode(categories));
    await prefs.setDouble('monthlyBudget', monthlyBudget);
  }

  List<TransactionItem> get filteredTransactions {
    return transactions.where((transaction) {
      final query = searchText.toLowerCase().trim();

      final matchesSearch = query.isEmpty ||
          transaction.name.toLowerCase().contains(query) ||
          transaction.category.toLowerCase().contains(query);

      final matchesCategory = selectedCategory == 'All' ||
          transaction.category == selectedCategory;

      final matchesMonth = selectedMonth == null ||
          (transaction.date.year == selectedMonth!.year &&
              transaction.date.month == selectedMonth!.month);

      return matchesSearch && matchesCategory && matchesMonth;
    }).toList();
  }

  Future<void> addTransaction({
    required String name,
    required double amount,
    required String type,
    required String category,
    required DateTime date,
  }) async {
    setState(() {
      transactions.insert(
        0,
        TransactionItem(
          id: DateTime.now().microsecondsSinceEpoch.toString(),
          name: name,
          amount: amount,
          type: type,
          category: category,
          date: date,
        ),
      );
    });
    await saveData();
  }

  Future<void> deleteTransaction(TransactionItem transaction) async {
    setState(() {
      transactions.removeWhere((t) => t.id == transaction.id);
    });
    await saveData();
  }

  Future<void> editTransaction(TransactionItem oldTransaction) async {
    final nameController = TextEditingController(text: oldTransaction.name);
    final amountController =
    TextEditingController(text: oldTransaction.amount.toString());

    String type = oldTransaction.type;
    String category = oldTransaction.category;
    DateTime selectedDate = oldTransaction.date;

    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (sheetContext) {
        return StatefulBuilder(
          builder: (context, setModalState) {
            final available =
            type == 'expense' ? categories : incomeCategories.toList();

            if (!available.contains(category)) {
              category = available.first;
            }

            return _TransactionForm(
              title: 'Edit Transaction',
              type: type,
              nameController: nameController,
              amountController: amountController,
              category: category,
              categories: available,
              selectedDate: selectedDate,
              categoryIcon: categoryIcon,
              onTypeChanged: (value) {
                setModalState(() {
                  type = value;
                  category = value == 'expense'
                      ? categories.first
                      : incomeCategories.first;
                });
              },
              onCategoryChanged: (value) {
                setModalState(() => category = value);
              },
              onDateChanged: (date) {
                setModalState(() => selectedDate = date);
              },
              buttonText: 'Save Changes',
              onSubmit: () async {
                final name = nameController.text.trim();
                final amount = double.tryParse(amountController.text.trim());

                if (name.isEmpty || amount == null || amount <= 0) {
                  _showMessage('Please enter a valid name and amount.');
                  return;
                }

                final index =
                transactions.indexWhere((t) => t.id == oldTransaction.id);

                if (index != -1) {
                  setState(() {
                    transactions[index] = TransactionItem(
                      id: oldTransaction.id,
                      name: name,
                      amount: amount,
                      type: type,
                      category: category,
                      date: selectedDate,
                    );
                  });
                  await saveData();
                }

                if (sheetContext.mounted) Navigator.pop(sheetContext);
              },
            );
          },
        );
      },
    );

    nameController.dispose();
    amountController.dispose();
  }

  Future<void> showTransactionForm({required String type}) async {
    final nameController = TextEditingController();
    final amountController = TextEditingController();
    DateTime selectedDate = DateTime.now();
    String category =
    type == 'expense' ? categories.first : incomeCategories.first;

    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (sheetContext) {
        return StatefulBuilder(
          builder: (context, setModalState) {
            final available =
            type == 'expense' ? categories : incomeCategories.toList();

            return _TransactionForm(
              title: type == 'expense' ? 'Add Expense' : 'Add Income',
              type: type,
              nameController: nameController,
              amountController: amountController,
              category: category,
              categories: available,
              selectedDate: selectedDate,
              categoryIcon: categoryIcon,
              onTypeChanged: (_) {},
              onCategoryChanged: (value) {
                setModalState(() => category = value);
              },
              onDateChanged: (date) {
                setModalState(() => selectedDate = date);
              },
              buttonText: type == 'expense' ? 'Add Expense' : 'Add Income',
              onSubmit: () async {
                final name = nameController.text.trim();
                final amount = double.tryParse(amountController.text.trim());

                if (name.isEmpty || amount == null || amount <= 0) {
                  _showMessage('Please enter a valid name and amount.');
                  return;
                }

                await addTransaction(
                  name: name,
                  amount: amount,
                  type: type,
                  category: category,
                  date: selectedDate,
                );

                if (sheetContext.mounted) Navigator.pop(sheetContext);
              },
              allowTypeChange: false,
            );
          },
        );
      },
    );

    nameController.dispose();
    amountController.dispose();
  }

  void _showMessage(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message)),
    );
  }

  void openStatistics() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => StatisticsPage(
          transactions: transactions,
          categoryIcon: categoryIcon,
        ),
      ),
    );
  }

  void openSettings() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => SettingsPage(
          currentTheme: widget.currentTheme,
          onThemeChanged: widget.onThemeChanged,
          onManageCategories: manageCategories,
          monthlyBudget: monthlyBudget,
          onBudgetChanged: (value) async {
            setState(() => monthlyBudget = value);
            await saveData();
          },
        ),
      ),
    ).then((_) => loadData());
  }

  Future<void> manageCategories() async {
    final controller = TextEditingController();

    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (sheetContext) {
        return StatefulBuilder(
          builder: (context, setModalState) {
            return SafeArea(
              child: Padding(
                padding: EdgeInsets.fromLTRB(
                  20,
                  10,
                  20,
                  MediaQuery.of(context).viewInsets.bottom + 20,
                ),
                child: SizedBox(
                  height: MediaQuery.of(context).size.height * 0.72,
                  child: Column(
                    children: [
                      const Text(
                        'Manage Categories',
                        style: TextStyle(
                          fontSize: 24,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 16),
                      TextField(
                        controller: controller,
                        textCapitalization: TextCapitalization.words,
                        decoration: const InputDecoration(
                          labelText: 'New Category',
                          prefixIcon: Icon(Icons.category),
                        ),
                      ),
                      const SizedBox(height: 10),
                      SizedBox(
                        width: double.infinity,
                        child: FilledButton.icon(
                          onPressed: () async {
                            final name = controller.text.trim();
                            if (name.isEmpty) return;

                            final exists = categories.any(
                                  (item) => item.toLowerCase() == name.toLowerCase(),
                            );

                            if (exists) {
                              _showMessage('Category already exists.');
                              return;
                            }

                            setState(() => categories.add(name));
                            await saveData();
                            controller.clear();
                            setModalState(() {});
                          },
                          icon: const Icon(Icons.add),
                          label: const Text('Add Category'),
                        ),
                      ),
                      const SizedBox(height: 8),
                      Expanded(
                        child: ListView.separated(
                          itemCount: categories.length,
                          separatorBuilder: (_, __) => const Divider(height: 1),
                          itemBuilder: (_, index) {
                            final category = categories[index];

                            return ListTile(
                              leading: CircleAvatar(
                                child: Icon(categoryIcon(category)),
                              ),
                              title: Text(category),
                              trailing: IconButton(
                                tooltip: 'Delete',
                                icon: const Icon(Icons.delete_outline),
                                onPressed: () async {
                                  if (transactions.any(
                                        (t) =>
                                    t.type == 'expense' &&
                                        t.category == category,
                                  )) {
                                    _showMessage(
                                      'This category is used by a transaction.',
                                    );
                                    return;
                                  }

                                  setState(() => categories.removeAt(index));
                                  if (selectedCategory == category) {
                                    selectedCategory = 'All';
                                  }
                                  await saveData();
                                  setModalState(() {});
                                },
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
          },
        );
      },
    );

    controller.dispose();
  }

  Future<void> chooseMonth() async {
    final initial = selectedMonth ?? DateTime.now();

    final picked = await showDialog<DateTime>(
      context: context,
      builder: (context) {
        int year = initial.year;
        int month = initial.month;

        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              title: const Text('Filter by Month'),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  DropdownButtonFormField<int>(
                    value: month,
                    decoration: const InputDecoration(labelText: 'Month'),
                    items: List.generate(
                      12,
                          (index) => DropdownMenuItem(
                        value: index + 1,
                        child: Text(
                          DateFormat.MMMM().format(DateTime(2020, index + 1)),
                        ),
                      ),
                    ),
                    onChanged: (value) {
                      if (value != null) {
                        setDialogState(() => month = value);
                      }
                    },
                  ),
                  const SizedBox(height: 12),
                  DropdownButtonFormField<int>(
                    value: year,
                    decoration: const InputDecoration(labelText: 'Year'),
                    items: List.generate(
                      11,
                          (index) => DropdownMenuItem(
                        value: DateTime.now().year - 5 + index,
                        child: Text('${DateTime.now().year - 5 + index}'),
                      ),
                    ),
                    onChanged: (value) {
                      if (value != null) {
                        setDialogState(() => year = value);
                      }
                    },
                  ),
                ],
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text('Cancel'),
                ),
                TextButton(
                  onPressed: () => Navigator.pop(
                    context,
                    DateTime(year, month),
                  ),
                  child: const Text('Apply'),
                ),
              ],
            );
          },
        );
      },
    );

    if (picked != null) {
      setState(() => selectedMonth = picked);
    }
  }

  Future<void> showBudgetDialog() async {
    final controller = TextEditingController(
      text: monthlyBudget > 0 ? monthlyBudget.toStringAsFixed(0) : '',
    );

    await showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Monthly Budget'),
          content: TextField(
            controller: controller,
            autofocus: true,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            decoration: const InputDecoration(
              labelText: 'Budget amount',
              prefixText: '₹ ',
            ),
          ),
          actions: [
            if (monthlyBudget > 0)
              TextButton(
                onPressed: () async {
                  setState(() => monthlyBudget = 0);
                  await saveData();
                  if (context.mounted) Navigator.pop(context);
                },
                child: const Text('Remove'),
              ),
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () async {
                final value = double.tryParse(controller.text.trim());
                if (value == null || value <= 0) return;

                setState(() => monthlyBudget = value);
                await saveData();

                if (context.mounted) Navigator.pop(context);
              },
              child: const Text('Save'),
            ),
          ],
        );
      },
    );

    controller.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (loading) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }

    final filtered = filteredTransactions;
    final theme = Theme.of(context);
    final hasBudget = monthlyBudget > 0;
    final overBudget = hasBudget && currentMonthExpense > monthlyBudget;

    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'Expense Tracker',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        centerTitle: true,
        actions: [
          IconButton(
            tooltip: 'Statistics',
            icon: const Icon(Icons.bar_chart_rounded),
            onPressed: openStatistics,
          ),
          IconButton(
            tooltip: 'Settings',
            icon: const Icon(Icons.settings_outlined),
            onPressed: openSettings,
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: loadData,
        child: ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 110),
          children: [
            Container(
              padding: const EdgeInsets.all(22),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [
                    theme.colorScheme.primary,
                    theme.colorScheme.primaryContainer,
                  ],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(24),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Total Balance',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 15,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    currencyFormat.format(balance),
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 32,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      _balanceMini(
                        icon: Icons.arrow_downward_rounded,
                        label: 'Income',
                        value: totalIncome,
                      ),
                      const SizedBox(width: 24),
                      _balanceMini(
                        icon: Icons.arrow_upward_rounded,
                        label: 'Expense',
                        value: totalExpense,
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: 14),
            Row(
              children: [
                Expanded(
                  child: _summaryCard(
                    title: 'Income',
                    amount: totalIncome,
                    icon: Icons.south_west_rounded,
                    color: Colors.green,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _summaryCard(
                    title: 'Expense',
                    amount: totalExpense,
                    icon: Icons.north_east_rounded,
                    color: Colors.red,
                  ),
                ),
              ],
            ),
            if (hasBudget) ...[
              const SizedBox(height: 14),
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    children: [
                      Row(
                        children: [
                          CircleAvatar(
                            backgroundColor: overBudget
                                ? Colors.red.withOpacity(.12)
                                : Colors.green.withOpacity(.12),
                            child: Icon(
                              overBudget
                                  ? Icons.warning_amber_rounded
                                  : Icons.savings_outlined,
                              color: overBudget ? Colors.red : Colors.green,
                            ),
                          ),
                          const SizedBox(width: 12),
                          const Expanded(
                            child: Text(
                              'Monthly Budget',
                              style: TextStyle(fontWeight: FontWeight.bold),
                            ),
                          ),
                          Text(
                            currencyFormat.format(monthlyBudget),
                            style: const TextStyle(fontWeight: FontWeight.bold),
                          ),
                          IconButton(
                            tooltip: 'Edit budget',
                            onPressed: showBudgetDialog,
                            icon: const Icon(Icons.edit_outlined, size: 20),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      LinearProgressIndicator(
                        value: budgetProgress,
                        minHeight: 9,
                        borderRadius: BorderRadius.circular(10),
                        color: overBudget ? Colors.red : Colors.green,
                      ),
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              overBudget
                                  ? 'Budget exceeded by ${currencyFormat.format(currentMonthExpense - monthlyBudget)}'
                                  : '${currencyFormat.format(monthlyBudget - currentMonthExpense)} remaining',
                              style: TextStyle(
                                color: overBudget ? Colors.red : null,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                          Text(
                            '${(currentMonthExpense / monthlyBudget * 100).clamp(0, 999).toStringAsFixed(0)}%',
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ],
            const SizedBox(height: 16),
            TextField(
              onChanged: (value) => setState(() => searchText = value),
              decoration: InputDecoration(
                hintText: 'Search by name or category...',
                prefixIcon: const Icon(Icons.search),
                suffixIcon: searchText.isNotEmpty
                    ? IconButton(
                  onPressed: () => setState(() => searchText = ''),
                  icon: const Icon(Icons.clear),
                )
                    : null,
              ),
            ),
            const SizedBox(height: 10),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: chooseMonth,
                    icon: const Icon(Icons.calendar_month_outlined),
                    label: Text(
                      selectedMonth == null
                          ? 'All Months'
                          : DateFormat('MMM yyyy').format(selectedMonth!),
                    ),
                  ),
                ),
                if (selectedMonth != null) ...[
                  const SizedBox(width: 8),
                  IconButton(
                    tooltip: 'Clear month',
                    onPressed: () => setState(() => selectedMonth = null),
                    icon: const Icon(Icons.close),
                  ),
                ],
              ],
            ),
            const SizedBox(height: 10),
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: [
                  _filterChip('All', Icons.list_alt_rounded),
                  ...categories.map(
                        (category) =>
                        _filterChip(category, categoryIcon(category)),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 22),
            Row(
              children: [
                const Expanded(
                  child: Text(
                    'Recent Transactions',
                    style: TextStyle(
                      fontSize: 21,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                Text(
                  '${filtered.length} item${filtered.length == 1 ? '' : 's'}',
                  style: TextStyle(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            if (filtered.isEmpty)
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(32),
                  child: Column(
                    children: [
                      Icon(
                        Icons.receipt_long_outlined,
                        size: 52,
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                      const SizedBox(height: 10),
                      const Text(
                        'No transactions found',
                        style: TextStyle(fontWeight: FontWeight.bold),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Try another search or filter.',
                        style: TextStyle(
                          color: theme.colorScheme.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ),
                ),
              )
            else
              ...filtered.map(_transactionCard),
          ],
        ),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _showAddMenu,
        icon: const Icon(Icons.add),
        label: const Text('Add'),
      ),
    );
  }

  Widget _balanceMini({
    required IconData icon,
    required String label,
    required double value,
  }) {
    return Expanded(
      child: Row(
        children: [
          Icon(icon, color: Colors.white, size: 18),
          const SizedBox(width: 6),
          Expanded(
            child: Text(
              '$label\n${currencyFormat.format(value)}',
              style: const TextStyle(
                color: Colors.white,
                height: 1.35,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _summaryCard({
    required String title,
    required double amount,
    required IconData icon,
    required Color color,
  }) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            CircleAvatar(
              radius: 18,
              backgroundColor: color.withOpacity(.12),
              child: Icon(icon, color: color, size: 20),
            ),
            const SizedBox(height: 10),
            Text(title),
            const SizedBox(height: 4),
            FittedBox(
              alignment: Alignment.centerLeft,
              fit: BoxFit.scaleDown,
              child: Text(
                currencyFormat.format(amount),
                style: const TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _filterChip(String category, IconData icon) {
    return Padding(
      padding: const EdgeInsets.only(right: 7),
      child: ChoiceChip(
        avatar: Icon(icon, size: 17),
        label: Text(category),
        selected: selectedCategory == category,
        onSelected: (_) {
          setState(() => selectedCategory = category);
        },
      ),
    );
  }

  Widget _transactionCard(TransactionItem transaction) {
    final isIncome = transaction.type == 'income';
    final color = isIncome ? Colors.green : Colors.red;

    return Card(
      margin: const EdgeInsets.only(bottom: 10),
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 12,
          vertical: 6,
        ),
        leading: CircleAvatar(
          backgroundColor: color.withOpacity(.12),
          child: Icon(categoryIcon(transaction.category), color: color),
        ),
        title: Text(
          transaction.name,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: const TextStyle(fontWeight: FontWeight.bold),
        ),
        subtitle: Text(
          '${transaction.category} • ${DateFormat('dd MMM yyyy').format(transaction.date)}',
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
        trailing: SizedBox(
          width: 112,
          child: Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              Expanded(
                child: Text(
                  '${isIncome ? '+' : '-'}${currencyFormat.format(transaction.amount)}',
                  textAlign: TextAlign.end,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: color,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
              PopupMenuButton<String>(
                padding: EdgeInsets.zero,
                onSelected: (value) {
                  if (value == 'edit') editTransaction(transaction);
                  if (value == 'delete') deleteTransaction(transaction);
                },
                itemBuilder: (_) => const [
                  PopupMenuItem(
                    value: 'edit',
                    child: Text('Edit'),
                  ),
                  PopupMenuItem(
                    value: 'delete',
                    child: Text('Delete'),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _showAddMenu() {
    showModalBottomSheet(
      context: context,
      showDragHandle: true,
      builder: (sheetContext) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const ListTile(
                  title: Text(
                    'Add Transaction',
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                ListTile(
                  leading: CircleAvatar(
                    child: const Icon(Icons.arrow_downward_rounded),
                  ),
                  title: const Text('Add Income'),
                  subtitle: const Text('Record money you received'),
                  onTap: () {
                    Navigator.pop(sheetContext);
                    showTransactionForm(type: 'income');
                  },
                ),
                ListTile(
                  leading: CircleAvatar(
                    child: const Icon(Icons.arrow_upward_rounded),
                  ),
                  title: const Text('Add Expense'),
                  subtitle: const Text('Record money you spent'),
                  onTap: () {
                    Navigator.pop(sheetContext);
                    showTransactionForm(type: 'expense');
                  },
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

// ============================================================
// TRANSACTION FORM
// ============================================================

class _TransactionForm extends StatelessWidget {
  final String title;
  final String type;
  final TextEditingController nameController;
  final TextEditingController amountController;
  final String category;
  final List<String> categories;
  final DateTime selectedDate;
  final IconData Function(String) categoryIcon;
  final ValueChanged<String> onTypeChanged;
  final ValueChanged<String> onCategoryChanged;
  final ValueChanged<DateTime> onDateChanged;
  final String buttonText;
  final VoidCallback onSubmit;
  final bool allowTypeChange;

  const _TransactionForm({
    required this.title,
    required this.type,
    required this.nameController,
    required this.amountController,
    required this.category,
    required this.categories,
    required this.selectedDate,
    required this.categoryIcon,
    required this.onTypeChanged,
    required this.onCategoryChanged,
    required this.onDateChanged,
    required this.buttonText,
    required this.onSubmit,
    this.allowTypeChange = true,
  });

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Padding(
        padding: EdgeInsets.fromLTRB(
          20,
          8,
          20,
          MediaQuery.of(context).viewInsets.bottom + 20,
        ),
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Text(
                  title,
                  style: const TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
              const SizedBox(height: 20),
              if (allowTypeChange)
                DropdownButtonFormField<String>(
                  value: type,
                  decoration: const InputDecoration(
                    labelText: 'Type',
                    prefixIcon: Icon(Icons.swap_vert),
                  ),
                  items: const [
                    DropdownMenuItem(
                      value: 'income',
                      child: Text('Income'),
                    ),
                    DropdownMenuItem(
                      value: 'expense',
                      child: Text('Expense'),
                    ),
                  ],
                  onChanged: (value) {
                    if (value != null) onTypeChanged(value);
                  },
                ),
              if (allowTypeChange) const SizedBox(height: 14),
              TextField(
                controller: nameController,
                textCapitalization: TextCapitalization.sentences,
                decoration: InputDecoration(
                  labelText: type == 'expense' ? 'Expense Name' : 'Income Source',
                  prefixIcon: Icon(
                    type == 'expense'
                        ? Icons.shopping_cart_outlined
                        : Icons.account_balance_wallet_outlined,
                  ),
                ),
              ),
              const SizedBox(height: 14),
              DropdownButtonFormField<String>(
                value: category,
                decoration: const InputDecoration(
                  labelText: 'Category',
                  prefixIcon: Icon(Icons.category_outlined),
                ),
                items: categories.map((item) {
                  return DropdownMenuItem<String>(
                    value: item,
                    child: Row(
                      children: [
                        Icon(categoryIcon(item), size: 21),
                        const SizedBox(width: 10),
                        Text(item),
                      ],
                    ),
                  );
                }).toList(),
                onChanged: (value) {
                  if (value != null) onCategoryChanged(value);
                },
              ),
              const SizedBox(height: 14),
              TextField(
                controller: amountController,
                keyboardType: const TextInputType.numberWithOptions(
                  decimal: true,
                ),
                decoration: const InputDecoration(
                  labelText: 'Amount',
                  prefixText: '₹ ',
                  prefixIcon: Icon(Icons.currency_rupee),
                ),
              ),
              const SizedBox(height: 6),
              ListTile(
                contentPadding: EdgeInsets.zero,
                leading: const Icon(Icons.calendar_month_outlined),
                title: const Text('Date'),
                subtitle: Text(DateFormat('dd MMM yyyy').format(selectedDate)),
                onTap: () async {
                  final date = await showDatePicker(
                    context: context,
                    initialDate: selectedDate,
                    firstDate: DateTime(2000),
                    lastDate: DateTime(2100),
                  );
                  if (date != null) onDateChanged(date);
                },
              ),
              const SizedBox(height: 10),
              SizedBox(
                width: double.infinity,
                height: 52,
                child: FilledButton.icon(
                  onPressed: onSubmit,
                  icon: const Icon(Icons.check),
                  label: Text(buttonText),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ============================================================
// SETTINGS
// ============================================================

class SettingsPage extends StatelessWidget {
  final ThemeMode currentTheme;
  final Future<void> Function(ThemeMode) onThemeChanged;
  final VoidCallback onManageCategories;
  final double monthlyBudget;
  final Future<void> Function(double) onBudgetChanged;

  const SettingsPage({
    super.key,
    required this.currentTheme,
    required this.onThemeChanged,
    required this.onManageCategories,
    required this.monthlyBudget,
    required this.onBudgetChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Settings')),
      body: ListView(
        padding: const EdgeInsets.symmetric(vertical: 8),
        children: [
          const _SectionTitle('Appearance'),
          RadioListTile<ThemeMode>(
            title: const Text('System Default'),
            secondary: const Icon(Icons.phone_android),
            value: ThemeMode.system,
            groupValue: currentTheme,
            onChanged: (value) {
              if (value != null) onThemeChanged(value);
            },
          ),
          RadioListTile<ThemeMode>(
            title: const Text('Light'),
            secondary: const Icon(Icons.light_mode_outlined),
            value: ThemeMode.light,
            groupValue: currentTheme,
            onChanged: (value) {
              if (value != null) onThemeChanged(value);
            },
          ),
          RadioListTile<ThemeMode>(
            title: const Text('Dark'),
            secondary: const Icon(Icons.dark_mode_outlined),
            value: ThemeMode.dark,
            groupValue: currentTheme,
            onChanged: (value) {
              if (value != null) onThemeChanged(value);
            },
          ),
          const Divider(),
          const _SectionTitle('Money'),
          ListTile(
            leading: const Icon(Icons.savings_outlined),
            title: const Text('Monthly Budget'),
            subtitle: Text(
              monthlyBudget > 0
                  ? 'Current: ₹${monthlyBudget.toStringAsFixed(2)}'
                  : 'Not set',
            ),
            trailing: const Icon(Icons.chevron_right),
            onTap: () async {
              final controller = TextEditingController(
                text: monthlyBudget > 0
                    ? monthlyBudget.toStringAsFixed(0)
                    : '',
              );

              await showDialog(
                context: context,
                builder: (dialogContext) {
                  return AlertDialog(
                    title: const Text('Set Monthly Budget'),
                    content: TextField(
                      controller: controller,
                      keyboardType:
                      const TextInputType.numberWithOptions(decimal: true),
                      decoration: const InputDecoration(
                        labelText: 'Budget',
                        prefixText: '₹ ',
                      ),
                    ),
                    actions: [
                      TextButton(
                        onPressed: () => Navigator.pop(dialogContext),
                        child: const Text('Cancel'),
                      ),
                      FilledButton(
                        onPressed: () async {
                          final value =
                          double.tryParse(controller.text.trim());
                          if (value == null || value <= 0) return;

                          await onBudgetChanged(value);
                          if (dialogContext.mounted) {
                            Navigator.pop(dialogContext);
                          }
                        },
                        child: const Text('Save'),
                      ),
                    ],
                  );
                },
              );
              controller.dispose();
            },
          ),
          ListTile(
            leading: const Icon(Icons.currency_rupee),
            title: const Text('Currency'),
            subtitle: const Text('Indian Rupee (₹)'),
          ),
          const Divider(),
          const _SectionTitle('Categories'),
          ListTile(
            leading: const Icon(Icons.category_outlined),
            title: const Text('Manage Categories'),
            subtitle: const Text('Add or remove expense categories'),
            trailing: const Icon(Icons.chevron_right),
            onTap: onManageCategories,
          ),
          const Divider(),
          const _SectionTitle('About'),
          const ListTile(
            leading: Icon(Icons.info_outline),
            title: Text('Expense Tracker'),
            subtitle: Text('Personal expense and income manager'),
          ),
        ],
      ),
    );
  }
}

class _SectionTitle extends StatelessWidget {
  final String text;

  const _SectionTitle(this.text);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 6),
      child: Text(
        text,
        style: TextStyle(
          fontSize: 15,
          fontWeight: FontWeight.bold,
          color: Theme.of(context).colorScheme.primary,
        ),
      ),
    );
  }
}

// ============================================================
// STATISTICS
// ============================================================

class StatisticsPage extends StatelessWidget {
  final List<TransactionItem> transactions;
  final IconData Function(String) categoryIcon;

  const StatisticsPage({
    super.key,
    required this.transactions,
    required this.categoryIcon,
  });

  @override
  Widget build(BuildContext context) {
    final expenses =
    transactions.where((t) => t.type == 'expense').toList();
    final income =
    transactions.where((t) => t.type == 'income').toList();

    final totalExpense =
    expenses.fold(0.0, (sum, t) => sum + t.amount);
    final totalIncome =
    income.fold(0.0, (sum, t) => sum + t.amount);

    final categoryTotals = <String, double>{};
    for (final expense in expenses) {
      categoryTotals[expense.category] =
          (categoryTotals[expense.category] ?? 0) + expense.amount;
    }

    final sorted = categoryTotals.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));

    final chartEntries = sorted
        .map(
          (e) => ChartEntry(
        label: e.key,
        value: e.value,
      ),
    )
        .toList();

    return Scaffold(
      appBar: AppBar(title: const Text('Statistics')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Row(
            children: [
              Expanded(
                child: _statBox(
                  context,
                  'Income',
                  totalIncome,
                  Colors.green,
                  Icons.south_west_rounded,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _statBox(
                  context,
                  'Expense',
                  totalExpense,
                  Colors.red,
                  Icons.north_east_rounded,
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(18),
              child: Column(
                children: [
                  const Align(
                    alignment: Alignment.centerLeft,
                    child: Text(
                      'Expense Distribution',
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  if (chartEntries.isEmpty)
                    const Padding(
                      padding: EdgeInsets.all(35),
                      child: Text('Add expenses to see your chart.'),
                    )
                  else
                    SizedBox(
                      height: 250,
                      child: CustomPaint(
                        painter: ExpensePiePainter(chartEntries),
                        child: Center(
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text(
                                'Total',
                                style: TextStyle(
                                  color: Theme.of(context)
                                      .colorScheme
                                      .onSurfaceVariant,
                                ),
                              ),
                              const SizedBox(height: 3),
                              Text(
                                '₹${totalExpense.toStringAsFixed(0)}',
                                style: const TextStyle(
                                  fontSize: 22,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  if (chartEntries.isNotEmpty) ...[
                    const SizedBox(height: 10),
                    ...chartEntries.map(
                          (entry) => _legendRow(
                        context,
                        entry,
                        totalExpense,
                        categoryIcon(entry.label),
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
          const SizedBox(height: 14),
          const Text(
            'Category Details',
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 10),
          if (sorted.isEmpty)
            const Card(
              child: Padding(
                padding: EdgeInsets.all(24),
                child: Center(
                  child: Text('No expense data yet.'),
                ),
              ),
            )
          else
            ...sorted.map(
                  (entry) => Card(
                margin: const EdgeInsets.only(bottom: 10),
                child: ListTile(
                  leading: CircleAvatar(
                    child: Icon(categoryIcon(entry.key)),
                  ),
                  title: Text(entry.key),
                  subtitle: totalExpense == 0
                      ? null
                      : Text(
                    '${(entry.value / totalExpense * 100).toStringAsFixed(1)}% of expenses',
                  ),
                  trailing: Text(
                    '₹${entry.value.toStringAsFixed(2)}',
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _statBox(
      BuildContext context,
      String title,
      double value,
      Color color,
      IconData icon,
      ) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(icon, color: color),
            const SizedBox(height: 8),
            Text(title),
            const SizedBox(height: 4),
            FittedBox(
              child: Text(
                '₹${value.toStringAsFixed(2)}',
                style: const TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _legendRow(
      BuildContext context,
      ChartEntry entry,
      double total,
      IconData icon,
      ) {
    final percentage = total == 0 ? 0 : entry.value / total;

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 5),
      child: Row(
        children: [
          CircleAvatar(
            radius: 15,
            backgroundColor: entry.color.withOpacity(.14),
            child: Icon(icon, size: 16, color: entry.color),
          ),
          const SizedBox(width: 10),
          Expanded(child: Text(entry.label)),
          Text('${(percentage * 100).toStringAsFixed(1)}%'),
          const SizedBox(width: 10),
          Text(
            '₹${entry.value.toStringAsFixed(0)}',
            style: const TextStyle(fontWeight: FontWeight.bold),
          ),
        ],
      ),
    );
  }
}

class ChartEntry {
  final String label;
  final double value;

  ChartEntry({
    required this.label,
    required this.value,
  });

  Color get color {
    const colors = [
      Colors.green,
      Colors.blue,
      Colors.orange,
      Colors.purple,
      Colors.red,
      Colors.teal,
      Colors.indigo,
      Colors.pink,
      Colors.brown,
      Colors.cyan,
    ];

    return colors[label.hashCode.abs() % colors.length];
  }
}

class ExpensePiePainter extends CustomPainter {
  final List<ChartEntry> entries;

  ExpensePiePainter(this.entries);

  @override
  void paint(Canvas canvas, Size size) {
    final total = entries.fold(0.0, (sum, e) => sum + e.value);
    if (total <= 0) return;

    final center = Offset(size.width / 2, size.height / 2);
    final radius = math.min(size.width, size.height) * .36;

    double startAngle = -math.pi / 2;

    for (final entry in entries) {
      final sweep = (entry.value / total) * math.pi * 2;
      final paint = Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 48
        ..strokeCap = StrokeCap.butt
        ..color = entry.color;

      canvas.drawArc(
        Rect.fromCircle(center: center, radius: radius),
        startAngle,
        sweep,
        false,
        paint,
      );

      startAngle += sweep;
    }
  }

  @override
  bool shouldRepaint(covariant ExpensePiePainter oldDelegate) {
    return oldDelegate.entries != entries;
  }
}
