import 'dart:typed_data';
import 'package:flutter/services.dart' show rootBundle;
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:barcode/barcode.dart';
import 'package:printing/printing.dart';
import 'package:intl/intl.dart';
import '../../models/order.dart';
import '../../models/customer.dart';
import '../../config/constants.dart';

class PrintService {
  static final PrintService instance = PrintService._init();
  PrintService._init();

  // Cached fonts to avoid reloading
  pw.Font? _fontRegular;
  pw.Font? _fontBold;
  pw.Font? _fontItalic;

  /// Load bundled NotoSans fonts from assets (works offline on POS)
  Future<({pw.Font regular, pw.Font bold, pw.Font italic})> _loadFonts() async {
    _fontRegular ??= pw.Font.ttf(
      await rootBundle.load('assets/fonts/NotoSans-Regular.ttf'),
    );
    // Variable font: same file supports bold weight
    _fontBold ??= _fontRegular;
    _fontItalic ??= pw.Font.ttf(
      await rootBundle.load('assets/fonts/NotoSans-Italic.ttf'),
    );
    return (regular: _fontRegular!, bold: _fontBold!, italic: _fontItalic!);
  }

  Future<Uint8List> generateBarcodeLabel(
    Order order,
    Customer customer,
    String? storeName,
  ) async {
    final pdf = pw.Document();

    final fonts = await _loadFonts();
    final font = fonts.regular;
    final fontBold = fonts.bold;

    pdf.addPage(
      pw.Page(
        pageFormat: PdfPageFormat(
          AppConstants.labelWidth * PdfPageFormat.mm,
          AppConstants.labelHeight * PdfPageFormat.mm,
        ),
        theme: pw.ThemeData.withFont(base: font, bold: fontBold),
        margin: pw.EdgeInsets.all(2 * PdfPageFormat.mm),
        build: (context) {
          return pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
            children: [
              // Store name
              pw.Text(
                storeName ?? 'LAUNDRY MANAGEMENT',
                style: pw.TextStyle(
                  fontSize: 10,
                  fontWeight: pw.FontWeight.bold,
                ),
              ),

              pw.SizedBox(height: 2),

              // Order code
              pw.Text(
                'Mã ĐH: ${order.orderCode}',
                style: const pw.TextStyle(fontSize: 8),
              ),

              // Customer name
              pw.Text(
                'KH: ${customer.name}',
                style: const pw.TextStyle(fontSize: 7),
                maxLines: 1,
              ),

              // Dates
              pw.Row(
                mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                children: [
                  pw.Text(
                    'Nhận: ${DateFormat('dd/MM/yy').format(order.receivedDate)}',
                    style: const pw.TextStyle(fontSize: 6),
                  ),
                  if (order.deliveryDate != null)
                    pw.Text(
                      'Giao: ${DateFormat('dd/MM/yy').format(order.deliveryDate!)}',
                      style: const pw.TextStyle(fontSize: 6),
                    ),
                ],
              ),

              pw.SizedBox(height: 1),

              // Barcode - dùng BarcodeWidget thay SvgImage cho đáng tin cậy hơn
              pw.Center(
                child: pw.BarcodeWidget(
                  barcode: Barcode.code128(),
                  data: order.barcode,
                  width: AppConstants.labelWidth * 0.9 * PdfPageFormat.mm,
                  height: 12 * PdfPageFormat.mm,
                  drawText: true,
                  textStyle: const pw.TextStyle(fontSize: 6),
                ),
              ),
            ],
          );
        },
      ),
    );

