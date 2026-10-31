# 第一周 Day 5：异步（Future / Stream / Isolate）

日期：2026-10-31　练习：[dart_basics/day5.dart](../../dart_basics/day5.dart)

## 1. 心智模型：单线程 + 事件循环

每个 **isolate** 都有自己的一个线程、一块堆内存和一个事件循环。不共享内存，所以不需要锁，也不会出现数据竞争。

```
同步代码跑完 → 清空 microtask 队列 → 从 event 队列取一个任务 → 清空 microtask 队列 → …
```

| 队列 | 谁往里放 | 优先级 |
|---|---|---|
| **microtask** | `scheduleMicrotask`、`.then` 回调、`await` 之后的续体、`Future.value()` 的完成 | 高，每轮都会**全部清空** |
| **event** | `Future(() {})`、`Future.delayed`、Timer、I/O、用户输入 | 低，每次只取一个 |

两条规则：
- **`.then` 和 `await` 的续体都在 microtask 里执行，只有「时间」和「I/O」相关的才进 event 队列。**
- 调用 `async` 函数时，它会**同步执行到第一个 `await`**，然后才把控制权交还给调用方。这点和 Kotlin 的 `launch` 不同。

练习 1 的答案是 `1 a 6 b 3 5 2 4`：

| 轮次 | 输出 | 原因 |
|---|---|---|
| 同步 | `1 a 6` | `work()` 同步执行到 `await null` 之前，所以 `a` 是同步打出来的 |
| microtask | `b 3 5` | 按入队顺序执行：先是 `await null` 的续体，然后是 `scheduleMicrotask`，最后是 `Future.value()` 完成后的 `.then` |
| event | `2 4` | `Future(...)` 和 `Future.delayed(zero)` 都是 Timer 任务，按入队顺序执行 |

## 2. 和原生对照

| Dart | Kotlin 协程 | Swift Concurrency |
|---|---|---|
| `Future<T>` | `Deferred<T>` / `suspend fun` | `Task<T>` / `async` 函数 |
| `Future.wait`、`(a, b).wait` | `awaitAll` | `async let` / `TaskGroup` |
| `Stream<T>` | `Flow<T>` | `AsyncSequence` |
| `async*` + `yield` | `flow { emit() }` | `AsyncStream` |
| `await for` | `collect {}` | `for await` |
| 单订阅 / 广播 Stream | 冷流 / `SharedFlow` | — |
| `StreamController` | `MutableSharedFlow` / `Channel` | `AsyncStream.Continuation` |
| `Isolate`（不共享内存，消息拷贝） | 线程池（共享内存） | 后台 Task / actor |
| `Isolate.run`（Flutter 里叫 `compute`） | `withContext(Dispatchers.Default)` | `Task.detached` |

和协程不一样的地方：
- **没有结构化并发**。Future 不能取消。如果一个 Future 没被 await，它抛出的错误会变成未捕获异常。
- **`await` 不切换线程**。CPU 密集的计算写在 `async` 函数里照样会卡 UI，要放到 Isolate 里跑。

## 3. Future

```dart
// ❌ 串行，200ms
final name = await fetchName(1);
final avatar = await fetchAvatar(1);

// ✅ 并发，100ms：先把 Future 都创建出来，再一起 await
final (name, avatar) = await (fetchName(1), fetchAvatar(1)).wait; // 每个值保留各自的类型
final names = await Future.wait(ids.map(fetchName));               // 同一类型的一组 Future
```

错误处理建议用 `try` / `on 类型` / `catch` 来写，比 `.catchError` 清楚：

```dart
try {
  return await unstableFetch(id).timeout(const Duration(milliseconds: 50));
} on TimeoutException {
  return 'unknown';
} on FormatException {
  return 'bad';
} // 没有列出的异常类型会继续往外抛；在 catch 里要重新抛出就用 rethrow
```

`Exception` 和 `Error` 的区别：`Exception` 表示可以预期的失败，比如网络或格式问题，值得重试或兜底。`Error`（StateError、TypeError…）表示代码 bug，不应该被吞掉。所以 `retry` 只 `on Exception` 是合理的设计。

## 4. Stream

- 默认的 Stream 是**单订阅**的，只能 listen 一次。**广播** Stream 可以同时被多个监听者订阅。
- `subscription.cancel()` 相当于取消 collect。在 `await for` 里 `break` 会**自动 cancel** 上游订阅。
- 操作符和 Iterable 基本一样：`map`、`where`、`distinct`、`take`、`asyncMap`、`fold`。
- 写 `async*` 生成器时，`yield` 发出一个值，`yield*` 转发另一个 Stream 的全部值。
- 在 Flutter 里，`StreamBuilder` 和 `FutureBuilder` 负责订阅和取消。

