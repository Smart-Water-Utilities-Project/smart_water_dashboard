import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:smart_water_dashboard/core/websocket.dart';

class ServerLogPage extends StatefulWidget {
  const ServerLogPage({super.key});

  @override
  State<StatefulWidget> createState() => _ServerLogPageState();
}

class _ServerLogPageState extends State<ServerLogPage> {
  final List<String> _logging = [];

  @override
  void initState() {
    super.initState();

  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: StreamBuilder(
        stream: WebSocketServer.log,
        builder: (context, snapshot) {
          if (!snapshot.hasData) {
            return const Center(child: CircularProgressIndicator(),);
          }

          _logging.add("[${DateTime.now().toIso8601String()}] ${snapshot.data!}");

          return ListView(
            reverse: true,
            children: _logging.reversed.map(
              (e) => Text(
                e,
                style: TextStyle(
                  fontFamily: Platform.isIOS || Platform.isMacOS ? "Courier" : "monospace"
                ),
              )
            ).toList(),
          );
        },
      ),
    );
  }
}
