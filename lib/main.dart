import 'dart:convert';
import 'dart:math';

import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:smart_water_dashboard/core/database.dart';
import 'package:smart_water_dashboard/core/websocket.dart';


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

  @override
  void initState() {
    super.initState();
  }

  @override
  Widget build(BuildContext context) {

    return Scaffold(
      body: SafeArea(
        child: Row(
          children: [
            NavigationRail(
              selectedIndex: _selectedIndex,
              labelType: NavigationRailLabelType.all,
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
              child: IndexedStack(
                children: [

                ],
              ),
            )
          ],
        ),
      )
    );
  }
}

// LineChart(
//   LineChartData(
//     titlesData: FlTitlesData(
//       leftTitles: AxisTitles(
//         axisNameWidget: Text("Litre / Minute"),
//       ),
//       topTitles: AxisTitles(
//         axisNameWidget: Text("Time")
//       ),
//       bottomTitles: AxisTitles(
//         sideTitles: SideTitles(
//           interval: 1,
//           reservedSize: 200,
//           showTitles: true,
//           getTitlesWidget: (value, meta) {
//             DateTime t = DateTime.fromMillisecondsSinceEpoch(
//               value.toInt() * 60 * 1000,
//               isUtc: true
//             );
//             return SideTitleWidget(
//               child: RotatedBox(
//                 quarterTurns: 1,
//                 child: Text(
//                   "${t.hour.toString().padLeft(2, "0")}:${t.minute.toString().padLeft(2, "0")}",
//                   textAlign: TextAlign.start,
//                 )
//               ),
//               axisSide: meta.axisSide,
//               space: 10,
//             );
//           },
//         )
//       )
//     ),
//     minY: 0,
//     maxY: 500,
//     lineBarsData: [
//       LineChartBarData(
//         spots: [
//           FlSpot(28316245, 35.123),
//           FlSpot(28316246, 345.123),
//           FlSpot(28316247, 123.768),
//           FlSpot(28316248, 10.32),
//           FlSpot(28316249, 10.32),
//           FlSpot(28316250, 10.32),
//           FlSpot(28316251, 10.32),
//           FlSpot(28316252, 10.32),
//           FlSpot(28316253, 10.32),
//           FlSpot(28316254, 10.32),
//           FlSpot(28316255, 10.32),
//           FlSpot(28316256, 10.32),
//           FlSpot(28316257, 10.32),
//           FlSpot(28316258, 10.32),
//           FlSpot(28316259, 10.32),
//           FlSpot(28316260, 10.32),
//         ]
//       )
//     ]
//   )
// )