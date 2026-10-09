import 'dart:io';

import 'package:test/test.dart';

/// The Android side answers three method channels by name. A name only one
/// side knows is not a compile error: the call throws `MissingPluginException`,
/// or the event is dropped, and the feature behind it stops working quietly.
void main() {
  const channels = <String, (String dart, String kotlin)>{
    'app': (
      'lib/plugins/app.dart',
      'android/app/src/main/kotlin/com/follow/clash/plugins/AppPlugin.kt',
    ),
    'service': (
      'lib/plugins/service.dart',
      'android/app/src/main/kotlin/com/follow/clash/plugins/ServicePlugin.kt',
    ),
    'tile': (
      'lib/plugins/tile.dart',
      'android/app/src/main/kotlin/com/follow/clash/plugins/TilePlugin.kt',
    ),
  };
  final sources = {
    for (final entry in channels.entries)
      entry.key: (
        dart: File(entry.value.$1).readAsStringSync(),
        kotlin: File(entry.value.$2).readAsStringSync(),
      ),
  };

  test('the app and the android plugins agree on the package name', () {
    final dart = File('lib/common/constant.dart').readAsStringSync();
    final components = File(
      'android/common/src/main/java/com/follow/clash/common/Components.kt',
    ).readAsStringSync();
    expect(
      _dartConst(dart, 'packageName'),
      _kotlinConst(components, 'PACKAGE_NAME'),
      reason: 'a channel the app opens must be one the plugin registers',
    );
  });

  test('the app and the android plugins agree on the channel names', () {
    final dart = <String>{};
    for (final entry in sources.entries) {
      final names = _quoted(
        entry.value.dart,
        r"MethodChannel\('\$packageName/(\w+)'",
      );
      expect(names, {entry.key}, reason: '${entry.key} channel name');
      dart.addAll(names);
    }
    final kotlin = <String>{};
    for (final entry in sources.entries) {
      final names = _quoted(
        entry.value.kotlin,
        r'Components\.PACKAGE_NAME\}/(\w+)"',
      );
      expect(names, {entry.key}, reason: '${entry.key} channel name');
      kotlin.addAll(names);
    }
    expect(dart, kotlin);
  });

  test('every method the app calls is answered by its plugin', () {
    var calls = 0;
    var handled = 0;
    for (final entry in sources.entries) {
      final sent = _quoted(
        entry.value.dart,
        r"invoke(?:Map)?Method(?:<[^>]*>)?\(\s*'([A-Za-z]\w*)'",
      );
      final answers = _quoted(entry.value.kotlin, r'"([A-Za-z]\w*)" ->');
      calls += sent.length;
      handled += answers.length;
      expect(
        sent.difference(answers),
        isEmpty,
        reason:
            '${entry.key} calls ${sent.difference(answers).join(', ')}, which '
            'its plugin does not answer',
      );
    }
    expect(calls, greaterThanOrEqualTo(20), reason: 'the extraction broke');
    expect(handled, greaterThanOrEqualTo(20), reason: 'the extraction broke');
  });

  test('every method a plugin calls is handled by the app', () {
    var sent = 0;
    var received = 0;
    for (final entry in sources.entries) {
      final events = _quoted(
        entry.value.kotlin,
        r'invokeMethod(?:OnMainThread)?\(\s*"([A-Za-z]\w*)"',
      );
      final handlers = _quoted(entry.value.dart, r"case '([A-Za-z]\w*)':");
      sent += events.length;
      received += handlers.length;
      expect(
        events.difference(handlers),
        isEmpty,
        reason:
            '${entry.key} sends ${events.difference(handlers).join(', ')}, which '
            'the app does not handle',
      );
    }
    expect(sent, greaterThanOrEqualTo(5), reason: 'the extraction broke');
    expect(received, greaterThanOrEqualTo(6), reason: 'the extraction broke');
  });

  test('the app and the app plugin agree on the argument keys', () {
    final app = sources['app']!;
    final keys = _quoted(app.dart, r"'([A-Za-z]\w*)':")
      ..removeAll(_quoted(app.dart, r"case '([A-Za-z]\w*)':"));
    final read = _quoted(
      app.kotlin,
      r'call\.argument(?:<[^>]*>)?\("([A-Za-z]\w*)"\)',
    );
    expect(keys, isNotEmpty, reason: 'the extraction broke');
    expect(
      keys,
      read,
      reason: 'an argument the plugin reads by a name the app does not send',
    );
  });
}

Set<String> _quoted(String source, String pattern) => RegExp(
  pattern,
  multiLine: true,
).allMatches(source).map((match) => match.group(1)!).toSet();

String _dartConst(String source, String name) {
  final match = RegExp("const $name\\s*=\\s*'([^']+)'").firstMatch(source);
  if (match == null) {
    fail('could not read $name from the app constants');
  }
  return match.group(1)!;
}

String _kotlinConst(String source, String name) {
  final match = RegExp('const val $name = "([^"]+)"').firstMatch(source);
  if (match == null) {
    fail('could not read $name from the android components');
  }
  return match.group(1)!;
}
