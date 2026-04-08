import 'dart:convert';
import 'package:flutter/material.dart';
import '../../services/api_service.dart';
import 'widgets/admin_branding.dart';

class VehicleDetailScreen extends StatefulWidget {
  final dynamic vehicleId;
  final String vehicleNumber;
  final List<Map<String, dynamic>> vehicleRecords;

  const VehicleDetailScreen({
    super.key,
    required this.vehicleId,
    required this.vehicleNumber,
    required this.vehicleRecords,
  });

  @override
  State<VehicleDetailScreen> createState() => _VehicleDetailScreenState();
}

class _VehicleDetailScreenState extends State<VehicleDetailScreen> {
  Map<String, dynamic> vehicleData = {};
  List<Map<String, dynamic>> todayRecords = [];
  bool hasStrictTodayRecords = false;
  bool loading = true;

  @override
  void initState() {
    super.initState();
    fetchVehicleDetails();
  }

  Future<void> fetchVehicleDetails() async {

    final response = await ApiService.get(
      "/api/admin/vehicle/${widget.vehicleId}",
      auth: true,
    );

    Map<String, dynamic> details = {};
    if (response.statusCode == 200) {
      final data = jsonDecode(response.body);
      if (data is Map<String, dynamic>) {
        details = data;
      }
    }

    setState(() {
      vehicleData = details;
      todayRecords = _filterToday(widget.vehicleRecords);
      hasStrictTodayRecords = todayRecords.any(_isTodayRow);
      loading = false;
    });
  }

  bool _isTodayRow(Map<String, dynamic> row) {
    final date = _extractDate(row);
    if (date == null) return false;
    final now = DateTime.now();
    return date.year == now.year &&
        date.month == now.month &&
        date.day == now.day;
  }

  DateTime? _extractDate(Map<String, dynamic> row) {
    final keys = [
      "trip_start_time",
      "trip_date",
      "updated_at",
      "created_at",
      "start_time",
      "started_at",
      "date",
      "createdAt",
      "timestamp",
      "logged_at",
    ];
    for (final key in keys) {
      final value = row[key];
      if (value == null) continue;
      if (value is String) {
        final parsed = DateTime.tryParse(value);
        if (parsed != null) return parsed.toLocal();
      }
      if (value is int) {
        // Supports epoch seconds or epoch milliseconds.
        final epochMs = value > 9999999999 ? value : value * 1000;
        return DateTime.fromMillisecondsSinceEpoch(epochMs).toLocal();
      }
    }
    return null;
  }

  List<Map<String, dynamic>> _filterToday(List<Map<String, dynamic>> rows) {
    final now = DateTime.now();
    final filtered = rows.where((row) {
      final date = _extractDate(row);
      if (date == null) return false;
      return date.year == now.year &&
          date.month == now.month &&
          date.day == now.day;
    }).toList();

    filtered.sort((a, b) {
      final aDate = _extractDate(a);
      final bDate = _extractDate(b);
      if (aDate == null && bDate == null) return 0;
      if (aDate == null) return 1;
      if (bDate == null) return -1;
      return bDate.compareTo(aDate);
    });

    if (filtered.isNotEmpty) return filtered;

    final activeRows = rows.where((row) {
      return (row["trip_status"] ?? row["status"] ?? "")
              .toString()
              .toUpperCase() ==
          "STARTED";
    }).toList();
    if (activeRows.isNotEmpty) return activeRows;

    return rows;
  }

  Map<String, dynamic> _asMap(dynamic value) {
    if (value is Map<String, dynamic>) return value;
    if (value is Map) return Map<String, dynamic>.from(value);
    return {};
  }

  String _firstText(List<dynamic> values, {String fallback = "-"}) {
    for (final value in values) {
      if (value == null) continue;
      final text = value.toString().trim();
      if (text.isNotEmpty && text.toLowerCase() != "null") {
        return text;
      }
    }
    return fallback;
  }

  String _driverText() {
    final vehicle = _asMap(vehicleData["vehicle"]);
    final trip = _asMap(vehicleData["trip"]);
    final data = _asMap(vehicleData["data"]);
    final row = todayRecords.isNotEmpty
        ? todayRecords.first
        : (widget.vehicleRecords.isNotEmpty ? widget.vehicleRecords.first : {});

    final driver = _firstText([
      vehicleData["driver_name"],
      vehicleData["driver"],
      vehicleData["current_driver"],
      vehicle["driver_name"],
      vehicle["driver"],
      trip["driver_name"],
      trip["driver"],
      data["driver_name"],
      data["driver"],
      row["driver_name"],
      row["driver"],
    ], fallback: "N/A");

    return driver;
  }

  String _statusText() {
    final vehicle = _asMap(vehicleData["vehicle"]);
    final trip = _asMap(vehicleData["trip"]);
    final data = _asMap(vehicleData["data"]);
    final row = todayRecords.isNotEmpty
        ? todayRecords.first
        : (widget.vehicleRecords.isNotEmpty ? widget.vehicleRecords.first : {});

    return _firstText([
      vehicleData["trip_status"],
      vehicleData["status"],
      vehicle["trip_status"],
      vehicle["status"],
      trip["trip_status"],
      trip["status"],
      data["trip_status"],
      data["status"],
      row["trip_status"],
      row["status"],
    ], fallback: "N/A");
  }

