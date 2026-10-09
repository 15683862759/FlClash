import 'dart:io';

import 'package:test/test.dart';
import 'package:yaml/yaml.dart';

void main() {
  late YamlMap workflow;

  setUpAll(() {
    workflow = loadYaml(
      File('.github/workflows/build.yaml').readAsStringSync(),
    ) as YamlMap;
  });

  test('tag releases run for this fork', () {
    const repository = 'nizabushangtianne3/FlClash';
    final jobs = workflow['jobs'] as YamlMap;
    final build = jobs['build'] as YamlMap;
    final upload = jobs['upload'] as YamlMap;

    for (final job in [build, upload]) {
      final condition = job['if'] as String;
      final repositories =
          RegExp(r"github\.repository == '([^']+)'")
              .allMatches(condition)
              .map((match) => match.group(1)!)
              .toSet();
      expect(repositories, contains(repository), reason: condition);
    }

    final buildCondition = build['if'] as String;
    expect(buildCondition, contains("github.event_name == 'push'"));
    expect(buildCondition, contains("startsWith(github.ref, 'refs/tags/v')"));
  });
}
