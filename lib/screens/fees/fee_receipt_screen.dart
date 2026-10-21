import 'dart:io';
import 'package:flutter/material.dart';
import 'package:printing/printing.dart';
import 'package:share_plus/share_plus.dart';
import '../../constants/app_colors.dart';
import '../../models/student.dart';
import '../../models/fee_payment.dart';
import '../../services/pdf_service.dart';

class FeeReceiptScreen extends StatefulWidget {
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
  State<FeeReceiptScreen> createState() => _FeeReceiptScreenState();
}

class _FeeReceiptScreenState extends State<FeeReceiptScreen> {
  bool _isProcessingImage = false;
  bool _isProcessingPdf = false;

  Future<void> _downloadOrPrintPdf() async {
    setState(() => _isProcessingPdf = true);
    try {
      final pdfBytes = await PdfService.generateFeeReceipt(
        payment: widget.payment,
        student: widget.student,
        totalBalanceDue: widget.balanceDue,
      );

      await Printing.layoutPdf(
        onLayout: (format) async => pdfBytes,
        name: 'Receipt_${widget.payment.receiptNo}.pdf',
      );
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error generating PDF: $e'), backgroundColor: AppColors.error),
        );
      }
    } finally {
      if (mounted) setState(() => _isProcessingPdf = false);
    }
  }

  Future<void> _downloadAsImage() async {
    setState(() => _isProcessingImage = true);
    try {
      final file = await PdfService.saveReceiptToFile(
        payment: widget.payment,
        student: widget.student,
        totalBalanceDue: widget.balanceDue,
        asImage: true,
      );

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: [
                const Icon(Icons.check_circle_rounded, color: Colors.white, size: 20),
                const SizedBox(width: 8),
                Expanded(
                  child: Text('Receipt image saved: ${file.path.split("/").last}'),
                ),
              ],
            ),
            backgroundColor: AppColors.success,
            action: SnackBarAction(
              label: 'Share Now',
              textColor: Colors.white,
              onPressed: () => _shareBill(asImage: true),
            ),
            duration: const Duration(seconds: 4),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error saving receipt image: $e'), backgroundColor: AppColors.error),
        );
      }
    } finally {
      if (mounted) setState(() => _isProcessingImage = false);
    }
  }

  Future<void> _shareBill({required bool asImage}) async {
    try {
      final file = await PdfService.saveReceiptToFile(
        payment: widget.payment,
        student: widget.student,
        totalBalanceDue: widget.balanceDue,
        asImage: asImage,
      );

      final studentName = widget.student.fullName;
      final month = widget.payment.feeMonth;
      final receiptNo = widget.payment.receiptNo;
      final amount = widget.payment.amount.toStringAsFixed(0);

      await Share.shareXFiles(
        [XFile(file.path)],
        subject: 'Fee Receipt #$receiptNo - $studentName',
        text: 'Tuition Fee Receipt for $studentName ($month) - Rs. $amount. Receipt #$receiptNo.',
      );
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error sharing receipt: $e'), backgroundColor: AppColors.error),
        );
      }
    }
  }

  void _showShareOptionsModal() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (ctx) {
        return Container(
          decoration: const BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
          ),
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: Colors.grey.shade300,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              const Text(
                'Share Fee Receipt',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: AppColors.textPrimary),
              ),
              const SizedBox(height: 4),
              const Text(
                'Choose your preferred format to share with parents / students.',
                style: TextStyle(fontSize: 12, color: AppColors.textSecondary),
              ),
              const SizedBox(height: 16),

              // Option 1: Image (WhatsApp)
              Container(
                decoration: BoxDecoration(
                  color: AppColors.lightYellow.withOpacity(0.4),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: AppColors.primaryYellow.withOpacity(0.5)),
                ),
                child: ListTile(
                  leading: Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: AppColors.primaryYellow.withOpacity(0.2),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(Icons.image_rounded, color: AppColors.darkYellow),
                  ),
                  title: const Row(
                    children: [
                      Text('Share as Image (PNG)', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                      SizedBox(width: 6),
                      Text(
                        '★ Best for WhatsApp',
                        style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: AppColors.primaryBlue),
                      ),
                    ],
                  ),
                  subtitle: const Text('Direct image preview without needing a PDF reader app', style: TextStyle(fontSize: 11)),
                  onTap: () {
                    Navigator.pop(ctx);
                    _shareBill(asImage: true);
                  },
                ),
              ),

              const SizedBox(height: 10),

              // Option 2: PDF Document
              Container(
                decoration: BoxDecoration(
                  color: AppColors.lightBlue.withOpacity(0.3),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: AppColors.primaryBlue.withOpacity(0.3)),
                ),
                child: ListTile(
                  leading: Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: AppColors.primaryBlue.withOpacity(0.12),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(Icons.picture_as_pdf_rounded, color: AppColors.primaryBlue),
                  ),
                  title: const Text('Share as PDF Document', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                  subtitle: const Text('Official full-resolution PDF bill document', style: TextStyle(fontSize: 11)),
                  onTap: () {
                    Navigator.pop(ctx);
                    _shareBill(asImage: false);
                  },
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Receipt #${widget.payment.receiptNo}',
              style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.white, fontSize: 16),
            ),
            Text(
              '${widget.student.fullName} • ${widget.payment.feeMonth}',
              style: TextStyle(color: Colors.white.withOpacity(0.85), fontSize: 11),
            ),
          ],
        ),
        backgroundColor: AppColors.primaryBlue,
        elevation: 0,
        iconTheme: const IconThemeData(color: Colors.white),
        actions: [
          IconButton(
            icon: const Icon(Icons.share_rounded, color: Colors.white),
            tooltip: 'Share Receipt',
            onPressed: _showShareOptionsModal,
          ),
          IconButton(
            icon: const Icon(Icons.print_rounded, color: Colors.white),
            tooltip: 'Print / Download PDF',
            onPressed: _downloadOrPrintPdf,
          ),
        ],
      ),
      body: Column(
        children: [
          // PDF Preview Canvas
          Expanded(
            child: PdfPreview(
              build: (format) => PdfService.generateFeeReceipt(
                payment: widget.payment,
                student: widget.student,
                totalBalanceDue: widget.balanceDue,
              ),
              allowPrinting: true,
              allowSharing: false,
              canChangePageFormat: false,
              canChangeOrientation: false,
              pdfFileName: 'Receipt_${widget.payment.receiptNo}.pdf',
              actions: const [],
            ),
          ),

          // Bottom Quick Action Bar for Instant Downloads & Sharing
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            decoration: BoxDecoration(
              color: Colors.white,
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.06),
                  blurRadius: 10,
                  offset: const Offset(0, -3),
                ),
              ],
            ),
            child: SafeArea(
              top: false,
              child: Row(
                children: [
                  // 1. Download as Image Button
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: _isProcessingImage ? null : _downloadAsImage,
                      icon: _isProcessingImage
                          ? const SizedBox(
                              width: 16,
                              height: 16,
                              child: CircularProgressIndicator(strokeWidth: 2, color: AppColors.darkYellow),
                            )
                          : const Icon(Icons.image_outlined, size: 18, color: AppColors.darkYellow),
                      label: const Text(
                        'Image (PNG)',
                        style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12, color: AppColors.darkYellow),
                      ),
                      style: OutlinedButton.styleFrom(
                        side: const BorderSide(color: AppColors.primaryYellow, width: 1.5),
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                      ),
                    ),
                  ),

                  const SizedBox(width: 8),

                  // 2. Download / Print PDF Button
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: _isProcessingPdf ? null : _downloadOrPrintPdf,
                      icon: _isProcessingPdf
                          ? const SizedBox(
                              width: 16,
                              height: 16,
                              child: CircularProgressIndicator(strokeWidth: 2, color: AppColors.primaryBlue),
                            )
                          : const Icon(Icons.picture_as_pdf_outlined, size: 18, color: AppColors.primaryBlue),
                      label: const Text(
                        'PDF Bill',
                        style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12, color: AppColors.primaryBlue),
                      ),
                      style: OutlinedButton.styleFrom(
                        side: const BorderSide(color: AppColors.primaryBlue, width: 1.5),
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                      ),
                    ),
                  ),

                  const SizedBox(width: 8),

                  // 3. Share Button
                  Expanded(
                    flex: 1,
                    child: ElevatedButton.icon(
                      onPressed: _showShareOptionsModal,
                      icon: const Icon(Icons.share_rounded, size: 18, color: Colors.white),
                      label: const Text(
                        'Share',
                        style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12, color: Colors.white),
                      ),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.primaryBlue,
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
