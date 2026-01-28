import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:geolocator/geolocator.dart';
import 'package:http/http.dart' as http;

class AddTripPage extends StatefulWidget {
  const AddTripPage({super.key});

  @override
  State<AddTripPage> createState() => _AddTripPageState();
}

class _AddTripPageState extends State<AddTripPage> {
  final _formKey = GlobalKey<FormState>();
  final _budgetController = TextEditingController();
  final _destinationController = TextEditingController();

  DateTime? _selectedDate;
  TimeOfDay? _selectedTime;
  LatLng? _myLocation;
  LatLng? _destinationLocation;
  final MapController _mapController = MapController();
  bool _isLoading = false;
  
  List<dynamic> _suggestions = [];
  Timer? _debounce;

  @override
  void initState() {
    super.initState();
    // Fix for lag: Wait until page builds before asking for location
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _determinePosition();
    });
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _budgetController.dispose();
    _destinationController.dispose();
    _mapController.dispose();
    super.dispose();
  }

  // --- GET CURRENT LOCATION ---
  Future<void> _determinePosition() async {
    bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) return;

    LocationPermission permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
      if (permission == LocationPermission.denied) return;
    }

    if (!mounted) return;
    Position position = await Geolocator.getCurrentPosition();
    
    if (!mounted) return;
    setState(() {
      _myLocation = LatLng(position.latitude, position.longitude);
    });
  }

  // --- SEARCH SUGGESTIONS ---
  Future<void> _fetchSuggestions(String query) async {
    if (_debounce?.isActive ?? false) _debounce!.cancel();
    _debounce = Timer(const Duration(milliseconds: 1000), () async {
      if (!mounted) return;
      if (query.isEmpty) {
        setState(() => _suggestions = []);
        return;
      }
      final url = Uri.parse('https://nominatim.openstreetmap.org/search?q=$query&format=json&addressdetails=1&limit=5');
      try {
        final response = await http.get(url, headers: {'User-Agent': 'com.lakbay.app'});
        if (!mounted) return;
        if (response.statusCode == 200) {
          setState(() { _suggestions = json.decode(response.body); });
        }
      } catch (e) { /* ignore */ }
    });
  }

  void _selectSuggestion(dynamic suggestion) {
    final lat = double.parse(suggestion['lat']);
    final lon = double.parse(suggestion['lon']);
    final name = suggestion['display_name'].split(',')[0]; 

    setState(() {
      _destinationController.text = name;
      _destinationLocation = LatLng(lat, lon);
      _suggestions = [];
    });

    FocusScope.of(context).unfocus();
    if (_myLocation != null) {
      final bounds = LatLngBounds(_myLocation!, _destinationLocation!);
      _mapController.fitCamera(CameraFit.bounds(bounds: bounds, padding: const EdgeInsets.all(50)));
    } else {
      _mapController.move(_destinationLocation!, 12.0);
    }
  }

  // --- TAP ON MAP TO PIN ---
  Future<void> _handleTap(TapPosition tapPosition, LatLng point) async {
    setState(() {
      _destinationLocation = point;
      _destinationController.text = "Loading address...";
    });

    final url = Uri.parse(
        'https://nominatim.openstreetmap.org/reverse?format=json&lat=${point.latitude}&lon=${point.longitude}&zoom=18&addressdetails=1');
    try {
      final response = await http.get(url, headers: {'User-Agent': 'com.lakbay.app'});
      if (!mounted) return;
      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        String placeName = data['display_name'].split(',')[0];
        setState(() { _destinationController.text = placeName; });
      }
    } catch (e) {
      if (mounted) setState(() { _destinationController.text = "Pinned Location"; });
    }
  }

  // --- SAVE TRIP (SECURE VERSION) ---
  Future<void> _saveTrip() async {
    if (!_formKey.currentState!.validate()) return;
    
    if (_selectedDate == null || _selectedTime == null || _destinationLocation == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Please select a Location, Date, and Time"), backgroundColor: Colors.red)
      );
      return;
    }

    setState(() => _isLoading = true);

    try {
      // 1. GET THE CURRENT USER'S ID
      final userId = Supabase.instance.client.auth.currentUser?.id;
      
      if (userId == null) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("You must be logged in!"), backgroundColor: Colors.red));
        return;
      }

      final dateString = "${_selectedDate!.month}/${_selectedDate!.day}/${_selectedDate!.year}";
      final timeString = _selectedTime!.format(context);
      
      // 2. INSERT TRIP WITH USER_ID
      await Supabase.instance.client.from('trips').insert({
        'user_id': userId, // <--- IMPORTANT: Securely links trip to YOU
        'destination': "${_destinationController.text.trim()} ($dateString @ $timeString)", 
        'budget': int.parse(_budgetController.text.trim()),
        'latitude': _destinationLocation!.latitude,
        'longitude': _destinationLocation!.longitude,
      });

      if (mounted) {
        Navigator.pop(context); // Go back to Home
        
        // Show Success Message at Bottom
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Row(
              children: [
                Icon(Icons.check_circle, color: Colors.white),
                SizedBox(width: 10),
                Text("Trip Saved Successfully!"),
              ],
            ),
            backgroundColor: Colors.green,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
          ),
        );
      }
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Error: $e")));
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _pickDate() async {
    final DateTime? picked = await showDatePicker(
      context: context, initialDate: DateTime.now(), firstDate: DateTime.now(), lastDate: DateTime(2030),
    );
    if (picked != null) setState(() => _selectedDate = picked);
  }

  Future<void> _pickTime() async {
    final TimeOfDay? picked = await showTimePicker(context: context, initialTime: TimeOfDay.now());
    if (picked != null) setState(() => _selectedTime = picked);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("Plan New Trip")),
      body: SingleChildScrollView(
        child: Form(
          key: _formKey,
          child: Column(
            children: [
              Padding(
                padding: const EdgeInsets.all(20.0),
                child: Column(
                  children: [
                    // SEARCH INPUT
                    Column(
                      children: [
                        TextFormField(
                          controller: _destinationController,
                          onChanged: _fetchSuggestions,
                          decoration: const InputDecoration(
                            labelText: "Search or Tap on Map",
                            prefixIcon: Icon(Icons.search),
                            suffixIcon: Icon(Icons.touch_app, color: Colors.blue),
                            border: OutlineInputBorder(),
                          ),
                          validator: (value) => (value == null || value.isEmpty) ? 'Please search or tap map' : null,
                        ),
                        if (_suggestions.isNotEmpty)
                          Container(
                            color: Colors.white, height: 200,
                            child: ListView.builder(
                              itemCount: _suggestions.length,
                              itemBuilder: (context, index) {
                                final option = _suggestions[index];
                                return ListTile(
                                  leading: const Icon(Icons.location_on, color: Colors.blue),
                                  title: Text(option['display_name']),
                                  onTap: () => _selectSuggestion(option),
                                );
                              },
                            ),
                          ),
                      ],
                    ),
                    const SizedBox(height: 15),

                    // BUDGET INPUT
                    TextFormField(
                      controller: _budgetController,
                      keyboardType: TextInputType.number,
                      decoration: const InputDecoration(
                        labelText: "Budget (₱)",
                        prefixIcon: Icon(Icons.attach_money),
                        border: OutlineInputBorder(),
                      ),
                      validator: (value) {
                        if (value == null || value.isEmpty) return 'Please enter a budget';
                        if (int.tryParse(value) == null) return 'Numbers only';
                        return null;
                      },
                    ),
                    const SizedBox(height: 15),

                    // DATE & TIME
                    Row(
                      children: [
                        Expanded(
                          child: InkWell(
                            onTap: _pickDate,
                            child: Container(
                              padding: const EdgeInsets.symmetric(vertical: 15, horizontal: 10),
                              decoration: BoxDecoration(border: Border.all(color: _selectedDate == null ? Colors.grey : Colors.blue), borderRadius: BorderRadius.circular(5)),
                              child: Row(children: [Icon(Icons.calendar_today, color: _selectedDate == null ? Colors.grey : Colors.blue), const SizedBox(width: 10), Text(_selectedDate == null ? "Select Date" : "${_selectedDate!.month}/${_selectedDate!.day}")]),
                            ),
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: InkWell(
                            onTap: _pickTime,
                            child: Container(
                              padding: const EdgeInsets.symmetric(vertical: 15, horizontal: 10),
                              decoration: BoxDecoration(border: Border.all(color: _selectedTime == null ? Colors.grey : Colors.blue), borderRadius: BorderRadius.circular(5)),
                              child: Row(children: [Icon(Icons.access_time, color: _selectedTime == null ? Colors.grey : Colors.blue), const SizedBox(width: 10), Text(_selectedTime == null ? "Select Time" : _selectedTime!.format(context))]),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),

              // MAP PREVIEW
              SizedBox(
                height: 350,
                child: FlutterMap(
                  mapController: _mapController,
                  options: MapOptions(
                    initialCenter: const LatLng(12.8797, 121.7740),
                    initialZoom: 5.0,
                    onTap: _handleTap, // Enables Tapping on Map
                  ),
                  children: [
                    TileLayer(urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png', userAgentPackageName: 'com.lakbay.app'),
                    MarkerLayer(
                      markers: [
                        if (_myLocation != null) Marker(point: _myLocation!, width: 60, height: 60, child: const Icon(Icons.my_location, color: Colors.blue)),
                        if (_destinationLocation != null) Marker(point: _destinationLocation!, width: 80, height: 80, child: const Icon(Icons.location_on, color: Colors.red, size: 50)),
                      ],
                    ),
                    if (_myLocation != null && _destinationLocation != null)
                      PolylineLayer(polylines: [Polyline(points: [_myLocation!, _destinationLocation!], strokeWidth: 4.0, color: Colors.blueAccent, isDotted: true)]),
                  ],
                ),
              ),

              // SAVE BUTTON
              Padding(
                padding: const EdgeInsets.all(20.0),
                child: SizedBox(
                  width: double.infinity,
                  height: 50,
                  child: ElevatedButton(
                    onPressed: _isLoading ? null : _saveTrip,
                    style: ElevatedButton.styleFrom(backgroundColor: Colors.blue, foregroundColor: Colors.white),
                    child: _isLoading ? const CircularProgressIndicator() : const Text("SAVE TRIP"),
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