import 'dart:io';
import 'dart:convert';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:path/path.dart';
import 'package:path_provider/path_provider.dart';
import 'package:crypto/crypto.dart';
import '../../config/constants.dart';

class DatabaseHelper {
  static final DatabaseHelper instance = DatabaseHelper._init();
  static Database? _database;

  DatabaseHelper._init();

  Future<Database> get database async {
    if (_database != null) return _database!;
    _database = await _initDB();
    return _database!;
  }

  Future<Database> _initDB() async {
    // Initialize FFI for desktop
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;

    final documentsDirectory = await getApplicationDocumentsDirectory();
    final dbPath = join(documentsDirectory.path, 'LaundryManagement');
    
    // Create directory if it doesn't exist
    await Directory(dbPath).create(recursive: true);
    
    final path = join(dbPath, AppConstants.dbName);

    return await openDatabase(
      path,
      version: AppConstants.dbVersion,
      onConfigure: _onConfigure,
      onCreate: _createDB,
      onUpgrade: _upgradeDB,
    );
  }

  Future<void> _onConfigure(Database db) async {
    // Performance optimizations for Windows
    await db.execute('PRAGMA foreign_keys = ON');
    await db.execute('PRAGMA journal_mode = WAL');
    await db.execute('PRAGMA synchronous = NORMAL');
  }

