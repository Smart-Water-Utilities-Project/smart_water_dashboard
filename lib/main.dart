import 'package:flutter/material.dart';
import 'package:smart_water_dashboard/core/database.dart';
import 'package:smart_water_dashboard/core/websocket.dart';
import 'package:smart_water_dashboard/page/data_chart.dart';
import 'package:smart_water_dashboard/page/server_log.dart';
import 'package:smart_water_dashboard/page/settings.dart';


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
                  icon: Icon(Icons.text_snippet_rounded),
                  label: Text("Server Log")
                ),
                NavigationRailDestination(
                  icon: Icon(Icons.settings_rounded),
                  label: Text("Settings")
                ),
              ],
            ),
            Expanded(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(20, 6, 40, 6),
                child: IndexedStack(
                  index: _selectedIndex,
                  children: const [
                    DataChartPage(),
                    ServerLogPage(),
                    SettingsPage()
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
