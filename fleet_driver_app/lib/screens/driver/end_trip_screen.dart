import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import '../../services/api_service.dart';
import 'login_screen.dart';

class EndTripScreen extends StatefulWidget {
  final int tripId;
  final String vehicleNumber;

  const EndTripScreen({
    super.key,
    required this.tripId,
    required this.vehicleNumber,
  });

  @override
  State<EndTripScreen> createState() => _EndTripScreenState();
}

class _EndTripScreenState extends State<EndTripScreen> {
  bool fetching = true;
  bool loading = false;

  List<dynamic> readingsRequired = [];
  Map<int, TextEditingController> readingControllers = {};
  Map<int, double> startReadings = {}; // Store start values for validation

  File? endPhoto;

  final ImagePicker picker = ImagePicker();

  String _formatValue(dynamic value) {
    if (value == null) return "-";
    final number = value is num ? value.toDouble() : double.tryParse(value.toString());
    if (number == null) return value.toString();
    if (number == number.roundToDouble()) {
      return number.toInt().toString();
    }
    return number.toStringAsFixed(2);
  }

  bool _isKmReading(Map<String, dynamic> reading) {
    final readingName = (reading["name"] ?? "").toString().toLowerCase();
    final readingUnit = (reading["unit"] ?? "").toString().toLowerCase();
    return readingName.contains("km") ||
        readingName.contains("kilometer") ||
        readingName.contains("odometer") ||
        readingUnit.contains("km") ||
        readingUnit.contains("kilometer");
  }

  @override
  void initState() {
    super.initState();
    fetchRequiredReadings();
  }

  // ================= FETCH REQUIRED READINGS =================
  Future<void> fetchRequiredReadings() async {
    setState(() => fetching = true);

    final response = await ApiService.get(
      "/api/trip/${widget.tripId}/readings",
      auth: true,
    );

    if (!mounted) return;

    if (response.statusCode == 200) {
      final data = jsonDecode(response.body);

      readingsRequired = data["readings"] ?? [];

      readingControllers.clear();
      startReadings.clear();

      for (var reading in readingsRequired) {
        readingControllers[reading["reading_type_id"]] =
            TextEditingController();
        // Store start value for validation
        if (reading["start_value"] != null) {
          startReadings[reading["reading_type_id"]] = 
              double.tryParse(reading["start_value"].toString()) ?? 0.0;
        }
      }
    }

    setState(() => fetching = false);
  }

  // ================= CAPTURE PHOTO =================
  Future<void> capturePhoto() async {
    final picked = await picker.pickImage(
      source: ImageSource.camera,
      imageQuality: 70,
    );

    if (picked != null) {
      setState(() {
        endPhoto = File(picked.path);
      });
    }
  }

  // ================= CALCULATE DIFFERENCE =================
  double? _calculateDifference(int readingTypeId, double endValue) {
    if (!startReadings.containsKey(readingTypeId)) return null;

    final startValue = startReadings[readingTypeId]!;
    return endValue - startValue;
  }

