# 第一周 Day 3：函数与类

> 日期：2026-10-28 ｜ 关联代码：[dart_basics/day3.dart](../../dart_basics/day3.dart)

运行：`dart run --enable-asserts dart_basics/day3.dart`。**命令行默认不执行 `assert`**，要加 `--enable-asserts`；`flutter run` 的 debug 模式默认会执行。

## 1. 函数：三种参数

```dart
int add(int a, int b) => a + b;                                   // 位置参数，必传
String hi(String name, [String? title]) => ...;                   // 可选位置参数 []
void request(String url, {int timeout = 30, required String method}) {}  // 命名参数 {}

request('/api', method: 'GET');   // 命名参数可以随意调换顺序
```

| | Dart | Kotlin | Swift |
|---|---|---|---|
| 命名参数 | `{int timeout = 30}`，调用时写 `timeout: 5` | 任何参数都能按名传 | 默认带参数标签 |
| 必传的命名参数 | `{required String method}` | 不写默认值就是必传 | 不写默认值就是必传 |
| 默认值 | 只能是**编译期常量** | 任意表达式 | 任意表达式 |

- 参数**要么是位置参数，要么是命名参数，在声明时就定死了**。不能像 Kotlin 那样对位置参数写 `add(a = 1)`。
- Flutter 的 Widget 构造函数几乎都用命名参数：`Text('hi', maxLines: 2)`。
- 函数是一等公民：`void Function(String)` 对应 Kotlin 的 `(String) -> Unit`。可以用 `typedef Listener = void Function(String);` 起别名。

## 2. 构造函数

```dart
class Point {
  final double x, y;

  Point(this.x, this.y);                          // 初始化形参：参数直接赋值给字段
  Point.origin() : x = 0, y = 0;                  // 命名构造 + 初始化列表
  Point.onXAxis(double x) : this(x, 0);           // 重定向构造
  Point.polar(double r, double t)
      : assert(r >= 0), x = r * cos(t), y = r * sin(t);   // 初始化列表里先 assert，再算出字段的值
}
```

**final 字段必须在构造函数体执行之前赋值**。可以赋值的位置有三个：
1. 声明时直接赋值
2. 初始化形参 `this.x`
3. **初始化列表 `: x = ...`**（字段的值需要计算时，只能写在这里）

执行到构造函数体 `{ }` 时对象已经创建好了，不能再给 final 字段赋值。这和 Kotlin 的 `init {}` 不同。

| 场景 | Dart | Kotlin | Swift |
|---|---|---|---|
| 多个构造函数 | 命名构造 `Point.origin()`（Dart 没有重载） | 次构造函数 / 重载 | 多个 `init` |
| 委托给另一个构造 | `: this(...)` | `: this(...)` | `self.init(...)` |
| 初始化前做校验 | 初始化列表 `assert` | `init { require() }` | `precondition` |

### factory 构造函数

- 普通构造函数**一定会创建新对象**。factory **可以返回任意对象**：缓存里已有的对象、子类实例，或者直接抛异常。
- factory 里没有 `this`，也不能写初始化列表。
- 调用方式和普通构造函数完全一样，调用方看不出背后是工厂。对应 Kotlin 的 `companion object` 工厂方法。

```dart
class Logger {
  final String tag;
  static final _cache = <String, Logger>{};
  Logger._(this.tag);                                                   // 私有构造
  factory Logger(String tag) => _cache.putIfAbsent(tag, () => Logger._(tag));  // putIfAbsent ≈ Kotlin getOrPut
}
```

### 其他要点

- **const 构造**：所有字段都是 final，构造函数前加 `const`，就可以 `const Point(1, 2)` 在编译期创建并复用。Flutter 里的 `const Text('hi')` 就是靠这个。
- **私有**：名字以 `_` 开头就是私有，范围是**整个文件（library）**，不是类。
- **getter**：`bool get isAdult => age >= 18;`，调用时不加括号。对应 Kotlin 的 `val get()` 和 Swift 的计算属性。
- **没有 data class**：默认的 `==` 比较的是引用。需要值相等时，自己重写 `==` 和 `hashCode`（第 4 周会用 freezed 自动生成）：

```dart
@override
bool operator ==(Object other) => other is Version && major == other.major && ...;
@override
int get hashCode => Object.hash(major, minor, patch);
```

只重写 `==` 不重写 `hashCode` 的话，对象放进 `Set` 或作为 `Map` 的 key 时会出错。练习里的 `Version in Set` 检查测的就是这个。

