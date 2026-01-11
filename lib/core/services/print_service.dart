import 'dart:typed_data';
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

  Future<Uint8List> generateBarcodeLabel(
    Order order,
    Customer customer,
    String? storeName,
  ) async {
    final pdf = pw.Document();
    
    final font = await PdfGoogleFonts.robotoRegular();
    final fontBold = await PdfGoogleFonts.robotoBold();

    // Create barcode
    final barcodeGenerator = Barcode.code128();
    final barcodeSvg = barcodeGenerator.toSvg(
      order.barcode,
      width: AppConstants.labelWidth * PdfPageFormat.mm,
      height: 25,
    );

    pdf.addPage(
      pw.Page(
        pageFormat: PdfPageFormat(
          AppConstants.labelWidth * PdfPageFormat.mm,
          AppConstants.labelHeight * PdfPageFormat.mm,
        ),
        theme: pw.ThemeData.withFont(
          base: font,
          bold: fontBold,
        ),
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
              
              // Barcode
              pw.Center(
                child: pw.SvgImage(
                  svg: barcodeSvg,
                  width: AppConstants.labelWidth * 0.9 * PdfPageFormat.mm,
                ),
              ),
            ],
          );
        },
      ),
    );

    return pdf.save();
  }

  Future<void> printBarcodeLabel(
    Order order,
    Customer customer,
    String? storeName,
  ) async {
    try {
      final pdfData = await generateBarcodeLabel(order, customer, storeName);
      
      await Printing.layoutPdf(
        onLayout: (format) async => pdfData,
        name: 'Order_${order.orderCode}_Label',
      );
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
    
    final font = await PdfGoogleFonts.robotoRegular();
    final fontBold = await PdfGoogleFonts.robotoBold();
    final fontItalic = await PdfGoogleFonts.robotoItalic();

    pdf.addPage(
      pw.Page(
        pageFormat: pageFormat,
        theme: pw.ThemeData.withFont(
          base: font,
          bold: fontBold,
          italic: fontItalic,
        ),
        margin: pw.EdgeInsets.all(5 * PdfPageFormat.mm),
        build: (context) {
          return pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              // Store header
              pw.Center(
                child: pw.Text(
                  storeName ?? 'LAUNDRY MANAGEMENT',
                  style: pw.TextStyle(
                    fontSize: 16,
                    fontWeight: pw.FontWeight.bold,
                  ),
                ),
              ),
              if (storeAddress != null && storeAddress.isNotEmpty)
                pw.Center(
                  child: pw.Text(
                    storeAddress,
                    style: const pw.TextStyle(fontSize: 10),
                    textAlign: pw.TextAlign.center,
                  ),
                ),
              if (storePhone != null && storePhone.isNotEmpty)
                pw.Center(
                  child: pw.Text(
                    'Hotline: $storePhone',
                    style: const pw.TextStyle(fontSize: 10),
                  ),
                ),
              
              pw.SizedBox(height: 3),
              pw.Divider(),
              
              // Order info
              pw.Text('Mã đơn hàng: ${order.orderCode}'),
              pw.Text('Ngày nhận: ${DateFormat('dd/MM/yyyy HH:mm').format(order.receivedDate)}'),
              if (order.deliveryDate != null)
                pw.Text('Ngày hẹn giao: ${DateFormat('dd/MM/yyyy').format(order.deliveryDate!)}'),
              
              pw.SizedBox(height: 3),
              
              // Customer info
              pw.Text('Khách hàng: ${customer.name}'),
              pw.Text('SĐT: ${customer.phone}'),
              if (customer.address != null && customer.address!.isNotEmpty)
                pw.Text('Địa chỉ: ${customer.address}'),
              
              pw.SizedBox(height: 3),
              pw.Divider(),
              
              // Order items
              pw.Text(
                'Chi tiết dịch vụ:',
                style: pw.TextStyle(fontWeight: pw.FontWeight.bold),
              ),
              pw.SizedBox(height: 2),
              
              ...orderItems.map((item) {
                return pw.Padding(
                  padding: const pw.EdgeInsets.symmetric(vertical: 1),
                  child: pw.Row(
                    mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                    children: [
                      pw.Expanded(
                        child: pw.Text(
                          '${item['service_name']} x${item['quantity']}',
                          style: const pw.TextStyle(fontSize: 10),
                        ),
                      ),
                      pw.Text(
                        NumberFormat.currency(locale: 'vi', symbol: 'đ')
                            .format(item['subtotal']),
                        style: const pw.TextStyle(fontSize: 10),
                      ),
                    ],
                  ),
                );
              }),
              
              pw.Divider(),
              
              // Total
              pw.Row(
                mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                children: [
                  pw.Text(
                    'Tổng cộng:',
                    style: pw.TextStyle(
                      fontSize: 12,
                      fontWeight: pw.FontWeight.bold,
                    ),
                  ),
                  pw.Text(
                    NumberFormat.currency(locale: 'vi', symbol: 'đ')
                        .format(order.totalAmount),
                    style: pw.TextStyle(
                      fontSize: 12,
                      fontWeight: pw.FontWeight.bold,
                    ),
                  ),
                ],
              ),
              
              pw.SizedBox(height: 2),
              
              // Payment info
              pw.Row(
                mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                children: [
                  pw.Text('Đã thanh toán:'),
                  pw.Text(
                    NumberFormat.currency(locale: 'vi', symbol: 'đ')
                        .format(order.paidAmount),
                  ),
                ],
              ),
              
              if (order.remainingAmount > 0)
                pw.Row(
                  mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                  children: [
                    pw.Text('Còn lại:'),
                    pw.Text(
                      NumberFormat.currency(locale: 'vi', symbol: 'đ')
                          .format(order.remainingAmount),
                      style: pw.TextStyle(fontWeight: pw.FontWeight.bold),
                    ),
                  ],
                ),
              
              pw.SizedBox(height: 3),
              pw.Divider(),
              
              // Barcode
              pw.Center(
                child: pw.BarcodeWidget(
                  barcode: Barcode.code128(),
                  data: order.barcode,
                  width: 60 * PdfPageFormat.mm,
                  height: 20 * PdfPageFormat.mm,
                ),
              ),
              
              pw.SizedBox(height: 3),
              
              // Footer
              pw.Center(
                child: pw.Text(
                  footerMessage ?? 'Cảm ơn quý khách!',
                  style: pw.TextStyle(
                    fontSize: 10,
                    fontStyle: pw.FontStyle.italic,
                  ),
                  textAlign: pw.TextAlign.center,
                ),
              ),
              
              pw.Center(
                child: pw.Text(
                  'Nhân viên: $employeeName',
                  style: const pw.TextStyle(fontSize: 8),
                ),
              ),
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
      
      await Printing.layoutPdf(
        onLayout: (format) async => pdfData,
        name: 'Order_${order.orderCode}_Receipt',
      );
    } catch (e) {
      rethrow;
    }
  }
}
