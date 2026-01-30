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
  
  // Streams
  late Stream<List<Map<String, dynamic>>> _expensesStream;
  late Stream<List<Map<String, dynamic>>> _packingStream;
  late Stream<List<Map<String, dynamic>>> _membersStream;
  late Stream<List<Map<String, dynamic>>> _notesStream;
  late Stream<List<Map<String, dynamic>>> _itineraryStream;
  late Stream<List<Map<String, dynamic>>> _pollsStream;

  // State
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

  // --- 🛠️ SETUP & HELPERS ---
  
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
      _expensesStream = Supabase.instance.client.from('expenses').stream(primaryKey: ['id']).eq('trip_id', id).order('created_at');
      _packingStream = Supabase.instance.client.from('packing_items').stream(primaryKey: ['id']).eq('trip_id', id).order('created_at');
      _membersStream = Supabase.instance.client.from('trip_members_with_permissions').stream(primaryKey: ['id']).eq('trip_id', id).order('name');
      _notesStream = Supabase.instance.client.from('trip_notes').stream(primaryKey: ['id']).eq('trip_id', id).order('created_at');
      _itineraryStream = Supabase.instance.client.from('itinerary_items').stream(primaryKey: ['id']).eq('trip_id', id).order('start_time');
      _pollsStream = Supabase.instance.client.from('polls').stream(primaryKey: ['id']).eq('trip_id', id).order('created_at');
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
  
  Future<void> _genericDelete(String table, int id) async { await Supabase.instance.client.from(table).delete().eq('id', id); }

  // --- 📅 TAB 1: OVERVIEW (Notes, Packing, Map) ---
  
  Widget _buildOverviewTab() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        // Weather
        if (_weatherData != null) Container(padding: const EdgeInsets.all(16), decoration: BoxDecoration(gradient: LinearGradient(colors: [Colors.blue.shade400, Colors.blue.shade200]), borderRadius: BorderRadius.circular(16)), child: Row(children: [Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text("${_weatherData!['main']['temp'].toStringAsFixed(1)}°C", style: const TextStyle(fontSize: 32, fontWeight: FontWeight.bold, color: Colors.white)), Text(_weatherData!['weather'][0]['description'].toUpperCase(), style: const TextStyle(color: Colors.white70, fontWeight: FontWeight.bold))]), const Spacer(), const Icon(Icons.wb_sunny, size: 48, color: Colors.white)])),
        const SizedBox(height: 20),
        
        // Map
        if (widget.trip['latitude'] != null) ...[
          GestureDetector(onTap: () => Navigator.push(context, MaterialPageRoute(builder: (c) => TripPreviewPage(tripName: widget.trip['destination'], lat: widget.trip['latitude'], lng: widget.trip['longitude']))), child: Container(height: 150, width: double.infinity, decoration: BoxDecoration(borderRadius: BorderRadius.circular(16), border: Border.all(color: Colors.grey.shade300)), child: ClipRRect(borderRadius: BorderRadius.circular(16), child: FlutterMap(options: MapOptions(initialCenter: latLng.LatLng(widget.trip['latitude'], widget.trip['longitude']), initialZoom: 13, interactionOptions: const InteractionOptions(flags: InteractiveFlag.none)), children: [TileLayer(urlTemplate: 'https://{s}.basemaps.cartocdn.com/light_all/{z}/{x}/{y}.png', subdomains: const ['a','b','c','d']), MarkerLayer(markers: [Marker(point: latLng.LatLng(widget.trip['latitude'], widget.trip['longitude']), width: 40, height: 40, child: const Icon(Icons.location_on, color: Colors.red, size: 40))])])))),
          const SizedBox(height: 20),
        ],

        // Packing
        Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [const Text("Packing List", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)), if (_canEdit) PopupMenuButton<String>(icon: const Icon(Icons.add_circle, color: Colors.blue), onSelected: _importPackingTemplate, itemBuilder: (c) => [const PopupMenuItem(value: "custom", child: Text("Add Item")), const PopupMenuItem(value: "beach", child: Text("Import: Beach Trip 🏖️")), const PopupMenuItem(value: "hiking", child: Text("Import: Hiking ⛰️"))])]),
        StreamBuilder<List<Map<String, dynamic>>>(stream: _packingStream, builder: (c, s) => Column(children: (s.data ?? []).map((i) => CheckboxListTile(title: Text(i['item_name'], style: TextStyle(decoration: i['is_checked'] ? TextDecoration.lineThrough : null)), value: i['is_checked'], onChanged: _canEdit ? (v) => Supabase.instance.client.from('packing_items').update({'is_checked': !i['is_checked']}).eq('id', i['id']) : null, secondary: _canEdit ? IconButton(icon: const Icon(Icons.close, size: 18), onPressed: () => _genericDelete('packing_items', i['id'])) : null)).toList())),
        
        const SizedBox(height: 20),
        // Notes
        Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [const Text("Notes", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)), if (_canEdit) IconButton(onPressed: _addNote, icon: const Icon(Icons.note_add, color: Colors.blue))]),
        StreamBuilder<List<Map<String, dynamic>>>(stream: _notesStream, builder: (c, s) => Column(children: (s.data ?? []).map((n) => Card(child: ListTile(title: Text(n['content']), trailing: _canEdit ? IconButton(icon: const Icon(Icons.close, size: 18), onPressed: () => _genericDelete('trip_notes', n['id'])) : null))).toList())),
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
          return ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: items.length,
            itemBuilder: (context, index) {
              final item = items[index];
              final date = DateTime.parse(item['start_time']);
              return Padding(
                padding: const EdgeInsets.only(bottom: 16),
                child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Column(children: [Text(DateFormat('MMM').format(date).toUpperCase(), style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.grey)), Text(DateFormat('dd').format(date), style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold))]),
                  const SizedBox(width: 15),
                  Expanded(child: Card(elevation: 2, child: ListTile(
                    title: Text(item['title'], style: const TextStyle(fontWeight: FontWeight.bold)),
                    subtitle: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      Text("${timeFormat.format(date)} • ${item['location_name'] ?? 'No Location'}"),
                      if (item['description'] != null) Text(item['description'], style: TextStyle(color: Colors.grey[600], fontSize: 12))
                    ]),
                    trailing: _canEdit ? IconButton(icon: const Icon(Icons.delete_outline, color: Colors.red), onPressed: () => _genericDelete('itinerary_items', item['id'])) : null,
                  )))
                ]),
              );
            },
          );
        },
      ),
    );
  }

  // --- 💰 TAB 3: MONEY (Expenses + Split) ---

  Widget _buildMoneyTab() {
    return StreamBuilder<List<Map<String, dynamic>>>(
      stream: _membersStream,
      builder: (context, membersSnap) {
        final members = membersSnap.data ?? [];
        return StreamBuilder<List<Map<String, dynamic>>>(
          stream: _expensesStream,
          builder: (context, expensesSnap) {
            final expenses = expensesSnap.data ?? [];
            
            // MATH LOGIC
            double totalSpent = expenses.fold(0.0, (sum, e) => sum + (e['amount'] as num).toDouble());
            double totalBudget = (widget.trip['budget'] as num).toDouble();
            
            // Who paid what?
            Map<String, double> paidByUser = {};
            for (var m in members) paidByUser[m['name']] = 0.0;
            
            for (var e in expenses) {
              String payer = e['paid_by'] ?? 'Unknown';
              paidByUser[payer] = (paidByUser[payer] ?? 0.0) + (e['amount'] as num).toDouble();
            }

            // Who owes who? (Split Evenly)
            double fairShare = totalSpent / (members.isEmpty ? 1 : members.length);

            return ListView(
              padding: const EdgeInsets.all(16),
              children: [
                // Budget Card
                Card(color: Colors.blue.shade50, child: Padding(padding: const EdgeInsets.all(16), child: Column(children: [
                   const Text("Total Budget", style: TextStyle(color: Colors.grey)),
                   Text("₱${currencyFormat.format(totalBudget)}", style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold)),
                   const SizedBox(height: 10),
                   LinearProgressIndicator(value: totalBudget==0?0:(totalSpent/totalBudget).clamp(0,1), backgroundColor: Colors.white, color: totalSpent>totalBudget?Colors.red:Colors.green),
                   const SizedBox(height: 5),
                   Text("Spent: ₱${currencyFormat.format(totalSpent)}", style: TextStyle(color: totalSpent>totalBudget?Colors.red:Colors.black)),
                ]))),

                const SizedBox(height: 20),
                const Text("Fair Share Calculator", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                const SizedBox(height: 5),
                // Debt List
                ...members.map((m) {
                  double paid = paidByUser[m['name']] ?? 0.0;
                  double balance = paid - fairShare; // + means people owe me. - means I owe.
                  return ListTile(
                    dense: true,
                    title: Text(m['name']),
                    subtitle: Text("Paid: ₱${currencyFormat.format(paid)}"),
                    trailing: Text(
                      balance >= 0 ? "Gets back ₱${currencyFormat.format(balance)}" : "Owes ₱${currencyFormat.format(balance.abs())}",
                      style: TextStyle(fontWeight: FontWeight.bold, color: balance >= 0 ? Colors.green : Colors.red),
                    ),
                  );
                }),

                const Divider(height: 40),
                Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [const Text("Expenses History", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)), if (_canEdit) IconButton(onPressed: () => _addExpense(members), icon: const Icon(Icons.add_circle, color: Colors.blue))]),
                ...expenses.map((e) => Card(child: ListTile(
                  title: Text(e['title']),
                  subtitle: Text("Paid by: ${e['paid_by'] ?? 'Unknown'}"),
                  trailing: Row(mainAxisSize: MainAxisSize.min, children: [
                    Text("₱${e['amount']}", style: const TextStyle(fontWeight: FontWeight.bold)),
                    if (_canEdit) IconButton(icon: const Icon(Icons.close, size: 16), onPressed: () => _genericDelete('expenses', e['id']))
                  ]),
                ))),
              ],
            );
          },
        );
      },
    );
  }

  // --- 🗳️ TAB 4: SOCIAL (Polls & Members) ---

  Widget _buildSocialTab() {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        // Polls Section
        Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [const Text("Polls", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)), if (_canEdit) IconButton(onPressed: _createPoll, icon: const Icon(Icons.how_to_vote, color: Colors.blue))]),
        StreamBuilder<List<Map<String, dynamic>>>(
          stream: _pollsStream,
          builder: (context, snapshot) {
            if (!snapshot.hasData || snapshot.data!.isEmpty) return const Padding(padding: EdgeInsets.all(8), child: Text("No active polls.", style: TextStyle(color: Colors.grey)));
            return Column(children: snapshot.data!.map((poll) => _buildPollCard(poll)).toList());
          },
        ),
        
        const Divider(height: 40),
        // Members Section
        Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [const Text("Members", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)), if (_canEdit) IconButton(onPressed: _addMember, icon: const Icon(Icons.person_add, color: Colors.blue))]),
        StreamBuilder<List<Map<String, dynamic>>>(
          stream: _membersStream,
          builder: (context, snapshot) {
            if (!snapshot.hasData) return const SizedBox();
            return Column(children: snapshot.data!.map((m) {
              final bool isEditor = (m['permission'] ?? 'view') == 'edit';
              return ListTile(
                leading: CircleAvatar(child: Text(m['name'][0])),
                title: Text(m['name']),
                subtitle: Text(m['email'] ?? "No email"),
                trailing: _isOwner && m['email'] != null 
                  ? IconButton(icon: Icon(Icons.vpn_key, color: isEditor ? Colors.amber : Colors.grey), onPressed: () => _toggleEditor(m['email']))
                  : null,
              );
            }).toList());
          },
        ),
      ],
    );
  }

  // --- 🧩 WIDGET HELPERS ---

  Widget _buildPollCard(Map<String, dynamic> poll) {
    return Card(
      margin: const EdgeInsets.only(bottom: 10),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(poll['question'], style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
            const SizedBox(height: 10),
            // Fetch Options
            FutureBuilder(
              future: Supabase.instance.client.from('poll_options').select().eq('poll_id', poll['id']),
              builder: (c, snap) {
                if (!snap.hasData) return const SizedBox();
                final options = List<Map<String, dynamic>>.from(snap.data as List);
                return Column(children: options.map((opt) => _buildPollOption(opt)).toList());
              }
            )
          ],
        ),
      ),
    );
  }

  Widget _buildPollOption(Map<String, dynamic> option) {
    return FutureBuilder(
      future: Supabase.instance.client.from('poll_votes').select().eq('option_id', option['id']),
      builder: (c, snap) {
        final votes = snap.data as List? ?? [];
        final count = votes.length;
        final bool iVoted = votes.any((v) => v['user_email'] == _myEmail);

        return ListTile(
          visualDensity: VisualDensity.compact,
          title: Text(option['text']),
          trailing: Row(mainAxisSize: MainAxisSize.min, children: [Text("$count votes"), const SizedBox(width: 10), Icon(iVoted ? Icons.check_circle : Icons.circle_outlined, color: iVoted ? Colors.green : Colors.grey)]),
          onTap: () async {
            if (iVoted) {
              await Supabase.instance.client.from('poll_votes').delete().eq('option_id', option['id']).eq('user_email', _myEmail!);
            } else {
              await Supabase.instance.client.from('poll_votes').insert({'option_id': option['id'], 'user_email': _myEmail!});
            }
            setState(() {}); // Refresh UI
          },
        );
      }
    );
  }

  // --- 📝 ACTIONS (Add/Import/Create) ---

  Future<void> _importPackingTemplate(String type) async {
    if (type == "custom") { _addPacking(); return; }
    List<String> items = [];
    if (type == "beach") items = ["Sunblock", "Swimsuit", "Towel", "Sunglasses", "Hat", "Slippers"];
    if (type == "hiking") items = ["Hiking Boots", "Water Bottle", "Trail Mix", "Raincoat", "First Aid Kit"];
    
    for (String item in items) {
      await Supabase.instance.client.from('packing_items').insert({'trip_id': widget.trip['id'], 'item_name': item});
    }
  }

  Future<void> _addItineraryItem() async {
    final titleC = TextEditingController();
    final locC = TextEditingController();
    TimeOfDay selectedTime = TimeOfDay.now();
    DateTime selectedDate = DateTime.parse(widget.trip['start_date'] ?? DateTime.now().toIso8601String());

    await showDialog(context: context, builder: (c) => AlertDialog(
      title: const Text("Add Event"),
      content: SingleChildScrollView(child: Column(children: [
        TextField(controller: titleC, decoration: const InputDecoration(labelText: "Activity Name")),
        TextField(controller: locC, decoration: const InputDecoration(labelText: "Location")),
        const SizedBox(height: 10),
        ElevatedButton(onPressed: () async {
           final d = await showDatePicker(context: context, initialDate: selectedDate, firstDate: DateTime(2000), lastDate: DateTime(2100));
           if (d!=null) selectedDate = d;
        }, child: const Text("Select Date")),
        ElevatedButton(onPressed: () async {
           final t = await showTimePicker(context: context, initialTime: selectedTime);
           if (t!=null) selectedTime = t;
        }, child: const Text("Select Time")),
      ])),
      actions: [
        ElevatedButton(onPressed: () async {
          final dt = DateTime(selectedDate.year, selectedDate.month, selectedDate.day, selectedTime.hour, selectedTime.minute);
          await Supabase.instance.client.from('itinerary_items').insert({
            'trip_id': widget.trip['id'],
            'title': titleC.text,
            'location_name': locC.text,
            'start_time': dt.toIso8601String()
          });
          if(mounted) Navigator.pop(c);
        }, child: const Text("Add"))
      ],
    ));
  }

  Future<void> _addExpense(List<dynamic> members) async { 
    final t=TextEditingController(); final a=TextEditingController(); 
    String selectedPayer = members.first['name'];
    
    await showDialog(context: context, builder: (c) => StatefulBuilder(builder: (c, setDialog) => AlertDialog(
      title: const Text("Add Expense"), 
      content: Column(mainAxisSize: MainAxisSize.min, children:[
        TextField(controller: t, decoration: const InputDecoration(labelText: "Item")), 
        TextField(controller: a, keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: "Cost")),
        const SizedBox(height: 10),
        DropdownButton<String>(
          value: selectedPayer,
          isExpanded: true,
          items: members.map<DropdownMenuItem<String>>((m) => DropdownMenuItem(value: m['name'], child: Text("Paid by: ${m['name']}"))).toList(),
          onChanged: (v) => setDialog(() => selectedPayer = v!)
        )
      ]), 
      actions:[ElevatedButton(onPressed:() async {
        if(t.text.isNotEmpty) {
          await Supabase.instance.client.from('expenses').insert({
            'trip_id': widget.trip['id'], 
            'title': t.text, 
            'amount': double.parse(a.text),
            'paid_by': selectedPayer // Save who paid
          }); 
          Navigator.pop(c);
        }
      }, child: const Text("Add"))]
    ))); 
  }

  Future<void> _createPoll() async {
    final qC = TextEditingController();
    final o1C = TextEditingController();
    final o2C = TextEditingController();
    await showDialog(context: context, builder: (c) => AlertDialog(
      title: const Text("Create Poll"),
      content: Column(mainAxisSize: MainAxisSize.min, children: [
        TextField(controller: qC, decoration: const InputDecoration(labelText: "Question")),
        TextField(controller: o1C, decoration: const InputDecoration(labelText: "Option 1")),
        TextField(controller: o2C, decoration: const InputDecoration(labelText: "Option 2")),
      ]),
      actions: [ElevatedButton(onPressed: () async {
        final pollRes = await Supabase.instance.client.from('polls').insert({'trip_id': widget.trip['id'], 'question': qC.text}).select();
        final pollId = pollRes[0]['id'];
        await Supabase.instance.client.from('poll_options').insert([
          {'poll_id': pollId, 'text': o1C.text},
          {'poll_id': pollId, 'text': o2C.text},
        ]);
        Navigator.pop(c);
      }, child: const Text("Create"))],
    ));
  }

  // (Simple adds)
  Future<void> _addPacking() async { final t=TextEditingController(); await showDialog(context: context, builder: (c)=>AlertDialog(title: const Text("Add Item"), content: TextField(controller: t), actions:[ElevatedButton(onPressed:()async{await Supabase.instance.client.from('packing_items').insert({'trip_id': widget.trip['id'], 'item_name': t.text});Navigator.pop(c);}, child:const Text("Add"))])); }
  Future<void> _addNote() async { final t=TextEditingController(); await showDialog(context: context, builder: (c)=>AlertDialog(title: const Text("Add Note"), content: TextField(controller: t), actions:[ElevatedButton(onPressed:()async{await Supabase.instance.client.from('trip_notes').insert({'trip_id': widget.trip['id'], 'content': t.text});Navigator.pop(c);}, child:const Text("Add"))])); }
  Future<void> _addMember() async { final t=TextEditingController(); await showDialog(context: context, builder: (c)=>AlertDialog(title: const Text("Add Member Name"), content: TextField(controller: t), actions:[ElevatedButton(onPressed:()async{await Supabase.instance.client.from('trip_members').insert({'trip_id': widget.trip['id'], 'name': t.text});Navigator.pop(c);}, child:const Text("Add"))])); }
  Future<void> _toggleEditor(String email) async {
    final cur = await Supabase.instance.client.from('shared_trips').select('permission').eq('trip_id', widget.trip['id']).eq('shared_with_email', email).maybeSingle();
    final newP = (cur?['permission']=='edit')?'view':'edit';
    await Supabase.instance.client.from('shared_trips').update({'permission': newP}).eq('trip_id', widget.trip['id']).eq('shared_with_email', email);
    if(mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("User is now $newP")));
  }

  // --- 🏗️ BUILD ---
  
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.trip['destination']),
        bottom: TabBar(
          controller: _tabController,
          tabs: const [
            Tab(icon: Icon(Icons.dashboard), text: "Plan"),
            Tab(icon: Icon(Icons.timeline), text: "Timeline"),
            Tab(icon: Icon(Icons.attach_money), text: "Money"),
            Tab(icon: Icon(Icons.people), text: "Social"),
          ],
        ),
        actions: [IconButton(icon: const Icon(Icons.share), onPressed: () {
             showDialog(context: context, builder: (c) => AlertDialog(content: SelectableText(widget.trip['join_code'] ?? "No Code")));
        })]
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