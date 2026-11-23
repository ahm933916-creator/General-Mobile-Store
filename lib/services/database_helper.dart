import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';
import '../models/models.dart';

class DatabaseHelper {
  static final DatabaseHelper instance = DatabaseHelper._init();
  static Database? _database;

  DatabaseHelper._init();

  Future<Database> get database async {
    if (_database != null) return _database!;
    _database = await _initDB('inventory_system.db');
    return _database!;
  }

  Future<Database> _initDB(String filePath) async {
    final dbPath = await getDatabasesPath();
    final path = join(dbPath, filePath);

    return await openDatabase(
      path,
      version: 10, // سجل العملة وتحويل أسعار المنتجات
      onCreate: _createDB,
      onUpgrade: _upgradeDB,
    );
  }

  Future _createDB(Database db, int version) async {
    await db.execute('''
      CREATE TABLE users (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        code TEXT NOT NULL UNIQUE,
        name TEXT NOT NULL UNIQUE,
        phone TEXT NOT NULL UNIQUE,
        address TEXT
      )
    ''');

    await db.execute('''
      CREATE TABLE categories (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        code TEXT,
        name TEXT NOT NULL UNIQUE
      )
    ''');

    await db.execute('''
      CREATE TABLE products (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        code TEXT NOT NULL UNIQUE,
        name TEXT NOT NULL UNIQUE,
        categoryId INTEGER,
        imagePath TEXT,
        barcodeImagePath TEXT,
        status TEXT NOT NULL,
        quantity INTEGER NOT NULL DEFAULT 1,
        purchasedQuantity INTEGER NOT NULL DEFAULT 0,
        currencyCode TEXT NOT NULL DEFAULT 'SYP',
        purchasePrice REAL NOT NULL DEFAULT 0.0,
        sellingPrice REAL NOT NULL DEFAULT 0.0,
        isForSale INTEGER NOT NULL DEFAULT 1,
        isForRent INTEGER NOT NULL DEFAULT 0,
        rentalPrice REAL NOT NULL DEFAULT 0.0,
        rentalStatus TEXT NOT NULL DEFAULT 'متاح',
        FOREIGN KEY (categoryId) REFERENCES categories (id) ON DELETE CASCADE
      )
    ''');

    await db.execute('''
      CREATE TABLE appointments (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        userId INTEGER,
        productId INTEGER,
        bookingDate TEXT NOT NULL,
        returnDate TEXT NOT NULL,
        cost REAL NOT NULL,
        paidAmount REAL NOT NULL,
        remainingDebt REAL NOT NULL,
        notes TEXT,
        FOREIGN KEY (userId) REFERENCES users (id) ON DELETE CASCADE,
        FOREIGN KEY (productId) REFERENCES products (id) ON DELETE CASCADE
      )
    ''');

    await db.execute('''
      CREATE TABLE expense_types (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        name TEXT NOT NULL UNIQUE
      )
    ''');

    await db.execute('''
      CREATE TABLE expenses (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        type TEXT NOT NULL,
        date TEXT NOT NULL,
        cost REAL NOT NULL,
        currencyCode TEXT NOT NULL DEFAULT 'SYP',
        exchangeRate REAL NOT NULL DEFAULT 1
      )
    ''');

    await db.execute('''
      CREATE TABLE sales_invoices (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        invoiceNumber TEXT NOT NULL UNIQUE,
        date TEXT NOT NULL,
        userId INTEGER,
        totalAmount REAL NOT NULL,
        paidAmount REAL NOT NULL,
        remainingDebt REAL NOT NULL,
        currencyCode TEXT NOT NULL DEFAULT 'SYP',
        exchangeRate REAL NOT NULL DEFAULT 1,
        FOREIGN KEY (userId) REFERENCES users (id) ON DELETE CASCADE
      )
    ''');

    await db.execute('''
      CREATE TABLE suppliers (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        code TEXT NOT NULL UNIQUE,
        name TEXT NOT NULL UNIQUE,
        phone TEXT NOT NULL,
        address TEXT
      )
    ''');

    await db.execute('''
      CREATE TABLE purchase_invoices (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        invoiceNumber TEXT NOT NULL UNIQUE,
        date TEXT NOT NULL,
        supplierId INTEGER,
        totalAmount REAL NOT NULL,
        paidAmount REAL NOT NULL,
        remainingDebt REAL NOT NULL,
        currencyCode TEXT NOT NULL DEFAULT 'SYP',
        exchangeRate REAL NOT NULL DEFAULT 1,
        FOREIGN KEY (supplierId) REFERENCES suppliers (id) ON DELETE SET NULL
      )
    ''');

    await db.execute('''
      CREATE TABLE purchase_items (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        invoiceId INTEGER,
        productId INTEGER,
        price REAL NOT NULL,
        quantity INTEGER NOT NULL,
        total REAL NOT NULL,
        FOREIGN KEY (invoiceId) REFERENCES purchase_invoices (id) ON DELETE CASCADE,
        FOREIGN KEY (productId) REFERENCES products (id) ON DELETE CASCADE
      )
    ''');

    await db.execute('''
      CREATE TABLE invoice_items (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        invoiceId INTEGER,
        productId INTEGER,
        price REAL NOT NULL,
        quantity INTEGER NOT NULL,
        total REAL NOT NULL,
        transactionType TEXT NOT NULL DEFAULT 'sale',
        rentalStartDate TEXT,
        rentalEndDate TEXT,
        FOREIGN KEY (invoiceId) REFERENCES sales_invoices (id) ON DELETE CASCADE,
        FOREIGN KEY (productId) REFERENCES products (id) ON DELETE CASCADE
      )
    ''');
  }

