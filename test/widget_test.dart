import 'package:bitdrix/main.dart';
import 'package:material_ui/material_ui.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('Bitdrix app builds', (WidgetTester tester) async {
    await tester.pumpWidget(
      const ProviderScope(
        child: BitdrixApp(),
      ),
    );
    await tester.pump();

    expect(find.byType(BitdrixApp), findsOneWidget);
    expect(find.byType(MaterialApp), findsOneWidget);

    // Unmount the ProviderScope so the providers dispose their services and
    // polling timers, then let any one-shot timers (retries, debounces) fire.
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump(const Duration(minutes: 1));
  });
}
