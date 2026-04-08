import 'dart:convert';
import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';

import '../../services/api_service.dart';
import 'widgets/admin_branding.dart';

class AdminServiceSchedulerScreen extends StatefulWidget {
  const AdminServiceSchedulerScreen({super.key});

  @override
  State<AdminServiceSchedulerScreen> createState() =>
      _AdminServiceSchedulerScreenState();
}

class _AdminServiceSchedulerScreenState
    extends State<AdminServiceSchedulerScreen> {
  final TextEditingController vehicleFilterController = TextEditingController();
  final TextEditingController serviceTypeController = TextEditingController();
  final TextEditingController notesController = TextEditingController();

  DateTime? filterDateFrom;
  DateTime? filterDateTo;
  String filterStatus = "ALL";

  List<Map<String, dynamic>> schedules = [];
  List<Map<String, dynamic>> vehicles = [];
  int? selectedVehicleId;
  DateTime? selectedScheduleDate;

  int totalSchedules = 0;
  int scheduledCount = 0;
  int completedCount = 0;
  int overdueCount = 0;

  bool loading = true;
  bool creating = false;
  bool importingRules = false;

  @override
  void initState() {
    super.initState();
    _loadInitial();
  }

  @override
  void dispose() {
    vehicleFilterController.dispose();
    serviceTypeController.dispose();
    notesController.dispose();
    super.dispose();
  }

  Future<void> _loadInitial() async {
    setState(() => loading = true);
    await Future.wait([
      fetchVehicles(),
      fetchSchedules(),
    ]);
    if (!mounted) return;
    setState(() => loading = false);
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

  Future<void> fetchVehicles() async {
    final response = await ApiService.get("/api/admin/vehicles", auth: true);
    if (response.statusCode != 200) return;

    final data = jsonDecode(response.body);
    final fetched = ((data["vehicles"] ?? []) as List)
        .whereType<Map>()
        .map((e) => Map<String, dynamic>.from(e))
        .toList();

    final unique = <String, Map<String, dynamic>>{};
    for (final row in fetched) {
      final id = row["id"];
      final number = (row["vehicle_number"] ?? "").toString().trim();
      if (id == null || number.isEmpty) continue;
      unique.putIfAbsent(number.toUpperCase(), () => row);
    }

    final list = unique.values.toList()
      ..sort((a, b) => (a["vehicle_number"] ?? "")
          .toString()
          .compareTo((b["vehicle_number"] ?? "").toString()));

    if (!mounted) return;
    setState(() {
      vehicles = list;
      selectedVehicleId ??= vehicles.isNotEmpty ? vehicles.first["id"] as int : null;
    });
  }

  Future<void> fetchSchedules() async {
    final params = <String, String>{};
    final vehicleFilter = vehicleFilterController.text.trim();

    if (vehicleFilter.isNotEmpty) {
      params["vehicle"] = vehicleFilter;
    }
    if (filterStatus != "ALL") {
      params["status"] = filterStatus;
    }
    if (filterDateFrom != null) {
      params["date_from"] = _apiDate(filterDateFrom!);
    }
    if (filterDateTo != null) {
      params["date_to"] = _apiDate(filterDateTo!);
    }

    final endpoint = params.isEmpty
        ? "/api/admin/service-schedules"
        : "/api/admin/service-schedules?${Uri(queryParameters: params).query}";

    final response = await ApiService.get(endpoint, auth: true);
    if (!mounted) return;

    if (response.statusCode != 200) {
      setState(() {
        schedules = [];
        totalSchedules = 0;
        scheduledCount = 0;
        completedCount = 0;
        overdueCount = 0;
      });
      return;
    }

    final data = jsonDecode(response.body);
    final summary = Map<String, dynamic>.from(data["summary"] ?? {});
    final fetched = ((data["schedules"] ?? []) as List)
        .whereType<Map>()
        .map((e) => Map<String, dynamic>.from(e))
        .toList();

    setState(() {
      schedules = fetched;
      totalSchedules = summary["totalSchedules"] ?? 0;
      scheduledCount = summary["scheduledCount"] ?? 0;
      completedCount = summary["completedCount"] ?? 0;
      overdueCount = summary["overdueCount"] ?? 0;
    });
  }

  Future<void> _pickFilterDate({required bool isFrom}) async {
    final picked = await showDatePicker(
      context: context,
      initialDate: (isFrom ? filterDateFrom : filterDateTo) ?? DateTime.now(),
      firstDate: DateTime(2020, 1, 1),
      lastDate: DateTime(2100, 12, 31),
    );
    if (picked == null) return;

    setState(() {
      if (isFrom) {
        filterDateFrom = picked;
        if (filterDateTo != null && filterDateTo!.isBefore(picked)) {
          filterDateTo = picked;
        }
      } else {
        filterDateTo = picked;
        if (filterDateFrom != null && filterDateFrom!.isAfter(picked)) {
          filterDateFrom = picked;
        }
      }
    });
  }

  Future<void> _pickScheduleDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: selectedScheduleDate ?? DateTime.now(),
      firstDate: DateTime(2020, 1, 1),
      lastDate: DateTime(2100, 12, 31),
    );
    if (picked == null) return;
    setState(() => selectedScheduleDate = picked);
  }

  Future<void> _createSchedule() async {
    final serviceType = serviceTypeController.text.trim();
    if (selectedVehicleId == null || serviceType.isEmpty || selectedScheduleDate == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Vehicle, service type and date are required")),
      );
      return;
    }

    setState(() => creating = true);

    final response = await ApiService.post(
      "/api/admin/service-schedules",
      {
        "vehicle_id": selectedVehicleId,
        "service_type": serviceType,
        "scheduled_date": _apiDate(selectedScheduleDate!),
        "notes": notesController.text.trim().isEmpty ? null : notesController.text.trim(),
      },
      auth: true,
    );

    if (!mounted) return;

    setState(() => creating = false);

    if (response.statusCode == 200) {
      serviceTypeController.clear();
      notesController.clear();
      setState(() => selectedScheduleDate = null);
      await fetchSchedules();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Service schedule created")),
      );
      return;
    }

    String message = "Failed to create schedule";
    try {
      final data = jsonDecode(response.body);
      if (data["message"] != null) {
        message = data["message"].toString();
      }
    } catch (_) {}

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message)),
    );
  }

  Future<void> _updateStatus(int id, String status) async {
    final response = await ApiService.patch(
      "/api/admin/service-schedules/$id/status",
      {"status": status},
      auth: true,
    );

    if (!mounted) return;

    if (response.statusCode == 200) {
      await fetchSchedules();
      return;
    }

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text("Failed to update status")),
    );
  }

  Future<void> _importMaintenanceRulesFromExcel() async {
    if (importingRules) return;

    final picked = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: const ["xlsx", "xls"],
      withData: false,
    );

    if (picked == null || picked.files.isEmpty) return;

    final path = picked.files.single.path;
    if (path == null || path.trim().isEmpty) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Unable to read selected file path")),
      );
      return;
    }

    setState(() => importingRules = true);

    final response = await ApiService.multipartPost(
      "/api/admin/maintenance-rules/import",
      {},
      file: File(path),
      fileField: "file",
      auth: true,
    );

    if (!mounted) return;

    setState(() => importingRules = false);

    if (response.statusCode == 200) {
      int insertedCount = 0;
      int failedCount = 0;

      try {
        final data = jsonDecode(response.body);
        insertedCount = data["inserted_count"] ?? 0;
        failedCount = data["failed_count"] ?? 0;
      } catch (_) {}

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            "Import complete. Inserted: $insertedCount, Failed: $failedCount",
          ),
        ),
      );
      return;
    }

    String message = "Failed to import maintenance rules";
    try {
      final data = jsonDecode(response.body);
      if (data["message"] != null) {
        message = data["message"].toString();
      }
    } catch (_) {}

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message)),
    );
  }

  void _resetFilters() {
    setState(() {
      vehicleFilterController.clear();
      filterDateFrom = null;
      filterDateTo = null;
      filterStatus = "ALL";
    });
    fetchSchedules();
  }

  Color _statusColor(String status) {
    switch (status) {
      case "COMPLETED":
        return Colors.green;
      case "OVERDUE":
        return Colors.redAccent;
      case "CANCELLED":
        return Colors.grey;
      default:
        return Colors.orangeAccent;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AdminBranding.background,
      appBar: AdminBranding.appBar(title: "Service Scheduler"),
      body: loading
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: fetchSchedules,
              child: ListView(
                padding: const EdgeInsets.all(12),
                children: [
                  _buildMaintenanceImportCard(),
                  const SizedBox(height: 12),
                  _buildCreateCard(),
                  const SizedBox(height: 12),
                  _buildSummaryCard(),
                  const SizedBox(height: 12),
                  _buildFilterCard(),
                  const SizedBox(height: 12),
                  if (schedules.isEmpty)
                    const Padding(
                      padding: EdgeInsets.only(top: 40),
                      child: Center(
                        child: Text(
                          "No service schedules found",
                          style: TextStyle(color: AdminBranding.secondaryText),
                        ),
                      ),
                    )
                  else
                    ...schedules.map((row) => _buildScheduleCard(row)),
                ],
              ),
            ),
    );
  }

  Widget _buildMaintenanceImportCard() {
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
          const Row(
            children: [
              Icon(Icons.upload_file_outlined, color: Color(0xFFCE1E2D)),
              SizedBox(width: 8),
              Text(
                "Import Maintenance Rules",
                style: TextStyle(
                  color: AdminBranding.primaryText,
                  fontWeight: FontWeight.bold,
                  fontSize: 16,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          const Text(
            "Upload Excel file with maintenance parameter intervals by vehicle type.",
            style: TextStyle(color: AdminBranding.secondaryText),
          ),
          const SizedBox(height: 10),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: importingRules ? null : _importMaintenanceRulesFromExcel,
              icon: const Icon(Icons.upload_outlined),
              label: Text(importingRules ? "Importing..." : "Upload Excel & Import"),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFFCE1E2D),
                foregroundColor: Colors.white,
                minimumSize: const Size.fromHeight(44),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCreateCard() {
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
            "Create Schedule",
            style: TextStyle(
              color: AdminBranding.primaryText,
              fontWeight: FontWeight.bold,
              fontSize: 16,
            ),
          ),
          const SizedBox(height: 10),
          DropdownButtonFormField<int>(
            value: selectedVehicleId,
            dropdownColor: Colors.white,
            decoration: const InputDecoration(
              labelText: "Vehicle",
              labelStyle: TextStyle(color: AdminBranding.secondaryText),
              filled: true,
              fillColor: Color(0xFFF7F8FA),
              border: OutlineInputBorder(borderSide: BorderSide.none),
            ),
            items: vehicles
                .map(
                  (v) => DropdownMenuItem<int>(
                    value: v["id"] as int,
                    child: Text(
                      (v["vehicle_number"] ?? "-").toString(),
                      style: const TextStyle(color: AdminBranding.primaryText),
                    ),
                  ),
                )
                .toList(),
            onChanged: (value) => setState(() => selectedVehicleId = value),
          ),
          const SizedBox(height: 10),
          TextField(
            controller: serviceTypeController,
            style: const TextStyle(color: AdminBranding.primaryText),
            decoration: InputDecoration(
              labelText: "Service Type",
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
          InkWell(
            onTap: _pickScheduleDate,
            child: Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
              decoration: BoxDecoration(
                color: const Color(0xFFF7F8FA),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                "Scheduled Date: ${_displayDate(selectedScheduleDate)}",
                style: const TextStyle(color: AdminBranding.primaryText),
              ),
            ),
          ),
          const SizedBox(height: 10),
          TextField(
            controller: notesController,
            maxLines: 2,
            style: const TextStyle(color: AdminBranding.primaryText),
            decoration: InputDecoration(
              labelText: "Notes (optional)",
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
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: creating ? null : _createSchedule,
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFFCE1E2D),
                foregroundColor: Colors.white,
                minimumSize: const Size.fromHeight(44),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              child: Text(creating ? "Creating..." : "Create Service Schedule"),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSummaryCard() {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AdminBranding.cardBorder),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          _summaryTile("Total", totalSchedules.toString()),
          _summaryTile("Scheduled", scheduledCount.toString()),
          _summaryTile("Completed", completedCount.toString()),
          _summaryTile("Overdue", overdueCount.toString()),
        ],
      ),
    );
  }

  Widget _summaryTile(String title, String value) {
    return Column(
      children: [
        Text(title, style: const TextStyle(color: AdminBranding.secondaryText, fontSize: 12)),
        const SizedBox(height: 4),
        Text(
          value,
          style: const TextStyle(
            color: AdminBranding.primaryText,
            fontWeight: FontWeight.bold,
            fontSize: 16,
          ),
        ),
      ],
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
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: vehicleFilterController,
                  style: const TextStyle(color: AdminBranding.primaryText),
                  decoration: InputDecoration(
                    labelText: "Filter Vehicle",
                    labelStyle: const TextStyle(color: AdminBranding.secondaryText),
                    filled: true,
                    fillColor: const Color(0xFFF7F8FA),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                      borderSide: BorderSide.none,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: DropdownButtonFormField<String>(
                  value: filterStatus,
                  dropdownColor: Colors.white,
                  decoration: const InputDecoration(
                    labelText: "Status",
                    labelStyle: TextStyle(color: AdminBranding.secondaryText),
                    filled: true,
                    fillColor: Color(0xFFF7F8FA),
                    border: OutlineInputBorder(borderSide: BorderSide.none),
                  ),
                  items: const [
                    DropdownMenuItem(value: "ALL", child: Text("All")),
                    DropdownMenuItem(value: "SCHEDULED", child: Text("Scheduled")),
                    DropdownMenuItem(value: "COMPLETED", child: Text("Completed")),
                    DropdownMenuItem(value: "OVERDUE", child: Text("Overdue")),
                    DropdownMenuItem(value: "CANCELLED", child: Text("Cancelled")),
                  ],
                  onChanged: (value) {
                    if (value == null) return;
                    setState(() => filterStatus = value);
                  },
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(
                child: InkWell(
                  onTap: () => _pickFilterDate(isFrom: true),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
                    decoration: BoxDecoration(
                      color: const Color(0xFFF7F8FA),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      "From: ${_displayDate(filterDateFrom)}",
                      style: const TextStyle(color: AdminBranding.primaryText),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: InkWell(
                  onTap: () => _pickFilterDate(isFrom: false),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
                    decoration: BoxDecoration(
                      color: const Color(0xFFF7F8FA),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      "To: ${_displayDate(filterDateTo)}",
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
                  onPressed: fetchSchedules,
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
        ],
      ),
    );
  }

  Widget _buildScheduleCard(Map<String, dynamic> row) {
    final id = row["id"] as int?;
    final vehicle = (row["vehicle_number"] ?? "-").toString();
    final equipment = (row["equipment_name"] ?? "-").toString();
    final serviceType = (row["service_type"] ?? "-").toString();
    final scheduledDate = (row["scheduled_date"] ?? "-").toString();
    final status = (row["status"] ?? "SCHEDULED").toString();
    final notes = (row["notes"] ?? "").toString();

    return Card(
      color: Colors.white,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: const BorderSide(color: AdminBranding.cardBorder),
      ),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    "Vehicle: $vehicle",
                    style: const TextStyle(
                      color: AdminBranding.primaryText,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: _statusColor(status).withOpacity(0.15),
                    borderRadius: BorderRadius.circular(30),
                  ),
                  child: Text(
                    status,
                    style: TextStyle(
                      color: _statusColor(status),
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 6),
            Text("Equipment: $equipment", style: const TextStyle(color: AdminBranding.secondaryText)),
            const SizedBox(height: 4),
            Text("Service: $serviceType", style: const TextStyle(color: AdminBranding.secondaryText)),
            const SizedBox(height: 4),
            Text("Date: $scheduledDate", style: const TextStyle(color: AdminBranding.secondaryText)),
            if (notes.trim().isNotEmpty) ...[
              const SizedBox(height: 4),
              Text("Notes: $notes", style: const TextStyle(color: AdminBranding.secondaryText)),
            ],
            const SizedBox(height: 10),
            if (id != null)
              DropdownButtonFormField<String>(
                value: status,
                dropdownColor: Colors.white,
                decoration: InputDecoration(
                  isDense: true,
                  filled: true,
                  fillColor: const Color(0xFFF7F8FA),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                    borderSide: BorderSide.none,
                  ),
                ),
                items: const [
                  DropdownMenuItem(value: "SCHEDULED", child: Text("SCHEDULED")),
                  DropdownMenuItem(value: "COMPLETED", child: Text("COMPLETED")),
                  DropdownMenuItem(value: "OVERDUE", child: Text("OVERDUE")),
                  DropdownMenuItem(value: "CANCELLED", child: Text("CANCELLED")),
                ],
                onChanged: (value) {
                  if (value == null || value == status) return;
                  _updateStatus(id, value);
                },
              ),
          ],
        ),
      ),
    );
  }
}
