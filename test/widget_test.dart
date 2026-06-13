import 'package:flutter_test/flutter_test.dart';

import 'package:team_track/main.dart';

void main() {
  testWidgets('renders TeamTrack dashboard shell', (WidgetTester tester) async {
    await tester.pumpWidget(const TeamTrackApp());

    expect(find.text('TeamTrack'), findsOneWidget);
    expect(find.text('Proyecto listo para conectar con Supabase.'), findsOneWidget);
  });
}