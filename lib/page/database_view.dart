import "dart:async";
import "dart:io";

import "package:flutter/material.dart";

import "package:intl/intl.dart";

import "package:smart_water_dashboard/core/database.dart";
import "package:smart_water_dashboard/core/extension.dart";


class DatabaseViewPage extends StatefulWidget {
  const DatabaseViewPage({super.key});

  @override
  State<StatefulWidget> createState() => _DatabaseViewPageState();
}

class _DatabaseViewPageState extends State<DatabaseViewPage> {
  static const int _rowPerPage = 12;
  int _pageIndex = 0;
  int _pageCount() => (DatabaseHandler.instance.getRowCount() / _rowPerPage).ceil();
  List<WaterRecord> _data = [];
  late Timer _updateTimer;


  final TextEditingController _dateInput = TextEditingController(
    text: DateFormat("yyyy/MM/dd").format(DateTime.now())
  );
  final TextEditingController _timeInput = TextEditingController(
    text: DateFormat("hh:mm").format(DateTime.now())
  );
  final TextEditingController _waterFlowInput = TextEditingController(text: "0.0");
  final TextEditingController _waterTempInput = TextEditingController(text: "0.0");
  final TextEditingController _waterDistInput = TextEditingController(text: "0.0");

  void _updateData() {
    _data = DatabaseHandler.instance.getRecordByLimit(_pageIndex * _rowPerPage, _pageIndex * _rowPerPage + _rowPerPage);
  }

  @override
  void initState() {
    super.initState();
    _updateData();
    _updateTimer = Timer.periodic(
      const Duration(seconds: 5),
      (timer) {
        setState(() {
          _updateData();
        });
      }
    );
  }

  @override
  void dispose() {
    _updateTimer.cancel();

    _dateInput.dispose();
    _timeInput.dispose();
    _waterFlowInput.dispose();
    _waterTempInput.dispose();
    _waterDistInput.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.start,
            mainAxisSize: MainAxisSize.max,
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              const SizedBox(
                width: 80,
                child: Text(
                  "ID",
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 16
                  ),
                ),
              ),
              const SizedBox(
                width: 160,
                child: Text(
                  "Timestamp",
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 16
                  ),
                ),
              ),
              const Expanded(
                child: Text(
                  "Water Flow",
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 16
                  ),
                ),
              ),
              const Expanded(
                child: Text(
                  "Water Temp",
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 16
                  ),
                ),
              ),
              const Expanded(
                child: Text(
                  "Water Temp",
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 16
                  ),
                ),
              ),
              SizedBox(
                width: 26,
                height: 26,
                child: InkWell(
                  borderRadius: BorderRadius.circular(8),
                  onTap: () async {
                    DateTime recordAt = DateTime.now();

                    _dateInput.text = DateFormat("yyyy/MM/dd").format(recordAt);
                    _timeInput.text = DateFormat("hh:mm").format(recordAt);
                    _waterFlowInput.text = "0.0";
                    _waterTempInput.text = "0.0";
                    _waterDistInput.text = "0.0";

                    await showDialog(
                      context: context,
                      builder: (BuildContext context) {
                        return AlertDialog(
                          title: const Text("Insert New Record"),
                          content: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              TextField(
                                controller: _dateInput,
                                readOnly: true,
                                maxLines: 1,
                                decoration: const InputDecoration(
                                  label: Text("Record Date"),
                                ),
                                onTap: () async {
                                  recordAt = await showDatePicker(
                                    context: context,
                                    firstDate: DateTime.fromMillisecondsSinceEpoch(0),
                                    lastDate: DateTime.tryParse("2100-01-01")!
                                  ) ?? DateTime.now();
                                  _dateInput.text = DateFormat("yyyy/MM/dd").format(recordAt);
                                },
                              ),
                              TextField(
                                controller: _timeInput,
                                readOnly: true,
                                maxLines: 1,
                                decoration: const InputDecoration(
                                  label: Text("Record Time"),
                                ),
                                onTap: () async {
                                  recordAt = recordAt.applied(
                                    await showTimePicker(
                                      context: context,
                                      initialTime: TimeOfDay.now()
                                    ) ?? TimeOfDay.now()
                                  );
                                  _timeInput.text = DateFormat("hh:mm").format(recordAt);
                                },
                              ),
                              TextField(
                                controller: _waterFlowInput,
                                maxLines: 1,
                                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                                decoration: const InputDecoration(
                                  label: Text("Water Flow"),
                                ),
                              ),
                              TextField(
                                controller: _waterTempInput,
                                maxLines: 1,
                                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                                decoration: const InputDecoration(
                                  label: Text("Water Temp"),
                                ),
                              ),
                              TextField(
                                controller: _waterDistInput,
                                maxLines: 1,
                                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                                decoration: const InputDecoration(
                                  label: Text("Water Dist"),
                                ),
                              ),
                            ],
                          ),
                          actions: [
                            OutlinedButton(
                              onPressed: () {
                                Navigator.of(context).pop();
                              },
                              child: const Text("Cancel"),
                            ),
                            ElevatedButton(
                              onPressed: () {
                                DatabaseHandler.instance.insertWaterRecord(
                                  recordAt.toMinutesSinceEpoch().floor(),
                                  double.tryParse(_waterFlowInput.text) ?? 0.0,
                                  double.tryParse(_waterTempInput.text) ?? 0.0,
                                  double.tryParse(_waterDistInput.text) ?? 0.0,
                                );

                                Navigator.of(context).pop();
                              },
                              child: const Text("Insert"),
                            )
                          ],
                        );
                      }
                    );
                  },
                  child: const Center(
                    child: Icon(
                      Icons.add_to_photos_rounded,
                      size: 24,
                    ),
                  ),
                ),
              )
            ],
          ),
          const Divider(
            thickness: 2,
          ),
          Expanded(
            child: ListView.separated(
              itemCount: _data.length,
              itemBuilder: (context, index) {
                return RowItem(
                  data: _data[index],
                  onDelete: () {
                    setState(() {
                      DatabaseHandler.instance.deleteRecord(_data[index].id);
                      _updateData();
                    });
                  },
                );
              },
              separatorBuilder: (context, index) => const Divider(),
              
            ),
          ),
          Row(
            mainAxisSize: MainAxisSize.max,
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              IconButton(
                onPressed: _pageIndex <= 0 ? null : () {
                  setState(() {
                    _pageIndex -= 1;
                    _updateData();
                  });
                },
                icon: const Icon(
                  Icons.chevron_left_rounded,
                  size: 26,
                ),
              ),
              Text(
                (_pageIndex + 1).toString(),
                style: const TextStyle(
                  fontSize: 18
                ),
              ),
              IconButton(
                onPressed: _pageIndex >= _pageCount() - 1 ? null : () {
                  setState(() {
                    _pageIndex += 1;
                    _updateData();
                  });
                },
                icon: const Icon(
                  Icons.chevron_right_rounded,
                  size: 26,
                ),
              ),
            ],
          )
        ],
      ),
    );
  }
}

