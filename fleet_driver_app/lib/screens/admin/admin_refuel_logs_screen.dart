import 'dart:convert';
import 'package:flutter/material.dart';
import '../../services/api_service.dart';
import 'widgets/admin_branding.dart';

class AdminRefuelLogsScreen extends StatefulWidget {
  const AdminRefuelLogsScreen({super.key});

  @override
  State<AdminRefuelLogsScreen> createState() => _AdminRefuelLogsScreenState();
}

class _AdminRefuelLogsScreenState extends State<AdminRefuelLogsScreen> {
  List<dynamic> logs = [];
  bool loading = true;
  double totalLitres = 0;
  int totalLogs = 0;

  final TextEditingController vehicleController = TextEditingController();
  final TextEditingController driverController = TextEditingController();
  DateTime? dateFrom;
  DateTime? dateTo;

  @override
  void initState() {
    super.initState();
    fetchRefuelLogs();
  }

  @override
  void dispose() {
    vehicleController.dispose();
    driverController.dispose();
    super.dispose();
  }

  Future<void> fetchRefuelLogs() async {
    final params = <String, String>{};

    final vehicle = vehicleController.text.trim();
    final driver = driverController.text.trim();

    if (vehicle.isNotEmpty) {
      params['vehicle'] = vehicle;
    }
    if (driver.isNotEmpty) {
      params['driver'] = driver;
    }
    if (dateFrom != null) {
      params['date_from'] = _apiDate(dateFrom!);
    }
    if (dateTo != null) {
      params['date_to'] = _apiDate(dateTo!);
    }

    final endpoint = params.isEmpty
        ? '/api/admin/refuel-logs'
        : '/api/admin/refuel-logs?${Uri(queryParameters: params).query}';

    final response = await ApiService.get(endpoint, auth: true);

    if (!mounted) return;

    if (response.statusCode == 200) {
      final data = jsonDecode(response.body);
      final summary = data['summary'] ?? {};
      setState(() {
        logs = data['refuels'] ?? [];
        totalLitres = (summary['totalLitres'] ?? 0).toDouble();
        totalLogs = summary['totalLogs'] ?? logs.length;
        loading = false;
      });
      return;
    }

    setState(() {
      logs = [];
      totalLitres = 0;
      totalLogs = 0;
      loading = false;
    });
  }

  String _apiDate(DateTime date) {
    final month = date.month.toString().padLeft(2, '0');
    final day = date.day.toString().padLeft(2, '0');
    return '${date.year}-$month-$day';
  }

  String _displayDate(DateTime? date) {
    if (date == null) return 'Select';
    final month = date.month.toString().padLeft(2, '0');
    final day = date.day.toString().padLeft(2, '0');
    return '$day-$month-${date.year}';
  }

  String _safeText(dynamic value, {String fallback = '-'}) {
    if (value == null) return fallback;
    final text = value.toString().trim();
    return text.isEmpty ? fallback : text;
  }

  String _photoUrl(dynamic photoPath) {
    final path = _safeText(photoPath, fallback: '');
    if (path.isEmpty) return '';
    if (path.startsWith('http://') || path.startsWith('https://')) {
      return path;
    }

    final normalized = path.replaceAll('\\', '/');
    if (normalized.startsWith('/')) {
      return '${ApiService.baseUrl}$normalized';
    }

    return '${ApiService.baseUrl}/$normalized';
  }

