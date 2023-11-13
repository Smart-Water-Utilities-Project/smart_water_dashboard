import 'dart:async';
import 'dart:collection';
import 'dart:convert';
import 'dart:io';

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
  double _heartbeatStartAt = DateTime.now().toMinutesSinceEpoch();
  late Timer _heartbeatTimer;

  late StreamController<dynamic> _dataController;
  StreamSink<dynamic> get _dataSink => _dataController.sink;
  late StreamController<dynamic> _errorController;
  StreamSink<dynamic> get _errorSink => _errorController.sink;
  static final StreamController<String> _logController = StreamController<String>();
  static StreamSink<String> get _logSink => _logController.sink;

  Stream<dynamic> get data => _dataController.stream;
  Stream<dynamic> get error => _errorController.stream;
  static Stream<String> get log => _logController.stream;

  static WebSocketServer get instance {
    if (_instance == null) {
      _instance = WebSocketServer._();
      _instance!.isRunning = false;
      _instance!._heartbeatBuffer.clear();
    }
    return _instance!;
  }

  double _calcHeartbeatValue(double now) {
    return (_instance!._heartbeatBuffer.average() / 60.0) * (now - _heartbeatStartAt);
  }

  Future<void> _waterDataHeartbeat() async {
    _heartbeatTimer = Timer.periodic(
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

            _logSink.add("Send heartbeat to ${client.id}");
          }
        );

        double now = DateTime.now().toMinutesSinceEpoch();

        if (now - _heartbeatStartAt >= 15 * 60 * 1000) {
          if (_instance!._heartbeatBuffer.isNotEmpty) {
            DatabaseHandler.instance.insertWaterRecord(
                now.floor(),
                _calcHeartbeatValue(now),
                0
            );

            _logSink.add("Insert record: (${now.floor()}, ${_calcHeartbeatValue(now)}, 0)");
          }

          _logSink.add("Clear buffer for 15 min heartbeat");

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

          _logSink.add("Socket server running on $address:$port");
        },
        (Object e, StackTrace st) {
          _instance!._errorSink.add(e);

          _logSink.add("Socket server error: ${e.toString()}");
        }
      );
    }
    return _instance!;
  }

  Future<void> close({bool force = false}) async {
    _logSink.add("Socket server closed");

    _dataController.close();
    _errorController.close();

    _instance!._clients.clear();
    _instance!._heartbeatBuffer.clear();
    _heartbeatTimer.cancel();
    _instance!._server.close(force: force);
    _instance!.isRunning = false;
  }

  Future<bool> boardcast(WebSocketEvent event, DeviceType? deviceType) async {
    if (_instance == null || !_instance!.isRunning) {
      return false;
    }

    if (deviceType == null) {
      _clients.values.forEach(
        (client) {
          client.socket.add(
            event.toJson()
          );

          _logSink.add("Send boardcast to ${client.id}");
        }
      );
    } else {
      _clients.values.where(
        (e) => e.deviceType == deviceType
      ).forEach(
        (client) {
          client.socket.add(
            event.toJson()
          );

          _logSink.add("Send boardcast to ${client.id}");
        }
      );
    }

    return true;
  }

  void _handleEvent(int socketId, dynamic rawEvent) async {
    WebSocketEvent event = WebSocketEvent.fromJson(rawEvent);

    _logSink.add("Socket event incoming: $rawEvent");

    switch (event.opCode) {
      case 0: {
        _handleDispatch(socketId, event);

        _logSink.add("Recivied dispatch: ($socketId, ${event.eventName})");
      }
      case 2: {
        _clients[socketId]!.deviceType = DeviceType.fromString(event.data["dt"]);

        _logSink.add("Set device type: ($socketId, ${DeviceType.fromString(event.data["dt"])})");
      }
      case 4: {
        double now = DateTime.now().toMinutesSinceEpoch();

        _instance!.boardcast(
          WebSocketEvent(
            opCode: 0,
            data: event.data,
            eventName: "SENSOR_DATA_FORWARD"
          ),
          DeviceType.mobileApp
        );

        if (_instance!._heartbeatBuffer.isNotEmpty && event.data["wf"] == 0.0) {
          DatabaseHandler.instance.insertWaterRecord(
              now.floor(),
              _calcHeartbeatValue(now),
              0
          );

          _logSink.add("Insert record: (${now.floor()}, ${_calcHeartbeatValue(now)}, 0)");

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

  void _handleDispatch(int socketId, WebSocketEvent event) {
    switch (event.eventName) {
      case "REQUEST_HISTORY_DATA": {
        List<WaterRecord> data = DatabaseHandler.instance.getRecord(event.data["s"], event.data["e"]);
        dynamic encodedData = data.map(
          (e) => {"t": e.timestamp, "wf": e.waterFlow, "wt": e.waterTemp}
        ).toList();

        _clients[socketId]?.socket.add(
          WebSocketEvent(
            opCode: 0,
            data: encodedData,
            eventName: "REQUEST_HISTORY_DATA_ACK"
          ).toJson()
        );
      }
    }
  }

  void _onRequest(WebSocket socket) async {
    if (!_clients.containsKey(socket.hashCode)) {
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

      _logSink.add("Device connected: ${socket.hashCode}");
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

    socket.done.then(
      (value) {
        _clients.remove(socket.hashCode);

        _logSink.add("Device disconnected: ${socket.hashCode}");
      }
    );
  }
}
