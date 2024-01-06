import "package:flutter/material.dart";

import "package:flutter_secure_storage/flutter_secure_storage.dart";
import "package:hive_flutter/adapters.dart";

import "package:smart_water_dashboard/core/cloud_messaging.dart";
import "package:smart_water_dashboard/core/database.dart";
import "package:smart_water_dashboard/core/server.dart";


class SettingsPage extends StatefulWidget {
  const SettingsPage({super.key});

  @override
  State<StatefulWidget> createState() => _SettingsPageState();
}

class _SettingsPageState extends State<SettingsPage> {
  late final TextEditingController _serverIpInputController;
  late final TextEditingController _serverPortInputController;
  late final TextEditingController _fcmServerkeyInputController;
  late final TextEditingController _dailyWaterUsageLimitInputController;
  late final TextEditingController _monthlyWaterUsageLimitInputController;
  final Box _sharedPrefs = Hive.box("sharedPrefs");
  final FlutterSecureStorage _secureStorage = const FlutterSecureStorage();

  void _initSharedPref() async {
    _fcmServerkeyInputController.text = await _secureStorage.read(key: "fcmServerKey") ?? "";
  }

  @override
  void initState() {
    super.initState();

    _serverIpInputController = TextEditingController(
      text: _sharedPrefs.get("serverIp", defaultValue: "127.0.0.1")
    );
    _serverPortInputController = TextEditingController(
      text: _sharedPrefs.get("serverPort", defaultValue: "5678")
    );

    _fcmServerkeyInputController = TextEditingController(text: "");

    _dailyWaterUsageLimitInputController = TextEditingController(
      text: _sharedPrefs.get("dailyWaterUsageLimit", defaultValue: -1).toString()
    );
    _monthlyWaterUsageLimitInputController = TextEditingController(
      text: _sharedPrefs.get("monthlyWaterUsageLimit", defaultValue: -1).toString()
    );

    _initSharedPref();

    _sharedPrefs.watch(key: "dailyWaterUsageLimit").listen((event) {
      _dailyWaterUsageLimitInputController.text = event.value.toString();
    });
    _sharedPrefs.watch(key: "monthlyWaterUsageLimit").listen((event) {
      _monthlyWaterUsageLimitInputController.text = event.value.toString();
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: ListView(
        padding: const EdgeInsets.fromLTRB(0, 30, 50, 30),
        children: [
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
                onPressed: () async {
                  await WebServer.instance.close();
                  await WebServer.serve(
                    _serverIpInputController.text,
                    int.parse(_serverPortInputController.text)
                  );

                  await _sharedPrefs.put("serverIp", _serverIpInputController.text);
                  await _sharedPrefs.put("serverPort", _serverPortInputController.text);
                  
                  if (!mounted) return;
                  showDialog(
                    context: context,
                    builder: (context) {
                      return AlertDialog(
                        title: const Text("已更新伺服器設定"),
                        actions: [
                          TextButton(
                            child: const Text("OK"),
                            onPressed: () {
                              Navigator.of(context).pop();
                            },
                          ),
                        ],
                      );
                    },
                  );
                },
                child: const Text("Apply & Restart"),
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
                        child: const Text("Cancel"),
                        onPressed: () {
                          Navigator.of(context).pop();
                        },
                      ),
                      TextButton(
                        child: const Text("Comfirm"),
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
            child: const Text("Drop Database"),
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
                width: 260,
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
                            child: const Text("OK"),
                            onPressed: () {
                              Navigator.of(context).pop();
                            },
                          ),
                        ],
                      );
                    },
                  );
                },
                child: const Text("Apply & Save"),
              )
            ],
          ),
          const SizedBox(height: 30,),
          const Text(
            "發送測試通知",
            style: TextStyle(
              fontSize: 22,
              fontWeight: FontWeight.bold
            ),
          ),
          const SizedBox(height: 10,),
          FilledButton(
            onPressed: () async {
              await CloudMessaging.send(
                FcmTopic.devTest,
                const FcmNotification(
                  title: "Dev Test",
                  body: "This is a test message"
                ),
                data: {"Hello": "World"}
              );

              if (!mounted) return;
              showDialog(
                context: context,
                builder: (context) {
                  return AlertDialog(
                    title: const Text("已發送測試通知"),
                    actions: [
                      TextButton(
                        child: const Text("OK"),
                        onPressed: () {
                          Navigator.of(context).pop();
                        },
                      ),
                    ],
                  );
                },
              );
            },
            child: const Text("Send Notification"),
          ),
          const SizedBox(height: 30,),
          const Text(
            "更改用水上限",
            style: TextStyle(
              fontSize: 22,
              fontWeight: FontWeight.bold
            ),
          ),
          Row(
            children: [
              SizedBox(
                width: 180,
                child: TextField(
                  controller: _dailyWaterUsageLimitInputController,
                  keyboardType: TextInputType.number,
                  maxLines: 1,
                  decoration: const InputDecoration(
                    label: Text("Daily Water Usage"),
                    suffixText: "L"
                  ),
                ),
              ),
              const SizedBox(width: 10,),
              SizedBox(
                width: 180,
                child: TextField(
                  controller: _monthlyWaterUsageLimitInputController,
                  keyboardType: TextInputType.number,
                  maxLines: 1,
                  decoration: const InputDecoration(
                    label: Text("Monthly Water Usage"),
                    suffixText: "L"
                  ),
                ),
              ),
              const SizedBox(width: 22,),
              FilledButton(
                onPressed: () async {
                  await _sharedPrefs.put("dailyWaterUsageLimit", int.tryParse(_dailyWaterUsageLimitInputController.text) ?? -1);
                  await _sharedPrefs.put("monthlyWaterUsageLimit", int.tryParse(_monthlyWaterUsageLimitInputController.text) ?? -1);

                  await _sharedPrefs.put("lastDailyWaterUsageNotifyAt", -1);
                  await _sharedPrefs.put("lastMonthlyWaterUsageNotifyAt", -1);
                  
                  if (!mounted) return;
                  showDialog(
                    context: context,
                    builder: (context) {
                      return AlertDialog(
                        title: const Text("已儲存用水上限"),
                        actions: [
                          TextButton(
                            child: const Text("OK"),
                            onPressed: () {
                              Navigator.of(context).pop();
                            },
                          ),
                        ],
                      );
                    },
                  );
                },
                child: const Text("Apply & Save"),
              ),
            ],
          ),
        ]
      ),
    );
  }
}
