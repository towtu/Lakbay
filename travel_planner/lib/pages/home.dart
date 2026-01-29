import 'dart:convert'; // For encoding data to save
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:intl/intl.dart';
import 'package:flutter_speed_dial/flutter_speed_dial.dart';
import 'package:shared_preferences/shared_preferences.dart'; // Local Storage
import 'package:travel_planner/utils/web_container.dart';
import 'login.dart';
import 'add_trip.dart';
import 'calendar_page.dart';
import 'trip_details.dart';

class HomePage extends StatefulWidget {
  const HomePage({super.key});
  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  final currencyFormat = NumberFormat("#,##0", "en_US");
  late Future<List<Map<String, dynamic>>> _tripsFuture;
  bool _isOffline = false; // To track if we are using cached data

  @override
  void initState() {
    super.initState();
    _tripsFuture = _fetchTrips();
  }

  // 🔌 SMART FETCH: Internet First -> Fallback to Cache
  Future<List<Map<String, dynamic>>> _fetchTrips() async {
    try {
      // 1. Try to get fresh data from Supabase
      final userId = Supabase.instance.client.auth.currentUser!.id;
      final response = await Supabase.instance.client
          .from('trips')
          .select()
          .or('user_id.eq.$userId,join_code.neq.null')
          .order('start_date', ascending: true);

      // 2. If successful, SAVE it to phone storage (Cache it)
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('cached_trips', json.encode(response));

      if (mounted) setState(() => _isOffline = false);
      return List<Map<String, dynamic>>.from(response);

    } catch (e) {
      // 3. If Internet fails, LOAD from phone storage
      print("Network Error: $e"); // Debug info
      final prefs = await SharedPreferences.getInstance();
      if (prefs.containsKey('cached_trips')) {
        final cachedData = json.decode(prefs.getString('cached_trips')!);
        
        if (mounted) {
          setState(() => _isOffline = true);
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text("You are offline. Showing cached trips."),
              backgroundColor: Colors.orange,
              duration: Duration(seconds: 3),
            )
          );
        }
        return List<Map<String, dynamic>>.from(cachedData);
      }
      
