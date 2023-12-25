import "dart:io";

import "package:flutter/material.dart";

import "package:smart_water_dashboard/core/cloud_messaging.dart";
import "package:smart_water_dashboard/core/server.dart";


class EventLogPage extends StatefulWidget {
  const EventLogPage({super.key});

  @override
  State<StatefulWidget> createState() => _EventLogPageState();
}

class _EventLogPageState extends State<EventLogPage> {
  final List<String> _logging = [];
  String _previousLog = "";
  int _duplicateCount = 0;

  String _getFontFamily() {
    if (Platform.isIOS || Platform.isMacOS) {
      return "Courier New";
    } else if (Platform.isWindows) {
      return "Cascadia Mono";
    }
    return "monospace";
  }

  @override
  void initState() {
    super.initState();
    WebServer.log.listen(
      (event) {
        String timestamp = DateTime.now().toIso8601String().substring(0, 19).replaceAll("T", " ");

        if (event == _previousLog) {
          _duplicateCount += 1;
          _logging.removeLast();
          _logging.add("[$timestamp] [WebServer] (${_duplicateCount + 1}) $event");
        } else {
          _duplicateCount = 0;
          _logging.add("[$timestamp] [WebServer] $event");
          _previousLog = event;
        }

        setState(() {});
      },
      cancelOnError: false
    );

    CloudMessaging.log.listen(
      (event) {
        String timestamp = DateTime.now().toIso8601String().substring(0, 19).replaceAll("T", " ");

        if (event == _previousLog) {
          _duplicateCount += 1;
          _logging.removeLast();
          _logging.add("[$timestamp] [CloudMessaging] (${_duplicateCount + 1}) $event");
        } else {
          _duplicateCount = 0;
          _logging.add("[$timestamp] [CloudMessaging] $event");
          _previousLog = event;
        }

        setState(() {});
      },
      cancelOnError: false
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: ListView(
        reverse: true,
        children: _logging.reversed.map(
          (e) => Text(
            e,
            style: TextStyle(
              fontFamily: _getFontFamily(),
              fontSize: 14,
              fontWeight: FontWeight.w500
            ),
          )
        ).toList(),
      ),
    );
  }
}
