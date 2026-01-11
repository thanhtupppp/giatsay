import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:excel/excel.dart';
import 'package:intl/intl.dart';
import 'package:path_provider/path_provider.dart';

class ExportService {
  /// Export revenue report to Excel
  static Future<String?> exportRevenueToExcel({
    required DateTime startDate,
    required DateTime endDate,
    required Map<String, dynamic> stats,
    required List<Map<String, dynamic>> dailyRevenue,
    required List<Map<String, dynamic>> topCustomers,
    required List<Map<String, dynamic>> topServices,
  }) async {
    try {
      final data = RevenueExportData(
        startDate: startDate,
        endDate: endDate,
        stats: stats,
        dailyRevenue: dailyRevenue,
        topCustomers: topCustomers,
        topServices: topServices,
      );

      final bytes = await compute(_generateRevenueExcelBytes, data);
      
      if (bytes == null) throw Exception('Failed to generate Excel bytes');

      final fileName = 'BaoCaoDoanhThu_${DateFormat('yyyyMMdd').format(startDate)}_${DateFormat('yyyyMMdd').format(endDate)}.xlsx';
      return await _saveExcelBytes(bytes, fileName);
    } catch (e) {
      debugPrint('Error exporting revenue to Excel: $e');
      return null;
    }
  }

  static List<int>? _generateRevenueExcelBytes(RevenueExportData data) {
    var excel = Excel.createExcel();
    excel.delete('Sheet1');
    
    // Sheet 1: Summary
    final summarySheet = excel['Tổng quan'];
    summarySheet.appendRow([TextCellValue('BÁO CÁO DOANH THU')]);
    summarySheet.appendRow([
      TextCellValue('Từ ${DateFormat('dd/MM/yyyy').format(data.startDate)} đến ${DateFormat('dd/MM/yyyy').format(data.endDate)}'),
    ]);
    summarySheet.appendRow([TextCellValue('')]);
    
    summarySheet.appendRow([TextCellValue('Chỉ số'), TextCellValue('Giá trị')]);
    summarySheet.appendRow([
      TextCellValue('Tổng doanh thu'),
      TextCellValue(NumberFormat.currency(locale: 'vi', symbol: 'đ').format(data.stats['total_revenue'] ?? 0)),
    ]);
    summarySheet.appendRow([
      TextCellValue('Tổng đơn hàng'),
      TextCellValue('${data.stats['total_orders'] ?? 0}'),
    ]);
    summarySheet.appendRow([
      TextCellValue('Giá trị TB/đơn'),
      TextCellValue(NumberFormat.currency(locale: 'vi', symbol: 'đ').format(data.stats['avg_order_value'] ?? 0)),
    ]);
    summarySheet.appendRow([
      TextCellValue('Đã thanh toán'),
      TextCellValue(NumberFormat.currency(locale: 'vi', symbol: 'đ').format(data.stats['total_paid'] ?? 0)),
    ]);
    
    // Sheet 2: Daily Revenue
    final dailySheet = excel['Doanh thu theo ngày'];
    dailySheet.appendRow([TextCellValue('Ngày'), TextCellValue('Số đơn'), TextCellValue('Doanh thu')]);
    
    for (final day in data.dailyRevenue) {
      final date = DateTime.parse(day['date'] as String);
      dailySheet.appendRow([
        TextCellValue(DateFormat('dd/MM/yyyy').format(date)),
        IntCellValue(day['order_count'] as int),
        DoubleCellValue((day['revenue'] as num).toDouble()),
      ]);
    }
    
    // Sheet 3: Top Customers
    final customersSheet = excel['Top khách hàng'];
    customersSheet.appendRow([TextCellValue('Hạng'), TextCellValue('Tên khách hàng'), TextCellValue('Số đơn'), TextCellValue('Tổng chi tiêu')]);
    
    for (var i = 0; i < data.topCustomers.length; i++) {
      final customer = data.topCustomers[i];
      customersSheet.appendRow([
        IntCellValue(i + 1),
        TextCellValue(customer['name'] as String),
        IntCellValue(customer['order_count'] as int),
        DoubleCellValue((customer['total_spent'] as num).toDouble()),
      ]);
    }
    
    // Sheet 4: Top Services
    final servicesSheet = excel['Top dịch vụ'];
    servicesSheet.appendRow([TextCellValue('Hạng'), TextCellValue('Tên dịch vụ'), TextCellValue('Số lượt'), TextCellValue('Doanh thu')]);
    
    for (var i = 0; i < data.topServices.length; i++) {
      final service = data.topServices[i];
      servicesSheet.appendRow([
        IntCellValue(i + 1),
        TextCellValue(service['name'] as String),
        IntCellValue(service['usage_count'] as int),
        DoubleCellValue((service['total_revenue'] as num).toDouble()),
      ]);
    }
    
    return excel.encode();
  }
  
