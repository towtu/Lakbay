import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:intl/intl.dart';
import 'package:flutter_speed_dial/flutter_speed_dial.dart';
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

  @override
  void initState() {
    super.initState();
    _tripsFuture = _fetchTrips();
  }

  Future<List<Map<String, dynamic>>> _fetchTrips() {
    final userId = Supabase.instance.client.auth.currentUser!.id;
    return Supabase.instance.client
          .from('trips')
          .select()
          .or('user_id.eq.$userId,join_code.neq.null')
          .order('start_date', ascending: true);
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

  Future<void> _submitJoinRequest(String code) async {
    if (code.isEmpty) return;
    Navigator.pop(context);

    try {
      final tripData = await Supabase.instance.client.from('trips').select('id').eq('join_code', code).maybeSingle();
      
      if (tripData == null) {
        if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Invalid Code. Trip not found.")));
        return;
      }

      final user = Supabase.instance.client.auth.currentUser!;
      final existing = await Supabase.instance.client.from('join_requests').select().eq('trip_id', tripData['id']).eq('user_id', user.id).maybeSingle();
      if (existing != null) {
         if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("You have already sent a request (Status: ${existing['status']}).")));
         return;
      }

      await Supabase.instance.client.from('join_requests').insert({
        'trip_id': tripData['id'],
        'user_id': user.id,
        'email': user.email,
        'status': 'pending'
      });

      if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Request sent! Wait for the owner to approve.")));

    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Error sending request.")));
    }
  }

  Future<void> _deleteTrip(int id) async {
    try {
      await Supabase.instance.client.from('trips').delete().eq('id', id);
      _refreshTrips();
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Only the owner can delete this trip.")));
    }
  }

  // 🎨 CARD DESIGN WIDGET
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
          await Navigator.push(context, MaterialPageRoute(builder: (context) => TripDetailsPage(trip: trip)));
          _refreshTrips();
        },
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header Image Placeholder (Optional: Add real images later!)
            Container(
              height: 100,
              decoration: BoxDecoration(
                color: Colors.blue.shade100,
                borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
              ),
              child: Center(
                child: Icon(Icons.location_city, size: 40, color: Colors.blue.shade300),
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Expanded(
                        child: Text(
                          trip['destination'] ?? "Unknown",
                          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      isOwner 
                          ? IconButton(
                              icon: const Icon(Icons.delete_outline, color: Colors.red, size: 20),
                              onPressed: () => _deleteTrip(trip['id']),
                              tooltip: "Delete Trip",
                              padding: EdgeInsets.zero,
                              constraints: const BoxConstraints(),
                            )
                          : const Tooltip(message: "Shared Trip", child: Icon(Icons.people, color: Colors.green, size: 20)),
                    ],
                  ),
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
      backgroundColor: Colors.grey[50], // Lighter background
      appBar: AppBar(
        title: const Text("Lakbay Dashboard", style: TextStyle(fontWeight: FontWeight.bold)),
        elevation: 0,
        backgroundColor: Colors.white,
        foregroundColor: Colors.black,
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
            if (snapshot.hasError) return Center(child: Text("Error: ${snapshot.error}", style: const TextStyle(color: Colors.red)));
            
            final trips = snapshot.data ?? [];

            return SingleChildScrollView(
              padding: const EdgeInsets.all(20),
              physics: const AlwaysScrollableScrollPhysics(),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // 📊 WELCOME & STATS AREA
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(24),
                    decoration: BoxDecoration(
                      gradient: LinearGradient(colors: [Colors.blue.shade800, Colors.blue.shade500]),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text("Ready for your next adventure?", style: TextStyle(color: Colors.white, fontSize: 24, fontWeight: FontWeight.bold)),
                        const SizedBox(height: 10),
                        Text("You have ${trips.length} upcoming trips planned.", style: const TextStyle(color: Colors.white70, fontSize: 16)),
                      ],
                    ),
                  ),
                  const SizedBox(height: 30),
                  
                  const Text("Your Trips", style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 15),

                  if (trips.isEmpty) 
                    const Center(child: Padding(padding: EdgeInsets.all(40), child: Text("No trips yet. Tap + to start planning!", style: TextStyle(color: Colors.grey, fontSize: 16)))),

                  // 📏 RESPONSIVE GRID LAYOUT
                  LayoutBuilder(
                    builder: (context, constraints) {
                      // Determine columns based on screen width
                      int crossAxisCount = 1; // Default Mobile
                      if (constraints.maxWidth > 1100) {
                        crossAxisCount = 4; // Large Desktop
                      } else if (constraints.maxWidth > 800) {
                        crossAxisCount = 3; // Desktop/Tablet Landscape
                      } else if (constraints.maxWidth > 600) {
                        crossAxisCount = 2; // Tablet Portrait
                      }

                      return GridView.builder(
                        shrinkWrap: true, // Important for SingleChildScrollView
                        physics: const NeverScrollableScrollPhysics(), // Scroll handled by parent
                        gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                          crossAxisCount: crossAxisCount,
                          crossAxisSpacing: 20,
                          mainAxisSpacing: 20,
                          childAspectRatio: 1.3, // Adjust card height ratio
                        ),
                        itemCount: trips.length,
                        itemBuilder: (context, index) {
                          return _buildTripCard(trips[index]);
                        },
                      );
                    },
                  ),
                  const SizedBox(height: 100), // Space for FAB
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
          SpeedDialChild(
            child: const Icon(Icons.add),
            backgroundColor: Colors.blue,
            foregroundColor: Colors.white,
            label: 'Add Trip',
            onTap: () async {
               await Navigator.push(context, MaterialPageRoute(builder: (context) => const AddTripPage()));
               _refreshTrips();
            },
          ),
          SpeedDialChild(
            child: const Icon(Icons.calendar_month),
            backgroundColor: Colors.green,
            foregroundColor: Colors.white,
            label: 'Calendar',
            onTap: () => Navigator.push(context, MaterialPageRoute(builder: (context) => const CalendarPage())),
          ),
          SpeedDialChild(
            child: const Icon(Icons.link),
            backgroundColor: Colors.orange,
            foregroundColor: Colors.white,
            label: 'Join Trip',
            onTap: _joinTripDialog,
          ),
        ],
      ),
    );
  }
}