import 'package:intl/intl.dart';
import '../core/database/database_helper.dart';
import '../models/transaction.dart';

class TransactionRepository {
  final DatabaseHelper _db = DatabaseHelper.instance;

  Future<int> create(Transaction transaction) async {
    return await _db.insert('transactions', transaction.toMap());
  }

  Future<List<Transaction>> getAll({
    String? type,
    DateTime? startDate,
    DateTime? endDate,
    String? category,
  }) async {
    String where = '1=1';
    List<dynamic> whereArgs = [];

    if (type != null) {
      where += ' AND type = ?';
      whereArgs.add(type);
    }

    if (startDate != null) {
      where += ' AND DATE(transaction_date) >= ?';
      whereArgs.add(DateFormat('yyyy-MM-dd').format(startDate));
    }

    if (endDate != null) {
      where += ' AND DATE(transaction_date) <= ?';
      whereArgs.add(DateFormat('yyyy-MM-dd').format(endDate));
    }

    if (category != null) {
      where += ' AND category = ?';
      whereArgs.add(category);
    }

    final results = await _db.query(
      'transactions',
      where: where,
      whereArgs: whereArgs,
      orderBy: 'transaction_date DESC',
    );

    return results.map((map) => Transaction.fromMap(map)).toList();
  }

  Future<Transaction?> getById(int id) async {
    final results = await _db.query(
      'transactions',
      where: 'id = ?',
      whereArgs: [id],
    );

    if (results.isEmpty) return null;
    return Transaction.fromMap(results.first);
  }

  Future<int> update(Transaction transaction) async {
    return await _db.update(
      'transactions',
      transaction.toMap(),
      where: 'id = ?',
      whereArgs: [transaction.id],
    );
  }

  Future<int> delete(int id) async {
    return await _db.delete(
      'transactions',
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  Future<Map<String, double>> getSummary({
    DateTime? startDate,
    DateTime? endDate,
  }) async {
    String where = '1=1';
    List<dynamic> whereArgs = [];

    if (startDate != null) {
      where += ' AND DATE(transaction_date) >= ?';
      whereArgs.add(DateFormat('yyyy-MM-dd').format(startDate));
    }

    if (endDate != null) {
      where += ' AND DATE(transaction_date) <= ?';
      whereArgs.add(DateFormat('yyyy-MM-dd').format(endDate));
    }

    final results = await _db.rawQuery('''
      SELECT 
        type,
        SUM(amount) as total
      FROM transactions
      WHERE $where
      GROUP BY type
    ''', whereArgs);

    double income = 0;
    double expense = 0;

    for (final row in results) {
      final type = row['type'] as String;
      final total = (row['total'] as num).toDouble();

      if (type == 'income') {
        income = total;
      } else if (type == 'expense') {
        expense = total;
      }
    }

    return {
      'income': income,
      'expense': expense,
      'balance': income - expense,
    };
  }

  Future<List<String>> getAllCategories({String? type}) async {
    String? where;
    List<dynamic>? whereArgs;

    if (type != null) {
      where = 'type = ?';
      whereArgs = [type];
    }

    final results = await _db.query(
      'transactions',
      where: where,
      whereArgs: whereArgs,
    );

    final categories = results
        .map((row) => row['category'] as String)
        .toSet()
        .toList();
    
    categories.sort();
    return categories;
  }

  Future<List<Map<String, dynamic>>> getCategorySummary({
    String? type,
    DateTime? startDate,
    DateTime? endDate,
  }) async {
    String where = '1=1';
    List<dynamic> whereArgs = [];

    if (type != null) {
      where += ' AND type = ?';
      whereArgs.add(type);
    }

    if (startDate != null) {
      where += ' AND DATE(transaction_date) >= ?';
      whereArgs.add(DateFormat('yyyy-MM-dd').format(startDate));
    }

    if (endDate != null) {
      where += ' AND DATE(transaction_date) <= ?';
      whereArgs.add(DateFormat('yyyy-MM-dd').format(endDate));
    }

    return await _db.rawQuery('''
      SELECT 
        category,
        type,
        COUNT(*) as count,
        SUM(amount) as total
      FROM transactions
      WHERE $where
      GROUP BY category, type
      ORDER BY total DESC
    ''', whereArgs);
  }
}
