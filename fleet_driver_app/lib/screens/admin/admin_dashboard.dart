import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../common/select_role_screen.dart';
import '../../services/api_service.dart';
import '../admin/admin_vehicle_screen.dart';
import '../admin/admin_trip_monitor_screen.dart';
import '../admin/admin_live_fleet_map_screen.dart';
import '../admin/admin_refuel_logs_screen.dart';
import '../admin/admin_service_scheduler_screen.dart';
import '../admin/admin_reports_screen.dart';

class AdminDashboardScreen extends StatefulWidget {
  const AdminDashboardScreen({super.key});

  @override
  State<AdminDashboardScreen> createState() => _AdminDashboardScreenState();
}

class _AdminDashboardScreenState extends State<AdminDashboardScreen> {
  int selectedIndex = 0;
  int totalVehicles = 0;
  int activeTrips = 0;
  int serviceDue = 0;
  int refuelToday = 0;

  final List<_DrawerItem> menuItems = const [
    _DrawerItem(label: "Dashboard", icon: Icons.dashboard_outlined),
    _DrawerItem(label: "Vehicles", icon: Icons.local_shipping_outlined),
    _DrawerItem(label: "Active Trips", icon: Icons.alt_route_outlined),
    _DrawerItem(label: "Live Fleet Map", icon: Icons.map_outlined),
    _DrawerItem(label: "Refuel Logs", icon: Icons.local_gas_station_outlined),
    _DrawerItem(label: "Service Schedule", icon: Icons.build_circle_outlined),
    _DrawerItem(label: "Reports", icon: Icons.assessment_outlined),
  ];

  @override
  void initState() {
    super.initState();
    fetchDashboardStats();
  }

  Future<void> fetchDashboardStats() async {
    final response = await ApiService.get(
      "/api/admin/dashboard-stats",
      auth: true,
    );

    if (!mounted) return;

    if (response.statusCode == 200) {
      final data = jsonDecode(response.body);
      setState(() {
        totalVehicles = data["totalVehicles"] ?? 0;
        activeTrips = data["activeTrips"] ?? 0;
        serviceDue = data["serviceDue"] ?? 0;
        refuelToday = data["refuelToday"] ?? 0;
      });
    }
  }