  Future<void> _createDB(Database db, int version) async {
    // Create users table
    await db.execute('''
      CREATE TABLE users (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        username TEXT UNIQUE NOT NULL,
        password_hash TEXT NOT NULL,
        full_name TEXT NOT NULL,
        role TEXT NOT NULL,
        phone TEXT,
        email TEXT,
        is_active INTEGER DEFAULT 1,
        created_at TEXT NOT NULL,
        updated_at TEXT NOT NULL
      )
    ''');

    // Create customers table
    await db.execute('''
      CREATE TABLE customers (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        name TEXT NOT NULL,
        phone TEXT NOT NULL,
        address TEXT,
        email TEXT,
        notes TEXT,
        created_at TEXT NOT NULL,
        updated_at TEXT NOT NULL
      )
    ''');

    // Create services table
    await db.execute('''
      CREATE TABLE services (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        name TEXT NOT NULL,
        category TEXT,
        price REAL NOT NULL,
        unit TEXT NOT NULL,
        description TEXT,
        is_active INTEGER DEFAULT 1,
        created_at TEXT NOT NULL,
        updated_at TEXT NOT NULL
      )
    ''');

    // Create orders table
    await db.execute('''
      CREATE TABLE orders (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        order_code TEXT UNIQUE NOT NULL,
        barcode TEXT UNIQUE NOT NULL,
        customer_id INTEGER NOT NULL,
        employee_id INTEGER NOT NULL,
        status TEXT NOT NULL,
        total_amount REAL DEFAULT 0,
        paid_amount REAL DEFAULT 0,
        payment_method TEXT,
        notes TEXT,
        received_date TEXT NOT NULL,
        delivery_date TEXT,
        completed_date TEXT,
        created_at TEXT NOT NULL,
        updated_at TEXT NOT NULL,
        FOREIGN KEY (customer_id) REFERENCES customers(id),
        FOREIGN KEY (employee_id) REFERENCES users(id)
      )
    ''');

    // Create order_items table
    await db.execute('''
      CREATE TABLE order_items (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        order_id INTEGER NOT NULL,
        service_id INTEGER NOT NULL,
        quantity REAL NOT NULL,
        unit_price REAL NOT NULL,
        subtotal REAL NOT NULL,
        notes TEXT,
        FOREIGN KEY (order_id) REFERENCES orders(id) ON DELETE CASCADE,
        FOREIGN KEY (service_id) REFERENCES services(id)
      )
    ''');

    // Create transactions table
    await db.execute('''
      CREATE TABLE transactions (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        type TEXT NOT NULL,
        category TEXT NOT NULL,
        amount REAL NOT NULL,
        description TEXT,
        order_id INTEGER,
        user_id INTEGER NOT NULL,
        transaction_date TEXT NOT NULL,
        created_at TEXT NOT NULL,
        FOREIGN KEY (order_id) REFERENCES orders(id),
        FOREIGN KEY (user_id) REFERENCES users(id)
      )
    ''');

    // Create assets table
    await db.execute('''
      CREATE TABLE assets (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        code TEXT,
        name TEXT NOT NULL,
        category TEXT,
        serial_number TEXT,
        purchase_date TEXT,
        purchase_price REAL,
        condition TEXT,
        location TEXT,
        notes TEXT,
        created_at TEXT NOT NULL,
        updated_at TEXT NOT NULL
      )
    ''');

    // Create maintenance_records table
    await db.execute('''
      CREATE TABLE maintenance_records (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        asset_id INTEGER NOT NULL,
        date TEXT NOT NULL,
        description TEXT NOT NULL,
        cost REAL DEFAULT 0,
        technician TEXT,
        created_at TEXT NOT NULL,
        FOREIGN KEY (asset_id) REFERENCES assets(id) ON DELETE CASCADE
      )
    ''');

    // Create salaries table
    await db.execute('''
      CREATE TABLE salaries (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        employee_id INTEGER NOT NULL,
        month TEXT NOT NULL,
        base_salary REAL NOT NULL,
        bonus REAL DEFAULT 0,
        deduction REAL DEFAULT 0,
        total_salary REAL NOT NULL,
        paid INTEGER DEFAULT 0,
        paid_date TEXT,
        notes TEXT,
        created_at TEXT NOT NULL,
        FOREIGN KEY (employee_id) REFERENCES users(id)
      )
    ''');

    // Create materials table (Inventory)
    await db.execute('''
      CREATE TABLE materials (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        name TEXT NOT NULL,
        unit TEXT NOT NULL,
        quantity REAL DEFAULT 0,
        min_quantity REAL DEFAULT 0,
        cost_price REAL DEFAULT 0,
        image_path TEXT,
        notes TEXT,
        created_at TEXT NOT NULL,
        updated_at TEXT NOT NULL
      )
    ''');

    // Create work_shifts table
    await db.execute('''
      CREATE TABLE work_shifts (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        name TEXT NOT NULL,
        start_time TEXT NOT NULL,
        end_time TEXT NOT NULL,
        is_active INTEGER DEFAULT 1,
        created_at TEXT NOT NULL,
        updated_at TEXT NOT NULL
      )
    ''');

    // Create timesheets table
    await db.execute('''
      CREATE TABLE timesheets (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        employee_id INTEGER NOT NULL,
        shift_id INTEGER,
        work_date TEXT NOT NULL,
        check_in TEXT,
        check_out TEXT,
        status TEXT NOT NULL,
        notes TEXT,
        created_at TEXT NOT NULL,
        updated_at TEXT NOT NULL,
        FOREIGN KEY (employee_id) REFERENCES users(id),
        FOREIGN KEY (shift_id) REFERENCES work_shifts(id)
      )
    ''');

    // Create indexes for better query performance
    await db.execute('CREATE INDEX idx_orders_customer ON orders(customer_id)');
    await db.execute('CREATE INDEX idx_orders_employee ON orders(employee_id)');
    await db.execute('CREATE INDEX idx_orders_status ON orders(status)');
    await db.execute('CREATE INDEX idx_orders_date ON orders(received_date)');
    await db.execute('CREATE INDEX idx_order_items_order ON order_items(order_id)');
    await db.execute('CREATE INDEX idx_transactions_date ON transactions(transaction_date)');
    await db.execute('CREATE INDEX idx_transactions_type ON transactions(type)');
    await db.execute('CREATE INDEX idx_salaries_employee ON salaries(employee_id)');
    await db.execute('CREATE INDEX idx_salaries_month ON salaries(month)');

    // Insert default admin user (password: admin123)
    await _createDefaultAdmin(db);

    // Insert sample services
    await _createDefaultServices(db);
  }

