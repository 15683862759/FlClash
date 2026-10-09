import 'dart:io';

import 'package:test/test.dart';

/// The file level check next to this one only notices a file nothing imports.
/// A single declaration can go dead inside a file that stays busy — a provider
/// nobody reads, a helper whose last caller left — and to whoever changes that
/// file next it still reads like working code.
void main() {
  final sources = {
    for (final file in _dartFiles()) _slash(file.path): file.readAsStringSync(),
  };
  final published = {
    for (final entry in sources.entries)
      if (entry.key.startsWith('lib/') && !_isGenerated(entry.key))
        entry.key: entry.value,
  };

  test('every provider the app declares is read from lib', () {
    final providers = {
      for (final entry in sources.entries)
        if (_isGenerated(entry.key) && entry.key.contains('providers'))
          for (final match in _provider.allMatches(entry.value))
            match.group(1)!,
    };
    expect(providers, isNotEmpty, reason: 'no provider declaration was read');
    final orphans = [
      for (final provider in providers)
        if (!published.values.any(
          (source) => RegExp('\\b$provider\\b').hasMatch(source),
        ))
          '$provider is generated and read nowhere in lib.',
    ];
    expect(orphans, isEmpty, reason: orphans.join('\n'));
  });

  test('every top level function lib declares is called from lib', () {
    final orphans = <String>[];
    for (final entry in published.entries) {
      if (entry.key.startsWith('lib/l10n/')) {
        continue;
      }
      final lines = entry.value.split('\n');
      for (var index = 0; index < lines.length; index++) {
        final match = _function.firstMatch(lines[index]);
        if (match == null) {
          continue;
        }
        final name = match.group(1)!;
        if (_riverpod.hasMatch(_nearestCode(lines, index))) {
          // A notifier is reached through the provider its annotation
          // generates, never through the name declared in this file.
          continue;
        }
        if (RegExp('\\b$name\\b').allMatches(entry.value).length > 1) {
          continue;
        }
        // Only lib counts as a caller here: a helper a test alone drives is a
        // leftover of the app, and the test that drives it hides that. Move the
        // helper into the test instead.
        final called = published.entries.any(
          (other) =>
              other.key != entry.key &&
              RegExp('\\b$name\\b').hasMatch(other.value),
        );
        if (!called) {
          orphans.add('${entry.key} declares $name, which lib never calls.');
        }
      }
    }
    expect(orphans, isEmpty, reason: orphans.join('\n'));
  });
}

final _provider = RegExp(r'^final (\w+Provider) = ', multiLine: true);

/// A declaration that starts in the first column, so class members, which are
/// indented, never match.
final _function = RegExp(
  r'^(?:[A-Za-z_][\w<>,?. ]*?)\s+(\w+)(?:<[^>]*>)?\s*\(',
);

final _riverpod = RegExp('^@[Rr]iverpod');

String _slash(String path) => path.replaceAll(r'\', '/');

String _nearestCode(List<String> lines, int index) {
  for (var cursor = index - 1; cursor >= 0 && cursor >= index - 4; cursor--) {
    final line = lines[cursor].trim();
    if (line.isEmpty) {
      continue;
    }
    return line;
  }
  return '';
}

bool _isGenerated(String path) =>
    path.endsWith('.g.dart') ||
    path.endsWith('.freezed.dart') ||
    path.contains('/generated/');

Iterable<File> _dartFiles() sync* {
  for (final root in ['lib', 'test', 'tool', 'plugins']) {
    final directory = Directory(root);
    if (!directory.existsSync()) {
      fail('$root no longer exists; update this test.');
    }
    for (final entity in directory.listSync(recursive: true)) {
      if (entity is File && entity.path.endsWith('.dart')) {
        yield entity;
      }
    }
  }
}