## 3. mixin

```dart
mixin Flyable {
  int altitude = 0;                 // 可以带状态
  void fly() => altitude += 100;
}
mixin Swimmable on Animal { ... }   // on：只有 Animal 的子类才能混入
class Duck extends Animal with Flyable, Swimmable {}
```

| | Dart mixin | Kotlin interface | Swift protocol extension |
|---|---|---|---|
| 默认方法 | ✅ | ✅ | ✅ |
| **实例字段（状态）** | ✅ | ❌ | ❌ |
| 冲突时怎么办 | 按 `with` 顺序，后写的覆盖先写的 | 必须手动 override | 报错 / 歧义 |

- mixin 本身也是一个类型：`final Observable o = counter;`
- Dart 的每个类都隐式定义了一个接口，可以 `implements` 任意类。
- Flutter 里常见的写法：`with SingleTickerProviderStateMixin`（第 7 周讲动画时会用到）。

## 4. extension

```dart
extension StringX on String {
  String capitalize() => isEmpty ? this : '${this[0].toUpperCase()}${substring(1)}';
}
extension on String? {               // 可以扩展可空类型，此时 this 可能是 null
  bool get isNullOrBlank => this == null || this!.trim().isEmpty;
}
```

- 和 Kotlin 一样是**静态分发**：看的是变量声明的类型。变量声明成 `dynamic` 时扩展不起作用。
- 不起名字的 `extension on X` 只在当前文件里可见。
- **Dart 不会对 `this` 做类型提升**，所以在 `String?` 的扩展里只能反复写 `this!`。方法如果只对非空值有意义，就把它放到 `on String` 的扩展里。

## 5. 级联 `..`

```dart
counter
  ..increment()
  ..increment();   // 整个表达式返回 counter 本身，≈ Kotlin apply {}
```

## 小测验

1. **为什么不能在构造函数体里给 final 字段赋值？应该写在哪？** 执行到构造函数体时对象已经创建好了。应该在声明处、初始化形参 `this.x`、或初始化列表 `: x = ...` 里赋值。（我第一次回答时漏掉了初始化列表。）
2. **普通构造和 factory 构造最本质的区别？** 普通构造一定会创建新对象；factory 可以返回任意对象（缓存、子类、抛异常），而且 factory 里没有 `this`。
3. **mixin 能做到、Kotlin interface 做不到的事？** mixin 可以有实例字段（状态）。

## 参考答案（练习 2、5）

```dart
factory Version.parse(String version) {
  final parts = version.split('.').map(int.tryParse).toList(); // List<int?>，只解析一次
  if (parts.length != 3 || parts.contains(null)) {
    throw FormatException('Bad version: $version');
  }
  return Version(parts[0]!, parts[1]!, parts[2]!);
}
```

## 我犯过的错（review 记录）

| 问题 | 原来的写法 | 改成 |
|---|---|---|
| `capitalize` 把空格吞掉了（review 加了测试 `'  '.capitalize()`） | 放在 `String?` 上，用 `isNullOrBlank` 判断，`null` 时返回 `''` | 单独放进 `on String` 的扩展，用 `isEmpty` 判断 |
| 死代码 | `int.tryParse(part ?? '')`，可是 `split` 的结果不可能为 null | 先确认类型，再决定要不要加 `??` |
| **同一个值解析两次（Day 2 `readInt` 也犯过）** | 先 `tryParse` 校验，再 `parse` 取值 | `map(int.tryParse)` 只解析一次，把结果留下来 |
| Kotlin 风格的 if/else | `containsKey` → 取值 / 新建、存入、返回 | `_cache.putIfAbsent(tag, () => Logger._(tag))` |
| `toString` 缺 `@override` 和返回类型 | `toString() => ...` | `@override String toString() => ...` |
| 类型写两遍 | `static final Map<String, Logger> _cache = <String, Logger>{};` | `static final _cache = <String, Logger>{};` |

还剩两个小问题（不影响通过）：
- `Version.parse` 里的 `if (...) throw ...;` 换行了却没加 `{}`，flutter_lints 会提示。`for` 里你已经加了花括号，`if` 也一样要加。
- `_listeners` 的类型仍然写了两遍，可以改成 `final _listeners = <void Function(String)>[];`。

**总结出的习惯问题**：先写出能跑的代码，再一层层堆判断。应该先想清楚**类型**（这里会不会是 null？）和**数据流**（这个值是不是已经算过了？），然后再动手写。