  String _typeText() {
    final vehicle = _asMap(vehicleData["vehicle"]);
    final data = _asMap(vehicleData["data"]);
    final row = widget.vehicleRecords.isNotEmpty ? widget.vehicleRecords.first : {};

    return _firstText([
      vehicleData["vehicle_type"],
      vehicleData["equipment_name"],
      vehicle["vehicle_type"],
      vehicle["equipment_name"],
      data["vehicle_type"],
      data["equipment_name"],
      row["vehicle_type"],
      row["equipment_name"],
    ], fallback: "-");
  }

  String _metricText(List<String> keys) {
    final vehicle = _asMap(vehicleData["vehicle"]);
    final trip = _asMap(vehicleData["trip"]);
    final data = _asMap(vehicleData["data"]);
    final row = todayRecords.isNotEmpty
        ? todayRecords.first
        : (widget.vehicleRecords.isNotEmpty ? widget.vehicleRecords.first : {});

    final candidates = <dynamic>[];
    for (final key in keys) {
      candidates.add(vehicleData[key]);
      candidates.add(vehicle[key]);
      candidates.add(trip[key]);
      candidates.add(data[key]);
      candidates.add(row[key]);
    }

    for (final value in candidates) {
      if (value == null) continue;
      if (value is num) return value.toString();
      final text = value.toString().trim();
      if (text.isNotEmpty && text.toLowerCase() != "null") {
        return text;
      }
    }

    return "0";
  }

  String _timeText(Map<String, dynamic> row) {
    final date = _extractDate(row);
    if (date == null) return "-";
    final h = date.hour.toString().padLeft(2, "0");
    final m = date.minute.toString().padLeft(2, "0");
    return "$h:$m";
  }

  @override
  Widget build(BuildContext context) {

    return Scaffold(
      appBar: AdminBranding.appBar(title: widget.vehicleNumber),
      backgroundColor: AdminBranding.background,

      body: loading
          ? const Center(child: CircularProgressIndicator())
          : Padding(
              padding: const EdgeInsets.all(16),

              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [

                  Text(
                    "Vehicle Details",
                    style: const TextStyle(
                      fontSize: 20,
                      color: AdminBranding.primaryText,
                      fontWeight: FontWeight.bold,
                    ),
                  ),

                  const SizedBox(height: 15),

                  Text(
                    "Type : ${_typeText()}",
                    style: const TextStyle(color: AdminBranding.secondaryText),
                  ),

                  Text(
                    "Driver : ${_driverText()}",
                    style: const TextStyle(color: AdminBranding.secondaryText),
                  ),

                  Text(
                    "Status : ${_statusText()}",
                    style: const TextStyle(color: AdminBranding.secondaryText),
                  ),

                  const SizedBox(height: 20),

                  const Text(
                    "Today's Activity",
                    style: TextStyle(
                      fontSize: 18,
                      color: AdminBranding.primaryText,
                    ),
                  ),

                  const SizedBox(height: 10),

                  Text(
                    hasStrictTodayRecords
                        ? "Trips today : ${todayRecords.length}"
                        : "Trips shown : ${todayRecords.length}",
                    style: const TextStyle(color: AdminBranding.secondaryText),
                  ),

                  Text(
                    "KM : ${_metricText(["km", "current_km", "total_km", "start_km", "end_km"])}",
                    style: const TextStyle(color: AdminBranding.secondaryText),
                  ),

                  Text(
                    "Hour Meter : ${_metricText(["hour_meter", "hourmeter", "start_hour_meter", "end_hour_meter", "engine_hours"])}",
                    style: const TextStyle(color: AdminBranding.secondaryText),
                  ),

                  const SizedBox(height: 12),

                  Expanded(
                    child: todayRecords.isEmpty
                        ? const Text(
                            "No trip records available",
                            style: TextStyle(color: AdminBranding.secondaryText),
                          )
                        : ListView.separated(
                            itemCount: todayRecords.length,
                            separatorBuilder: (_, __) =>
                                const Divider(color: AdminBranding.cardBorder),
                            itemBuilder: (context, index) {
                              final row = todayRecords[index];
                              return ListTile(
                                contentPadding: EdgeInsets.zero,
                                title: Text(
                                  "Driver: ${row["driver_name"] ?? "No Driver"}",
                                  style: const TextStyle(color: AdminBranding.primaryText),
                                ),
                                subtitle: Text(
                                  "Shift: ${row["shift"] ?? row["driver_shift"] ?? "-"}  Time: ${_timeText(row)}",
                                  style: const TextStyle(color: AdminBranding.secondaryText),
                                ),
                                trailing: Text(
                                  (row["trip_status"] ?? "IDLE").toString(),
                                  style: const TextStyle(
                                    color: AdminBranding.primaryText,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              );
                            },
                          ),
                  ),
                ],
              ),
            ),
    );
  }
}