  Future<void> _handleMenuTap(int index) async {
    setState(() {
      selectedIndex = index;
    });
    Navigator.pop(context);

    if (index == 1) {
      Navigator.push(
        context,
        MaterialPageRoute(builder: (_) => const AdminVehicleScreen()),
      );
      return;
    }

    if (index == 2) {
      Navigator.push(
        context,
        MaterialPageRoute(builder: (_) => const AdminTripMonitorScreen()),
      );
      return;
    }

    if (index == 3) {
      Navigator.push(
        context,
        MaterialPageRoute(builder: (_) => const AdminLiveFleetMapScreen()),
      );
      return;
    }

    if (index == 4) {
      Navigator.push(
        context,
        MaterialPageRoute(builder: (_) => const AdminRefuelLogsScreen()),
      );
      return;
    }

    if (index == 5) {
      Navigator.push(
        context,
        MaterialPageRoute(builder: (_) => const AdminServiceSchedulerScreen()),
      );
      return;
    }

    if (index == 6) {
      Navigator.push(
        context,
        MaterialPageRoute(builder: (_) => const AdminReportsScreen()),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF4F5F8),
      drawer: Drawer(
        backgroundColor: const Color(0xFF131A29),
        child: Column(
          children: [
            DrawerHeader(
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                  colors: [Color(0xFF1C2436), Color(0xFF121826)],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
              ),
              child: Row(
                children: [
                  Container(
                    width: 54,
                    height: 54,
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: Padding(
                      padding: const EdgeInsets.all(8),
                      child: Image.asset("assets/lloyds_logo.png"),
                    ),
                  ),
                  const SizedBox(width: 12),
                  const Expanded(
                    child: Text(
                      "Lloyds Admin",
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 20,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            ...List.generate(menuItems.length, (index) {
              return ListTile(
                leading: Icon(
                  menuItems[index].icon,
                  size: 18,
                  color: selectedIndex == index
                      ? Colors.white
                      : const Color(0xFFD4D8E2),
                ),
                title: Text(
                  menuItems[index].label,
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                selected: selectedIndex == index,
                selectedTileColor: const Color(0xFF293249),
                selectedColor: Colors.white,
                onTap: () => _handleMenuTap(index),
              );
            }),
            const Spacer(),
            ListTile(
              leading: const Icon(Icons.logout, color: Colors.red),
              title: const Text(
                "Logout",
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w500,
                ),
              ),
              onTap: () async {
                final prefs = await SharedPreferences.getInstance();
                await prefs.clear();
                if (!mounted) return;
                Navigator.pushAndRemoveUntil(
                  context,
                  MaterialPageRoute(builder: (_) => const SelectRoleScreen()),
                  (route) => false,
                );
              },
            ),
          ],
        ),
      ),
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        iconTheme: const IconThemeData(color: Color(0xFF1E2432)),
        title: const Text(
          "Admin Dashboard",
          style: TextStyle(
            color: Color(0xFF1E2432),
            fontWeight: FontWeight.w700,
          ),
        ),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 16),
            child: Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(10),
              ),
              child: Padding(
                padding: const EdgeInsets.all(6),
                child: Image.asset("assets/lloyds_logo.png"),
              ),
            ),
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: fetchDashboardStats,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            Container(
              padding: const EdgeInsets.all(18),
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [Color(0xFFCE1E2D), Color(0xFFE44A58)],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(18),
                boxShadow: const [
                  BoxShadow(
                    color: Color(0x30000000),
                    blurRadius: 18,
                    offset: Offset(0, 8),
                  ),
                ],
              ),
              child: const Row(
                children: [
                  Icon(Icons.verified_user, color: Colors.white, size: 30),
                  SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      "Welcome to Lloyds Fleet Control Center",
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 18),
            Row(
              children: [
                Expanded(
                  child: _KpiCard(
                    title: "Total Vehicles",
                    value: "$totalVehicles",
                    icon: Icons.local_shipping,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _KpiCard(
                    title: "Active Trips",
                    value: "$activeTrips",
                    icon: Icons.route,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: _KpiCard(
                    title: "Service Due",
                    value: "$serviceDue",
                    icon: Icons.build,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _KpiCard(
                    title: "Refuel Today",
                    value: "$refuelToday",
                    icon: Icons.local_gas_station,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 20),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: const Color(0xFFFFF2F2),
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: const Color(0xFFFFCDD2)),
              ),
              child: Text(
                "Service due vehicles: $serviceDue",
                style: const TextStyle(
                  color: Color(0xFFB3261E),
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
            const SizedBox(height: 20),
            const Text(
              "Quick Overview",
              style: TextStyle(
                color: Color(0xFF1E2432),
                fontSize: 18,
                fontWeight: FontWeight.w800,
              ),
            ),
            const SizedBox(height: 10),
            Container(
              height: 160,
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: const Color(0xFFE9ECF3)),
              ),
              child: const Center(
                child: Text(
                  "Use the menu to manage vehicles, trips, maps, refuels and reports.",
                  style: TextStyle(color: Color(0xFF677084)),
                  textAlign: TextAlign.center,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _DrawerItem {
  final String label;
  final IconData icon;

  const _DrawerItem({
    required this.label,
    required this.icon,
  });
}

class _KpiCard extends StatelessWidget {
  final String title;
  final String value;
  final IconData icon;

  const _KpiCard({
    required this.title,
    required this.value,
    required this.icon,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFE9ECF3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              color: const Color(0xFFFDECEF),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(icon, color: const Color(0xFFCE1E2D)),
          ),
          const SizedBox(height: 12),
          Text(
            value,
            style: const TextStyle(
              fontSize: 22,
              fontWeight: FontWeight.bold,
              color: Color(0xFF1E2432),
            ),
          ),
          Text(
            title,
            style: const TextStyle(color: Color(0xFF616C83)),
          ),
        ],
      ),
    );
  }
}
