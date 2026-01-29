import 'dart:convert';
import 'dart:async'; // Required for the Timer
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:intl/intl.dart';
import 'package:http/http.dart' as http;
import 'package:travel_planner/utils/web_container.dart';

class AddTripPage extends StatefulWidget {
  const AddTripPage({super.key});
  @override
  State<AddTripPage> createState() => _AddTripPageState();
}

class _AddTripPageState extends State<AddTripPage> {
  final _formKey = GlobalKey<FormState>();
  final _destinationController = TextEditingController();
  final _budgetController = TextEditingController();
  final MapController _mapController = MapController();
  
  // Default: Manila (Prevents null error on map load)
  LatLng _selectedLocation = const LatLng(14.5995, 120.9842); 
  
  // Suggestion Variables
  List<dynamic> _suggestions = [];
  Timer? _debounce;
  bool _isLoadingSuggestions = false;

  DateTime? _startDate;
  DateTime? _endDate;
  final DateFormat _dateFormat = DateFormat('MMM dd, yyyy');

  // 🔍 SAFE SEARCH (Debounced)
  // Waits for 1 second of silence before searching to save API usage
  void _onSearchChanged(String query) {
    if (_debounce?.isActive ?? false) _debounce!.cancel();
    
    _debounce = Timer(const Duration(milliseconds: 1000), () {
      if (query.length > 2) { 
        _fetchSuggestions(query);
      } else {
        setState(() => _suggestions = []);
      }
    });
  }

  Future<void> _fetchSuggestions(String query) async {
    setState(() => _isLoadingSuggestions = true);
    try {
      final url = Uri.parse('https://nominatim.openstreetmap.org/search?q=$query&format=json&addressdetails=1&limit=5');
      final response = await http.get(url, headers: {'User-Agent': 'LakbayApp/1.0'});

      if (response.statusCode == 200) {
        setState(() {
          _suggestions = json.decode(response.body);
          _isLoadingSuggestions = false;
        });
      }
    } catch (e) {
      setState(() => _isLoadingSuggestions = false);
    }
  }

  // When you select a suggestion from the list
  void _selectSuggestion(dynamic suggestion) {
    final lat = double.parse(suggestion['lat']);
    final lon = double.parse(suggestion['lon']);
    final name = suggestion['display_name'].split(',')[0]; // Keep it short

    setState(() {
      _selectedLocation = LatLng(lat, lon);
      _destinationController.text = name;
      _suggestions = []; // Hide list
    });
    
    _mapController.move(_selectedLocation, 12.0);
    FocusScope.of(context).unfocus(); // Hide keyboard
  }

