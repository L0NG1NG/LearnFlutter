import 'dart:math';

// 第一周 Day 4 练习：集合、records、sealed + 模式匹配
// 运行：dart run --enable-asserts dart_basics/day4.dart
// 练习 1~3 的签名已经给好，把 throw UnimplementedError() 换成你的实现。
// 练习 4~5 的类要你自己写；写完后把 main() 里对应那段检查取消注释。
// 今天的额外要求：
//   - 每个值只算一次（Day 2、Day 3 都栽在「解析两次」上）
//   - 能用表达式就别用 if/else + 临时变量（collection if/for、switch 表达式、模式）

// ───────── 练习 1：集合字面量 ─────────
// 返回菜单项，顺序如下：
//   'Home'
//   已登录 → 'Profile'，未登录 → 'Login'
//   badge 不为 null 时放 badge
//   extras 里的每一项转成大写
//   'About'
// 要求：函数体只有一个 return 一个 List 字面量，不许调用 add / addAll。
List<String> buildMenu({
  required bool loggedIn,
  String? badge,
  List<String> extras = const [],
}) => [
  'Home',
  if (loggedIn) 'Profile' else 'Login',
  ?badge,
  ...extras.map((e) => e.toUpperCase()),
  'About',
];

// ───────── 练习 2：函数式操作 ─────────
typedef Score = ({String name, int score});

// 按分数从高到低排，取前 n 个人的名字。不能改动传进来的 rows！
List<String> topNames(List<Score> rows, int n) =>
    ([...rows]..sort((a, b) => b.score.compareTo(a.score)))
        .take(n)
        .map((s) => s.name)
        .toList();

// 统计词频：忽略大小写，按任意空白切分，忽略空串。
// 'a b  A' => {a: 2, b: 1}（key 按第一次出现的顺序）
Map<String, int> wordCount(String text) => text
    .toLowerCase()
    .trim()
    .split(RegExp(r'\s+'))
    .where((word) => word.isNotEmpty)
    .fold(<String, int>{}, (map, word) {
      map[word] = map.putIfAbsent(word, () => 0) + 1;
      return map;
    });

// 平均值，空集合返回 null
double? average(Iterable<int> xs) {
  final result = xs.fold((
    sum: 0,
    count: 0,
  ), (acc, x) => (sum: acc.sum + x, count: acc.count + 1));

  return result.count == 0 ? null : result.sum / result.count;
}

// ───────── 练习 3：records + 模式 ─────────
// 返回 (最小值, 最大值)，空列表返回 null。只遍历一遍。
(int, int)? minMax(List<int> xs) {
  if (xs.isEmpty) return null;
  var min = xs.first;
  var max = xs.first;
  for (final x in xs) {
    if (x < min) min = x;
    if (x > max) max = x;
  }
  return (min, max);
}

// '31.23, 121.47' => (lat: 31.23, lng: 121.47)
// 不是两段、某段不是数字、|lat| > 90、|lng| > 180 都返回 null
// 提示：if (表达式 case 模式 when 条件) 可以一口气完成「解构 + 判空 + 校验」
({double lat, double lng})? parseLatLng(String s) {
  if (s.split(',').map(double.tryParse).toList() case [double lat, double lng]
      when lat.abs() <= 90 && lng.abs() <= 180) {
    return (lat: lat, lng: lng);
  }
  return null;
}

// ───────── 练习 4：sealed class + switch 表达式 ─────────
// sealed class Shape，两个子类：
//   Circle(double radius)
//   Rect(double width, double height)
// double area(Shape s)：圆 pi*r*r，矩形 w*h（pi 来自 dart:math）
// String describe(Shape s)：
//   半径为 0 的圆 => 'point'
//   其它圆        => 'circle r=2.0'
//   宽高相等的矩形 => 'square 3.0'
//   其它矩形      => 'rect 2.0x3.0'
// 两个函数都只能写一个 switch 表达式，不写 default / _
// 写完后试试：再加一个 class Triangle extends Shape，看看编译器怎么说，然后删掉

sealed class Shape {}

class Circle extends Shape {
  final double radius;
  Circle(this.radius);
}

class Rect extends Shape {
  final double width;
  final double height;
  Rect(this.width, this.height);
}

double area(Shape s) => switch (s) {
  Circle(:final radius) => pi * radius * radius,
  Rect(:final width, :final height) => width * height,
};

String describe(Shape s) => switch (s) {
  Circle(radius: 0) => 'point',
  Circle(:final radius) => 'circle r=$radius',
  Rect(:final width, :final height) when width == height => 'square $width',
  Rect(:final width, :final height) => 'rect ${width}x$height',
};

