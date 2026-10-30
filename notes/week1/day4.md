# 第一周 Day 4：集合、records、sealed + 模式匹配

> 日期：2026-10-30 ｜ 关联代码：[dart_basics/day4.dart](../../dart_basics/day4.dart)

运行：`dart run --enable-asserts dart_basics/day4.dart`

## 0. 回顾：final 字段的三个赋值位置

1. 声明处：`final int count = 0;`
2. 初始化形参：`Point(this.x, this.y);`
3. **初始化列表**：`Point(this.x, this.y) : distance = sqrt(x * x + y * y);`

值需要**计算**出来（而不是把参数原样存进去）时，就要用初始化列表。`: assert(...)` 也写在初始化列表里。

| | 写法 |
|---|---|
| Kotlin | `val d = ...` 写在类体或 `init {}` 里 |
| Swift | `init` 里调用 `super.init()` 之前给 `let` 赋值 |
| Dart | 构造函数体执行时对象已经建好，final 只能在冒号后面的初始化列表里赋值；初始化列表里不能访问 `this` |

（这是第二次漏答初始化列表，Day 6 复盘会再考。）

## 1. 集合字面量

```dart
final items = [
  'Home',
  if (loggedIn) 'Profile' else 'Login',   // collection if
  for (final t in tags) '#$t',            // collection for
  ...extras,                              // 展开
  ...?maybeList,                          // 为 null 时什么都不放
  ?badge,                                 // Dart 3.8+：null-aware 元素
];
final map = {'a': 1, if (x) 'b': 2};
```

Kotlin 要用 `buildList { if (x) add(...) }`，Dart 直接在字面量里写控制流。Flutter 中最常见的用法：`Column(children: [Header(), if (loading) Spinner(), for (final i in items) Tile(i)])`。

## 2. 函数式操作

| Kotlin | Dart | 注意 |
|---|---|---|
| `map / filter` | `map / where` | 返回**惰性** `Iterable`，需要 `.toList()` |
| `sortedBy {}` | `list.sort(cmp)` | ⚠️ **原地修改、返回 void** |
| `getOrPut` | `putIfAbsent` / `update(k, f, ifAbsent:)` | |
| `groupBy` | 核心库没有（`package:collection` 里有） | |

```dart
final sorted = [...list]..sort((a, b) => b.score.compareTo(a.score)); // 复制一份再排序，不改原列表
```

**惰性 Iterable 每访问一次就重新计算一次。** 实测：

```dart
double? average(Iterable<int> xs) =>
    xs.isEmpty ? null : xs.reduce((a, b) => a + b) / xs.length;

average([1, 2, 3, 4, 5, 6].where((x) { calls++; return x.isEven; }));
// calls == 14：isEmpty 2 次 + reduce 6 次 + length 6 次
```

需要多次访问时，要么先 `.toList()`，要么改成只遍历一遍（`fold`）。

## 3. Records

```dart
(int, String) pair = (1, 'a');                    // pair.$1、pair.$2
({double lat, double lng}) p = (lat: 1, lng: 2);   // p.lat
final (a, b) = pair;                               // 解构
(x, y) = (y, x);                                   // 交换
```

- ≈ Swift 的 tuple；不像 Kotlin `Pair` 那样只能放两个值。
- **自带结构相等**：`(1, 2) == (1, 2)` 为 true。
- 适合临时组合几个值、函数多返回值。需要在多处传递或加方法时，还是写类。

## 4. sealed class + switch 表达式

```dart
sealed class Result {}
class Ok extends Result { final int data; Ok(this.data); }
class Err extends Result { final String msg; Err(this.msg); }

String show(Result r) => switch (r) {
  Ok(data: 0)                    => 'zero',              // 常量模式
  Ok(:final data) when data < 0  => 'negative $data',    // 守卫
  Ok(:final data)                => 'ok $data',
  Err(:final msg)                => 'err $msg',
};
```

- 子类必须写在**同一个文件**里，编译器才能做穷尽性检查。漏掉一个子类就会编译报错（≈ Kotlin `when` on sealed / Swift enum `switch`）。
- 不写 `default` / `_`，这样以后新增子类时编译器能帮你找到所有需要补的地方。

