import 'package:flutter_test/flutter_test.dart';

import 'package:cwatch/model/services_infra/ssh/process_ssh_search_planner.dart';

void main() {
  const planner = ProcessSshSearchPlanner();

  test('createPlan derives command base, name flag, and timeout policy', () {
    final plan = planner.createPlan(
      basePath: '/var/log',
      query: 'nginx',
      matchCase: false,
      searchContents: true,
      timeout: const Duration(seconds: 30),
    );

    expect(plan.basePath, '/var/log');
    expect(plan.commandBase, "cd '/var/log' &&");
    expect(plan.escapedQuery, 'nginx');
    expect(plan.nameFlag, '-iname');
    expect(plan.effectiveTimeoutSeconds, 120);
  });

  test('buildPatternClause handles shallow and deep path matching', () {
    final clause = planner.buildPatternClause(
      'logs, nested/path',
      nameFlag: '-iname',
      basePath: '/var/log',
      allowDeepNameMatch: true,
    );

    expect(clause, contains("-iname 'logs'"));
    expect(clause, contains("-path './nested/path'"));
    expect(clause, contains("-path './nested/path/*'"));
  });

  test('buildPruneClause keeps directory prune rules explicit', () {
    final clause = planner.buildPruneClause(
      'cache,tmp/data',
      nameFlag: '-iname',
      basePath: '/var/log',
    );

    expect(clause, contains("-iname 'cache'"));
    expect(clause, contains("-path './tmp/data'"));
    expect(clause, contains("-path './tmp/data/*'"));
  });

  test('buildPredicate combines type, include, and exclude rules', () {
    final plan = planner.createPlan(
      basePath: '/var/log',
      query: 'nginx',
      matchCase: true,
      searchContents: false,
      timeout: const Duration(seconds: 30),
    );

    final predicate = planner.buildPredicate(
      typeFlag: 'f',
      includeName: true,
      plan: plan,
      matchWholeWord: false,
      includePattern: 'conf',
      excludePattern: 'tmp',
    );

    expect(predicate, contains('-type f'));
    expect(predicate, contains("-name '*nginx*'"));
    expect(predicate, contains("-path './conf'"));
    expect(predicate, contains("! \\( -name 'tmp'"));
  });
}
