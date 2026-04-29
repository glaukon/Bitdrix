import 'package:bitdrix/main.dart';
import 'package:flutter/material.dart';
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
  });
}