class RowItem extends StatelessWidget {
  const RowItem({super.key, required this.data, required this.onDelete});

  final WaterRecord data;
  final void Function() onDelete;
  
  String _getFontFamily() {
    if (Platform.isIOS || Platform.isMacOS) {
      return "Courier New";
    } else if (Platform.isWindows) {
      return "Cascadia Mono";
    }
    return "monospace";
  }

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.start,
      mainAxisSize: MainAxisSize.max,
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        SizedBox(
          width: 80,
          child: Text(
            data.id.toString(),
            style: TextStyle(
              fontFamily: _getFontFamily()
            ),
          ),
        ),
        SizedBox(
          width: 160,
          child: Text(
            data.timestamp.toString(),
            style: TextStyle(
              fontFamily: _getFontFamily()
            ),
          ),
        ),
        Expanded(
          child: Text(
            data.waterFlow.toStringAsFixed(3),
            style: TextStyle(
              fontFamily: _getFontFamily()
            ),
          ),
        ),
        Expanded(
          child: Text(
            data.waterTemp.toStringAsFixed(3),
            style: TextStyle(
              fontFamily: _getFontFamily()
            ),
          ),
        ),
        Expanded(
          child: Text(
            data.waterDist.toStringAsFixed(3),
            style: TextStyle(
              fontFamily: _getFontFamily()
            ),
          ),
        ),
        SizedBox(
          width: 26,
          height: 26,
          child: InkWell(
            borderRadius: BorderRadius.circular(8),
            onTap: onDelete,
            child: const Center(
              child: Icon(
                Icons.delete_forever_rounded,
                size: 24,
              ),
            ),
          ),
        )
      ],
    );
  }
}
