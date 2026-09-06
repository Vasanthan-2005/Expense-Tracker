import 'dart:io';
import 'package:flutter/foundation.dart' hide Category;
import 'package:flutter/material.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:sqflite/sqflite.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

import '../../models/category.dart';
import '../../models/expense.dart';
import '../../models/account.dart';
import '../../models/income.dart';
import '../../models/transfer.dart';
import '../../models/app_settings.dart';

class DatabaseHelper {
  static final DatabaseHelper instance = DatabaseHelper._internal();
  static Database? _database;
  Future<Database>? _dbInitFuture;

  DatabaseHelper._internal();

  Future<void> closeDatabase() async {
    if (_database != null && _database!.isOpen) {
      await _database!.close();
      _database = null;
    }
    _dbInitFuture = null;
  }

  Future<Database> get database async {
    if (_database != null && _database!.isOpen) return _database!;
    _dbInitFuture ??= _initDatabase();
    _database = await _dbInitFuture;
    return _database!;
  }

  Future<Database> _initDatabase() async {
    // Initialize FFI for Desktop (Windows/Linux/macOS) and test environments
    if (!kIsWeb && (Platform.isWindows || Platform.isLinux || Platform.isMacOS)) {
      sqfliteFfiInit();
      databaseFactory = databaseFactoryFfi;
    }

    String dbPath;
    if (kIsWeb) {
      dbPath = 'expense_tracker.db';
    } else {
      try {
        final documentsDirectory = await getApplicationDocumentsDirectory();
        dbPath = p.join(documentsDirectory.path, 'expense_tracker.db');
      } catch (_) {
        dbPath = inMemoryDatabasePath;
      }
    }

    return await openDatabase(
      dbPath,
      version: 3,
      onCreate: _onCreate,
      onUpgrade: _onUpgrade,
      onConfigure: (db) async {
        await db.execute('PRAGMA foreign_keys = ON');
      },
    );
  }

  Future<void> _onCreate(Database db, int version) async {
    // 1. Create categories table
    await db.execute('''
      CREATE TABLE categories (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        name TEXT NOT NULL,
        icon_code INTEGER NOT NULL,
        icon_font_family TEXT,
        color_value INTEGER NOT NULL,
        is_default INTEGER NOT NULL DEFAULT 0,
        created_at INTEGER NOT NULL,
        monthly_budget INTEGER,
        sort_order INTEGER NOT NULL DEFAULT 0
      )
    ''');

    // 2. Create accounts table
    await db.execute('''
      CREATE TABLE accounts (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        name TEXT NOT NULL,
        opening_balance INTEGER NOT NULL DEFAULT 0,
        icon_code INTEGER NOT NULL,
        icon_font_family TEXT,
        color_value INTEGER NOT NULL,
        is_default INTEGER NOT NULL DEFAULT 0,
        created_at INTEGER NOT NULL,
        updated_at INTEGER NOT NULL
      )
    ''');

    // 3. Create expenses table
    await db.execute('''
      CREATE TABLE expenses (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        amount INTEGER NOT NULL,
        category_id INTEGER NOT NULL,
        account_id INTEGER,
        note TEXT,
        date TEXT NOT NULL,
        time TEXT NOT NULL,
        created_at INTEGER NOT NULL,
        updated_at INTEGER NOT NULL,
        FOREIGN KEY (category_id) REFERENCES categories (id) ON DELETE RESTRICT,
        FOREIGN KEY (account_id) REFERENCES accounts (id) ON DELETE RESTRICT
      )
    ''');

    // 4. Create incomes table
    await db.execute('''
      CREATE TABLE incomes (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        amount INTEGER NOT NULL,
        account_id INTEGER NOT NULL,
        source_or_note TEXT,
        date TEXT NOT NULL,
        time TEXT NOT NULL,
        created_at INTEGER NOT NULL,
        updated_at INTEGER NOT NULL,
        FOREIGN KEY (account_id) REFERENCES accounts (id) ON DELETE RESTRICT
      )
    ''');

    // 5. Create transfers table
    await db.execute('''
      CREATE TABLE transfers (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        amount INTEGER NOT NULL,
        from_account_id INTEGER NOT NULL,
        to_account_id INTEGER NOT NULL,
        note TEXT,
        date TEXT NOT NULL,
        time TEXT NOT NULL,
        created_at INTEGER NOT NULL,
        updated_at INTEGER NOT NULL,
        FOREIGN KEY (from_account_id) REFERENCES accounts (id) ON DELETE RESTRICT,
        FOREIGN KEY (to_account_id) REFERENCES accounts (id) ON DELETE RESTRICT
      )
    ''');

    // 6. Create settings table
    await db.execute('''
      CREATE TABLE settings (
        key TEXT PRIMARY KEY,
        value TEXT NOT NULL
      )
    ''');

    // Indexes for high performance queries
    await db.execute('CREATE INDEX idx_expenses_date ON expenses(date)');
    await db.execute('CREATE INDEX idx_expenses_category ON expenses(category_id)');
    await db.execute('CREATE INDEX idx_expenses_account ON expenses(account_id)');
    await db.execute('CREATE INDEX idx_expenses_created_at ON expenses(created_at)');
    await db.execute('CREATE INDEX idx_incomes_account ON incomes(account_id)');
    await db.execute('CREATE INDEX idx_transfers_from_account ON transfers(from_account_id)');
    await db.execute('CREATE INDEX idx_transfers_to_account ON transfers(to_account_id)');

    // Seed default categories
    final batch = db.batch();
    for (final cat in Category.defaultCategories) {
      batch.insert('categories', cat.toMap());
    }

    // Seed default accounts
    for (final acc in Account.defaultAccounts) {
      batch.insert('accounts', acc.toMap());
    }

    // Seed default settings
    final defaultSettings = AppSettings();
    defaultSettings.toMap().forEach((key, value) {
      batch.insert('settings', {'key': key, 'value': value});
    });

    await batch.commit(noResult: true);
  }

