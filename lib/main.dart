import 'dart:async';
import 'dart:convert';
import 'dart:math';

import 'package:flutter/material.dart';
import 'package:smart_water_dashboard/core/database.dart';
import 'package:smart_water_dashboard/core/extension.dart';
import 'package:smart_water_dashboard/core/websocket.dart';
import 'package:syncfusion_flutter_charts/charts.dart';
import 'package:syncfusion_flutter_charts/sparkcharts.dart';


void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await WebSocketServer.serve(
    "127.0.0.1", 5678,
  );
  await DatabaseHandler.init();
  runApp(const MainApp());
}

class MainApp extends StatelessWidget {
  const MainApp({Key? key}) : super(key: key);
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Smart Water Dashboard',
      theme: ThemeData(
        useMaterial3: true,
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFF5266FF)
        )
      ),
      debugShowCheckedModeBanner: false,
      home: const HomePage(),
    );
  }
}

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  int _selectedIndex = 0;
  int _chartEndAt = DateTime.now().millisecondsSinceEpoch;
  List<(int, double)> _chartData = [];

  @override
  void initState() {
    super.initState();
    updateChart();
    Timer.periodic(
      Duration(seconds: 30),
      (t) {
        int now = DateTime.now().millisecondsSinceEpoch;

        if (now - _chartEndAt > 60 * 1000) {
          updateChart();

          setState(() {});
        }
      }
    );
  }

  void updateChart() {
    List<WaterRecord> data = DatabaseHandler.instance.getRecord(_chartEndAt, _chartEndAt + (10 * 60 * 1000));
    _chartData.clear();
    for (int t = _chartEndAt - (10 * 60 * 1000); t <= _chartEndAt; t += 60 * 1000) {
      double waterValue = data.where((e) => t <= e.timestamp && e.timestamp < t + 60 * 1000).map((e) => e.waterFlow).sum();
      _chartData.add((t, waterValue));
    }
  }

  @override
  Widget build(BuildContext context) {

    return Scaffold(
      body: SafeArea(
        child: Row(
          children: [
            NavigationRail(
              elevation: 10.0,
              selectedIndex: _selectedIndex,
              labelType: NavigationRailLabelType.selected,
              groupAlignment: 0.0,
              leading: ClipRRect(
                borderRadius: BorderRadius.circular(10),
                child: Image.asset(
                  "assets/smart_water_icon.png",
                  width: 56,
                  height: 56,
                ),
              ),
              onDestinationSelected: (value) {
                setState(() {
                  _selectedIndex = value;
                });
              },
              destinations: const [
                NavigationRailDestination(
                  icon: Icon(Icons.home_rounded),
                  label: Text("Overview")
                ),
                NavigationRailDestination(
                  icon: Icon(Icons.settings_rounded),
                  label: Text("Settings")
                ),
              ],
            ),
            Expanded(
              child: Padding(
                padding: EdgeInsets.symmetric(horizontal: 8),
                child: IndexedStack(
                  index: _selectedIndex,
                  children: [
                    SfCartesianChart(
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
                    Center(child: Text("Settings"),)
                  ],
                ),
              )
            )
          ],
        ),
      )
    );
  }
}

