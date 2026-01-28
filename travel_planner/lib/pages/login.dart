import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'home.dart';

class LoginPage extends StatefulWidget {
  const LoginPage({super.key});

  @override
  State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {
  // Controllers to get text from input fields
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  bool _isLoading = false;

  // Sign Up Function
  Future<void> _signUp() async {
    try {
      setState(() => _isLoading = true);
      // This sends data to Supabase Auth
      await Supabase.instance.client.auth.signUp(
        email: _emailController.text.trim(),
        password: _passwordController.text.trim(),
      );
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Account Created! Please Log In.")),
        );
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Error: $e")),
      );
    } finally {
      setState(() => _isLoading = false);
    }
  }

  // Login Function
  Future<void> _signIn() async {
    try {
      setState(() => _isLoading = true);
      await Supabase.instance.client.auth.signInWithPassword(
        email: _emailController.text.trim(),
        password: _passwordController.text.trim(),
      );
      
      // If successful, go to Home Page
      if (mounted) {
        Navigator.pushReplacement(
          context, 
          MaterialPageRoute(builder: (context) => const HomePage()),
        );
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Login Failed: $e")),
      );
    } finally {
      setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: Padding(
        padding: const EdgeInsets.all(20.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Text("LAKBAY LOGIN", style: TextStyle(color: Colors.yellowAccent, fontSize: 30, fontWeight: FontWeight.bold)),
            const SizedBox(height: 40),
            
            // Email Input
            TextField(
              controller: _emailController,
              style: const TextStyle(color: Colors.white),
              decoration: InputDecoration(
                labelText: "Email",
                labelStyle: const TextStyle(color: Colors.grey),
                enabledBorder: OutlineInputBorder(borderSide: BorderSide(color: Colors.grey[800]!)),
                focusedBorder: const OutlineInputBorder(borderSide: BorderSide(color: Colors.yellowAccent)),
              ),
            ),
            const SizedBox(height: 20),
            
            // Password Input
            TextField(
              controller: _passwordController,
              obscureText: true, // Hide password
              style: const TextStyle(color: Colors.white),
              decoration: InputDecoration(
                labelText: "Password",
                labelStyle: const TextStyle(color: Colors.grey),
                enabledBorder: OutlineInputBorder(borderSide: BorderSide(color: Colors.grey[800]!)),
                focusedBorder: const OutlineInputBorder(borderSide: BorderSide(color: Colors.yellowAccent)),
              ),
            ),
            const SizedBox(height: 30),

            _isLoading 
            ? const CircularProgressIndicator(color: Colors.yellowAccent)
            : Column(
                children: [
                  ElevatedButton(
                    onPressed: _signIn,
                    style: ElevatedButton.styleFrom(backgroundColor: Colors.yellowAccent, foregroundColor: Colors.black),
                    child: const Text("LOGIN"),
                  ),
                  TextButton(
                    onPressed: _signUp,
                    child: const Text("Create Account", style: TextStyle(color: Colors.grey)),
                  )
                ],
              )
          ],
        ),
      ),
    );
  }
}