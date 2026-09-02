import 'dart:io';

void main() {
  final lcov = File('coverage/lcov.info').readAsLinesSync();
  final layerLinesFound = <String, int>{};
  final layerLinesHit = <String, int>{};

  String currentFile = '';
  for (final line in lcov) {
    if (line.startsWith('SF:')) {
      currentFile = line.substring(3).replaceAll('\\', '/');
    } else if (line.startsWith('LF:')) {
      final layer = _getLayer(currentFile);
      layerLinesFound[layer] = (layerLinesFound[layer] ?? 0) + int.parse(line.substring(3));
    } else if (line.startsWith('LH:')) {
      final layer = _getLayer(currentFile);
      layerLinesHit[layer] = (layerLinesHit[layer] ?? 0) + int.parse(line.substring(3));
    }
  }

  // ignore: avoid_print
  print('=== Layer Coverage Breakdown ===');
  for (final layer in layerLinesFound.keys) {
    final found = layerLinesFound[layer]!;
    final hit = layerLinesHit[layer] ?? 0;
    final pct = (hit / found) * 100;
    // ignore: avoid_print
    print('${layer.padRight(25)}: ${pct.toStringAsFixed(1)}% ($hit / $found lines)');
  }
}

String _getLayer(String path) {
  if (path.contains('/parsers/')) return 'parsers';
  if (path.contains('/data/')) return 'data';
  if (path.contains('/domain/')) return 'domain';
  if (path.contains('/core/')) return 'core';
  if (path.contains('/application/')) return 'application';
  if (path.contains('/presentation/')) return 'presentation';
  return 'other';
}