  Future _upgradeDB(Database db, int oldVersion, int newVersion) async {
    if (oldVersion < 3) {
      await db.execute('''
        CREATE TABLE IF NOT EXISTS sales_invoices (
          id INTEGER PRIMARY KEY AUTOINCREMENT,
          invoiceNumber TEXT NOT NULL UNIQUE,
          date TEXT NOT NULL,
          userId INTEGER,
          totalAmount REAL NOT NULL,
          paidAmount REAL NOT NULL,
          remainingDebt REAL NOT NULL,
          FOREIGN KEY (userId) REFERENCES users (id) ON DELETE CASCADE
        )
      ''');

      await db.execute('''
        CREATE TABLE IF NOT EXISTS invoice_items (
          id INTEGER PRIMARY KEY AUTOINCREMENT,
          invoiceId INTEGER,
          productId INTEGER,
          price REAL NOT NULL,
          quantity INTEGER NOT NULL,
          total REAL NOT NULL,
          FOREIGN KEY (invoiceId) REFERENCES sales_invoices (id) ON DELETE CASCADE,
          FOREIGN KEY (productId) REFERENCES products (id) ON DELETE CASCADE
        )
      ''');
    }

    if (oldVersion < 4) {
      try {
        await db.execute('ALTER TABLE products ADD COLUMN barcodeImagePath TEXT;');
      } catch (_) {}
    }

    if (oldVersion < 5) {
      for (final statement in [
        'ALTER TABLE products ADD COLUMN isForSale INTEGER NOT NULL DEFAULT 1',
        'ALTER TABLE products ADD COLUMN isForRent INTEGER NOT NULL DEFAULT 0',
        'ALTER TABLE products ADD COLUMN rentalPrice REAL NOT NULL DEFAULT 0.0',
      ]) {
        try {
          await db.execute(statement);
        } catch (_) {}
      }
    }

    if (oldVersion < 6) {
      try {
        await db.execute("ALTER TABLE invoice_items ADD COLUMN transactionType TEXT NOT NULL DEFAULT 'sale'");
      } catch (_) {}
    }


    if (oldVersion < 8) {
      for (final statement in [
        'ALTER TABLE products ADD COLUMN purchasedQuantity INTEGER NOT NULL DEFAULT 0',
        '''CREATE TABLE IF NOT EXISTS suppliers (id INTEGER PRIMARY KEY AUTOINCREMENT, code TEXT NOT NULL UNIQUE, name TEXT NOT NULL UNIQUE, phone TEXT NOT NULL, address TEXT)''',
        '''CREATE TABLE IF NOT EXISTS purchase_invoices (id INTEGER PRIMARY KEY AUTOINCREMENT, invoiceNumber TEXT NOT NULL UNIQUE, date TEXT NOT NULL, supplierId INTEGER, totalAmount REAL NOT NULL, paidAmount REAL NOT NULL, remainingDebt REAL NOT NULL)''',
        '''CREATE TABLE IF NOT EXISTS purchase_items (id INTEGER PRIMARY KEY AUTOINCREMENT, invoiceId INTEGER, productId INTEGER, price REAL NOT NULL, quantity INTEGER NOT NULL, total REAL NOT NULL)''',
      ]) { try { await db.execute(statement); } catch (_) {} }
    }

    if (oldVersion < 10) {
      for (final statement in [
        "ALTER TABLE products ADD COLUMN currencyCode TEXT NOT NULL DEFAULT 'SYP'",
        "ALTER TABLE sales_invoices ADD COLUMN currencyCode TEXT NOT NULL DEFAULT 'SYP'",
        'ALTER TABLE sales_invoices ADD COLUMN exchangeRate REAL NOT NULL DEFAULT 1',
        "ALTER TABLE purchase_invoices ADD COLUMN currencyCode TEXT NOT NULL DEFAULT 'SYP'",
        'ALTER TABLE purchase_invoices ADD COLUMN exchangeRate REAL NOT NULL DEFAULT 1',
        "ALTER TABLE expenses ADD COLUMN currencyCode TEXT NOT NULL DEFAULT 'SYP'",
        'ALTER TABLE expenses ADD COLUMN exchangeRate REAL NOT NULL DEFAULT 1',
      ]) { try { await db.execute(statement); } catch (_) {} }
    }

    if (oldVersion < 9) {
      try { await db.execute('CREATE INDEX IF NOT EXISTS idx_purchase_items_invoice ON purchase_items(invoiceId)'); } catch (_) {}
    }

    if (oldVersion < 7) {
      for (final statement in [
        "ALTER TABLE products ADD COLUMN rentalStatus TEXT NOT NULL DEFAULT 'متاح'",
        'ALTER TABLE invoice_items ADD COLUMN rentalStartDate TEXT',
        'ALTER TABLE invoice_items ADD COLUMN rentalEndDate TEXT',
      ]) {
        try {
          await db.execute(statement);
        } catch (_) {}
      }
    }
  }

