import 'dart:async';
import 'dart:convert';
import 'dart:io';

class WebSocketServer {
  WebSocketServer._();

  static WebSocketServer? _instance;

  late HttpServer server;
  late void Function(dynamic data) onData;
  late void Function(dynamic error)? onError;
  bool isRunning = false;
  List<WebSocket> clients = [];

  static WebSocketServer get instance {
    if (_instance == null) {
      _instance = WebSocketServer._();
      _instance!.isRunning = false;
    }
    return _instance!;
  }

  static Future<WebSocketServer> serve(
    dynamic address, int port, void Function(dynamic data) onData,
    {bool v6Only = false, void Function(dynamic error)? onError}
  ) async {
    if (_instance == null || !_instance!.isRunning) {
      _instance = WebSocketServer._();
      await runZonedGuarded(
        () async {
          _instance!.server = await HttpServer.bind(address, port, v6Only: v6Only);
          _instance!.server.listen(_instance!.onRequest);
          _instance!.isRunning = true;
          _instance!.onData = onData;
          _instance!.onError = onError;
        },
        (Object e, StackTrace st) {
          if (_instance!.onError != null) {
            _instance!.onError!(e);
          }
        }
      );
    }
    return _instance!;
  }

  Future<bool> boardcast(dynamic data) async {
    if (_instance == null || !_instance!.isRunning) {
      return false;
    }

    for (WebSocket client in clients) {
      client.add(data);
    }

    return true;
  }

  void onRequest(HttpRequest req) async {
    var socket = await WebSocketTransformer.upgrade(req);

    if (!clients.contains(socket)) {
      clients.add(socket);
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
          onData(
            jsonDecode(data)
          );
        } on Exception catch (_) {
          onData(data);
        }
      }
    );
  }
}
