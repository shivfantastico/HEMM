import 'package:flutter/material.dart';
import 'screens/common/select_role_screen.dart';
import 'services/app_update_service.dart';
import 'services/session_service.dart';

void main() {
  runApp(const FleetApp());
}

class FleetApp extends StatelessWidget {
  const FleetApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        useMaterial3: true,
        scaffoldBackgroundColor: const Color(0xFFF4F5F7),
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFFCE1E2D),
          primary: const Color(0xFFCE1E2D),
          secondary: const Color(0xFF20283A),
          surface: Colors.white,
        ),
        appBarTheme: const AppBarTheme(
          elevation: 0,
          centerTitle: true,
          backgroundColor: Colors.transparent,
          foregroundColor: Color(0xFF1F2533),
        ),
        cardTheme: CardThemeData(
          color: Colors.white,
          elevation: 0,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(18),
          ),
        ),
        inputDecorationTheme: InputDecorationTheme(
          filled: true,
          fillColor: const Color(0xFFF7F8FA),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(14),
            borderSide: BorderSide.none,
          ),
        ),
      ),
      home: const AppEntryScreen(),
    );
  }
}

class AppEntryScreen extends StatefulWidget {
  const AppEntryScreen({super.key});

  @override
  State<AppEntryScreen> createState() => _AppEntryScreenState();
}

class _AppEntryScreenState extends State<AppEntryScreen> {
  late final Future<Widget> _homeFuture;

  @override
  void initState() {
    super.initState();
    _homeFuture = SessionService.resolveHome();
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<Widget>(
      future: _homeFuture,
      builder: (context, snapshot) {
        if (snapshot.connectionState != ConnectionState.done) {
          return const Scaffold(
            body: Center(
              child: CircularProgressIndicator(),
            ),
          );
        }

        return UpdateGate(
          child: snapshot.data ?? const SelectRoleScreen(),
        );
      },
    );
  }
}
