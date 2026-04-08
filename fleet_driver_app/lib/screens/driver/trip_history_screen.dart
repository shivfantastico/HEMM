import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../services/api_service.dart';

class TripHistoryScreen extends StatefulWidget {
  const TripHistoryScreen({super.key});

  @override
  State<TripHistoryScreen> createState() => _TripHistoryScreenState();
}

class _TripHistoryScreenState extends State<TripHistoryScreen> {
  bool loading = true;
  List trips = [];

  DateTime? _extractTripDate(Map<String, dynamic> trip) {
    final possibleKeys = [
      "date",
      "trip_date",
      "created_at",
      "start_time",
      "started_at",
      "start_date",
      "trip_start_time",
      "createdAt",
    ];

    for (final key in possibleKeys) {
      final value = trip[key];
      if (value == null) continue;
      if (value is String && value.isNotEmpty) {
        final parsed = DateTime.tryParse(value);
        if (parsed != null) return parsed;

        try {
          return DateFormat('dd-MM-yyyy').parseStrict(value);
        } catch (_) {}
        try {
          return DateFormat('dd-MM-yyyy HH:mm').parseStrict(value);
        } catch (_) {}
      }
    }
    return null;
  }

  String _tripDateText(Map<String, dynamic> trip) {
    final tripDate = _extractTripDate(trip);
    if (tripDate == null) return "-";
    return DateFormat('dd-MM-yyyy HH:mm').format(tripDate.toLocal());
  }

  bool _isTripFromLast24Hours(Map<String, dynamic> trip) {
    final tripDate = _extractTripDate(trip);
    if (tripDate == null) return false;
    final localTripDate = tripDate.toLocal();
    final now = DateTime.now();
    final difference = now.difference(localTripDate);
    return !difference.isNegative && difference < const Duration(hours: 24);
  }

  String _tripVehicleText(Map<String, dynamic> trip) {
    final vehicle = trip["vehicle"];
    if (vehicle is Map && vehicle["vehicle_number"] != null) {
      return vehicle["vehicle_number"].toString();
    }
    if (trip["vehicle_number"] != null) {
      return trip["vehicle_number"].toString();
    }
    return "Unknown Vehicle";
  }

  List<Map<String, dynamic>> _tripReadingRows(Map<String, dynamic> trip) {
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

  String _tripTotalKmText(Map<String, dynamic> trip) {
    if (trip["total_km"] != null) {
      return _formatValue(trip["total_km"]);
    }

    for (final reading in _tripReadingRows(trip)) {
      final name = (reading["name"] ?? "").toString().toLowerCase();
      if (name.contains("km") || name.contains("kilometer") || name.contains("odometer")) {
        final used = reading["used_value"];
        if (used != null) return _formatValue(used);
      }
    }

    return "-";
  }

  String _tripReadingsText(Map<String, dynamic> trip) {
    final readings = _tripReadingRows(trip);
    if (readings.isEmpty) return "Readings: -";

    final lines = <String>[];
    for (final reading in readings) {
      final name = (reading["name"] ?? "Reading").toString();
      final unit = (reading["unit"] ?? "").toString();
      final startValue = _formatValue(reading["start_value"]);
      final endValue = _formatValue(reading["end_value"]);
      final usedValue = _formatValue(reading["used_value"]);
      final unitSuffix = unit.isEmpty ? "" : " $unit";

      lines.add("$name: $usedValue$unitSuffix ($startValue -> $endValue)");
    }

    return lines.join("\n");
  }

  @override
  void initState() {
    super.initState();
    fetchTripHistory();
  }

  Future<void> fetchTripHistory() async {
    setState(() => loading = true);

    try {
      final response = await ApiService.get("/api/trip/history", auth: true);

      if (!mounted) return;

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        List<dynamic> parsedTrips = [];
        if (data["trips"] is List) {
          parsedTrips = data["trips"];
        } else if (data["data"] is List) {
          parsedTrips = data["data"];
        } else if (data["history"] is List) {
          parsedTrips = data["history"];
        }

        setState(() {
          trips = parsedTrips;
          loading = false;
        });
        return;
      }

      String message = "Unable to load trip history";
      try {
        final body = jsonDecode(response.body);
        if (body is Map && body["message"] != null) {
          message = body["message"].toString();
        }
      } catch (_) {}

      setState(() {
        trips = [];
        loading = false;
      });

      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));
    } catch (_) {
      if (!mounted) return;
      setState(() {
        trips = [];
        loading = false;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Network error while loading trips")),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final allTrips = trips
        .whereType<Map>()
        .map((t) => Map<String, dynamic>.from(t))
        .toList();
    final recentTrips = allTrips.where(_isTripFromLast24Hours).toList();

    return Scaffold(
      appBar: AppBar(
        title: const Text("Trip History"),
        backgroundColor: const Color(0xFFCE1E2D),
      ),
      body: loading
          ? const Center(child: CircularProgressIndicator())
          : recentTrips.isEmpty
              ? const Center(
                  child: Text(
                    "No trips in the last 24 hours",
                    style: TextStyle(fontSize: 16),
                  ),
                )
              : ListView.builder(
                  padding: const EdgeInsets.all(16),
                  itemCount: recentTrips.length,
                  itemBuilder: (context, index) {
                    final trip = recentTrips[index];
                    return Card(
                      margin: const EdgeInsets.only(bottom: 12),
                      child: Padding(
                        padding: const EdgeInsets.all(16),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                const Icon(Icons.local_shipping, color: Color(0xFFCE1E2D)),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: Text(
                                    _tripVehicleText(trip),
                                    style: const TextStyle(
                                      fontSize: 16,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 8),
                            Text(
                              "Date: ${_tripDateText(trip)}",
                              style: const TextStyle(color: Colors.black54),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              "Status: ${trip["trip_status"] ?? "-"}",
                              style: const TextStyle(color: Colors.black54),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              "Total KM: ${_tripTotalKmText(trip)}",
                              style: const TextStyle(
                                fontWeight: FontWeight.w600,
                                color: Color(0xFF1E8D4A),
                              ),
                            ),
                            const SizedBox(height: 8),
                            Text(
                              _tripReadingsText(trip),
                              style: const TextStyle(fontSize: 14),
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                ),
    );
  }
}
