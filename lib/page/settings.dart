import 'package:flutter/material.dart';
import 'package:smart_water_dashboard/core/database.dart';
import 'package:smart_water_dashboard/core/websocket.dart';

class SettingsPage extends StatefulWidget {
  const SettingsPage({super.key});

  @override
  State<StatefulWidget> createState() => _SettingsPageState();
}

class _SettingsPageState extends State<SettingsPage> {
  late TextEditingController _serverIpInputController;
  late TextEditingController _serverPortInputController;

  @override
  void initState() {
    super.initState();
    _serverIpInputController = TextEditingController(text: "127.0.0.1");
    _serverPortInputController = TextEditingController(text: "5678");
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Column(
        mainAxisAlignment: MainAxisAlignment.start,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SizedBox(height: 30,),
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
                  WebSocketServer.instance.close();
                  WebSocketServer.serve(
                    _serverIpInputController.text,
                    int.parse(_serverPortInputController.text)
                  );
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
                    title: const Text("確定要清除所有資料嗎？"),
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
                          WebSocketServer.instance.close();
                          DatabaseHandler.instance.dropTable();
                          DatabaseHandler.instance.createTable();
                          WebSocketServer.serve(
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
          )
        ],
      ),
    );
  }
}
