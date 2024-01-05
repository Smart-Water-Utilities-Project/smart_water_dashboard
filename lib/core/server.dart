import "dart:async";
import "dart:collection";
import "dart:convert";
import "dart:io";

import "package:hive_flutter/adapters.dart";

import "package:smart_water_dashboard/core/cloud_messaging.dart";
import "package:smart_water_dashboard/core/database.dart";
import "package:smart_water_dashboard/core/extension.dart";

enum DeviceType {
  sensor,
  mobileApp,
  socketServer,
  unknown;

  static DeviceType fromString(String raw) {
    switch (raw) {
      case "sensor":
        {
          return DeviceType.sensor;
        }
      case "mobile_app":
        {
          return DeviceType.mobileApp;
        }
      case "socket_server":
        {
          return DeviceType.socketServer;
        }
      case _:
        {
          return DeviceType.unknown;
        }
    }
  }
}

class WebSocketClient {
  final int id;
  final WebSocket socket;
  DeviceType deviceType;

  WebSocketClient(
      {required this.id, required this.socket, required this.deviceType});
}

class WebSocketEvent {
  final int opCode;
  final dynamic data;
  final String? eventName;

  WebSocketEvent({required this.opCode, this.data, this.eventName});

  String toJson() {
    return jsonEncode({"op": opCode, "d": data, "t": eventName});
  }

  static WebSocketEvent fromJson(dynamic data) {
    return WebSocketEvent(
        opCode: data["op"], data: data["d"], eventName: data["t"]);
  }
}

class WebServer {
  WebServer._();

  static WebServer? _instance;

  final Box _sharedPrefs = Hive.box("sharedPrefs");

  late HttpServer _server;
  bool isRunning = false;
  final HashMap<int, WebSocketClient> _clients = HashMap();

  final List<double> _heartbeatBuffer = [];
  double _heartbeatStartAt = DateTime.now().toMinutesSinceEpoch();
  late Timer _heartbeatTimer;

  double _lastWaterTemp = -1;
  double _lastWaterDist = -1;

  int _waterLeakageCount = 0;

  late StreamController<dynamic> _dataController;
  StreamSink<dynamic> get _dataSink => _dataController.sink;
  late StreamController<dynamic> _errorController;
  StreamSink<dynamic> get _errorSink => _errorController.sink;
  static final StreamController<String> _logController =
      StreamController<String>();
  static StreamSink<String> get _logSink => _logController.sink;

  Stream<dynamic> get data => _dataController.stream;
  Stream<dynamic> get error => _errorController.stream;
  static Stream<String> get log => _logController.stream;

  static WebServer get instance {
    _instance ??= WebServer._();
    return _instance!;
  }

  double _calcHeartbeatValue(double now) {
    return (_heartbeatBuffer.average() / 60.0) * (now - _heartbeatStartAt);
  }

  Future<void> _waterDataHeartbeat() async {
    _heartbeatTimer = Timer.periodic(const Duration(seconds: 5), (t) async {
      if (_instance == null || !isRunning) {
        t.cancel();
      }

      List<WebSocketClient> sensors = _clients.values
          .where((e) => e.deviceType == DeviceType.sensor)
          .toList();

      sensors.forEach((client) {
        client.socket.add(WebSocketEvent(opCode: 3, data: {
          "wl": _sharedPrefs.get("waterDistTarget", defaultValue: 1.0)
        }).toJson());
      });

      if (sensors.isNotEmpty) {
        _logSink
            .add("Send heartbeat to ${sensors.map((e) => e.id).join(", ")}");
      }

      double now = DateTime.now().toMinutesSinceEpoch();

      if (now - _heartbeatStartAt >= 15 * 60 * 1000) {
        double heartbeatValue = _calcHeartbeatValue(now);

        DatabaseHandler.instance.insertWaterRecord(
            now.floor(), heartbeatValue, _lastWaterTemp, _lastWaterDist);

        _logSink.add(
            "Insert record: (${now.floor()}, $heartbeatValue, $_lastWaterTemp, $_lastWaterDist)");

        _logSink.add("Clear buffer for 15 min heartbeat");

        _heartbeatBuffer.clear();
        _heartbeatStartAt = now;

        _waterLeakageCount += 1;
      }

      if (_waterLeakageCount > 4 &&
          _sharedPrefs.get("waterLeakageNotify", defaultValue: true)) {
        if (now -
                    _sharedPrefs.get("lastWaterLeakageNotifyAt",
                        defaultValue: 0) >
                60 &&
            now - _sharedPrefs.get("lastPipeFreezeNotifyAt", defaultValue: 0) <
                60 * 24) {
          await CloudMessaging.send(
              FcmTopic.waterLeakage,
              const FcmNotification(
                  title: "Water Leakage Alert",
                  body:
                      "There appears to be a water leakage in your home, turn off the valve or take other actions."));

          await _sharedPrefs.put("lastWaterLeakageNotifyAt", now);
        }

        _waterLeakageCount = 0;
      }
    });
  }

