import 'package:uuid/uuid.dart';
import 'package:intl/intl.dart';
import '../core/database/database_helper.dart';
import '../models/order.dart';
import '../models/order_item.dart';

class OrderRepository {
  final DatabaseHelper _db = DatabaseHelper.instance;
  final _uuid = const Uuid();

  String _generateOrderCode() {
    final now = DateTime.now();
    final dateStr = DateFormat('yyyyMMdd').format(now);
    final timeStr = DateFormat('HHmmss').format(now);
    return 'DH$dateStr$timeStr';
  }

  String _generateBarcode() {
    return _uuid.v4().replaceAll('-', '').substring(0, 12).toUpperCase();
  }

  Future<int> create(Order order, List<OrderItem> items) async {
    final db = await _db.database;

    // Start transaction
    return await db.transaction((txn) async {
      // Insert order
      final orderId = await txn.insert('orders', order.toMap());

      // Insert order items
      // Insert order items using batch
      final batch = txn.batch();
      for (final item in items) {
        batch.insert(
          'order_items',
          item.copyWith(orderId: orderId).toMap(),
        );
      }
      await batch.commit(noResult: true);

      return orderId;
    });
  }

  Future<Order> createOrderWithCode(Order order, List<OrderItem> items) async {
    // Generate order code and barcode if not provided
    final orderCode = order.orderCode.isEmpty ? _generateOrderCode() : order.orderCode;
    final barcode = order.barcode.isEmpty ? _generateBarcode() : order.barcode;

    final newOrder = order.copyWith(
      orderCode: orderCode,
      barcode: barcode,
    );

    final id = await create(newOrder, items);
    return newOrder.copyWith(id: id);
  }

  Future<List<Order>> getAll({
    String? status,
    DateTime? startDate,
    DateTime? endDate,
    int? customerId,
    String? searchQuery,
    int? limit,
    int? offset,
  }) async {
    String where = '1=1';
    List<dynamic> whereArgs = [];

    if (status != null) {
      where += ' AND status = ?';
      whereArgs.add(status);
    }

    if (startDate != null) {
      where += ' AND DATE(received_date) >= ?';
      whereArgs.add(DateFormat('yyyy-MM-dd').format(startDate));
    }

    if (endDate != null) {
      where += ' AND DATE(received_date) <= ?';
      whereArgs.add(DateFormat('yyyy-MM-dd').format(endDate));
    }

    if (customerId != null) {
      where += ' AND customer_id = ?';
      whereArgs.add(customerId);
    }

    if (searchQuery != null && searchQuery.isNotEmpty) {
      where += ' AND (order_code LIKE ? OR barcode LIKE ?)';
      whereArgs.add('%$searchQuery%');
      whereArgs.add('%$searchQuery%');
    }

    final results = await _db.query(
      'orders',
      where: where,
      whereArgs: whereArgs,
      orderBy: 'received_date DESC',
      limit: limit,
      offset: offset,
    );

    return results.map((map) => Order.fromMap(map)).toList();
  }

  Future<Order?> getById(int id) async {
    final results = await _db.query(
      'orders',
      where: 'id = ?',
      whereArgs: [id],
    );

    if (results.isEmpty) return null;
    return Order.fromMap(results.first);
  }

  Future<Order?> getByCode(String orderCode) async {
    final results = await _db.query(
      'orders',
      where: 'order_code = ?',
      whereArgs: [orderCode],
    );

    if (results.isEmpty) return null;
    return Order.fromMap(results.first);
  }

  Future<Order?> getByBarcode(String barcode) async {
    final results = await _db.query(
      'orders',
      where: 'barcode = ?',
      whereArgs: [barcode],
    );

    if (results.isEmpty) return null;
    return Order.fromMap(results.first);
  }

  Future<List<OrderItem>> getOrderItems(int orderId) async {
    final results = await _db.query(
      'order_items',
      where: 'order_id = ?',
      whereArgs: [orderId],
    );

    return results.map((map) => OrderItem.fromMap(map)).toList();
  }

  Future<List<Map<String, dynamic>>> getOrderItemsWithServiceName(int orderId) async {
    return await _db.rawQuery('''
      SELECT 
        oi.*,
        s.name as service_name,
        s.unit as service_unit
      FROM order_items oi
      INNER JOIN services s ON oi.service_id = s.id
      WHERE oi.order_id = ?
    ''', [orderId]);
  }

  Future<List<Map<String, dynamic>>> getAllWithCustomerInfo({
    String? status,
    DateTime? startDate,
    DateTime? endDate,
  }) async {
    String where = '1=1';
    List<dynamic> whereArgs = [];

    if (status != null) {
      where += ' AND o.status = ?';
      whereArgs.add(status);
    }

    if (startDate != null) {
      where += ' AND DATE(o.received_date) >= ?';
      whereArgs.add(DateFormat('yyyy-MM-dd').format(startDate));
    }

    if (endDate != null) {
      where += ' AND DATE(o.received_date) <= ?';
      whereArgs.add(DateFormat('yyyy-MM-dd').format(endDate));
    }

    return await _db.rawQuery('''
      SELECT 
        o.*,
        c.name as customer_name,
        c.phone as customer_phone,
        c.address as customer_address,
        u.full_name as employee_name
      FROM orders o
      INNER JOIN customers c ON o.customer_id = c.id
      INNER JOIN users u ON o.employee_id = u.id
      WHERE $where
      ORDER BY o.received_date DESC
    ''', whereArgs);
  }

