import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../services/api_service.dart';
import 'widgets/admin_branding.dart';

class AdminTripMonitorScreen extends StatefulWidget {
  const AdminTripMonitorScreen({super.key});

  @override
  State<AdminTripMonitorScreen> createState() => _AdminTripMonitorScreenState();
}

class _AdminTripMonitorScreenState extends State<AdminTripMonitorScreen> {
  List<Map<String, dynamic>> activeTrips = [];
  List<Map<String, dynamic>> completedTrips = [];
  bool loading = true;

  @override
  void initState() {
    super.initState();
    fetchTrips();
  }

  Future<void> fetchTrips() async {
    final activeResponse = await ApiService.get("/api/admin/active-trips", auth: true);
    final completedResponse = await ApiService.get("/api/admin/completed-trips", auth: true);

    if (!mounted) return;

    setState(() {
      activeTrips = activeResponse.statusCode == 200
          ? _toMapList(jsonDecode(activeResponse.body)["trips"])
          : [];
      completedTrips = completedResponse.statusCode == 200
          ? _toMapList(jsonDecode(completedResponse.body)["trips"])
          : [];
      loading = false;
    });
  }

  List<Map<String, dynamic>> _toMapList(dynamic source) {
    if (source is! List) return [];
    return source
        .whereType<Map>()
        .map((item) => Map<String, dynamic>.from(item))
        .toList();
  }

  List<Map<String, dynamic>> _tripReadings(Map<String, dynamic> trip) {
    final raw = trip["readings"];
    if (raw is! List) return [];
    return raw
        .whereType<Map>()
        .map((item) => Map<String, dynamic>.from(item))
        .toList();
  }

  String _formatValue(dynamic value) {
    if (value == null) return "-";
    final number = value is num ? value.toDouble() : double.tryParse(value.toString());
    if (number == null) return value.toString();
    if (number == number.roundToDouble()) {
      return number.toInt().toString();
    }
    return number.toStringAsFixed(2);
  }

  String _formatDate(dynamic value) {
    if (value == null) return "-";
    final parsed = DateTime.tryParse(value.toString());
    if (parsed == null) return value.toString();
    return DateFormat("dd-MM-yyyy HH:mm").format(parsed.toLocal());
  }

  String _completedAtText(Map<String, dynamic> trip) {
    return _formatDate(trip["completed_at"] ?? trip["created_at"]);
  }

