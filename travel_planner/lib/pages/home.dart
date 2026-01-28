import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'login.dart';
import 'add_trip.dart'; // Make sure you have this file created!

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  
  // LOGOUT FUNCTION
  Future<void> _logout() async {
    await Supabase.instance.client.auth.signOut();
    if (mounted) {
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (context) => const LoginPage()),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white, // White background
      
      // 1. APP BAR (Blue)
      appBar: AppBar(
        title: const Text("My Itinerary"),
        backgroundColor: Colors.blue,
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            onPressed: _logout,
            icon: const Icon(Icons.logout),
            tooltip: "Logout",
          )
        ],
      ),

      // 2. BODY (The content)
      body: const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.flight_takeoff, size: 80, color: Colors.blueAccent),
            SizedBox(height: 20),
            Text(
              "No trips yet!",
              style: TextStyle(fontSize: 20, color: Colors.grey),
            ),
            Text(
              "Tap the + button to plan your next adventure.",
              style: TextStyle(color: Colors.grey),
            ),
          ],
        ),
      ),

      // 3. FLOATING BUTTON (Blue +)
      floatingActionButton: FloatingActionButton(
        onPressed: () {
          // Navigate to the "Add Trip" page
          Navigator.push(
            context,
            MaterialPageRoute(builder: (context) => const AddTripPage()),
          );
        },
        backgroundColor: Colors.blue,
        child: const Icon(Icons.add, color: Colors.white),
      ),
    );
  }
}