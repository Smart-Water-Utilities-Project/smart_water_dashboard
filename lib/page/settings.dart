import 'package:flutter/material.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:smart_water_dashboard/core/database.dart';
import 'package:smart_water_dashboard/core/server.dart';

class SettingsPage extends StatefulWidget {
  const SettingsPage({super.key});

  @override
  State<StatefulWidget> createState() => _SettingsPageState();
}

class _SettingsPageState extends State<SettingsPage> {
  late final TextEditingController _serverIpInputController;
  late final TextEditingController _serverPortInputController;
  late final TextEditingController _fcmServerkeyInputController;
  late final SharedPreferences _sharedPref;
  final FlutterSecureStorage _secureStorage = const FlutterSecureStorage();

  void _initSharedPref() async {
    _sharedPref = await SharedPreferences.getInstance();
    _serverIpInputController.text = _sharedPref.getString("serverIp") ?? "127.0.0.1";
    _serverPortInputController.text = _sharedPref.getString("serverPort") ?? "5678";
    _fcmServerkeyInputController.text = await _secureStorage.read(key: "fcmServerKey") ?? "";
  }

  @override
  void initState() {
    super.initState();
    _serverIpInputController = TextEditingController(text: "127.0.0.1");
    _serverPortInputController = TextEditingController(text: "5678");
    _fcmServerkeyInputController = TextEditingController(text: "");
    _initSharedPref();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Column(
        mainAxisAlignment: MainAxisAlignment.start,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SizedBox(height: 8,),
          const Text(
            "更改伺服器位址",
            style: TextStyle(
              fontSize: 22,
              fontWeight: FontWeight.bold
            ),
          ),
          Row(
            children: [
              SizedBox(
                width: 140,
                child: TextField(
                  controller: _serverIpInputController,
                  keyboardType: TextInputType.number,
                  maxLength: 15,
                  maxLines: 1,
                  decoration: const InputDecoration(
                    hintText: "127.0.0.1",
                    label: Text("Server IP")
                  ),
                ),
              ),
              const SizedBox(width: 10,),
              SizedBox(
                width: 80,
                child: TextField(
                  controller: _serverPortInputController,
                  keyboardType: TextInputType.number,
                  maxLength: 5,
                  maxLines: 1,
                  decoration: const InputDecoration(
                    hintText: "5678",
                    label: Text("Server Port")
                  ),
                ),
              ),
              const SizedBox(width: 22,),
              FilledButton(
                onPressed: () {
                  WebServer.instance.close();
                  WebServer.serve(
                    _serverIpInputController.text,
                    int.parse(_serverPortInputController.text)
                  );

                  _sharedPref.setString("serverIp", _serverIpInputController.text);
                  _sharedPref.setString("serverPort", _serverPortInputController.text);
                  
                  showDialog(
                    context: context,
                    builder: (context) {
                      return AlertDialog(
                        title: const Text("已更新伺服器設定"),
                        actions: [
                          TextButton(
                            child: const Text('OK'),
                            onPressed: () {
                              Navigator.of(context).pop();
                            },
                          ),
                        ],
                      );
                    },
                  );
                },
                child: const Text("Apply"),
              )
            ],
          ),
          const SizedBox(height: 30,),
          const Text(
            "清空資料庫",
            style: TextStyle(
              fontSize: 22,
              fontWeight: FontWeight.bold
            ),
          ),
          const SizedBox(height: 10,),
          FilledButton(
            onPressed: () {
              showDialog(
                context: context,
                builder: (context) {
                  return AlertDialog(
                    title: Text("確定要清除全部 ${DatabaseHandler.instance.getRowCount()} 筆資料嗎？"),
                    actions: [
                      TextButton(
                        child: const Text('Cancel'),
                        onPressed: () {
                          Navigator.of(context).pop();
                        },
                      ),
                      TextButton(
                        child: const Text('Comfirm'),
                        onPressed: () {
                          WebServer.instance.close();
                          DatabaseHandler.instance.dropTable();
                          DatabaseHandler.instance.createTable();
                          WebServer.serve(
                            _serverIpInputController.text,
                            int.parse(_serverPortInputController.text)
                          );
                          Navigator.of(context).pop();
                        },
                      ),
                    ],
                  );
                },
              );
            },
            child: const Text("Comfirm"),
          ),
          const SizedBox(height: 30,),
          const Text(
            "更改 FCM Server Key",
            style: TextStyle(
              fontSize: 22,
              fontWeight: FontWeight.bold
            ),
          ),
          Row(
            children: [
              SizedBox(
                width: 140,
                child: TextField(
                  controller: _fcmServerkeyInputController,
                  keyboardType: TextInputType.text,
                  maxLines: 1,
                  maxLength: 200,
                  obscureText: true,
                  decoration: const InputDecoration(
                    hintText: "AADA...23D",
                    label: Text("Server Key")
                  ),
                ),
              ),
              const SizedBox(width: 22,),
              FilledButton(
                onPressed: () async {
                  await _secureStorage.write(
                    key: "fcmServerKey",
                    value: _fcmServerkeyInputController.text
                  );
                  if (!mounted) return;
                  showDialog(
                    context: context,
                    builder: (context) {
                      return AlertDialog(
                        title: const Text("已更新 Server Key"),
                        actions: [
                          TextButton(
                            child: const Text('OK'),
                            onPressed: () {
                              Navigator.of(context).pop();
                            },
                          ),
                        ],
                      );
                    },
                  );
                },
                child: const Text("Apply"),
              )
            ],
          )
        ],
      ),
    );
  }
}
