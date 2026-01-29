import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:intl/intl.dart';
import 'package:http/http.dart' as http;
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart' as latLng;
import 'package:url_launcher/url_launcher.dart';
import 'package:travel_planner/utils/web_container.dart';
import 'trip_preview.dart';

class TripDetailsPage extends StatefulWidget {
  final Map<String, dynamic> trip;

  const TripDetailsPage({super.key, required this.trip});

  @override
  State<TripDetailsPage> createState() => _TripDetailsPageState();
}

class _TripDetailsPageState extends State<TripDetailsPage> {
  // ✅ YOUR API KEY
  final String _weatherApiKey = '7893495de6bf87dc1c782d309dc77ea5';
  
  final currencyFormat = NumberFormat("#,##0", "en_US");
  
  // Streams are not final so we can refresh them
  late Stream<List<Map<String, dynamic>>> _expensesStream;
  late Stream<List<Map<String, dynamic>>> _packingStream;
  late Stream<List<Map<String, dynamic>>> _membersStream;
  
  Map<String, dynamic>? _weatherData;
  bool _isLoadingWeather = true;

  @override
  void initState() {
    super.initState();
    // 1. Initialize streams DIRECTLY (No setState here!)
    final tripId = widget.trip['id'];
    _expensesStream = _getExpensesStream(tripId);
    _packingStream = _getPackingStream(tripId);
    _membersStream = _getMembersStream(tripId);

    // 2. Fetch weather
    _fetchWeather();
  }

  // --- 🔄 STREAM GETTERS (Reusable) ---
  Stream<List<Map<String, dynamic>>> _getExpensesStream(int tripId) {
    return Supabase.instance.client
        .from('expenses')
        .stream(primaryKey: ['id'])
        .eq('trip_id', tripId)
        .order('created_at');
  }

  Stream<List<Map<String, dynamic>>> _getPackingStream(int tripId) {
    return Supabase.instance.client
        .from('packing_items')
        .stream(primaryKey: ['id'])
        .eq('trip_id', tripId)
        .order('created_at');
  }

  Stream<List<Map<String, dynamic>>> _getMembersStream(int tripId) {
    return Supabase.instance.client
        .from('trip_members')
        .stream(primaryKey: ['id'])
        .eq('trip_id', tripId)
        .order('created_at');
  }

  // --- 🔄 FORCE REFRESH (Only uses setState) ---
  void _refreshAllStreams() {
    final tripId = widget.trip['id'];
    setState(() {
      _expensesStream = _getExpensesStream(tripId);
      _packingStream = _getPackingStream(tripId);
      _membersStream = _getMembersStream(tripId);
    });
  }

  // --- 🌤️ WEATHER FEATURE ---
  Future<void> _fetchWeather() async {
    final lat = widget.trip['latitude'];
    final lng = widget.trip['longitude'];
    
    if (lat == null || lng == null) {
      if (mounted) setState(() => _isLoadingWeather = false);
      return;
    }

    try {
      final url = Uri.parse('https://api.openweathermap.org/data/2.5/weather?lat=$lat&lon=$lng&appid=$_weatherApiKey&units=metric');
      final response = await http.get(url);
      
      if (response.statusCode == 200) {
        if (mounted) {
          setState(() {
            _weatherData = json.decode(response.body);
            _isLoadingWeather = false;
          });
        }
      } else {
        if (mounted) setState(() => _isLoadingWeather = false);
      }
    } catch (e) {
      if (mounted) setState(() => _isLoadingWeather = false);
    }
  }

  // --- 🗺️ OPEN GOOGLE MAPS ---
  Future<void> _openGoogleMaps() async {
    final lat = widget.trip['latitude'];
    final lng = widget.trip['longitude'];
    
    if (lat == null || lng == null) return;

    final googleMapsUrl = Uri.parse('http://googleusercontent.com/maps.google.com/maps?daddr=$lat,$lng');
    if (!await launchUrl(googleMapsUrl, mode: LaunchMode.externalApplication)) {
       await launchUrl(googleMapsUrl);
    }
  }

