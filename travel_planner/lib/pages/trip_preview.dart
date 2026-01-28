import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:url_launcher/url_launcher.dart';

class TripPreviewPage extends StatefulWidget {
  final String tripName;
  final double lat;
  final double lng;

  const TripPreviewPage({
    super.key, 
    required this.tripName, 
    required this.lat, 
    required this.lng
  });

  @override
  State<TripPreviewPage> createState() => _TripPreviewPageState();
}

class _TripPreviewPageState extends State<TripPreviewPage> {
  
  Future<void> _launchGoogleMaps() async {
    // FIX: Using the official Google Maps Direction API link.
    // This format works on all phones and browsers.
    final googleMapsUrl = Uri.parse(
        "https://www.google.com/maps/dir/?api=1&destination=${widget.lat},${widget.lng}&travelmode=driving");

    try {
      if (await canLaunchUrl(googleMapsUrl)) {
        await launchUrl(googleMapsUrl, mode: LaunchMode.externalApplication);
      } else {
        // If the app is not installed, open the browser version
        await launchUrl(googleMapsUrl);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("Could not open maps: $e")),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        // Shows the city name (hides the date/time)
        title: Text(widget.tripName.split('(')[0]),
        backgroundColor: Colors.blue,
        foregroundColor: Colors.white,
      ),
      body: Stack(
        children: [
          // 1. THE INTERNAL MAP PREVIEW
          FlutterMap(
            options: MapOptions(
              initialCenter: LatLng(widget.lat, widget.lng),
              initialZoom: 15.0,
            ),
            children: [
              TileLayer(
                urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                userAgentPackageName: 'com.lakbay.app',
              ),
              MarkerLayer(
                markers: [
                  Marker(
                    point: LatLng(widget.lat, widget.lng),
                    width: 100,
                    height: 100,
                    child: const Column(
                      children: [
                        Icon(Icons.location_on, color: Colors.red, size: 50),
                      ],
                    ),
                  ),
                ],
              ),
            ],
          ),

          // 2. THE BOTTOM SHEET (Details + Button)
          Align(
            alignment: Alignment.bottomCenter,
            child: Container(
              margin: const EdgeInsets.all(20),
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(20),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.2),
                    blurRadius: 10,
                    offset: const Offset(0, 5),
                  ),
                ],
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    widget.tripName.split('(')[0], 
                    style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 5),
                  Text(
                    "Coordinates: ${widget.lat.toStringAsFixed(4)}, ${widget.lng.toStringAsFixed(4)}",
                    style: const TextStyle(color: Colors.grey),
                  ),
                  const SizedBox(height: 20),
                  
                  // THE BUTTON
                  SizedBox(
                    width: double.infinity,
                    height: 50,
                    child: ElevatedButton.icon(
                      onPressed: _launchGoogleMaps,
                      icon: const Icon(Icons.directions),
                      label: const Text("GET DIRECTIONS (GOOGLE MAPS)"),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.blue,
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
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