  /// Export orders to Excel
  static Future<String?> exportOrdersToExcel({
    required List<Map<String, dynamic>> orders,
  }) async {
    try {
      final bytes = await compute(_generateOrdersExcelBytes, orders);
      if (bytes == null) throw Exception('Failed to generate Excel bytes');
      
      final fileName = 'DanhSachDonHang_${DateFormat('yyyyMMdd_HHmmss').format(DateTime.now())}.xlsx';
      return await _saveExcelBytes(bytes, fileName);
    } catch (e) {
      debugPrint('Error exporting orders to Excel: $e');
      return null;
    }
  }

  static List<int>? _generateOrdersExcelBytes(List<Map<String, dynamic>> orders) {
    var excel = Excel.createExcel();
    excel.delete('Sheet1');
    
    final sheet = excel['Đơn hàng'];
    sheet.appendRow([
      TextCellValue('Mã đơn'),
      TextCellValue('Khách hàng'),
      TextCellValue('SĐT'),
      TextCellValue('Ngày nhận'),
      TextCellValue('Ngày giao'),
      TextCellValue('Tổng tiền'),
      TextCellValue('Đã trả'),
      TextCellValue('Còn lại'),
      TextCellValue('Trạng thái'),
    ]);
    
    for (final order in orders) {
      sheet.appendRow([
        TextCellValue(order['order_code'] as String),
        TextCellValue(order['customer_name'] as String? ?? ''),
        TextCellValue(order['customer_phone'] as String? ?? ''),
        TextCellValue(DateFormat('dd/MM/yyyy').format(DateTime.parse(order['received_date'] as String))),
        TextCellValue(order['delivery_date'] != null 
            ? DateFormat('dd/MM/yyyy').format(DateTime.parse(order['delivery_date'] as String))
            : ''),
        DoubleCellValue((order['total_amount'] as num).toDouble()),
        DoubleCellValue((order['paid_amount'] as num).toDouble()),
        DoubleCellValue((order['total_amount'] as num).toDouble() - (order['paid_amount'] as num).toDouble()),
        TextCellValue(order['status'] as String),
      ]);
    }
    return excel.encode();
  }
  
  /// Export customers to Excel
  static Future<String?> exportCustomersToExcel({
    required List<Map<String, dynamic>> customers,
  }) async {
    try {
      final bytes = await compute(_generateCustomersExcelBytes, customers);
      if (bytes == null) throw Exception('Failed to generate Excel bytes');

      final fileName = 'DanhSachKhachHang_${DateFormat('yyyyMMdd_HHmmss').format(DateTime.now())}.xlsx';
      return await _saveExcelBytes(bytes, fileName);
    } catch (e) {
      debugPrint('Error exporting customers to Excel: $e');
      return null;
    }
  }

  static List<int>? _generateCustomersExcelBytes(List<Map<String, dynamic>> customers) {
    var excel = Excel.createExcel();
    excel.delete('Sheet1');
    
    final sheet = excel['Khách hàng'];
    sheet.appendRow([
      TextCellValue('Tên'),
      TextCellValue('SĐT'),
      TextCellValue('Email'),
      TextCellValue('Địa chỉ'),
      TextCellValue('Tổng đơn'),
      TextCellValue('Tổng chi tiêu'),
    ]);
    
    for (final customer in customers) {
      sheet.appendRow([
        TextCellValue(customer['name'] as String),
        TextCellValue(customer['phone'] as String),
        TextCellValue(customer['email'] as String? ?? ''),
        TextCellValue(customer['address'] as String? ?? ''),
        IntCellValue(customer['total_orders'] as int? ?? 0),
        DoubleCellValue((customer['total_spent'] as num?)?.toDouble() ?? 0),
      ]);
    }
    return excel.encode();
  }
  
