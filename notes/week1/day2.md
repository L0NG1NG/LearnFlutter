# 第一周 Day 2：变量、空安全、final 与 const

> 日期：2026-10-27 ｜ 关联代码：[dart_basics/day2.dart](../../dart_basics/day2.dart)

运行单个 Dart 文件不需要建工程：`dart run dart_basics/day2.dart`。也可以用 [DartPad](https://dartpad.dev) 在线试代码。

> ⚠️ 写惯 Kotlin / Swift 后最容易踩的坑：**Dart 每行结尾必须写分号**。

## 1. 变量声明

| 含义 | Dart | Kotlin | Swift |
|---|---|---|---|
| 可变变量 | `var x = 1;` | `var x = 1` | `var x = 1` |
| 只能赋值一次（运行时确定） | `final x = now();` | `val x = now()` | `let x = now()` |
| 编译期常量 | `const x = 1;` | `const val x = 1` | — |
| 显式写类型 | `int x = 1;` | `val x: Int = 1` | `let x: Int = 1` |
| 延迟初始化 | `late String x;` | `lateinit var x` | `var x: String!` |
| 懒加载 | `late final x = calc();` | `by lazy { }` | `lazy var` |

和 Kotlin / Swift 不同的地方：

- **类型写在变量名前面**（像 Java）：`String name`。
- **一切皆对象**：`int` 也是对象；`int` 和 `double` 都是 `num` 的子类。
- **没有隐式类型转换**：`int` 要转成 `double` 需要调用 `.toDouble()`。
- **整除用 `~/`**：`7 / 2 == 3.5`，`7 ~/ 2 == 3`。
- **字符串插值**：`'Hi $name'`、`'${user.name}'`。单引号和双引号作用一样，**社区惯例是统一用单引号**。
- **`dynamic` 和 `Object?`**：`dynamic` 会关闭类型检查，尽量不用；需要表示"任意类型"时用 `Object?`。

**惯用写法**：局部变量用 `final` 或 `var` 让编译器推断类型；函数签名和字段才写明类型。

## 2. final 和 const ⭐

- `final`：**引用**只能赋值一次，指向的对象本身可以修改。
- `const`：**编译期**就确定，而且**深度不可变**。

```dart
final a = [1, 2];
a.add(3);              // ✅ 可以

const b = [1, 2];
b.add(3);              // 💥 运行时抛出 UnsupportedError

final c = const [1, 2];
c.add(3);              // 💥 能编译，但运行时报错：变量是 final，对象是 const

const now = DateTime.now();  // ❌ 编译错误：DateTime.now() 不是编译期常量
```

**规范化**：值相同的 const 对象全局只有一份。

```dart
identical(const [1], const [1]);  // true
identical([1], [1]);              // false
```

**这对 Flutter 的意义**：`const Text('Hello')` 在编译期就创建好，而且永远是同一个实例。重建界面时，Flutter 发现新旧 Widget 是同一个对象，就**直接跳过这部分的重建**。这是 Flutter 里最便宜的性能优化。

**怎么选**：能用 `const` 就用 `const` → 值要到运行时才知道就用 `final` → 确实需要修改才用 `var`。

## 3. 空安全

| 含义 | Dart | Kotlin | Swift |
|---|---|---|---|
| 可空类型 | `String?` | `String?` | `String?` |
| 安全调用 | `a?.length` | `a?.length` | `a?.count` |
| 默认值 | `a ?? 'x'` | `a ?: "x"` | `a ?? "x"` |
| 为 null 时才赋值 | `a ??= 'x';` | — | — |
| 强制解包 | `a!` | `a!!` | `a!` |
| 判空后自动转成非空类型 | `if (a != null) a.length` | 智能转换 | `if let` |
| 下标的安全访问 | `map?['k']`、`list?[0]` | — | — |

### 要点

**1. `Map` 取值永远返回可空类型**：`m['a']` 的类型是 `int?`，即使这个 key 一定存在。

**2. 自动类型提升只对局部变量和私有 final 字段（Dart 3.2+）生效**，公开字段不行，因为它可能在判空后被改掉，或者被子类用 getter 重写。

```dart
if (name != null) print(name.length);  // ❌ name 是公开字段
final n = name;
if (n != null) print(n.length);        // ✅ 先拷贝到局部变量
```

**3. 短路规则**：链式调用里第一个 `?.` 发现 null，**整条链后面的部分都不会执行**。所以后面不可空的部分不用再写 `?.`，写了 analyzer 还会报 `invalid_null_aware_operator` 的 warning。这一点和 Kotlin 不同：Kotlin 每一步都要写 `?.`。

```dart
user?.values.first      // ✅ 能走到 .values，说明 user 一定不是 null
user?.values?.first     // ⚠️ warning：第二个 ?. 是多余的
```

**4. 少用 `!`**：值为 null 时会直接崩溃。`!` 用得多往往说明数据模型设计得不太对。

## 4. 其他工具

- `=>`：函数体只有一个表达式时的简写，类似 Kotlin 的 `fun f() = ...`。
- `dart analyze dart_basics`：静态检查。
- `dart format dart_basics`：官方格式化工具，**只有一种官方格式**，几乎不能配置。建议在 Android Studio 开启 Settings → Languages & Frameworks → Flutter → Format code on save。

## 5. 练习回顾

### 预测题（4/4 ✅）

| 代码 | 答案 |
|---|---|
| `final list = const [1,2,3]; list.add(4);` | 能编译，运行时抛出 `UnsupportedError` |
| `const now = DateTime.now();` | 编译错误，`DateTime.now()` 不是编译期常量 |
| `int? n; n ??= 5; n ??= 10; print(n);` | `5` |
| `print(10 ~/ 3 + 10 / 4);` | `5.5`（`3` + `2.5`） |

### 编程题参考解法

```dart
String greet(String? name) =>
    (name == null || name.isEmpty) ? 'Hello, stranger!' : 'Hello, $name!';

int totalLength(List<String?> words) =>
    words.fold(0, (sum, w) => sum + (w?.length ?? 0));

int readInt(Map<String, String> config, String key, int defaultValue) =>
    int.tryParse(config[key] ?? '') ?? defaultValue;

String cityOf(Map<String, Map<String, String>?>? user) =>
    user?['address']?['city']?.toUpperCase() ?? 'UNKNOWN';
```

### 我犯过的错

- `readInt` 第一版先 `tryParse` 判断、再 `parse` 取值，**解析了两次**。`tryParse` 的返回值本身就能用。
- `cityOf` 第一版用 `values.firstOrNull` 取"第一个值"，而不是按 key 取值，**只是凑巧通过了测试**。Map 里有多个 key 时就会取错。
- 写法习惯：显式写 `String? value = ...`、`return` 之后还写 `else`，都是 Kotlin / Java 的习惯。Dart 更偏向 `final` 加类型推断、`=>` 表达式。
