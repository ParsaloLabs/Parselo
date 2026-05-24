import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:parsalo_agent/main.dart';

void main() {
  testWidgets('App boots and shows splash', (WidgetTester tester) async {
    await tester.pumpWidget(const ProviderScope(child: ParsaloAgentApp()));
    expect(find.byType(MaterialApp), findsOneWidget);
  });
}
