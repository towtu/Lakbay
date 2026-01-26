import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

// Import your main file
import 'package:travel_planner/main.dart';

void main() {
  testWidgets('App loads correctly smoke test', (WidgetTester tester) async {
    // 1. Load the new TravelPlannerApp (instead of MyApp)
    await tester.pumpWidget(const TravelPlannerApp());

    // 2. check if our title "LAKBAY: TAGOLOAN" exists on screen
    expect(find.text('LAKBAY: TAGOLOAN'), findsOneWidget);

    // 3. Verify that the "Itinerary" button exists
    expect(find.text('Itinerary'), findsOneWidget);
  });
}