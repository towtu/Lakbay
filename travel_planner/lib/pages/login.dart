import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'home.dart'; 

class LoginPage extends StatefulWidget {
  const LoginPage({super.key});

  @override
  State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  bool _isLoading = false;

  // SIGN UP
  Future<void> _signUp() async {
    try {
      setState(() => _isLoading = true);
      await Supabase.instance.client.auth.signUp(
        email: _emailController.text.trim(),
        password: _passwordController.text.trim(),
      );
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Account Created! You can now Log In.")),
        );
      }
    } on AuthException catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.message)));
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Error occurred")));
    } finally {
      setState(() => _isLoading = false);
    }
  }

  // LOG IN
  Future<void> _signIn() async {
    try {
      setState(() => _isLoading = true);
      await Supabase.instance.client.auth.signInWithPassword(
        email: _emailController.text.trim(),
        password: _passwordController.text.trim(),
      );
      if (mounted) {
        Navigator.pushReplacement(
          context, 
          MaterialPageRoute(builder: (context) => const HomePage()),
        );
      }
    } on AuthException catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.message)));
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Error occurred")));
    } finally {
      setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.flight_takeoff, size: 80, color: Colors.yellowAccent),
              const SizedBox(height: 20),
              const Text("LAKBAY", style: TextStyle(color: Colors.yellowAccent, fontSize: 40, fontWeight: FontWeight.bold)),
              const Text("PLAN YOUR ADVENTURE", style: TextStyle(color: Colors.grey, letterSpacing: 2)),
              const SizedBox(height: 50),
              
              TextField(
                controller: _emailController,
                style: const TextStyle(color: Colors.white),
                decoration: const InputDecoration(labelText: "Email", prefixIcon: Icon(Icons.email_outlined)),
              ),
              const SizedBox(height: 20),
              
              TextField(
                controller: _passwordController,
                obscureText: true,
                style: const TextStyle(color: Colors.white),
                decoration: const InputDecoration(labelText: "Password", prefixIcon: Icon(Icons.lock_outline)),
              ),
              const SizedBox(height: 30),

              _isLoading 
              ? const CircularProgressIndicator(color: Colors.yellowAccent)
              : Column(
                  children: [
                    SizedBox(
                      width: double.infinity,
                      height: 50,
                      child: ElevatedButton(
                        onPressed: _signIn,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.yellowAccent, 
                          foregroundColor: Colors.black,
                        ),
                        child: const Text("LOGIN", style: TextStyle(fontWeight: FontWeight.bold)),
                      ),
                    ),
                    const SizedBox(height: 15),
                    TextButton(
                      onPressed: _signUp,
                      child: const Text("No account? Create one", style: TextStyle(color: Colors.grey)),
                    )
                  ],
                )
            ],
          ),
        ),
      ),
    );
  }
}