import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
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
  final String _weatherApiKey = '7893495de6bf87dc1c782d309dc77ea5';
  final currencyFormat = NumberFormat("#,##0", "en_US");
  final dateFormat = DateFormat('MMM dd, yyyy');
  
  late Stream<List<Map<String, dynamic>>> _expensesStream;
  late Stream<List<Map<String, dynamic>>> _packingStream;
  late Stream<List<Map<String, dynamic>>> _membersStream;
  late Stream<List<Map<String, dynamic>>> _notesStream;
  late Stream<List<Map<String, dynamic>>> _requestsStream;

  Map<String, dynamic>? _weatherData;
  bool _isLoadingWeather = true;
  
  bool _isOwner = false;
  bool _canEdit = false;
  String? _joinCode;

  @override
  void initState() {
    super.initState();
    _checkPermissions();
    _refreshAllStreams();
    _fetchWeather();
    _joinCode = widget.trip['join_code']; 
  }

  Future<void> _checkPermissions() async {
    final currentUser = Supabase.instance.client.auth.currentUser;
    if (currentUser == null) return;
    
    final tripOwnerId = widget.trip['user_id'];
    bool isOwner = currentUser.id == tripOwnerId;

    bool isEditor = false;
    if (!isOwner) {
      final response = await Supabase.instance.client
          .from('shared_trips')
          .select('permission')
          .eq('trip_id', widget.trip['id'])
          .eq('shared_with_email', currentUser.email!)
          .maybeSingle();
      
      if (response != null && response['permission'] == 'edit') {
        isEditor = true;
      }
    }

    setState(() {
      _isOwner = isOwner;
      _canEdit = isOwner || isEditor;
    });
  }

  Stream<List<Map<String, dynamic>>> _getExpensesStream(int tripId) => Supabase.instance.client.from('expenses').stream(primaryKey: ['id']).eq('trip_id', tripId).order('created_at');
  Stream<List<Map<String, dynamic>>> _getPackingStream(int tripId) => Supabase.instance.client.from('packing_items').stream(primaryKey: ['id']).eq('trip_id', tripId).order('created_at');
  Stream<List<Map<String, dynamic>>> _getMembersStream(int tripId) => Supabase.instance.client.from('trip_members').stream(primaryKey: ['id']).eq('trip_id', tripId).order('created_at');
  Stream<List<Map<String, dynamic>>> _getNotesStream(int tripId) => Supabase.instance.client.from('trip_notes').stream(primaryKey: ['id']).eq('trip_id', tripId).order('created_at');
  Stream<List<Map<String, dynamic>>> _getRequestsStream(int tripId) => Supabase.instance.client.from('join_requests').stream(primaryKey: ['id']).eq('trip_id', tripId).order('created_at');

  void _refreshAllStreams() {
    final tripId = widget.trip['id'];
    setState(() {
      _expensesStream = _getExpensesStream(tripId);
      _packingStream = _getPackingStream(tripId);
      _membersStream = _getMembersStream(tripId);
      _notesStream = _getNotesStream(tripId);
      _requestsStream = _getRequestsStream(tripId);
    });
  }

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
      if (response.statusCode == 200 && mounted) {
        setState(() {
          _weatherData = json.decode(response.body);
          _isLoadingWeather = false;
        });
      }
    } catch (e) { if (mounted) setState(() => _isLoadingWeather = false); }
  }

  Future<void> _openGoogleMaps() async {
    final lat = widget.trip['latitude'];
    final lng = widget.trip['longitude'];
    if (lat == null || lng == null) return;
    final googleMapsUrl = Uri.parse('https://www.google.com/maps/dir/?api=1&destination=$lat,$lng');
    try {
      if (!await launchUrl(googleMapsUrl, mode: LaunchMode.externalApplication)) await launchUrl(googleMapsUrl);
    } catch (_) { if(mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Could not open maps."))); }
  }

  void _showShareDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text("Invite People"),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text("Share this code. Friends can click 'Join Trip' on the home screen."),
            const SizedBox(height: 20),
            Container(padding: const EdgeInsets.all(15), decoration: BoxDecoration(color: Colors.blue[50], borderRadius: BorderRadius.circular(10)), child: SelectableText(_joinCode ?? "Generating...", style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold, letterSpacing: 2))),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text("Close")),
          ElevatedButton.icon(onPressed: () { Clipboard.setData(ClipboardData(text: _joinCode ?? "")); ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Code copied!"))); }, icon: const Icon(Icons.copy), label: const Text("Copy Code")),
        ],
      ),
    );
  }

  Future<void> _toggleEditorPermission(String email) async {
    final current = await Supabase.instance.client.from('shared_trips').select('permission').eq('trip_id', widget.trip['id']).eq('shared_with_email', email).maybeSingle();
    if (current == null) return;
    final newPerm = (current['permission'] == 'edit') ? 'view' : 'edit';
    await Supabase.instance.client.from('shared_trips').update({'permission': newPerm}).eq('trip_id', widget.trip['id']).eq('shared_with_email', email);
    if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("User is now ${newPerm == 'edit' ? 'an EDITOR' : 'VIEW ONLY'}")));
  }

  Future<void> _handleRequest(Map<String, dynamic> request, bool approve) async {
    await Supabase.instance.client.from('join_requests').update({'status': approve ? 'approved' : 'rejected'}).eq('id', request['id']);
    if (approve) {
      await Supabase.instance.client.from('shared_trips').insert({'trip_id': widget.trip['id'], 'shared_with_email': request['email'], 'permission': 'view'}); 
      await Supabase.instance.client.from('trip_members').insert({'trip_id': widget.trip['id'], 'name': request['email'].split('@')[0], 'email': request['email'], 'is_paid': false});
    }
    if (mounted) { ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(approve ? "User approved!" : "User rejected."))); _refreshAllStreams(); }
  }

  // 🗑️ DELETED: _showDeleteConfirm is gone!

  // Now deletes immediately
  Future<void> _deleteGeneric(String table, int id) async { 
    await Supabase.instance.client.from(table).delete().eq('id', id); 
    if (mounted) _refreshAllStreams(); 
  }
  
  Future<void> _addItemGeneric(String table, Map<String, dynamic> data) async { await Supabase.instance.client.from(table).insert(data); if (mounted) _refreshAllStreams(); }

  Future<void> _addExpense() async { final t=TextEditingController(); final a=TextEditingController(); await showDialog(context: context, builder: (context) => AlertDialog(title: const Text("Add Expense"), content: Column(mainAxisSize: MainAxisSize.min, children:[TextField(controller: t, decoration: const InputDecoration(labelText: "Item")), TextField(controller: a, keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: "Cost"))]), actions:[TextButton(onPressed:()=>Navigator.pop(context), child:const Text("Cancel")), ElevatedButton(onPressed:() async {if(t.text.isNotEmpty && a.text.isNotEmpty) {await _addItemGeneric('expenses', {'trip_id': widget.trip['id'], 'title': t.text, 'amount': double.parse(a.text)}); Navigator.pop(context);}}, child: const Text("Add"))])); }
  Future<void> _addPacking() async { final t=TextEditingController(); await showDialog(context: context, builder: (context) => AlertDialog(title: const Text("Add Item"), content: TextField(controller: t, decoration: const InputDecoration(labelText: "Name")), actions:[TextButton(onPressed:()=>Navigator.pop(context), child:const Text("Cancel")), ElevatedButton(onPressed:() async {if(t.text.isNotEmpty) {await _addItemGeneric('packing_items', {'trip_id': widget.trip['id'], 'item_name': t.text}); Navigator.pop(context);}}, child: const Text("Add"))])); }
  Future<void> _addMember() async { final t=TextEditingController(); await showDialog(context: context, builder: (context) => AlertDialog(title: const Text("Add Member"), content: TextField(controller: t, decoration: const InputDecoration(labelText: "Name")), actions:[TextButton(onPressed:()=>Navigator.pop(context), child:const Text("Cancel")), ElevatedButton(onPressed:() async {if(t.text.isNotEmpty) {await _addItemGeneric('trip_members', {'trip_id': widget.trip['id'], 'name': t.text}); Navigator.pop(context);}}, child: const Text("Add"))])); }
  Future<void> _addNote() async { final t=TextEditingController(); await showDialog(context: context, builder: (context) => AlertDialog(title: const Text("Add Note"), content: TextField(controller: t, maxLines: 3, decoration: const InputDecoration(labelText: "Content")), actions:[TextButton(onPressed:()=>Navigator.pop(context), child:const Text("Cancel")), ElevatedButton(onPressed:() async {if(t.text.isNotEmpty) {await _addItemGeneric('trip_notes', {'trip_id': widget.trip['id'], 'content': t.text}); Navigator.pop(context);}}, child: const Text("Save"))])); }

  @override
  Widget build(BuildContext context) {
    final bool hasLocation = widget.trip['latitude'] != null && widget.trip['longitude'] != null;
    final String? startDateStr = widget.trip['start_date'];
    final String? endDateStr = widget.trip['end_date'];
    String dateRange = "";
    if (startDateStr != null && endDateStr != null) {
      dateRange = "${dateFormat.format(DateTime.parse(startDateStr))} - ${dateFormat.format(DateTime.parse(endDateStr))}";
    }

    return Scaffold(
      backgroundColor: Colors.grey[50],
      appBar: AppBar(
        title: Text(widget.trip['destination'], style: const TextStyle(color: Colors.white)),
        backgroundColor: Colors.blue, 
        iconTheme: const IconThemeData(color: Colors.white),
        actions: [
          IconButton(icon: const Icon(Icons.share, color: Colors.white), onPressed: _showShareDialog, tooltip: "Share Trip Code"),
          if (hasLocation) IconButton(icon: const Icon(Icons.directions, color: Colors.white), onPressed: _openGoogleMaps, tooltip: "Get Directions")
        ],
      ),
      body: WebContainer(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (dateRange.isNotEmpty)
                Padding(padding: const EdgeInsets.only(bottom: 16.0), child: Row(children: [const Icon(Icons.calendar_today, color: Colors.grey, size: 20), const SizedBox(width: 8), Text(dateRange, style: const TextStyle(fontSize: 16, color: Colors.black87))])),
              
              if (_isOwner) 
                StreamBuilder<List<Map<String, dynamic>>>(
                  stream: _requestsStream,
                  builder: (context, snapshot) {
                    final requests = snapshot.data?.where((r) => r['status'] == 'pending').toList() ?? [];
                    if (requests.isEmpty) return const SizedBox();
                    return Container(
                      margin: const EdgeInsets.only(bottom: 20),
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(color: Colors.orange[50], borderRadius: BorderRadius.circular(12), border: Border.all(color: Colors.orange)),
                      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                        const Text("🔔 Join Requests", style: TextStyle(fontWeight: FontWeight.bold, color: Colors.orange)),
                        ...requests.map((r) => ListTile(title: Text(r['email']), trailing: Row(mainAxisSize: MainAxisSize.min, children: [IconButton(icon: const Icon(Icons.check, color: Colors.green), onPressed: () => _handleRequest(r, true)), IconButton(icon: const Icon(Icons.close, color: Colors.red), onPressed: () => _handleRequest(r, false))]))),
                      ]),
                    );
                  },
                ),

              if (hasLocation) ...[
                GestureDetector(
                  onTap: () => Navigator.push(context, MaterialPageRoute(builder: (context) => TripPreviewPage(tripName: widget.trip['destination'], lat: widget.trip['latitude'], lng: widget.trip['longitude']))),
                  child: Container(height: 200, width: double.infinity, decoration: BoxDecoration(borderRadius: BorderRadius.circular(16), border: Border.all(color: Colors.grey.shade300)), child: ClipRRect(borderRadius: BorderRadius.circular(16), child: Stack(children: [FlutterMap(options: MapOptions(initialCenter: latLng.LatLng(widget.trip['latitude'], widget.trip['longitude']), initialZoom: 13.0, interactionOptions: const InteractionOptions(flags: InteractiveFlag.none)), children: [TileLayer(urlTemplate: 'https://{s}.basemaps.cartocdn.com/light_all/{z}/{x}/{y}.png', subdomains: const ['a', 'b', 'c', 'd']), MarkerLayer(markers: [Marker(point: latLng.LatLng(widget.trip['latitude'], widget.trip['longitude']), width: 40, height: 40, child: const Icon(Icons.location_on, color: Colors.red, size: 40))])]), Positioned(bottom: 10, right: 10, child: ElevatedButton.icon(onPressed: _openGoogleMaps, icon: const Icon(Icons.directions, size: 18), label: const Text("Directions")))]))),
                ),
                const SizedBox(height: 20),
              ],
              
              if (hasLocation && !_isLoadingWeather && _weatherData != null)
                Container(padding: const EdgeInsets.all(16), decoration: BoxDecoration(gradient: LinearGradient(colors: [Colors.blue.shade400, Colors.blue.shade200]), borderRadius: BorderRadius.circular(16)), child: Row(children: [Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text("${_weatherData!['main']['temp'].toStringAsFixed(1)}°C", style: const TextStyle(fontSize: 32, fontWeight: FontWeight.bold, color: Colors.white)), Text(_weatherData!['weather'][0]['description'].toUpperCase(), style: const TextStyle(color: Colors.white70, fontWeight: FontWeight.bold))]), const Spacer(), Icon(Icons.wb_sunny, size: 48, color: Colors.white)])),
              if (hasLocation) const SizedBox(height: 20),

              // 📝 NOTES (Direct Delete)
              Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [const Text("Travel Notes", style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)), if (_canEdit) IconButton(onPressed: _addNote, icon: const Icon(Icons.note_add, color: Colors.blue))]),
              StreamBuilder<List<Map<String, dynamic>>>(
                stream: _notesStream,
                builder: (context, snapshot) {
                  if (!snapshot.hasData || snapshot.data!.isEmpty) return const Text("No notes yet.", style: TextStyle(color: Colors.grey));
                  return Column(children: snapshot.data!.map((note) => Card(margin: const EdgeInsets.only(bottom: 8), child: ListTile(title: Text(note['content']), trailing: _canEdit ? IconButton(icon: const Icon(Icons.delete_outline, size: 20, color: Colors.grey), onPressed: () => _deleteGeneric('trip_notes', note['id'])) : null))).toList());
                },
              ),
              const SizedBox(height: 20),

              // 💰 BUDGET (Direct Delete)
              const Text("Budget", style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
              StreamBuilder<List<Map<String, dynamic>>>(
                stream: _expensesStream,
                builder: (context, snapshot) {
                  if (!snapshot.hasData) return const LinearProgressIndicator();
                  final expenses = snapshot.data!;
                  double total = expenses.fold(0, (sum, item) => sum + (item['amount'] as num).toDouble());
                  double budget = (widget.trip['budget'] as num).toDouble();
                  return Card(child: Padding(padding: const EdgeInsets.all(16), child: Column(children: [Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [Text("₱${currencyFormat.format(total)}", style: TextStyle(fontWeight: FontWeight.bold, color: total > budget ? Colors.red : Colors.black)), Text(" / ₱${currencyFormat.format(budget)}", style: const TextStyle(color: Colors.grey))]), const SizedBox(height: 10), LinearProgressIndicator(value: budget == 0 ? 0 : (total/budget).clamp(0, 1), color: total > budget ? Colors.red : Colors.green, backgroundColor: Colors.grey[200]), ExpansionTile(title: const Text("Details"), children: [...expenses.map((e) => ListTile(title: Text(e['title']), trailing: Row(mainAxisSize: MainAxisSize.min, children: [Text("₱${e['amount']}"), if (_canEdit) IconButton(icon: const Icon(Icons.close, size: 16), onPressed: () => _deleteGeneric('expenses', e['id']))]))), if (_canEdit) TextButton(onPressed: _addExpense, child: const Text("Add Expense"))])])));
                },
              ),
              const SizedBox(height: 20),

              // 👥 MEMBERS (Direct Delete)
              Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [const Text("Members", style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)), if (_canEdit) IconButton(onPressed: _addMember, icon: const Icon(Icons.person_add, color: Colors.blue))]),
              StreamBuilder<List<Map<String, dynamic>>>(
                stream: _membersStream,
                builder: (context, snapshot) {
                  if (!snapshot.hasData || snapshot.data!.isEmpty) return const Text("No members.", style: TextStyle(color: Colors.grey));
                  return Card(child: Column(children: snapshot.data!.map((m) {
                    final bool hasEmail = m['email'] != null;
                    return CheckboxListTile(
                      title: Text(m['name']),
                      subtitle: Text(m['is_paid'] ? "Paid" : "Not Paid", style: TextStyle(color: m['is_paid'] ? Colors.green : Colors.red)),
                      value: m['is_paid'],
                      onChanged: _canEdit ? (val) async { await Supabase.instance.client.from('trip_members').update({'is_paid': !m['is_paid']}).eq('id', m['id']); } : null,
                      secondary: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          if (_isOwner && hasEmail) 
                             IconButton(
                               icon: const Icon(Icons.vpn_key, color: Colors.orange, size: 20),
                               tooltip: "Toggle Edit Permission",
                               onPressed: () => _toggleEditorPermission(m['email']),
                             ),
                          if (_canEdit) 
                            IconButton(icon: const Icon(Icons.delete_outline, color: Colors.grey), onPressed: () => _deleteGeneric('trip_members', m['id'])),
                        ],
                      ),
                    );
                  }).toList()));
                },
              ),
              const SizedBox(height: 20),

              // 🎒 PACKING (Direct Delete)
              Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [const Text("Packing", style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)), if (_canEdit) IconButton(onPressed: _addPacking, icon: const Icon(Icons.add_circle, color: Colors.blue))]),
              StreamBuilder<List<Map<String, dynamic>>>(
                stream: _packingStream,
                builder: (context, snapshot) {
                  if (!snapshot.hasData || snapshot.data!.isEmpty) return const Text("Empty list.", style: TextStyle(color: Colors.grey));
                  return Card(child: Column(children: snapshot.data!.map((item) => CheckboxListTile(title: Text(item['item_name'], style: TextStyle(decoration: item['is_checked'] ? TextDecoration.lineThrough : null, color: Colors.black)), value: item['is_checked'], onChanged: _canEdit ? (val) async { await Supabase.instance.client.from('packing_items').update({'is_checked': !item['is_checked']}).eq('id', item['id']); } : null, secondary: _canEdit ? IconButton(icon: const Icon(Icons.delete_outline), onPressed: () => _deleteGeneric('packing_items', item['id'])) : null)).toList()));
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