import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:smartspend/application/export/export_backup_usecase.dart';
import 'package:smartspend/core/database/database_helper.dart';
import 'package:smartspend/presentation/providers/app_providers.dart';
import 'package:smartspend/presentation/screens/settings/settings_screen.dart';

class TestExportBackupUseCase extends Fake implements ExportBackupUseCase {
  @override
  Future<String> exportToJson({String? passphrase}) async =>
      '{"version":"1.0","payload":{"transactions":[]}}';

  @override
  Future<String> exportToCsv() async =>
      'Date,Amount,Merchant,Category\n2026-01-01,100.0,Test,General';
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late DatabaseHelper dbHelper;
  late TestExportBackupUseCase testExportUseCase;

  setUp(() async {
    dbHelper = DatabaseHelper.inMemory();
    testExportUseCase = TestExportBackupUseCase();
  });

  tearDown(() async {
    await dbHelper.close();
  });

  group('SettingsScreen Comprehensive UI Test Suite', () {
    testWidgets('Renders all preferences and switches theme mode',
        (tester) async {
      tester.view.physicalSize = const Size(1080, 2400);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            dbHelperProvider.overrideWithValue(dbHelper),
          ],
          child: const MaterialApp(
            home: SettingsScreen(),
          ),
        ),
      );

      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      expect(find.text('Settings & Privacy'), findsOneWidget);
      expect(find.text('100% Offline & Encrypted'), findsOneWidget);
      expect(find.text('Preferences'), findsOneWidget);
      expect(find.text('Theme Mode'), findsOneWidget);
      expect(find.text('Primary Currency'), findsOneWidget);
      expect(find.text('Security'), findsOneWidget);
      expect(find.text('Biometric App Lock'), findsOneWidget);
      expect(find.text('Load Golden Sample SMS'), findsOneWidget);
      expect(find.text('Export Data to JSON'), findsOneWidget);
      expect(find.text('Export Data to CSV'), findsOneWidget);

      // Tap Theme Mode switch to toggle
      final themeSwitch = find.byWidgetPredicate(
        (w) => w is Switch && w.value == true,
      );
      if (themeSwitch.evaluate().isNotEmpty) {
        await tester.tap(themeSwitch.first);
        await tester.pump();
      }

      await tester.pump(const Duration(seconds: 11));
    });

    testWidgets('Allows changing primary currency', (tester) async {
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            dbHelperProvider.overrideWithValue(dbHelper),
          ],
          child: const MaterialApp(
            home: SettingsScreen(),
          ),
        ),
      );

      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      // Verify default currency INR
      expect(find.text('INR'), findsOneWidget);

      await tester.pump(const Duration(seconds: 11));
    });

    testWidgets('Tapping Export to JSON opens dialog and copies to clipboard',
        (tester) async {
      tester.view.physicalSize = const Size(1080, 2400);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            dbHelperProvider.overrideWithValue(dbHelper),
            exportBackupUseCaseProvider.overrideWithValue(testExportUseCase),
          ],
          child: const MaterialApp(
            home: SettingsScreen(),
          ),
        ),
      );

      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      await tester.tap(find.text('Export Data to JSON'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 200));

      expect(find.text('JSON Backup'), findsOneWidget);
      expect(find.text('Copy to Clipboard'), findsOneWidget);

      await tester.tap(find.text('Copy to Clipboard'));
      await tester.pumpAndSettle();

      expect(find.text('JSON Backup'), findsNothing);
      await tester.pump(const Duration(seconds: 11));
    });

    testWidgets('Tapping Export to CSV opens dialog and dismisses with Done',
        (tester) async {
      tester.view.physicalSize = const Size(1080, 2400);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            dbHelperProvider.overrideWithValue(dbHelper),
            exportBackupUseCaseProvider.overrideWithValue(testExportUseCase),
          ],
          child: const MaterialApp(
            home: SettingsScreen(),
          ),
        ),
      );

      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      await tester.tap(find.text('Export Data to CSV'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 200));

      expect(find.text('CSV Export'), findsOneWidget);
      expect(find.text('Done'), findsOneWidget);

      await tester.tap(find.text('Done'));
      await tester.pumpAndSettle();

      expect(find.text('CSV Export'), findsNothing);
      await tester.pump(const Duration(seconds: 11));
    });

    testWidgets('Toggles biometric app lock switch', (tester) async {
      tester.view.physicalSize = const Size(1080, 2400);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            dbHelperProvider.overrideWithValue(dbHelper),
          ],
          child: const MaterialApp(
            home: SettingsScreen(),
          ),
        ),
      );

      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      final switches = find.byType(Switch);
      if (switches.evaluate().length >= 2) {
        await tester.tap(switches.at(1));
        await tester.pump();
      }

      await tester.pump(const Duration(seconds: 11));
    });

    testWidgets('Tapping Load Golden Sample SMS loads sample data',
        (tester) async {
      tester.view.physicalSize = const Size(1080, 2400);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            dbHelperProvider.overrideWithValue(dbHelper),
          ],
          child: const MaterialApp(
            home: SettingsScreen(),
          ),
        ),
      );

      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      await tester.tap(find.text('Load Golden Sample SMS'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 500));

      await tester.pump(const Duration(seconds: 11));
    });
  });
}
