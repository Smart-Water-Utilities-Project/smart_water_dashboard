import "dart:convert";
import "dart:io";

import "package:flutter/material.dart";


extension DateTimeConvert on DateTime {
  double toMinutesSinceEpoch() {
    return millisecondsSinceEpoch / (60 * 1000);
  }

  int toSecondsSinceEpoch() {
    return (millisecondsSinceEpoch / 1000).floor();
  }

  DateTime applied(TimeOfDay time) {
    return DateTime(year, month, day, time.hour, time.minute);
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
  Future<String> body({bool allowMalformed = true}) async {
    return utf8.decode(
      await expand((e) => e).toList(),
      allowMalformed: allowMalformed
    );
  }
}

extension HttpClientResponseUtil on HttpClientResponse {
  Future<String> body({bool allowMalformed = true}) async {
    return utf8.decode(
      await expand((e) => e).toList(),
      allowMalformed: allowMalformed
    );
  }
}