  static Future<WebServer> serve(dynamic address, int port) async {
    if (_instance == null || !_instance!.isRunning) {
      _instance = WebServer._();
      _instance!._dataController = StreamController<dynamic>();
      _instance!._errorController = StreamController<dynamic>();

      await runZonedGuarded(() async {
        _instance!._server = await HttpServer.bind(address, port);
        _instance!._server.listen(_instance!._onRequest);
        _instance!.isRunning = true;
        _instance!._heartbeatBuffer.clear();
        _instance!._waterDataHeartbeat();

        _logSink.add("Socket server running on $address:$port");
      }, (Object e, StackTrace st) {
        _instance!._errorSink.add(e);

        _logSink.add("Socket server error: ${e.toString()}");
      });
    }
    return _instance!;
  }

  Future<void> close({bool force = false}) async {
    _logSink.add("Socket server closed");

    _dataController.close();
    _errorController.close();

    _clients.clear();
    _heartbeatBuffer.clear();
    _heartbeatTimer.cancel();
    _server.close(force: force);
    isRunning = false;
  }

  Future<bool> boardcast(WebSocketEvent event, DeviceType? deviceType) async {
    if (_instance == null || !isRunning) {
      return false;
    }

    List<WebSocketClient> boardcastTargets = _clients.values
        .where((e) => deviceType == null ? true : e.deviceType == deviceType)
        .toList();

    boardcastTargets.forEach((client) {
      client.socket.add(event.toJson());
    });

    _logSink.add(
        "Send boardcast to ${boardcastTargets.map((e) => e.id).join(", ")}");

    return true;
  }

  void _onRequest(HttpRequest request) async {
    switch (request.uri.path) {
      case "/ws":
        {
          _handleSocket(request);
        }
      case "/history":
        {
          _handleHistoryRequest(request);
        }
      case "/waterDistTarget":
        {
          _handleWaterDistTargetRequest(request);
        }
      case "/waterLimit":
        {
          _handleWaterLimitRequest(request);
        }
      case "/waterValve":
        {
          _handleValveRequest(request);
        }
      case "/notifySettings":
        {
          _handleNotifySettingsRequest(request);
        }
      default:
        {
          request.response.statusCode = 404;
          request.response.write(jsonEncode({"msg": "Not Found"}));
          request.response.close();
        }
    }

    _logSink.add(
        "Incoming request: ${request.method} ${request.protocolVersion} ${request.uri}");
  }

  void _handleSocket(HttpRequest request) async {
    WebSocket socket;

    if (request.headers.value("Connection")?.toLowerCase() != "upgrade") {
      request.response.statusCode = 426;
      request.response.write(jsonEncode(
          {"msg": "Upgrade to WebSocket is required for this endpoint"}));
      request.response.close();
    }

    try {
      socket = await WebSocketTransformer.upgrade(request);
    } catch (e) {
      _logSink.add("Invalid WebSocket upgrade request");

      return;
    }

    if (!_clients.containsKey(socket.hashCode)) {
      _clients[socket.hashCode] = WebSocketClient(
          id: socket.hashCode, socket: socket, deviceType: DeviceType.unknown);

      socket.add(
          WebSocketEvent(opCode: 1, data: {"id": socket.hashCode}).toJson());

      _logSink.add("Device connected: ${socket.hashCode}");
    }

    socket.listen((dynamic data) {
      if (data is List<int>) {
        try {
          data = utf8.decode(data);
        } on FormatException catch (_) {
          data = utf8.decode(data, allowMalformed: true);
        }
      }
      try {
        data = jsonDecode(data);
        _handleSocketEvent(socket.hashCode, data);
        _dataSink.add(data);
      } on Exception catch (_) {
        _dataSink.add(data);
      }
    });

    socket.done.then((value) {
      _clients.remove(socket.hashCode);

      _logSink.add("Device disconnected: ${socket.hashCode}");
    });
  }

