import 'dart:async';
import 'dart:isolate';

// 第一周 Day 5 练习：Future / async-await / Stream / Isolate
// 运行：dart run --enable-asserts dart_basics/day5.dart
// 把 throw UnimplementedError() 换成你的实现。
// 今天的额外要求：
//   - 能并发的别串行（看 check 里的耗时检查）
//   - 继续「每个值只算一次」、不为了过测试写死分支

// ───────── 练习 1：事件循环，先猜再跑 ─────────
// 不要运行！先读 eventLoopDemo，把你认为的 log 顺序填进 myGuess。
// 填完再跑，对比结果，想清楚每一步为什么。
const myGuess = <String>[
  '1',
  'a',
  '6',
  'b',
  '3',
  '2',
  '4',
  '5',
]; //实际 1 a 6 b 3 2 4 5，then会在清空microtask队列执行

Future<List<String>> eventLoopDemo() async {
  final log = <String>[];

  Future<void> work() async {
    log.add('a');
    await null;
    log.add('b');
  }

  log.add('1');
  Future(() => log.add('2'));
  work();
  scheduleMicrotask(() => log.add('3'));
  Future.delayed(Duration.zero, () => log.add('4'));
  Future.value().then((_) => log.add('5'));
  log.add('6');

  await Future.delayed(const Duration(milliseconds: 20));
  return log;
}

// ───────── 练习 2：并发 ─────────
// 假的网络请求，每个耗时 100ms（不要改）
Future<String> fetchName(int id) =>
    Future.delayed(const Duration(milliseconds: 100), () => 'user$id');
Future<String> fetchAvatar(int id) =>
    Future.delayed(const Duration(milliseconds: 100), () => 'avatar$id.png');

// 并发拉取所有 id 的名字，保持 ids 的顺序。5 个 id 总耗时要 < 200ms。
Future<List<String>> loadAll(List<int> ids) => Future.wait(ids.map(fetchName));

// 同时拉名字和头像，返回 'user1|avatar1.png'。总耗时要 < 200ms。
// 提示：试试 records 的 .wait
Future<String> loadProfile(int id) => (
  fetchName(id),
  fetchAvatar(id),
).wait.then((result) => '${result.$1}|${result.$2}');

// ───────── 练习 3：错误处理 ─────────
// 执行 task，抛异常就重试，最多一共执行 times 次。
// 全部失败时，把「最后一次」的异常原样抛出去。
Future<T> retry<T>(Future<T> Function() task, {int times = 3}) async {
  try {
    return await task();
  } on Exception {
    if (times <= 1) rethrow;
    return retry(task, times: times - 1);
  }
}

// 不稳定的接口（不要改）：
//   id == 0 → 200ms 才返回
//   id == 1 → 抛 FormatException
//   id == 2 → 抛 StateError
//   其他    → 立刻返回 'user$id'
Future<String> unstableFetch(int id) async {
  switch (id) {
    case 0:
      await Future.delayed(const Duration(milliseconds: 200));
      return 'slow';
    case 1:
      throw const FormatException('bad json');
    case 2:
      throw StateError('server down');
    default:
      return 'user$id';
  }
}

// 调 unstableFetch：超过 50ms → 'unknown'；FormatException → 'bad'；
// 其他异常照常往外抛。
Future<String> nameOrFallback(int id) async {
  try {
    return await unstableFetch(id).timeout(const Duration(milliseconds: 50));
  } on TimeoutException {
    return 'unknown';
  } on FormatException {
    return 'bad';
  }
}

// ───────── 练习 4：Stream ─────────
// 用 async* 写：从 from 倒数到 1，每个数之间隔 10ms。countdown(0) 什么也不发。
Stream<int> countdown(int from) async* {
  for (var i = from; i > 0; i--) {
    yield i;
    if (i > 1) {
      await Future.delayed(const Duration(milliseconds: 10));
    }
  }
}

// 清洗搜索框输入：去首尾空格、丢掉空串、连续重复的只留一个。
// 要求：只用 Stream 的操作符链出来，不写 async*、不写 await for。
Stream<String> cleanQueries(Stream<String> raw) =>
    raw.map((w) => w.trim()).where((w) => w.isNotEmpty).distinct();

// 用 await for 读 s，把读到的内容用 ',' 拼起来，遇到 stop 就停（stop 本身不要）。
// 停下以后不能再继续监听源 Stream —— 测试会检查源有没有被 cancel。
Future<String> readUntil(Stream<String> s, String stop) async {
  final result = <String>[];
  await for (final value in s) {
    if (value == stop) {
      break;
    }
    result.add(value);
  }
  return result.join(',');
}

// ───────── 练习 5（挑战）：debounce ─────────
// 搜索框防抖（第 4 周主线项目会用到）：source 每发一个值就重新计时，
// 安静满 duration 才把「最新的那个值」发出去。
// source 结束时：如果还有没发出去的值，立刻发出，然后关闭输出流。
// 提示：StreamController + Timer；记得在 onCancel 里取消对 source 的订阅。
Stream<T> debounce<T>(Stream<T> source, Duration duration) {
  late final StreamController<T> controller;
  StreamSubscription<T>? subscription;
  Timer? timer;

  late T last;
  var hasPending = false;
  controller = StreamController<T>(
    onListen: () {
      subscription = source.listen(
        (value) {
          last = value;
          hasPending = true;

          timer?.cancel();

          timer = Timer(duration, () {
            controller.add(value);
            hasPending = false;
          });
        },
        onDone: () {
          timer?.cancel();

          if (hasPending) {
            controller.add(last);
            hasPending = false;
          }
          controller.close();
        },
        onError: (Object e, StackTrace stackTrace) {
          controller.addError(e, stackTrace);
        },
      );
    },
    onCancel: () async {
      timer?.cancel();
      await subscription?.cancel();
    },
  );

  return controller.stream;
}

