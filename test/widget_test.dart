import 'package:animpro/main.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  testWidgets('first launch shows the non-AI onboarding after splash', (tester) async {
    SharedPreferences.setMockInitialValues(<String, Object>{
      'onboarding_complete': false,
    });
    final preferences = await SharedPreferences.getInstance();

    await tester.pumpWidget(AnimProApp(preferences: preferences));
    await tester.pump(const Duration(milliseconds: 1000));
    await tester.pumpAndSettle();

    expect(find.text('Make a little magic, frame by frame.'), findsOneWidget);
    expect(find.text('LOCAL BY DESIGN · NO AI'), findsOneWidget);
  });
}
