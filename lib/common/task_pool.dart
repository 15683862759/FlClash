import 'dart:async';
import 'dart:collection';

class _FairQueue {
  final Map<Object?, Queue<Completer<void>>> _queues = {};
  final Queue<Object?> _order = Queue();
  int _length = 0;

  int get length => _length;

  void add(Object? key, Completer<void> waiter) {
    final queue = _queues.putIfAbsent(key, () {
      _order.add(key);
      return Queue<Completer<void>>();
    });
    queue.add(waiter);
    _length++;
  }

  Completer<void>? removeFirst() {
    while (_order.isNotEmpty) {
      final key = _order.removeFirst();
      final queue = _queues[key];
      if (queue == null) {
        continue;
      }
      final waiter = queue.removeFirst();
      if (queue.isEmpty) {
        _queues.remove(key);
      } else {
        _order.add(key);
      }
      _length--;
      return waiter;
    }
    return null;
  }
}

class TaskPool {
  TaskPool(this.concurrency) : assert(concurrency > 0);

  final int concurrency;

  final _waiting = _FairQueue();
  final _priorityWaiting = _FairQueue();
  int _active = 0;

  int get activeCount => _active;

  int get pendingCount => _waiting.length + _priorityWaiting.length;

  int get idleSlots => pendingCount == 0 ? concurrency - _active : 0;

  /// Queued tasks with different [fairKey] values take turns when a slot frees.
  Future<T> run<T>(
    Future<T> Function() task, {
    bool priority = false,
    Object? fairKey,
  }) async {
    if (_active >= concurrency || pendingCount > 0) {
      final waiter = Completer<void>();
      if (priority) {
        _priorityWaiting.add(fairKey, waiter);
      } else {
        _waiting.add(fairKey, waiter);
      }
      await waiter.future;
    } else {
      _active++;
    }
    try {
      return await task();
    } finally {
      final waiter = _priorityWaiting.removeFirst() ?? _waiting.removeFirst();
      if (waiter != null) {
        waiter.complete();
      } else {
        _active--;
      }
    }
  }
}