  Future<void> _onUpgrade(Database db, int oldVersion, int newVersion) async {
    if (oldVersion < 2) {
      // 1. Create accounts table
      await db.execute('''
        CREATE TABLE IF NOT EXISTS accounts (
          id INTEGER PRIMARY KEY AUTOINCREMENT,
          name TEXT NOT NULL,
          opening_balance INTEGER NOT NULL DEFAULT 0,
          icon_code INTEGER NOT NULL,
          icon_font_family TEXT,
          color_value INTEGER NOT NULL,
          is_default INTEGER NOT NULL DEFAULT 0,
          created_at INTEGER NOT NULL,
          updated_at INTEGER NOT NULL
        )
      ''');

      // Seed default accounts if empty
      final existingAccounts = await db.query('accounts');
      if (existingAccounts.isEmpty) {
        final batch = db.batch();
        for (final acc in Account.defaultAccounts) {
          batch.insert('accounts', acc.toMap());
        }
        await batch.commit(noResult: true);
      }

      // 2. Add account_id to expenses table if missing
      try {
        await db.execute('ALTER TABLE expenses ADD COLUMN account_id INTEGER REFERENCES accounts(id)');
      } catch (_) {}

      // Get default expense account id (the one with is_default = 1, or 2, or 1)
      int defaultAccId = 1;
      final defRes = await db.query('accounts', where: 'is_default = 1', limit: 1);
      if (defRes.isNotEmpty) {
        defaultAccId = defRes.first['id'] as int;
      } else {
        final anyRes = await db.query('accounts', limit: 1);
        if (anyRes.isNotEmpty) {
          defaultAccId = anyRes.first['id'] as int;
        }
      }

      await db.update('expenses', {'account_id': defaultAccId}, where: 'account_id IS NULL');

      // 3. Create incomes table
      await db.execute('''
        CREATE TABLE IF NOT EXISTS incomes (
          id INTEGER PRIMARY KEY AUTOINCREMENT,
          amount INTEGER NOT NULL,
          account_id INTEGER NOT NULL,
          source_or_note TEXT,
          date TEXT NOT NULL,
          time TEXT NOT NULL,
          created_at INTEGER NOT NULL,
          updated_at INTEGER NOT NULL,
          FOREIGN KEY (account_id) REFERENCES accounts (id) ON DELETE RESTRICT
        )
      ''');

      // 4. Create transfers table
      await db.execute('''
        CREATE TABLE IF NOT EXISTS transfers (
          id INTEGER PRIMARY KEY AUTOINCREMENT,
          amount INTEGER NOT NULL,
          from_account_id INTEGER NOT NULL,
          to_account_id INTEGER NOT NULL,
          note TEXT,
          date TEXT NOT NULL,
          time TEXT NOT NULL,
          created_at INTEGER NOT NULL,
          updated_at INTEGER NOT NULL,
          FOREIGN KEY (from_account_id) REFERENCES accounts (id) ON DELETE RESTRICT,
          FOREIGN KEY (to_account_id) REFERENCES accounts (id) ON DELETE RESTRICT
        )
      ''');

      // Indexes
      try {
        await db.execute('CREATE INDEX IF NOT EXISTS idx_expenses_account ON expenses(account_id)');
        await db.execute('CREATE INDEX IF NOT EXISTS idx_incomes_account ON incomes(account_id)');
        await db.execute('CREATE INDEX IF NOT EXISTS idx_transfers_from_account ON transfers(from_account_id)');
        await db.execute('CREATE INDEX IF NOT EXISTS idx_transfers_to_account ON transfers(to_account_id)');
      } catch (_) {}
    }

    if (oldVersion < 3) {
      try {
        await db.execute('ALTER TABLE categories ADD COLUMN monthly_budget INTEGER');
      } catch (_) {}
      try {
        await db.execute('ALTER TABLE categories ADD COLUMN sort_order INTEGER NOT NULL DEFAULT 0');
        final cats = await db.query('categories', orderBy: 'is_default DESC, name ASC');
        for (int i = 0; i < cats.length; i++) {
          final id = cats[i]['id'] as int;
          await db.update('categories', {'sort_order': i}, where: 'id = ?', whereArgs: [id]);
        }
      } catch (_) {}
    }

    try {
      await db.update('accounts', {'name': 'Expense Account'}, where: 'name = ? OR LOWER(name) = ?', whereArgs: ['UPI / Bank', 'upi / bank']);
    } catch (_) {}
  }

  // --- ACCOUNTS CRUD & BALANCE CALCULATIONS ---

  Future<List<Account>> getAccounts() async {
    final db = await database;
    var maps = await db.query('accounts', orderBy: 'is_default DESC, id ASC');
    if (maps.isEmpty) {
      final batch = db.batch();
      for (final acc in Account.defaultAccounts) {
        batch.insert('accounts', acc.toMap());
      }
      await batch.commit(noResult: true);
      maps = await db.query('accounts', orderBy: 'is_default DESC, id ASC');
    } else {
      final hasCash = maps.any((m) => (m['name'] as String).toLowerCase().contains('cash'));
      if (!hasCash) {
        final now = DateTime.now();
        final cashAcc = Account(
          name: 'Cash',
          openingBalanceMinorUnits: 0,
          iconCodePoint: Icons.payments.codePoint,
          colorValue: 0xFF10B981,
          isDefault: false,
          createdAt: now,
          updatedAt: now,
        );
        await db.insert('accounts', cashAcc.toMap());
        maps = await db.query('accounts', orderBy: 'is_default DESC, id ASC');
      }
    }
    return maps.map((m) => Account.fromMap(m)).toList();
  }

  Future<Account?> getDefaultAccount() async {
    final db = await database;
    final maps = await db.query('accounts', where: 'is_default = 1', limit: 1);
    if (maps.isNotEmpty) {
      return Account.fromMap(maps.first);
    }
    final all = await db.query('accounts', orderBy: 'id ASC', limit: 1);
    if (all.isNotEmpty) {
      return Account.fromMap(all.first);
    }
    return null;
  }

  Future<int> insertAccount(Account account) async {
    final db = await database;
    if (account.isDefault) {
      await db.update('accounts', {'is_default': 0});
    }
    return await db.insert('accounts', account.toMap());
  }

  Future<int> updateAccount(Account account) async {
    final db = await database;
    if (account.id == null) return 0;
    if (account.isDefault) {
      await db.update('accounts', {'is_default': 0}, where: 'id != ?', whereArgs: [account.id]);
    }
    return await db.update(
      'accounts',
      account.toMap(),
      where: 'id = ?',
      whereArgs: [account.id],
    );
  }

  Future<void> setDefaultAccount(int accountId) async {
    final db = await database;
    await db.transaction((txn) async {
      await txn.update('accounts', {'is_default': 0});
      await txn.update('accounts', {'is_default': 1}, where: 'id = ?', whereArgs: [accountId]);
    });
  }

