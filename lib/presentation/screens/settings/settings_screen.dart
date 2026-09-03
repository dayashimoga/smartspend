import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/crypto/key_manager.dart';
import '../../../core/theme/app_theme.dart';
import '../../providers/app_providers.dart';

class SettingsScreen extends ConsumerWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final themeMode = ref.watch(themeModeProvider);
    final currency = ref.watch(defaultCurrencyProvider);
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Settings & Privacy'),
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // Privacy Banner
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: AppColors.income.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(16),
              border:
                  Border.all(color: AppColors.income.withValues(alpha: 0.3)),
            ),
            child: Row(
              children: [
                const Icon(Icons.security, color: AppColors.income, size: 28),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        '100% Offline & Encrypted',
                        style: TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 14,
                            color: AppColors.income),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        'Your financial data never leaves this device. Zero cloud sync, zero telemetry, zero trackers.',
                        style: TextStyle(
                            fontSize: 12,
                            color: isDark
                                ? AppColors.darkTextSecondary
                                : AppColors.lightTextSecondary),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),

          // Preferences
          const Text('Preferences',
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
          const SizedBox(height: 12),

          // Theme Mode
          ListTile(
            title: const Text('Theme Mode'),
            subtitle: Text(themeMode == ThemeMode.dark
                ? 'Dark Mode (AMOLED)'
                : 'Light Mode'),
            trailing: Switch(
              value: themeMode == ThemeMode.dark,
              onChanged: (val) {
                ref.read(themeModeProvider.notifier).state =
                    val ? ThemeMode.dark : ThemeMode.light;
              },
            ),
          ),

          // Currency
          ListTile(
            title: const Text('Primary Currency'),
            subtitle: Text(currency),
            trailing: DropdownButton<String>(
              value: currency,
              underline: const SizedBox.shrink(),
              items: const [
                DropdownMenuItem(value: 'INR', child: Text('INR (₹)')),
                DropdownMenuItem(value: 'USD', child: Text('USD (\$)')),
                DropdownMenuItem(value: 'EUR', child: Text('EUR (€)')),
                DropdownMenuItem(value: 'GBP', child: Text('GBP (£)')),
                DropdownMenuItem(value: 'AED', child: Text('AED (د.إ)')),
              ],
              onChanged: (val) {
                if (val != null) {
                  ref.read(defaultCurrencyProvider.notifier).state = val;
                }
              },
            ),
          ),

          const SizedBox(height: 24),
          // Security
          const Text('Security',
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
          const SizedBox(height: 12),

          FutureBuilder<bool>(
            future: KeyManager.isBiometricLockEnabled(),
            builder: (context, snapshot) {
              final enabled = snapshot.data ?? false;
              return ListTile(
                title: const Text('Biometric App Lock'),
                subtitle: const Text('Require Fingerprint / Face ID to unlock'),
                trailing: Switch(
                  value: enabled,
                  onChanged: (val) async {
                    await KeyManager.setBiometricLockEnabled(val);
                    (context as Element).markNeedsBuild();
                  },
                ),
              );
            },
          ),

          const SizedBox(height: 24),
          // Data Portability & Testing
          const Text('Data & Tools',
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
          const SizedBox(height: 12),

          ListTile(
            leading:
                const Icon(Icons.analytics_outlined, color: AppColors.primary),
            title: const Text('Data Quality & Ingestion History'),
            subtitle: const Text(
                'Parser health, sync diagnostics, and historical runs'),
            trailing: const Icon(Icons.chevron_right),
            onTap: () => context.push('/data-quality'),
          ),

          ListTile(
            leading:
                const Icon(Icons.science_outlined, color: AppColors.primary),
            title: const Text('Load Golden Sample SMS'),
            subtitle: const Text(
                'Inject all 12+ golden test SMS for instant evaluation'),
            onTap: () async {
              try {
                final jsonStr = await rootBundle
                    .loadString('test/fixtures/golden_sms.json');
                final fixtures = jsonDecode(jsonStr) as List<dynamic>;

                final messages = fixtures
                    .map((f) => {
                          'sender': f['sender'],
                          'body': f['raw_sms'],
                          'timestamp': f['timestamp'],
                        })
                    .toList();

                final useCase = ref.read(ingestSmsUseCaseProvider);
                final res = await useCase.execute(messages);

                ref.invalidate(financialSummaryProvider);
                ref.invalidate(recentTransactionsProvider);
                ref.invalidate(allTransactionsProvider);
                ref.invalidate(accountsProvider);
                ref.invalidate(cardsProvider);
                ref.invalidate(billsProvider);
                ref.invalidate(fastagsProvider);
                ref.invalidate(needsReviewTransactionsProvider);

                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                        content: Text(
                            'Loaded ${res.newlyIngested} sample records (${res.duplicatesSkipped} skipped duplicates)')),
                  );
                }
              } catch (e) {
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('Error loading sample data: $e')),
                  );
                }
              }
            },
          ),

          ListTile(
            leading: const Icon(Icons.file_download_outlined),
            title: const Text('Export Data to JSON'),
            subtitle:
                const Text('Complete backup with SHA-256 integrity checksum'),
            onTap: () async {
              final useCase = ref.read(exportBackupUseCaseProvider);
              final jsonStr = await useCase.exportToJson();
              if (context.mounted) {
                _showExportResult(context, 'JSON Backup', jsonStr);
              }
            },
          ),

          ListTile(
            leading: const Icon(Icons.table_chart_outlined),
            title: const Text('Export Data to CSV'),
            subtitle: const Text('Spreadsheet compatible format'),
            onTap: () async {
              final useCase = ref.read(exportBackupUseCaseProvider);
              final csvStr = await useCase.exportToCsv();
              if (context.mounted) {
                _showExportResult(context, 'CSV Export', csvStr);
              }
            },
          ),
          const SizedBox(height: 32),
        ],
      ),
    );
  }

  void _showExportResult(BuildContext context, String title, String content) {
    showDialog(
      context: context,
      builder: (ctx) {
        return AlertDialog(
          title: Text(title),
          content: SingleChildScrollView(
            child: SelectableText(
              content.length > 1000
                  ? '${content.substring(0, 1000)}...\n[Truncated for display]'
                  : content,
              style: const TextStyle(fontSize: 11, fontFamily: 'monospace'),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () {
                Clipboard.setData(ClipboardData(text: content));
                Navigator.pop(ctx);
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Copied export to clipboard')),
                );
              },
              child: const Text('Copy to Clipboard'),
            ),
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Done'),
            ),
          ],
        );
      },
    );
  }
}
