import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:smartspend/domain/entities/fastag_record.dart';
import 'package:smartspend/domain/enums/bank.dart';
import 'package:smartspend/presentation/providers/app_providers.dart';
import 'package:smartspend/presentation/screens/fastag/fastag_screen.dart';

void main() {
  final sampleFastags = [
    FastagRecord(
      id: 'ft_1',
      vehicle: 'KA01AB1234',
      bank: Bank.sbi,
      latestWalletBalance: 1450.0,
      currency: 'INR',
      lastUpdated: DateTime(2026, 1, 15),
    ),
    FastagRecord(
      id: 'ft_2',
      vehicle: 'MH02CD5678',
      bank: Bank.icici,
      latestWalletBalance: 820.0,
      currency: 'INR',
      lastUpdated: DateTime(2026, 1, 16),
    ),
  ];

  group('FastagScreen Comprehensive UI Test Suite', () {
    testWidgets('Renders FASTag vehicles with balance and bank names',
        (tester) async {
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            fastagsProvider.overrideWith((ref) => Future.value(sampleFastags)),
          ],
          child: const MaterialApp(
            home: FastagScreen(),
          ),
        ),
      );

      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      expect(find.text('FASTag & Tolls'), findsOneWidget);
      expect(find.text('KA01AB1234'), findsOneWidget);
      expect(find.text('MH02CD5678'), findsOneWidget);
      expect(find.text('State Bank of India'), findsOneWidget);
      expect(find.text('ICICI Bank'), findsOneWidget);
    });

    testWidgets('Renders empty state when no fastag records exist',
        (tester) async {
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            fastagsProvider.overrideWith((ref) => Future.value([])),
          ],
          child: const MaterialApp(
            home: FastagScreen(),
          ),
        ),
      );

      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      expect(find.text('No FASTag vehicles detected'), findsOneWidget);
      expect(find.text('NETC FASTag tolls and recharges will appear here'),
          findsOneWidget);
    });

    testWidgets('Renders error state gracefully', (tester) async {
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            fastagsProvider.overrideWith((ref) => Future.error('DB_ERROR')),
          ],
          child: const MaterialApp(
            home: FastagScreen(),
          ),
        ),
      );

      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));
      expect(find.textContaining('Error: DB_ERROR'), findsOneWidget);
    });
  });
}
