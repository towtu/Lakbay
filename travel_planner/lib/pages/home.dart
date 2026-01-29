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

  // 🔌 SMART FETCH: Sync Offline Queue -> Try Internet -> Fallback to Cache
  Future<List<Map<String, dynamic>>> _fetchTrips() async {
    final prefs = await SharedPreferences.getInstance();
    final userId = Supabase.instance.client.auth.currentUser!.id;
    
    List<Map<String, dynamic>> combinedTrips = [];

    // --- STEP 1: LOAD OFFLINE QUEUE (Pending Trips) ---
    List<String> offlineQueue = prefs.getStringList('offline_queue') ?? [];
    List<Map<String, dynamic>> offlineTrips = offlineQueue.map((e) => json.decode(e) as Map<String, dynamic>).toList();

    // --- STEP 2: TRY SYNCING (If Internet Available) ---
    if (offlineTrips.isNotEmpty) {
      try {
        for (var trip in offlineTrips) {
          trip.remove('id'); // Remove fake ID before uploading
          await Supabase.instance.client.from('trips').insert(trip);
        }
        // If successful, clear the queue!
        await prefs.setStringList('offline_queue', []);
        offlineTrips.clear(); 
        if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Synced offline trips to cloud! ☁️"), backgroundColor: Colors.green));
      } catch (e) {
        // If sync fails, we keep 'offlineTrips' to show the user
        // We silently fail here so the app doesn't crash
      }
    }

    // --- STEP 3: FETCH ONLINE TRIPS ---
    try {
      final response = await Supabase.instance.client
          .from('trips')
          .select()
          .or('user_id.eq.$userId,join_code.neq.null')
          .order('start_date', ascending: true);
      
      // Save successful load to cache
      await prefs.setString('cached_trips', json.encode(response));
      
      combinedTrips.addAll(List<Map<String, dynamic>>.from(response));
      if (mounted) setState(() => _isOffline = false);

    } catch (e) {
      // --- STEP 4: FALLBACK TO CACHE (If Internet Fails) ---
      if (prefs.containsKey('cached_trips')) {
        final cachedData = json.decode(prefs.getString('cached_trips')!);
        combinedTrips.addAll(List<Map<String, dynamic>>.from(cachedData));
      }
      if (mounted) setState(() => _isOffline = true);
    }

    // Merge offline pending trips at the top
    return [...offlineTrips, ...combinedTrips];
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

  // --- 🔗 JOIN TRIP LOGIC ---
  Future<void> _joinTripDialog() async {
    final codeController = TextEditingController();
    await showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text("Join a Trip"),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text("Enter the Trip Code shared by the owner."),
            const SizedBox(height: 10),
            TextField(
              controller: codeController,
              decoration: const InputDecoration(labelText: "Trip Code (e.g., LAK-123)", border: OutlineInputBorder()),
            ),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text("Cancel")),
          ElevatedButton(
            onPressed: () => _submitJoinRequest(codeController.text.trim()),
            child: const Text("Request to Join"),
          ),
        ],
      ),
    );
  }

  // 🚀 FIXED: Smart Join with Trim & Keyhole Function
  Future<void> _submitJoinRequest(String code) async {
    // 1. CLEAN INPUT
    String cleanCode = code.trim();
    if (cleanCode.isEmpty) return;
    Navigator.pop(context); 

    try {
      // 2. CALL THE "KEYHOLE" FUNCTION
      final tripId = await Supabase.instance.client.rpc('get_trip_id_by_code', params: {'code_text': cleanCode});

      if (tripId == null) {
        if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Invalid Code. Trip not found.")));
        return;
      }

      // 3. CHECK DUPLICATES
      final user = Supabase.instance.client.auth.currentUser!;
      final existing = await Supabase.instance.client.from('join_requests').select().eq('trip_id', tripId).eq('user_id', user.id).maybeSingle();
      
      if (existing != null) {
         if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("You have already sent a request (Status: ${existing['status']}).")));
         return;
      }

      // 4. SEND REQUEST
      await Supabase.instance.client.from('join_requests').insert({
        'trip_id': tripId,
        'user_id': user.id,
        'email': user.email,
        'status': 'pending'
      });

      if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Request sent! Ask the owner to approve you."), backgroundColor: Colors.green));

    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Error: $e"), backgroundColor: Colors.red));
    }
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

  // 🎨 TRIP CARD WIDGET
  Widget _buildTripCard(Map<String, dynamic> trip) {
    // Check if offline (has negative ID)
    final bool isOfflineTrip = (trip['id'] is int) && (trip['id'] as int) < 0;
    
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
          // If offline, we still allow clicking, but details page handles missing data gracefully
          await Navigator.push(context, MaterialPageRoute(builder: (context) => TripDetailsPage(trip: trip)));
          if (!isOfflineTrip) _refreshTrips(); // Refresh on return if online
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
                    Expanded(
                      child: Row(
                        children: [
                          if (isOfflineTrip) const Padding(padding: EdgeInsets.only(right: 5), child: Icon(Icons.cloud_upload, size: 16, color: Colors.orange)),
                          Expanded(child: Text(trip['destination'] ?? "Unknown", style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18), overflow: TextOverflow.ellipsis)),
                        ],
                      )
                    ),
                    if (!isOfflineTrip)
                      isOwner 
                        ? IconButton(icon: const Icon(Icons.delete_outline, color: Colors.red, size: 20), onPressed: () => _deleteTrip(trip['id'])) 
                        : const Icon(Icons.people, color: Colors.green, size: 20),
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
        centerTitle: true,
        title: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.travel_explore, color: Colors.blue),
            const SizedBox(width: 8),
            Text(
              "LAKBAY", 
              style: TextStyle(fontWeight: FontWeight.w900, letterSpacing: 3.0, color: Colors.blue.shade800)
            ),
          ],
        ),
        elevation: 0,
        backgroundColor: Colors.white,
        iconTheme: const IconThemeData(color: Colors.black),
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
            
            // If error AND offline, show message
            if (snapshot.hasError && !_isOffline) return Center(child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [const Icon(Icons.wifi_off, size: 50, color: Colors.grey), const SizedBox(height: 10), Text("Network Error.\n${snapshot.error}", textAlign: TextAlign.center)]));
            
            final trips = snapshot.data ?? [];

            return SingleChildScrollView(
              padding: const EdgeInsets.all(20),
              physics: const AlwaysScrollableScrollPhysics(),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // 📶 OFFLINE BANNER
                  if (_isOffline)
                    Container(
                      margin: const EdgeInsets.only(bottom: 20),
                      padding: const EdgeInsets.all(12),
                      width: double.infinity,
                      decoration: BoxDecoration(color: Colors.orange.shade100, borderRadius: BorderRadius.circular(10), border: Border.all(color: Colors.orange)),
                      child: const Row(children: [Icon(Icons.wifi_off, color: Colors.orange), SizedBox(width: 10), Expanded(child: Text("You are offline. Showing saved trips.", style: TextStyle(color: Colors.brown)))])
                    ),

                  // 📊 WELCOME & STATS
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(24),
                    decoration: BoxDecoration(gradient: LinearGradient(colors: [Colors.blue.shade800, Colors.blue.shade500]), borderRadius: BorderRadius.circular(20)),
                    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      const Text("Ready for your next adventure?", style: TextStyle(color: Colors.white, fontSize: 24, fontWeight: FontWeight.bold)),
                      const SizedBox(height: 10),
                      Text("You have ${trips.length} upcoming trips.", style: const TextStyle(color: Colors.white70, fontSize: 16)),
                    ]),
                  ),
                  const SizedBox(height: 30),
                  
                  const Text("Your Trips", style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 15),

                  if (trips.isEmpty) const Center(child: Padding(padding: EdgeInsets.all(40), child: Text("No trips yet. Tap + to start planning!", style: TextStyle(color: Colors.grey, fontSize: 16)))),

                  // 📏 RESPONSIVE GRID
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