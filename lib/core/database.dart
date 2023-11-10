import 'dart:io';

import 'package:path_provider/path_provider.dart';
import 'package:smart_water_dashboard/core/extension.dart';
import 'package:sqlite3/sqlite3.dart';


class WaterRecord {
  final int timestamp;
  final double waterFlow;
  final double waterTemp;

  WaterRecord(this.timestamp, this.waterFlow, this.waterTemp);
}

class DatabaseHandler {
  DatabaseHandler._();

  static DatabaseHandler? _instance;
  late Database _database;
  
  static DatabaseHandler get instance {
    return _instance!;
  }

  static Future<DatabaseHandler> init() async {
    if (_instance == null) {
      _instance = DatabaseHandler._();

      Directory docPath = await getApplicationDocumentsDirectory();
      _instance!._database = sqlite3.open("${docPath.path}/water_record.db");

      _instance!._database.execute(
        """
          CREATE TABLE IF NOT EXISTS waterRecord (
            timestamp INTEGER PRIMARY KEY NOT NULL,
            waterFlow REAL NOT NULL,
            waterTemp REAL NOT NULL
          );
        """
      );
    }
    return _instance!;
  }

  void dispose() {
    _instance!._database.dispose();
    _instance = null;
  }

  void drop() {
    _instance!._database.execute(
      """
        DROP TABLE waterRecord;
      """
    );
  }

  void insertWaterRecord(WaterRecord data) {
    _instance!._database.execute(
      """
        INSERT INTO waterRecord (
          timestamp, waterFlow, waterTemp
        ) VALUES (
          '${data.timestamp}', '${data.waterFlow}', '${data.waterTemp}'
        )
      """
    );
  }

  List<WaterRecord> getRecord(int? start, int? end) {
    List<WaterRecord> result = [];

    start ??= 0;
    end ??= DateTime.now().millisecondsSinceEpoch;

    ResultSet query = _instance!._database.select(
      """
        SELECT * FROM waterRecord
        WHERE timestamp >= $start AND timestamp <= $end;
      """
    );
    for (final Row row in query) {
      result.add(
        WaterRecord(row['timestamp'], row['waterFlow'], row['waterTemp'])
      );
    }

    return result;
  }
}