import 'package:fl_clash/features/editor/yaml_lines.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('unquoteYaml', () {
    test('keeps a hash inside a quoted scalar', () {
      expect(unquoteYaml('"secret #1"'), 'secret #1');
      expect(unquoteYaml("'a # b'"), 'a # b');
    });

    test('still strips the comment outside the quotes', () {
      expect(unquoteYaml('"secret" # note'), 'secret');
      expect(unquoteYaml('plain # note'), 'plain');
      expect(unquoteYaml('# note'), '');
    });

    test('leaves an unquoted value alone', () {
      expect(unquoteYaml('plain'), 'plain');
      expect(unquoteYaml(''), '');
    });
  });
}
