import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:secure_shared_preferences/secure_shared_preferences.dart';
import 'package:shared_preferences/shared_preferences.dart';
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
  static late final SharedPreferences _sharedPref;
  static late final SecureSharedPref _secureSharedPref;
  
  static final StreamController<String> _logController = StreamController<String>();
  static StreamSink<String> get _logSink => _logController.sink;
  static Stream<String> get log => _logController.stream;

  static Future<void> init() async {
    if (Platform.isMacOS) {
      _logSink.add("macOS currently don't support `secure_shared_preferences`, your FCM Server Key may not be encrypted.");
      _sharedPref = await SharedPreferences.getInstance();
    } else {
      _secureSharedPref = await SecureSharedPref.getInstance();
    }
  }

  static Future<int> send(FcmTopic topic, FcmNotification notification, {Map<String, String>? data}) async {
    Uri uri = Uri.parse("https://fcm.googleapis.com/fcm/send");

    String serverKey;
    if (Platform.isMacOS) {
      serverKey = _sharedPref.getString("fcmServerKey") ?? "";
    } else {
      serverKey = await _secureSharedPref.getString("fcmServerKey", isEncrypted: true) ?? "";
    }

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
