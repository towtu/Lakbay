import 'package:flutter/material.dart';

class HomePage extends StatelessWidget {
  const HomePage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("LAKBAY: TAGOLOAN"),
        centerTitle: true,
      ),
      body: Padding(
        padding: const EdgeInsets.all(20.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // 1. Welcome Text
            const Text(
              "Where to next?",
              style: TextStyle(
                fontSize: 28, 
                fontWeight: FontWeight.bold,
                color: Colors.white, 
              ),
            ),
            const SizedBox(height: 5),
            Text(
              "Plan your dream adventure.",
              style: TextStyle(fontSize: 16, color: Colors.grey[400]),
            ),
            
            const SizedBox(height: 30),

            // 2. The Menu Grid
            Expanded(
              child: GridView.count(
                crossAxisCount: 2, 
                crossAxisSpacing: 15,
                mainAxisSpacing: 15,
                children: [
                  _buildMenuCard(
                    icon: Icons.map_outlined,
                    title: "Itinerary",
                    onTap: () {
                      print("Itinerary Clicked");
                    },
                  ),
                  _buildMenuCard(
                    icon: Icons.checklist_rtl,
                    title: "Packing List",
                    onTap: () {
                       print("Packing Clicked");
                    },
                  ),
                  _buildMenuCard(
                    icon: Icons.attach_money,
                    title: "Budget",
                    onTap: () {
                       print("Budget Clicked");
                    },
                  ),
                  _buildMenuCard(
                    icon: Icons.settings_outlined,
                    title: "Settings",
                    onTap: () {
                       print("Settings Clicked");
                    },
                  ),
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

  // Helper Widget for the Cards
  Widget _buildMenuCard({
    required IconData icon, 
    required String title, 
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        decoration: BoxDecoration(
          color: Colors.grey[900], 
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: Colors.yellowAccent.withOpacity(0.2)), 
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, size: 40, color: Colors.yellowAccent), 
            const SizedBox(height: 15),
            Text(
              title,
              style: const TextStyle(
                fontSize: 16, 
                fontWeight: FontWeight.bold,
                color: Colors.white, 
              ),
            ),
          ],
        ),
      ),
    );
  }
}