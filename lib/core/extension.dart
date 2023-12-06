import 'dart:convert';
import 'dart:io';

extension DateTimeConvert on DateTime {
  double toMinutesSinceEpoch() {
    return millisecondsSinceEpoch / (60 * 1000);
  }

  int toSecondsSinceEpoch() {
    return (millisecondsSinceEpoch / 1000).floor();
  }
}

extension DoubleListUtil on List<double> {
  double sum() {
    if (isEmpty) return 0;
    return reduce((a, b) => a + b);
  }

  double average() {
    if (isEmpty) return 0;
    return sum() / length;
  }
}

extension DoubleIterableUtil on Iterable<double> {
  double sum() {
    if (isEmpty) return 0;
    return reduce((a, b) => a + b);
  }

  double average() {
    if (isEmpty) return 0;
    return sum() / length;
  }
}

extension HttpRequestUtil on HttpRequest {
  Future<List<int>> rawBody() async {
    return await expand((e) => e).toList();
  }

  Future<String> body({bool allowMalformed = true}) async {
    return utf8.decode(
      await expand((e) => e).toList(),
      allowMalformed: allowMalformed
    );
  }
}
