import 'dart:convert';
import 'package:flutter/material.dart';
import '../../services/api_service.dart';
import 'widgets/admin_branding.dart';

class AdminTripMonitorScreen extends StatefulWidget {
  const AdminTripMonitorScreen({super.key});

  @override
  State<AdminTripMonitorScreen> createState() =>
      _AdminTripMonitorScreenState();
}

class _AdminTripMonitorScreenState
    extends State<AdminTripMonitorScreen> {

  List trips = [];
  bool loading = true;

  @override
  void initState() {
    super.initState();
    fetchTrips();
  }

  Future<void> fetchTrips() async {

    final response =
        await ApiService.get("/api/admin/active-trips", auth: true);

    if (response.statusCode == 200) {
      final data = jsonDecode(response.body);

      setState(() {
        trips = data["trips"];
        loading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {

    return Scaffold(
      backgroundColor: AdminBranding.background,

      appBar: AdminBranding.appBar(title: "Active Trips Monitor"),

      body: loading
          ? const Center(child: CircularProgressIndicator())
              : trips.isEmpty
              ? const Center(
                  child: Text(
                    "No Active Trips",
                    style: TextStyle(color: AdminBranding.secondaryText),
                  ),
                )
              : ListView.builder(
                  padding: const EdgeInsets.all(10),
                  itemCount: trips.length,
                  itemBuilder: (context, index) {

                    final trip = trips[index];

                    return Card(
                      margin: const EdgeInsets.only(bottom: 10),
                      color: Colors.white,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14),
                        side: const BorderSide(color: AdminBranding.cardBorder),
                      ),

                      child: ListTile(
                        leading: const Icon(
                          Icons.local_shipping,
                          color: Color(0xFFCE1E2D),
                        ),

                        title: Text(
                          trip["vehicle_number"],
                          style: const TextStyle(
                            color: AdminBranding.primaryText,
                            fontWeight: FontWeight.w700,
                          ),
                        ),

                        subtitle: Text(
                          "Driver : ${trip["driver_name"]}\n"
                          "Equipment : ${trip["equipment_name"]}",
                          style: const TextStyle(color: AdminBranding.secondaryText),
                        ),

                        trailing: Container(
                          padding: const EdgeInsets.all(6),
                          decoration: BoxDecoration(
                            color: Colors.green,
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: const Text(
                            "ACTIVE",
                            style: TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.bold),
                          ),
                        ),
                      ),
                    );
                  },
                ),
    );
  }
}
