import 'dart:convert';
import 'package:flutter/material.dart';
import '../../services/api_service.dart';
import 'widgets/admin_branding.dart';

class VehicleMonitoringScreen extends StatefulWidget {
  const VehicleMonitoringScreen({super.key});

  @override
  State<VehicleMonitoringScreen> createState() =>
      _VehicleMonitoringScreenState();
}

class _VehicleMonitoringScreenState
    extends State<VehicleMonitoringScreen> {

  List vehicles = [];
  bool loading = true;

  @override
  void initState() {
    super.initState();
    fetchVehicles();
  }

  Future<void> fetchVehicles() async {

    final response = await ApiService.get(
      "/api/admin/vehicles",
      auth: true,
    );

    if (response.statusCode == 200) {
      final data = jsonDecode(response.body);

      setState(() {
        vehicles = data["vehicles"];
        loading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {

    return Scaffold(
      backgroundColor: AdminBranding.background,
      appBar: AdminBranding.appBar(title: "Vehicle Monitoring"),

      body: loading
          ? const Center(child: CircularProgressIndicator())
          : GridView.builder(
              padding: const EdgeInsets.all(16),
              gridDelegate:
                  const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 2,
                crossAxisSpacing: 12,
                mainAxisSpacing: 12,
                childAspectRatio: 1.4,
              ),
              itemCount: vehicles.length,
              itemBuilder: (context, index) {

                final vehicle = vehicles[index];

                return Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: AdminBranding.cardBorder),
                  ),

                  child: Column(
                    crossAxisAlignment:
                        CrossAxisAlignment.start,
                    children: [

                      Text(
                        vehicle["vehicle_number"],
                        style: const TextStyle(
                          fontSize: 18,
                          color: AdminBranding.primaryText,
                          fontWeight: FontWeight.bold,
                        ),
                      ),

                      const SizedBox(height: 10),

                      Text(
                        "Type: ${vehicle["vehicle_type"]}",
                        style: const TextStyle(
                            color: AdminBranding.secondaryText),
                      ),

                      const SizedBox(height: 5),

                      Text(
                        "Equipment: ${vehicle["equipment_name"]}",
                        style: const TextStyle(
                            color: AdminBranding.secondaryText),
                      ),

                      const Spacer(),

                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 10,
                            vertical: 5),
                        decoration: BoxDecoration(
                          color: vehicle["status"] == "ACTIVE"
                              ? Colors.green
                              : Colors.grey,
                          borderRadius:
                              BorderRadius.circular(5),
                        ),
                        child: Text(
                          vehicle["status"],
                          style: const TextStyle(
                              color: Colors.white),
                        ),
                      ),
                    ],
                  ),
                );
              },
            ),
    );
  }
}