  void _handleSocketEvent(int socketId, dynamic rawEvent) async {
    WebSocketEvent event = WebSocketEvent.fromJson(rawEvent);

    _logSink.add("Socket event incoming: $rawEvent");

    switch (event.opCode) {
      case 0:
        {
          _handleSocketDispatch(socketId, event);

          _logSink.add("Recivied dispatch: ($socketId, ${event.eventName})");
        }
      case 2:
        {
          _clients[socketId]!.deviceType =
              DeviceType.fromString(event.data["dt"]);

          _logSink.add(
              "Set device type: ($socketId, ${DeviceType.fromString(event.data["dt"])})");
        }
      case 4:
        {
          double now = DateTime.now().toMinutesSinceEpoch();

          _lastWaterTemp = event.data["wt"];
          _lastWaterDist = event.data["wd"];

          boardcast(
              WebSocketEvent(
                  opCode: 0,
                  data: event.data,
                  eventName: "SENSOR_DATA_FORWARD"),
              DeviceType.mobileApp);

          if (_heartbeatBuffer.isNotEmpty && event.data["wf"] == 0.0) {
            double heartbeatValue = _calcHeartbeatValue(now);

            DatabaseHandler.instance.insertWaterRecord(now.floor(),
                heartbeatValue, event.data["wt"], event.data["wd"]);

            _logSink.add(
                "Insert record: (${now.floor()}, $heartbeatValue, $_lastWaterTemp, $_lastWaterDist)");

            _heartbeatBuffer.clear();
            _heartbeatStartAt = now;
          }

          if (event.data["wf"] != 0.0) {
            if (_heartbeatBuffer.isEmpty) {
              _heartbeatStartAt = now;
            }
            _heartbeatBuffer.add(event.data["wf"]);
          }
        }
    }
  }

  void _handleSocketDispatch(int socketId, WebSocketEvent event) {
    switch (event.eventName) {}
  }

  void _handleHistoryRequest(HttpRequest request) {
    Map<String, String> params = request.uri.queryParameters;

    if (!params.keys.contains("start") || !params.keys.contains("end")) {
      request.response.statusCode = 400;
      request.response.write(jsonEncode({"msg": "Missing parameters"}));
      request.response.close();
      return;
    }

    List<WaterRecord> data = DatabaseHandler.instance
        .getRecord(int.parse(params["start"]!), int.parse(params["end"]!));
    dynamic encodedData = data
        .map((e) => {
              "t": e.timestamp,
              "wf": e.waterFlow,
              "wt": e.waterTemp,
              "wd": e.waterDist
            })
        .toList();

    request.response.write(jsonEncode(encodedData));
    request.response.close();
  }

  void _handleWaterDistTargetRequest(HttpRequest request) async {
    if (request.method == "GET") {
      request.response.write(jsonEncode(
          {"target": _sharedPrefs.get("waterDistTarget", defaultValue: 0.5)}));
      request.response.close();
      return;
    }

    if (request.method != "PUT") {
      request.response.statusCode = 405;
      request.response
          .write(jsonEncode({"msg": "This endpoint only support GET or PUT"}));
      request.response.close();
      return;
    }

    String body = await request.body();

    if (body.isEmpty) {
      request.response.statusCode = 400;
      request.response
          .write(jsonEncode({"msg": "Request body can't be empty"}));
      request.response.close();
      return;
    }

    dynamic jsonBody = jsonDecode(body);

    if (jsonBody case {"target": double target}) {
      request.response.statusCode = 204;

      await _sharedPrefs.put("waterDistTarget", target);

      request.response.close();
      return;
    }

    request.response.statusCode = 400;
    request.response.write(jsonEncode({"msg": "Body pattern error"}));
    request.response.close();
  }