自己用 `StreamController` 实现一个操作符时，要处理好这几点：
1. 在 `onListen` 里才去订阅 source，保持「冷」的特性。
2. 数据、**错误**、完成三种事件都要转发，`onError: controller.addError` 不能漏。
3. 在 `onCancel` 里取消对 source 的订阅，以及自己创建的 Timer。

## 5. Isolate

- 每个 isolate 的堆是独立的。传过去的数据会被**拷贝**，所以闭包里不要捕获大对象，也不要捕获不能发送的对象（Socket、带原生资源的对象）。
- 一次性的计算用 `Isolate.run(() => heavy(x))` 就够了。长期运行的后台 isolate 要用 `SendPort` / `ReceivePort` 收发消息。
- 典型用途：解析大 JSON、处理图片、加解密。网络请求本身是异步 I/O，**不需要**放进 isolate。

## 参考答案（review 后的写法）

```dart
Future<List<String>> loadAll(List<int> ids) => Future.wait(ids.map(fetchName));

Future<String> loadProfile(int id) async {
  final (name, avatar) = await (fetchName(id), fetchAvatar(id)).wait;
  return '$name|$avatar';
}

Future<T> retry<T>(Future<T> Function() task, {int times = 3}) async {
  try {
    return await task();
  } on Exception {
    if (times <= 1) rethrow;
    return retry(task, times: times - 1);
  }
}

Stream<int> countdown(int from) async* {
  for (var i = from; i > 0; i--) {
    yield i;
    if (i > 1) await Future.delayed(const Duration(milliseconds: 10));
  }
}

Stream<String> cleanQueries(Stream<String> raw) =>
    raw.map((w) => w.trim()).where((w) => w.isNotEmpty).distinct();

Future<String> readUntil(Stream<String> s, String stop) async {
  final result = <String>[];
  await for (final value in s) {
    if (value == stop) break; // break 会 cancel 源 Stream
    result.add(value);
  }
  return result.join(',');
}

Stream<T> debounce<T>(Stream<T> source, Duration duration) {
  late final StreamController<T> controller;
  StreamSubscription<T>? subscription;
  Timer? timer;
  (T,)? pending; // 用 record 包一层：null 表示「没有值」，(null,) 表示「值就是 null」

  void flush() {
    if (pending case (final value,)) {
      pending = null;
      controller.add(value);
    }
  }

  controller = StreamController<T>(
    onListen: () {
      subscription = source.listen(
        (value) {
          pending = (value,);
          timer?.cancel();
          timer = Timer(duration, flush);
        },
        onError: controller.addError,
        onDone: () {
          timer?.cancel();
          flush();
          controller.close();
        },
      );
    },
    onCancel: () {
      timer?.cancel();
      return subscription?.cancel();
    },
  );
  return controller.stream;
}

Future<int> countPrimesInBackground(int n) => Isolate.run(() => countPrimes(n));
```

## 我犯过的错（review 记录）

| 问题 | 原来的写法 | 改成 |
|---|---|---|
| 以为 `.then` 的回调进 event 队列 | 猜测顺序为 `… 3 2 4 5` | `Future.value()` 在 microtask 里完成，`.then` 回调也跟着在 microtask 里执行，所以 `5` 排在 `2` 和 `4` 前面 |
| **用 `null` 当「没有值」的标记**（T 可空时出错） | `T? last` + `if (value != null)` | 用 `bool hasPending`，或者用 `(T,)?` 包一层。「有没有值」和「值是什么」要分开存 |
| **没有转发 source 的错误** | `listen` 不传 `onError` → 进程崩溃 | `onError: controller.addError` |
| 第一个值之前也延迟了 | 先 `delay` 再 `yield` | 先 `yield`，`i > 1` 时才 `delay` |
| 少写泛型、能 final 的没 final | `StreamSubscription?`、`late StreamController` | `StreamSubscription<T>?`、`late final` |

还剩两个小问题（不影响通过）：
- `loadProfile` 仍然写成 `.then((r) => '${r.$1}|${r.$2}')`。改成 `async` + 解构，给字段起名字会更好读。
- `debounce` 里 Timer 回调和 `onDone` 各写了一遍「发出 + 清标记」的逻辑，可以抽成一个 `flush()`。`onError` 也可以直接传 tear-off `controller.addError`。

这次做得好的地方：没有重复计算，也没有为了过测试写死分支。`retry` 主动区分了 `Exception` 和 `Error`。
