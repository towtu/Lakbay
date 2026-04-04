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

class _TripDetailsPageState extends State<TripDetailsPage> with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final currencyFormat = NumberFormat("#,##0", "en_US");
  final dateFormat = DateFormat('MMM dd, yyyy');
  final timeFormat = DateFormat('h:mm a');
  
  late Stream<List<Map<String, dynamic>>> _expensesStream;
  late Stream<List<Map<String, dynamic>>> _packingStream;
  late Stream<List<Map<String, dynamic>>> _membersStream;
  late Stream<List<Map<String, dynamic>>> _notesStream;
  late Stream<List<Map<String, dynamic>>> _itineraryStream;
  late Stream<List<Map<String, dynamic>>> _pollsStream;
  late Stream<List<Map<String, dynamic>>> _joinRequestsStream;

  Map<String, dynamic>? _weatherData;
  bool _isOwner = false;
  bool _canEdit = false;
  String? _joinCode;
  String? _myEmail;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 4, vsync: this);
    _myEmail = Supabase.instance.client.auth.currentUser?.email;
    _checkPermissions();
    _refreshAllStreams();
    _fetchWeather();
    _joinCode = widget.trip['join_code'];
  }

  Future<void> _checkPermissions() async {
    final user = Supabase.instance.client.auth.currentUser;
    if (user == null) return;
    final tripOwnerId = widget.trip['user_id'];
    bool isOwner = user.id == tripOwnerId;
    bool isEditor = false;
    if (!isOwner) {
      final response = await Supabase.instance.client.from('shared_trips').select('permission').eq('trip_id', widget.trip['id']).eq('shared_with_email', user.email!).maybeSingle();
      if (response != null && response['permission'] == 'edit') isEditor = true;
    }
    if (mounted) setState(() { _isOwner = isOwner; _canEdit = isOwner || isEditor; });
  }

  void _refreshAllStreams() {
    final id = widget.trip['id'];
    setState(() {
      _expensesStream = Supabase.instance.client.from('expenses').stream(primaryKey: ['id']).eq('trip_id', id);
      _packingStream = Supabase.instance.client.from('packing_items').stream(primaryKey: ['id']).eq('trip_id', id);
      _membersStream = Supabase.instance.client.from('trip_members').stream(primaryKey: ['id']).eq('trip_id', id);
      _notesStream = Supabase.instance.client.from('trip_notes').stream(primaryKey: ['id']).eq('trip_id', id);
      _itineraryStream = Supabase.instance.client.from('itinerary_items').stream(primaryKey: ['id']).eq('trip_id', id);
      _pollsStream = Supabase.instance.client.from('polls').stream(primaryKey: ['id']).eq('trip_id', id);
      _joinRequestsStream = Supabase.instance.client.from('join_requests').stream(primaryKey: ['id']).eq('trip_id', id);
    });
  }

  Future<void> _fetchWeather() async {
    final lat = widget.trip['latitude']; final lng = widget.trip['longitude'];
    if (lat == null || lng == null) return;
    try {
      final url = Uri.parse('https://api.openweathermap.org/data/2.5/weather?lat=$lat&lon=$lng&appid=7893495de6bf87dc1c782d309dc77ea5&units=metric');
      final res = await http.get(url);
      if (res.statusCode == 200 && mounted) setState(() => _weatherData = json.decode(res.body));
    } catch (_) {}
  }

  Future<void> _openGoogleMaps() async {
    final lat = widget.trip['latitude']; final lng = widget.trip['longitude'];
    if (lat == null || lng == null) return;
    final googleMapsUrl = Uri.parse('https://www.google.com/maps/dir/?api=1&destination=$lat,$lng');
    try {
      if (!await launchUrl(googleMapsUrl, mode: LaunchMode.externalApplication)) await launchUrl(googleMapsUrl);
    } catch (_) { if(mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Could not open maps."))); }
  }

  void _showShareDialog() {
    showDialog(context: context, builder: (c) => AlertDialog(title: const Text("Invite People"), content: Column(mainAxisSize: MainAxisSize.min, children: [const Text("Share this code. Friends can click 'Join Trip' on the home screen."), const SizedBox(height: 20), Container(padding: const EdgeInsets.all(15), decoration: BoxDecoration(color: Colors.blue[50], borderRadius: BorderRadius.circular(10)), child: SelectableText(_joinCode ?? "Generating...", style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold, letterSpacing: 2)))]), actions: [TextButton(onPressed: () => Navigator.pop(c), child: const Text("Close")), ElevatedButton.icon(onPressed: () { Clipboard.setData(ClipboardData(text: _joinCode ?? "")); ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Code copied!"))); }, icon: const Icon(Icons.copy), label: const Text("Copy Code"))]));
  }
  
  Future<void> _deleteWithConfirm(String table, int id, String itemName) async {
    final bool? confirmed = await showDialog<bool>(context: context, builder: (c) => AlertDialog(title: Text("Delete $itemName?"), content: const Text("This action cannot be undone."), actions: [TextButton(onPressed: () => Navigator.pop(c, false), child: const Text("Cancel")), ElevatedButton(style: ElevatedButton.styleFrom(backgroundColor: Colors.red, foregroundColor: Colors.white), onPressed: () => Navigator.pop(c, true), child: const Text("Delete"))]));
    if (confirmed != true) return;
    await Supabase.instance.client.from(table).delete().eq('id', id);
    if (mounted) { _refreshAllStreams(); ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("$itemName deleted."))); }
  }

  // --- 📅 TAB 1: OVERVIEW ---
  Widget _buildOverviewTab() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        if (_weatherData != null) Container(padding: const EdgeInsets.all(16), decoration: BoxDecoration(gradient: LinearGradient(colors: [Colors.blue.shade400, Colors.blue.shade200]), borderRadius: BorderRadius.circular(16)), child: Row(children: [Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text("${_weatherData!['main']['temp'].toStringAsFixed(1)}°C", style: const TextStyle(fontSize: 32, fontWeight: FontWeight.bold, color: Colors.white)), Text(_weatherData!['weather'][0]['description'].toUpperCase(), style: const TextStyle(color: Colors.white70, fontWeight: FontWeight.bold))]), const Spacer(), const Icon(Icons.wb_sunny, size: 48, color: Colors.white)])),
        const SizedBox(height: 20),
        
        if (widget.trip['latitude'] != null) ...[
          GestureDetector(onTap: () => Navigator.push(context, MaterialPageRoute(builder: (c) => TripPreviewPage(tripName: widget.trip['destination'], lat: widget.trip['latitude'], lng: widget.trip['longitude']))), child: Container(height: 200, width: double.infinity, decoration: BoxDecoration(borderRadius: BorderRadius.circular(16), border: Border.all(color: Colors.grey.shade300)), child: ClipRRect(borderRadius: BorderRadius.circular(16), child: Stack(children: [FlutterMap(options: MapOptions(initialCenter: latLng.LatLng(widget.trip['latitude'], widget.trip['longitude']), initialZoom: 13, interactionOptions: const InteractionOptions(flags: InteractiveFlag.none)), children: [TileLayer(urlTemplate: 'https://{s}.basemaps.cartocdn.com/light_all/{z}/{x}/{y}.png', subdomains: const ['a','b','c','d']), MarkerLayer(markers: [Marker(point: latLng.LatLng(widget.trip['latitude'], widget.trip['longitude']), width: 40, height: 40, child: const Icon(Icons.location_on, color: Colors.red, size: 40))])]), Positioned(bottom: 10, right: 10, child: ElevatedButton.icon(onPressed: _openGoogleMaps, icon: const Icon(Icons.directions, size: 18), label: const Text("Directions")))])))),
          const SizedBox(height: 20),
        ],

        Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [const Text("Packing List", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)), if (_canEdit) IconButton(icon: const Icon(Icons.playlist_add, color: Colors.blue), onPressed: _showPackingOptions)]),
        StreamBuilder<List<Map<String, dynamic>>>(stream: _packingStream, builder: (c, s) { final items = s.data ?? []; items.sort((a, b) => (a['created_at'] ?? '').compareTo(b['created_at'] ?? '')); return Column(children: items.map((i) => CheckboxListTile(title: Text(i['item_name'], style: TextStyle(decoration: i['is_checked'] ? TextDecoration.lineThrough : null)), value: i['is_checked'], onChanged: _canEdit ? (v) async { try { await Supabase.instance.client.from('packing_items').update({'is_checked': !i['is_checked']}).eq('id', i['id']); } catch(e) { if(mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Error: $e"))); } } : null, secondary: _canEdit ? IconButton(icon: const Icon(Icons.delete_outline, color: Colors.red), onPressed: () => _deleteWithConfirm('packing_items', i['id'], "Item")) : null)).toList()); }),
        
        const SizedBox(height: 20),
        Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [const Text("Notes", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)), if (_canEdit) IconButton(onPressed: _addNote, icon: const Icon(Icons.note_add, color: Colors.blue))]),
        StreamBuilder<List<Map<String, dynamic>>>(stream: _notesStream, builder: (c, s) { final notes = s.data ?? []; notes.sort((a, b) => (b['created_at'] ?? '').compareTo(a['created_at'] ?? '')); return Column(children: notes.map((n) => Card(child: ListTile(title: Text(n['content']), trailing: _canEdit ? IconButton(icon: const Icon(Icons.delete_outline, color: Colors.red), onPressed: () => _deleteWithConfirm('trip_notes', n['id'], "Note")) : null))).toList()); }),
      ]),
    );
  }

  // --- 🗺️ TAB 2: ITINERARY ---
  Widget _buildItineraryTab() {
    return Scaffold(
      floatingActionButton: _canEdit ? FloatingActionButton.extended(onPressed: _addItineraryItem, label: const Text("Add Event"), icon: const Icon(Icons.add)) : null,
      body: StreamBuilder<List<Map<String, dynamic>>>(
        stream: _itineraryStream,
        builder: (context, snapshot) {
          if (!snapshot.hasData || snapshot.data!.isEmpty) return const Center(child: Text("No events yet. Start planning!", style: TextStyle(color: Colors.grey)));
          final items = snapshot.data!;
          items.sort((a, b) => a['start_time'].compareTo(b['start_time']));
          return ListView.builder(padding: const EdgeInsets.all(16), itemCount: items.length, itemBuilder: (context, index) {
            final item = items[index];
            final date = DateTime.parse(item['start_time']);
            return Padding(padding: const EdgeInsets.only(bottom: 16), child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [Column(children: [Text(DateFormat('MMM').format(date).toUpperCase(), style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.grey)), Text(DateFormat('dd').format(date), style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold))]), const SizedBox(width: 15), Expanded(child: Card(elevation: 2, child: ListTile(title: Text(item['title'], style: const TextStyle(fontWeight: FontWeight.bold)), subtitle: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text("${timeFormat.format(date)} • ${item['location_name'] ?? 'No Location'}"), if (item['description'] != null) Text(item['description'], style: TextStyle(color: Colors.grey[600], fontSize: 12))]), trailing: _canEdit ? IconButton(icon: const Icon(Icons.delete_outline, color: Colors.red), onPressed: () => _deleteWithConfirm('itinerary_items', item['id'], "Event")) : null)))]));
          });
        },
      ),
    );
  }

  // --- 💰 TAB 3: MONEY ---
  Widget _buildMoneyTab() {
    return StreamBuilder<List<Map<String, dynamic>>>(stream: _membersStream, builder: (context, membersSnap) {
      final members = membersSnap.data ?? [];
      return StreamBuilder<List<Map<String, dynamic>>>(stream: _expensesStream, builder: (context, expensesSnap) {
        final expenses = expensesSnap.data ?? [];
        expenses.sort((a, b) => (b['created_at'] ?? '').compareTo(a['created_at'] ?? ''));
        double totalSpent = expenses.fold(0.0, (sum, e) => sum + (e['amount'] as num).toDouble());
        double totalBudget = (widget.trip['budget'] as num).toDouble();
        Map<String, double> paidByUser = {};
        for (var m in members) paidByUser[m['name']] = 0.0;
        for (var e in expenses) { String payer = e['paid_by'] ?? 'Unknown'; paidByUser[payer] = (paidByUser[payer] ?? 0.0) + (e['amount'] as num).toDouble(); }
        double fairShare = totalSpent / (members.isEmpty ? 1 : members.length);

        return ListView(padding: const EdgeInsets.all(16), children: [
          Card(color: Colors.blue.shade50, child: Padding(padding: const EdgeInsets.all(16), child: Column(children: [const Text("Total Budget", style: TextStyle(color: Colors.grey)), Text("₱${currencyFormat.format(totalBudget)}", style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold)), const SizedBox(height: 10), LinearProgressIndicator(value: totalBudget==0?0:(totalSpent/totalBudget).clamp(0,1), backgroundColor: Colors.white, color: totalSpent>totalBudget?Colors.red:Colors.green), const SizedBox(height: 5), Text("Spent: ₱${currencyFormat.format(totalSpent)}", style: TextStyle(color: totalSpent>totalBudget?Colors.red:Colors.black))]))),
          const SizedBox(height: 20), const Text("Fair Share Calculator", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)), const SizedBox(height: 5),
          ...members.map((m) {
            double paid = paidByUser[m['name']] ?? 0.0;
            double balance = paid - fairShare;
            return ListTile(dense: true, title: Text(m['name']), subtitle: Text("Paid: ₱${currencyFormat.format(paid)}"), trailing: Text(balance >= 0 ? "Gets back ₱${currencyFormat.format(balance)}" : "Owes ₱${currencyFormat.format(balance.abs())}", style: TextStyle(fontWeight: FontWeight.bold, color: balance >= 0 ? Colors.green : Colors.red)));
          }),
          const Divider(height: 40), Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [const Text("Expenses History", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)), if (_canEdit) IconButton(onPressed: () => _addExpense(members), icon: const Icon(Icons.add_circle, color: Colors.blue))]),
          ...expenses.map((e) => Card(child: ListTile(title: Text(e['title']), subtitle: Text("Paid by: ${e['paid_by'] ?? 'Unknown'}"), trailing: Row(mainAxisSize: MainAxisSize.min, children: [Text("₱${e['amount']}", style: const TextStyle(fontWeight: FontWeight.bold)), if (_canEdit) IconButton(icon: const Icon(Icons.delete_outline, color: Colors.red), onPressed: () => _deleteWithConfirm('expenses', e['id'], "Expense"))])))),
        ]);
      });
    });
  }

  // --- 🗳️ TAB 4: SOCIAL ---
  Widget _buildSocialTab() {
    return ListView(padding: const EdgeInsets.all(16), children: [
      Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [const Text("Polls", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)), if (_canEdit) IconButton(onPressed: _createPoll, icon: const Icon(Icons.how_to_vote, color: Colors.blue))]),
      StreamBuilder<List<Map<String, dynamic>>>(stream: _pollsStream, builder: (context, snapshot) {
        if (!snapshot.hasData || snapshot.data!.isEmpty) return const Padding(padding: EdgeInsets.all(8), child: Text("No active polls.", style: TextStyle(color: Colors.grey)));
        return Column(children: snapshot.data!.map((poll) => _buildPollCard(poll)).toList());
      }),
      const Divider(height: 40),
      Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [const Text("Members", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)), if (_canEdit) IconButton(onPressed: _addMember, icon: const Icon(Icons.person_add, color: Colors.blue))]),
      StreamBuilder<List<Map<String, dynamic>>>(stream: _membersStream, builder: (context, snapshot) {
        if (!snapshot.hasData) return const SizedBox();
        return Column(children: snapshot.data!.map((m) => _buildMemberTile(m)).toList());
      }),
      if (_canEdit) ...[
        const Divider(height: 40),
        const Text("Pending Join Requests", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
        StreamBuilder<List<Map<String, dynamic>>>(
          stream: _joinRequestsStream,
          builder: (context, snapshot) {
            if (!snapshot.hasData) return const SizedBox();
            final pendingRequests = snapshot.data!.where((req) => req['status'] == 'pending').toList();
            if (pendingRequests.isEmpty) return const Padding(padding: EdgeInsets.all(8), child: Text("No pending requests.", style: TextStyle(color: Colors.grey)));
            return Column(children: pendingRequests.map((req) => _buildJoinRequestTile(req)).toList());
          }
        ),
      ],
    ]);
  }

  Widget _buildMemberTile(Map<String, dynamic> m) {
    String name = m['name'] ?? "Unknown";
    String initial = name.isNotEmpty ? name[0].toUpperCase() : "?";

    if (m['email'] == null) {
      return ListTile(
        leading: CircleAvatar(child: Text(initial)), 
        title: Text(name), 
        subtitle: const Text("Guest (Manual Add)"),
        // 🚀 FIXED: Added Delete for Manual Guests
        trailing: _canEdit 
          ? IconButton(icon: const Icon(Icons.delete_outline, color: Colors.red), onPressed: () => _deleteWithConfirm('trip_members', m['id'], name))
          : null,
      );
    }

    return FutureBuilder(
      future: Supabase.instance.client.from('shared_trips').select('permission').eq('trip_id', widget.trip['id']).eq('shared_with_email', m['email']).maybeSingle(),
      builder: (c, snap) {
        String perm = 'view';
        // 🚀 FIXED: Type Casting for Permission Check (The '[]' Operator Fix)
        if (snap.hasData && snap.data != null) {
          final data = snap.data as Map<String, dynamic>;
          perm = data['permission'] ?? 'view';
        }
        bool isEditor = perm == 'edit';

        return ListTile(
          leading: CircleAvatar(child: Text(initial)),
          title: Text(name),
          subtitle: Text(m['email']),
          trailing: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (_isOwner && m['email'] != null)
                IconButton(
                  icon: Icon(Icons.vpn_key, color: isEditor ? Colors.amber : Colors.grey),
                  tooltip: isEditor ? "Demote to Viewer" : "Promote to Editor",
                  onPressed: () => _toggleEditor(m['email']),
                ),
              // 🚀 FIXED: Delete Member Button
              if (_canEdit)
                IconButton(
                  icon: const Icon(Icons.delete_outline, color: Colors.red),
                  onPressed: () => _deleteWithConfirm('trip_members', m['id'], name),
                ),
            ],
          ),
        );
      }
    );
  }

  Widget _buildPollCard(Map<String, dynamic> poll) {
    return Card(margin: const EdgeInsets.only(bottom: 10), child: Padding(padding: const EdgeInsets.all(12), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [Text(poll['question'], style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)), if (_canEdit) IconButton(icon: const Icon(Icons.delete_outline, color: Colors.red, size: 20), onPressed: () => _deleteWithConfirm('polls', poll['id'], "Poll"))]),
        const SizedBox(height: 10), 
        FutureBuilder(future: Supabase.instance.client.from('poll_options').select().eq('poll_id', poll['id']), builder: (c, snap) { 
          if (!snap.hasData) return const SizedBox(); 
          // 🚀 FIXED: Type Casting
          final options = (snap.data as List).cast<Map<String, dynamic>>();
          return Column(children: options.map<Widget>((opt) => _buildPollOption(opt)).toList()); 
        })])));
  }

  Widget _buildPollOption(Map<String, dynamic> option) {
    return FutureBuilder(future: Supabase.instance.client.from('poll_votes').select().eq('option_id', option['id']), builder: (c, snap) { 
      // 🚀 FIXED: Type Casting
      final votes = (snap.data as List?)?.cast<Map<String, dynamic>>() ?? []; 
      final count = votes.length; 
      final bool iVoted = votes.any((v) => v['user_email'] == _myEmail); 
      return ListTile(visualDensity: VisualDensity.compact, title: Text(option['text']), trailing: Row(mainAxisSize: MainAxisSize.min, children: [Text("$count votes"), const SizedBox(width: 10), Icon(iVoted ? Icons.check_circle : Icons.circle_outlined, color: iVoted ? Colors.green : Colors.grey)]), onTap: () async { if (iVoted) { await Supabase.instance.client.from('poll_votes').delete().eq('option_id', option['id']).eq('user_email', _myEmail!); } else { await Supabase.instance.client.from('poll_votes').insert({'option_id': option['id'], 'user_email': _myEmail!}); } setState(() {}); }); 
    });
  }

  Widget _buildJoinRequestTile(Map<String, dynamic> req) {
    return ListTile(
      title: Text(req['email'] ?? 'Unknown User'),
      subtitle: const Text('Wants to join the trip'),
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          IconButton(
            icon: const Icon(Icons.check_circle, color: Colors.green),
            onPressed: () => _handleJoinRequest(req, true),
          ),
          IconButton(
            icon: const Icon(Icons.cancel, color: Colors.red),
            onPressed: () => _handleJoinRequest(req, false),
          ),
        ],
      )
    );
  }

  Future<void> _handleJoinRequest(Map<String, dynamic> req, bool accept) async {
    try {
      if (accept) {
        // Add to shared_trips
        await Supabase.instance.client.from('shared_trips').insert({
          'trip_id': widget.trip['id'],
          'shared_with_email': req['email'],
          'permission': 'view'
        });
        // Add to trip_members
        String name = req['email'].toString().split('@')[0];
        await Supabase.instance.client.from('trip_members').insert({
          'trip_id': widget.trip['id'],
          'name': name,
          'email': req['email']
        });
        // Update request status
        await Supabase.instance.client.from('join_requests').update({'status': 'approved'}).eq('id', req['id']);
      } else {
        // Reject request
        await Supabase.instance.client.from('join_requests').update({'status': 'rejected'}).eq('id', req['id']);
      }
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(accept ? "Request accepted" : "Request rejected")));
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Error: $e")));
      }
    }
  }

  // --- 📝 ACTIONS ---
  Future<void> _showPackingOptions() async {
    final userId = Supabase.instance.client.auth.currentUser!.id;
    final templates = await Supabase.instance.client.from('packing_templates').select().eq('user_id', userId);
    if(!mounted) return;
    await showModalBottomSheet(context: context, builder: (c) => Container(padding: const EdgeInsets.all(20), child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
      const Text("Add Items", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18)), const SizedBox(height: 10),
      ListTile(leading: const Icon(Icons.add), title: const Text("Add Single Item"), onTap: () { Navigator.pop(c); _addPacking(); }),
      const Divider(), const Text("Import from Template:", style: TextStyle(color: Colors.grey)),
      if (templates.isEmpty) const Padding(padding: EdgeInsets.all(10), child: Text("No templates found. Create one in your Profile!", style: TextStyle(fontStyle: FontStyle.italic))),
      ...templates.map((t) => ListTile(leading: const Icon(Icons.copy, color: Colors.blue), title: Text(t['name']), onTap: () async { Navigator.pop(c); final items = await Supabase.instance.client.from('packing_template_items').select().eq('template_id', t['id']); for(var item in items) { await Supabase.instance.client.from('packing_items').insert({'trip_id': widget.trip['id'], 'item_name': item['item_name']}); } if(mounted) { _refreshAllStreams(); ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Imported ${t['name']}"))); } }))
    ])));
  }
  
  Future<void> _addItineraryItem() async {
    final titleC = TextEditingController(); final locC = TextEditingController();
    TimeOfDay selectedTime = TimeOfDay.now(); DateTime selectedDate = DateTime.parse(widget.trip['start_date'] ?? DateTime.now().toIso8601String());
    String? errTitle;
    
    await showDialog(context: context, builder: (c) => StatefulBuilder(builder: (c, setState) => AlertDialog(
      title: const Text("Add Event"), 
      content: SingleChildScrollView(child: Column(children: [
        TextField(controller: titleC, decoration: InputDecoration(labelText: "Activity Name", errorText: errTitle), onChanged: (_)=>setState(()=>errTitle=null)), 
        TextField(controller: locC, decoration: const InputDecoration(labelText: "Location")), 
        const SizedBox(height: 10), 
        ElevatedButton(onPressed: () async { final d = await showDatePicker(context: context, initialDate: selectedDate, firstDate: DateTime(2000), lastDate: DateTime(2100)); if (d!=null) setState(()=>selectedDate = d); }, child: Text("Date: ${DateFormat('MMM dd').format(selectedDate)}")), 
        ElevatedButton(onPressed: () async { final t = await showTimePicker(context: context, initialTime: selectedTime); if (t!=null) setState(()=>selectedTime = t); }, child: Text("Time: ${selectedTime.format(context)}"))
      ])), 
      actions: [
        TextButton(onPressed:()=>Navigator.pop(c), child:const Text("Cancel")), 
        ElevatedButton(onPressed: () async { 
          if(titleC.text.isEmpty) { setState(()=>errTitle="Required"); return; }
          final dt = DateTime(selectedDate.year, selectedDate.month, selectedDate.day, selectedTime.hour, selectedTime.minute); 
          await Supabase.instance.client.from('itinerary_items').insert({'trip_id': widget.trip['id'], 'title': titleC.text, 'location_name': locC.text, 'start_time': dt.toIso8601String()}); 
          if(mounted) Navigator.pop(c); 
        }, child: const Text("Add"))
      ]
    )));
  }

  Future<void> _addExpense(List<dynamic> members) async { 
    final t=TextEditingController(); final a=TextEditingController();
    
    // 🚀 FIXED: Unique names to prevent dropdown crash
    final uniqueNames = members.map((m) => m['name'] as String).toSet().toList();
    List<String> selectedPayers = [];
    
    String? errItem; String? errCost;
    await showDialog(context: context, builder: (c) => StatefulBuilder(builder: (c, setState) => AlertDialog(
      title: const Text("Add Expense"), 
      content: SingleChildScrollView(child: Column(mainAxisSize: MainAxisSize.min, children:[
        TextField(controller: t, decoration: InputDecoration(labelText: "Item", errorText: errItem), onChanged: (_)=>setState(()=>errItem=null)), 
        TextField(controller: a, keyboardType: TextInputType.number, decoration: InputDecoration(labelText: "Total Cost", errorText: errCost), onChanged: (_)=>setState(()=>errCost=null)), 
        const SizedBox(height: 10),
        const Align(alignment: Alignment.centerLeft, child: Text("Who Paid?", style: TextStyle(fontWeight: FontWeight.bold))),
        Container(height: 150, width: double.maxFinite, child: ListView(shrinkWrap: true, children: uniqueNames.map((name) {
              return CheckboxListTile(title: Text(name), value: selectedPayers.contains(name), dense: true, onChanged: (bool? value) { setState(() { if (value == true) { selectedPayers.add(name); } else { selectedPayers.remove(name); } }); });
            }).toList())),
        if (selectedPayers.isEmpty) const Text("Select at least one payer", style: TextStyle(color: Colors.red, fontSize: 12))
      ])), 
      actions:[
        TextButton(onPressed:()=>Navigator.pop(c), child:const Text("Cancel")), 
        ElevatedButton(onPressed:() async {
          bool valid = true; if(t.text.isEmpty) { setState(()=>errItem="Required"); valid=false; } if(a.text.isEmpty) { setState(()=>errCost="Required"); valid=false; } if(selectedPayers.isEmpty) { setState((){}); valid=false; }
          if(valid) {
            double totalAmount = double.parse(a.text);
            double splitAmount = totalAmount / selectedPayers.length;
            for (String payer in selectedPayers) { await Supabase.instance.client.from('expenses').insert({'trip_id': widget.trip['id'], 'title': selectedPayers.length > 1 ? "${t.text} (Split)" : t.text, 'amount': splitAmount, 'paid_by': payer}); }
            Navigator.pop(c); 
          }
        }, child: const Text("Add"))
      ]
    ))); 
  }

  Future<void> _createPoll() async { final qC = TextEditingController(); final o1C = TextEditingController(); final o2C = TextEditingController(); String? errQ;
    await showDialog(context: context, builder: (c) => StatefulBuilder(builder: (c, setState) => AlertDialog(title: const Text("Create Poll"), content: Column(mainAxisSize: MainAxisSize.min, children: [TextField(controller: qC, decoration: InputDecoration(labelText: "Question", errorText: errQ), onChanged: (_)=>setState(()=>errQ=null)), TextField(controller: o1C, decoration: const InputDecoration(labelText: "Option 1")), TextField(controller: o2C, decoration: const InputDecoration(labelText: "Option 2"))]), actions: [TextButton(onPressed:()=>Navigator.pop(c), child:const Text("Cancel")), ElevatedButton(onPressed: () async {
      if(qC.text.isEmpty) { setState(()=>errQ="Required"); return; }
      final pollRes = await Supabase.instance.client.from('polls').insert({'trip_id': widget.trip['id'], 'question': qC.text}).select(); 
      if (pollRes.isEmpty) return; // Safety
      final pollId = pollRes[0]['id']; 
      await Supabase.instance.client.from('poll_options').insert([{'poll_id': pollId, 'text': o1C.text}, {'poll_id': pollId, 'text': o2C.text}]); Navigator.pop(c); 
    }, child: const Text("Create"))]))); 
  }

  Future<void> _addPacking() async { final t=TextEditingController(); String? err; await showDialog(context: context, builder: (c)=>StatefulBuilder(builder:(c,setState)=>AlertDialog(title: const Text("Add Item"), content: TextField(controller: t, decoration: InputDecoration(errorText: err), onChanged:(_)=>setState(()=>err=null)), actions:[TextButton(onPressed:()=>Navigator.pop(c), child:const Text("Cancel")), ElevatedButton(onPressed:()async{if(t.text.isEmpty){setState(()=>err="Required");return;} await Supabase.instance.client.from('packing_items').insert({'trip_id': widget.trip['id'], 'item_name': t.text});Navigator.pop(c);}, child:const Text("Add"))]))); }
  Future<void> _addNote() async { final t=TextEditingController(); String? err; await showDialog(context: context, builder: (c)=>StatefulBuilder(builder:(c,setState)=>AlertDialog(title: const Text("Add Note"), content: TextField(controller: t, decoration: InputDecoration(errorText: err), onChanged:(_)=>setState(()=>err=null)), actions:[TextButton(onPressed:()=>Navigator.pop(c), child:const Text("Cancel")), ElevatedButton(onPressed:()async{if(t.text.isEmpty){setState(()=>err="Required");return;} await Supabase.instance.client.from('trip_notes').insert({'trip_id': widget.trip['id'], 'content': t.text});Navigator.pop(c);}, child:const Text("Add"))]))); }
  Future<void> _addMember() async { final t=TextEditingController(); String? err; await showDialog(context: context, builder: (c)=>StatefulBuilder(builder:(c,setState)=>AlertDialog(title: const Text("Add Member Name"), content: TextField(controller: t, decoration: InputDecoration(errorText: err), onChanged:(_)=>setState(()=>err=null)), actions:[TextButton(onPressed:()=>Navigator.pop(c), child:const Text("Cancel")), ElevatedButton(onPressed:()async{if(t.text.isEmpty){setState(()=>err="Required");return;} await Supabase.instance.client.from('trip_members').insert({'trip_id': widget.trip['id'], 'name': t.text});Navigator.pop(c);}, child:const Text("Add"))]))); }
  Future<void> _toggleEditor(String email) async { final cur = await Supabase.instance.client.from('shared_trips').select('permission').eq('trip_id', widget.trip['id']).eq('shared_with_email', email).maybeSingle(); final newP = (cur?['permission']=='edit')?'view':'edit'; await Supabase.instance.client.from('shared_trips').update({'permission': newP}).eq('trip_id', widget.trip['id']).eq('shared_with_email', email); if(mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("User is now $newP"))); setState((){}); }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.trip['destination'], style: const TextStyle(color: Colors.white)),
        backgroundColor: Colors.blue,
        iconTheme: const IconThemeData(color: Colors.white),
        actions: [IconButton(icon: const Icon(Icons.share, color: Colors.white), onPressed: _showShareDialog)],
        bottom: TabBar(
          controller: _tabController,
          labelColor: Colors.white,
          unselectedLabelColor: Colors.white70,
          indicatorColor: Colors.white,
          tabs: const [
            Tab(icon: Icon(Icons.dashboard), text: "Plan"),
            Tab(icon: Icon(Icons.timeline), text: "Timeline"),
            Tab(icon: Icon(Icons.attach_money), text: "Money"),
            Tab(icon: Icon(Icons.people), text: "Social"),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          _buildOverviewTab(),
          _buildItineraryTab(),
          _buildMoneyTab(),
          _buildSocialTab(),
        ],
      ),
    );
  }
}