  Future<void> deleteAccount(int accountId) async {
    final db = await database;
    await db.transaction((txn) async {
      final countRes = await txn.rawQuery('SELECT COUNT(*) as cnt FROM accounts');
      final count = Sqflite.firstIntValue(countRes) ?? 0;
      if (count <= 1) {
        throw Exception('Cannot delete the last remaining account');
      }

      // Check if fallback account exists
      final fallbackRes = await txn.query('accounts', where: 'id != ?', whereArgs: [accountId], limit: 1);
      final fallbackId = fallbackRes.first['id'] as int;

      // Reassign expenses to fallback
      await txn.update('expenses', {'account_id': fallbackId}, where: 'account_id = ?', whereArgs: [accountId]);
      // Reassign incomes to fallback
      await txn.update('incomes', {'account_id': fallbackId}, where: 'account_id = ?', whereArgs: [accountId]);
      // Delete transfers involving this account
      await txn.delete('transfers', where: 'from_account_id = ? OR to_account_id = ?', whereArgs: [accountId, accountId]);

      // If deleted account was default, set fallback as default
      final accRes = await txn.query('accounts', where: 'id = ?', whereArgs: [accountId], limit: 1);
      if (accRes.isNotEmpty && (accRes.first['is_default'] == 1)) {
        await txn.update('accounts', {'is_default': 1}, where: 'id = ?', whereArgs: [fallbackId]);
      }

      await txn.delete('accounts', where: 'id = ?', whereArgs: [accountId]);
    });
  }

  /// Calculates the live dynamic balance for every account:
  /// Current Balance = opening_balance + sum(incomes) - sum(expenses) + sum(transfers_in) - sum(transfers_out)
  Future<Map<int, int>> getAccountCalculatedBalances() async {
    final db = await database;
    final res = await db.rawQuery('''
      SELECT 
        a.id,
        a.opening_balance 
        + COALESCE((SELECT SUM(amount) FROM incomes WHERE account_id = a.id), 0)
        - COALESCE((SELECT SUM(amount) FROM expenses WHERE account_id = a.id), 0)
        + COALESCE((SELECT SUM(amount) FROM transfers WHERE to_account_id = a.id), 0)
        - COALESCE((SELECT SUM(amount) FROM transfers WHERE from_account_id = a.id), 0) AS calculated_balance
      FROM accounts a
    ''');

    final Map<int, int> balanceMap = {};
    for (final row in res) {
      final id = row['id'] as int;
      final bal = (row['calculated_balance'] as int?) ?? 0;
      balanceMap[id] = bal;
    }
    return balanceMap;
  }

  /// Calculates the historical closing balance for every account as of the end of a specific month.
  /// Balance = opening_balance + sum(incomes <= endOfMonth) - sum(expenses <= endOfMonth) + sum(transfers_in <= endOfMonth) - sum(transfers_out <= endOfMonth)
  Future<Map<int, int>> getAccountClosingBalancesForMonth(int year, int month) async {
    final db = await database;
    final yearStr = year.toString().padLeft(4, '0');
    final monthStr = month.toString().padLeft(2, '0');
    final lastDay = DateTime(year, month + 1, 0).day.toString().padLeft(2, '0');
    final endIso = '$yearStr-$monthStr-$lastDay';

    final res = await db.rawQuery('''
      SELECT 
        a.id,
        a.opening_balance 
        + COALESCE((SELECT SUM(amount) FROM incomes WHERE account_id = a.id AND date <= ?), 0)
        - COALESCE((SELECT SUM(amount) FROM expenses WHERE account_id = a.id AND date <= ?), 0)
        + COALESCE((SELECT SUM(amount) FROM transfers WHERE to_account_id = a.id AND date <= ?), 0)
        - COALESCE((SELECT SUM(amount) FROM transfers WHERE from_account_id = a.id AND date <= ?), 0) AS calculated_balance
      FROM accounts a
    ''', [endIso, endIso, endIso, endIso]);

    final Map<int, int> balanceMap = {};
    for (final row in res) {
      final id = row['id'] as int;
      final bal = (row['calculated_balance'] as int?) ?? 0;
      balanceMap[id] = bal;
    }
    return balanceMap;
  }

  // --- EXPENSE CRUD ---

  Future<int> insertExpense(Expense expense) async {
    final db = await database;
    var targetAccountId = expense.accountId;

    if (targetAccountId == null) {
      final defaultAcc = await getDefaultAccount();
      targetAccountId = defaultAcc?.id ?? 1;
    }

    final expenseToInsert = expense.copyWith(accountId: targetAccountId);
    return await db.insert('expenses', expenseToInsert.toMap());
  }

  Future<int> updateExpense(Expense expense) async {
    final db = await database;
    if (expense.id == null) return 0;
    var targetAccountId = expense.accountId;
    if (targetAccountId == null) {
      final defaultAcc = await getDefaultAccount();
      targetAccountId = defaultAcc?.id ?? 1;
    }
    final expenseToUpdate = expense.copyWith(accountId: targetAccountId);

    return await db.update(
      'expenses',
      expenseToUpdate.toMap(),
      where: 'id = ?',
      whereArgs: [expense.id],
    );
  }