  // 📍 Map -> Text (Reverse Geocoding)
  // When you tap the map, it fills the text box
  Future<void> _updateAddressFromPin(LatLng pos) async {
    setState(() => _selectedLocation = pos);
    try {
      final url = Uri.parse('https://nominatim.openstreetmap.org/reverse?format=json&lat=${pos.latitude}&lon=${pos.longitude}&zoom=10');
      final response = await http.get(url, headers: {'User-Agent': 'LakbayApp/1.0'});

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        if (data['display_name'] != null) {
          String name = data['address']['city'] ?? data['address']['town'] ?? data['address']['village'] ?? "";
          String country = data['address']['country'] ?? "";
          
          if (name.isEmpty) {
             _destinationController.text = data['display_name'].split(',')[0];
          } else {
             _destinationController.text = "$name, $country";
          }
        }
      }
    } catch (e) {
      // Ignore errors, just keep the pin
    }
  }

  Future<void> _selectDate(BuildContext context, bool isStart) async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: isStart ? (_startDate ?? DateTime.now()) : (_endDate ?? _startDate ?? DateTime.now()),
      firstDate: DateTime.now(),
      lastDate: DateTime(2100),
    );
    if (picked != null) {
      setState(() {
        if (isStart) {
          _startDate = picked;
          if (_endDate != null && _endDate!.isBefore(_startDate!)) {
            _endDate = null;
          }
        } else {
          _endDate = picked;
        }
      });
    }
  }

  Future<void> _saveTrip() async {
    if (!_formKey.currentState!.validate()) return;
    if (_startDate == null || _endDate == null) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Please select both start and end dates.")));
      return;
    }

    final userId = Supabase.instance.client.auth.currentUser!.id;
    
    await Supabase.instance.client.from('trips').insert({
      'user_id': userId,
      'destination': _destinationController.text.trim(),
      
      // 🚀 FIX: Convert to Integer (.toInt()) to match database type 'bigint'
      'budget': double.parse(_budgetController.text.trim()).toInt(),
      
      'latitude': _selectedLocation.latitude,
      'longitude': _selectedLocation.longitude,
      'start_date': _startDate!.toIso8601String(),
      'end_date': _endDate!.toIso8601String(),
    });

    if (mounted) Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("Plan a New Trip")),
      body: WebContainer(
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // 🗺️ MAP SECTION
              SizedBox(
                height: 300,
                child: Stack(
                  children: [
                    FlutterMap(
                      mapController: _mapController,
                      options: MapOptions(
                        initialCenter: _selectedLocation,
                        initialZoom: 12.0,
                        onTap: (_, latlng) => _updateAddressFromPin(latlng),
                      ),
                      children: [
                        TileLayer(
                          urlTemplate: 'https://{s}.basemaps.cartocdn.com/light_all/{z}/{x}/{y}.png', 
                          subdomains: const ['a', 'b', 'c', 'd'],
                        ),
                        MarkerLayer(
                          markers: [
                            Marker(
                              point: _selectedLocation,
                              width: 50,
                              height: 50,
                              child: const Icon(Icons.location_on, color: Colors.red, size: 50),
                            ),
                          ],
                        ),
                      ],
                    ),
                    Positioned(
                      top: 10, left: 10, right: 10,
                      child: Container(
                        padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 12),
                        decoration: BoxDecoration(color: Colors.white.withOpacity(0.9), borderRadius: BorderRadius.circular(8)),
                        child: const Text("Tap map to pin location", textAlign: TextAlign.center, style: TextStyle(fontWeight: FontWeight.bold)),
                      ),
                    ),
                  ],
                ),
              ),

              // 📝 FORM SECTION
              Padding(
                padding: const EdgeInsets.all(24),
                child: Form(
                  key: _formKey,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      // DESTINATION FIELD + SUGGESTIONS LIST
                      Column(
                        children: [
                          TextFormField(
                            controller: _destinationController,
                            onChanged: _onSearchChanged, // 👈 Triggers Search
                            decoration: InputDecoration(
                              labelText: "Destination Name",
                              hintText: "Type to search (e.g., Cebu)",
                              border: const OutlineInputBorder(),
                              filled: true,
                              fillColor: Colors.white,
                              suffixIcon: _isLoadingSuggestions 
                                  ? const Padding(padding: EdgeInsets.all(10), child: CircularProgressIndicator(strokeWidth: 2)) 
                                  : const Icon(Icons.search),
                            ),
                            validator: (v) => v!.isEmpty ? "Required" : null,
                          ),
                          // THE SUGGESTIONS LIST
                          if (_suggestions.isNotEmpty)
                            Container(
                              color: Colors.white,
                              height: 200, 
                              child: ListView.separated(
                                itemCount: _suggestions.length,
                                separatorBuilder: (context, index) => const Divider(height: 1),
                                itemBuilder: (context, index) {
                                  final item = _suggestions[index];
                                  return ListTile(
                                    title: Text(item['display_name'].split(',')[0], style: const TextStyle(fontWeight: FontWeight.bold)),
                                    subtitle: Text(item['display_name'], maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 12)),
                                    leading: const Icon(Icons.location_on, color: Colors.grey),
                                    onTap: () => _selectSuggestion(item),
                                  );
                                },
                              ),
                            ),
                        ],
                      ),
                      const SizedBox(height: 15),
                      
                      // BUDGET FIELD
                      TextFormField(
                        controller: _budgetController,
                        keyboardType: TextInputType.number,
                        decoration: const InputDecoration(labelText: "Total Budget (₱)", border: OutlineInputBorder(), prefixIcon: Icon(Icons.account_balance_wallet)),
                        validator: (v) => v!.isEmpty ? "Required" : null,
                      ),
                      const SizedBox(height: 15),
                      
                      // DATES
                      Row(
                        children: [
                          Expanded(child: InkWell(onTap: () => _selectDate(context, true), child: InputDecorator(decoration: const InputDecoration(labelText: "Start Date", border: OutlineInputBorder(), prefixIcon: Icon(Icons.calendar_today)), child: Text(_startDate == null ? "Select" : _dateFormat.format(_startDate!))))),
                          const SizedBox(width: 10),
                          Expanded(child: InkWell(onTap: () => _selectDate(context, false), child: InputDecorator(decoration: const InputDecoration(labelText: "End Date", border: OutlineInputBorder(), prefixIcon: Icon(Icons.event)), child: Text(_endDate == null ? "Select" : _dateFormat.format(_endDate!))))),
                        ],
                      ),
                      const SizedBox(height: 30),

                      // SAVE BUTTON
                      SizedBox(
                        height: 55,
                        child: ElevatedButton(
                          onPressed: _saveTrip,
                          style: ElevatedButton.styleFrom(backgroundColor: Colors.blue, foregroundColor: Colors.white, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10))),
                          child: const Text("CREATE TRIP", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                        ),
                      ),
                    ],
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