  /// Export transactions to Excel
  static Future<String?> exportTransactionsToExcel({
    required List<Map<String, dynamic>> transactions,
  }) async {
    try {
      final bytes = await compute(_generateTransactionsExcelBytes, transactions);
      if (bytes == null) throw Exception('Failed to generate Excel bytes');
      
      final fileName = 'BaoCaoThuChi_${DateFormat('yyyyMMdd_HHmmss').format(DateTime.now())}.xlsx';
      return await _saveExcelBytes(bytes, fileName);
    } catch (e) {
      debugPrint('Error exporting transactions to Excel: $e');
      return null;
    }
  }

  static List<int>? _generateTransactionsExcelBytes(List<Map<String, dynamic>> transactions) {
    var excel = Excel.createExcel();
    excel.delete('Sheet1');
    
    final sheet = excel['Thu chi'];
    sheet.appendRow([
      TextCellValue('Ngày'),
      TextCellValue('Loại'),
      TextCellValue('Danh mục'),
      TextCellValue('Mô tả'),
      TextCellValue('Số tiền'),
    ]);
    
    double totalIncome = 0;
    double totalExpense = 0;
    
    for (final transaction in transactions) {
      final amount = (transaction['amount'] as num).toDouble();
      final type = transaction['type'] as String;
      
      if (type == 'income') {
        totalIncome += amount;
      } else {
        totalExpense += amount;
      }
      
      sheet.appendRow([
        TextCellValue(DateFormat('dd/MM/yyyy').format(DateTime.parse(transaction['date'] as String))),
        TextCellValue(type == 'income' ? 'Thu' : 'Chi'),
        TextCellValue(transaction['category'] as String),
        TextCellValue(transaction['description'] as String),
        DoubleCellValue(amount),
      ]);
    }
    
    // Add summary
    sheet.appendRow([TextCellValue('')]);
    sheet.appendRow([TextCellValue('Tổng thu'), TextCellValue(''), TextCellValue(''), TextCellValue(''), DoubleCellValue(totalIncome)]);
    sheet.appendRow([TextCellValue('Tổng chi'), TextCellValue(''), TextCellValue(''), TextCellValue(''), DoubleCellValue(totalExpense)]);
    sheet.appendRow([TextCellValue('Số dư'), TextCellValue(''), TextCellValue(''), TextCellValue(''), DoubleCellValue(totalIncome - totalExpense)]);
    
    return excel.encode();
  }
  
  /// Save Excel file locally
  static Future<String> _saveExcelBytes(List<int> bytes, String fileName) async {
    // Get Downloads directory
    Directory? directory;
    if (Platform.isWindows) {
      directory = Directory('${Platform.environment['USERPROFILE']}\\Downloads');
    } else if (Platform.isLinux || Platform.isMacOS) {
      directory = Directory('${Platform.environment['HOME']}/Downloads');
    } else {
      directory = await getApplicationDocumentsDirectory();
    }
    
    if (!directory.existsSync()) {
      directory.createSync(recursive: true);
    }
    
    final filePath = '${directory.path}\\$fileName';
    final file = File(filePath);
    await file.writeAsBytes(bytes);
    
    return filePath;
  }
  
  /// Open file explorer at the given path
  static Future<void> openFileLocation(String filePath) async {
    if (Platform.isWindows) {
      await Process.run('explorer.exe', ['/select,', filePath]);
    } else if (Platform.isMacOS) {
      await Process.run('open', ['-R', filePath]);
    } else if (Platform.isLinux) {
      final directory = File(filePath).parent.path;
      await Process.run('xdg-open', [directory]);
    }
  }
}

// DTO for Revenue Export to pass through Isolate
class RevenueExportData {
  final DateTime startDate;
  final DateTime endDate;
  final Map<String, dynamic> stats;
  final List<Map<String, dynamic>> dailyRevenue;
  final List<Map<String, dynamic>> topCustomers;
  final List<Map<String, dynamic>> topServices;

  RevenueExportData({
    required this.startDate,
    required this.endDate,
    required this.stats,
    required this.dailyRevenue,
    required this.topCustomers,
    required this.topServices,
  });
}
