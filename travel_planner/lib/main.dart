import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'pages/login.dart'; // Imports the Login Page
import 'pages/home.dart';  // Imports the Home Page

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // 🔴 STOP! PASTE YOUR SUPABASE KEYS HERE BEFORE RUNNING 🔴
  await Supabase.initialize(
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
      
      // THEME: Black & Yellow (Cyberpunk Style)
      theme: ThemeData(
        brightness: Brightness.dark, 
        scaffoldBackgroundColor: Colors.black, 
        primaryColor: Colors.yellowAccent,
        
        colorScheme: const ColorScheme.dark(
          primary: Colors.yellowAccent,
          secondary: Colors.yellow,
          surface: Colors.black, // Cards will be black/dark grey
        ),

        // Input Field Style
        inputDecorationTheme: InputDecorationTheme(
          filled: true,
          fillColor: Colors.grey[900],
          enabledBorder: OutlineInputBorder(
            borderSide: BorderSide(color: Colors.grey.shade800),
            borderRadius: BorderRadius.circular(10),
          ),
          focusedBorder: OutlineInputBorder(
            borderSide: const BorderSide(color: Colors.yellowAccent),
            borderRadius: BorderRadius.circular(10),
          ),
          labelStyle: const TextStyle(color: Colors.grey),
          prefixIconColor: Colors.yellowAccent,
        ),

        // App Bar Style
        appBarTheme: const AppBarTheme(
          backgroundColor: Colors.black,
          elevation: 0,
          centerTitle: true,
          iconTheme: IconThemeData(color: Colors.yellowAccent),
          titleTextStyle: TextStyle(
            color: Colors.yellowAccent, 
            fontSize: 24, 
            fontWeight: FontWeight.bold,
            letterSpacing: 1.5,
          ),
        ),
        
        useMaterial3: true,
      ),
      
      // LOGIC: Check if user is already logged in
      home: Supabase.instance.client.auth.currentUser == null
          ? const LoginPage()
          : const HomePage(),
    );
  }
}