## 5. 模式速查

| 模式 | 写法 | 含义 |
|---|---|---|
| 对象 | `Rect(:final width)` | 类型匹配并取出字段 |
| 常量 | `Circle(radius: 0)`、`Failed(code: 401)` | 字段等于某个常量 |
| 类型 | `String city` | 类型匹配并绑定变量，可以代替 `is` |
| 列表 | `[double a, double b]`、`[]` | 长度和元素同时匹配 |
| Map | `{'name': String name}` | key 存在且值的类型匹配 |
| 判空 | `final x?` | 不为 null 才匹配 |
| 守卫 | `when cond` | 额外的条件 |

`if-case` 可以一步完成「判断 + 解构 + 校验」：

```dart
if (s.split(',').map(double.tryParse).toList() case [double lat, double lng]
    when lat.abs() <= 90 && lng.abs() <= 180) {
  return (lat: lat, lng: lng);
}
```

`[double lat, double lng]` 一次同时检查了长度为 2、元素不为 null、类型是 double，每段只解析一次。（`double.tryParse` 会忽略首尾空白，所以 `' 121.47'` 也能解析。）

JSON 解析也是这样，一个 Map 模式可以替代一长串 `is` / `as` / `[]`：

```dart
String? userCity(Object? json) => switch (json) {
  {'user': {'address': {'city': String city}}} => city,
  _ => null,
};
```

## 参考答案（review 后的写法）

```dart
List<String> buildMenu({required bool loggedIn, String? badge, List<String> extras = const []}) => [
  'Home',
  if (loggedIn) 'Profile' else 'Login',
  ?badge,
  ...extras.map((e) => e.toUpperCase()),
  'About',
];

Map<String, int> wordCount(String text) {
  final counts = <String, int>{};
  for (final w in text.toLowerCase().split(RegExp(r'\s+'))) {
    if (w.isEmpty) continue;
    counts.update(w, (c) => c + 1, ifAbsent: () => 1);
  }
  return counts;
}

double? average(Iterable<int> xs) {
  final (sum, count) = xs.fold((0, 0), (acc, x) => (acc.$1 + x, acc.$2 + 1));
  return count == 0 ? null : sum / count;
}

String render(LoadState s) => switch (s) {
  Loading() => 'loading...',
  Loaded(items: []) => 'empty',
  Loaded(:final items) => '${items.length} items: ${items.join(', ')}',
  Failed(code: 401) => 'please login',
  Failed(:final message) => 'error: $message',
};
```

## 我犯过的错（review 记录）

| 问题 | 原来的写法 | 改成 |
|---|---|---|
| **为了让测试通过而硬编码** | `500 => 'error: oops'` | `Failed(:final message) => 'error: $message'`。测试和题目对不上时，应该提问，或者想清楚这条测试本来要测什么 |
| 题目要求不写 `is` | `'city': final city` + `when city is String` | 类型模式 `'city': String city` |
| **又算了两次**（第三次出现） | 每个词调了两次 `toLowerCase()` | 一开始就对整段文本 `toLowerCase()` |
| 惰性 Iterable 遍历三遍 | `isEmpty` + `reduce` + `length` | 用 `fold` 一遍同时求和与计数 |
| 分两步校验 | `length != 2` 之后再用 `parts[0]`/`parts[1]` | 列表模式 `[double lat, double lng]` |
| 守卫可以换成常量模式 | `Circle(:final radius) when radius == 0` | `Circle(radius: 0)` |

还剩两个小问题（不影响通过）：
- `wordCount` 仍然是 `map[w] = map.putIfAbsent(w, () => 0) + 1`。`update(w, (c) => c + 1, ifAbsent: () => 1)` 更直接；另外后面已经有 `where(isNotEmpty)`，前面的 `.trim()` 就多余了。
- `Loaded(:final items) when items.isEmpty` 可以写成列表模式 `Loaded(items: [])`。

题目歧义（是我写题的问题）：练习 5 的「其它 Failed => `'error: timeout'`」应该写成 `'error: <message>'`。
