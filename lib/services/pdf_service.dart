import 'dart:io';
import 'package:flutter/services.dart';
import 'package:path_provider/path_provider.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import 'package:intl/intl.dart';
import '../models/student.dart';
import '../models/fee_payment.dart';
import '../models/attendance.dart';
import '../models/centre_profile.dart';
import '../database/db_helper.dart';
import '../constants/app_constants.dart';

class PdfService {
  static final PdfColor brandBlue = PdfColor.fromInt(0xFF0056D2);
  static final PdfColor brandYellow = PdfColor.fromInt(0xFFFFB800);
  static final PdfColor darkBlue = PdfColor.fromInt(0xFF003B95);
  static final PdfColor grayText = PdfColor.fromInt(0xFF64748B);
  static final PdfColor lightBg = PdfColor.fromInt(0xFFF8FAFC);
  static final PdfColor borderColor = PdfColor.fromInt(0xFFE2E8F0);

  /// Load logo as MemoryImage
  static Future<pw.MemoryImage?> _loadLogo() async {
    try {
      final bytes = await rootBundle.load('assets/images/logo.png');
      return pw.MemoryImage(bytes.buffer.asUint8List());
    } catch (_) {
      return null;
    }
  }

  // ==========================================
  // 1. PROFESSIONAL FEE PAYMENT RECEIPT PDF
  // ==========================================
  static Future<Uint8List> generateFeeReceipt({
    required FeePayment payment,
    required Student student,
    required double totalBalanceDue,
  }) async {
    final pdf = pw.Document();
    final logoImage = await _loadLogo();
    final profile = await DBHelper.instance.getCentreProfile();
    final currencyFormat = NumberFormat.currency(locale: 'en_IN', symbol: 'Rs. ');

    pdf.addPage(
      pw.Page(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(32),
        build: (pw.Context context) {
          return pw.Container(
            padding: const pw.EdgeInsets.all(24),
            decoration: pw.BoxDecoration(
              border: pw.Border.all(color: brandBlue, width: 2),
              borderRadius: pw.BorderRadius.circular(12),
            ),
            child: pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                // Top Header with Logo & Centre Details
                pw.Row(
                  crossAxisAlignment: pw.CrossAxisAlignment.center,
                  children: [
                    if (logoImage != null)
                      pw.Container(
                        width: 75,
                        height: 75,
                        margin: const pw.EdgeInsets.only(right: 16),
                        child: pw.Image(logoImage),
                      ),
                    pw.Expanded(
                      child: pw.Column(
                        crossAxisAlignment: pw.CrossAxisAlignment.start,
                        children: [
                          pw.Text(
                            profile.centreName.toUpperCase(),
                            style: pw.TextStyle(
                              fontSize: 20,
                              fontWeight: pw.FontWeight.bold,
                              color: brandBlue,
                            ),
                          ),
                          pw.SizedBox(height: 3),
                          pw.Text(
                            profile.tagline,
                            style: pw.TextStyle(
                              fontSize: 10,
                              fontStyle: pw.FontStyle.italic,
                              color: brandYellow,
                            ),
                          ),
                          pw.SizedBox(height: 4),
                          pw.Text(
                            '${profile.address} | Phone: ${profile.phone}',
                            style: pw.TextStyle(fontSize: 9, color: grayText),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),

                pw.SizedBox(height: 12),
                pw.Divider(color: brandBlue, thickness: 1.5),
                pw.SizedBox(height: 8),

                // Receipt Badge & Date
                pw.Row(
                  mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                  children: [
                    pw.Container(
                      padding: const pw.EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                      decoration: pw.BoxDecoration(
                        color: brandBlue,
                        borderRadius: pw.BorderRadius.circular(6),
                      ),
                      child: pw.Text(
                        'FEE PAYMENT RECEIPT',
                        style: pw.TextStyle(
                          color: PdfColors.white,
                          fontSize: 12,
                          fontWeight: pw.FontWeight.bold,
                        ),
                      ),
                    ),
                    pw.Column(
                      crossAxisAlignment: pw.CrossAxisAlignment.end,
                      children: [
                        pw.Text(
                          'Receipt No: ${payment.receiptNo}',
                          style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 11),
                        ),
                        pw.Text(
                          'Date: ${payment.paymentDate}',
                          style: pw.TextStyle(color: grayText, fontSize: 10),
                        ),
                      ],
                    ),
                  ],
                ),

                pw.SizedBox(height: 16),

                // Student Information Card
                pw.Container(
                  padding: const pw.EdgeInsets.all(12),
                  decoration: pw.BoxDecoration(
                    color: lightBg,
                    border: pw.Border.all(color: borderColor),
                    borderRadius: pw.BorderRadius.circular(8),
                  ),
                  child: pw.Row(
                    children: [
                      pw.Expanded(
                        child: pw.Column(
                          crossAxisAlignment: pw.CrossAxisAlignment.start,
                          children: [
                            _buildInfoRow('Student Name:', student.fullName),
                            pw.SizedBox(height: 4),
                            _buildInfoRow('Student ID:', student.studentId),
                            pw.SizedBox(height: 4),
                            _buildInfoRow('Class / Grade:', student.gradeClass),
                          ],
                        ),
                      ),
                      pw.Expanded(
                        child: pw.Column(
                          crossAxisAlignment: pw.CrossAxisAlignment.start,
                          children: [
                            _buildInfoRow('Parent / Guardian:', student.parentName),
                            pw.SizedBox(height: 4),
                            _buildInfoRow('Contact Mobile:', student.mobile),
                            pw.SizedBox(height: 4),
                            _buildInfoRow('Fee Month:', payment.feeMonth),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),

                pw.SizedBox(height: 18),

                // Payment Details Table
                pw.Table(
                  border: pw.TableBorder.all(color: borderColor, width: 0.8),
                  columnWidths: {
                    0: const pw.FlexColumnWidth(3),
                    1: const pw.FlexColumnWidth(2),
                    2: const pw.FlexColumnWidth(2),
                  },
                  children: [
                    pw.TableRow(
                      decoration: pw.BoxDecoration(color: lightBg),
                      children: [
                        _buildTableHeader('Description'),
                        _buildTableHeader('Payment Method'),
                        _buildTableHeader('Amount (INR)'),
                      ],
                    ),
                    pw.TableRow(
                      children: [
                        _buildTableCell('Tuition Fees for ${payment.feeMonth}'),
                        _buildTableCell(payment.paymentMethod),
                        _buildTableCell(currencyFormat.format(payment.amount), isBold: true),
                      ],
                    ),
                  ],
                ),

                pw.SizedBox(height: 14),

                // Summary Calculation Block
                pw.Align(
                  alignment: pw.Alignment.centerRight,
                  child: pw.Container(
                    width: 240,
                    padding: const pw.EdgeInsets.all(10),
                    decoration: pw.BoxDecoration(
                      border: pw.Border.all(color: borderColor),
                      borderRadius: pw.BorderRadius.circular(6),
                    ),
                    child: pw.Column(
                      children: [
                        _buildSummaryRow('Monthly Fee Rate:', currencyFormat.format(student.monthlyFees)),
                        pw.SizedBox(height: 4),
                        _buildSummaryRow('Amount Paid Today:', currencyFormat.format(payment.amount), isHighlight: true),
                        pw.Divider(color: borderColor),
                        _buildSummaryRow(
                          'Remaining Balance Due:',
                          currencyFormat.format(totalBalanceDue),
                          isRed: totalBalanceDue > 0,
                        ),
                      ],
                    ),
                  ),
                ),

                if (payment.notes != null && payment.notes!.isNotEmpty) ...[
                  pw.SizedBox(height: 12),
                  pw.Text('Notes: ${payment.notes!}', style: pw.TextStyle(fontSize: 10, color: grayText)),
                ],

                pw.Spacer(),

                // Signatures & Footer
                pw.Row(
                  mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                  crossAxisAlignment: pw.CrossAxisAlignment.end,
                  children: [
                    pw.Column(
                      crossAxisAlignment: pw.CrossAxisAlignment.start,
                      children: [
                        pw.Text('Parent / Student Signature', style: pw.TextStyle(fontSize: 10, color: grayText)),
                        pw.SizedBox(height: 25),
                        pw.Container(width: 140, height: 1, color: PdfColors.grey500),
                      ],
                    ),
                    pw.Column(
                      crossAxisAlignment: pw.CrossAxisAlignment.center,
                      children: [
                        pw.Text(
                          'For ${profile.centreName.toUpperCase()}',
                          style: pw.TextStyle(fontSize: 10, fontWeight: pw.FontWeight.bold, color: darkBlue),
                        ),
                        pw.SizedBox(height: 25),
                        pw.Container(width: 150, height: 1, color: PdfColors.grey500),
                        pw.SizedBox(height: 3),
                        pw.Text(
                          profile.inchargeName.isNotEmpty ? profile.inchargeName : 'Authorized Signature & Seal',
                          style: pw.TextStyle(fontSize: 9, color: grayText),
                        ),
                      ],
                    ),
                  ],
                ),

                pw.SizedBox(height: 10),
                pw.Center(
                  child: pw.Text(
                    'This is a computer generated receipt from ${profile.centreName} mobile app.',
                    style: pw.TextStyle(fontSize: 8, color: grayText, fontStyle: pw.FontStyle.italic),
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );

    return pdf.save();
  }

  /// Rasterize the fee receipt PDF into a crisp, high-resolution PNG image
  static Future<Uint8List> generateFeeReceiptImage({
    required FeePayment payment,
    required Student student,
    required double totalBalanceDue,
    double dpi = 220,
  }) async {
    final pdfBytes = await generateFeeReceipt(
      payment: payment,
      student: student,
      totalBalanceDue: totalBalanceDue,
    );

    Uint8List? imageBytes;
    await for (final page in Printing.raster(pdfBytes, pages: [0], dpi: dpi)) {
      imageBytes = await page.toPng();
      break;
    }

    if (imageBytes != null) {
      return imageBytes;
    }
    throw Exception('Failed to rasterize receipt into image');
  }

  /// Save receipt PDF or PNG image to device temporary/storage folder and return file
  static Future<File> saveReceiptToFile({
    required FeePayment payment,
    required Student student,
    required double totalBalanceDue,
    required bool asImage,
  }) async {
    final tempDir = await getTemporaryDirectory();
    final safeReceiptNo = payment.receiptNo.replaceAll(RegExp(r'[^a-zA-Z0-9_-]'), '_');

    if (asImage) {
      final imgBytes = await generateFeeReceiptImage(
        payment: payment,
        student: student,
        totalBalanceDue: totalBalanceDue,
      );
      final file = File('${tempDir.path}/Receipt_${safeReceiptNo}.png');
      await file.writeAsBytes(imgBytes);
      return file;
    } else {
      final pdfBytes = await generateFeeReceipt(
        payment: payment,
        student: student,
        totalBalanceDue: totalBalanceDue,
      );
      final file = File('${tempDir.path}/Receipt_${safeReceiptNo}.pdf');
      await file.writeAsBytes(pdfBytes);
      return file;
    }
  }

  // ==========================================
  // 2. ATTENDANCE REPORT PDF
  // ==========================================
  static Future<Uint8List> generateAttendanceReport({
    required List<Attendance> attendanceList,
    String? gradeClass,
    String? startDate,
    String? endDate,
    Student? specificStudent,
  }) async {
    final pdf = pw.Document();
    final logoImage = await _loadLogo();
    final profile = await DBHelper.instance.getCentreProfile();

    int presentCount = attendanceList.where((a) => a.status == 'Present').length;
    int absentCount = attendanceList.where((a) => a.status == 'Absent').length;
    int leaveCount = attendanceList.where((a) => a.status == 'Leave').length;

    pdf.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(32),
        header: (pw.Context context) {
          return pw.Column(
            children: [
              pw.Row(
                crossAxisAlignment: pw.CrossAxisAlignment.center,
                children: [
                  if (logoImage != null)
                    pw.Container(
                      width: 50,
                      height: 50,
                      margin: const pw.EdgeInsets.only(right: 12),
                      child: pw.Image(logoImage),
                    ),
                  pw.Expanded(
                    child: pw.Column(
                      crossAxisAlignment: pw.CrossAxisAlignment.start,
                      children: [
                        pw.Text(
                          profile.centreName,
                          style: pw.TextStyle(fontSize: 16, fontWeight: pw.FontWeight.bold, color: brandBlue),
                        ),
                        pw.Text(
                          'ATTENDANCE REPORT - ${specificStudent != null ? specificStudent.fullName : (gradeClass ?? "All Classes")}',
                          style: pw.TextStyle(fontSize: 12, fontWeight: pw.FontWeight.bold, color: darkBlue),
                        ),
                        pw.Text(
                          '${profile.address} | Phone: ${profile.phone}',
                          style: pw.TextStyle(fontSize: 8.5, color: grayText),
                        ),
                        pw.Text(
                          'Date Range: ${startDate ?? "Beginning"} to ${endDate ?? "Present"}',
                          style: pw.TextStyle(fontSize: 8.5, color: grayText),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              pw.SizedBox(height: 8),
              pw.Divider(color: brandBlue, thickness: 1),
              pw.SizedBox(height: 6),
            ],
          );
        },
        build: (pw.Context context) {
          return [
            // Summary Chips
            pw.Row(
              mainAxisAlignment: pw.MainAxisAlignment.spaceAround,
              children: [
                _buildStatBadge('Total Records', '${attendanceList.length}', brandBlue),
                _buildStatBadge('Present', '$presentCount', PdfColor.fromInt(0xFF10B981)),
                _buildStatBadge('Absent', '$absentCount', PdfColor.fromInt(0xFFEF4444)),
                _buildStatBadge('Leave', '$leaveCount', PdfColor.fromInt(0xFFF59E0B)),
              ],
            ),
            pw.SizedBox(height: 16),

            // Table of records
            pw.Table(
              border: pw.TableBorder.all(color: borderColor, width: 0.5),
              columnWidths: {
                0: const pw.FlexColumnWidth(1.2),
                1: const pw.FlexColumnWidth(2.5),
                2: const pw.FlexColumnWidth(1.5),
                3: const pw.FlexColumnWidth(1.5),
                4: const pw.FlexColumnWidth(2),
              },
              children: [
                pw.TableRow(
                  decoration: pw.BoxDecoration(color: lightBg),
                  children: [
                    _buildTableHeader('Date'),
                    _buildTableHeader('Student Name'),
                    _buildTableHeader('Class'),
                    _buildTableHeader('Status'),
                    _buildTableHeader('Notes'),
                  ],
                ),
                ...attendanceList.map((att) {
                  return pw.TableRow(
                    children: [
                      _buildTableCell(att.date),
                      _buildTableCell(att.studentName ?? '-'),
                      _buildTableCell(att.gradeClass ?? '-'),
                      _buildStatusCell(att.status),
                      _buildTableCell(att.notes ?? '-'),
                    ],
                  );
                }),
              ],
            ),
          ];
        },
      ),
    );

    return pdf.save();
  }

  // ==========================================
  // 3. FEE COLLECTION & PENDING REPORT PDF
  // ==========================================
  static Future<Uint8List> generateFeesReport({
    required List<FeePayment> paymentList,
    required List<Map<String, dynamic>> pendingStudentsList,
    String? month,
  }) async {
    final pdf = pw.Document();
    final logoImage = await _loadLogo();
    final profile = await DBHelper.instance.getCentreProfile();
    final currency = NumberFormat.currency(locale: 'en_IN', symbol: 'Rs. ');

    double totalCollected = paymentList.fold(0.0, (sum, item) => sum + item.amount);
    double totalPending = pendingStudentsList.fold(0.0, (sum, item) => sum + (item['balance'] as double));

    pdf.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(32),
        header: (pw.Context context) {
          return pw.Column(
            children: [
              pw.Row(
                crossAxisAlignment: pw.CrossAxisAlignment.center,
                children: [
                  if (logoImage != null)
                    pw.Container(
                      width: 50,
                      height: 50,
                      margin: const pw.EdgeInsets.only(right: 12),
                      child: pw.Image(logoImage),
                    ),
                  pw.Expanded(
                    child: pw.Column(
                      crossAxisAlignment: pw.CrossAxisAlignment.start,
                      children: [
                        pw.Text(
                          profile.centreName,
                          style: pw.TextStyle(fontSize: 16, fontWeight: pw.FontWeight.bold, color: brandBlue),
                        ),
                        pw.Text(
                          'FEES COLLECTION & PENDING REPORT - ${month ?? "All Months"}',
                          style: pw.TextStyle(fontSize: 12, fontWeight: pw.FontWeight.bold, color: darkBlue),
                        ),
                        pw.Text(
                          '${profile.address} | Phone: ${profile.phone}',
                          style: pw.TextStyle(fontSize: 8.5, color: grayText),
                        ),
                        pw.Text(
                          'Generated On: ${DateFormat('dd MMM yyyy, hh:mm a').format(DateTime.now())}',
                          style: pw.TextStyle(fontSize: 8.5, color: grayText),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              pw.SizedBox(height: 8),
              pw.Divider(color: brandBlue, thickness: 1),
              pw.SizedBox(height: 6),
            ],
          );
        },
        build: (pw.Context context) {
          return [
            // Overview Cards
            pw.Row(
              mainAxisAlignment: pw.MainAxisAlignment.spaceAround,
              children: [
                _buildStatBadge('Total Collected', currency.format(totalCollected), brandBlue),
                _buildStatBadge('Total Pending Dues', currency.format(totalPending), PdfColor.fromInt(0xFFEF4444)),
                _buildStatBadge('Payments Count', '${paymentList.length}', darkBlue),
              ],
            ),
            pw.SizedBox(height: 16),

            // Section 1: Recent Fee Payments
            pw.Text(
              'Fee Collections',
              style: pw.TextStyle(fontSize: 12, fontWeight: pw.FontWeight.bold, color: brandBlue),
            ),
            pw.SizedBox(height: 6),
            pw.Table(
              border: pw.TableBorder.all(color: borderColor, width: 0.5),
              columnWidths: {
                0: const pw.FlexColumnWidth(1.8),
                1: const pw.FlexColumnWidth(2.5),
                2: const pw.FlexColumnWidth(1.2),
                3: const pw.FlexColumnWidth(1.5),
                4: const pw.FlexColumnWidth(1.5),
                5: const pw.FlexColumnWidth(1.5),
              },
              children: [
                pw.TableRow(
                  decoration: pw.BoxDecoration(color: lightBg),
                  children: [
                    _buildTableHeader('Receipt No'),
                    _buildTableHeader('Student'),
                    _buildTableHeader('Class'),
                    _buildTableHeader('Month'),
                    _buildTableHeader('Mode'),
                    _buildTableHeader('Amount'),
                  ],
                ),
                ...paymentList.map((p) => pw.TableRow(
                      children: [
                        _buildTableCell(p.receiptNo),
                        _buildTableCell(p.studentName ?? '-'),
                        _buildTableCell(p.gradeClass ?? '-'),
                        _buildTableCell(p.feeMonth),
                        _buildTableCell(p.paymentMethod),
                        _buildTableCell(currency.format(p.amount), isBold: true),
                      ],
                    )),
              ],
            ),

            if (pendingStudentsList.isNotEmpty) ...[
              pw.SizedBox(height: 20),
              pw.Text(
                'Students with Pending Dues',
                style: pw.TextStyle(fontSize: 12, fontWeight: pw.FontWeight.bold, color: PdfColor.fromInt(0xFFEF4444)),
              ),
              pw.SizedBox(height: 6),
              pw.Table(
                border: pw.TableBorder.all(color: borderColor, width: 0.5),
                columnWidths: {
                  0: const pw.FlexColumnWidth(1.5),
                  1: const pw.FlexColumnWidth(2.5),
                  2: const pw.FlexColumnWidth(1.5),
                  3: const pw.FlexColumnWidth(2),
                  4: const pw.FlexColumnWidth(2),
                },
                children: [
                  pw.TableRow(
                    decoration: pw.BoxDecoration(color: lightBg),
                    children: [
                      _buildTableHeader('Student ID'),
                      _buildTableHeader('Name'),
                      _buildTableHeader('Class'),
                      _buildTableHeader('Parent Contact'),
                      _buildTableHeader('Pending Balance'),
                    ],
                  ),
                  ...pendingStudentsList.map((st) => pw.TableRow(
                        children: [
                          _buildTableCell(st['student_id'] ?? ''),
                          _buildTableCell(st['name'] ?? ''),
                          _buildTableCell(st['class'] ?? ''),
                          _buildTableCell(st['mobile'] ?? ''),
                          _buildTableCell(currency.format(st['balance']), isBold: true),
                        ],
                      )),
                ],
              ),
            ],
          ];
        },
      ),
    );

    return pdf.save();
  }

  // ==========================================
  // HELPER PDF WIDGETS
  // ==========================================
  static pw.Widget _buildInfoRow(String title, String val) {
    return pw.RichText(
      text: pw.TextSpan(
        text: '$title ',
        style: pw.TextStyle(fontSize: 9, color: grayText, fontWeight: pw.FontWeight.bold),
        children: [
          pw.TextSpan(
            text: val,
            style: pw.TextStyle(fontSize: 9, color: PdfColors.black, fontWeight: pw.FontWeight.normal),
          ),
        ],
      ),
    );
  }

  static pw.Widget _buildTableHeader(String text) {
    return pw.Padding(
      padding: const pw.EdgeInsets.symmetric(horizontal: 6, vertical: 5),
      child: pw.Text(
        text,
        style: pw.TextStyle(fontSize: 9, fontWeight: pw.FontWeight.bold, color: brandBlue),
      ),
    );
  }

  static pw.Widget _buildTableCell(String text, {bool isBold = false}) {
    return pw.Padding(
      padding: const pw.EdgeInsets.symmetric(horizontal: 6, vertical: 5),
      child: pw.Text(
        text,
        style: pw.TextStyle(fontSize: 8.5, fontWeight: isBold ? pw.FontWeight.bold : pw.FontWeight.normal),
      ),
    );
  }

  static pw.Widget _buildStatusCell(String status) {
    PdfColor color = PdfColors.black;
    if (status == 'Present') color = PdfColor.fromInt(0xFF10B981);
    if (status == 'Absent') color = PdfColor.fromInt(0xFFEF4444);
    if (status == 'Leave') color = PdfColor.fromInt(0xFFF59E0B);

    return pw.Padding(
      padding: const pw.EdgeInsets.symmetric(horizontal: 6, vertical: 5),
      child: pw.Text(
        status,
        style: pw.TextStyle(fontSize: 8.5, fontWeight: pw.FontWeight.bold, color: color),
      ),
    );
  }

  static pw.Widget _buildSummaryRow(String title, String val, {bool isHighlight = false, bool isRed = false}) {
    return pw.Row(
      mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
      children: [
        pw.Text(
          title,
          style: pw.TextStyle(
            fontSize: 9,
            fontWeight: isHighlight ? pw.FontWeight.bold : pw.FontWeight.normal,
            color: isRed ? PdfColor.fromInt(0xFFEF4444) : PdfColors.black,
          ),
        ),
        pw.Text(
          val,
          style: pw.TextStyle(
            fontSize: 9.5,
            fontWeight: pw.FontWeight.bold,
            color: isRed ? PdfColor.fromInt(0xFFEF4444) : (isHighlight ? brandBlue : PdfColors.black),
          ),
        ),
      ],
    );
  }

  static pw.Widget _buildStatBadge(String title, String count, PdfColor color) {
    return pw.Container(
      padding: const pw.EdgeInsets.symmetric(horizontal: 14, vertical: 8),
      decoration: pw.BoxDecoration(
        border: pw.Border.all(color: color, width: 1),
        borderRadius: pw.BorderRadius.circular(6),
      ),
      child: pw.Column(
        children: [
          pw.Text(title, style: pw.TextStyle(fontSize: 9, color: grayText)),
          pw.SizedBox(height: 3),
          pw.Text(count, style: pw.TextStyle(fontSize: 12, fontWeight: pw.FontWeight.bold, color: color)),
        ],
      ),
    );
  }

  /// Print or Share PDF
  static Future<void> printOrShareReceipt(Uint8List pdfBytes, String receiptNo) async {
    await Printing.sharePdf(bytes: pdfBytes, filename: 'Receipt_$receiptNo.pdf');
  }
}
