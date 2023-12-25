import "dart:async";

import "package:flutter/material.dart";

import "package:syncfusion_flutter_charts/charts.dart";

import "package:smart_water_dashboard/core/database.dart";
import "package:smart_water_dashboard/core/extension.dart";


class DataChartPage extends StatefulWidget {
  const DataChartPage({super.key});

  @override
  State<StatefulWidget> createState() => _DataChartPageState();
}

class _DataChartPageState extends State<DataChartPage> {
  double _chartEndAt = DateTime.now().toMinutesSinceEpoch();
  final List<(int, double)> _chartData = [];
  late Timer _updateTimer;

  @override
  void initState() {
    super.initState();
    _updateChart();
    _updateTimer = Timer.periodic(
      const Duration(seconds: 5),
      (t) {
        setState(() {
          _updateChart();
        });
      }
    );
  }

  @override
  void dispose() {
    _updateTimer.cancel();
    super.dispose();
  }

  void _updateChart() {
    List<WaterRecord> data = DatabaseHandler.instance.getRecord(_chartEndAt.floor() - 10, _chartEndAt.floor());

    _chartData.clear();

    for (int t = _chartEndAt.floor() - 10; t <= _chartEndAt; t += 1) {
      double avg = data.where((e) => e.timestamp == t).map((e) => e.waterFlow).average();
      _chartData.add((t, avg));
    }
    _chartEndAt = DateTime.now().toMinutesSinceEpoch();
  }
  
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SfCartesianChart(
        title: ChartTitle(
          text: "10 分鍾用水量"
        ),
        primaryXAxis: NumericAxis(
          labelRotation: 45,
          labelAlignment: LabelAlignment.end,
          axisLabelFormatter: (axisLabelRenderArgs) {
            DateTime time = DateTime.fromMillisecondsSinceEpoch((axisLabelRenderArgs.value * 60 * 1000).toInt());
            return ChartAxisLabel(
              "${time.hour.toString().padLeft(2, "0")}:${time.minute.toString().padLeft(2, "0")}",
              null
            );
          },
        ),
        primaryYAxis: NumericAxis(
          axisLabelFormatter: (axisLabelRenderArgs) {
            return ChartAxisLabel(
              "${axisLabelRenderArgs.value.toStringAsFixed(1)} L",
              null
            );
          },
        ),
        trackballBehavior: TrackballBehavior(
          activationMode: ActivationMode.singleTap
        ),
        series: [
          LineSeries(
            dataSource: _chartData,
            xValueMapper: (datum, index) {
              return datum.$1;
            },
            yValueMapper: (datum, index) {
              return datum.$2;
            },
          )
        ],
      ),
    );
  }
}
