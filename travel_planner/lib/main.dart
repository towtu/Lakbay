import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'pages/login.dart';
import 'pages/home.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await Supabase.initialize(
    // KEEPS YOUR EXISTING KEYS - NO NEED TO CHANGE THEM
    url: 'https://vkbncqegskrnqrqwjkpv.supabase.co', 
    anonKey: 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6InZrYm5jcWVnc2tybnFycXdqa3B2Iiwicm9sZSI6ImFub24iLCJpYXQiOjE3Njk1OTQyMTQsImV4cCI6MjA4NTE3MDIxNH0.7AlX6LVv3Bnmvnr_W_NNsgLrVzpk0SooJbKfVmR4tLM', 
  );

  runApp(const TravelPlannerApp());
}

class TravelPlannerApp extends StatelessWidget {
  const TravelPlannerApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'Lakbay',
      
      // NEW THEME: Blue & White (Clean Style)
      theme: ThemeData(
        brightness: Brightness.light, // <--- Light mode now
        scaffoldBackgroundColor: Colors.white, // <--- White background
        primaryColor: Colors.blue,
        
        colorScheme: ColorScheme.light(
          primary: Colors.blue,
          secondary: Colors.blueAccent,
          surface: Colors.white,
          onSurface: Colors.black, // Text is black
        ),

        // Input Field Style
        inputDecorationTheme: InputDecorationTheme(
          filled: true,
          fillColor: Colors.grey[50], // Very light grey box
          enabledBorder: OutlineInputBorder(
            borderSide: BorderSide(color: Colors.blue.shade100),
            borderRadius: BorderRadius.circular(10),
          ),
          focusedBorder: OutlineInputBorder(
            borderSide: const BorderSide(color: Colors.blue, width: 2),
            borderRadius: BorderRadius.circular(10),
          ),
          labelStyle: const TextStyle(color: Colors.blueGrey),
          prefixIconColor: Colors.blue,
        ),

        // App Bar Style
        appBarTheme: const AppBarTheme(
          backgroundColor: Colors.blue, // Blue header
          foregroundColor: Colors.white, // White text
          elevation: 0,
          centerTitle: true,
          titleTextStyle: TextStyle(
            color: Colors.white, 
            fontSize: 24, 
            fontWeight: FontWeight.bold,
            letterSpacing: 1.0,
          ),
        ),
        
        useMaterial3: true,
      ),
      
      home: Supabase.instance.client.auth.currentUser == null
          ? const LoginPage()
          : const HomePage(),
    );
  }
}