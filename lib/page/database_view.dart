import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:smart_water_dashboard/core/database.dart';

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
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Column(
        children: [
          const Row(
            mainAxisAlignment: MainAxisAlignment.start,
            mainAxisSize: MainAxisSize.max,
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              SizedBox(
                width: 80,
                child: Text(
                  "ID",
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 16
                  ),
                ),
              ),
              SizedBox(
                width: 160,
                child: Text(
                  "Timestamp",
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 16
                  ),
                ),
              ),
              Expanded(
                child: Text(
                  "Water Flow",
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 16
                  ),
                ),
              ),
              Expanded(
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
              )
            ],
          ),
          const Divider(
            thickness: 2,
            color: Colors.black,
          ),
          Expanded(
            child: ListView.separated(
              itemCount: _data.length,
              physics: const NeverScrollableScrollPhysics(),
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
                disabledColor: Colors.black26,
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
                disabledColor: Colors.black26,
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
