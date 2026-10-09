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

    test('keeps a hash inside quotes that also carries a comment', () {
      expect(unquoteYaml('"secret #1" # note'), 'secret #1');
      expect(unquoteYaml("'a # b' # note"), 'a # b');
    });

    test('drops a comment a quote reopened', () {
      expect(unquoteYaml("'a' # 'b'"), 'a');
      expect(unquoteYaml('a\t# note'), 'a');
    });

    test('leaves an unquoted value alone', () {
      expect(unquoteYaml('plain'), 'plain');
      expect(unquoteYaml(''), '');
    });
  });

  group('yamlCommentIndex', () {
    test('finds a comment only after a space, outside quotes', () {
      expect(yamlCommentIndex('rule # note'), 5);
      expect(yamlCommentIndex('# note'), 0);
      expect(yamlCommentIndex('a\t# note'), 2);
      expect(yamlCommentIndex('"a #b"'), -1);
      expect(yamlCommentIndex("'a #b'"), -1);
      expect(yamlCommentIndex('a#b'), -1);
      expect(yamlCommentIndex('plain'), -1);
    });
  });
}
