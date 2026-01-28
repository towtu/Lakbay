import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:geolocator/geolocator.dart';

class MapPage extends StatefulWidget {
  const MapPage({super.key});

  @override
  State<MapPage> createState() => _MapPageState();
}

class _MapPageState extends State<MapPage> {
  LatLng? _myLocation;
  // This variable stores the pin you just tapped
  LatLng? _selectedPin; 
  
  final MapController _mapController = MapController();
  double _currentZoom = 13.0;

  @override
  void initState() {
    super.initState();
    _determinePosition();
  }

  Future<void> _determinePosition() async {
    bool serviceEnabled;
    LocationPermission permission;

    serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) return;

    permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
      if (permission == LocationPermission.denied) return;
    }

    Position position = await Geolocator.getCurrentPosition();
    
    setState(() {
      _myLocation = LatLng(position.latitude, position.longitude);
    });

    _mapController.move(_myLocation!, _currentZoom);
  }

  Future<void> _launchMaps(double lat, double lng) async {
    final googleMapsUrl = Uri.parse("google.navigation:q=$lat,$lng&mode=d");
    if (await canLaunchUrl(googleMapsUrl)) {
      await launchUrl(googleMapsUrl);
    } else {
      final browserUrl = Uri.parse("https://www.google.com/maps/dir/?api=1&destination=$lat,$lng");
      await launchUrl(browserUrl);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Tap to Add Pin"), // Updated Title
        backgroundColor: Colors.blue,
        foregroundColor: Colors.white,
      ),
      body: FlutterMap(
        mapController: _mapController,
        options: MapOptions(
          initialCenter: const LatLng(12.8797, 121.7740), 
          initialZoom: _currentZoom,
          
          // --- THIS DETECTS YOUR TAP ---
          onTap: (tapPosition, point) {
            setState(() {
              _selectedPin = point; // Saves the location you tapped
            });
            
            // Show the popup immediately for the new pin
            _showPopup(context, point.latitude, point.longitude);
          },
        ),
        children: [
          TileLayer(
            urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
            userAgentPackageName: 'com.lakbay.app',
          ),
          
          MarkerLayer(
            markers: [
              // 1. BLUE DOT (YOU)
              if (_myLocation != null)
                Marker(
                  point: _myLocation!,
                  width: 60,
                  height: 60,
                  child: const Column(
                    children: [
                      Icon(Icons.my_location, color: Colors.blue, size: 30),
                      Text("Me", style: TextStyle(color: Colors.blue, fontWeight: FontWeight.bold)),
                    ],
                  ),
                ),
                
              // 2. RED PIN (THE ONE YOU TAPPED)
              if (_selectedPin != null)
                Marker(
                  point: _selectedPin!,
                  width: 80,
                  height: 80,
                  child: GestureDetector(
                    onTap: () => _showPopup(context, _selectedPin!.latitude, _selectedPin!.longitude),
                    child: const Icon(Icons.location_on, color: Colors.red, size: 50),
                  ),
                ),
            ],
          ),
        ],
      ),
    );
  }

  void _showPopup(BuildContext context, double lat, double lng) {
    showModalBottomSheet(
      context: context,
      builder: (context) => Container(
        height: 180,
        padding: const EdgeInsets.all(20),
        child: Column(
          children: [
            const Text("Selected Location", style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold)),
            const Text("Tap below to navigate here", style: TextStyle(color: Colors.grey)),
            const SizedBox(height: 20),
            ElevatedButton.icon(
              onPressed: () {
                Navigator.pop(context);
                _launchMaps(lat, lng);
              },
              icon: const Icon(Icons.directions),
              label: const Text("NAVIGATE HERE"),
              style: ElevatedButton.styleFrom(backgroundColor: Colors.blue, foregroundColor: Colors.white),
            )
          ],
        ),
      ),
    );
  }
}