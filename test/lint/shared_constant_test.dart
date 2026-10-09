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

  test('the app and the core agree on the service ids', () {
    final app = File('lib/common/service_probe.dart').readAsStringSync();
    final core = File('core/service_check.go').readAsStringSync();
    final targets = _enumValues(app, 'ServiceTarget', r"^\s{2}\w+\('([^']+)',");
    final statuses = _enumValues(
      app,
      'ServiceProbeStatus',
      r"^\s{2}\w+\('([^']+)'\)",
    );
    final registered = _quotedValues(core, r'\{name: "([^"]+)", check:');
    final reported = _quotedValues(core, r'service\w+\s*=\s*"([^"]+)"');

    expect(targets, isNotEmpty);
    expect(statuses, isNotEmpty);
    expect(registered, isNotEmpty);
    expect(reported, isNotEmpty);
    expect(
      targets,
      registered,
      reason: 'a ServiceTarget id must name a checker the core registers',
    );
    expect(
      statuses,
      reported,
      reason: 'a ServiceProbeStatus id must be a status the core reports',
    );
  });

  test('the app and the core agree on the method names', () {
    final app = File('lib/core/method.dart').readAsStringSync();
    final core = File('core/constant.go').readAsStringSync();
    final methods = _enumValues(app, 'CoreMethod', r'^  (\w+),');
    final dispatched = _quotedValues(
      core,
      r'^\s*\w+Method\s+CoreMethod\s*=\s*"([^"]+)"',
    );

    expect(methods, isNotEmpty);
    expect(dispatched, isNotEmpty);
    expect(
      methods,
      dispatched,
      reason: 'a CoreMethod name must be one the core answers',
    );
  });

  test('the app and the core agree on the service sweep budget', () {
    final app = File('lib/common/constant.dart').readAsStringSync();
    final core = File('core/service_check.go').readAsStringSync();

    expect(
      _dartIntConst(app, 'serviceSweepBudgetFactor'),
      _goIntConst(core, 'serviceSweepBudgetFactor'),
      reason: 'the guard the app waits with must cover the sweep the core runs',
    );
  });
}

int _dartIntConst(String source, String name) {
  final match = RegExp('const $name\\s*=\\s*(\\d+)').firstMatch(source);
  if (match == null) {
    fail('could not read $name from the Dart constants');
  }
  return int.parse(match.group(1)!);
}

int _goIntConst(String source, String name) {
  final match = RegExp('$name\\s*=\\s*(\\d+)').firstMatch(source);
  if (match == null) {
    fail('could not read $name from the core sources');
  }
  return int.parse(match.group(1)!);
}

Set<String> _enumValues(String source, String name, String pattern) {
  final start = source.indexOf('enum $name {');
  if (start < 0) {
    fail('could not find enum $name in the app sources');
  }
  final semi = source.indexOf(';', start);
  final close = source.indexOf('}', start);
  final end = semi > start && semi < close ? semi : close;
  return _quotedValues(source.substring(start, end), pattern);
}

Set<String> _quotedValues(String source, String pattern) {
  return RegExp(
    pattern,
    multiLine: true,
  ).allMatches(source).map((match) => match.group(1)!).toSet();
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
