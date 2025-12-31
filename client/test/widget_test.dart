import 'package:flutter_test/flutter_test.dart';
import 'package:travel_organizer/main.dart';

void main() {
  testWidgets('App loads trips screen', (WidgetTester tester) async {
    await tester.pumpWidget(const TravelOrganizerApp());
    await tester.pumpAndSettle();

    expect(find.text('My Trips'), findsOneWidget);
  });
}
