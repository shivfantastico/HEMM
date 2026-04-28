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

    final normalizedQr = qrData
        .trim()
        .toUpperCase()
        .replaceAll(RegExp(r'[^A-Z0-9]'), '');

    final response = await ApiService.post("/api/vehicle/by-qr", {
      "qr_value": normalizedQr,
    }, auth: true);

    if (response.statusCode == 200) {
      final data = jsonDecode(response.body);

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text("Vehicle: ${data["vehicle"]["vehicle_number"]}"),
        ),
      );

      Navigator.pop(context, data["vehicle"]["vehicle_number"]);
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