  void _handleWaterLimitRequest(HttpRequest request) async {
    if (request.method == "GET") {
      request.response.write(jsonEncode({
        "daily_limit":
            _sharedPrefs.get("dailyWaterUsageLimit", defaultValue: -1),
        "monthly_limit":
            _sharedPrefs.get("monthlyWaterUsageLimit", defaultValue: -1)
      }));
      request.response.close();
      return;
    }

    if (request.method != "PUT") {
      request.response.statusCode = 405;
      request.response
          .write(jsonEncode({"msg": "This endpoint only support GET or PUT"}));
      request.response.close();
      return;
    }

    String body = await request.body();

    if (body.isEmpty) {
      request.response.statusCode = 204;

      request.response.close();
      return;
    }

    dynamic jsonBody = jsonDecode(body);

    await _sharedPrefs.put(
        "dailyWaterUsageLimit",
        jsonBody["daily_limit"] ??
            _sharedPrefs.get("dailyWaterUsageLimit", defaultValue: true));
    await _sharedPrefs.put(
        "monthlyWaterUsageLimit",
        jsonBody["monthly_limit"] ??
            _sharedPrefs.get("monthlyWaterUsageLimit", defaultValue: true));

    request.response.statusCode = 204;
    request.response.close();
  }

  void _handleValveRequest(HttpRequest request) async {
    if (request.method == "GET") {
      request.response.write(jsonEncode(
          {"status": _sharedPrefs.get("waterValve", defaultValue: false)}));

      request.response.close();
      return;
    }

    if (request.method != "PUT") {
      request.response.statusCode = 405;
      request.response
          .write(jsonEncode({"msg": "This endpoint only support GET or PUT"}));
      request.response.close();
      return;
    }

    String body = await request.body();

    if (body.isEmpty) {
      request.response.statusCode = 400;
      request.response
          .write(jsonEncode({"msg": "Request body can't be empty"}));
      request.response.close();
      return;
    }

    dynamic jsonBody = jsonDecode(body);

    if (jsonBody case {"status": bool status}) {
      request.response.statusCode = 204;

      await _sharedPrefs.put("waterValve", status);

      request.response.close();

      _clients.forEach((uid, client) {
        client.socket.add(WebSocketEvent(opCode: 0, data: {
          "status": _sharedPrefs.get("waterValve", defaultValue: true)
        }).toJson());
      });

      return;
    }

    request.response.statusCode = 400;
    request.response.write(jsonEncode({"msg": "Body pattern error"}));
    request.response.close();
  }

  void _handleNotifySettingsRequest(HttpRequest request) async {
    if (request.method == "GET") {
      request.response.write(jsonEncode({
        "pipe_freeze": _sharedPrefs.get("pipeFreezeNotify", defaultValue: true),
        "water_leakage":
            _sharedPrefs.get("waterLeakageNotify", defaultValue: true),
        "water_usage_limit":
            _sharedPrefs.get("waterUsageLimitNotify", defaultValue: true),
      }));

      request.response.close();
      return;
    }

    if (request.method != "PUT") {
      request.response.statusCode = 405;
      request.response
          .write(jsonEncode({"msg": "This endpoint only support GET or PUT"}));
      request.response.close();
      return;
    }

    String body = await request.body();

    if (body.isEmpty) {
      request.response.statusCode = 204;

      request.response.close();
      return;
    }

    dynamic jsonBody = jsonDecode(body);

    await _sharedPrefs.put(
        "pipeFreezeNotify",
        jsonBody["pipe_freeze"] ??
            _sharedPrefs.get("pipeFreezeNotify", defaultValue: true));
    await _sharedPrefs.put(
        "waterLeakageNotify",
        jsonBody["water_leakage"] ??
            _sharedPrefs.get("waterLeakageNotify", defaultValue: true));
    await _sharedPrefs.put(
        "waterUsageLimitNotify",
        jsonBody["water_usage_limit"] ??
            _sharedPrefs.get("waterUsageLimitNotify", defaultValue: true));

    request.response.statusCode = 204;
    request.response.close();
  }
}
