import 'package:flutter/material.dart';
import 'pages/home.dart'; // Make sure you have the 'pages' folder created

void main() {
  runApp(const TravelPlannerApp());
}

class TravelPlannerApp extends StatelessWidget {
  const TravelPlannerApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'Travel Planner',
      // Black and Yellow Theme
      theme: ThemeData(
        brightness: Brightness.dark, 
        scaffoldBackgroundColor: Colors.black, 
        primaryColor: Colors.yellowAccent,
        
        colorScheme: const ColorScheme.dark(
          primary: Colors.yellowAccent,
          secondary: Colors.yellow,
        ),
        
        appBarTheme: const AppBarTheme(
          backgroundColor: Colors.black,
          elevation: 0,
          iconTheme: IconThemeData(color: Colors.yellowAccent),
          titleTextStyle: TextStyle(
            color: Colors.yellowAccent, 
            fontSize: 20, 
            fontWeight: FontWeight.bold
          ),
        ),
        
        useMaterial3: true,
      ),
      home: const HomePage(),
    );
  }
}