import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:table_calendar/table_calendar.dart';
import 'package:intl/intl.dart';
import 'package:travel_planner/utils/web_container.dart';
import 'trip_details.dart';

class CalendarPage extends StatefulWidget {
  const CalendarPage({super.key});

  @override
  State<CalendarPage> createState() => _CalendarPageState();
}

class _CalendarPageState extends State<CalendarPage> {
  // 🔒 FIXED: Only use Month format
  final CalendarFormat _calendarFormat = CalendarFormat.month; 
  
  DateTime _focusedDay = DateTime.now();
  DateTime? _selectedDay;
  Map<DateTime, List<Map<String, dynamic>>> _tripsByDate = {};
  bool _isLoading = true;
  final _dateFormat = DateFormat('MMM dd');

  @override
  void initState() {
    super.initState();
    _selectedDay = _focusedDay;
    _fetchTrips();
  }

  Future<void> _fetchTrips() async {
    final user = Supabase.instance.client.auth.currentUser;
    if (user == null) return;

    final response = await Supabase.instance.client
        .from('trips')
        .select()
        .or('user_id.eq.${user.id},join_code.neq.null'); 

    final data = response as List<dynamic>;
    Map<DateTime, List<Map<String, dynamic>>> tripsMap = {};

    for (var trip in data) {
      if (trip['start_date'] != null) {
        DateTime startDate = DateTime.parse(trip['start_date']);
        DateTime normalizedDate = DateTime(startDate.year, startDate.month, startDate.day);
        
        if (tripsMap[normalizedDate] == null) {
          tripsMap[normalizedDate] = [];
        }
        tripsMap[normalizedDate]!.add(trip as Map<String, dynamic>);
      }
    }

    setState(() {
      _tripsByDate = tripsMap;
      _isLoading = false;
    });
  }

  List<Map<String, dynamic>> _getTripsForDay(DateTime day) {
    DateTime normalizedDay = DateTime(day.year, day.month, day.day);
    return _tripsByDate[normalizedDay] ?? [];
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("Trip Calendar")),
      body: WebContainer(
        child: _isLoading
            ? const Center(child: CircularProgressIndicator())
            : Column(
                children: [
                  TableCalendar(
                    firstDay: DateTime.utc(2020, 1, 1),
                    lastDay: DateTime.utc(2100, 12, 31),
                    focusedDay: _focusedDay,
                    calendarFormat: _calendarFormat, // 🔒 Forced to Month
                    
                    // 🔒 LOCK THE HEADER:
                    headerStyle: const HeaderStyle(
                      formatButtonVisible: false, // Hides the "2 weeks / Week" button
                      titleCentered: true,
                    ),
                    
                    // 🔒 DISABLE SWITCHOVER:
                    availableCalendarFormats: const {
                      CalendarFormat.month: 'Month',
                    },

                    selectedDayPredicate: (day) => isSameDay(_selectedDay, day),
                    onDaySelected: (selectedDay, focusedDay) {
                      setState(() {
                        _selectedDay = selectedDay;
                        _focusedDay = focusedDay;
                      });
                    },
                    onPageChanged: (focusedDay) => _focusedDay = focusedDay,
                    eventLoader: _getTripsForDay,
                    calendarStyle: const CalendarStyle(
                      markerDecoration: BoxDecoration(color: Colors.blue, shape: BoxShape.circle),
                      todayDecoration: BoxDecoration(color: Colors.orange, shape: BoxShape.circle),
                      selectedDecoration: BoxDecoration(color: Colors.blue, shape: BoxShape.circle),
                    ),
                  ),
                  const SizedBox(height: 8.0),
                  Expanded(
                    child: ValueListenableBuilder<List<Map<String, dynamic>>>(
                      valueListenable: ValueNotifier(_getTripsForDay(_selectedDay!)),
                      builder: (context, trips, _) {
                        if (trips.isEmpty) {
                          return const Center(child: Text("No trips starting on this day."));
                        }
                        return ListView.builder(
                          itemCount: trips.length,
                          itemBuilder: (context, index) {
                            final trip = trips[index];
                            final startDate = DateTime.parse(trip['start_date']);
                            final endDate = DateTime.parse(trip['end_date']);
                            return Card(
                              margin: const EdgeInsets.symmetric(horizontal: 12.0, vertical: 4.0),
                              child: ListTile(
                                leading: const Icon(Icons.flight_takeoff, color: Colors.blue),
                                title: Text(trip['destination'], style: const TextStyle(fontWeight: FontWeight.bold)),
                                subtitle: Text("${_dateFormat.format(startDate)} - ${_dateFormat.format(endDate)}"),
                                onTap: () => Navigator.push(context, MaterialPageRoute(builder: (context) => TripDetailsPage(trip: trip))),
                              ),
                            );
                          },
                        );
                      },
                    ),
                  ),
                ],
              ),
      ),
    );
  }
}