  // ==================== عمليات المستخدمين ====================
  Future<int> insertUser(AppUser user) async {
    final db = await database;
    return await db.insert('users', user.toMap());
  }

  Future<List<AppUser>> getUsers() async {
    final db = await database;
    final result = await db.query('users');
    return result.map((json) => AppUser.fromMap(json)).toList();
  }

  Future<int> updateUser(AppUser user) async {
    final db = await database;
    return await db.update('users', user.toMap(), where: 'id = ?', whereArgs: [user.id]);
  }

  Future<int> deleteUser(int id) async {
    final db = await database;
    return await db.delete('users', where: 'id = ?', whereArgs: [id]);
  }

  Future<double> getUserTotalDebt(int userId, {String targetCode = 'SYP', double targetRate = 1}) async {
    final db = await database;
    final rows = await db.query('sales_invoices', columns: ['remainingDebt', 'currencyCode', 'exchangeRate'], where: 'userId = ?', whereArgs: [userId]);
    return rows.fold<double>(0, (sum, row) {
      final value = (row['remainingDebt'] as num?)?.toDouble() ?? 0;
      final source = row['currencyCode']?.toString() == 'USD' ? value * ((row['exchangeRate'] as num?)?.toDouble() ?? 1) : value;
      return sum + (targetCode == 'USD' ? source / (targetRate <= 0 ? 1 : targetRate) : source);
    });
  }

  Future<double> getSupplierTotalDebt(int supplierId, {String targetCode = 'SYP', double targetRate = 1}) async {
    final rows = await (await database).query('purchase_invoices', columns: ['remainingDebt', 'currencyCode', 'exchangeRate'], where: 'supplierId = ?', whereArgs: [supplierId]);
    return rows.fold<double>(0, (sum, row) {
      final value = (row['remainingDebt'] as num?)?.toDouble() ?? 0;
      final source = row['currencyCode']?.toString() == 'USD' ? value * ((row['exchangeRate'] as num?)?.toDouble() ?? 1) : value;
      return sum + (targetCode == 'USD' ? source / (targetRate <= 0 ? 1 : targetRate) : source);
    });
  }

