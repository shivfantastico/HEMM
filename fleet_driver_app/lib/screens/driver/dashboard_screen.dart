import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:image_picker/image_picker.dart';
import 'package:geolocator/geolocator.dart';
import '../../services/api_service.dart';
import 'trip_started_screen.dart';
import 'scan_qr_screen.dart';

class DashboardScreen extends StatefulWidget {
  final String driverName;
  final int driverId;

  const DashboardScreen({
    super.key,
    required this.driverName,
    required this.driverId,
  });

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  final vehicleController = TextEditingController();

  bool loading = false;
  bool validatingVehicle = false;
  bool showReadingsForm = false;
  int? selectedVehicleId;

  List trips = [];

  List<dynamic> readingsRequired = [];
  Map<int, TextEditingController> readingControllers = {};
  Map<int, double> lastEndReadings = {}; // Store last trip's end values for validation

  XFile? startPhoto;

  late DateTime now;
  Timer? clockTimer;

  String get currentDate => DateFormat('dd-MM-yyyy').format(now);
  String get currentTime => DateFormat('HH:mm').format(now);

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
    return difference.inHours < 24;
  }

  String _tripVehicleText(Map<String, dynamic> trip) {
    final vehicle = trip["vehicle"];
    if (vehicle is Map && vehicle["vehicle_number"] != null) {
      return vehicle["vehicle_number"].toString();
    }
    if (trip["vehicle_number"] != null) {
      return trip["vehicle_number"].toString();
    }
    if (trip["vehicleNo"] != null) {
      return trip["vehicleNo"].toString();
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
    now = DateTime.now();
    clockTimer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (!mounted) return;
      setState(() {
        now = DateTime.now();
      });
    });
    fetchTripHistory();
  }

  @override
  void dispose() {
    clockTimer?.cancel();
    vehicleController.dispose();
    for (final controller in readingControllers.values) {
      controller.dispose();
    }
    super.dispose();
  }

  // ================= FETCH TRIP HISTORY =================
  Future<void> fetchTripHistory() async {
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
      });

      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(message)));
    } catch (_) {
      if (!mounted) return;
      setState(() {
        trips = [];
      });
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Network error while loading trips")),
      );
    }
  }

  // ================= QR SCANNER =================
  Future<void> openScanner() async {
    final result = await Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => ScanQrScreen()),
    );

    if (!mounted) return;

    if (result != null) {
      setState(() {
        vehicleController.text = result;
        showReadingsForm = false;
        selectedVehicleId = null;
        startPhoto = null;
      });
    }
  }

  // ================= CAPTURE PHOTO =================
  Future<void> captureStartPhoto() async {
    final picker = ImagePicker();
    final image = await picker.pickImage(
      source: ImageSource.camera,
      imageQuality: 60,
    );

    if (image != null) {
      setState(() {
        startPhoto = image;
      });
    }
  }

  // ================= VALIDATE VEHICLE + SHOW FORM =================
  Future<void> startTrip() async {
    if (vehicleController.text.isEmpty) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text("Vehicle required")));
      return;
    }

    setState(() {
      validatingVehicle = true;
      showReadingsForm = false;
      selectedVehicleId = null;
      startPhoto = null;
    });

    final validateResponse = await ApiService.post("/api/vehicle/by-qr", {
      "qr_value": vehicleController.text.trim(),
    }, auth: true);

    if (!mounted) return;

    if (validateResponse.statusCode != 200) {
      setState(() {
        validatingVehicle = false;
      });
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text("Invalid Vehicle")));
      return;
    }

    final vehicleData = jsonDecode(validateResponse.body);
    final vehicleId = vehicleData["vehicle"]["id"];

    final incomingReadings = vehicleData["vehicle"]["readings_required"];
    readingsRequired = incomingReadings is List ? incomingReadings : [];

    // Fetch last trip's end readings for this vehicle
    final lastTripResponse = await ApiService.get("/api/trip/last/${vehicleId}", auth: true);
    if (lastTripResponse.statusCode == 200) {
      final lastTripData = jsonDecode(lastTripResponse.body);
      if (lastTripData["readings"] is List) {
        for (var reading in lastTripData["readings"]) {
          if (reading["end_value"] != null) {
            final readingTypeId = reading["reading_type_id"];
            final endValue = double.tryParse(reading["end_value"].toString());
            if (endValue != null) {
              lastEndReadings[readingTypeId] = endValue;
            }
          }
        }
      }
    }

    for (final controller in readingControllers.values) {
      controller.dispose();
    }
    readingControllers = {};

    for (var reading in readingsRequired) {
      readingControllers[reading["id"]] = TextEditingController();
    }

    setState(() {
      selectedVehicleId = vehicleId;
      validatingVehicle = false;
      showReadingsForm = true;
    });
  }

  // ================= SUBMIT TRIP =================
  Future<void> _postTripStartLocation({
    required int tripId,
  }) async {
    try {
      final serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) return;

      var permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
      }

      if (permission == LocationPermission.denied ||
          permission == LocationPermission.deniedForever) {
        return;
      }

      final position = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
      );

      final payload = {
        "trip_id": tripId,
        "latitude": position.latitude,
        "longitude": position.longitude,
      };

      final endpoints = <String>[
        "/location",
        "/api/location",
        "/api/admin/location",
      ];

      for (final endpoint in endpoints) {
        final response = await ApiService.post(
          endpoint,
          payload,
          auth: true,
        );
        if (response.statusCode == 200 || response.statusCode == 201) {
          debugPrint("Location updated via $endpoint");
          return;
        }
        debugPrint(
          "Location update failed on $endpoint: ${response.statusCode} ${response.body}",
        );
      }

      // Retry once after short delay in case trip status just transitioned to STARTED.
      await Future.delayed(const Duration(milliseconds: 800));
      for (final endpoint in endpoints) {
        final response = await ApiService.post(
          endpoint,
          payload,
          auth: true,
        );
        if (response.statusCode == 200 || response.statusCode == 201) {
          debugPrint("Location updated on retry via $endpoint");
          return;
        }
      }
    } catch (_) {
      // Location sync should not block trip start flow.
    }
  }

  Future<void> submitDynamicTrip(int vehicleId) async {
    if (loading) return;

    if (startPhoto == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Speedometer photo required")),
      );
      return;
    }

    final List<Map<String, dynamic>> readingsPayload = [];

    for (var entry in readingControllers.entries) {
      if (entry.value.text.isEmpty) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text("All readings required")));
        return;
      }

      final parsedValue = double.tryParse(entry.value.text);
      if (parsedValue == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Reading values must be numeric")),
        );
        return;
      }

      readingsPayload.add({
        "reading_type_id": entry.key,
        "start_value": parsedValue,
      });
    }

    setState(() => loading = true);

    final response = await ApiService.multipartPost(
      "/api/trip/start",
      {
        "vehicle_id": vehicleId.toString(),
        "readings": jsonEncode(readingsPayload),
      },
      file: File(startPhoto!.path),
      fileField: "start_photo",
      auth: true,
    );

    if (!mounted) return;

    setState(() => loading = false);

    if (response.statusCode == 200) {
      Map<String, dynamic> data;
      try {
        data = Map<String, dynamic>.from(jsonDecode(response.body));
      } catch (_) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Trip started but response was invalid")),
        );
        return;
      }

      int? tripId;
      if (data["trip_id"] is int) {
        tripId = data["trip_id"];
      } else if (data["trip"] is Map && data["trip"]["id"] is int) {
        tripId = data["trip"]["id"];
      } else if (data["data"] is Map && data["data"]["trip_id"] is int) {
        tripId = data["data"]["trip_id"];
      }

      if (tripId == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text("Trip started but trip id was not returned"),
          ),
        );
        return;
      }

      final resolvedTripId = tripId;
      await _postTripStartLocation(
        tripId: resolvedTripId,
      );

      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => TripStartedScreen(
            tripId: resolvedTripId,
            vehicleNumber: vehicleController.text.trim(),
            date: currentDate,
            time: currentTime,
          ),
        ),
      );
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            ApiService.messageFromResponse(
              response,
              fallbackMessage: "Failed to start trip",
            ),
          ),
        ),
      );
    }
  }

  Widget buildDateTimeCard() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFFCE1E2D), Color(0xFFE84C3D)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(14),
        boxShadow: const [
          BoxShadow(
            color: Color(0x26000000),
            blurRadius: 10,
            offset: Offset(0, 5),
          ),
        ],
      ),
      child: Row(
        children: [
          const Icon(Icons.calendar_month, color: Colors.white),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              DateFormat('EEEE, dd MMM yyyy').format(now),
              style: const TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          const Icon(Icons.access_time, color: Colors.white),
          const SizedBox(width: 6),
          Text(
            DateFormat('hh:mm:ss a').format(now),
            style: const TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }

  Widget buildReadingsSection() {
    if (!showReadingsForm || selectedVehicleId == null) {
      return const SizedBox.shrink();
    }

    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(top: 14),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFFEEEEEE)),
        boxShadow: const [
          BoxShadow(
            color: Color(0x14000000),
            blurRadius: 8,
            offset: Offset(0, 3),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(
            children: [
              Icon(Icons.speed, color: Color(0xFFCE1E2D)),
              SizedBox(width: 8),
              Text(
                "Enter Start Readings",
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
              ),
            ],
          ),
          const SizedBox(height: 12),
          if (readingsRequired.isEmpty)
            const Text(
              "No readings configured for this vehicle.",
              style: TextStyle(color: Colors.black54),
            )
          else
            ...readingsRequired.map(
              (reading) => Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: TextField(
                  controller: readingControllers[reading["id"]],
                  keyboardType: const TextInputType.numberWithOptions(
                    decimal: true,
                  ),
                  decoration: InputDecoration(
                    labelText: "${reading["name"]} (${reading["unit"]})",
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                    prefixIcon: const Icon(Icons.pin_outlined),
                    filled: true,
                    fillColor: const Color(0xFFF8F8F9),
                  ),
                ),
              ),
            ),
          const SizedBox(height: 4),
          OutlinedButton.icon(
            onPressed: loading ? null : captureStartPhoto,
            icon: const Icon(Icons.camera_alt),
            label: Text(
              startPhoto == null
                  ? "Capture Speedometer Photo"
                  : "Retake Speedometer Photo",
            ),
          ),
          if (startPhoto != null)
            const Padding(
              padding: EdgeInsets.only(top: 6),
              child: Text(
                "Photo Captured",
                style: TextStyle(
                  color: Colors.green,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          const SizedBox(height: 12),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: loading
                  ? null
                  : () => submitDynamicTrip(selectedVehicleId!),
              icon: loading
                  ? const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Colors.white,
                      ),
                    )
                  : const Icon(Icons.play_arrow),
              label: Text(loading ? "Starting..." : "Start Trip"),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFFCE1E2D),
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 13),
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ================= UI =================
  @override
  Widget build(BuildContext context) {
    final allTrips = trips
        .whereType<Map>()
        .map((t) => Map<String, dynamic>.from(t))
        .toList();
    final recentTrips = allTrips.where(_isTripFromLast24Hours).toList();

    return Scaffold(
      backgroundColor: const Color(0xFFF4F4F6),
      body: Column(
        children: [
          Container(
            height: 90,
            width: double.infinity,
            color: const Color(0xFFCE1E2D),
            child: SafeArea(
              child: Center(
                child: Image.asset("assets/lloyds_logo.png", height: 45),
              ),
            ),
          ),
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(20),
              child: Column(
                children: [
                  Card(
                    child: ListTile(
                      title: Text("Welcome, ${widget.driverName}"),
                      subtitle: Text("Driver ID: ${widget.driverId}"),
                    ),
                  ),

                  const SizedBox(height: 14),
                  buildDateTimeCard(),
                  const SizedBox(height: 20),

                  TextField(
                    controller: vehicleController,
                    decoration: InputDecoration(
                      labelText: "Vehicle Number",
                      border: const OutlineInputBorder(),
                      suffixIcon: IconButton(
                        icon: const Icon(Icons.qr_code_scanner),
                        onPressed: openScanner,
                      ),
                    ),
                    onChanged: (_) {
                      if (showReadingsForm) {
                        setState(() {
                          showReadingsForm = false;
                          selectedVehicleId = null;
                          startPhoto = null;
                        });
                      }
                    },
                  ),

                  const SizedBox(height: 15),

                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: validatingVehicle ? null : startTrip,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFFCE1E2D),
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 13),
                      ),
                      child: validatingVehicle
                          ? const SizedBox(
                              width: 18,
                              height: 18,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: Colors.white,
                              ),
                            )
                          : const Text("Continue"),
                    ),
                  ),

                  buildReadingsSection(),

                  const SizedBox(height: 25),

                  Align(
                    alignment: Alignment.centerLeft,
                    child: Text(
                      "Recent Trip History (Last 24 Hours)",
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),

                  const SizedBox(height: 10),

                  if (recentTrips.isEmpty)
                    const Card(
                      child: Padding(
                        padding: EdgeInsets.all(14),
                        child: Text("No trips in the last 24 hours"),
                      ),
                    )
                  else
                    const SizedBox.shrink(),

                  ...recentTrips.map(
                    (trip) => Card(
                      child: ListTile(
                        leading: const Icon(Icons.local_shipping),
                        title: Text(_tripVehicleText(trip)),
                        subtitle: Text(
                          "Trip ID: ${trip["id"] ?? "-"}"
                          "\nDate: ${_tripDateText(trip)}"
                          "\nStatus: ${trip["trip_status"] ?? "-"}"
                          "\nTotal KM: ${_tripTotalKmText(trip)}"
                          "\n${_tripReadingsText(trip)}",
                        ),
                        isThreeLine: false,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
