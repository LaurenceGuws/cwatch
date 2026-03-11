import 'dart:async';

import 'package:dartssh2/dartssh2.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:cwatch/model/services_infra/ssh/builtin/builtin_ssh_client_lifecycle.dart';

class _FakeClient implements SSHClient {
  bool closed = false;
  final Completer<void> doneCompleter = Completer<void>();

  @override
  void close() {
    closed = true;
    if (!doneCompleter.isCompleted) {
      doneCompleter.complete();
    }
  }

  @override
  Future<void> get done => doneCompleter.future;

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

void main() {
  test('withManagedClient closes client after action', () async {
    final lifecycle = const BuiltInSshClientLifecycle();
    final client = _FakeClient();

    final result = await lifecycle.withManagedClient<int>(
      () async => client,
      (_) async => 7,
    );

    expect(result, 7);
    expect(client.closed, true);
  });

  test('killClient closes client immediately', () {
    final lifecycle = const BuiltInSshClientLifecycle();
    final client = _FakeClient();

    lifecycle.killClient(client);

    expect(client.closed, true);
  });
}
