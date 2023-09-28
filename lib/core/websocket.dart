import 'dart:async';
import 'dart:convert';
import 'dart:io';

class WebSocketServer {
  WebSocketServer._();

  static WebSocketServer? _instance;

  late HttpServer _server;
  bool isRunning = false;
  final List<WebSocket> _clients = [];

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
    }
    return _instance!;
  }

  static Future<WebSocketServer> serve(dynamic address, int port, {bool v6Only = false}) async {
    if (_instance == null || !_instance!.isRunning) {
      _instance = WebSocketServer._();
      _instance!._dataController = StreamController<dynamic>();
      _instance!._errorController = StreamController<dynamic>();
      await runZonedGuarded(
        () async {
          _instance!._server = await HttpServer.bind(address, port, v6Only: v6Only);
          _instance!._server.listen(_instance!.onRequest);
          _instance!.isRunning = true;
        },
        (Object e, StackTrace st) {
          _instance!._errorSink.add(e);
        }
      );
    }
    return _instance!;
  }

  Future<void> close({bool force = false}) async {
    _dataController.close();
    _errorController.close();
    _instance!._clients.clear();
    _instance!._server.close(force: force);
    _instance!.isRunning = false;
  }

  Future<bool> boardcast(dynamic data) async {
    if (_instance == null || !_instance!.isRunning) {
      return false;
    }

    for (WebSocket client in _clients) {
      client.add(data);
    }

    return true;
  }

  void onRequest(HttpRequest req) async {
    var socket = await WebSocketTransformer.upgrade(req);

    if (!_clients.contains(socket)) {
      _clients.add(socket);
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
          _dataSink.add(jsonDecode(data));
        } on Exception catch (_) {
          _dataSink.add(data);
        }
      }
    );
  }
}
