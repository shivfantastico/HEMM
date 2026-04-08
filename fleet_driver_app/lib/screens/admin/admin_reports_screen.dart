import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:open_filex/open_filex.dart';
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../services/api_service.dart';
import 'widgets/admin_branding.dart';

class AdminReportsScreen extends StatefulWidget {
  const AdminReportsScreen({super.key});

  @override
  State<AdminReportsScreen> createState() => _AdminReportsScreenState();
}

class _AdminReportsScreenState extends State<AdminReportsScreen> {
  final TextEditingController vehicleController = TextEditingController();
  DateTime? dateFrom;
  DateTime? dateTo;

  bool loading = true;
  bool exportingExcel = false;
  bool exportingPdf = false;
  Map<String, dynamic> summary = {};
  List<Map<String, dynamic>> topRefuelVehicles = [];
  List<Map<String, dynamic>> recentTrips = [];

  @override
  void initState() {
    super.initState();
    fetchReports();
  }

  @override
  void dispose() {
    vehicleController.dispose();
    super.dispose();
  }

  String _apiDate(DateTime date) {
    final m = date.month.toString().padLeft(2, "0");
    final d = date.day.toString().padLeft(2, "0");
    return "${date.year}-$m-$d";
  }

  String _displayDate(DateTime? date) {
    if (date == null) return "Select";
    final m = date.month.toString().padLeft(2, "0");
    final d = date.day.toString().padLeft(2, "0");
    return "$d-$m-${date.year}";
  }

  Future<void> _pickDate({required bool isFrom}) async {
    final picked = await showDatePicker(
      context: context,
      initialDate: (isFrom ? dateFrom : dateTo) ?? DateTime.now(),
      firstDate: DateTime(2020, 1, 1),
      lastDate: DateTime(2100, 12, 31),
    );
    if (picked == null) return;

    setState(() {
      if (isFrom) {
        dateFrom = picked;
        if (dateTo != null && dateTo!.isBefore(picked)) {
          dateTo = picked;
        }
      } else {
        dateTo = picked;
        if (dateFrom != null && dateFrom!.isAfter(picked)) {
          dateFrom = picked;
        }
      }
    });
  }

  Future<void> fetchReports() async {
    final params = _queryParams();

    final endpoint = params.isEmpty
        ? "/api/admin/reports"
        : "/api/admin/reports?${Uri(queryParameters: params).query}";

    final response = await ApiService.get(endpoint, auth: true);
    if (!mounted) return;

    if (response.statusCode != 200) {
      setState(() {
        loading = false;
        summary = {};
        topRefuelVehicles = [];
        recentTrips = [];
      });
      return;
    }

    final data = jsonDecode(response.body);
    setState(() {
      loading = false;
      summary = Map<String, dynamic>.from(data["summary"] ?? {});
      topRefuelVehicles = ((data["topRefuelVehicles"] ?? []) as List)
          .whereType<Map>()
          .map((e) => Map<String, dynamic>.from(e))
          .toList();
      recentTrips = ((data["recentTrips"] ?? []) as List)
          .whereType<Map>()
          .map((e) => Map<String, dynamic>.from(e))
          .toList();
    });
  }

  Map<String, String> _queryParams() {
    final params = <String, String>{};
    final vehicle = vehicleController.text.trim();

    if (vehicle.isNotEmpty) {
      params["vehicle"] = vehicle;
    }
    if (dateFrom != null) {
      params["date_from"] = _apiDate(dateFrom!);
    }
    if (dateTo != null) {
      params["date_to"] = _apiDate(dateTo!);
    }

    return params;
  }

