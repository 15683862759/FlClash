import 'dart:io';

import 'package:fl_clash/common/constant.dart';
import 'package:test/test.dart';

/// The app and the core each keep a copy of the browser user agent and the default test URL.
void main() {
  test('the app and the core share one user agent and test URL', () {
    final dart = File('lib/common/constant.dart').readAsStringSync();
    final go = File('core/outbound_ip.go').readAsStringSync();
    final core = File('core/common.go').readAsStringSync();
    expect(_dartConst(dart, 'browserUa'), startsWith('Mozilla/5.0 '));
    expect(_dartConst(dart, 'defaultTestUrl'), startsWith('https://'));

    expect(
      _dartConst(dart, 'browserUa'),
      _goConst(go, 'browserUserAgent'),
      reason: 'browserUa and browserUserAgent must stay in step',
    );
    expect(
      _dartConst(dart, 'defaultTestUrl'),
      _goConst(core, 'defaultTestURL'),
      reason: 'defaultTestUrl and defaultTestURL must stay in step',
    );
  });

  test('the editor suggests the default test URL', () {
    final schema = File(
      'lib/features/editor/clash_schema.dart',
    ).readAsStringSync();
    final suggested = RegExp(
      r"'url': YamlSchema\.scalar\(\['([^']+)'\]\)",
    ).allMatches(schema).map((match) => match.group(1)).toList();

    expect(suggested, isNotEmpty);
    for (final url in suggested) {
      expect(url, defaultTestUrl, reason: 'the schema suggests $url');
    }
  });
}

String _dartConst(String source, String name) {
  final match = RegExp("const $name\\s*=\\s*'([^']+)'").firstMatch(source);
  if (match == null) {
    fail('could not read $name from the Dart constants');
  }
  return match.group(1)!;
}

String _goConst(String source, String name) {
  final match = RegExp('$name\\s*=\\s*"([^"]+)"').firstMatch(source);
  if (match == null) {
    fail('could not read $name from the core sources');
  }
  return match.group(1)!;
}
