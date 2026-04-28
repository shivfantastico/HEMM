import 'dart:convert';
import 'package:flutter/material.dart';
import '../../services/api_service.dart';
import '../../services/session_service.dart';
import 'dashboard_screen.dart';

class OtpScreen extends StatefulWidget {
  final String mobile;

  const OtpScreen({super.key, required this.mobile});

  @override
  State<OtpScreen> createState() => _OtpScreenState();
}

class _OtpScreenState extends State<OtpScreen> {
  final otpController = TextEditingController();
  bool loading = false;

  Future<void> verifyOtp() async {
    if (otpController.text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Enter OTP")),
      );
      return;
    }

    setState(() => loading = true);

    final response = await ApiService.post(
      "/api/auth/verify-otp",
      {
        "mobile": widget.mobile,
        "otp": otpController.text.trim(),
      },
    );

    setState(() => loading = false);

    if (response.statusCode == 200) {
      final data = jsonDecode(response.body);
      final token = data["token"]?.toString() ?? "";
      final driver = data["driver"] is Map
          ? Map<String, dynamic>.from(data["driver"])
          : <String, dynamic>{};
      final driverName = (driver["name"] ?? "Driver").toString();
      final driverId = driver["id"] is int
          ? driver["id"] as int
          : int.tryParse(driver["id"]?.toString() ?? "") ?? 0;

      if (token.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("OTP verified but token is missing")),
        );
        return;
      }

      await SessionService.saveDriverSession(
        token: token,
        name: driverName,
        userId: driverId,
      );

      Navigator.pushAndRemoveUntil(
        context,
        MaterialPageRoute(
          builder: (_) => DashboardScreen(
            driverName: driverName,
            driverId: driverId,
          ),
        ),
        (route) => false,
      );
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Invalid OTP")),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF4F4F6),
      body: Column(
        children: [

          // ================= HEADER =================
          Container(
            height: 100,
            width: double.infinity,
            color: const Color(0xFFCE1E2D),
            child: SafeArea(
              child: Center(
                child: Image.asset(
                  "assets/lloyds_logo.png",
                  height: 45,
                ),
              ),
            ),
          ),

          const SizedBox(height: 40),

          Expanded(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                children: [

                  const Text(
                    "Verify OTP",
                    style: TextStyle(
                      fontSize: 26,
                      fontWeight: FontWeight.bold,
                    ),
                  ),

                  const SizedBox(height: 10),

                  Text(
                    "OTP sent to ${widget.mobile}",
                    style: const TextStyle(color: Colors.grey),
                  ),

                  const SizedBox(height: 30),

                  Container(
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(18),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.grey.shade300,
                          blurRadius: 12,
                          offset: const Offset(0, 5),
                        ),
                      ],
                    ),
                    child: Column(
                      children: [

                        TextField(
                          controller: otpController,
                          keyboardType: TextInputType.number,
                          decoration: InputDecoration(
                            labelText: "Enter OTP",
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),
                        ),

                        const SizedBox(height: 30),

                        SizedBox(
                          width: double.infinity,
                          height: 50,
                          child: ElevatedButton(
                            style: ElevatedButton.styleFrom(
                              backgroundColor: const Color(0xFFCE1E2D),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(30),
                              ),
                            ),
                            onPressed: loading ? null : verifyOtp,
                            child: Text(
                              loading ? "Verifying..." : "VERIFY OTP",
                              style: const TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                                letterSpacing: 1,
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
        ],
      ),
    );
  }
}