  Future<void> _downloadReport(String format) async {
    if (format == "excel") {
      setState(() => exportingExcel = true);
    } else {
      setState(() => exportingPdf = true);
    }

    try {
      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString("token");

      final params = _queryParams();
      final uri = Uri.parse("${ApiService.baseUrl}/api/admin/reports/export/$format")
          .replace(queryParameters: params.isEmpty ? null : params);

      final response = await http.get(
        uri,
        headers: {
          if (token != null) "Authorization": "Bearer $token",
        },
      );

      if (response.statusCode != 200) {
        throw Exception("Export failed");
      }

      final dir = await getTemporaryDirectory();
      final timestamp = DateTime.now().toIso8601String().replaceAll(RegExp(r"[:.]"), "-");
      final ext = format == "excel" ? "xlsx" : "pdf";
      final file = File("${dir.path}/fleet-report-$timestamp.$ext");

      await file.writeAsBytes(response.bodyBytes);
      await OpenFilex.open(file.path);

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("${format.toUpperCase()} exported successfully")),
      );
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Failed to export ${format.toUpperCase()}")),
      );
    } finally {
      if (!mounted) return;
      if (format == "excel") {
        setState(() => exportingExcel = false);
      } else {
        setState(() => exportingPdf = false);
      }
    }
  }

  int _intValue(String key) {
    final value = summary[key];
    if (value is num) return value.toInt();
    return 0;
  }

  double _doubleValue(String key) {
    final value = summary[key];
    if (value is num) return value.toDouble();
    return 0;
  }

  void _resetFilters() {
    setState(() {
      vehicleController.clear();
      dateFrom = null;
      dateTo = null;
      loading = true;
    });
    fetchReports();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AdminBranding.background,
      appBar: AdminBranding.appBar(title: "Reports"),
      body: loading
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: fetchReports,
              child: ListView(
                padding: const EdgeInsets.all(12),
                children: [
                  _buildFilterCard(),
                  const SizedBox(height: 12),
                  _buildSummarySection(),
                  const SizedBox(height: 12),
                  _buildTopRefuelVehicles(),
                  const SizedBox(height: 12),
                  _buildRecentTrips(),
                ],
              ),
            ),
    );
  }

  Widget _buildFilterCard() {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AdminBranding.cardBorder),
      ),
      child: Column(
        children: [
          TextField(
            controller: vehicleController,
            style: const TextStyle(color: AdminBranding.primaryText),
            decoration: InputDecoration(
              labelText: "Vehicle (optional)",
              labelStyle: const TextStyle(color: AdminBranding.secondaryText),
              filled: true,
              fillColor: const Color(0xFFF7F8FA),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
                borderSide: BorderSide.none,
              ),
            ),
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(
                child: InkWell(
                  onTap: () => _pickDate(isFrom: true),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
                    decoration: BoxDecoration(
                      color: const Color(0xFFF7F8FA),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      "From: ${_displayDate(dateFrom)}",
                      style: const TextStyle(color: AdminBranding.primaryText),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: InkWell(
                  onTap: () => _pickDate(isFrom: false),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
                    decoration: BoxDecoration(
                      color: const Color(0xFFF7F8FA),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      "To: ${_displayDate(dateTo)}",
                      style: const TextStyle(color: AdminBranding.primaryText),
                    ),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(
                child: OutlinedButton(
                  onPressed: _resetFilters,
                  style: OutlinedButton.styleFrom(
                    foregroundColor: AdminBranding.primaryText,
                    side: const BorderSide(color: AdminBranding.cardBorder),
                    minimumSize: const Size.fromHeight(44),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  child: const Text("Reset"),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: ElevatedButton(
                  onPressed: () {
                    setState(() => loading = true);
                    fetchReports();
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFFCE1E2D),
                    foregroundColor: Colors.white,
                    minimumSize: const Size.fromHeight(44),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  child: const Text("Apply Filters"),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: exportingExcel ? null : () => _downloadReport("excel"),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: AdminBranding.primaryText,
                    side: const BorderSide(color: AdminBranding.cardBorder),
                    minimumSize: const Size.fromHeight(44),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  icon: const Icon(Icons.table_chart_outlined),
                  label: Text(exportingExcel ? "Exporting..." : "Export Excel"),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: exportingPdf ? null : () => _downloadReport("pdf"),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: AdminBranding.primaryText,
                    side: const BorderSide(color: AdminBranding.cardBorder),
                    minimumSize: const Size.fromHeight(44),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  icon: const Icon(Icons.picture_as_pdf_outlined),
                  label: Text(exportingPdf ? "Exporting..." : "Export PDF"),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildSummarySection() {
    return Column(
      children: [
        Row(
          children: [
            Expanded(
              child: _kpiCard("Total Trips", _intValue("totalTrips").toString()),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: _kpiCard("Completed Trips", _intValue("completedTrips").toString()),
            ),
          ],
        ),
        const SizedBox(height: 10),
        Row(
          children: [
            Expanded(
              child: _kpiCard("Active Trips", _intValue("activeTrips").toString()),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: _kpiCard("Total Refuels", _intValue("totalRefuels").toString()),
            ),
          ],
        ),
        const SizedBox(height: 10),
        Row(
          children: [
            Expanded(
              child: _kpiCard("Refuel Litres", _doubleValue("totalRefuelLitres").toStringAsFixed(2)),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: _kpiCard("Services", _intValue("totalServices").toString()),
            ),
          ],
        ),
        const SizedBox(height: 10),
        Row(
          children: [
            Expanded(
              child: _kpiCard("Svc Scheduled", _intValue("scheduledServices").toString()),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: _kpiCard("Svc Completed", _intValue("completedServices").toString()),
            ),
          ],
        ),
      ],
    );
  }

  Widget _kpiCard(String title, String value) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AdminBranding.cardBorder),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: const TextStyle(color: AdminBranding.secondaryText, fontSize: 12)),
          const SizedBox(height: 8),
          Text(
            value,
            style: const TextStyle(
              color: AdminBranding.primaryText,
              fontSize: 18,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTopRefuelVehicles() {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AdminBranding.cardBorder),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            "Top Refuel Vehicles",
            style: TextStyle(color: AdminBranding.primaryText, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 8),
          if (topRefuelVehicles.isEmpty)
            const Text("No data", style: TextStyle(color: AdminBranding.secondaryText))
          else
            ...topRefuelVehicles.map((row) {
              final vehicle = (row["vehicle_number"] ?? "-").toString();
              final litres = (row["total_litres"] ?? 0).toString();
              final count = (row["total_refuels"] ?? 0).toString();
              return Padding(
                padding: const EdgeInsets.symmetric(vertical: 4),
                child: Text(
                  "$vehicle  •  $litres L  •  $count refuels",
                  style: const TextStyle(color: AdminBranding.secondaryText),
                ),
              );
            }),
        ],
      ),
    );
  }

  Widget _buildRecentTrips() {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AdminBranding.cardBorder),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            "Recent Trips",
            style: TextStyle(color: AdminBranding.primaryText, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 8),
          if (recentTrips.isEmpty)
            const Text("No trips found", style: TextStyle(color: AdminBranding.secondaryText))
          else
            ...recentTrips.map((row) {
              final tripId = (row["trip_id"] ?? "-").toString();
              final vehicle = (row["vehicle_number"] ?? "-").toString();
              final driver = (row["driver_name"] ?? "-").toString();
              final status = (row["trip_status"] ?? "-").toString();
              final createdAt = (row["created_at"] ?? "-").toString();

              return Container(
                margin: const EdgeInsets.only(bottom: 8),
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: const Color(0xFFF7F8FA),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  "Trip #$tripId | $vehicle | $driver | $status | $createdAt",
                  style: const TextStyle(color: AdminBranding.secondaryText),
                ),
              );
            }),
        ],
      ),
    );
  }
}
