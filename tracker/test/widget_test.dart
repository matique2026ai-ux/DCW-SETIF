import 'package:flutter_test/flutter_test.dart';
import 'package:drh_setif_tracker/main.dart';

void main() {
  testWidgets('App loads successfully', (WidgetTester tester) async {
    await tester.pumpWidget(const DRHTrackerApp());

    await tester.pumpAndSettle();

    expect(find.text('DCW-SETIF-TRACKER'), findsOneWidget);
  });
}
