import 'dart:convert';
import 'package:flutter/material.dart';
import '../../services/api_service.dart';

class ManualEntryScreen extends StatefulWidget {
  @override
  State<ManualEntryScreen> createState() => _ManualEntryScreenState();
}

class _ManualEntryScreenState extends State<ManualEntryScreen> {

  final vehicleController = TextEditingController();
  bool loading = false;

  validateVehicle() async {
    setState(() => loading = true);

    final response = await ApiService.post(
      "/api/vehicle/by-qr",
      {
        "qr_value": vehicleController.text.trim()
      },
      auth: true,
    );

    setState(() => loading = false);

    if (response.statusCode == 200) {
      final data = jsonDecode(response.body);

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Vehicle: ${data["vehicle"]["vehicle_number"]}")),
      );

      Navigator.pop(context);
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Invalid Vehicle Number")),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text("Manual Vehicle Entry")),
      body: Padding(
        padding: EdgeInsets.all(16),
        child: Column(
          children: [

            TextField(
              controller: vehicleController,
              decoration: InputDecoration(
                labelText: "Enter Vehicle Number",
                border: OutlineInputBorder(),
              ),
            ),

            SizedBox(height: 20),

            ElevatedButton(
              onPressed: loading ? null : validateVehicle,
              child: Text(loading ? "Checking..." : "Validate Vehicle"),
            ),
          ],
        ),
      ),
    );
  }
}