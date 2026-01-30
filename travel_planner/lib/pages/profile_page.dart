import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:travel_planner/utils/web_container.dart';

class ProfilePage extends StatefulWidget {
  const ProfilePage({super.key});

  @override
  State<ProfilePage> createState() => _ProfilePageState();
}

class _ProfilePageState extends State<ProfilePage> {
  final _nameController = TextEditingController();
  final _email = Supabase.instance.client.auth.currentUser?.email ?? "";
  bool _isLoading = false;
  List<Map<String, dynamic>> _myTemplates = [];

  @override
  void initState() {
    super.initState();
    _loadProfile();
    _loadTemplates();
  }

  Future<void> _loadProfile() async {
    final userId = Supabase.instance.client.auth.currentUser!.id;
    final data = await Supabase.instance.client.from('profiles').select('nickname').eq('id', userId).maybeSingle();
    if (data != null && data['nickname'] != null) _nameController.text = data['nickname'];
  }

  Future<void> _loadTemplates() async {
    final userId = Supabase.instance.client.auth.currentUser!.id;
    final data = await Supabase.instance.client.from('packing_templates').select().eq('user_id', userId).order('created_at');
    if (mounted) setState(() => _myTemplates = List<Map<String, dynamic>>.from(data));
  }

  Future<void> _saveProfile() async {
    setState(() => _isLoading = true);
    final userId = Supabase.instance.client.auth.currentUser!.id;
    await Supabase.instance.client.from('profiles').upsert({'id': userId, 'nickname': _nameController.text.trim()});
    if (mounted) { setState(() => _isLoading = false); ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Profile Updated!"))); }
  }

  // --- TEMPLATE LOGIC ---
  Future<void> _createTemplate() async {
    final tController = TextEditingController();
    await showDialog(context: context, builder: (c) => AlertDialog(title: const Text("New Packing List"), content: TextField(controller: tController, decoration: const InputDecoration(labelText: "List Name (e.g., Beach Gear)")), actions: [ElevatedButton(onPressed: () async {
      if(tController.text.isNotEmpty) {
        final user = Supabase.instance.client.auth.currentUser!;
        await Supabase.instance.client.from('packing_templates').insert({'user_id': user.id, 'name': tController.text});
        _loadTemplates();
        if(mounted) Navigator.pop(c);
      }
    }, child: const Text("Create"))]));
  }

  Future<void> _editTemplate(Map<String, dynamic> template) async {
    final tItem = TextEditingController();
    await showDialog(context: context, builder: (c) => StatefulBuilder(builder: (c, setState) => AlertDialog(
      title: Text("Edit ${template['name']}"),
      content: SizedBox(width: double.maxFinite, child: Column(mainAxisSize: MainAxisSize.min, children: [
        Row(children: [Expanded(child: TextField(controller: tItem, decoration: const InputDecoration(labelText: "Add Item"))), IconButton(icon: const Icon(Icons.add_circle, color: Colors.blue), onPressed: () async {
          if(tItem.text.isNotEmpty) {
             await Supabase.instance.client.from('packing_template_items').insert({'template_id': template['id'], 'item_name': tItem.text});
             tItem.clear(); setState((){}); // Refresh dialog
          }
        })]),
        const SizedBox(height: 10),
        const Text("Items:", style: TextStyle(fontWeight: FontWeight.bold)),
        SizedBox(height: 200, child: FutureBuilder(future: Supabase.instance.client.from('packing_template_items').select().eq('template_id', template['id']), builder: (c, snap) {
          if(!snap.hasData) return const Center(child: CircularProgressIndicator());
          final items = snap.data as List;
          return ListView.builder(itemCount: items.length, itemBuilder: (c, i) => ListTile(dense: true, title: Text(items[i]['item_name']), trailing: IconButton(icon: const Icon(Icons.delete, size: 16, color: Colors.red), onPressed: () async { await Supabase.instance.client.from('packing_template_items').delete().eq('id', items[i]['id']); setState((){}); })));
        }))
      ])),
      actions: [TextButton(onPressed: () => Navigator.pop(c), child: const Text("Done"))],
    )));
  }

  Future<void> _deleteTemplate(int id) async {
    await Supabase.instance.client.from('packing_templates').delete().eq('id', id);
    _loadTemplates();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("My Profile")),
      body: WebContainer(child: SingleChildScrollView(padding: const EdgeInsets.all(24.0), child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          const CircleAvatar(radius: 40, child: Icon(Icons.person, size: 40)),
          const SizedBox(height: 10), Center(child: Text(_email, style: const TextStyle(color: Colors.grey))),
          const SizedBox(height: 20),
          TextField(controller: _nameController, decoration: const InputDecoration(labelText: "Nickname", border: OutlineInputBorder(), prefixIcon: Icon(Icons.badge))),
          const SizedBox(height: 10),
          ElevatedButton(onPressed: _isLoading ? null : _saveProfile, child: const Text("Save Nickname")),
          
          const Divider(height: 40),
          Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [const Text("My Packing Templates", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)), IconButton(onPressed: _createTemplate, icon: const Icon(Icons.add_box, color: Colors.blue))]),
          if(_myTemplates.isEmpty) const Text("No templates yet. Create one to use in your trips!", style: TextStyle(color: Colors.grey, fontStyle: FontStyle.italic)),
          ..._myTemplates.map((t) => Card(child: ListTile(title: Text(t['name']), trailing: Row(mainAxisSize: MainAxisSize.min, children: [IconButton(icon: const Icon(Icons.edit, color: Colors.orange), onPressed: () => _editTemplate(t)), IconButton(icon: const Icon(Icons.delete, color: Colors.red), onPressed: () => _deleteTemplate(t['id']))])))),
      ]))),
    );
  }
}