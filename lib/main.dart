import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:smart_water_dashboard/core/websocket.dart';
import 'native/ffi.dart';

void main() async {
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
  void initServer() async {
    var s = await WebSocketServer.serve(
      "127.0.0.1", 5678,
      (data) {
        WebSocketServer.instance.boardcast(
          jsonEncode(data)
        );
        print(data);
      },
      onError: (e) {
        print(e);
      }
    );
    print(s.isRunning);
  }

  @override
  void initState() {
    super.initState();
    initServer();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: <Widget>[
            const Text("You're running on"),
          ],
        ),
      ),
    );
  }
}
