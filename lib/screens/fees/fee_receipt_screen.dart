import 'package:flutter/material.dart';
import 'package:printing/printing.dart';
import '../../constants/app_colors.dart';
import '../../models/student.dart';
import '../../models/fee_payment.dart';
import '../../services/pdf_service.dart';

class FeeReceiptScreen extends StatelessWidget {
  final FeePayment payment;
  final Student student;
  final double balanceDue;

  const FeeReceiptScreen({
    super.key,
    required this.payment,
    required this.student,
    required this.balanceDue,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: Text(
          'Receipt #${payment.receiptNo}',
          style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.white),
        ),
        backgroundColor: AppColors.primaryBlue,
        elevation: 0,
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      body: PdfPreview(
        build: (format) => PdfService.generateFeeReceipt(
          payment: payment,
          student: student,
          totalBalanceDue: balanceDue,
        ),
        allowPrinting: true,
        allowSharing: true,
        canChangePageFormat: false,
        pdfFileName: 'Receipt_${payment.receiptNo}.pdf',
        actions: const [],
      ),
    );
  }
}
