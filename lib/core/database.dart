import 'dart:io';

import 'package:path_provider/path_provider.dart';
import 'package:smart_water_dashboard/core/extension.dart';
import 'package:sqlite3/sqlite3.dart';


class WaterRecord {
  final int id;
  final int timestamp;
  final double waterFlow;
  final double waterTemp;

  WaterRecord(this.id, this.timestamp, this.waterFlow, this.waterTemp);
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

      _instance!.createTable();
    }
    return _instance!;
  }

  void dispose() {
    _instance!._database.dispose();
    _instance = null;
  }

  void createTable() {
    _instance!._database.execute(
      """
        CREATE TABLE IF NOT EXISTS waterRecord (
          id INTEGER PRIMARY KEY AUTOINCREMENT NOT NULL,
          timestamp INTEGER NOT NULL,
          waterFlow REAL NOT NULL,
          waterTemp REAL NOT NULL
        );
      """
    );
  }

  void dropTable() {
    _instance!._database.execute(
      """
        DROP TABLE waterRecord;
      """
    );
  }

  void insertWaterRecord(int timestamp, double waterFlow, double waterTemp) {
    _instance!._database.execute(
      """
        INSERT INTO waterRecord (
          timestamp, waterFlow, waterTemp
        ) VALUES (
          '$timestamp', '$waterFlow', '$waterTemp'
        )
      """
    );
  }

  void deleteRecord(int id) {
    _instance!._database.execute(
      """
        DELETE FROM waterRecord WHERE id = '$id';
      """
    );
  }

  int getRowCount() {
    ResultSet query = _instance!._database.select(
      """
        SELECT COUNT(1) FROM waterRecord;
      """
    );

    return query.rows[0][0] as int;
  }

  List<WaterRecord> getRecordByLimit(int from, int to) {
    List<WaterRecord> result = [];

    ResultSet query = _instance!._database.select(
      """
        SELECT * FROM waterRecord
        LIMIT $from, $to;
      """
    );
    query.forEach(
      (Row row) {
        result.add(
          WaterRecord(row['id'], row['timestamp'], row['waterFlow'], row['waterTemp'])
        );
      }
    );

    return result;
  }

  List<WaterRecord> getRecord(int? start, int? end) {
    List<WaterRecord> result = [];

    start ??= DateTime.fromMicrosecondsSinceEpoch(0).toMinutesSinceEpoch().floor();
    end ??= DateTime.now().toMinutesSinceEpoch().floor();

    ResultSet query = _instance!._database.select(
      """
        SELECT * FROM waterRecord
        WHERE timestamp >= $start AND timestamp <= $end;
      """
    );
    query.forEach(
      (Row row) {
        result.add(
          WaterRecord(row['id'], row['timestamp'], row['waterFlow'], row['waterTemp'])
        );
      }
    );

    return result;
  }
}