  Future<int> updateOrderStatus(int orderId, String status) async {
    return await updateStatus(orderId, status);
  }

  Future<int> update(Order order) async {
    return await _db.update(
      'orders',
      order.copyWith(updatedAt: DateTime.now()).toMap(),
      where: 'id = ?',
      whereArgs: [order.id],
    );
  }

  Future<int> updateStatus(int orderId, String status) async {
    final updates = {
      'status': status,
      'updated_at': DateTime.now().toIso8601String(),
    };

    // If status is delivered, set completed_date
    if (status == 'delivered') {
      updates['completed_date'] = DateTime.now().toIso8601String();
    }

    return await _db.update(
      'orders',
      updates,
      where: 'id = ?',
      whereArgs: [orderId],
    );
  }

  Future<int> updatePayment(int orderId, double paidAmount, String? paymentMethod) async {
    return await _db.update(
      'orders',
      {
        'paid_amount': paidAmount,
        'payment_method': paymentMethod,
        'updated_at': DateTime.now().toIso8601String(),
      },
      where: 'id = ?',
      whereArgs: [orderId],
    );
  }
  
  Future<List<Map<String, dynamic>>> getOrdersByCustomer(int customerId) async {
    return await _db.query(
      'orders',
      where: 'customer_id = ?',
      whereArgs: [customerId],
      orderBy: 'received_date DESC',
    );
  }

  Future<int> delete(int id) async {
    // Order items will be automatically deleted due to ON DELETE CASCADE
    return await _db.delete(
      'orders',
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  Future<Map<String, int>> getOrderStatusCounts() async {
    final results = await _db.rawQuery('''
      SELECT status, COUNT(*) as count
      FROM orders
      GROUP BY status
    ''');

    final Map<String, int> counts = {};
    for (final row in results) {
      counts[row['status'] as String] = row['count'] as int;
    }

    return counts;
  }

  Future<double> getTotalRevenue({DateTime? startDate, DateTime? endDate}) async {
    String where = '1=1';
    List<dynamic> whereArgs = [];

    if (startDate != null) {
      where += ' AND DATE(received_date) >= ?';
      whereArgs.add(DateFormat('yyyy-MM-dd').format(startDate));
    }

    if (endDate != null) {
      where += ' AND DATE(received_date) <= ?';
      whereArgs.add(DateFormat('yyyy-MM-dd').format(endDate));
    }

    final result = await _db.rawQuery('''
      SELECT SUM(paid_amount) as total
      FROM orders
      WHERE $where
    ''', whereArgs);

    return (result.first['total'] as num?)?.toDouble() ?? 0.0;
  }

  Future<List<Map<String, dynamic>>> getRevenueByDate({
    required DateTime startDate,
    required DateTime endDate,
  }) async {
    return await _db.rawQuery('''
      SELECT 
        DATE(received_date) as date,
        COUNT(*) as order_count,
        SUM(total_amount) as total_amount,
        SUM(paid_amount) as paid_amount
      FROM orders
      WHERE DATE(received_date) BETWEEN ? AND ?
      GROUP BY DATE(received_date)
      ORDER BY date
    ''', [
      DateFormat('yyyy-MM-dd').format(startDate),
      DateFormat('yyyy-MM-dd').format(endDate),
    ]);
  }
  
  Future<Map<String, dynamic>> getRevenueStats(DateTime startDate, DateTime endDate) async {
    final result = await _db.rawQuery('''
      SELECT 
        COUNT(*) as total_orders,
        COALESCE(SUM(total_amount), 0) as total_revenue,
        COALESCE(SUM(paid_amount), 0) as total_paid,
        COALESCE(AVG(total_amount), 0) as avg_order_value
      FROM orders
      WHERE DATE(received_date) BETWEEN ? AND ?
    ''', [
      DateFormat('yyyy-MM-dd').format(startDate),
      DateFormat('yyyy-MM-dd').format(endDate),
    ]);
    
    if (result.isEmpty) {
      return {
        'total_orders': 0,
        'total_revenue': 0.0,
        'total_paid': 0.0,
        'avg_order_value': 0.0,
      };
    }
    
    return result.first;
  }
  
  Future<List<Map<String, dynamic>>> getDailyRevenue(DateTime startDate, DateTime endDate) async {
    return await _db.rawQuery('''
      SELECT 
        DATE(received_date) as date,
        COALESCE(SUM(total_amount), 0) as revenue,
        COUNT(*) as order_count
      FROM orders
      WHERE DATE(received_date) BETWEEN ? AND ?
      GROUP BY DATE(received_date)
      ORDER BY date
    ''', [
      DateFormat('yyyy-MM-dd').format(startDate),
      DateFormat('yyyy-MM-dd').format(endDate),
    ]);
  }
}