  Future<void> updateUserTotalDebtDirectly(int userId, double newTotalDebt) async {}

  // ==================== الموردون ====================
  Future<int> insertSupplier(Supplier supplier) async => (await database).insert('suppliers', supplier.toMap());
  Future<List<Supplier>> getSuppliers() async => (await database).query('suppliers').then((rows) => rows.map((row) => Supplier.fromMap(Map<String, dynamic>.from(row))).toList());
  Future<int> updateSupplier(Supplier supplier) async => (await database).update('suppliers', supplier.toMap(), where: 'id = ?', whereArgs: [supplier.id]);
  Future<int> deleteSupplier(int id) async => (await database).delete('suppliers', where: 'id = ?', whereArgs: [id]);

  Future<void> changeProductQuantity(int productId, int delta) async {
    final db = await database;
    await db.rawUpdate('UPDATE products SET quantity = quantity + ? WHERE id = ?', [delta, productId]);
  }

  Future<int> insertPurchaseInvoice(Map<String, dynamic> data) async {
    final db = await database;
    return db.transaction((txn) async {
      final id = await txn.insert('purchase_invoices', {
        'invoiceNumber': data['invoiceNumber'], 'date': data['date'], 'supplierId': data['supplierId'],
        'totalAmount': data['totalAmount'], 'paidAmount': data['paidAmount'], 'remainingDebt': data['remainingDebt'],
        'currencyCode': data['currencyCode'] ?? 'SYP',
        'exchangeRate': data['exchangeRate'] ?? 1,
      });
      for (final item in (data['items'] as List)) {
        await txn.insert('purchase_items', {'invoiceId': id, 'productId': item['productId'], 'price': item['price'], 'quantity': item['quantity'], 'total': item['total']});
        await txn.rawUpdate('UPDATE products SET quantity = quantity + ?, purchasedQuantity = purchasedQuantity + ? WHERE id = ?', [item['quantity'], item['quantity'], item['productId']]);
      }
      return id;
    });
  }

  Future<List> getPurchaseInvoices() async {
    final db = await database;
    final invoices = await db.rawQuery('SELECT purchase_invoices.*, suppliers.name AS supplierName FROM purchase_invoices LEFT JOIN suppliers ON suppliers.id = purchase_invoices.supplierId ORDER BY purchase_invoices.id DESC');
    final result = <Map<String, dynamic>>[];
    for (final invoice in invoices) {
      final row = Map<String, dynamic>.from(invoice);
      row['items'] = await db.rawQuery('SELECT purchase_items.*, products.name AS productName FROM purchase_items LEFT JOIN products ON products.id = purchase_items.productId WHERE purchase_items.invoiceId = ?', [invoice['id']]);
      result.add(row);
    }
    return result;
  }

  Future<int> deletePurchaseInvoice(int invoiceId) async {
    final db = await database;
    return db.transaction((txn) async {
      final items = await txn.query('purchase_items', where: 'invoiceId = ?', whereArgs: [invoiceId]);
      for (final item in items) {
        await txn.rawUpdate('UPDATE products SET quantity = quantity - ?, purchasedQuantity = purchasedQuantity - ? WHERE id = ?', [item['quantity'], item['quantity'], item['productId']]);
      }
      await txn.delete('purchase_items', where: 'invoiceId = ?', whereArgs: [invoiceId]);
      return txn.delete('purchase_invoices', where: 'id = ?', whereArgs: [invoiceId]);
    });
  }

  // ==================== عمليات التصنيفات ====================
  Future<int> insertCategory(Category category) async {
    final db = await database;
    return await db.insert('categories', category.toMap());
  }

  Future<List<Category>> getCategories() async {
    final db = await database;
    final result = await db.query('categories');
    return result.map((json) => Category.fromMap(json)).toList();
  }

  Future<int> updateCategory(Category category) async {
    final db = await database;
    return await db.update('categories', category.toMap(), where: 'id = ?', whereArgs: [category.id]);
  }

