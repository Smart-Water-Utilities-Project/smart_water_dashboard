import 'dart:async';
import 'dart:collection';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:smart_water_dashboard/core/database.dart';
import 'package:smart_water_dashboard/core/extension.dart';


enum DeviceType {
  sensor,
  mobileApp,
  socketServer,
  unknown;

  static DeviceType fromString(String raw) {
    switch (raw) {
      case "sensor": {
        return DeviceType.sensor;
      }
      case "mobile_app": {
        return DeviceType.mobileApp;
      }
      case "socket_server": {
        return DeviceType.socketServer;
      }
      case _: {
        return DeviceType.unknown;
      }
    }
  }
}

class WebSocketClient {
  final int id;
  final WebSocket socket;
  DeviceType deviceType;

  WebSocketClient({required this.id, required this.socket, required this.deviceType});
}

class WebSocketEvent {
  final int opCode;
  final dynamic data;
  final String? eventName;

  WebSocketEvent({required this.opCode, this.data, this.eventName});

  String toJson() {
    return jsonEncode(
      {
        "op": opCode,
        "d": data,
        "t": eventName
      }
    );
  }

  static WebSocketEvent fromJson(dynamic data) {
    return WebSocketEvent(
      opCode: data["op"],
      data: data["d"],
      eventName: data["t"]
    );
  }
}

class WebSocketServer {
  WebSocketServer._();

  static WebSocketServer? _instance;

  late HttpServer _server;
  bool isRunning = false;
  final HashMap<int, WebSocketClient> _clients = HashMap();

  final List<double> _heartbeatBuffer = [];
  int _heartbeatStartAt = DateTime.now().millisecondsSinceEpoch;

  late StreamController<dynamic> _dataController;
  StreamSink<dynamic> get _dataSink => _dataController.sink;
  late StreamController<dynamic> _errorController;
  StreamSink<dynamic> get _errorSink => _errorController.sink;

  Stream<dynamic> get data => _dataController.stream;
  Stream<dynamic> get error => _errorController.stream;

  static WebSocketServer get instance {
    if (_instance == null) {
      _instance = WebSocketServer._();
      _instance!.isRunning = false;
      _instance!._heartbeatBuffer.clear();
    }
    return _instance!;
  }

  double _calcHeartbeatValue(int now) {
    return (_instance!._heartbeatBuffer.average() / 60.0) * ((now - _heartbeatStartAt) / 60000);
  }

  Future<void> _waterDataHeartbeat() async {
    Timer.periodic(
      const Duration(seconds: 5),
      (t) {
        if (_instance == null || !_instance!.isRunning) {
          t.cancel();
        }

        _instance!._clients.values.where(
          (e) => e.deviceType == DeviceType.sensor
        ).forEach(
          (client) {
            client.socket.add(
              WebSocketEvent(
                opCode: 3
              ).toJson()
            );
          }
        );

        debugPrint("Send heartbeat to ${_instance!._clients.length} device(s)");

        int now = DateTime.now().millisecondsSinceEpoch;

        if (now - _heartbeatStartAt >= 15 * 60 * 1000) {
          if (_instance!._heartbeatBuffer.isNotEmpty) {
            DatabaseHandler.instance.insertWaterRecord(
              WaterRecord(
                now.floor(),
                _calcHeartbeatValue(now),
                0
              )
            );

            debugPrint("Insert record: (${now.floor()}, ${_calcHeartbeatValue(now)}, 0)");
          }

          debugPrint("Clear buffer for 15 min heartbeat");

          _instance!._heartbeatBuffer.clear();
          _heartbeatStartAt = now;
        }
      }
    );
  }

  static Future<WebSocketServer> serve(dynamic address, int port) async {
    if (_instance == null || !_instance!.isRunning) {
      _instance = WebSocketServer._();
      _instance!._dataController = StreamController<dynamic>();
      _instance!._errorController = StreamController<dynamic>();
      await runZonedGuarded(
        () async {
          _instance!._server = await HttpServer.bind(address, port);
          _instance!._server.transform(WebSocketTransformer()).listen(_instance!._onRequest);
          _instance!.isRunning = true;
          _instance!._heartbeatBuffer.clear();
          _instance!._waterDataHeartbeat();

          debugPrint("Socket server running on $address:$port");
        },
        (Object e, StackTrace st) {
          _instance!._errorSink.add(e);

          debugPrint("Socket server error: ${e.toString()}");
        }
      );
    }
    return _instance!;
  }

  Future<void> close({bool force = false}) async {
    _dataController.close();
    _errorController.close();
    _instance!._clients.clear();
    _instance!._heartbeatBuffer.clear();
    _instance!._server.close(force: force);
    _instance!.isRunning = false;

    debugPrint("Socket server closed");
  }

  Future<bool> boardcast(dynamic data) async {
    if (_instance == null || !_instance!.isRunning) {
      return false;
    }

    for (WebSocketClient client in _clients.values) {
      client.socket.add(data);
    }

    return true;
  }

  void _handleEvent(int socketId, dynamic rawEvent) async {
    WebSocketEvent event = WebSocketEvent.fromJson(rawEvent);

    debugPrint("Socket event incoming: $rawEvent");

    switch (event.opCode) {
      case 2: {
        _clients[socketId]!.deviceType = DeviceType.fromString(event.data["dt"]);

        debugPrint("Set device type: ($socketId, ${DeviceType.fromString(event.data["dt"])})");
      }
      case 4: {
        int now = DateTime.now().millisecondsSinceEpoch;

        if (_instance!._heartbeatBuffer.isNotEmpty && event.data["wf"] == 0.0) {
          DatabaseHandler.instance.insertWaterRecord(
            WaterRecord(
              now.floor(),
              _calcHeartbeatValue(now),
              0
            )
          );

          debugPrint((now).toString());
          debugPrint((_heartbeatStartAt).toString());
          debugPrint("Insert record: (${now.floor()}, ${_calcHeartbeatValue(now)}, 0)");

          _instance!._heartbeatBuffer.clear();
          _heartbeatStartAt = now;
        }

        if (event.data["wf"] != 0.0) {
          if (_instance!._heartbeatBuffer.isEmpty) {
            _heartbeatStartAt = now;
          }
          _instance!._heartbeatBuffer.add(event.data["wf"]);
        }
      }
    }
  }

  void _onRequest(WebSocket socket) async {
    if (!_clients.containsKey(socket.hashCode)) {
      debugPrint("New device connected: ${socket.hashCode}");

      _clients[socket.hashCode] = WebSocketClient(
        id: socket.hashCode,
        socket: socket,
        deviceType: DeviceType.unknown
      );

      socket.add(
        WebSocketEvent(
          opCode: 1,
          data: {
            "id": socket.hashCode
          }
        ).toJson()
      );

      debugPrint("Send `Hello` to ${socket.hashCode}");
    }

    socket.listen(
      (dynamic data) {
        if (data is List<int>) {
          try {
            data = utf8.decode(data);
          } on FormatException catch (_) {
            data = utf8.decode(data, allowMalformed: true);
          }
        }
        try {
          data = jsonDecode(data);
          _handleEvent(socket.hashCode, data);
          _dataSink.add(data);
        } on Exception catch (_) {
          _dataSink.add(data);
        }
      }
    );
  }
}
