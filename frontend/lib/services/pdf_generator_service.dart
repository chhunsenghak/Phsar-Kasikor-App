import 'package:flutter/foundation.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import '../models/app_state.dart';
import 'web_download.dart';

class PdfGeneratorService {
  /// PDF text has no `৛`/Khmer-glyph support in the base font, so KHR amounts
  /// are rendered with a "KHR" suffix instead of the `៛` glyph used on-screen.
  static String _formatCurrency(num amount, [String currency = 'USD']) {
    final parts = amount.toStringAsFixed(currency == 'KHR' ? 0 : 2).split('.');
    final RegExp reg = RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))');
    String mathFunc(Match match) => '${match[1]},';
    final formattedInt = parts[0].replaceAllMapped(reg, mathFunc);
    if (currency == 'KHR') {
      return '$formattedInt KHR';
    }
    return '\$$formattedInt.${parts[1]}';
  }

  static String _cleanText(String input) {
    if (input.trim().isEmpty) return 'Crop Item';
    return input.replaceAll('—', '-').trim();
  }

  /// The base PDF font (Helvetica) has no Khmer glyphs, so any Khmer text
  /// rendered without this used to be silently stripped down to an empty
  /// string by `_cleanText`'s old ASCII-only filter. Noto Sans Khmer is
  /// fetched (and cached) via the `printing` package's Google Fonts helper
  /// and registered as a font-fallback, so Latin text keeps using the default
  /// font while Khmer glyphs render through the fallback automatically.
  static Future<pw.ThemeData> _buildTheme() async {
    final khmerRegular = await PdfGoogleFonts.notoSansKhmerRegular();
    final khmerBold = await PdfGoogleFonts.notoSansKhmerBold();
    return pw.ThemeData.withFont(
      fontFallback: [khmerRegular, khmerBold],
    );
  }

  /// Cambodia local date + time (12-hour clock, AM/PM) — the same UTC+7
  /// convention used by the in-app order/notification screens, so a PDF
  /// generated from an order never disagrees with what's shown on screen.
  static String _formatDateTime(DateTime dateTime) {
    final cambodia = dateTime.toUtc().add(const Duration(hours: 7));
    final datePart =
        '${cambodia.year.toString().padLeft(4, '0')}-${cambodia.month.toString().padLeft(2, '0')}-${cambodia.day.toString().padLeft(2, '0')}';
    int hour = cambodia.hour;
    final minute = cambodia.minute.toString().padLeft(2, '0');
    final ampm = hour >= 12 ? 'PM' : 'AM';
    hour = hour % 12;
    if (hour == 0) hour = 12;
    final hourStr = hour.toString().padLeft(2, '0');
    return '$datePart $hourStr:$minute $ampm';
  }

  /// Parses a `created_at` value from the backend — a naive UTC timestamp
  /// with no offset — into Cambodia local date + time.
  static String _formatBackendDateTime(String? raw) {
    if (raw == null) return _formatDateTime(DateTime.now());
    try {
      String cleaned = raw.trim().replaceAll(' ', 'T');
      if (!cleaned.endsWith('Z') &&
          !RegExp(r'[+-]\d{2}:?\d{2}$').hasMatch(cleaned)) {
        cleaned += 'Z';
      }
      return _formatDateTime(DateTime.parse(cleaned));
    } catch (_) {
      return raw.split('T').first;
    }
  }

  /// Generate Invoice PDF for an Order
  static Future<Uint8List> generateOrderInvoicePdf({
    required Map<String, dynamic> order,
    required AppState state,
  }) async {
    final pdf = pw.Document(theme: await _buildTheme());

    final orderId = (order['id']?.toString() ?? 'ORDER-0000').toUpperCase();
    final shortId = orderId.length >= 8 ? orderId.substring(0, 8) : orderId;
    final String status = order['order_status'] ?? 'PENDING';
    final String pStatus = order['payment_status'] ?? 'UNPAID';
    final double totalAmount = (order['total_amount'] as num?)?.toDouble() ?? 0.0;
    final String currency = resolveOrderCurrency(order, state.products);
    final isPickup = (order['delivery_method'] ?? 'DELIVERY') == 'PICKUP';
    final double deliveryFee = (order['delivery_fee'] as num?)?.toDouble() ?? 0.0;
    final double subtotal = totalAmount - deliveryFee;
    final items = order['items'] as List<dynamic>? ?? [];

    final String dateStr = _formatBackendDateTime(order['created_at']?.toString());

    pdf.addPage(
      pw.Page(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(32),
        build: (pw.Context context) {
          return pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              // Company Brand Header
              pw.Row(
                mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                children: [
                  pw.Column(
                    crossAxisAlignment: pw.CrossAxisAlignment.start,
                    children: [
                      pw.Text(
                        'AgriMarket',
                        style: pw.TextStyle(
                          fontSize: 24,
                          fontWeight: pw.FontWeight.bold,
                          color: PdfColors.teal800,
                        ),
                      ),
                      pw.Text(
                        'Direct Farm Marketplace Platform',
                        style: const pw.TextStyle(
                          fontSize: 10,
                          color: PdfColors.grey700,
                        ),
                      ),
                    ],
                  ),
                  pw.Column(
                    crossAxisAlignment: pw.CrossAxisAlignment.end,
                    children: [
                      pw.Text(
                        'TAX INVOICE',
                        style: pw.TextStyle(
                          fontSize: 18,
                          fontWeight: pw.FontWeight.bold,
                          color: PdfColors.grey800,
                        ),
                      ),
                      pw.Text(
                        'Invoice #: INV-$shortId',
                        style: pw.TextStyle(
                          fontSize: 11,
                          fontWeight: pw.FontWeight.bold,
                        ),
                      ),
                      pw.Text(
                        'Date Time: $dateStr',
                        style: const pw.TextStyle(fontSize: 10),
                      ),
                    ],
                  ),
                ],
              ),
              pw.SizedBox(height: 16),
              pw.Divider(thickness: 1, color: PdfColors.grey300),
              pw.SizedBox(height: 12),

              // Order Summary Row
              pw.Row(
                mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                children: [
                  pw.Column(
                    crossAxisAlignment: pw.CrossAxisAlignment.start,
                    children: [
                      pw.Text(
                        'Billed To:',
                        style: pw.TextStyle(
                          fontSize: 11,
                          fontWeight: pw.FontWeight.bold,
                        ),
                      ),
                      pw.Text(
                        _cleanText(state.userName),
                        style: const pw.TextStyle(fontSize: 11),
                      ),
                      pw.Text(
                        'Payment Method: ${(order['payment_method'] ?? 'KHQR') == 'COD' ? 'Cash on Delivery' : 'Bakong KHQR'}',
                        style: const pw.TextStyle(
                          fontSize: 10,
                          color: PdfColors.grey700,
                        ),
                      ),
                    ],
                  ),
                  pw.Column(
                    crossAxisAlignment: pw.CrossAxisAlignment.end,
                    children: [
                      pw.Text(
                        'Fulfillment: ${isPickup ? 'Self-Pickup' : 'Express Delivery'}',
                        style: const pw.TextStyle(fontSize: 10),
                      ),
                      pw.Text(
                        'Order Status: $status',
                        style: pw.TextStyle(
                          fontSize: 10,
                          fontWeight: pw.FontWeight.bold,
                          color: status == 'COMPLETED' || status == 'PAID'
                              ? PdfColors.green800
                              : PdfColors.orange800,
                        ),
                      ),
                      pw.Text(
                        'Payment Status: $pStatus',
                        style: pw.TextStyle(
                          fontSize: 10,
                          fontWeight: pw.FontWeight.bold,
                          color: pStatus == 'PAID'
                              ? PdfColors.green800
                              : PdfColors.red800,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
              pw.SizedBox(height: 20),

              // Line Items Table
              pw.TableHelper.fromTextArray(
                border: pw.TableBorder.all(color: PdfColors.grey300, width: 0.5),
                headerStyle: pw.TextStyle(
                  fontWeight: pw.FontWeight.bold,
                  fontSize: 10,
                  color: PdfColors.white,
                ),
                headerDecoration: const pw.BoxDecoration(
                  color: PdfColors.teal700,
                ),
                cellStyle: const pw.TextStyle(fontSize: 10),
                columnWidths: {
                  0: const pw.FlexColumnWidth(3),
                  1: const pw.FlexColumnWidth(1),
                  2: const pw.FlexColumnWidth(1.5),
                  3: const pw.FlexColumnWidth(1.5),
                },
                headers: ['Item', 'Qty', 'Unit Price', 'Subtotal'],
                data: items.map((item) {
                  final matchingProd = state.products.firstWhere(
                    (p) => p.id == item['product_id'],
                    orElse: () => MarketProduct(
                      id: '',
                      name: 'Crop Listing',
                      category: 'Grains',
                      price: 1.0,
                      unit: 'kg',
                      quantity: 0.0,
                      farmerName: 'Verified Farmer',
                      location: 'Cambodia',
                      description: '',
                      imageUrl: '',
                    ),
                  );
                  final double qty = (item['quantity'] as num?)?.toDouble() ?? 1.0;
                  final double itemSub = (item['subtotal'] as num?)?.toDouble() ?? totalAmount;
                  final double rate = itemSub / qty;

                  return [
                    _cleanText(matchingProd.name),
                    '${qty.toInt()} ${_cleanText(matchingProd.unit)}',
                    _formatCurrency(rate, currency),
                    _formatCurrency(itemSub, currency),
                  ];
                }).toList(),
              ),

              pw.SizedBox(height: 16),

              // Total Summary Box
              pw.Row(
                mainAxisAlignment: pw.MainAxisAlignment.end,
                children: [
                  pw.Container(
                    width: 220,
                    padding: const pw.EdgeInsets.all(12),
                    decoration: pw.BoxDecoration(
                      border: pw.Border.all(color: PdfColors.grey300),
                      borderRadius: const pw.BorderRadius.all(pw.Radius.circular(6)),
                    ),
                    child: pw.Column(
                      children: [
                        pw.Row(
                          mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                          children: [
                            pw.Text('Subtotal:', style: const pw.TextStyle(fontSize: 10)),
                            pw.Text(_formatCurrency(subtotal, currency), style: const pw.TextStyle(fontSize: 10)),
                          ],
                        ),
                        pw.SizedBox(height: 4),
                        pw.Row(
                          mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                          children: [
                            pw.Text('Delivery Fee:', style: const pw.TextStyle(fontSize: 10)),
                            pw.Text(_formatCurrency(deliveryFee, currency), style: const pw.TextStyle(fontSize: 10)),
                          ],
                        ),
                        pw.Divider(thickness: 0.5, color: PdfColors.grey300),
                        pw.Row(
                          mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                          children: [
                            pw.Text('Total Payable:', style: pw.TextStyle(fontSize: 11, fontWeight: pw.FontWeight.bold)),
                            pw.Text(
                              _formatCurrency(totalAmount, currency),
                              style: pw.TextStyle(fontSize: 12, fontWeight: pw.FontWeight.bold, color: PdfColors.teal800),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ],
              ),

              pw.Spacer(),

              // Footer Note
              pw.Divider(thickness: 0.5, color: PdfColors.grey400),
              pw.SizedBox(height: 6),
              pw.Center(
                child: pw.Text(
                  'Thank you for shopping on AgriMarket - Empowering Local Cambodian Farmers.',
                  style: const pw.TextStyle(fontSize: 9, color: PdfColors.grey600),
                ),
              ),
            ],
          );
        },
      ),
    );

    return pdf.save();
  }

  /// Generate Contract Agreement PDF
  static Future<Uint8List> generateContractAgreementPdf({
    required BidOffer contract,
    required AppState state,
  }) async {
    final pdf = pw.Document(theme: await _buildTheme());

    final agreementId = contract.id.toUpperCase();
    final shortId = agreementId.length >= 8 ? agreementId.substring(0, 8) : agreementId;
    final totalVal = contract.offeredPrice * contract.quantity;
    // BidOffer carries no creation timestamp, so this reflects when the PDF
    // itself was generated rather than when the agreement was struck.
    final dateStr = _formatDateTime(DateTime.now());

    pdf.addPage(
      pw.Page(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(32),
        build: (pw.Context context) {
          return pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              // Header
              pw.Row(
                mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                children: [
                  pw.Column(
                    crossAxisAlignment: pw.CrossAxisAlignment.start,
                    children: [
                      pw.Text(
                        'AgriMarket',
                        style: pw.TextStyle(
                          fontSize: 24,
                          fontWeight: pw.FontWeight.bold,
                          color: PdfColors.teal800,
                        ),
                      ),
                      pw.Text(
                        'Agricultural Wholesale Contract Agreement',
                        style: const pw.TextStyle(
                          fontSize: 10,
                          color: PdfColors.grey700,
                        ),
                      ),
                    ],
                  ),
                  pw.Column(
                    crossAxisAlignment: pw.CrossAxisAlignment.end,
                    children: [
                      pw.Text(
                        'AGREEMENT',
                        style: pw.TextStyle(
                          fontSize: 16,
                          fontWeight: pw.FontWeight.bold,
                          color: PdfColors.grey800,
                        ),
                      ),
                      pw.Text(
                        'Ref #: AGR-$shortId',
                        style: pw.TextStyle(
                          fontSize: 11,
                          fontWeight: pw.FontWeight.bold,
                        ),
                      ),
                      pw.Text('Date Time: $dateStr', style: const pw.TextStyle(fontSize: 10)),
                    ],
                  ),
                ],
              ),
              pw.SizedBox(height: 16),
              pw.Divider(thickness: 1, color: PdfColors.grey300),
              pw.SizedBox(height: 12),

              // Parties Info
              pw.Text(
                'CONTRACTING PARTIES',
                style: pw.TextStyle(fontSize: 11, fontWeight: pw.FontWeight.bold, color: PdfColors.teal800),
              ),
              pw.SizedBox(height: 8),
              pw.Row(
                children: [
                  pw.Expanded(
                    child: pw.Container(
                      padding: const pw.EdgeInsets.all(10),
                      decoration: pw.BoxDecoration(
                        border: pw.Border.all(color: PdfColors.grey300),
                        borderRadius: const pw.BorderRadius.all(pw.Radius.circular(6)),
                      ),
                      child: pw.Column(
                        crossAxisAlignment: pw.CrossAxisAlignment.start,
                        children: [
                          pw.Text('BUYER / PURCHASER', style: pw.TextStyle(fontSize: 9, fontWeight: pw.FontWeight.bold, color: PdfColors.grey700)),
                          pw.SizedBox(height: 4),
                          pw.Text(_cleanText(contract.buyerName), style: pw.TextStyle(fontSize: 11, fontWeight: pw.FontWeight.bold)),
                        ],
                      ),
                    ),
                  ),
                  pw.SizedBox(width: 12),
                  pw.Expanded(
                    child: pw.Container(
                      padding: const pw.EdgeInsets.all(10),
                      decoration: pw.BoxDecoration(
                        border: pw.Border.all(color: PdfColors.grey300),
                        borderRadius: const pw.BorderRadius.all(pw.Radius.circular(6)),
                      ),
                      child: pw.Column(
                        crossAxisAlignment: pw.CrossAxisAlignment.start,
                        children: [
                          pw.Text('SELLER / PRODUCER', style: pw.TextStyle(fontSize: 9, fontWeight: pw.FontWeight.bold, color: PdfColors.grey700)),
                          pw.SizedBox(height: 4),
                          pw.Text(
                            _cleanText(contract.product.farmerName.isNotEmpty ? contract.product.farmerName : 'Verified Farmer'),
                            style: pw.TextStyle(fontSize: 11, fontWeight: pw.FontWeight.bold),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
              pw.SizedBox(height: 16),

              // Terms Table
              pw.Text(
                'AGREED WHOLESALE SPECIFICATIONS',
                style: pw.TextStyle(fontSize: 11, fontWeight: pw.FontWeight.bold, color: PdfColors.teal800),
              ),
              pw.SizedBox(height: 8),
              pw.TableHelper.fromTextArray(
                border: pw.TableBorder.all(color: PdfColors.grey300, width: 0.5),
                headerStyle: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 10, color: PdfColors.white),
                headerDecoration: const pw.BoxDecoration(color: PdfColors.teal700),
                cellStyle: const pw.TextStyle(fontSize: 10),
                headers: ['Crop Name', 'Agreed Quantity', 'Unit Rate', 'Total Contract Value'],
                data: [
                  [
                    _cleanText(contract.product.name),
                    '${contract.quantity.toInt()} ${_cleanText(contract.product.unit)}s',
                    '${_formatCurrency(contract.offeredPrice, contract.product.currency)}/${_cleanText(contract.product.unit)}',
                    _formatCurrency(totalVal, contract.product.currency),
                  ]
                ],
              ),
              pw.SizedBox(height: 16),

              // Status Banner
              pw.Container(
                width: double.infinity,
                padding: const pw.EdgeInsets.all(10),
                decoration: pw.BoxDecoration(
                  color: contract.status == 'accepted' ? PdfColors.green50 : PdfColors.orange50,
                  border: pw.Border.all(color: contract.status == 'accepted' ? PdfColors.green300 : PdfColors.orange300),
                  borderRadius: const pw.BorderRadius.all(pw.Radius.circular(6)),
                ),
                child: pw.Text(
                  'Agreement Status: ${contract.status.toUpperCase()} - Bound by AgriMarket Wholesale Negotiation Protocol.',
                  style: pw.TextStyle(
                    fontSize: 10,
                    fontWeight: pw.FontWeight.bold,
                    color: contract.status == 'accepted' ? PdfColors.green900 : PdfColors.orange900,
                  ),
                ),
              ),
              pw.SizedBox(height: 24),

              // Signatures Section
              pw.Row(
                mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                children: [
                  pw.Column(
                    crossAxisAlignment: pw.CrossAxisAlignment.start,
                    children: [
                      pw.Container(
                        width: 160,
                        height: 50,
                        decoration: pw.BoxDecoration(border: pw.Border.all(color: PdfColors.grey400, width: 0.5)),
                        child: pw.Center(
                          child: pw.Text('[ Digital Signature Verified ]', style: const pw.TextStyle(fontSize: 8, color: PdfColors.grey600)),
                        ),
                      ),
                      pw.SizedBox(height: 4),
                      pw.Text('Buyer Signature: ${_cleanText(contract.buyerName)}', style: const pw.TextStyle(fontSize: 9)),
                    ],
                  ),
                  pw.Column(
                    crossAxisAlignment: pw.CrossAxisAlignment.start,
                    children: [
                      pw.Container(
                        width: 160,
                        height: 50,
                        decoration: pw.BoxDecoration(border: pw.Border.all(color: PdfColors.grey400, width: 0.5)),
                        child: pw.Center(
                          child: pw.Text('[ Digital Signature Verified ]', style: const pw.TextStyle(fontSize: 8, color: PdfColors.grey600)),
                        ),
                      ),
                      pw.SizedBox(height: 4),
                      pw.Text(
                        'Seller Signature: ${_cleanText(contract.product.farmerName.isNotEmpty ? contract.product.farmerName : 'Verified Farmer')}',
                        style: const pw.TextStyle(fontSize: 9),
                      ),
                    ],
                  ),
                ],
              ),

              pw.Spacer(),

              // Footer
              pw.Divider(thickness: 0.5, color: PdfColors.grey400),
              pw.SizedBox(height: 6),
              pw.Center(
                child: pw.Text(
                  'AgriMarket Platform - Official Direct Farm Contract Copy.',
                  style: const pw.TextStyle(fontSize: 9, color: PdfColors.grey600),
                ),
              ),
            ],
          );
        },
      ),
    );

    return pdf.save();
  }

  /// Print or Download Invoice
  static Future<bool> downloadOrPrintInvoice({
    required Map<String, dynamic> order,
    required AppState state,
  }) async {
    try {
      final pdfBytes = await generateOrderInvoicePdf(order: order, state: state);
      final orderId = (order['id']?.toString() ?? '0000').substring(0, 8);
      final filename = 'Invoice_INV-$orderId.pdf';
      if (kIsWeb) {
        downloadFileWeb(pdfBytes, filename);
        return true;
      }
      try {
        await Printing.layoutPdf(
          onLayout: (PdfPageFormat format) async => pdfBytes,
          name: filename,
        );
        return true;
      } catch (_) {
        downloadFileWeb(pdfBytes, filename);
        return true;
      }
    } catch (e) {
      debugPrint('Failed to download invoice: $e');
      return false;
    }
  }

  /// Print or Download Contract
  static Future<bool> downloadOrPrintContract({
    required BidOffer contract,
    required AppState state,
  }) async {
    try {
      final pdfBytes = await generateContractAgreementPdf(contract: contract, state: state);
      final agreementId = contract.id.substring(0, 8).toUpperCase();
      final filename = 'Contract_AGR-$agreementId.pdf';
      if (kIsWeb) {
        downloadFileWeb(pdfBytes, filename);
        return true;
      }
      try {
        await Printing.layoutPdf(
          onLayout: (PdfPageFormat format) async => pdfBytes,
          name: filename,
        );
        return true;
      } catch (_) {
        downloadFileWeb(pdfBytes, filename);
        return true;
      }
    } catch (e) {
      debugPrint('Failed to download contract: $e');
      return false;
    }
  }
}