// ───────── 练习 6：Isolate ─────────
// CPU 密集的同步函数（不要改）
int countPrimes(int n) {
  var count = 0;
  for (var i = 2; i <= n; i++) {
    var isPrime = true;
    for (var j = 2; j * j <= i; j++) {
      if (i % j == 0) {
        isPrime = false;
        break;
      }
    }
    if (isPrime) count++;
  }
  return count;
}

// 把 countPrimes 放到另一个 isolate 里跑，不卡当前 isolate 的事件循环。
Future<int> countPrimesInBackground(int n) => Isolate.run(() => countPrimes(n));

// ───────────────────────────────────────────
Future<void> main() async {
  // ── 练习 1 ──
  final actualLog = await eventLoopDemo();
  print('事件循环实际顺序: ${actualLog.join(' ')}');
  await check('你的猜测', () => myGuess.join(' '), actualLog.join(' '));

  // ── 练习 2 ──
  await check(
    'loadAll',
    () async => (await loadAll([3, 1, 2])).join(','),
    'user3,user1,user2',
  );
  await check('loadAll 空', () async => (await loadAll([])).length, 0);
  await checkFast('loadAll 并发', () => loadAll([1, 2, 3, 4, 5]));
  await check('loadProfile', () => loadProfile(7), 'user7|avatar7.png');
  await checkFast('loadProfile 并发', () => loadProfile(7));

  // ── 练习 3 ──
  var attempts = 0;
  await check(
    'retry 第 3 次成功',
    () => retry(() async {
      attempts++;
      if (attempts < 3) throw Exception('fail $attempts');
      return 'ok';
    }),
    'ok',
  );
  await check('retry 次数', () => attempts, 3);
  attempts = 0;
  await check(
    'retry 全失败抛最后一个',
    () => retry(() async {
      attempts++;
      throw Exception('fail $attempts');
    }, times: 2),
    '抛出异常 Exception: fail 2',
  );
  await check('retry 不多试', () => attempts, 2);
  attempts = 0;
  await check('retry 一次成功不重试', () async {
    await retry(() async => ++attempts);
    return attempts;
  }, 1);

  await check('fallback 超时', () => nameOrFallback(0), 'unknown');
  await check('fallback 坏 JSON', () => nameOrFallback(1), 'bad');
  await check(
    'fallback 其他异常往外抛',
    () => nameOrFallback(2),
    '抛出异常 Bad state: server down',
  );
  await check('fallback 正常', () => nameOrFallback(9), 'user9');

  // ── 练习 4 ──
  await check(
    'countdown',
    () async => (await countdown(3).toList()).join(','),
    '3,2,1',
  );
  await check('countdown 0', () => countdown(0).isEmpty, true);
  await check(
    'cleanQueries',
    () async => (await cleanQueries(
      Stream.fromIterable([
        '  ',
        'flu',
        'flu ',
        'flutter',
        '',
        'flutter',
        'dart',
        'flutter',
      ]),
    ).toList()).join(','),
    'flu,flutter,dart,flutter',
  );
  var cancelled = false;
  final source = StreamController<String>(onCancel: () => cancelled = true);
  for (final x in ['a', 'b', 'stop', 'c']) {
    source.add(x);
  }
  await check('readUntil', () => readUntil(source.stream, 'stop'), 'a,b');
  await check('readUntil 取消了源', () => cancelled, true);
  await check(
    'readUntil 没遇到 stop',
    () => readUntil(Stream.fromIterable(['x', 'y']), 'stop'),
    'x,y',
  );

  // ── 练习 5 ──
  await check('debounce', () async {
    final input = StreamController<String>();
    final out = debounce(
      input.stream,
      const Duration(milliseconds: 50),
    ).toList();
    for (final q in ['f', 'fl', 'flu']) {
      input.add(q);
      await Future.delayed(const Duration(milliseconds: 10));
    }
    await Future.delayed(const Duration(milliseconds: 100));
    input.add('flut');
    await input.close();
    return (await out).join(',');
  }, 'flu,flut');

  // ── 练习 6 ──
  var ticks = 0;
  final ticker = Timer.periodic(
    const Duration(milliseconds: 5),
    (_) => ticks++,
  );
  await check('isolate 结果', () => countPrimesInBackground(3000000), 216816);
  ticker.cancel();
  await check('isolate 期间主 isolate 没卡住', () => ticks > 10, true);
}

Future<void> check(
  String label,
  FutureOr<Object?> Function() actual,
  Object? expected,
) async {
  Object? value;
  try {
    value = await actual();
  } catch (e) {
    value = '抛出异常 $e';
  }
  final ok = value == expected;
  print('${ok ? '✅' : '❌'} $label${ok ? '' : '  期望 $expected，实际 $value'}');
}

Future<void> checkFast(String label, Future<Object?> Function() task) async {
  final sw = Stopwatch()..start();
  try {
    await task();
  } catch (e) {
    print('❌ $label  抛出异常 $e');
    return;
  }
  final ms = sw.elapsedMilliseconds;
  final ok = ms < 200;
  print('${ok ? '✅' : '❌'} $label  耗时 ${ms}ms${ok ? '' : '（> 200ms，串行了？）'}');
}
