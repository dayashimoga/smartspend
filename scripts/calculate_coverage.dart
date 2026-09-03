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
  String currentFile = '';
  int currentLf = 0;
  int currentLh = 0;
  final fileStats = <Map<String, dynamic>>[];

  for (final l in lines) {
    if (l.startsWith('SF:')) {
      currentFile = l.substring(3).trim();
    } else if (l.startsWith('LF:')) {
      currentLf = int.parse(l.substring(3).trim());
      totalFound += currentLf;
    } else if (l.startsWith('LH:')) {
      currentLh = int.parse(l.substring(3).trim());
      totalHit += currentLh;
      fileStats.add({
        'file': currentFile,
        'lf': currentLf,
        'lh': currentLh,
        'missed': currentLf - currentLh,
        'pct': currentLf > 0 ? (currentLh / currentLf) * 100 : 100.0,
      });
    }
  }

  fileStats.sort((a, b) => (b['missed'] as int).compareTo(a['missed'] as int));

  final percent = totalFound > 0 ? (totalHit / totalFound) * 100 : 0.0;
  // ignore: avoid_print
  print('=== Code Coverage Summary ===');
  // ignore: avoid_print
  print('Lines Found: $totalFound');
  // ignore: avoid_print
  print('Lines Hit:   $totalHit');
  // ignore: avoid_print
  print('Coverage:    ${percent.toStringAsFixed(2)}%');
  // ignore: avoid_print
  print('\n=== Lowest Covered Files (Top 10) ===');
  for (final f in fileStats.take(10)) {
    // ignore: avoid_print
    print(
        '${(f['pct'] as double).toStringAsFixed(1)}% (${f['lh']}/${f['lf']}) [missed ${f['missed']}]: ${f['file']}');
  }

  final reportsDir = Directory('reports');
  if (!reportsDir.existsSync()) reportsDir.createSync(recursive: true);

  File('reports/coverage_summary.json').writeAsStringSync('''
{
  "totalLines": $totalFound,
  "linesHit": $totalHit,
  "coveragePercentage": ${percent.toStringAsFixed(2)},
  "status": "${percent >= 90.0 ? 'PASS' : 'FAIL'}"
}
''');

  if (percent < 90.0) {
    // ignore: avoid_print
    print(
        '\n[ERROR] Code coverage ${percent.toStringAsFixed(2)}% is below the mandatory 90.0% quality gate!');
    exit(1);
  }
}
