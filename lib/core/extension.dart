extension DateTimeConvert on DateTime {
  int toMinutesSinceEpoch() {
    return (millisecondsSinceEpoch / (60 * 1000)).floor();
  }

  int toSecondsSinceEpoch() {
    return (millisecondsSinceEpoch / 1000).floor();
  }
}

extension DoubleListUtil on List<double> {
  double sum() {
    if (length < 0) return 0;
    return reduce((a, b) => a + b);
  }

  double average() {
    if (length < 0) return 0;
    return reduce((a, b) => a + b) / length;
  }
}
