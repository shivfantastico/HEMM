import 'dart:convert';
import 'package:flutter/material.dart';
import '../../services/api_service.dart';

class RegisterDriverScreen extends StatefulWidget {
  const RegisterDriverScreen({super.key});

  @override
  State<RegisterDriverScreen> createState() => _RegisterDriverScreenState();
}

class _RegisterDriverScreenState extends State<RegisterDriverScreen> {
  final nameController = TextEditingController();
  final mobileController = TextEditingController();
  final userIdController = TextEditingController();
  final passwordController = TextEditingController();
  final confirmPasswordController = TextEditingController();

  bool loading = false;

  Future<void> registerDriver() async {
    if (nameController.text.trim().isEmpty ||
        mobileController.text.trim().isEmpty ||
        userIdController.text.trim().isEmpty ||
        passwordController.text.isEmpty ||
        confirmPasswordController.text.isEmpty) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text("Please fill all fields")));
      return;
    }

    if (passwordController.text != confirmPasswordController.text) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text("Passwords do not match")));
      return;
    }

    setState(() => loading = true);

    final response = await ApiService.post("/api/auth/register", {
      "name": nameController.text.trim(),
      "mobile": mobileController.text.trim(),
      "username": userIdController.text.trim(),
      "user_id": userIdController.text.trim(),
      "password": passwordController.text,
    });

    if (!mounted) return;
    setState(() => loading = false);

    if (response.statusCode == 200 || response.statusCode == 201) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Driver registered successfully")),
      );
      Navigator.pop(context);
      return;
    }

    String message = "Registration failed";
    try {
      final data = jsonDecode(response.body);
      if (data["message"] != null) {
        message = data["message"].toString();
      }
    } catch (_) {}

    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
  }

  @override
  void dispose() {
    nameController.dispose();
    mobileController.dispose();
    userIdController.dispose();
    passwordController.dispose();
    confirmPasswordController.dispose();
    super.dispose();
  }

  InputDecoration _decoration(String label, IconData icon) {
    return InputDecoration(
      labelText: label,
      prefixIcon: Icon(icon),
      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF4F4F6),
      appBar: AppBar(
        title: const Text("Driver Registration"),
        backgroundColor: const Color(0xFFCE1E2D),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
            boxShadow: [
              BoxShadow(
                color: Colors.grey.shade300,
                blurRadius: 10,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Column(
            children: [
              TextField(
                controller: nameController,
                decoration: _decoration("Driver Name", Icons.badge_outlined),
              ),
              const SizedBox(height: 14),
              TextField(
                controller: mobileController,
                keyboardType: TextInputType.phone,
                decoration: _decoration("Mobile Number", Icons.phone_outlined),
              ),
              const SizedBox(height: 14),
              TextField(
                controller: userIdController,
                decoration: _decoration("User ID", Icons.person_outline),
              ),
              const SizedBox(height: 14),
              TextField(
                controller: passwordController,
                obscureText: true,
                decoration: _decoration("Password", Icons.lock_outline),
              ),
              const SizedBox(height: 14),
              TextField(
                controller: confirmPasswordController,
                obscureText: true,
                decoration: _decoration(
                  "Confirm Password",
                  Icons.lock_reset_outlined,
                ),
              ),
              const SizedBox(height: 22),
              SizedBox(
                width: double.infinity,
                height: 50,
                child: ElevatedButton(
                  onPressed: loading ? null : registerDriver,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFFCE1E2D),
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(28),
                    ),
                  ),
                  child: Text(
                    loading ? "Registering..." : "REGISTER DRIVER",
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      letterSpacing: 0.8,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