  Future<void> _upgradeDB(Database db, int oldVersion, int newVersion) async {
    // Handle database migrations
    if (oldVersion < 2) {
      // Version 2: Add materials table
      await db.execute('''
        CREATE TABLE materials (
          id INTEGER PRIMARY KEY AUTOINCREMENT,
          name TEXT NOT NULL,
          unit TEXT NOT NULL,
          quantity REAL DEFAULT 0,
          min_quantity REAL DEFAULT 0,
          cost_price REAL DEFAULT 0,
          image_path TEXT,
          notes TEXT,
          created_at TEXT NOT NULL,
          updated_at TEXT NOT NULL
        )
      ''');
    }

    if (oldVersion < 3) {
      // Version 3: Add shift management
      await db.execute('''
        CREATE TABLE work_shifts (
          id INTEGER PRIMARY KEY AUTOINCREMENT,
          name TEXT NOT NULL,
          start_time TEXT NOT NULL,
          end_time TEXT NOT NULL,
          is_active INTEGER DEFAULT 1,
          created_at TEXT NOT NULL,
          updated_at TEXT NOT NULL
        )
      ''');

      await db.execute('''
        CREATE TABLE timesheets (
          id INTEGER PRIMARY KEY AUTOINCREMENT,
          employee_id INTEGER NOT NULL,
          shift_id INTEGER,
          work_date TEXT NOT NULL,
          check_in TEXT,
          check_out TEXT,
          status TEXT NOT NULL,
          notes TEXT,
          created_at TEXT NOT NULL,
          updated_at TEXT NOT NULL,
          FOREIGN KEY (employee_id) REFERENCES users(id),
          FOREIGN KEY (shift_id) REFERENCES work_shifts(id)
        )
      ''');
    }

    if (oldVersion < 4) {
      // Version 4: Add code and serial_number to assets
      try {
        await db.execute('ALTER TABLE assets ADD COLUMN code TEXT');
        await db.execute('ALTER TABLE assets ADD COLUMN serial_number TEXT');
      } catch (e) {
        // Ignore if columns already exist
      }
    }

    if (oldVersion < 5) {
      // Version 5: Add maintenance_records table
      await db.execute('''
        CREATE TABLE maintenance_records (
          id INTEGER PRIMARY KEY AUTOINCREMENT,
          asset_id INTEGER NOT NULL,
          date TEXT NOT NULL,
          description TEXT NOT NULL,
          cost REAL DEFAULT 0,
          technician TEXT,
          created_at TEXT NOT NULL,
          FOREIGN KEY (asset_id) REFERENCES assets(id) ON DELETE CASCADE
        )
      ''');
    }
  }

  Future<void> _createDefaultAdmin(Database db) async {
    // Hash password using the same method as auth_service (SHA256)
    final password = 'admin123';
    final passwordBytes = utf8.encode(password);
    final passwordHash = sha256.convert(passwordBytes).toString();
    
    await db.insert('users', {
      'username': 'admin',
      'password_hash': passwordHash,
      'full_name': 'Administrator',
      'role': AppConstants.roleAdmin,
      'phone': '0000000000',
      'email': 'admin@laundry.com',
      'is_active': 1,
      'created_at': DateTime.now().toIso8601String(),
      'updated_at': DateTime.now().toIso8601String(),
    });
  }