  Future<int> deleteCategory(int id) async {
    final db = await database;
    return await db.delete('categories', where: 'id = ?', whereArgs: [id]);
  }

  Future<void> convertProductPrices({required String fromCode, required double fromRate, required String toCode, required double toRate}) async {
    final db = await database;
    final rows = await db.query('products');
    for (final row in rows) {
      final storedCode = row['currencyCode']?.toString() ?? fromCode;
      final sourceRate = storedCode == 'USD' ? (fromRate <= 0 ? 1 : fromRate) : 1;
      final baseSypPurchase = ((row['purchasePrice'] as num?)?.toDouble() ?? 0) * sourceRate;
      final baseSypSelling = ((row['sellingPrice'] as num?)?.toDouble() ?? 0) * sourceRate;
      final baseSypRental = ((row['rentalPrice'] as num?)?.toDouble() ?? 0) * sourceRate;
      final targetRate = toCode == 'USD' ? (toRate <= 0 ? 1 : toRate) : 1;
      await db.update('products', {
        'purchasePrice': baseSypPurchase / targetRate,
        'sellingPrice': baseSypSelling / targetRate,
        'rentalPrice': baseSypRental / targetRate,
        'currencyCode': toCode,
      }, where: 'id = ?', whereArgs: [row['id']]);
    }
  }

  // ==================== عمليات المنتجات ====================
  Future<int> insertProduct(Product product) async {
    final db = await database;
    return await db.insert('products', product.toMap());
  }

  Future<List<Product>> getProducts() async {
    final db = await database;
    final result = await db.query('products');
    return result.map((json) => Product.fromMap(json)).toList();
  }

  Future<List> getProductsWithCategory() async {
    final db = await database;
    return await db.rawQuery('''
      SELECT products.*, categories.name as categoryName 
      FROM products 
      LEFT JOIN categories ON products.categoryId = categories.id
    ''');
  }

  Future<int> updateProduct(Product product) async {
    final db = await database;
    return await db.update('products', product.toMap(), where: 'id = ?', whereArgs: [product.id]);
  }

  Future<int> updateProductStatus(int productId, String status) async {
    final db = await database;
    return await db.update('products', {'status': status}, where: 'id = ?', whereArgs: [productId]);
  }

  Future<int> deleteProduct(int id) async {
    final db = await database;
    return await db.delete('products', where: 'id = ?', whereArgs: [id]);
  }

  // ==================== التقارير والمواعيد القديمة ====================
  Future<List> getAppointmentsSorted(String orderBy) async {
    final db = await database;
    return await db.rawQuery('''
      SELECT appointments.*, users.name as userName, products.name as productName, products.status as productStatus
      FROM appointments
      LEFT JOIN users ON appointments.userId = users.id
      LEFT JOIN products ON appointments.productId = products.id
      ORDER BY appointments.$orderBy DESC
    ''');
  }

