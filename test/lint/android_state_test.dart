import 'dart:io';

import 'package:test/test.dart';

/// The VPN service is started from a `SharedState` the app writes as JSON and
/// Gson reads back. A name only one side has is not an error there: Gson leaves
/// the Kotlin default in place, so a setting silently reverts, and an enum that
/// lands null throws the moment the service reads it.
void main() {
  final sharedState = File('lib/models/state.dart').readAsStringSync();
  final coreModels = File('lib/models/core.dart').readAsStringSync();
  final configModels = File('lib/models/config.dart').readAsStringSync();
  final enums = File('lib/enum/enum.dart').readAsStringSync();
  final kotlinState = File(
    'android/app/src/main/kotlin/com/follow/clash/models/State.kt',
  ).readAsStringSync();
  final kotlinVpn = File(
    'android/service/src/main/java/com/follow/clash/service/models/VpnOptions.kt',
  ).readAsStringSync();
  final kotlinEnums = File(
    'android/common/src/main/java/com/follow/clash/common/Enums.kt',
  ).readAsStringSync();

  test('the shared state the app writes is the one the service reads', () {
    final sent = _dartPayloadNames(sharedState, 'SharedState');
    final read = _kotlinProperties(kotlinState, 'SharedState');
    expect(sent, isNotEmpty);
    expect(read, isNotEmpty);
    expect(
      sent.length,
      greaterThanOrEqualTo(10),
      reason: 'the extraction broke',
    );
    expect(
      sent.difference(read),
      isEmpty,
      reason: 'the service ignores ${sent.difference(read).join(', ')}',
    );
    expect(
      read.difference(sent),
      isEmpty,
      reason: 'the service expects ${read.difference(sent).join(', ')} in vain',
    );
  });

  test('the setup params use the same json keys', () {
    final sent = _dartPayloadKeys(coreModels, 'SetupParams');
    final read = _kotlinSerializedNames(kotlinState, 'SetupParams');
    expect(sent, isNotEmpty);
    expect(sent, read);
  });

  test('the vpn options the app writes are the ones the service reads', () {
    final sent = _dartPayloadNames(coreModels, 'VpnOptions');
    final read = _kotlinProperties(kotlinVpn, 'VpnOptions');
    expect(sent, isNotEmpty);
    expect(read, isNotEmpty);
    expect(sent, read);
  });

  test('the access control props only drop the app side fields', () {
    final sent = _dartPayloadNames(configModels, 'AccessControlProps');
    final read = _kotlinProperties(kotlinVpn, 'AccessControlProps');
    expect(sent, isNotEmpty);
    expect(read, isNotEmpty);
    expect(
      read.difference(sent),
      isEmpty,
      reason: 'the service reads ${read.difference(sent).join(', ')} in vain',
    );
  });

  test('the access control modes carry the names the app sends', () {
    final sent = _enumValues(enums, 'AccessControlMode');
    final read = _kotlinSerializedNames(kotlinEnums, 'AccessControlMode');
    expect(sent, isNotEmpty);
    expect(sent, read, reason: 'an unknown mode leaves the Kotlin enum null');
  });
}

/// The json key of every field of a freezed factory: the `@JsonKey` name when
/// one is given, the field name otherwise.
Set<String> _dartPayloadKeys(String source, String className) =>
    _dartFields(source, className).values.toSet();

Set<String> _dartPayloadNames(String source, String className) =>
    _dartFields(source, className).keys.toSet();

Map<String, String> _dartFields(String source, String className) {
  const header = 'const factory ';
  final open = source.indexOf('$header$className({');
  if (open < 0) {
    fail('could not find the $className factory');
  }
  final close = source.indexOf('}) =', open);
  if (close < 0) {
    fail('could not find the end of the $className factory');
  }
  final fields = <String, String>{};
  for (final chunk in _splitTopLevel(
    source.substring(open + header.length + className.length + 2, close),
  )) {
    final parameter = chunk.trim();
    if (parameter.isEmpty) {
      continue;
    }
    final keyed = RegExp("name: '([^']+)'").firstMatch(parameter);
    final field = RegExp(
      r'([A-Za-z_]\w*)\s*\??\s*$',
    ).firstMatch(parameter.replaceAll(RegExp(r'=\s*.+$', dotAll: true), ''));
    if (field == null) {
      fail('could not read a field name from "$parameter"');
    }
    fields[field.group(1)!] = keyed?.group(1) ?? field.group(1)!;
  }
  return fields;
}

Set<String> _enumValues(String source, String name) {
  final start = source.indexOf('enum $name {');
  if (start < 0) {
    fail('could not find enum $name');
  }
  final end = source.indexOf('}', start);
  final values = <String>{};
  for (final chunk in _splitTopLevel(
    source.substring(source.indexOf('{', start) + 1, end),
  )) {
    // One value per line, or all of them on one, with any `@JsonValue(...)`
    // standing in front of the name.
    final cleaned = chunk.replaceAll(RegExp(r'\([^)]*\)'), ' ').trim();
    final match = RegExp(r'(\w+)\s*$').firstMatch(cleaned);
    if (match != null) {
      values.add(match.group(1)!);
    }
  }
  return values;
}

/// The property names of a Kotlin data class.
Set<String> _kotlinProperties(String source, String className) {
  final body = _kotlinClassBody(source, className);
  return RegExp(
    r'^\s*val (\w+):',
    multiLine: true,
  ).allMatches(body).map((match) => match.group(1)!).toSet();
}

/// The `@SerializedName` values of a Kotlin data class or enum.
Set<String> _kotlinSerializedNames(String source, String className) {
  final body = _kotlinClassBody(source, className);
  return RegExp(
    r'@SerializedName\("([^"]+)"\)',
  ).allMatches(body).map((match) => match.group(1)!).toSet();
}

String _kotlinClassBody(String source, String className) {
  final start =
      RegExp(
        '(?:data class|enum class) $className[(\\s]',
      ).firstMatch(source)?.start ??
      -1;
  if (start < 0) {
    fail('could not find the Kotlin $className');
  }
  final open = source.indexOf('(', start);
  final brace = source.indexOf('{', start);
  final isEnum = brace >= 0 && (open < 0 || brace < open);
  final bodyStart = isEnum ? brace : open;
  if (bodyStart < 0) {
    fail('could not find the body of the Kotlin $className');
  }
  final close = source.indexOf(isEnum ? '\n}' : '\n)', bodyStart);
  if (close < 0) {
    fail('could not find the end of the Kotlin $className');
  }
  return source.substring(bodyStart, close);
}

List<String> _splitTopLevel(String body) {
  final parts = <String>[];
  final buffer = StringBuffer();
  var depth = 0;
  for (var index = 0; index < body.length; index++) {
    final char = body[index];
    if (char == '<' || char == '(' || char == '[') {
      depth++;
    } else if (char == '>' || char == ')' || char == ']') {
      depth--;
    } else if (char == ',' && depth == 0) {
      parts.add(buffer.toString());
      buffer.clear();
      continue;
    }
    buffer.write(char);
  }
  parts.add(buffer.toString());
  return parts;
}