  // --- 🗑️ HELPER: CONFIRMATION DIALOG ---
  Future<bool?> _showDeleteConfirm(String title) {
    return showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text("Confirm Delete"),
        content: Text("Are you sure you want to delete this $title?"),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text("Cancel")),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red, foregroundColor: Colors.white),
            child: const Text("Delete"),
          ),
        ],
      ),
    );
  }

  // --- 👥 MEMBER FUNCTIONS ---
  Future<void> _addMember() async {
    final nameController = TextEditingController();
    await showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text("Add Trip Member"),
        content: TextField(controller: nameController, decoration: const InputDecoration(labelText: "Name", hintText: "Juan Dela Cruz")),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text("Cancel")),
          ElevatedButton(
            onPressed: () async {
              if (nameController.text.isNotEmpty) {
                await Supabase.instance.client.from('trip_members').insert({
                  'trip_id': widget.trip['id'],
                  'name': nameController.text.trim(),
                });
                if (mounted) {
                  Navigator.pop(context);
                  _refreshAllStreams(); 
                }
              }
            },
            child: const Text("Add"),
          )
        ],
      ),
    );
  }

  Future<void> _toggleMemberPaid(int id, bool currentValue) async {
    await Supabase.instance.client.from('trip_members').update({'is_paid': !currentValue}).eq('id', id);
  }

  Future<void> _deleteMember(int id) async {
    bool? confirm = await _showDeleteConfirm("member");
    if (confirm != true) return;
    await Supabase.instance.client.from('trip_members').delete().eq('id', id);
    if (mounted) _refreshAllStreams();
  }

  // --- 💰 EXPENSE FUNCTIONS ---
  Future<void> _addExpense() async {
    final titleController = TextEditingController();
    final amountController = TextEditingController();

    await showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text("Add Expense"),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(controller: titleController, decoration: const InputDecoration(labelText: "Item (e.g., Hotel)")),
            TextField(controller: amountController, keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: "Cost (₱)")),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text("Cancel")),
          ElevatedButton(
            onPressed: () async {
              final title = titleController.text.trim();
              final amount = double.tryParse(amountController.text.trim());
              if (title.isNotEmpty && amount != null) {
                await Supabase.instance.client.from('expenses').insert({
                  'trip_id': widget.trip['id'],
                  'title': title,
                  'amount': amount,
                });
                if (mounted) {
                  Navigator.pop(context);
                  _refreshAllStreams();
                }
              }
            },
            child: const Text("Add"),
          )
        ],
      ),
    );
  }

  Future<void> _deleteExpense(int id) async {
    bool? confirm = await _showDeleteConfirm("expense");
    if (confirm != true) return;
    await Supabase.instance.client.from('expenses').delete().eq('id', id);
    if (mounted) _refreshAllStreams();
  }

  // --- ✅ PACKING LIST FUNCTIONS ---
  Future<void> _addPackingItem() async {
    final itemController = TextEditingController();
    await showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text("Add Item"),
        content: TextField(controller: itemController, decoration: const InputDecoration(labelText: "Item Name", hintText: "Toothbrush")),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text("Cancel")),
          ElevatedButton(
            onPressed: () async {
              if (itemController.text.isNotEmpty) {
                await Supabase.instance.client.from('packing_items').insert({
                  'trip_id': widget.trip['id'],
                  'item_name': itemController.text.trim(),
                });
                if (mounted) {
                  Navigator.pop(context);
                  _refreshAllStreams();
                }
              }
            },
            child: const Text("Add"),
          )
        ],
      ),
    );
  }

  Future<void> _toggleItem(int id, bool currentValue) async {
    await Supabase.instance.client.from('packing_items').update({'is_checked': !currentValue}).eq('id', id);
  }

  Future<void> _deleteItem(int id) async {
    bool? confirm = await _showDeleteConfirm("item");
    if (confirm != true) return;
    await Supabase.instance.client.from('packing_items').delete().eq('id', id);
    if (mounted) _refreshAllStreams();
  }

  @override
  Widget build(BuildContext context) {
    final bool hasLocation = widget.trip['latitude'] != null && widget.trip['longitude'] != null;

    return Scaffold(
      backgroundColor: Colors.grey[50],
      appBar: AppBar(
        title: Text(widget.trip['destination']),
        actions: [
          if (hasLocation)
            IconButton(icon: const Icon(Icons.directions, color: Colors.blue), onPressed: _openGoogleMaps)
        ],
      ),
      body: WebContainer(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              
              // --- 🗺️ MAP PREVIEW ---
              if (hasLocation) ...[
                GestureDetector(
                  onTap: () {
                    Navigator.push(context, MaterialPageRoute(builder: (context) => TripPreviewPage(tripName: widget.trip['destination'], lat: widget.trip['latitude'], lng: widget.trip['longitude'])));
                  },
                  child: Container(
                    height: 200, 
                    width: double.infinity,
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: Colors.grey.shade300),
                      boxShadow: [BoxShadow(color: Colors.black12, blurRadius: 4, offset: const Offset(0, 2))],
                    ),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(16),
                      child: Stack(
                        children: [
                          FlutterMap(
                            options: MapOptions(
                              initialCenter: latLng.LatLng(widget.trip['latitude'], widget.trip['longitude']),
                              initialZoom: 13.0,
                              interactionOptions: const InteractionOptions(flags: InteractiveFlag.none), 
                            ),
                            children: [
                              TileLayer(urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png'),
                              MarkerLayer(markers: [Marker(point: latLng.LatLng(widget.trip['latitude'], widget.trip['longitude']), width: 40, height: 40, child: const Icon(Icons.location_on, color: Colors.red, size: 40))]),
                            ],
                          ),
                          Positioned(top: 10, right: 10, child: Container(padding: const EdgeInsets.all(6), decoration: BoxDecoration(color: Colors.black54, borderRadius: BorderRadius.circular(8)), child: const Icon(Icons.fullscreen, color: Colors.white))),
                          Positioned(bottom: 10, right: 10, child: ElevatedButton.icon(onPressed: _openGoogleMaps, icon: const Icon(Icons.directions, size: 18), label: const Text("Get Directions"), style: ElevatedButton.styleFrom(backgroundColor: Colors.blue, foregroundColor: Colors.white, padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8)))),
                        ],
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 20),
              ],

              // --- 🌤️ WEATHER ---
              if (hasLocation && !_isLoadingWeather && _weatherData != null)
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(gradient: LinearGradient(colors: [Colors.blue.shade400, Colors.blue.shade200]), borderRadius: BorderRadius.circular(16)),
                  child: Row(
                    children: [
                      Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text("${_weatherData!['main']['temp'].toStringAsFixed(1)}°C", style: const TextStyle(fontSize: 32, fontWeight: FontWeight.bold, color: Colors.white)), Text(_weatherData!['weather'][0]['description'].toUpperCase(), style: const TextStyle(color: Colors.white70, fontWeight: FontWeight.bold))]),
                      const Spacer(),
                      Icon(_weatherData!['weather'][0]['main'].toString().toLowerCase().contains('cloud') ? Icons.cloud : Icons.wb_sunny, size: 48, color: Colors.white),
                    ],
                  ),
                ),
              if (hasLocation) const SizedBox(height: 20),

              // --- 💰 BUDGET TRACKER ---
              const Text("Budget Tracker", style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
              const SizedBox(height: 10),
              StreamBuilder<List<Map<String, dynamic>>>(
                stream: _expensesStream,
                builder: (context, snapshot) {
                  if (!snapshot.hasData) return const LinearProgressIndicator();
                  final expenses = snapshot.data!;
                  double totalSpent = expenses.fold(0, (sum, item) => sum + (item['amount'] as num).toDouble());
                  double budget = (widget.trip['budget'] as num).toDouble();
                  double progress = (budget == 0) ? 0 : (totalSpent / budget);
                  bool isOverBudget = totalSpent > budget;

                  return Card(
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        children: [
                          Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [Text("Spent: ₱${currencyFormat.format(totalSpent)}", style: TextStyle(fontWeight: FontWeight.bold, color: isOverBudget ? Colors.red : Colors.black)), Text("Budget: ₱${currencyFormat.format(budget)}", style: const TextStyle(color: Colors.grey))]),
                          const SizedBox(height: 10),
                          LinearProgressIndicator(value: progress > 1 ? 1 : progress, backgroundColor: Colors.grey[200], color: isOverBudget ? Colors.red : Colors.green, minHeight: 10, borderRadius: BorderRadius.circular(5)),
                          const SizedBox(height: 10),
                          ExpansionTile(
                            title: const Text("View Expense List"),
                            children: [
                              ...expenses.map((e) => ListTile(
                                title: Text(e['title']),
                                trailing: Row(mainAxisSize: MainAxisSize.min, children: [Text("-₱${currencyFormat.format(e['amount'])}", style: const TextStyle(color: Colors.red)), IconButton(icon: const Icon(Icons.delete_outline, size: 20, color: Colors.grey), onPressed: () => _deleteExpense(e['id']))]),
                              )),
                              TextButton.icon(onPressed: _addExpense, icon: const Icon(Icons.add), label: const Text("Add Expense")),
                            ],
                          )
                        ],
                      ),
                    ),
                  );
                },
              ),
              const SizedBox(height: 20),

              // --- 👥 MEMBERS & AMOT ---
              Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [const Text("Members", style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)), IconButton(onPressed: _addMember, icon: const Icon(Icons.person_add, color: Colors.blue))]),
              StreamBuilder<List<Map<String, dynamic>>>(
                stream: _membersStream,
                builder: (context, snapshot) {
                  if (!snapshot.hasData) return const SizedBox();
                  final members = snapshot.data!;
                  
                  // Calculations
                  double budget = (widget.trip['budget'] as num).toDouble();
                  double sharePerPerson = (members.isEmpty) ? 0 : budget / members.length;
                  int paidCount = members.where((m) => m['is_paid'] == true).length;
                  double collectedAmount = sharePerPerson * paidCount;

                  if (members.isEmpty) return const Text("No members yet.", style: TextStyle(color: Colors.grey));

                  return Card(
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    child: Padding(
                      padding: const EdgeInsets.all(8.0),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                           // Header Info
                           Padding(
                             padding: const EdgeInsets.all(10),
                             child: Row(
                               mainAxisAlignment: MainAxisAlignment.spaceBetween,
                               children: [
                                 Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                                   const Text("Share per person", style: TextStyle(color: Colors.grey, fontSize: 12)),
                                   Text("₱${currencyFormat.format(sharePerPerson)}", style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: Colors.blue)),
                                 ]),
                                 Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
                                   const Text("Collected", style: TextStyle(color: Colors.grey, fontSize: 12)),
                                   Text("₱${currencyFormat.format(collectedAmount)}", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: collectedAmount >= budget ? Colors.green : Colors.orange)),
                                 ]),
                               ],
                             ),
                           ),
                           const Divider(),
                           // Member List
                           ...members.map((m) => CheckboxListTile(
                            title: Text(m['name']),
                            subtitle: Text(m['is_paid'] ? "Paid" : "Not Paid", style: TextStyle(color: m['is_paid'] ? Colors.green : Colors.red, fontSize: 12)),
                            value: m['is_paid'],
                            activeColor: Colors.green,
                            onChanged: (val) => _toggleMemberPaid(m['id'], m['is_paid']),
                            secondary: IconButton(icon: const Icon(Icons.delete_outline, color: Colors.grey, size: 20), onPressed: () => _deleteMember(m['id'])),
                          )),
                        ],
                      ),
                    ),
                  );
                },
              ),
              const SizedBox(height: 20),

              // --- ✅ PACKING LIST ---
              Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [const Text("Packing List", style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)), IconButton(onPressed: _addPackingItem, icon: const Icon(Icons.add_circle, color: Colors.blue))]),
              StreamBuilder<List<Map<String, dynamic>>>(
                stream: _packingStream,
                builder: (context, snapshot) {
                  if (!snapshot.hasData) return const SizedBox();
                  final items = snapshot.data!;
                  if (items.isEmpty) return const Text("Nothing to pack yet.", style: TextStyle(color: Colors.grey));

                  return Card(
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    child: Column(
                      children: items.map((item) => CheckboxListTile(
                        title: Text(item['item_name'], style: TextStyle(decoration: item['is_checked'] ? TextDecoration.lineThrough : null, color: item['is_checked'] ? Colors.grey : Colors.black)),
                        value: item['is_checked'],
                        onChanged: (val) => _toggleItem(item['id'], item['is_checked']),
                        secondary: IconButton(icon: const Icon(Icons.delete_outline, color: Colors.grey), onPressed: () => _deleteItem(item['id'])),
                      )).toList(),
                    ),
                  );
                },
              ),
              const SizedBox(height: 50),
            ],
          ),
        ),
      ),
    );
  }
}