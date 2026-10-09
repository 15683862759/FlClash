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

  test('the app and the helper agree on how they talk', () {
    final app = File('lib/common/constant.dart').readAsStringSync();
    final hub = File('services/helper/src/service/hub.rs').readAsStringSync();
    final linux = File(
      'services/helper/src/service/linux.rs',
    ).readAsStringSync();
    final windows = File(
      'services/helper/src/service/windows.rs',
    ).readAsStringSync();

    expect(
      _dartConst(app, 'helperProtocolVersionHeader'),
      _rustConst(hub, 'PROTOCOL_VERSION_HEADER'),
      reason: 'the app must send the header the helper reads',
    );
    expect(
      _dartConst(app, 'helperProtocolVersion'),
      _rustConst(hub, 'PROTOCOL_VERSION'),
      reason: 'a version the helper does not answer makes it unreachable',
    );
    expect(
      _dartIntConst(app, 'helperPort'),
      _rustIntConst(hub, 'LISTEN_PORT'),
      reason: 'the app dials the port the helper listens on',
    );
    expect(
      _dartConst(app, 'helperSocketPath'),
      _rustConst(linux, 'SOCKET_PATH'),
      reason: 'the app connects to the socket the helper owns',
    );
    expect(
      _dartConst(app, 'appHelperService'),
      _rustConst(windows, 'SERVICE_NAME'),
      reason: 'the app installs the service the helper registers',
    );
  });

  test('every message the core sends decodes into an app event', () {
    final app = File('lib/enum/enum.dart').readAsStringSync();
    final core = File('core/constant.go').readAsStringSync();
    final events = _enumValues(app, 'CoreEventType', r'^  (\w+),');
    final messages = _quotedValues(
      core,
      r'^\s*\w+Message\s+MessageType\s*=\s*"([^"]+)"',
    );

    expect(events, isNotEmpty);
    expect(messages, isNotEmpty);
    expect(
      messages.difference(events),
      isEmpty,
      reason:
          'a message the core sends must be a CoreEventType the app decodes',
    );
  });

  test('the app and the core agree on the geo resources', () {
    final app = File('lib/enum/enum.dart').readAsStringSync();
    final core = File('core/hub.go').readAsStringSync();
    // The body slice ends at the enum's `;`, so the last member arrives
    // without its separator and needs the end-of-input alternative.
    final names = _enumValues(app, 'GeoResource', r'^  (\w+)(?:[,;]|$)');
    final values = _enumValues(app, 'GeoResource', r"@JsonValue\('([^']+)'\)");
    final keys = _quotedValues(core, r'^\t"(\w+)":\s+\{update:');
    final lowerKeys = {for (final key in keys) key.toLowerCase()};

    expect(names, isNotEmpty);
    expect(values, isNotEmpty);
    expect(keys, isNotEmpty);
    expect(
      names,
      keys,
      reason:
          'the app updates a resource by name, which the core looks up as is',
    );
    expect(
      values,
      lowerKeys,
      reason:
          'the core reports the name back and the app decodes it lower cased',
    );
  });
}

String _rustConst(String source, String name) {
  final match = RegExp('const $name: &str = "([^"]+)"').firstMatch(source);
  if (match == null) {
    fail('could not read $name from the helper sources');
  }
  return match.group(1)!;
}

int _rustIntConst(String source, String name) {
  final match = RegExp('const $name: u16 = (\\d+)').firstMatch(source);
  if (match == null) {
    fail('could not read $name from the helper sources');
  }
  return int.parse(match.group(1)!);
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