  Future<void> _pickDate({required bool isFrom}) async {
    final current = isFrom ? dateFrom : dateTo;
    final picked = await showDatePicker(
      context: context,
      initialDate: current ?? DateTime.now(),
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

  void _resetFilters() {
    setState(() {
      vehicleController.clear();
      driverController.clear();
      dateFrom = null;
      dateTo = null;
      loading = true;
    });
    fetchRefuelLogs();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AdminBranding.background,
      appBar: AdminBranding.appBar(title: 'Refuel Logs'),
      body: RefreshIndicator(
        onRefresh: fetchRefuelLogs,
        child: ListView(
          padding: const EdgeInsets.all(12),
          children: [
            Container(
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
                        child: _FilterTextField(
                          controller: vehicleController,
                          label: 'Vehicle',
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: _FilterTextField(
                          controller: driverController,
                          label: 'Driver',
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  Row(
                    children: [
                      Expanded(
                        child: _DateButton(
                          label: 'From',
                          value: _displayDate(dateFrom),
                          onTap: () => _pickDate(isFrom: true),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: _DateButton(
                          label: 'To',
                          value: _displayDate(dateTo),
                          onTap: () => _pickDate(isFrom: false),
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
                          child: const Text('Reset'),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: ElevatedButton(
                          onPressed: () {
                            setState(() => loading = true);
                            fetchRefuelLogs();
                          },
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFFCE1E2D),
                            foregroundColor: Colors.white,
                            minimumSize: const Size.fromHeight(44),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),
                          child: const Text('Apply Filters'),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: AdminBranding.cardBorder),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text(
                    'Total Litres',
                    style: TextStyle(color: AdminBranding.secondaryText),
                  ),
                  Text(
                    totalLitres.toStringAsFixed(2),
                    style: const TextStyle(
                      color: AdminBranding.primaryText,
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  Text(
                    'Logs: $totalLogs',
                    style: const TextStyle(color: AdminBranding.secondaryText),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),
            if (loading)
              const Padding(
                padding: EdgeInsets.only(top: 48),
                child: Center(child: CircularProgressIndicator()),
              )
            else if (logs.isEmpty)
              const Padding(
                padding: EdgeInsets.only(top: 48),
                child: Center(
                  child: Text(
                    'No refuel logs found',
                    style: TextStyle(color: AdminBranding.secondaryText),
                  ),
                ),
              )
            else
              ...logs.map((log) {
                final litre = _safeText(log['litre']);
                final vehicle = _safeText(log['vehicle_number']);
                final driver = _safeText(log['driver_name']);
                final tripId = _safeText(log['trip_id']);
                final createdAt = _safeText(log['created_at']);
                final photoUrl = _photoUrl(log['photo']);

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
                        Text(
                          'Vehicle: $vehicle',
                          style: const TextStyle(
                            color: AdminBranding.primaryText,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 6),
                        Text(
                          'Driver: $driver',
                          style: const TextStyle(color: AdminBranding.secondaryText),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'Trip ID: $tripId',
                          style: const TextStyle(color: AdminBranding.secondaryText),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'Litres: $litre',
                          style: const TextStyle(color: AdminBranding.secondaryText),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'Logged at: $createdAt',
                          style: const TextStyle(color: AdminBranding.secondaryText),
                        ),
                        if (photoUrl.isNotEmpty) ...[
                          const SizedBox(height: 10),
                          InkWell(
                            onTap: () {
                              showDialog<void>(
                                context: context,
                                builder: (_) => Dialog(
                                  backgroundColor: Colors.white,
                                  child: InteractiveViewer(
                                    child: Image.network(photoUrl),
                                  ),
                                ),
                              );
                            },
                            child: ClipRRect(
                              borderRadius: BorderRadius.circular(8),
                              child: Image.network(
                                photoUrl,
                                height: 140,
                                width: double.infinity,
                                fit: BoxFit.cover,
                                errorBuilder: (_, __, ___) {
                                  return Container(
                                    height: 120,
                                    color: Colors.black12,
                                    alignment: Alignment.center,
                                    child: const Text(
                                      'Image unavailable',
                                      style: TextStyle(
                                        color: AdminBranding.secondaryText,
                                      ),
                                    ),
                                  );
                                },
                              ),
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                );
              }),
          ],
        ),
      ),
    );
  }
}

class _FilterTextField extends StatelessWidget {
  final TextEditingController controller;
  final String label;

  const _FilterTextField({
    required this.controller,
    required this.label,
  });

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: controller,
      style: const TextStyle(color: AdminBranding.primaryText),
      decoration: InputDecoration(
        labelText: label,
        labelStyle: const TextStyle(color: AdminBranding.secondaryText),
        filled: true,
        fillColor: const Color(0xFFF7F8FA),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: BorderSide.none,
        ),
      ),
    );
  }
}

class _DateButton extends StatelessWidget {
  final String label;
  final String value;
  final VoidCallback onTap;

  const _DateButton({
    required this.label,
    required this.value,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
        decoration: BoxDecoration(
          color: const Color(0xFFF7F8FA),
          borderRadius: BorderRadius.circular(10),
        ),
        child: Row(
          children: [
            Text(
              '$label: ',
              style: const TextStyle(color: AdminBranding.secondaryText),
            ),
            Expanded(
              child: Text(
                value,
                textAlign: TextAlign.right,
                style: const TextStyle(color: AdminBranding.primaryText),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