  Future<void> _createDefaultServices(Database db) async {
    final now = DateTime.now().toIso8601String();
    
    final defaultServices = [
      {
        'name': 'Giặt thường',
        'category': 'Giặt',
        'price': 15000,
        'unit': AppConstants.unitKg,
        'description': 'Giặt quần áo thường',
        'is_active': 1,
        'created_at': now,
        'updated_at': now,
      },
      {
        'name': 'Giặt hấp',
        'category': 'Giặt',
        'price': 20000,
        'unit': AppConstants.unitKg,
        'description': 'Giặt hấp quần áo cao cấp',
        'is_active': 1,
        'created_at': now,
        'updated_at': now,
      },
      {
        'name': 'Ủi đồ',
        'category': 'Ủi',
        'price': 10000,
        'unit': AppConstants.unitItem,
        'description': 'Ủi quần áo',
        'is_active': 1,
        'created_at': now,
        'updated_at': now,
      },
      {
        'name': 'Giặt chăn màn',
        'category': 'Giặt đặc biệt',
        'price': 50000,
        'unit': AppConstants.unitItem,
        'description': 'Giặt chăn ga gối đệm',
        'is_active': 1,
        'created_at': now,
        'updated_at': now,
      },
      {
        'name': 'Giặt khô',
        'category': 'Giặt đặc biệt',
        'price': 30000,
        'unit': AppConstants.unitItem,
        'description': 'Giặt khô quần áo cao cấp',
        'is_active': 1,
        'created_at': now,
        'updated_at': now,
      },
    ];

    for (final service in defaultServices) {
      await db.insert('services', service);
    }
  }

  // Generic CRUD operations
  Future<int> insert(String table, Map<String, dynamic> data) async {
    final db = await database;
    return await db.insert(table, data);
  }

  Future<List<Map<String, dynamic>>> query(
    String table, {
    String? where,
    List<dynamic>? whereArgs,
    String? orderBy,
    int? limit,
    int? offset,
  }) async {
    final db = await database;
    return await db.query(
      table,
      where: where,
      whereArgs: whereArgs,
      orderBy: orderBy,
      limit: limit,
      offset: offset,
    );
  }

  Future<int> update(
    String table,
    Map<String, dynamic> data, {
    required String where,
    required List<dynamic> whereArgs,
  }) async {
    final db = await database;
    return await db.update(table, data, where: where, whereArgs: whereArgs);
  }

  Future<int> delete(
    String table, {
    required String where,
    required List<dynamic> whereArgs,
  }) async {
    final db = await database;
    return await db.delete(table, where: where, whereArgs: whereArgs);
  }

  Future<List<Map<String, dynamic>>> rawQuery(String sql, [List<dynamic>? arguments]) async {
    final db = await database;
    return await db.rawQuery(sql, arguments);
  }

  Future<int> rawInsert(String sql, [List<dynamic>? arguments]) async {
    final db = await database;
    return await db.rawInsert(sql, arguments);
  }

  // Backup database
  Future<String> backupDatabase() async {
    final db = await database;
    final dbPath = db.path;
    
    final documentsDirectory = await getApplicationDocumentsDirectory();
    final backupDirectory = join(documentsDirectory.path, 'LaundryManagement', 'Backups');
    await Directory(backupDirectory).create(recursive: true);
    
    final timestamp = DateTime.now().toIso8601String().replaceAll(':', '-');
    final backupPath = join(backupDirectory, 'backup_$timestamp.db');
    
    await File(dbPath).copy(backupPath);
    return backupPath;
  }

  // Restore database from backup
  Future<void> restoreDatabase(String backupPath) async {
    final db = await database;
    final dbPath = db.path;
    
    await db.close();
    await File(backupPath).copy(dbPath);
    
    _database = null;
    await database; // Reinitialize
  }

  // Close database
  Future<void> close() async {
    final db = await database;
    await db.close();
    _database = null;
  }

  // Clear all data (for testing)
  Future<void> clearAllData() async {
    final db = await database;
    await db.delete('order_items');
    await db.delete('orders');
    await db.delete('transactions');
    await db.delete('salaries');
    await db.delete('customers');
    await db.delete('services');
    await db.delete('assets');
    await db.delete('users');
    
    // Recreate default admin
    await _createDefaultAdmin(db);
    await _createDefaultServices(db);
  }
}