      // 4. If no cache and no internet, show error
      throw "No internet and no saved trips.";
    }
  }

  void _refreshTrips() {
    setState(() {
      _tripsFuture = _fetchTrips();
    });
  }

  Future<void> _logout() async {
    await Supabase.instance.client.auth.signOut();
    if (mounted) Navigator.pushReplacement(context, MaterialPageRoute(builder: (context) => const LoginPage()));
  }

  // ... (Join Dialog code remains the same as before) ...
  Future<void> _joinTripDialog() async {
    final codeController = TextEditingController();
    await showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text("Join a Trip"),
        content: Column(mainAxisSize: MainAxisSize.min, children: [const Text("Enter Trip Code:"), TextField(controller: codeController)]),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text("Cancel")),
          ElevatedButton(onPressed: () => _submitJoinRequest(codeController.text.trim()), child: const Text("Join")),
        ],
      ),
    );
  }
  
  Future<void> _submitJoinRequest(String code) async {
    if (code.isEmpty) return;
    Navigator.pop(context);
    try {
      final tripData = await Supabase.instance.client.from('trips').select('id').eq('join_code', code).maybeSingle();
      if (tripData == null) return;
      final user = Supabase.instance.client.auth.currentUser!;
      await Supabase.instance.client.from('join_requests').insert({'trip_id': tripData['id'], 'user_id': user.id, 'email': user.email, 'status': 'pending'});
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Request sent!")));
    } catch (_) {}
  }

  Future<void> _deleteTrip(int id) async {
    if (_isOffline) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Cannot delete while offline.")));
      return;
    }
    try {
      await Supabase.instance.client.from('trips').delete().eq('id', id);
      _refreshTrips();
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Only the owner can delete this trip.")));
    }
  }

  Widget _buildTripCard(Map<String, dynamic> trip) {
    final bool isOwner = trip['user_id'] == Supabase.instance.client.auth.currentUser?.id;
    final String? startDateStr = trip['start_date'];
    String subtitle = "Budget: ₱${currencyFormat.format(trip['budget'])}";
    if (startDateStr != null) {
      subtitle += "\nStarts: ${DateFormat('MMM dd, yyyy').format(DateTime.parse(startDateStr))}";
    }

    return Card(
      elevation: 4,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: () async {
          if (_isOffline) {
            ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Viewing details requires internet for now.")));
            // You can remove this check if you implement full offline caching for details later
          } else {
            await Navigator.push(context, MaterialPageRoute(builder: (context) => TripDetailsPage(trip: trip)));
            _refreshTrips();
          }
        },
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              height: 100,
              decoration: BoxDecoration(color: Colors.blue.shade100, borderRadius: const BorderRadius.vertical(top: Radius.circular(16))),
              child: Center(child: Icon(Icons.location_city, size: 40, color: Colors.blue.shade300)),
            ),
            Padding(
              padding: const EdgeInsets.all(12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
                    Expanded(child: Text(trip['destination'] ?? "Unknown", style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18), overflow: TextOverflow.ellipsis)),
                    isOwner ? IconButton(icon: const Icon(Icons.delete_outline, color: Colors.red, size: 20), onPressed: () => _deleteTrip(trip['id'])) : const Icon(Icons.people, color: Colors.green, size: 20),
                  ]),
                  const SizedBox(height: 8),
                  Text(subtitle, style: TextStyle(color: Colors.grey[700], height: 1.4)),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[50],
      appBar: AppBar(
        // 🎨 NEW DESIGN: Centered, Bold Title
        centerTitle: true,
        title: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.travel_explore, color: Colors.blue), // Logo Icon
            const SizedBox(width: 8),
            Text(
              "LAKBAY", 
              style: TextStyle(
                fontWeight: FontWeight.w900, // Extra Bold
                letterSpacing: 3.0, // Wide spacing looks premium
                color: Colors.blue.shade800
              )
            ),
          ],
        ),
        elevation: 0,
        backgroundColor: Colors.white,
        iconTheme: const IconThemeData(color: Colors.black), // Black Logout Icon
        actions: [
          IconButton(onPressed: _logout, icon: const Icon(Icons.logout)),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: () async { _refreshTrips(); },
        child: FutureBuilder<List<Map<String, dynamic>>>(
          future: _tripsFuture,
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) return const Center(child: CircularProgressIndicator());
            
            // If error AND we couldn't load from cache
            if (snapshot.hasError) return Center(child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [const Icon(Icons.wifi_off, size: 50, color: Colors.grey), const SizedBox(height: 10), Text("No Internet & No Cached Data.\n${snapshot.error}", textAlign: TextAlign.center)]));
            
            final trips = snapshot.data ?? [];

            return SingleChildScrollView(
              padding: const EdgeInsets.all(20),
              physics: const AlwaysScrollableScrollPhysics(),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // 📶 OFFLINE BANNER (Only shows if offline)
                  if (_isOffline)
                    Container(
                      margin: const EdgeInsets.only(bottom: 20),
                      padding: const EdgeInsets.all(12),
                      width: double.infinity,
                      decoration: BoxDecoration(color: Colors.orange.shade100, borderRadius: BorderRadius.circular(10), border: Border.all(color: Colors.orange)),
                      child: const Row(children: [Icon(Icons.wifi_off, color: Colors.orange), SizedBox(width: 10), Expanded(child: Text("You are offline. Showing last saved trips.", style: TextStyle(color: Colors.brown)))])
                    ),

                  // 📊 WELCOME & STATS
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(24),
                    decoration: BoxDecoration(gradient: LinearGradient(colors: [Colors.blue.shade800, Colors.blue.shade500]), borderRadius: BorderRadius.circular(20)),
                    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      const Text("Ready for your next adventure?", style: TextStyle(color: Colors.white, fontSize: 24, fontWeight: FontWeight.bold)),
                      const SizedBox(height: 10),
                      Text("You have ${trips.length} upcoming trips planned.", style: const TextStyle(color: Colors.white70, fontSize: 16)),
                    ]),
                  ),
                  const SizedBox(height: 30),
                  
                  const Text("Your Trips", style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 15),

                  if (trips.isEmpty) const Center(child: Padding(padding: EdgeInsets.all(40), child: Text("No trips yet. Tap + to start planning!", style: TextStyle(color: Colors.grey, fontSize: 16)))),

                  // 📏 GRID LAYOUT
                  LayoutBuilder(
                    builder: (context, constraints) {
                      int crossAxisCount = 1;
                      if (constraints.maxWidth > 1100) crossAxisCount = 4;
                      else if (constraints.maxWidth > 800) crossAxisCount = 3;
                      else if (constraints.maxWidth > 600) crossAxisCount = 2;

                      return GridView.builder(
                        shrinkWrap: true,
                        physics: const NeverScrollableScrollPhysics(),
                        gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(crossAxisCount: crossAxisCount, crossAxisSpacing: 20, mainAxisSpacing: 20, childAspectRatio: 1.3),
                        itemCount: trips.length,
                        itemBuilder: (context, index) => _buildTripCard(trips[index]),
                      );
                    },
                  ),
                  const SizedBox(height: 100),
                ],
              ),
            );
          },
        ),
      ),
      floatingActionButton: SpeedDial(
        icon: Icons.menu,
        activeIcon: Icons.close,
        backgroundColor: Colors.blue,
        foregroundColor: Colors.white,
        activeBackgroundColor: Colors.red,
        activeForegroundColor: Colors.white,
        children: [
          SpeedDialChild(child: const Icon(Icons.add), backgroundColor: Colors.blue, foregroundColor: Colors.white, label: 'Add Trip', onTap: () async { await Navigator.push(context, MaterialPageRoute(builder: (context) => const AddTripPage())); _refreshTrips(); }),
          SpeedDialChild(child: const Icon(Icons.calendar_month), backgroundColor: Colors.green, foregroundColor: Colors.white, label: 'Calendar', onTap: () => Navigator.push(context, MaterialPageRoute(builder: (context) => const CalendarPage()))),
          SpeedDialChild(child: const Icon(Icons.link), backgroundColor: Colors.orange, foregroundColor: Colors.white, label: 'Join Trip', onTap: _joinTripDialog),
        ],
      ),
    );
  }
}