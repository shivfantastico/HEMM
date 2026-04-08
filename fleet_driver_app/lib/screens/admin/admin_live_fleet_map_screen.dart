import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';

import '../../services/api_service.dart';
import 'widgets/admin_branding.dart';

class AdminLiveFleetMapScreen extends StatefulWidget {
  const AdminLiveFleetMapScreen({super.key});

  @override
  State<AdminLiveFleetMapScreen> createState() => _AdminLiveFleetMapScreenState();
}

class _AdminLiveFleetMapScreenState extends State<AdminLiveFleetMapScreen> {
  static const LatLng _defaultPlantCenter = LatLng(19.0760, 72.8777);

  final Completer<GoogleMapController> _mapController = Completer();
  Set<Marker> _markers = <Marker>{};
  bool _loading = true;
  String? _error;
  Timer? _pollingTimer;

  @override
  void initState() {
    super.initState();
    _fetchVehicleLocations();
    _pollingTimer = Timer.periodic(
      const Duration(seconds: 15),
      (_) => _fetchVehicleLocations(silent: true),
    );
  }

  @override
  void dispose() {
    _pollingTimer?.cancel();
    super.dispose();
  }

  Future<void> _fetchVehicleLocations({bool silent = false}) async {
    if (!silent) {
      setState(() {
        _loading = true;
        _error = null;
      });
    }

    try {
      final endpoints = <String>[
        '/location',
        '/api/location',
        '/api/admin/location',
        '/api/admin/vehicle-locations',
      ];
      dynamic response;
      String? successfulEndpoint;

      for (final endpoint in endpoints) {
        final candidate = await ApiService.get(
          endpoint,
          auth: true,
        );
        if (candidate.statusCode == 200) {
          response = candidate;
          successfulEndpoint = endpoint;
          break;
        }
      }

      if (response == null) {
        setState(() {
          _loading = false;
          _error = 'Failed to load vehicle locations (404). Checked: /location, /api/location, /api/admin/location, /api/admin/vehicle-locations';
        });
        return;
      }

      final decoded = jsonDecode(response.body);
      final List rawList;
      if (decoded is Map && decoded['locations'] is List) {
        rawList = decoded['locations'] as List;
      } else if (decoded is Map && decoded['vehicles'] is List) {
        rawList = decoded['vehicles'] as List;
      } else if (decoded is Map && decoded['data'] is List) {
        rawList = decoded['data'] as List;
      } else if (decoded is List) {
        rawList = decoded;
      } else {
        rawList = [];
      }

      final markers = <Marker>{};

      for (final item in rawList) {
        if (item is! Map) continue;
        final row = Map<String, dynamic>.from(item);

        final lat = _asDouble(
          row['latitude'] ?? row['lat'] ?? row['current_lat'] ?? row['currentLatitude'],
        );
        final lng = _asDouble(
          row['longitude'] ?? row['lng'] ?? row['lon'] ?? row['current_lng'] ?? row['currentLongitude'],
        );

        if (lat == null || lng == null) continue;

        final vehicleNumber = (row['vehicle_number'] ?? row['vehicleNo'] ?? 'Unknown Vehicle').toString();
        final status = (row['trip_status'] ?? row['status'] ?? 'UNKNOWN').toString();
        final driver = (row['driver_name'] ?? row['driver'] ?? 'No Driver').toString();

        markers.add(
          Marker(
            markerId: MarkerId(vehicleNumber),
            position: LatLng(lat, lng),
            infoWindow: InfoWindow(
              title: vehicleNumber,
              snippet: '$status | $driver',
            ),
          ),
        );
      }

      setState(() {
        _markers = markers;
        _loading = false;
        _error = markers.isEmpty
            ? 'No vehicle locations found. Check API payload keys: lat/lng or latitude/longitude.'
            : null;
      });

      if (!silent && successfulEndpoint != null) {
        debugPrint('Live map endpoint: $successfulEndpoint');
      }

      if (markers.isNotEmpty) {
        final controller = await _mapController.future;
        await controller.animateCamera(
          CameraUpdate.newLatLng(markers.first.position),
        );
      }
    } catch (_) {
      setState(() {
        _loading = false;
        _error = 'Unable to load live map right now.';
      });
    }
  }

  double? _asDouble(dynamic value) {
    if (value is num) return value.toDouble();
    if (value is String) return double.tryParse(value);
    return null;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AdminBranding.background,
      appBar: AdminBranding.appBar(
        title: 'Live Fleet Map',
        actions: [
          IconButton(
            onPressed: () => _fetchVehicleLocations(),
            icon: const Icon(Icons.refresh),
            tooltip: 'Refresh',
          ),
        ],
      ),
      body: Stack(
        children: [
          GoogleMap(
            initialCameraPosition: const CameraPosition(
              target: _defaultPlantCenter,
              zoom: 16,
            ),
            myLocationButtonEnabled: false,
            markers: _markers,
            onMapCreated: (controller) {
              if (!_mapController.isCompleted) {
                _mapController.complete(controller);
              }
            },
          ),
          if (_loading)
            const Center(child: CircularProgressIndicator()),
          if (_error != null)
            Align(
              alignment: Alignment.bottomCenter,
              child: Container(
                margin: const EdgeInsets.all(12),
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: const Color(0xFFFFCDD2)),
                ),
                child: Text(
                  _error!,
                  style: const TextStyle(color: Color(0xFFB3261E)),
                  textAlign: TextAlign.center,
                ),
              ),
            ),
        ],
      ),
    );
  }
}