// ───────── 练习 5：给页面状态建模 + 解析 JSON ─────────
// （第 4 周做主线项目的「加载 / 空 / 错误」三态时，就是这个写法）
// sealed class LoadState，三个子类：
//   Loading()
//   Loaded(List<String> items)
//   Failed(String message, {int? code})
// String render(LoadState s)：
//   Loading                => 'loading...'
//   Loaded 且 items 为空    => 'empty'
//   Loaded                 => '2 items: a, b'
//   Failed 且 code 是 401   => 'please login'
//   其它 Failed            => 'error: timeout'
//
// String? userCity(Object? json)：
//   json 形如 {'user': {'address': {'city': 'Shanghai'}}} 时返回城市名，
//   任意一层缺失、或者类型不对（比如 city 是数字、json 是 List）都返回 null。
//   要求：只用一个 map 模式，不写任何 `is` / `as` / `[]`

sealed class LoadState {}

class Loading extends LoadState {}

class Loaded extends LoadState {
  final List<String> items;
  Loaded(this.items);
}

class Failed extends LoadState {
  final String message;
  final int? code;
  Failed(this.message, {this.code});
}

String render(LoadState s) => switch (s) {
  Loading() => 'loading...',
  Loaded(:final items) when items.isEmpty => 'empty',
  Loaded(:final items) => '${items.length} items: ${items.join(', ')}',
  Failed(code: 401) => 'please login',
  Failed(:final message) => 'error: $message',
};

String? userCity(Object? json) => switch (json) {
  {'user': {'address': {'city': String city}}} => city,
  _ => null,
};

void main() {
  // ── 练习 1 ──
  check(
    'menu 未登录',
    () => buildMenu(loggedIn: false).join(','),
    'Home,Login,About',
  );
  check(
    'menu 已登录',
    () => buildMenu(
      loggedIn: true,
      badge: 'VIP',
      extras: ['faq', 'shop'],
    ).join(','),
    'Home,Profile,VIP,FAQ,SHOP,About',
  );

  // ── 练习 2 ──
  final rows = <Score>[
    (name: 'Amy', score: 80),
    (name: 'Bob', score: 95),
    (name: 'Cat', score: 60),
  ];
  check('topNames', () => topNames(rows, 2).join(','), 'Bob,Amy');
  check('topNames n 过大', () => topNames(rows, 10).length, 3);
  check('topNames 没改原列表', () => rows.first.name, 'Amy');
  check(
    'wordCount',
    () => wordCount(' a b  A\nb\tc ').toString(),
    '{a: 2, b: 2, c: 1}',
  );
  check('wordCount 空串', () => wordCount('   ').isEmpty, true);
  check('average', () => average([1, 2, 3, 4]), 2.5);
  check('average 空', () => average([]), null);
  check('average Set', () => average({10, 20}), 15.0);

  // ── 练习 3 ──
  check('minMax', () => minMax([3, 1, 4, 1, 5]), (1, 5)); // records 自带结构相等
  check('minMax 单个', () => minMax([7]), (7, 7));
  check('minMax 空', () => minMax([]), null);
  check('parseLatLng', () => parseLatLng('31.23, 121.47'), (
    lat: 31.23,
    lng: 121.47,
  ));
  check('parseLatLng 负数', () => parseLatLng('-33.9,151.2')?.lat, -33.9);
  check('parseLatLng 一段', () => parseLatLng('31.23'), null);
  check('parseLatLng 三段', () => parseLatLng('1,2,3'), null);
  check('parseLatLng 非数字', () => parseLatLng('x, 1'), null);
  check('parseLatLng 越界', () => parseLatLng('91, 0'), null);

  // ── 练习 4 ──
  check('area 圆', () => area(Circle(1)).toStringAsFixed(4), '3.1416');
  check('area 矩形', () => area(Rect(2, 3)), 6.0);
  check('describe point', () => describe(Circle(0)), 'point');
  check('describe circle', () => describe(Circle(2)), 'circle r=2.0');
  check('describe square', () => describe(Rect(3, 3)), 'square 3.0');
  check('describe rect', () => describe(Rect(2, 3)), 'rect 2.0x3.0');

  // ── 练习 5 ──
  check('render loading', () => render(Loading()), 'loading...');
  check('render empty', () => render(Loaded([])), 'empty');
  check('render items', () => render(Loaded(['a', 'b'])), '2 items: a, b');
  check(
    'render 401',
    () => render(Failed('unauthorized', code: 401)),
    'please login',
  );
  check('render error', () => render(Failed('timeout')), 'error: timeout');
  check('render 500', () => render(Failed('oops', code: 500)), 'error: oops');
  final json = {
    'user': {
      'name': 'Tom',
      'address': {'city': 'Shanghai', 'zip': '200000'},
    },
  };
  check('userCity', () => userCity(json), 'Shanghai');
  check(
    'userCity 缺 address',
    () => userCity({
      'user': {'name': 'Tom'},
    }),
    null,
  );
  check(
    'userCity city 是数字',
    () => userCity({
      'user': {
        'address': {'city': 1},
      },
    }),
    null,
  );
  check('userCity 是 List', () => userCity([json]), null);
  check('userCity null', () => userCity(null), null);
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