  Widget _statusBadge(String label, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(
        label,
        style: const TextStyle(
          color: Colors.white,
          fontWeight: FontWeight.bold,
          fontSize: 12,
        ),
      ),
    );
  }

  Widget _metricBox(String label, String value) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(
          color: const Color(0xFFF7F8FA),
          borderRadius: BorderRadius.circular(10),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              label,
              style: const TextStyle(
                color: AdminBranding.secondaryText,
                fontSize: 12,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              value,
              style: const TextStyle(
                color: AdminBranding.primaryText,
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildActiveTripsTab() {
    if (activeTrips.isEmpty) {
      return const Center(
        child: Text(
          "No Active Trips",
          style: TextStyle(color: AdminBranding.secondaryText),
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: fetchTrips,
      child: ListView.builder(
        padding: const EdgeInsets.all(12),
        itemCount: activeTrips.length,
        itemBuilder: (context, index) {
          final trip = activeTrips[index];

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
                (trip["vehicle_number"] ?? "-").toString(),
                style: const TextStyle(
                  color: AdminBranding.primaryText,
                  fontWeight: FontWeight.w700,
                ),
              ),
              subtitle: Text(
                "Driver: ${(trip["driver_name"] ?? "-").toString()}\n"
                "Equipment: ${(trip["equipment_name"] ?? "-").toString()}\n"
                "Started: ${_formatDate(trip["created_at"])}",
                style: const TextStyle(color: AdminBranding.secondaryText),
              ),
              trailing: _statusBadge("ACTIVE", Colors.green),
            ),
          );
        },
      ),
    );
  }

  Widget _buildCompletedTripsTab() {
    if (completedTrips.isEmpty) {
      return const Center(
        child: Text(
          "No Completed Trips",
          style: TextStyle(color: AdminBranding.secondaryText),
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: fetchTrips,
      child: ListView.builder(
        padding: const EdgeInsets.all(12),
        itemCount: completedTrips.length,
        itemBuilder: (context, index) {
          final trip = completedTrips[index];
          final readings = _tripReadings(trip);

          return Container(
            margin: const EdgeInsets.only(bottom: 10),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: AdminBranding.cardBorder),
            ),
            child: ExpansionTile(
              tilePadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              childrenPadding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
              leading: const Icon(
                Icons.assignment_turned_in_outlined,
                color: Color(0xFF1E8D4A),
              ),
              title: Text(
                (trip["vehicle_number"] ?? "-").toString(),
                style: const TextStyle(
                  color: AdminBranding.primaryText,
                  fontWeight: FontWeight.w700,
                ),
              ),
              subtitle: Text(
                "Driver: ${(trip["driver_name"] ?? "-").toString()}\n"
                "Trip ID: ${(trip["trip_id"] ?? "-").toString()}\n"
                "Completed: ${_completedAtText(trip)}",
                style: const TextStyle(color: AdminBranding.secondaryText),
              ),
              trailing: _statusBadge("COMPLETED", const Color(0xFF1E8D4A)),
              children: [
                Align(
                  alignment: Alignment.centerLeft,
                  child: Text(
                    "Equipment: ${(trip["equipment_name"] ?? "-").toString()}",
                    style: const TextStyle(
                      color: AdminBranding.secondaryText,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                if (readings.isEmpty)
                  const Align(
                    alignment: Alignment.centerLeft,
                    child: Text(
                      "No reading details available",
                      style: TextStyle(color: AdminBranding.secondaryText),
                    ),
                  )
                else
                  ...readings.map((reading) {
                    final unit = (reading["unit"] ?? "").toString();
                    final title = unit.isEmpty
                        ? (reading["name"] ?? "Reading").toString()
                        : "${reading["name"]} ($unit)";

                    return Container(
                      margin: const EdgeInsets.only(bottom: 10),
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: const Color(0xFFF7F8FA),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            title,
                            style: const TextStyle(
                              color: AdminBranding.primaryText,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          const SizedBox(height: 10),
                          Row(
                            children: [
                              _metricBox(
                                "Start",
                                _formatValue(reading["start_value"]),
                              ),
                              const SizedBox(width: 8),
                              _metricBox(
                                "End",
                                _formatValue(reading["end_value"]),
                              ),
                              const SizedBox(width: 8),
                              _metricBox(
                                "Difference",
                                _formatValue(reading["difference_value"]),
                              ),
                            ],
                          ),
                        ],
                      ),
                    );
                  }),
              ],
            ),
          );
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 2,
      child: Scaffold(
        backgroundColor: AdminBranding.background,
        appBar: AdminBranding.appBar(title: "Trip Monitor"),
        body: loading
            ? const Center(child: CircularProgressIndicator())
            : Column(
                children: [
                  Container(
                    margin: const EdgeInsets.fromLTRB(12, 12, 12, 0),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: AdminBranding.cardBorder),
                    ),
                    child: const TabBar(
                      labelColor: Color(0xFFCE1E2D),
                      unselectedLabelColor: AdminBranding.secondaryText,
                      indicatorColor: Color(0xFFCE1E2D),
                      tabs: [
                        Tab(text: "Active Trips"),
                        Tab(text: "Completed Trips"),
                      ],
                    ),
                  ),
                  Expanded(
                    child: TabBarView(
                      children: [
                        _buildActiveTripsTab(),
                        _buildCompletedTripsTab(),
                      ],
                    ),
                  ),
                ],
              ),
      ),
    );
  }
}
