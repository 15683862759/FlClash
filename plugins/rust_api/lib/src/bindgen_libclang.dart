import 'dart:io';

typedef DirectoryEntries = List<String> Function(String directory);

/// The directory that holds libclang for a bindgen run, or null when none does.
String? libclangDirectory({
  required String compilerPath,
  String? override,
  DirectoryEntries entriesOf = listEntries,
}) {
  final named = override?.trim();
  if (named != null && named.isNotEmpty && _holdsLibclang(entriesOf(named))) {
    return named;
  }
  final prebuilt = File(compilerPath).parent.parent;
  for (final name in const ['lib', 'lib64']) {
    final directory = '${prebuilt.path}${Platform.pathSeparator}$name';
    if (_holdsLibclang(entriesOf(directory))) {
      return directory;
    }
  }
  return null;
}

List<String> listEntries(String directory) {
  final dir = Directory(directory);
  if (!dir.existsSync()) {
    return const [];
  }
  return [for (final entry in dir.listSync()) entry.uri.pathSegments.last];
}

bool _holdsLibclang(List<String> entries) =>
    entries.any((entry) => entry.startsWith('libclang.'));