  Future<void> completeTrip() async {
    if (readingControllers.values
        .any((controller) => controller.text.isEmpty)) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("All readings required")),
      );
      return;
    }

    if (endPhoto == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Speedometer photo required")),
      );
      return;
    }

    setState(() => loading = true);

    List<Map<String, dynamic>> readingsPayload = [];

    for (final entry in readingControllers.entries) {
      final parsedValue = double.tryParse(entry.value.text.trim());
      if (parsedValue == null) {
        if (!mounted) return;
        setState(() => loading = false);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Reading values must be numeric")),
        );
        return;
      }

      // Find the reading details
      final reading = readingsRequired.firstWhere(
        (r) => r["reading_type_id"] == entry.key,
        orElse: () => {},
      );

      // Validate end km > start km for km readings
      final isKmReading = reading is Map<String, dynamic> && _isKmReading(reading);

      if (isKmReading && startReadings.containsKey(entry.key)) {
        final startValue = startReadings[entry.key]!;
        if (parsedValue <= startValue) {
          if (!mounted) return;
          setState(() => loading = false);
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                "End ${reading["name"]} must be greater than start value (${_formatValue(startValue)})",
              ),
            ),
          );
          return;
        }
      }

      readingsPayload.add({
        "reading_type_id": entry.key,
        "end_value": parsedValue,
      });
    }

    final response = await ApiService.multipartPost(
      "/api/trip/end",
      {
        "trip_id": widget.tripId.toString(),
        "readings": jsonEncode(readingsPayload),
      },
      file: endPhoto!,
      fileField: "end_photo",
      auth: true,
    );

    if (!mounted) return;
    setState(() => loading = false);

    if (response.statusCode == 200) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Trip Completed Successfully")),
      );

      Navigator.pushAndRemoveUntil(
        context,
        MaterialPageRoute(builder: (_) => const LoginScreen()),
        (route) => false,
      );
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            ApiService.messageFromResponse(
              response,
              fallbackMessage: "Failed to complete trip",
            ),
          ),
        ),
      );
    }
  }

  // ================= UI =================
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF4F4F6),
      appBar: AppBar(
        title: const Text("End Trip"),
        backgroundColor: const Color(0xFFCE1E2D),
      ),
      body: fetching
          ? const Center(child: CircularProgressIndicator())
          : readingsRequired.isEmpty
              ? const Center(
                  child: Text(
                    "No readings configured for this vehicle",
                    style: TextStyle(fontSize: 16),
                  ),
                )
              : SingleChildScrollView(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    children: [
                      Card(
                        elevation: 4,
                        child: ListTile(
                          title: Text(widget.vehicleNumber),
                          subtitle:
                              const Text("Enter End Readings"),
                        ),
                      ),
                      const SizedBox(height: 20),

                      // Dynamic Reading Fields
                      ...readingsRequired.map((reading) {
                        final readingTypeId = reading["reading_type_id"];
                        final startValue = startReadings[readingTypeId];
                        final isKmReading = _isKmReading(
                          Map<String, dynamic>.from(reading),
                        );
                        final endValue = double.tryParse(
                          readingControllers[readingTypeId]?.text.trim() ?? "",
                        );
                        final difference = endValue == null
                            ? null
                            : _calculateDifference(readingTypeId, endValue);
                        return Padding(
                          padding:
                              const EdgeInsets.only(bottom: 15),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              TextField(
                                controller: readingControllers[
                                    readingTypeId],
                                keyboardType:
                                    const TextInputType.numberWithOptions(
                                      decimal: true,
                                    ),
                                decoration: InputDecoration(
                                  labelText:
                                      "${reading["name"]} (${reading["unit"]})",
                                  border:
                                      const OutlineInputBorder(),
                                  helperText: startValue != null 
                                      ? isKmReading
                                          ? "Start km: ${_formatValue(startValue)}"
                                          : "Start: ${_formatValue(startValue)}"
                                      : null,
                                ),
                                onChanged: (value) {
                                  // Update difference display when value changes
                                  setState(() {});
                                },
                              ),
                              if (startValue != null && difference != null)
                                Padding(
                                  padding: const EdgeInsets.only(top: 4),
                                  child: Text(
                                    isKmReading
                                        ? "Distance covered: ${_formatValue(difference)} km"
                                        : "Difference: ${_formatValue(difference)}",
                                    style: TextStyle(
                                      color: isKmReading && difference <= 0
                                          ? Colors.red
                                          : Colors.green,
                                      fontWeight: FontWeight.w600,
                                      fontSize: 14,
                                    ),
                                  ),
                                ),
                            ],
                          ),
                        );
                      }),

                      const SizedBox(height: 20),

                      // PHOTO BUTTON
                      ElevatedButton.icon(
                        onPressed: capturePhoto,
                        icon:
                            const Icon(Icons.camera_alt),
                        label: const Text(
                            "Capture Speedometer Photo"),
                      ),

                      if (endPhoto != null)
                        Padding(
                          padding:
                              const EdgeInsets.only(top: 10),
                          child: Image.file(
                            endPhoto!,
                            height: 150,
                          ),
                        ),

                      const SizedBox(height: 30),

                      SizedBox(
                        width: double.infinity,
                        height: 50,
                        child: ElevatedButton(
                          onPressed:
                              loading ? null : completeTrip,
                          style: ElevatedButton.styleFrom(
                            backgroundColor:
                                Colors.green,
                          ),
                          child: Text(
                            loading
                                ? "Processing..."
                                : "COMPLETE TRIP",
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
    );
  }
}
