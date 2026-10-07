import 'dart:async';

import 'package:fl_clash/common/common.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('never runs more than the configured number of tasks at once', () async {
    final pool = TaskPool(3);
    final gates = <Completer<void>>[];
    var running = 0;
    var peak = 0;

    final runs = List.generate(12, (_) {
      return pool.run(() async {
        running++;
        peak = running > peak ? running : peak;
        final gate = Completer<void>();
        gates.add(gate);
        await gate.future;
        running--;
      });
    });

    var released = 0;
    while (released < 12) {
      await Future<void>.delayed(Duration.zero);
      while (released < gates.length) {
        gates[released++].complete();
      }
    }
    await Future.wait(runs);

    expect(peak, 3);
    expect(pool.activeCount, 0);
    expect(pool.pendingCount, 0);
  });

  test('admits queued tasks in the order they arrived', () async {
    final pool = TaskPool(1);
    final order = <int>[];
    final runs = List.generate(
      5,
      (index) => pool.run(() async {
        order.add(index);
      }),
    );

    await Future.wait(runs);

    expect(order, [0, 1, 2, 3, 4]);
  });

  test('hands the slot on when a task throws', () async {
    final pool = TaskPool(1);
    await expectLater(
      pool.run(() async => throw StateError('boom')),
      throwsStateError,
    );

    expect(await pool.run(() async => 'next'), 'next');
    expect(pool.activeCount, 0);
  });

  test('runs priority tasks before queued normal tasks', () async {
    final pool = TaskPool(1);
    final order = <int>[];
    final blocker = Completer<void>();
    final first = pool.run(() async {
      order.add(0);
      await blocker.future;
    });
    await Future<void>.delayed(Duration.zero);
    final normal = pool.run(() async {
      order.add(2);
    });
    final priority = pool.run(() async {
      order.add(1);
    }, priority: true);

    blocker.complete();
    await Future.wait([first, normal, priority]);

    expect(order, [0, 1, 2]);
  });

  test(
    'shares queued slots across fair keys before draining one key',
    () async {
      final pool = TaskPool(1);
      final order = <String>[];
      final blocker = Completer<void>();
      final first = pool.run(
        () async {
          order.add('a-0');
          await blocker.future;
        },
        priority: true,
        fairKey: 'a',
      );
      final second = pool.run(
        () async {
          order.add('a-1');
        },
        priority: true,
        fairKey: 'a',
      );
      final secondSameKey = pool.run(
        () async {
          order.add('a-2');
        },
        priority: true,
        fairKey: 'a',
      );
      final third = pool.run(
        () async {
          order.add('b-0');
        },
        priority: true,
        fairKey: 'b',
      );

      blocker.complete();
      await Future.wait([first, second, secondSameKey, third]);

      expect(order, ['a-0', 'a-1', 'b-0', 'a-2']);
    },
  );
}
