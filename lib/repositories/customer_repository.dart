import '../core/database/database_helper.dart';
import '../models/customer.dart';

class CustomerRepository {
  final DatabaseHelper _db = DatabaseHelper.instance;

  Future<int> create(Customer customer) async {
    return await _db.insert('customers', customer.toMap());
  }

  Future<List<Customer>> getAll({String? searchQuery}) async {
    List<Map<String, dynamic>> results;

    if (searchQuery != null && searchQuery.isNotEmpty) {
      results = await _db.rawQuery('''
        SELECT 
          c.*, 
          COUNT(o.id) as order_count,
          SUM(o.total_amount) as total_spent,
          MAX(o.received_date) as last_order_date,
          (SELECT status FROM orders WHERE customer_id = c.id ORDER BY received_date DESC LIMIT 1) as last_order_status
        FROM customers c
        LEFT JOIN orders o ON c.id = o.customer_id
        WHERE c.name LIKE ? OR c.phone LIKE ?
        GROUP BY c.id
        ORDER BY c.created_at DESC
      ''', ['%$searchQuery%', '%$searchQuery%']);
    } else {
      results = await _db.rawQuery('''
        SELECT 
          c.*, 
          COUNT(o.id) as order_count,
          SUM(o.total_amount) as total_spent,
          MAX(o.received_date) as last_order_date,
          (SELECT status FROM orders WHERE customer_id = c.id ORDER BY received_date DESC LIMIT 1) as last_order_status
        FROM customers c
        LEFT JOIN orders o ON c.id = o.customer_id
        GROUP BY c.id
        ORDER BY c.created_at DESC
      ''');
    }

    return results.map((map) => Customer.fromMap(map)).toList();
  }

  Future<Customer?> getById(int id) async {
    final results = await _db.query(
      'customers',
      where: 'id = ?',
      whereArgs: [id],
    );

    if (results.isEmpty) return null;
    return Customer.fromMap(results.first);
  }

  Future<Customer?> getByPhone(String phone) async {
    final results = await _db.query(
      'customers',
      where: 'phone = ?',
      whereArgs: [phone],
    );

    if (results.isEmpty) return null;
    return Customer.fromMap(results.first);
  }

  Future<int> update(Customer customer) async {
    return await _db.update(
      'customers',
      customer.copyWith(updatedAt: DateTime.now()).toMap(),
      where: 'id = ?',
      whereArgs: [customer.id],
    );
  }

  Future<int> delete(int id) async {
    return await _db.delete(
      'customers',
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  Future<int> getCount() async {
    final result = await _db.rawQuery('SELECT COUNT(*) as count FROM customers');
    return result.first['count'] as int;
  }

  Future<List<Map<String, dynamic>>> getTopCustomers({int limit = 10}) async {
    return await _db.rawQuery('''
      SELECT 
        c.*,
        COUNT(o.id) as order_count,
        SUM(o.total_amount) as total_spent
      FROM customers c
      LEFT JOIN orders o ON c.id = o.customer_id
      GROUP BY c.id
      ORDER BY total_spent DESC
      LIMIT ?
    ''', [limit]);
  }
}