  // ==================== الفواتير والمبيعات الجديدة ====================
  Future<String?> insertSalesInvoice(Map<String, dynamic> invoiceData, {bool stockAlreadyReserved = false}) async {
    final db = await database;

    List items = invoiceData['items'];
    for (var item in items) {
      int prodId = item['productId'];
      int requestedQty = item['quantity'];

      var prodResult = await db.query(
        'products',
        where: 'id = ?',
        whereArgs: [prodId],
      );

      if (prodResult.isNotEmpty) {
        int availableQty = (prodResult.first['quantity'] as num?)?.toInt() ?? 0;
        String prodName = prodResult.first['name']?.toString() ?? 'منتج';
        if (item['transactionType'] == 'rent' && prodResult.first['rentalStatus']?.toString() == 'محجوز للإيجار') {
          return '⚠️ المنتج ($prodName) محجوز للإيجار ولا يمكن حجزه مرة أخرى.';
        }
        if (!stockAlreadyReserved && requestedQty > availableQty) {
          return '⚠️ الكمية المطلوبة للمنتج ($prodName) أكبر من المتوفر في المخزون ($availableQty فقط)!';
        }
      } else {
        return '⚠️ أحد المنتجات غير موجود في النظام!';
      }
    }

    await db.transaction((txn) async {
      int invoiceId = await txn.insert('sales_invoices', {
        'invoiceNumber': invoiceData['invoiceNumber'],
        'date': invoiceData['date'],
        'userId': invoiceData['userId'],
        'totalAmount': invoiceData['totalAmount'],
        'paidAmount': invoiceData['paidAmount'],
        'remainingDebt': invoiceData['remainingDebt'],
        'currencyCode': invoiceData['currencyCode'] ?? 'SYP',
        'exchangeRate': invoiceData['exchangeRate'] ?? 1,
      });

      for (var item in items) {
        int prodId = item['productId'];
        int qty = item['quantity'];

        await txn.insert('invoice_items', {
          'invoiceId': invoiceId,
          'productId': prodId,
          'price': item['price'],
          'quantity': qty,
          'total': item['total'],
          'transactionType': item['transactionType'] ?? 'sale',
          'rentalStartDate': item['rentalStartDate'],
          'rentalEndDate': item['rentalEndDate'],
        });

        if (item['transactionType'] == 'rent') {
          await txn.update(
            'products',
            {'rentalStatus': 'محجوز للإيجار'},
            where: 'id = ?',
            whereArgs: [prodId],
          );
        }

        // خصم الكمية المباعة من مخزون المنتج الكلي
        if (!stockAlreadyReserved) {
          await txn.rawUpdate('UPDATE products SET quantity = quantity - ? WHERE id = ?', [qty, prodId]);
        }
      }
    });

    return null;
  }

  // دالة استرجاع الفواتير وتضمين كافة البنود التابعة لكل فاتورة مع أسماء المنتجات
  Future<List> getSalesInvoices() async {
    final db = await database;
    var invoices = await db.rawQuery('''
      SELECT sales_invoices.*, users.name as userName 
      FROM sales_invoices 
      LEFT JOIN users ON sales_invoices.userId = users.id 
      ORDER BY sales_invoices.id DESC
    ''');

    List detailedInvoices = [];
    for (var inv in invoices) {
      var mutableInv = Map<String, dynamic>.from(inv);
      var items = await db.rawQuery('''
        SELECT invoice_items.*, products.name as productName 
        FROM invoice_items 
        LEFT JOIN products ON invoice_items.productId = products.id 
        WHERE invoice_items.invoiceId = ?
      ''', [inv['id']]);
      
      mutableInv['items'] = items;
      detailedInvoices.add(mutableInv);
    }
    return detailedInvoices;
  }

  Future<int> deleteSalesInvoice(int invoiceId) async {
    final db = await database;
    return db.transaction((txn) async {
      final items = await txn.query('invoice_items', where: 'invoiceId = ?', whereArgs: [invoiceId]);
      for (final item in items) await txn.rawUpdate('UPDATE products SET quantity = quantity + ? WHERE id = ?', [item['quantity'], item['productId']]);
      await txn.delete('invoice_items', where: 'invoiceId = ?', whereArgs: [invoiceId]);
      return txn.delete('sales_invoices', where: 'id = ?', whereArgs: [invoiceId]);
    });
  }

  // ==================== عمليات المصروفات ====================
  Future<int> insertExpenseType(String name) async {
    final db = await database;
    return await db.insert('expense_types', {'name': name});
  }

  Future<List<ExpenseType>> getExpenseTypes() async {
    final db = await database;
    final result = await db.query('expense_types');
    return result.map((json) => ExpenseType.fromMap(json)).toList();
  }

  Future<int> insertExpense(Expense expense) async {
    final db = await database;
    return await db.insert('expenses', expense.toMap());
  }

  Future<List<Expense>> getExpenses() async {
    final db = await database;
    final result = await db.query('expenses', orderBy: 'date DESC');
    return result.map((json) => Expense.fromMap(json)).toList();
  }

  Future<int> updateExpense(Expense expense) async {
    final db = await database;
    return await db.update('expenses', expense.toMap(), where: 'id = ?', whereArgs: [expense.id]);
  }

  Future<int> deleteExpense(int id) async {
    final db = await database;
    return await db.delete('expenses', where: 'id = ?', whereArgs: [id]);
  }
}
