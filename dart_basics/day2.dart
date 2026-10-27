// 第一周 Day 2 练习：变量、空安全、final / const
// 运行：dart run dart_basics/day2.dart
// 把每个 TODO 补完，直到所有检查都显示 ✅

// 练习 1：打招呼
// name 为 null 或空字符串时返回 "Hello, stranger!"，否则返回 "Hello, <name>!"
String greet(String? name) =>
    (name == null || name.isEmpty) ? 'Hello, stranger!' : 'Hello, $name!';

// 练习 2：统计总长度
// 返回所有单词长度之和，null 当作长度 0
int totalLength(List<String?> words) =>
    words.fold(0, (sum, w) => sum + (w?.length ?? 0));

// 练习 3：读取配置
// 从 config 里取 key 对应的值并转成 int；
// key 不存在或值不是合法整数时返回 defaultValue
// 提示：int.tryParse 解析失败会返回 null
int readInt(Map<String, String> config, String key, int defaultValue) =>
    int.tryParse(config[key] ?? '') ?? defaultValue;

// 练习 4：取第一个用户的城市名（转大写）
// user 可能为 null，user['address'] 可能为 null，address['city'] 也可能为 null；
// 任意一层为 null 时返回 'UNKNOWN'。要求：只用一个表达式写完
String cityOf(Map<String, Map<String, String>?>? user) =>
    user?['address']?['city']?.toUpperCase() ?? 'UNKNOWN';

void main() {
  check('greet(null)', greet(null), 'Hello, stranger!');
  check('greet("")', greet(''), 'Hello, stranger!');
  check('greet("Flutter")', greet('Flutter'), 'Hello, Flutter!');

  check('totalLength', totalLength(['ab', null, 'cde']), 5);
  check('totalLength empty', totalLength([]), 0);

  final config = {'port': '8080', 'timeout': 'abc'};
  check('readInt port', readInt(config, 'port', 80), 8080);
  check('readInt bad value', readInt(config, 'timeout', 30), 30);
  check('readInt missing', readInt(config, 'retries', 3), 3);

  check('cityOf null', cityOf(null), 'UNKNOWN');
  check('cityOf no address', cityOf({}), 'UNKNOWN');
  check('cityOf no city', cityOf({'address': {}}), 'UNKNOWN');
  check(
    'cityOf ok',
    cityOf({
      'address': {'city': 'Shenzhen'},
    }),
    'SHENZHEN',
  );
  // Day 2 review 补充：Map 里有多个 key 时也要取对
  check(
    'cityOf multiple keys',
    cityOf({
      'profile': {'name': 'Tom'},
      'address': {'street': 'Keyuan Rd', 'city': 'Shenzhen'},
    }),
    'SHENZHEN',
  );
}

void check(String label, Object? actual, Object? expected) {
  final ok = actual == expected;
  print('${ok ? '✅' : '❌'} $label${ok ? '' : '  期望 $expected，实际 $actual'}');
}
