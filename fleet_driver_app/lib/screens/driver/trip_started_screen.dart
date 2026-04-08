import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import '../../services/api_service.dart';
import 'end_trip_screen.dart';

class TripStartedScreen extends StatefulWidget {
  final int tripId;
  final String vehicleNumber;
  final String date;
  final String time;

  const TripStartedScreen({
    super.key,
    required this.tripId,
    required this.vehicleNumber,
    required this.date,
    required this.time,
  });

  @override
  State<TripStartedScreen> createState() => _TripStartedScreenState();
}

class _TripStartedScreenState extends State<TripStartedScreen> {
  final litreController = TextEditingController();
  File? refuelPhoto;
  bool refuelLoading = false;

  final ImagePicker picker = ImagePicker();

  @override
  void dispose() {
    litreController.dispose();
    super.dispose();
  }

  // ================= CAPTURE PHOTO =================
  Future<void> captureRefuelPhoto() async {
    final picked = await picker.pickImage(
      source: ImageSource.camera,
      imageQuality: 70,
    );

    if (picked != null) {
      setState(() {
        refuelPhoto = File(picked.path);
      });
    }
  }

  // ================= SUBMIT REFUEL =================
  Future<void> submitRefuel() async {
    if (litreController.text.isEmpty) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text("Enter refuel litre")));
      return;
    }

    if (refuelPhoto == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Fuel machine photo required")),
      );
      return;
    }

    setState(() => refuelLoading = true);
    final response = await ApiService.multipartPost(
      "/api/trip/refuel",
      {
        "trip_id": widget.tripId.toString(),
        "litre": litreController.text.trim(),
      },
      file: refuelPhoto!,
      fileField: "refuel_photo",
      auth: true,
    );

    if (!mounted) return;
    setState(() => refuelLoading = false);

    if (response.statusCode == 200) {
      Navigator.pop(context);
      litreController.clear();
      setState(() {
        refuelPhoto = null;
      });

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Refuel recorded successfully")),
      );
    } else {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(
        SnackBar(
          content: Text(
            ApiService.messageFromResponse(
              response,
              fallbackMessage: "Refuel failed",
            ),
          ),
        ),
      );
    }
  }

  // ================= REFUEL BOTTOM SHEET =================
  void openRefuelSheet() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) {
        return Container(
          decoration: const BoxDecoration(
            color: Color(0xFFFDFDFE),
            borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
          ),
          child: Padding(
            padding: EdgeInsets.only(
              left: 20,
              right: 20,
              top: 16,
              bottom: MediaQuery.of(context).viewInsets.bottom + 20,
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Center(
                  child: Container(
                    width: 42,
                    height: 5,
                    decoration: BoxDecoration(
                      color: Colors.black12,
                      borderRadius: BorderRadius.circular(20),
                    ),
                  ),
                ),
                const SizedBox(height: 14),
                const Text(
                  "Refuel Entry",
                  style: TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.w700,
                    color: Color(0xFF1B1F2A),
                  ),
                ),
                const SizedBox(height: 6),
                const Text(
                  "Add litres and upload fuel machine photo",
                  style: TextStyle(color: Colors.black54),
                ),
                const SizedBox(height: 18),
                TextField(
                  controller: litreController,
                  keyboardType: const TextInputType.numberWithOptions(
                    decimal: true,
                  ),
                  decoration: InputDecoration(
                    labelText: "Refuel Litres",
                    prefixIcon: const Icon(Icons.local_gas_station_outlined),
                    filled: true,
                    fillColor: const Color(0xFFF4F5F7),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(14),
                      borderSide: BorderSide.none,
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                SizedBox(
                  width: double.infinity,
                  child: OutlinedButton.icon(
                    onPressed: captureRefuelPhoto,
                    style: OutlinedButton.styleFrom(
                      side: const BorderSide(color: Color(0xFFCE1E2D)),
                      padding: const EdgeInsets.symmetric(vertical: 13),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    icon: const Icon(Icons.camera_alt_outlined),
                    label: Text(
                      refuelPhoto == null
                          ? "Capture Fuel Machine Photo"
                          : "Retake Photo",
                    ),
                  ),
                ),
                if (refuelPhoto != null)
                  Container(
                    margin: const EdgeInsets.only(top: 10),
                    height: 130,
                    width: double.infinity,
                    clipBehavior: Clip.antiAlias,
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Image.file(refuelPhoto!, fit: BoxFit.cover),
                  ),
                const SizedBox(height: 16),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: refuelLoading ? null : submitRefuel,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFFCE1E2D),
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    child: Text(
                      refuelLoading ? "Submitting..." : "Submit Refuel",
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  // ================= UI =================
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF1F3F8),
      body: SafeArea(
        child: SingleChildScrollView(
          child: Column(
            children: [
              Container(
                width: double.infinity,
                padding: const EdgeInsets.fromLTRB(20, 18, 20, 26),
                decoration: const BoxDecoration(
                  gradient: LinearGradient(
                    colors: [
                      Color(0xFFB81528),
                      Color(0xFFCE1E2D),
                      Color(0xFFE33C49),
                    ],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.vertical(
                    bottom: Radius.circular(26),
                  ),
                ),
                child: Column(
                  children: [
                    Center(
                      child: Image.asset("assets/lloyds_logo.png", height: 42),
                    ),
                    const SizedBox(height: 18),
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: const Color(0x22FFFFFF),
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: const Color(0x33FFFFFF)),
                      ),
                      child: Row(
                        children: [
                          Container(
                            width: 56,
                            height: 56,
                            decoration: const BoxDecoration(
                              color: Color(0x30FFFFFF),
                              shape: BoxShape.circle,
                            ),
                            child: const Icon(
                              Icons.check_circle_rounded,
                              color: Colors.white,
                              size: 36,
                            ),
                          ),
                          const SizedBox(width: 12),
                          const Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  "Trip Started",
                                  style: TextStyle(
                                    color: Colors.white,
                                    fontSize: 24,
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                                SizedBox(height: 4),
                                Text(
                                  "You are all set. Drive safely.",
                                  style: TextStyle(color: Color(0xFFF2F4F8)),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(18, 16, 18, 20),
                child: Column(
                  children: [
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(16),
                        boxShadow: const [
                          BoxShadow(
                            color: Color(0x16000000),
                            blurRadius: 12,
                            offset: Offset(0, 5),
                          ),
                        ],
                      ),
                      child: Column(
                        children: [
                          buildInfoTile(
                            icon: Icons.local_shipping_outlined,
                            label: "Vehicle",
                            value: widget.vehicleNumber,
                          ),
                          const SizedBox(height: 10),
                          buildInfoTile(
                            icon: Icons.calendar_month_outlined,
                            label: "Date",
                            value: widget.date,
                          ),
                          const SizedBox(height: 10),
                          buildInfoTile(
                            icon: Icons.access_time_outlined,
                            label: "Time",
                            value: widget.time,
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 16),
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        color: const Color(0xFFE9F9EF),
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(color: const Color(0xFFBEE9CD)),
                      ),
                      child: const Row(
                        children: [
                          Icon(Icons.shield_outlined, color: Color(0xFF1E8D4A)),
                          SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              "Use refuel whenever you fill fuel during this trip.",
                              style: TextStyle(
                                color: Color(0xFF1E8D4A),
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 26),
                    SizedBox(
                      width: double.infinity,
                      height: 54,
                      child: ElevatedButton.icon(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFFFF9D00),
                          foregroundColor: Colors.white,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(14),
                          ),
                          elevation: 0,
                        ),
                        onPressed: openRefuelSheet,
                        icon: const Icon(Icons.local_gas_station_rounded),
                        label: const Text(
                          "Refuel",
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 12),
                    SizedBox(
                      width: double.infinity,
                      height: 54,
                      child: ElevatedButton.icon(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF1B9B58),
                          foregroundColor: Colors.white,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(14),
                          ),
                          elevation: 0,
                        ),
                        onPressed: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) => EndTripScreen(
                                tripId: widget.tripId,
                                vehicleNumber: widget.vehicleNumber,
                              ),
                            ),
                          );
                        },
                        icon: const Icon(Icons.flag_circle_outlined),
                        label: const Text(
                          "End Trip",
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget buildInfoTile({
    required IconData icon,
    required String label,
    required String value,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
      decoration: BoxDecoration(
        color: const Color(0xFFF7F8FB),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          Icon(icon, color: const Color(0xFFCE1E2D), size: 20),
          const SizedBox(width: 10),
          Text(
            "$label:",
            style: const TextStyle(color: Colors.black54, fontSize: 15),
          ),
          const Spacer(),
          Flexible(
            child: Text(
              value,
              textAlign: TextAlign.right,
              style: const TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w700,
                color: Color(0xFF1A1D26),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
