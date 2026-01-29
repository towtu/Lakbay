import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:intl/intl.dart';
import 'package:flutter_speed_dial/flutter_speed_dial.dart'; // Import Speed Dial
import 'package:travel_planner/utils/web_container.dart';
import 'login.dart';
import 'add_trip.dart';
import 'calendar_page.dart'; // Import Calendar Page
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
    // Fetch trips where I am the owner OR I have joined via code
    final userId = Supabase.instance.client.auth.currentUser!.id;
    return Supabase.instance.client
          .from('trips')
          .select()
          .or('user_id.eq.$userId,join_code.neq.null')
          .order('start_date', ascending: true); // Order by start date
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
      // Check if already joined/requested
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[100],
      appBar: AppBar(
        title: const Text("Lakbay"),
        actions: [
          IconButton(onPressed: _logout, icon: const Icon(Icons.logout)),
        ],
      ),
      body: WebContainer(
        child: RefreshIndicator(
          onRefresh: () async { _refreshTrips(); },
          child: FutureBuilder<List<Map<String, dynamic>>>(
            future: _tripsFuture,
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) return const Center(child: CircularProgressIndicator());
              if (snapshot.hasError) return Center(child: Text("Error: ${snapshot.error}", style: const TextStyle(color: Colors.red)));
              final trips = snapshot.data ?? [];
              if (trips.isEmpty) return const Center(child: Text("No trips yet. Create one or Join via code!"));

              return ListView.builder(
                padding: const EdgeInsets.all(12),
                itemCount: trips.length,
                itemBuilder: (context, index) {
                  final trip = trips[index];
                  final bool isOwner = trip['user_id'] == Supabase.instance.client.auth.currentUser?.id;
                  final String? startDateStr = trip['start_date'];
                  String subtitle = "Budget: ₱${currencyFormat.format(trip['budget'])}";
                  if (startDateStr != null) {
                    subtitle += "\nStarts: ${DateFormat('MMM dd, yyyy').format(DateTime.parse(startDateStr))}";
                  }

                  return Card(
                    elevation: 4, margin: const EdgeInsets.only(bottom: 15),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
                    child: ListTile(
                      contentPadding: const EdgeInsets.all(16),
                      leading: Container(padding: const EdgeInsets.all(12), decoration: BoxDecoration(color: Colors.blue.withOpacity(0.1), borderRadius: BorderRadius.circular(12)), child: Icon(Icons.location_on, color: Colors.blue.shade700, size: 30)),
                      title: Text(trip['destination'] ?? "Unknown", style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                      subtitle: Text(subtitle),
                      isThreeLine: startDateStr != null,
                      trailing: isOwner 
                          ? IconButton(icon: const Icon(Icons.delete_outline, color: Colors.red), onPressed: () => _deleteTrip(trip['id']))
                          : const Tooltip(message: "Shared Trip", child: Icon(Icons.people, color: Colors.green)), 
                      onTap: () async {
                        await Navigator.push(context, MaterialPageRoute(builder: (context) => TripDetailsPage(trip: trip)));
                        _refreshTrips();
                      },
                    ),
                  );
                },
              );
            },
          ),
        ),
      ),
      // 🔘 NEW EXPANDABLE FAB MENU
      floatingActionButton: SpeedDial(
        icon: Icons.menu,
        activeIcon: Icons.close,
        backgroundColor: Colors.blue,
        foregroundColor: Colors.white,
        activeBackgroundColor: Colors.red,
        activeForegroundColor: Colors.white,
        visible: true,
        closeManually: false,
        curve: Curves.bounceIn,
        overlayColor: Colors.black,
        overlayOpacity: 0.5,
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