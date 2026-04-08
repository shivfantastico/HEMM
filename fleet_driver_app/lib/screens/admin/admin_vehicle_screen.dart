import 'dart:convert';
import 'package:flutter/material.dart';
import '../../services/api_service.dart';
import 'vehicle_detail_screen.dart';
import 'widgets/admin_branding.dart';

class AdminVehicleScreen extends StatefulWidget {
  const AdminVehicleScreen({super.key});

  @override
  State<AdminVehicleScreen> createState() => _AdminVehicleScreenState();
}

class _AdminVehicleScreenState extends State<AdminVehicleScreen> {
  Map<String, List<Map<String, dynamic>>> vehicleRecords = {};
  List<Map<String, dynamic>> uniqueVehicles = [];
  List<Map<String, dynamic>> vehicleTypes = [];

  bool loading = true;
  bool creatingVehicle = false;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    setState(() {
      loading = true;
    });

    await Future.wait([
      fetchVehicles(),
      fetchVehicleTypes(),
    ]);

    if (!mounted) return;
    setState(() {
      loading = false;
    });
  }

  Future<void> fetchVehicles() async {
    final response = await ApiService.get(
      "/api/admin/vehicles",
      auth: true,
    );

    if (!mounted) return;

    if (response.statusCode == 200) {
      final data = jsonDecode(response.body);
      final fetched = ((data["vehicles"] ?? []) as List)
          .whereType<Map>()
          .map((item) => Map<String, dynamic>.from(item))
          .toList();
      final grouped = <String, List<Map<String, dynamic>>>{};

      for (final vehicle in fetched) {
        final key = _vehicleKey(vehicle);
        grouped.putIfAbsent(key, () => []);
        grouped[key]!.add(vehicle);
      }

      final deduped = grouped.values
          .map(_pickPrimaryVehicleRecord)
          .toList()
        ..sort(
          (a, b) => (a["vehicle_number"] ?? "")
              .toString()
              .compareTo((b["vehicle_number"] ?? "").toString()),
        );

      setState(() {
        vehicleRecords = grouped;
        uniqueVehicles = deduped;
      });
    }
  }

  Future<void> fetchVehicleTypes() async {
    final response = await ApiService.get(
      "/api/admin/vehicle-types",
      auth: true,
    );

    if (!mounted) return;
    if (response.statusCode != 200) return;

    final data = jsonDecode(response.body);
    final fetched = ((data["vehicle_types"] ?? []) as List)
        .whereType<Map>()
        .map((item) => Map<String, dynamic>.from(item))
        .toList();

    setState(() {
      vehicleTypes = fetched;
    });
  }

  String _extractMessage(httpResponseBody) {
    try {
      final data = jsonDecode(httpResponseBody);
      if (data is Map && data["message"] != null) {
        return data["message"].toString();
      }
    } catch (_) {}
    return "Request failed";
  }

  Future<void> _createVehicle({
    required String vehicleNumber,
    required int vehicleTypeId,
  }) async {
    if (creatingVehicle) return;
    setState(() {
      creatingVehicle = true;
    });

    final response = await ApiService.post("/api/admin/vehicles", {
      "vehicle_number": vehicleNumber.trim().toUpperCase(),
      "vehicle_type_id": vehicleTypeId,
    }, auth: true);

    if (!mounted) return;
    setState(() {
      creatingVehicle = false;
    });

    if (response.statusCode == 201 || response.statusCode == 200) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Vehicle added successfully")),
      );
      await fetchVehicles();
      return;
    }

    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(_extractMessage(response.body))));
  }

  Future<void> _deleteVehicle(int vehicleId) async {
    final response = await ApiService.delete(
      "/api/admin/vehicles/$vehicleId",
      auth: true,
    );

    if (!mounted) return;

    if (response.statusCode == 200) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Vehicle deleted successfully")),
      );
      await fetchVehicles();
      return;
    }

    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(_extractMessage(response.body))));
  }

  Future<void> _showAddVehicleDialog() async {
    if (vehicleTypes.isEmpty) {
      await fetchVehicleTypes();
    }

    if (!mounted) return;

    if (vehicleTypes.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Vehicle types not found")),
      );
      return;
    }

    final vehicleNumberController = TextEditingController();
    int? selectedTypeId = vehicleTypes.first["id"] as int?;

    await showDialog(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setLocalState) {
            return AlertDialog(
              title: const Text("Add Vehicle"),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    TextField(
                      controller: vehicleNumberController,
                      decoration: const InputDecoration(
                        labelText: "Vehicle Number",
                        border: OutlineInputBorder(),
                      ),
                    ),
                    const SizedBox(height: 12),
                    DropdownButtonFormField<int>(
                      value: selectedTypeId,
                      decoration: const InputDecoration(
                        labelText: "Vehicle Type",
                        border: OutlineInputBorder(),
                      ),
                      items: vehicleTypes
                          .map(
                            (type) => DropdownMenuItem<int>(
                              value: type["id"] as int,
                              child: Text((type["name"] ?? "-").toString()),
                            ),
                          )
                          .toList(),
                      onChanged: (value) {
                        setLocalState(() {
                          selectedTypeId = value;
                        });
                      },
                    ),
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text("Cancel"),
                ),
                ElevatedButton(
                  onPressed: creatingVehicle
                      ? null
                      : () async {
                          final vehicleNumber = vehicleNumberController.text
                              .trim();
                          if (vehicleNumber.isEmpty || selectedTypeId == null) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                content: Text(
                                  "Vehicle number and vehicle type are required",
                                ),
                              ),
                            );
                            return;
                          }

                          Navigator.pop(context);
                          await _createVehicle(
                            vehicleNumber: vehicleNumber,
                            vehicleTypeId: selectedTypeId!,
                          );
                        },
                  child: Text(creatingVehicle ? "Adding..." : "Add"),
                ),
              ],
            );
          },
        );
      },
    );
  }

  Future<void> _confirmDeleteVehicle(Map<String, dynamic> vehicle) async {
    final id = vehicle["id"];
    if (id is! int) return;

    final shouldDelete = await showDialog<bool>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text("Delete Vehicle"),
          content: Text(
            "Delete vehicle ${(vehicle["vehicle_number"] ?? "-").toString()}?",
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text("Cancel"),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
              onPressed: () => Navigator.pop(context, true),
              child: const Text("Delete"),
            ),
          ],
        );
      },
    );

    if (shouldDelete == true) {
      await _deleteVehicle(id);
    }
  }

  Color getStatusColor(String? status) {
    if (status == "STARTED") {
      return Colors.green;
    }

    if (status == "SERVICE_DUE") {
      return Colors.red;
    }

    return Colors.orange;
  }

  String _vehicleKey(Map<String, dynamic> vehicle) {
    final number = vehicle["vehicle_number"];
    if (number != null && number.toString().trim().isNotEmpty) {
      return number.toString().trim().toUpperCase();
    }
    return "ID-${vehicle["id"] ?? ""}";
  }

  int _statusPriority(String? status) {
    if (status == "STARTED") return 3;
    if (status == "SERVICE_DUE") return 2;
    return 1;
  }

  DateTime? _extractDate(Map<String, dynamic> row) {
    final keys = [
      "trip_start_time",
      "trip_date",
      "updated_at",
      "created_at",
      "start_time",
    ];
    for (final key in keys) {
      final value = row[key];
      if (value == null) continue;
      if (value is String) {
        final parsed = DateTime.tryParse(value);
        if (parsed != null) return parsed;
      }
    }
    return null;
  }

  Map<String, dynamic> _pickPrimaryVehicleRecord(
    List<Map<String, dynamic>> records,
  ) {
    if (records.isEmpty) return {};
    records.sort((a, b) {
      final aDate = _extractDate(a);
      final bDate = _extractDate(b);
      if (aDate != null && bDate != null) {
        final byDate = bDate.compareTo(aDate);
        if (byDate != 0) return byDate;
      }
      return _statusPriority(b["trip_status"]?.toString())
          .compareTo(_statusPriority(a["trip_status"]?.toString()));
    });
    return records.first;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AdminBranding.appBar(
        title: "Vehicle Monitoring",
        actions: [
          IconButton(
            onPressed: _showAddVehicleDialog,
            icon: const Icon(Icons.add),
            tooltip: "Add Vehicle",
          ),
          IconButton(
            onPressed: _loadData,
            icon: const Icon(Icons.refresh),
            tooltip: "Refresh",
          ),
        ],
      ),
      backgroundColor: AdminBranding.background,
      body: loading
          ? const Center(child: CircularProgressIndicator())
          : GridView.builder(
              padding: const EdgeInsets.all(16),
              itemCount: uniqueVehicles.length,
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 2,
                mainAxisSpacing: 16,
                crossAxisSpacing: 16,
                childAspectRatio: 1.2,
              ),
              itemBuilder: (context, index) {
                final vehicle = uniqueVehicles[index];
                final key = _vehicleKey(vehicle);

                return GestureDetector(
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => VehicleDetailScreen(
                          vehicleId: vehicle["id"],
                          vehicleNumber:
                              (vehicle["vehicle_number"] ?? "-").toString(),
                          vehicleRecords:
                              vehicleRecords[key] ?? <Map<String, dynamic>>[],
                        ),
                      ),
                    );
                  },
                  child: Container(
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: getStatusColor(vehicle["trip_status"]?.toString()),
                        width: 2,
                      ),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.end,
                          children: [
                            IconButton(
                              padding: EdgeInsets.zero,
                              constraints: const BoxConstraints(),
                              onPressed: () => _confirmDeleteVehicle(vehicle),
                              icon: const Icon(
                                Icons.delete_outline,
                                color: Colors.redAccent,
                              ),
                              tooltip: "Delete Vehicle",
                            ),
                          ],
                        ),
                        Expanded(
                          child: Center(
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                FittedBox(
                                  fit: BoxFit.scaleDown,
                                  child: Text(
                                    (vehicle["vehicle_number"] ?? "").toString(),
                                    style: const TextStyle(
                                      fontSize: 22,
                                      fontWeight: FontWeight.bold,
                                      color: Color(0xFF1E2432),
                                    ),
                                    textAlign: TextAlign.center,
                                  ),
                                ),
                                const SizedBox(height: 8),
                                Text(
                                  (vehicle["vehicle_type"] ?? "-").toString(),
                                  style: const TextStyle(
                                    color: Color(0xFF5F6A80),
                                    fontSize: 12,
                                  ),
                                  textAlign: TextAlign.center,
                                ),
                              ],
                            ),
                          ),
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
