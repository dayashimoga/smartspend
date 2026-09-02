import 'dart:io';

void main() {
  final lcovFile = File('coverage/lcov.info');
  if (!lcovFile.existsSync()) {
    // ignore: avoid_print
    print('coverage/lcov.info not found');
    exit(1);
  }

  final lines = lcovFile.readAsLinesSync();
  int totalFound = 0;
  int totalHit = 0;

  for (final l in lines) {
    if (l.startsWith('LF:')) {
      totalFound += int.parse(l.substring(3).trim());
    } else if (l.startsWith('LH:')) {
      totalHit += int.parse(l.substring(3).trim());
    }
  }

  final percent = totalFound > 0 ? (totalHit / totalFound) * 100 : 0.0;
  // ignore: avoid_print
  print('=== Code Coverage Summary ===');
  // ignore: avoid_print
  print('Lines Found: $totalFound');
  // ignore: avoid_print
  print('Lines Hit:   $totalHit');
  // ignore: avoid_print
  print('Coverage:    ${percent.toStringAsFixed(2)}%');

  final reportsDir = Directory('reports');
  if (!reportsDir.existsSync()) reportsDir.createSync(recursive: true);

  File('reports/coverage_summary.json').writeAsStringSync('''
{
  "totalLines": $totalFound,
  "linesHit": $totalHit,
  "coveragePercentage": ${percent.toStringAsFixed(2)},
  "status": "${percent >= 90.0 ? 'PASS' : 'WARNING'}"
}
''');
}
