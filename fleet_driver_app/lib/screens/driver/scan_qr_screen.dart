import 'package:flutter/material.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'dart:convert';
import '../../services/api_service.dart';

class ScanQrScreen extends StatefulWidget {
  @override
  State<ScanQrScreen> createState() => _ScanQrScreenState();
}

class _ScanQrScreenState extends State<ScanQrScreen> {
  bool scanned = false;

  void handleScan(String qrData) async {
    if (scanned) return;
    scanned = true;

    final response = await ApiService.post("/vehicle/by-qr", {
      "qr_code": qrData,
    }, auth: true);

    if (response.statusCode == 200) {
      final data = jsonDecode(response.body);

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text("Vehicle: ${data["vehicle"]["vehicle_number"]}"),
        ),
      );

      Navigator.pop(context);
    } else {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text("Invalid Vehicle QR")));
      scanned = false;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text("Scan Vehicle QR")),
      body: MobileScanner(
        onDetect: (barcodeCapture) {
          final barcode = barcodeCapture.barcodes.first;
          if (barcode.rawValue != null) {
            handleScan(barcode.rawValue!);
          }
        },
      ),
    );
  }
}
