// 第一周 Day 3 练习：函数与类
// 运行：dart run --enable-asserts dart_basics/day3.dart
//（命令行默认不执行 assert；flutter run 的 debug 模式默认开启）
// 和 Day 2 不同：这次签名、构造函数也要你自己写。
// 每完成一个练习，把 main() 里对应那段检查取消注释，直到全部 ✅

// ───────── 练习 1：User —— 命名参数 + required + 重定向构造 ─────────
// class User，字段：final String name; final int age; final String? email;
// - 主构造函数用命名参数：name、age 必传，email 可选。用法：User(name: 'Tom', age: 20)
// - 命名构造函数 User.guest()：name = 'guest'，age = 0，用重定向（: this(...)）写
// - getter isAdult：age >= 18
// - 加分：让 User 可以 const 构造

class User {
  final String name;
  final int age;
  final String? email;
  const User({required this.name, required this.age, this.email});
  const User.guest() : this(name: 'guest', age: 0);
  bool get isAdult => age >= 18;
}

// ───────── 练习 2：Version —— 初始化列表 + factory + == ─────────
// class Version，字段 final int major, minor, patch
// - 主构造函数 Version(1, 2, 3)，用初始化列表 assert 三个数都 >= 0
// - factory Version.parse('1.2.3')；格式不对（不是 3 段、或某段不是整数）时 throw FormatException
// - toString() 返回 '1.2.3'
// - Version(1, 2, 3) == Version(1, 2, 3) 要为 true（想想 Kotlin data class 帮你做了什么，Dart 没做）

class Version {
  final int major, minor, patch;
  const Version(this.major, this.minor, this.patch)
    : assert(major >= 0 && minor >= 0 && patch >= 0);

  factory Version.parse(String version) {
    final parts = version.split('.').map(int.tryParse).toList(); // List<int?>
    if (parts.length != 3 || parts.contains(null))
      throw FormatException('Bad version: $version');
    return Version(parts[0]!, parts[1]!, parts[2]!);
  }

  @override
  String toString() => '$major.$minor.$patch';

  @override
  bool operator ==(Object other) =>
      other is Version &&
      major == other.major &&
      minor == other.minor &&
      patch == other.patch;

  @override
  int get hashCode => Object.hash(major, minor, patch);
}

// ───────── 练习 3：Logger —— 用 factory 实现「同名单例」 ─────────
// - Logger('net') 调用两次，拿到的是同一个对象（identical 为 true）
// - Logger('db') 是另一个对象
// - 字段 final String tag
// 提示：私有命名构造 Logger._(...) + static Map 缓存

class Logger {
  final String tag;
  static final _cache = <String, Logger>{};
  Logger._(this.tag);

  factory Logger(String tag) => _cache.putIfAbsent(tag, () => Logger._(tag));
}

// ───────── 练习 4：mixin ─────────
// mixin Observable：
//   - addListener(void Function(String) listener)
//   - notify(String event)：依次调用所有 listener
// class Counter with Observable：
//   - int value，初始 0
//   - increment()：value + 1，然后 notify('count=$value')

mixin Observable {
  final List<void Function(String)> _listeners = <void Function(String)>[];
  void addListener(void Function(String) listener) => _listeners.add(listener);
  void notify(String event) {
    for (final listener in _listeners) {
      listener(event);
    }
  }
}

class Counter with Observable {
  int value = 0;
  void increment() {
    value++;
    notify('count=$value');
  }
}

// ───────── 练习 5：extension ─────────
// - String? 上的 getter isNullOrBlank：null、''、'   ' 都返回 true（对照 Kotlin isNullOrBlank）
// - String 上的方法 capitalize()：'flutter' => 'Flutter'，'' => ''
// - int 上的 getter seconds：3.seconds == Duration(seconds: 3)

extension StringX on String? {
  bool get isNullOrBlank => this == null || this!.trim().isEmpty;
}

extension on String {
  String capitalize() =>
      isEmpty ? this : '${this[0].toUpperCase()}${substring(1)}';
}

extension DurationX on int {
  Duration get seconds => Duration(seconds: this);
}

void main() {
  // ── 练习 1 ──
  const tom = User(name: 'Tom', age: 20, email: 'tom@x.com');
  check('User name', () => tom.name, 'Tom');
  check('User email 可选', () => User(name: 'Amy', age: 3).email, null);
  check('User isAdult', () => tom.isAdult, true);
  check('User.guest name', () => User.guest().name, 'guest');
  check('User.guest isAdult', () => User.guest().isAdult, false);

  // ── 练习 2 ──
  check('Version toString', () => Version(1, 2, 3).toString(), '1.2.3');
  check('Version.parse', () => Version.parse('10.0.7').toString(), '10.0.7');
  check('Version ==', () => Version(1, 2, 3) == Version.parse('1.2.3'), true);
  check('Version !=', () => Version(1, 2, 3) == Version(1, 2, 4), false);
  check('Version in Set', () => {Version(1, 0, 0), Version(1, 0, 0)}.length, 1);
  checkThrows<FormatException>('parse 段数不对', () => Version.parse('1.2'));
  checkThrows<FormatException>('parse 非数字', () => Version.parse('1.x.3'));
  checkThrows<AssertionError>('assert 负数', () => Version(-1, 0, 0));

  // ── 练习 3 ──
  check('Logger 同名同对象', () => identical(Logger('net'), Logger('net')), true);
  check('Logger 异名异对象', () => identical(Logger('net'), Logger('db')), false);
  check('Logger tag', () => Logger('db').tag, 'db');

  // ── 练习 4 ──
  final counter = Counter();
  final events = <String>[];
  counter.addListener(events.add);
  counter.addListener((e) => events.add('2nd:$e'));
  counter
    ..increment()
    ..increment();
  check('Counter value', () => counter.value, 2);
  check(
    'Counter events',
    () => events.join(','),
    'count=1,2nd:count=1,count=2,2nd:count=2',
  );
  // mixin 本身也是一个类型，可以用来声明变量
  final Observable observable = counter;
  check('Counter is Observable', () => identical(observable, counter), true);

  // ── 练习 5 ──
  String? nothing;
  check('isNullOrBlank null', () => nothing.isNullOrBlank, true);
  check('isNullOrBlank 空格', () => '   '.isNullOrBlank, true);
  check('isNullOrBlank 有字', () => ' a '.isNullOrBlank, false);
  check('capitalize', () => 'flutter'.capitalize(), 'Flutter');
  check('capitalize 空串', () => ''.capitalize(), '');
  // Day 3 review 补充：全是空格的字符串要原样返回，不能把空格吞掉
  check('capitalize 纯空格', () => '  '.capitalize(), '  ');
  check('3.seconds', () => 3.seconds, const Duration(seconds: 3));
}

void check(String label, Object? Function() actual, Object? expected) {
  Object? value;
  try {
    value = actual();
  } catch (e) {
    value = '抛出异常 $e';
  }
  final ok = value == expected;
  print('${ok ? '✅' : '❌'} $label${ok ? '' : '  期望 $expected，实际 $value'}');
}

void checkThrows<T>(String label, void Function() body) {
  try {
    body();
    print('❌ $label  期望抛出 $T，实际没抛');
  } catch (e) {
    final ok = e is T;
    print('${ok ? '✅' : '❌'} $label${ok ? '' : '  期望 $T，实际 ${e.runtimeType}'}');
  }
}
