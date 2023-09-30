import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:smart_water_dashboard/core/websocket.dart';
import 'package:sqlite3/sqlite3.dart';


void main() async {
  await WebSocketServer.serve(
    "127.0.0.1", 5678,
  );
  final db = sqlite3.openInMemory();
  db.dispose();
  runApp(const MainApp());
}

class MainApp extends StatelessWidget {
  const MainApp({Key? key}) : super(key: key);
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Flutter Demo',
      theme: ThemeData(
        primarySwatch: Colors.blue,
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
  List<dynamic> l = [];

  @override
  void initState() {
    super.initState();
    WebSocketServer.instance.data.listen((event) {
      setState(() {
        l.add(event);
      });
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: ListView(
        children: l.map((e) {
          return Text(jsonEncode(e));
        }).toList(),
      )
    );
  }
}
