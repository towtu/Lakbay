import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'login.dart';

class HomePage extends StatelessWidget {
  const HomePage({super.key});

  Future<void> _logout(BuildContext context) async {
    await Supabase.instance.client.auth.signOut();
    if (context.mounted) {
      Navigator.pushReplacement(
        context, 
        MaterialPageRoute(builder: (context) => const LoginPage()),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("LAKBAY: TAGOLOAN"),
        actions: [
          IconButton(
            icon: const Icon(Icons.logout),
            onPressed: () => _logout(context),
            tooltip: 'Logout',
          )
        ],
      ),
      body: Padding(
        padding: const EdgeInsets.all(20.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              "Where to next?",
              style: TextStyle(fontSize: 28, fontWeight: FontWeight.bold, color: Colors.white),
            ),
            const SizedBox(height: 5),
            Text("Plan your dream adventure.", style: TextStyle(fontSize: 16, color: Colors.grey[400])),
            const SizedBox(height: 30),

            Expanded(
              child: GridView.count(
                crossAxisCount: 2, 
                crossAxisSpacing: 15,
                mainAxisSpacing: 15,
                children: [
                  _buildMenuCard(icon: Icons.map_outlined, title: "Itinerary"),
                  _buildMenuCard(icon: Icons.checklist_rtl, title: "Packing List"),
                  _buildMenuCard(icon: Icons.attach_money, title: "Budget"),
                  _buildMenuCard(icon: Icons.settings_outlined, title: "Settings"),
                ],
              ),
            ),
          ],
        ),
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () {},
        backgroundColor: Colors.yellowAccent, 
        foregroundColor: Colors.black, 
        child: const Icon(Icons.add),
      ),
    );
  }

  Widget _buildMenuCard({required IconData icon, required String title}) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.grey[900], 
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.yellowAccent.withOpacity(0.2)), 
      ),
      child: InkWell(
        onTap: () => print("$title Clicked"),
        borderRadius: BorderRadius.circular(20),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, size: 40, color: Colors.yellowAccent), 
            const SizedBox(height: 15),
            Text(title, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.white)),
          ],
        ),
      ),
    );
  }
}