    return pdf.save();
  }

  /// In trực tiếp không hiện dialog - dùng cho POS
  Future<void> _directPrint(Uint8List pdfData, String name) async {
    // Lấy danh sách máy in
    final printers = await Printing.listPrinters();

    if (printers.isEmpty) {
      throw Exception('Không tìm thấy máy in nào!');
    }

    // Tìm máy in mặc định hoặc dùng máy in đầu tiên
    Printer? defaultPrinter;
    for (final printer in printers) {
      if (printer.isDefault) {
        defaultPrinter = printer;
        break;
      }
    }
    defaultPrinter ??= printers.first;

    // In trực tiếp
    await Printing.directPrintPdf(
      printer: defaultPrinter,
      onLayout: (format) async => pdfData,
      name: name,
    );
  }

  Future<void> printBarcodeLabel(
    Order order,
    Customer customer,
    String? storeName,
  ) async {
    try {
      final pdfData = await generateBarcodeLabel(order, customer, storeName);
      await _directPrint(pdfData, 'Order_${order.orderCode}_Label');
    } catch (e) {
      rethrow;
    }
  }

  /// In 2 bill cùng lúc cho POS workflow:
  /// - Bill 1: Hóa đơn cho khách (receipt)
  /// - Bill 2: Nhãn dán đồ (label với barcode)
  Future<void> printDualBills(
    Order order,
    Customer customer,
    List<Map<String, dynamic>> orderItems,
    String? storeName,
    String employeeName, {
    String? storeAddress,
    String? storePhone,
  }) async {
    try {
      // Generate both bills
      final receiptPdf = await generateOrderReceipt(
        order,
        customer,
        orderItems,
        storeName,
        employeeName,
        storeAddress: storeAddress,
        storePhone: storePhone,
        footerMessage: 'Vui lòng giữ phiếu này để nhận đồ!',
      );

      final labelPdf = await generateBarcodeLabel(order, customer, storeName);

      // In trực tiếp không hiện dialog
      // In receipt trước
      await _directPrint(receiptPdf, 'Order_${order.orderCode}_Receipt');

      // In label
      await _directPrint(labelPdf, 'Order_${order.orderCode}_Label');
    } catch (e) {
      rethrow;
    }
  }

  Future<Uint8List> generateOrderReceipt(
    Order order,
    Customer customer,
    List<Map<String, dynamic>> orderItems,
    String? storeName,
    String employeeName, {
    String? storeAddress,
    String? storePhone,
    String? footerMessage,
    PdfPageFormat pageFormat = PdfPageFormat.roll80,
  }) async {
    final pdf = pw.Document();

    final fonts = await _loadFonts();
    final font = fonts.regular;
    final fontBold = fonts.bold;
    final fontItalic = fonts.italic;

    pdf.addPage(
      pw.Page(
        pageFormat: pageFormat,
        theme: pw.ThemeData.withFont(
          base: font,
          bold: fontBold,
          italic: fontItalic,
        ),
        // Tăng margin phải lên 8mm để tránh bị mất chữ ở mép phải (do máy in lệch)
        margin: const pw.EdgeInsets.only(
          left: 4 * PdfPageFormat.mm,
          right: 8 * PdfPageFormat.mm,
        ),
        build: (context) {
          final smallStyle = const pw.TextStyle(fontSize: 8);
          final mediumStyle = pw.TextStyle(
            fontSize: 9,
            fontWeight: pw.FontWeight.bold,
          );
          final titleStyle = pw.TextStyle(
            fontSize: 12,
            fontWeight: pw.FontWeight.bold,
          );

          return pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              pw.SizedBox(height: 5),
              // Store header
              pw.Center(
                child: pw.Text(
                  storeName ?? 'LAUNDRY STORE',
                  style: titleStyle,
                  textAlign: pw.TextAlign.center,
                ),
              ),
              if (storeAddress != null && storeAddress.isNotEmpty)
                pw.Center(
                  child: pw.Text(
                    storeAddress,
                    style: const pw.TextStyle(fontSize: 7),
                    textAlign: pw.TextAlign.center,
                  ),
                ),
              if (storePhone != null && storePhone.isNotEmpty)
                pw.Center(
                  child: pw.Text(
                    'Hotline: $storePhone',
                    style: const pw.TextStyle(fontSize: 7),
                  ),
                ),

              pw.SizedBox(height: 2),
              pw.Divider(thickness: 0.5),
              pw.SizedBox(height: 2),

              // Order info
              pw.Row(
                mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                children: [
                  pw.Text('Mã đơn: ${order.orderCode}', style: mediumStyle),
                  pw.Text(
                    DateFormat('dd/MM HH:mm').format(order.receivedDate),
                    style: smallStyle,
                  ),
                ],
              ),

              if (order.deliveryDate != null)
                pw.Text(
                  'Hẹn giao: ${DateFormat('dd/MM/yyyy HH:mm').format(order.deliveryDate!)}',
                  style: smallStyle,
                ),

              pw.SizedBox(height: 2),

              // Customer info
              pw.Text('KH: ${customer.name}', style: mediumStyle),
              pw.Text('SĐT: ${customer.phone}', style: smallStyle),
              if (customer.address != null && customer.address!.isNotEmpty)
                pw.Text(
                  'ĐC: ${customer.address}',
                  style: const pw.TextStyle(fontSize: 7),
                  maxLines: 2,
                ),

              pw.SizedBox(height: 2),
              pw.Divider(thickness: 0.5),

              // Order items
              ...orderItems.map((item) {
                return pw.Padding(
                  padding: const pw.EdgeInsets.symmetric(vertical: 1),
                  child: pw.Row(
                    children: [
                      pw.Expanded(
                        child: pw.Text(
                          '${item['service_name']}',
                          style: smallStyle,
                        ),
                      ),
                      pw.Container(
                        width: 20,
                        alignment: pw.Alignment.center,
                        child: pw.Text(
                          'x${item['quantity']}',
                          style: smallStyle,
                        ),
                      ),
                      pw.Container(
                        width: 50,
                        alignment: pw.Alignment.centerRight,
                        child: pw.Text(
                          NumberFormat.currency(
                            locale: 'vi',
                            symbol: '',
                          ).format(item['subtotal']),
                          style: smallStyle,
                        ),
                      ),
                    ],
                  ),
                );
              }),

              pw.Divider(thickness: 0.5),

              // Total & Payment
              pw.Row(
                mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                children: [
                  pw.Text('TỔNG CỘNG:', style: mediumStyle),
                  pw.Text(
                    NumberFormat.currency(
                      locale: 'vi',
                      symbol: 'đ',
                    ).format(order.totalAmount),
                    style: pw.TextStyle(
                      fontSize: 11,
                      fontWeight: pw.FontWeight.bold,
                    ), // Giảm font size một chút và viết hoa
                  ),
                ],
              ),

              pw.SizedBox(height: 2),

              // Luôn hiển thị thanh toán và còn lại
              pw.Row(
                mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                children: [
                  pw.Text('Đã thanh toán:', style: smallStyle),
                  pw.Text(
                    NumberFormat.currency(
                      locale: 'vi',
                      symbol: 'đ',
                    ).format(order.paidAmount),
                    style: smallStyle,
                  ),
                ],
              ),

              pw.Row(
                mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                children: [
                  pw.Text('CÒN LẠI:', style: mediumStyle),
                  pw.Text(
                    NumberFormat.currency(
                      locale: 'vi',
                      symbol: 'đ',
                    ).format(order.remainingAmount),
                    style: mediumStyle,
                  ),
                ],
              ),

              pw.SizedBox(height: 4),
              // Barcode
              pw.Center(
                child: pw.BarcodeWidget(
                  barcode: Barcode.code128(),
                  data: order.barcode,
                  width: 50 * PdfPageFormat.mm,
                  height: 15 * PdfPageFormat.mm,
                  drawText: true,
                  textStyle: const pw.TextStyle(fontSize: 7),
                ),
              ),

              if (footerMessage != null) ...[
                pw.SizedBox(height: 2),
                pw.Center(
                  child: pw.Text(
                    footerMessage,
                    style: const pw.TextStyle(fontSize: 7),
                    textAlign: pw.TextAlign.center,
                  ),
                ),
              ],
              pw.Text(
                '.',
                style: const pw.TextStyle(fontSize: 1, color: PdfColors.white),
              ), // Spacer for cutter
            ],
          );
        },
      ),
    );

    return pdf.save();
  }

  Future<void> printOrderReceipt(
    Order order,
    Customer customer,
    List<Map<String, dynamic>> orderItems,
    String? storeName,
    String employeeName, {
    String? storeAddress,
    String? storePhone,
    String? footerMessage,
    PdfPageFormat pageFormat = PdfPageFormat.roll80,
  }) async {
    try {
      final pdfData = await generateOrderReceipt(
        order,
        customer,
        orderItems,
        storeName,
        employeeName,
        storeAddress: storeAddress,
        storePhone: storePhone,
        footerMessage: footerMessage,
        pageFormat: pageFormat,
      );

      await _directPrint(pdfData, 'Order_${order.orderCode}_Receipt');
    } catch (e) {
      rethrow;
    }
  }

  /// In báo cáo doanh thu ca làm việc
  Future<void> printShiftReport({
    required DateTime date,
    required String employeeName,
    required double cashTotal,
    required double transferTotal,
    required double eWalletTotal,
    required double grandTotal,
    required int orderCount,
    required double unpaidTotal,
    required List<Map<String, dynamic>> orders,
    bool isAllEmployees = false,
  }) async {
    final pdf = pw.Document();

    final fonts = await _loadFonts();
    final font = fonts.regular;
    final fontBold = fonts.bold;

    final currencyFormat = NumberFormat.currency(locale: 'vi', symbol: 'đ');

    pdf.addPage(
      pw.Page(
        pageFormat: PdfPageFormat.roll80,
        theme: pw.ThemeData.withFont(base: font, bold: fontBold),
        margin: const pw.EdgeInsets.only(
          left: 4 * PdfPageFormat.mm,
          right: 8 * PdfPageFormat.mm,
        ),
        build: (context) {
          final smallStyle = const pw.TextStyle(fontSize: 8);
          final mediumStyle = pw.TextStyle(
            fontSize: 9,
            fontWeight: pw.FontWeight.bold,
          );
          final titleStyle = pw.TextStyle(
            fontSize: 11,
            fontWeight: pw.FontWeight.bold,
          );

          return pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              pw.SizedBox(height: 5),

              // Title
              pw.Center(
                child: pw.Text('BÁO CÁO DOANH THU CA', style: titleStyle),
              ),
              pw.SizedBox(height: 3),
              pw.Center(
                child: pw.Text(
                  'Ngày: ${DateFormat('dd/MM/yyyy').format(date)}',
                  style: smallStyle,
                ),
              ),
              pw.Center(
                child: pw.Text(
                  isAllEmployees ? 'Tất cả nhân viên' : 'NV: $employeeName',
                  style: mediumStyle,
                ),
              ),

              pw.SizedBox(height: 4),
              pw.Divider(thickness: 0.5),
              pw.SizedBox(height: 2),

              // Payment breakdown
              _buildReportRow(
                'Tiền mặt:',
                currencyFormat.format(cashTotal),
                smallStyle,
              ),
              _buildReportRow(
                'Chuyển khoản:',
                currencyFormat.format(transferTotal),
                smallStyle,
              ),
              _buildReportRow(
                'Ví điện tử:',
                currencyFormat.format(eWalletTotal),
                smallStyle,
              ),

              pw.SizedBox(height: 2),
              pw.Divider(thickness: 0.5),

              _buildReportRow(
                'TỔNG THU:',
                currencyFormat.format(grandTotal),
                mediumStyle,
              ),
              _buildReportRow('Số đơn:', '$orderCount', smallStyle),
              if (unpaidTotal > 0)
                _buildReportRow(
                  'Chưa thu:',
                  currencyFormat.format(unpaidTotal),
                  smallStyle,
                ),

              pw.SizedBox(height: 4),
              pw.Divider(thickness: 0.5),
              pw.SizedBox(height: 2),

              // Order list
              pw.Text('CHI TIẾT ĐƠN HÀNG:', style: mediumStyle),
              pw.SizedBox(height: 2),
              ...orders.map((order) {
                final paymentLabel =
                    AppConstants.paymentMethodLabels[order['payment_method']
                        as String?] ??
                    'Chưa TT';
                return pw.Padding(
                  padding: const pw.EdgeInsets.symmetric(vertical: 1),
                  child: pw.Row(
                    children: [
                      pw.Expanded(
                        flex: 2,
                        child: pw.Text(
                          '${order['order_code']}',
                          style: smallStyle,
                        ),
                      ),
                      pw.Expanded(
                        flex: 2,
                        child: pw.Text(
                          '${order['customer_name']}',
                          style: smallStyle,
                        ),
                      ),
                      pw.Container(
                        width: 30,
                        child: pw.Text(paymentLabel, style: smallStyle),
                      ),
                      pw.Container(
                        width: 45,
                        alignment: pw.Alignment.centerRight,
                        child: pw.Text(
                          currencyFormat.format(
                            (order['paid_amount'] as num).toDouble(),
                          ),
                          style: smallStyle,
                        ),
                      ),
                    ],
                  ),
                );
              }),

              pw.SizedBox(height: 4),
              pw.Divider(thickness: 0.5),
              pw.SizedBox(height: 2),

              // Signature line
              pw.Center(
                child: pw.Text(
                  'In lúc: ${DateFormat('HH:mm dd/MM/yyyy').format(DateTime.now())}',
                  style: const pw.TextStyle(fontSize: 7),
                ),
              ),
              pw.SizedBox(height: 8),
              pw.Row(
                mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                children: [
                  pw.Column(
                    children: [
                      pw.Text('Nhân viên', style: smallStyle),
                      pw.SizedBox(height: 20),
                      pw.Text(employeeName, style: smallStyle),
                    ],
                  ),
                  pw.Column(
                    children: [
                      pw.Text('Quản lý', style: smallStyle),
                      pw.SizedBox(height: 20),
                      pw.Text('...............', style: smallStyle),
                    ],
                  ),
                ],
              ),
              pw.Text(
                '.',
                style: const pw.TextStyle(fontSize: 1, color: PdfColors.white),
              ),
            ],
          );
        },
      ),
    );

    final pdfData = await pdf.save();
    await Printing.layoutPdf(
      onLayout: (format) async => pdfData,
      name: 'ShiftReport_${DateFormat('yyyyMMdd').format(date)}',
    );
  }

  pw.Widget _buildReportRow(String label, String value, pw.TextStyle style) {
    return pw.Padding(
      padding: const pw.EdgeInsets.symmetric(vertical: 1),
      child: pw.Row(
        mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
        children: [
          pw.Text(label, style: style),
          pw.Text(value, style: style),
        ],
      ),
    );
  }
}
