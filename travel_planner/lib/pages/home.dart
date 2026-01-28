import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:intl/intl.dart';
import '../utils/web_container.dart'; // <--- UPDATED PATH
import 'login.dart';
import 'add_trip.dart';
import 'map_page.dart';
import 'trip_preview.dart';

class HomePage extends StatefulWidget {
  const HomePage({super.key});
  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  final _tripsStream = Supabase.instance.client.from('trips').stream(primaryKey: ['id']).order('id', ascending: false);
  final currencyFormat = NumberFormat("#,##0", "en_US");

  Future<void> _deleteTrip(int id) async {
    bool? confirm = await showModalBottomSheet<bool>(
      context: context,
      builder: (context) => Container(
        padding: const EdgeInsets.all(20), height: 180,
        child: Column(children: [
          const Text("Delete this trip?", style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
          const Spacer(),
          Row(children: [
            Expanded(child: OutlinedButton(onPressed: () => Navigator.pop(context, false), child: const Text("Cancel"))),
            const SizedBox(width: 10),
            Expanded(child: ElevatedButton(onPressed: () => Navigator.pop(context, true), style: ElevatedButton.styleFrom(backgroundColor: Colors.red, foregroundColor: Colors.white), child: const Text("Delete"))),
          ])
        ]),
      ),
    );
    if (confirm == true) await Supabase.instance.client.from('trips').delete().eq('id', id);
  }

  Future<void> _logout() async {
    await Supabase.instance.client.auth.signOut();
    if (mounted) Navigator.pushReplacement(context, MaterialPageRoute(builder: (context) => const LoginPage()));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[100],
      appBar: AppBar(
        title: const Text("My Itinerary"),
        actions: [
          IconButton(onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (context) => const MapPage())), icon: const Icon(Icons.map)),
          IconButton(onPressed: _logout, icon: const Icon(Icons.logout)),
        ],
      ),
      body: WebContainer(
        child: StreamBuilder<List<Map<String, dynamic>>>(
          stream: _tripsStream,
          builder: (context, snapshot) {
            if (!snapshot.hasData) return const Center(child: CircularProgressIndicator());
            final trips = snapshot.data!;
            if (trips.isEmpty) return const Center(child: Text("No trips yet! Click + to add one."));

            return ListView.builder(
              padding: const EdgeInsets.all(12),
              itemCount: trips.length,
              itemBuilder: (context, index) {
                final trip = trips[index];
                return Card(
                  elevation: 4, margin: const EdgeInsets.only(bottom: 15),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
                  child: ListTile(
                    contentPadding: const EdgeInsets.all(16),
                    leading: Container(padding: const EdgeInsets.all(12), decoration: BoxDecoration(color: Colors.blue.withOpacity(0.1), borderRadius: BorderRadius.circular(12)), child: Icon(Icons.location_on, color: Colors.blue.shade700, size: 30)),
                    title: Text(trip['destination'] ?? "Unknown", style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                    subtitle: Text("Budget: ₱${currencyFormat.format(trip['budget'])}"),
                    trailing: IconButton(icon: const Icon(Icons.delete_outline, color: Colors.red), onPressed: () => _deleteTrip(trip['id'])),
                    onTap: () {
                      if (trip['latitude'] != null) {
                        Navigator.push(context, MaterialPageRoute(builder: (context) => TripPreviewPage(tripName: trip['destination'], lat: trip['latitude'], lng: trip['longitude'])));
                      }
                    },
                  ),
                );
              },
            );
          },
        ),
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (context) => const AddTripPage())),
        backgroundColor: Colors.blue,
        child: const Icon(Icons.add, color: Colors.white),
      ),
    );
  }
}