  Future<int> deleteExpense(int id) async {
    final db = await database;
    return await db.delete(
      'expenses',
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  Future<List<Expense>> getExpenses({
    String? searchQuery,
    List<int>? categoryIds,
    int? accountId,
    DateTime? startDate,
    DateTime? endDate,
    int? limit,
    int? offset,
    bool oldestFirst = false,
  }) async {
    final db = await database;

    final whereClauses = <String>[];
    final whereArgs = <dynamic>[];

    if (searchQuery != null && searchQuery.trim().isNotEmpty) {
      whereClauses.add('(note LIKE ? OR category_id IN (SELECT id FROM categories WHERE name LIKE ?))');
      final queryParam = '%${searchQuery.trim()}%';
      whereArgs.add(queryParam);
      whereArgs.add(queryParam);
    }

    if (categoryIds != null && categoryIds.isNotEmpty) {
      final placeholders = List.filled(categoryIds.length, '?').join(',');
      whereClauses.add('category_id IN ($placeholders)');
      whereArgs.addAll(categoryIds);
    }

    if (accountId != null) {
      whereClauses.add('account_id = ?');
      whereArgs.add(accountId);
    }

    if (startDate != null) {
      final startIso = "${startDate.year.toString().padLeft(4, '0')}-${startDate.month.toString().padLeft(2, '0')}-${startDate.day.toString().padLeft(2, '0')}";
      whereClauses.add('date >= ?');
      whereArgs.add(startIso);
    }

    if (endDate != null) {
      final endIso = "${endDate.year.toString().padLeft(4, '0')}-${endDate.month.toString().padLeft(2, '0')}-${endDate.day.toString().padLeft(2, '0')}";
      whereClauses.add('date <= ?');
      whereArgs.add(endIso);
    }

    final whereString = whereClauses.isNotEmpty ? whereClauses.join(' AND ') : null;
    final orderBy = oldestFirst ? 'date ASC, time ASC, id ASC' : 'date DESC, time DESC, id DESC';

    final maps = await db.query(
      'expenses',
      where: whereString,
      whereArgs: whereArgs.isNotEmpty ? whereArgs : null,
      orderBy: orderBy,
      limit: limit,
      offset: offset,
    );

    return maps.map((m) => Expense.fromMap(m)).toList();
  }

  Future<int> getExpenseCount({
    String? searchQuery,
    List<int>? categoryIds,
    DateTime? startDate,
    DateTime? endDate,
  }) async {
    final db = await database;

    final whereClauses = <String>[];
    final whereArgs = <dynamic>[];

    if (searchQuery != null && searchQuery.trim().isNotEmpty) {
      whereClauses.add('(note LIKE ? OR category_id IN (SELECT id FROM categories WHERE name LIKE ?))');
      final queryParam = '%${searchQuery.trim()}%';
      whereArgs.add(queryParam);
      whereArgs.add(queryParam);
    }

    if (categoryIds != null && categoryIds.isNotEmpty) {
      final placeholders = List.filled(categoryIds.length, '?').join(',');
      whereClauses.add('category_id IN ($placeholders)');
      whereArgs.addAll(categoryIds);
    }

    if (startDate != null) {
      final startIso = "${startDate.year.toString().padLeft(4, '0')}-${startDate.month.toString().padLeft(2, '0')}-${startDate.day.toString().padLeft(2, '0')}";
      whereClauses.add('date >= ?');
      whereArgs.add(startIso);
    }

    if (endDate != null) {
      final endIso = "${endDate.year.toString().padLeft(4, '0')}-${endDate.month.toString().padLeft(2, '0')}-${endDate.day.toString().padLeft(2, '0')}";
      whereClauses.add('date <= ?');
      whereArgs.add(endIso);
    }

    final whereString = whereClauses.isNotEmpty ? whereClauses.join(' AND ') : null;

    final result = await db.rawQuery(
      'SELECT COUNT(*) as count FROM expenses ${whereString != null ? "WHERE $whereString" : ""}',
      whereArgs.isNotEmpty ? whereArgs : null,
    );

    return Sqflite.firstIntValue(result) ?? 0;
  }

  // --- INCOMES CRUD ---

  Future<int> insertIncome(Income income) async {
    final db = await database;
    return await db.insert('incomes', income.toMap());
  }

  Future<int> updateIncome(Income income) async {
    final db = await database;
    if (income.id == null) return 0;
    return await db.update(
      'incomes',
      income.toMap(),
      where: 'id = ?',
      whereArgs: [income.id],
    );
  }

  Future<int> deleteIncome(int id) async {
    final db = await database;
    return await db.delete(
      'incomes',
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  Future<List<Income>> getIncomes({int? accountId, int? limit}) async {
    final db = await database;
    final maps = await db.query(
      'incomes',
      where: accountId != null ? 'account_id = ?' : null,
      whereArgs: accountId != null ? [accountId] : null,
      orderBy: 'date DESC, time DESC, id DESC',
      limit: limit,
    );
    return maps.map((m) => Income.fromMap(m)).toList();
  }

  Future<List<Income>> getIncomesFiltered({
    int? accountId,
    DateTime? startDate,
    DateTime? endDate,
    String? searchQuery,
    int? limit,
    int? offset,
    bool oldestFirst = false,
  }) async {
    final db = await database;

    final whereClauses = <String>[];
    final whereArgs = <dynamic>[];

    if (accountId != null) {
      whereClauses.add('account_id = ?');
      whereArgs.add(accountId);
    }

    if (searchQuery != null && searchQuery.trim().isNotEmpty) {
      whereClauses.add('(source_or_note LIKE ?)');
      whereArgs.add('%${searchQuery.trim()}%');
    }

    if (startDate != null) {
      final startIso = "${startDate.year.toString().padLeft(4, '0')}-${startDate.month.toString().padLeft(2, '0')}-${startDate.day.toString().padLeft(2, '0')}";
      whereClauses.add('date >= ?');
      whereArgs.add(startIso);
    }

    if (endDate != null) {
      final endIso = "${endDate.year.toString().padLeft(4, '0')}-${endDate.month.toString().padLeft(2, '0')}-${endDate.day.toString().padLeft(2, '0')}";
      whereClauses.add('date <= ?');
      whereArgs.add(endIso);
    }

    final whereString = whereClauses.isNotEmpty ? whereClauses.join(' AND ') : null;
    final orderBy = oldestFirst ? 'date ASC, time ASC, id ASC' : 'date DESC, time DESC, id DESC';

    final maps = await db.query(
      'incomes',
      where: whereString,
      whereArgs: whereArgs.isNotEmpty ? whereArgs : null,
      orderBy: orderBy,
      limit: limit,
      offset: offset,
    );

    return maps.map((m) => Income.fromMap(m)).toList();
  }

  Future<int> getTotalIncomePaiseForMonth(int year, int month, {int? accountId}) async {
    final db = await database;
    final yearStr = year.toString().padLeft(4, '0');
    final monthStr = month.toString().padLeft(2, '0');
    final lastDay = DateTime(year, month + 1, 0).day.toString().padLeft(2, '0');
    final startIso = '$yearStr-$monthStr-01';
    final endIso = '$yearStr-$monthStr-$lastDay';

    final whereClauses = ['date >= ?', 'date <= ?'];
    final whereArgs = <dynamic>[startIso, endIso];

    if (accountId != null) {
      whereClauses.add('account_id = ?');
      whereArgs.add(accountId);
    }

    final res = await db.rawQuery('''
      SELECT SUM(amount) as total 
      FROM incomes 
      WHERE ${whereClauses.join(' AND ')}
    ''', whereArgs);

    return (res.first['total'] as int?) ?? 0;
  }

  Future<Map<int, int>> getAccountIncomeBreakdownForMonth(int year, int month) async {
    final db = await database;
    final yearStr = year.toString().padLeft(4, '0');
    final monthStr = month.toString().padLeft(2, '0');
    final lastDay = DateTime(year, month + 1, 0).day.toString().padLeft(2, '0');
    final startIso = '$yearStr-$monthStr-01';
    final endIso = '$yearStr-$monthStr-$lastDay';

    final res = await db.rawQuery('''
      SELECT account_id, SUM(amount) as total 
      FROM incomes 
      WHERE date >= ? AND date <= ?
      GROUP BY account_id
    ''', [startIso, endIso]);

    final Map<int, int> result = {};
    for (final row in res) {
      final accId = row['account_id'] as int;
      final tot = (row['total'] as int?) ?? 0;
      result[accId] = tot;
    }
    return result;
  }

  Future<Map<String, dynamic>> getMonthBudgetPerformance({
    required int year,
    required int month,
    int? overallBudgetPaise,
  }) async {
    final db = await database;
    final yearStr = year.toString().padLeft(4, '0');
    final monthStr = month.toString().padLeft(2, '0');
    final lastDay = DateTime(year, month + 1, 0).day.toString().padLeft(2, '0');
    final startIso = '$yearStr-$monthStr-01';
    final endIso = '$yearStr-$monthStr-$lastDay';

    // 1. Total spent in month & count of expenses
    final totalSpentRes = await db.rawQuery(
      'SELECT SUM(amount) as total, COUNT(*) as count FROM expenses WHERE date >= ? AND date <= ?',
      [startIso, endIso],
    );
    final totalSpentPaise = (totalSpentRes.first['total'] as int?) ?? 0;
    final expenseCount = (totalSpentRes.first['count'] as int?) ?? 0;
    final bool hasData = expenseCount > 0 && totalSpentPaise > 0;

    // 2. Categories with budget
    final catMaps = await db.query('categories', orderBy: 'sort_order ASC, id ASC');
    final categories = catMaps.map((m) => Category.fromMap(m)).toList();
    final spentMap = await getAllCategorySpentPaiseForMonth(year, month);

    final List<Map<String, dynamic>> categoryBreakdown = [];
    int budgetedCategoriesCount = 0;
    int categoriesWithinBudgetCount = 0;
    bool allCategoriesWithinBudget = true;

    for (final cat in categories) {
      final spent = spentMap[cat.id] ?? 0;
      final hasBudget = cat.isBudgetSet;
      final budget = cat.monthlyBudgetPaise;
      final isWithin = !hasBudget || (spent <= budget!);

      if (hasBudget) {
        budgetedCategoriesCount++;
        if (isWithin) {
          categoriesWithinBudgetCount++;
        } else {
          allCategoriesWithinBudget = false;
        }
      }

      categoryBreakdown.add({
        'category': cat,
        'spentPaise': spent,
        'budgetPaise': budget,
        'isBudgetSet': hasBudget,
        'isWithinBudget': isWithin,
        'savedPaise': (hasData && hasBudget && budget != null) ? (budget - spent) : null,
      });
    }

    final bool isOverallBudgetSet = overallBudgetPaise != null && overallBudgetPaise > 0;
    final bool isOverallWithinBudget = !isOverallBudgetSet || (totalSpentPaise <= overallBudgetPaise);
    final int overallSavedPaise = (hasData && isOverallBudgetSet) ? (overallBudgetPaise - totalSpentPaise) : 0;

    final bool hasAnyBudget = isOverallBudgetSet || budgetedCategoriesCount > 0;
    // Celebration qualification strictly requires proper data in the month (hasData = true)
    final bool isCelebrationQualified = hasData && hasAnyBudget && isOverallWithinBudget && allCategoriesWithinBudget;
    final int exceededCategoriesCount = budgetedCategoriesCount - categoriesWithinBudgetCount;

    return {
      'year': year,
      'month': month,
      'hasData': hasData,
      'expenseCount': expenseCount,
      'totalSpentPaise': totalSpentPaise,
      'overallBudgetPaise': overallBudgetPaise,
      'isOverallBudgetSet': isOverallBudgetSet,
      'isOverallWithinBudget': isOverallWithinBudget,
      'overallSavedPaise': overallSavedPaise,
      'budgetedCategoriesCount': budgetedCategoriesCount,
      'categoriesWithinBudgetCount': categoriesWithinBudgetCount,
      'exceededCategoriesCount': exceededCategoriesCount,
      'allCategoriesWithinBudget': allCategoriesWithinBudget,
      'isCelebrationQualified': isCelebrationQualified,
      'categoryBreakdown': categoryBreakdown,
    };
  }

  Future<List<Map<String, dynamic>>> getAllDistinctYearMonths() async {
    final db = await database;
    final Set<String> distinctKeys = {};
    final List<Map<String, dynamic>> result = [];

    const months = [
      'January', 'February', 'March', 'April', 'May', 'June',
      'July', 'August', 'September', 'October', 'November', 'December'
    ];

    final expRows = await db.query('expenses', columns: ['date'], where: 'date IS NOT NULL');
    final incRows = await db.query('incomes', columns: ['date'], where: 'date IS NOT NULL');

    final allRows = [...expRows, ...incRows];
    for (final row in allRows) {
      final dateStr = row['date'] as String?;
      if (dateStr != null && dateStr.isNotEmpty) {
        final parsed = DateTime.tryParse(dateStr);
        if (parsed != null) {
          final key = '${parsed.year.toString().padLeft(4, '0')}-${parsed.month.toString().padLeft(2, '0')}';
          if (!distinctKeys.contains(key)) {
            distinctKeys.add(key);
            result.add({
              'year': parsed.year,
              'month': parsed.month,
              'key': key,
              'label': '${months[parsed.month - 1]} ${parsed.year}',
            });
          }
        }
      }
    }

    result.sort((a, b) => (b['key'] as String).compareTo(a['key'] as String));
    return result;
  }

  Future<List<Map<String, dynamic>>> getAllMonthsBudgetPerformance({int? overallBudgetPaise}) async {
    final availableMonths = await getAllDistinctYearMonths();
    final List<Map<String, dynamic>> results = [];

    for (final m in availableMonths) {
      final year = m['year'] as int;
      final month = m['month'] as int;
      final perf = await getMonthBudgetPerformance(
        year: year,
        month: month,
        overallBudgetPaise: overallBudgetPaise,
      );
      if (perf['hasData'] == true && (perf['totalSpentPaise'] as int? ?? 0) > 0) {
        results.add(perf);
      }
    }
    return results;
  }

  Future<Map<String, dynamic>> getCelebrationSummaryStats({int? overallBudgetPaise}) async {
    final allHistory = await getAllMonthsBudgetPerformance(overallBudgetPaise: overallBudgetPaise);
    
    int totalSavedAllTimePaise = 0;
    int totalWinningMonths = 0;
    int currentStreak = 0;
    int bestStreak = 0;
    int runningStreak = 0;
    bool streakBroken = false;

    for (int i = 0; i < allHistory.length; i++) {
      final perf = allHistory[i];
      final isWon = perf['isCelebrationQualified'] == true;
      final saved = perf['overallSavedPaise'] as int? ?? 0;
      if (saved > 0) {
        totalSavedAllTimePaise += saved;
      }
      if (isWon) {
        totalWinningMonths++;
        if (!streakBroken) {
          currentStreak++;
        }
      } else {
        streakBroken = true;
      }
    }

    for (int i = allHistory.length - 1; i >= 0; i--) {
      final isWon = allHistory[i]['isCelebrationQualified'] == true;
      if (isWon) {
        runningStreak++;
        if (runningStreak > bestStreak) {
          bestStreak = runningStreak;
        }
      } else {
        runningStreak = 0;
      }
    }

    return {
      'totalSavedAllTimePaise': totalSavedAllTimePaise,
      'totalWinningMonths': totalWinningMonths,
      'totalReviewedMonths': allHistory.length,
      'currentStreak': currentStreak,
      'bestStreak': bestStreak,
      'allHistory': allHistory,
    };
  }

  // --- TRANSFERS CRUD ---

  Future<int> insertTransfer(Transfer transfer) async {
    final db = await database;
    return await db.insert('transfers', transfer.toMap());
  }

  Future<int> updateTransfer(Transfer transfer) async {
    final db = await database;
    if (transfer.id == null) return 0;
    return await db.update(
      'transfers',
      transfer.toMap(),
      where: 'id = ?',
      whereArgs: [transfer.id],
    );
  }

  Future<int> deleteTransfer(int id) async {
    final db = await database;
    return await db.delete(
      'transfers',
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  Future<List<Transfer>> getTransfers({int? accountId, int? limit}) async {
    final db = await database;
    final String? where = accountId != null ? 'from_account_id = ? OR to_account_id = ?' : null;
    final List<dynamic>? whereArgs = accountId != null ? [accountId, accountId] : null;

    final maps = await db.query(
      'transfers',
      where: where,
      whereArgs: whereArgs,
      orderBy: 'date DESC, time DESC, id DESC',
      limit: limit,
    );
    return maps.map((m) => Transfer.fromMap(m)).toList();
  }

  // --- CATEGORIES CRUD ---

  Future<List<Category>> getCategories() async {
    final db = await database;
    final maps = await db.query('categories', orderBy: 'sort_order ASC, id ASC');
    return maps.map((m) => Category.fromMap(m)).toList();
  }

  Future<int> insertCategory(Category category) async {
    final db = await database;
    final maxRes = await db.rawQuery('SELECT MAX(sort_order) as max_order FROM categories');
    int nextSortOrder = 0;
    if (maxRes.isNotEmpty && maxRes.first['max_order'] != null) {
      nextSortOrder = (maxRes.first['max_order'] as int) + 1;
    }
    final categoryToInsert = category.copyWith(sortOrder: nextSortOrder);
    return await db.insert('categories', categoryToInsert.toMap());
  }

  Future<void> updateCategoryOrder(List<Category> categories) async {
    final db = await database;
    await db.transaction((txn) async {
      for (int i = 0; i < categories.length; i++) {
        final cat = categories[i];
        if (cat.id != null) {
          await txn.update(
            'categories',
            {'sort_order': i},
            where: 'id = ?',
            whereArgs: [cat.id],
          );
        }
      }
    });
  }

  Future<void> updateCategoryBudget(int categoryId, int? monthlyBudgetPaise) async {
    final db = await database;
    await db.update(
      'categories',
      {'monthly_budget': monthlyBudgetPaise},
      where: 'id = ?',
      whereArgs: [categoryId],
    );
  }

  Future<int> getCategorySpentPaiseForMonth(int categoryId, int year, int month) async {
    final db = await database;
    final yearStr = year.toString().padLeft(4, '0');
    final monthStr = month.toString().padLeft(2, '0');
    final lastDay = DateTime(year, month + 1, 0).day.toString().padLeft(2, '0');
    final startIso = '$yearStr-$monthStr-01';
    final endIso = '$yearStr-$monthStr-$lastDay';

    final res = await db.rawQuery('''
      SELECT SUM(amount) as total 
      FROM expenses 
      WHERE category_id = ? AND date >= ? AND date <= ?
    ''', [categoryId, startIso, endIso]);

    return (res.first['total'] as int?) ?? 0;
  }

  Future<Map<int, int>> getAllCategorySpentPaiseForMonth(int year, int month) async {
    final db = await database;
    final yearStr = year.toString().padLeft(4, '0');
    final monthStr = month.toString().padLeft(2, '0');
    final lastDay = DateTime(year, month + 1, 0).day.toString().padLeft(2, '0');
    final startIso = '$yearStr-$monthStr-01';
    final endIso = '$yearStr-$monthStr-$lastDay';

    final res = await db.rawQuery('''
      SELECT category_id, SUM(amount) as total 
      FROM expenses 
      WHERE date >= ? AND date <= ?
      GROUP BY category_id
    ''', [startIso, endIso]);

    final Map<int, int> result = {};
    for (final row in res) {
      final catId = row['category_id'] as int;
      final tot = (row['total'] as int?) ?? 0;
      result[catId] = tot;
    }
    return result;
  }

  Future<int> updateCategory(Category category) async {
    final db = await database;
    if (category.id == null) return 0;
    return await db.update(
      'categories',
      category.toMap(),
      where: 'id = ?',
      whereArgs: [category.id],
    );
  }

  Future<void> deleteCategory(int categoryId, {int? fallbackCategoryId}) async {
    final db = await database;
    await db.transaction((txn) async {
      // Find fallback category (e.g. 'Other' or remaining category) if not provided
      int targetFallbackId;
      if (fallbackCategoryId != null && fallbackCategoryId != categoryId) {
        targetFallbackId = fallbackCategoryId;
      } else {
        final otherRes = await txn.query('categories', where: 'name = ? AND id != ?', whereArgs: ['Other', categoryId], limit: 1);
        if (otherRes.isNotEmpty) {
          targetFallbackId = otherRes.first['id'] as int;
        } else {
          // If no 'Other', pick any remaining category
          final anyRes = await txn.query('categories', where: 'id != ?', whereArgs: [categoryId], limit: 1);
          if (anyRes.isEmpty) {
            throw Exception('Cannot delete the last remaining category');
          }
          targetFallbackId = anyRes.first['id'] as int;
        }
      }

      // Reassign expenses using deleted category to fallback
      await txn.update(
        'expenses',
        {'category_id': targetFallbackId},
        where: 'category_id = ?',
        whereArgs: [categoryId],
      );

      // Delete the category
      await txn.delete(
        'categories',
        where: 'id = ?',
        whereArgs: [categoryId],
      );
    });
  }

  Future<void> syncDefaultCategories() async {
    final db = await database;

    // Purge unwanted old categories ('Bills', 'Food', 'Transport')
    final unwanted = ['bills', 'food', 'transport'];
    for (final name in unwanted) {
      final res = await db.query('categories', where: 'LOWER(name) = ?', whereArgs: [name]);
      if (res.isNotEmpty) {
        final catId = res.first['id'] as int;
        final expCount = Sqflite.firstIntValue(
          await db.rawQuery('SELECT COUNT(*) FROM expenses WHERE category_id = ?', [catId]),
        ) ?? 0;

        if (expCount == 0) {
          await db.delete('categories', where: 'id = ?', whereArgs: [catId]);
        } else {
          final fallbackCat = await db.query('categories', where: 'LOWER(name) = ?', whereArgs: ['misc']);
          if (fallbackCat.isNotEmpty) {
            final fallbackId = fallbackCat.first['id'] as int;
            await db.update('expenses', {'category_id': fallbackId}, where: 'category_id = ?', whereArgs: [catId]);
            await db.delete('categories', where: 'id = ?', whereArgs: [catId]);
          }
        }
      }
    }

    // Purge unwanted old default accounts ('Savings')
    final savingsRes = await db.query('accounts', where: 'LOWER(name) = ?', whereArgs: ['savings']);
    if (savingsRes.isNotEmpty) {
      final accId = savingsRes.first['id'] as int;
      final expCount = Sqflite.firstIntValue(await db.rawQuery('SELECT COUNT(*) FROM expenses WHERE account_id = ?', [accId])) ?? 0;
      final incCount = Sqflite.firstIntValue(await db.rawQuery('SELECT COUNT(*) FROM incomes WHERE account_id = ?', [accId])) ?? 0;
      final trCount = Sqflite.firstIntValue(await db.rawQuery('SELECT COUNT(*) FROM transfers WHERE from_account_id = ? OR to_account_id = ?', [accId, accId])) ?? 0;

      if (expCount == 0 && incCount == 0 && trCount == 0) {
        await db.delete('accounts', where: 'id = ?', whereArgs: [accId]);
      }
    }
  }

  Future<void> cleanupCorruptedImportData() async {
    final db = await database;
    await syncDefaultCategories();
    // Remove expenses/incomes with absurd corrupted amounts (> ₹1,000,000) or corrupt imports
    await db.delete('expenses', where: 'amount > ? OR note = ?', whereArgs: [100000000, 'Imported CSV']);
    await db.delete('incomes', where: 'amount > ?', whereArgs: [100000000]);
    // Reset standard 40k seed opening balance on Salary Account to 0
    await db.update('accounts', {'opening_balance': 0}, where: 'name = ? AND opening_balance = ?', whereArgs: ['Salary Account', 4000000]);
  }

  // --- FAST SQL AGGREGATIONS FOR REPORTS & DASHBOARD ---

  Future<int> getTotalPaiseForDateRange(String startIso, String endIso) async {
    final db = await database;
    final res = await db.rawQuery(
      'SELECT SUM(amount) as total FROM expenses WHERE date >= ? AND date <= ?',
      [startIso, endIso],
    );
    return (res.first['total'] as int?) ?? 0;
  }

  Future<Map<String, Map<String, int>>> getMonthlyDailyTotals(int year, int month) async {
    final db = await database;
    final yearStr = year.toString().padLeft(4, '0');
    final monthStr = month.toString().padLeft(2, '0');
    final prefix = '$yearStr-$monthStr%';

    final expRes = await db.rawQuery('''
      SELECT date, SUM(amount) as total FROM expenses WHERE date LIKE ? GROUP BY date
    ''', [prefix]);

    final incRes = await db.rawQuery('''
      SELECT date, SUM(amount) as total FROM incomes WHERE date LIKE ? GROUP BY date
    ''', [prefix]);

    final Map<String, Map<String, int>> result = {};
    for (final row in expRes) {
      final d = row['date'] as String;
      final tot = (row['total'] as int?) ?? 0;
      result.putIfAbsent(d, () => {'expense': 0, 'income': 0})['expense'] = tot;
    }
    for (final row in incRes) {
      final d = row['date'] as String;
      final tot = (row['total'] as int?) ?? 0;
      result.putIfAbsent(d, () => {'expense': 0, 'income': 0})['income'] = tot;
    }

    return result;
  }

  Future<Map<int, int>> getCategoryTotalsForDateRange(String startIso, String endIso) async {
    final db = await database;
    final res = await db.rawQuery('''
      SELECT category_id, SUM(amount) as total 
      FROM expenses 
      WHERE date >= ? AND date <= ?
      GROUP BY category_id
    ''', [startIso, endIso]);

    final Map<int, int> map = {};
    for (final row in res) {
      final catId = row['category_id'] as int;
      final total = (row['total'] as int?) ?? 0;
      map[catId] = total;
    }
    return map;
  }

  Future<List<Map<String, dynamic>>> getDailySpendTotals(String startIso, String endIso) async {
    final db = await database;
    return await db.rawQuery('''
      SELECT date, SUM(amount) as total 
      FROM expenses 
      WHERE date >= ? AND date <= ?
      GROUP BY date
      ORDER BY date ASC
    ''', [startIso, endIso]);
  }

  Future<Map<String, dynamic>?> getHighestSingleExpense(String startIso, String endIso) async {
    final db = await database;
    final res = await db.rawQuery('''
      SELECT amount, note, date 
      FROM expenses 
      WHERE date >= ? AND date <= ?
      ORDER BY amount DESC 
      LIMIT 1
    ''', [startIso, endIso]);

    if (res.isEmpty) return null;
    return res.first;
  }

  Future<int> getTotalIncomePaiseForDateRange(String startIso, String endIso) async {
    final db = await database;
    final result = await db.rawQuery(
      'SELECT SUM(amount) as total FROM incomes WHERE date >= ? AND date <= ?',
      [startIso, endIso],
    );
    final val = result.first['total'];
    return (val as int?) ?? 0;
  }

  Future<List<int>> getAvailableYears() async {
    final db = await database;
    final expYears = await db.rawQuery(
      "SELECT DISTINCT CAST(substr(date, 1, 4) AS INTEGER) as yr FROM expenses WHERE date IS NOT NULL AND length(date) >= 4"
    );
    final incYears = await db.rawQuery(
      "SELECT DISTINCT CAST(substr(date, 1, 4) AS INTEGER) as yr FROM incomes WHERE date IS NOT NULL AND length(date) >= 4"
    );

    final Set<int> yearsSet = {};
    for (final row in expYears) {
      final y = row['yr'] as int?;
      if (y != null && y > 2000) yearsSet.add(y);
    }
    for (final row in incYears) {
      final y = row['yr'] as int?;
      if (y != null && y > 2000) yearsSet.add(y);
    }

    yearsSet.add(DateTime.now().year);
    final list = yearsSet.toList()..sort((a, b) => b.compareTo(a));
    return list;
  }

  // --- SETTINGS CRUD ---

  Future<AppSettings> getSettings() async {
    final db = await database;
    final maps = await db.query('settings');
    final Map<String, String> settingsMap = {};
    for (final m in maps) {
      settingsMap[m['key'] as String] = m['value'] as String;
    }
    return AppSettings.fromMap(settingsMap);
  }

  Future<void> updateSetting(String key, String value) async {
    final db = await database;
    await db.insert(
      'settings',
      {'key': key, 'value': value},
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  // --- BACKUP & RESTORE ---

  Future<Map<String, dynamic>> exportDataJson() async {
    final db = await database;
    final categories = await db.query('categories');
    final accounts = await db.query('accounts');
    final expenses = await db.query('expenses');
    final incomes = await db.query('incomes');
    final transfers = await db.query('transfers');
    final settings = await db.query('settings');

    return {
      'version': 2,
      'exported_at': DateTime.now().toIso8601String(),
      'categories': categories,
      'accounts': accounts,
      'expenses': expenses,
      'incomes': incomes,
      'transfers': transfers,
      'settings': settings,
    };
  }

  Future<void> importDataJson(Map<String, dynamic> data) async {
    if (!data.containsKey('categories') || !data.containsKey('expenses')) {
      throw FormatException('Invalid backup file format');
    }

    final db = await database;
    await db.transaction((txn) async {
      // Clear existing
      await txn.delete('expenses');
      await txn.delete('incomes');
      await txn.delete('transfers');
      await txn.delete('categories');
      await txn.delete('accounts');
      await txn.delete('settings');

      // Insert accounts
      if (data.containsKey('accounts')) {
        final accountsList = List<Map<String, dynamic>>.from(data['accounts']);
        for (final acc in accountsList) {
          await txn.insert('accounts', acc, conflictAlgorithm: ConflictAlgorithm.replace);
        }
      } else {
        for (final acc in Account.defaultAccounts) {
          await txn.insert('accounts', acc.toMap(), conflictAlgorithm: ConflictAlgorithm.replace);
        }
      }

      // Insert categories
      final categoriesList = List<Map<String, dynamic>>.from(data['categories']);
      for (final cat in categoriesList) {
        await txn.insert('categories', cat, conflictAlgorithm: ConflictAlgorithm.replace);
      }

      // Insert expenses
      final expensesList = List<Map<String, dynamic>>.from(data['expenses']);
      for (final exp in expensesList) {
        await txn.insert('expenses', exp, conflictAlgorithm: ConflictAlgorithm.replace);
      }

      // Insert incomes
      if (data.containsKey('incomes')) {
        final incomesList = List<Map<String, dynamic>>.from(data['incomes']);
        for (final inc in incomesList) {
          await txn.insert('incomes', inc, conflictAlgorithm: ConflictAlgorithm.replace);
        }
      }

      // Insert transfers
      if (data.containsKey('transfers')) {
        final transfersList = List<Map<String, dynamic>>.from(data['transfers']);
        for (final tr in transfersList) {
          await txn.insert('transfers', tr, conflictAlgorithm: ConflictAlgorithm.replace);
        }
      }

      // Insert settings
      if (data.containsKey('settings')) {
        final settingsList = List<Map<String, dynamic>>.from(data['settings']);
        for (final st in settingsList) {
          await txn.insert('settings', st, conflictAlgorithm: ConflictAlgorithm.replace);
        }
      }
    });
  }

  Future<Map<int, List<int>>> getAvailableExportYearsAndMonths() async {
    final db = await database;
    final Map<int, Set<int>> resultMap = {};

    final rows = await db.query(
      'expenses',
      columns: ['date'],
      where: 'date IS NOT NULL',
      orderBy: 'date DESC',
    );

    for (final row in rows) {
      final dateStr = row['date'] as String?;
      if (dateStr != null && dateStr.isNotEmpty) {
        final parsed = DateTime.tryParse(dateStr);
        if (parsed != null) {
          resultMap.putIfAbsent(parsed.year, () => <int>{}).add(parsed.month);
        }
      }
    }

    final Map<int, List<int>> sortedResult = {};
    final years = resultMap.keys.toList()..sort((a, b) => b.compareTo(a));
    for (final y in years) {
      final mList = resultMap[y]!.toList()..sort((a, b) => b.compareTo(a));
      sortedResult[y] = mList;
    }
    return sortedResult;
  }

  Future<List<Map<String, dynamic>>> getAvailableExportMonths() async {
    final db = await database;
    final List<Map<String, dynamic>> result = [];
    final set = <String>{};

    final rows = await db.query(
      'expenses',
      columns: ['date'],
      where: 'date IS NOT NULL',
      orderBy: 'date DESC',
    );

    const months = [
      'January', 'February', 'March', 'April', 'May', 'June',
      'July', 'August', 'September', 'October', 'November', 'December'
    ];

    for (final row in rows) {
      final dateStr = row['date'] as String?;
      if (dateStr != null && dateStr.isNotEmpty) {
        final parsed = DateTime.tryParse(dateStr);
        if (parsed != null) {
          final key = '${parsed.year}-${parsed.month}';
          if (!set.contains(key)) {
            set.add(key);
            result.add({
              'year': parsed.year,
              'month': parsed.month,
              'label': '${months[parsed.month - 1]} ${parsed.year}',
            });
          }
        }
      }
    }
    return result;
  }

  Future<void> clearAllData() async {
    final db = await database;
    await db.transaction((txn) async {
      await txn.delete('expenses');
      await txn.delete('incomes');
      await txn.delete('transfers');
      await txn.delete('categories');
      await txn.delete('accounts');
      await txn.delete('settings');

      // Re-seed default categories
      for (final cat in Category.defaultCategories) {
        await txn.insert('categories', cat.toMap());
      }

      // Re-seed default accounts
      for (final acc in Account.defaultAccounts) {
        await txn.insert('accounts', acc.toMap());
      }

      // Re-seed settings
      final defaultSettings = AppSettings();
      defaultSettings.toMap().forEach((key, value) async {
        await txn.insert('settings', {'key': key, 'value': value});
      });
    });
  }
}
