import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:smart_water_dashboard/core/extension.dart';


enum FcmTopic {
  waterLeakage("/waterLeakage");

  final String _path;

  const FcmTopic(this._path);

  String get path => "/topics$_path";
}

class FcmNotification {
  final String title;
  final String body;

  const FcmNotification({required this.title, required this.body});

  Object toObject() {
    return {
      "title": title,
      "body": body
    };
  }
}

class CloudMessaging {
  static final HttpClient _httpClient = HttpClient();
  static const FlutterSecureStorage _secureStorage = FlutterSecureStorage();
  
  static final StreamController<String> _logController = StreamController<String>();
  static StreamSink<String> get _logSink => _logController.sink;
  static Stream<String> get log => _logController.stream;

  static Future<int> send(FcmTopic topic, FcmNotification notification, {Map<String, String>? data}) async {
    Uri uri = Uri.parse("https://fcm.googleapis.com/fcm/send");

    String serverKey = await _secureStorage.read(key: "fcmServerKey") ?? "";

    String requestBody = jsonEncode({
      "to": topic.path,
      "notification": notification.toObject(),
      "data": data
    });

    HttpClientRequest req = await _httpClient.postUrl(uri);
    req.headers.contentType = ContentType.json;
    req.headers.add("Authorization", "Bearer $serverKey");
    req.headers.contentLength = utf8.encode(requestBody).length;
    req.write(requestBody);

    HttpClientResponse res = await req.close();

    int messageId = jsonDecode(await res.body())["message_id"];

    _logSink.add("Fire notification to `${topic.path}` ($messageId)");

    return messageId;
  }
}
