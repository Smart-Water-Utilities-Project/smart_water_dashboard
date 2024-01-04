import "dart:io";

import "package:hive_flutter/adapters.dart";
import "package:path_provider/path_provider.dart";
import "package:smart_water_dashboard/core/cloud_messaging.dart";
import "package:sqlite3/sqlite3.dart";

import "package:smart_water_dashboard/core/extension.dart";


class WaterRecord {
  final int id;
  final int timestamp;
  final double waterFlow;
  final double waterTemp;
  final double waterDist;

  WaterRecord(
    this.id,
    this.timestamp,
    this.waterFlow,
    this.waterTemp,
    this.waterDist
  );
}

class DatabaseHandler {
  DatabaseHandler._();

  static DatabaseHandler? _instance;
  late Database _database;
  
  final Box _sharedPrefs = Hive.box("sharedPrefs");
  
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
          waterTemp REAL NOT NULL,
          waterDist REAL NOT NULL
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

  Future<void> _handleDailyWaterLimitNotify(double waterFlow) async {
    if (_sharedPrefs.get("dailyWaterUsageLimit", defaultValue: -1) < 0) return;

    DateTime now = DateTime.now();

    if (now.weekday != _sharedPrefs.get("lastDailyWaterUsageNotifyAt", defaultValue: -1)) {
      await _sharedPrefs.put(
        "currentDailyWaterUsage",
        waterFlow + _sharedPrefs.get("currentDailyWaterUsage", defaultValue: 0.0)
      );

      if (_sharedPrefs.get("currentDailyWaterUsage") >= _sharedPrefs.get("dailyWaterUsageLimit")) {
        if (_sharedPrefs.get("waterUsageLimitNotify", defaultValue: true)) {
          await CloudMessaging.send(
            FcmTopic.waterLimit,
            const FcmNotification(
              title: "Daily Water Usage Exceeded",
              body: "Daily water usage limits have been exceeded, please take actions to reduce your daily water usage."
            ),
            data: {
              "limit": _sharedPrefs.get("dailyWaterUsageLimit").toString(),
              "current": _sharedPrefs.get("currentDailyWaterUsage").toString()
            }
          );
        }

        await _sharedPrefs.put("lastDailyWaterUsageNotifyAt", now.weekday);
        await _sharedPrefs.delete("currentDailyWaterUsage");
      }
    }
  }

  Future<void> _handleMonthlyWaterLimitNotify(double waterFlow) async {
    if (_sharedPrefs.get("monthlyWaterUsageLimit", defaultValue: -1) < 0) return;

    DateTime now = DateTime.now();

    if (now.month != _sharedPrefs.get("lastMonthlyWaterUsageNotifyAt", defaultValue: -1)) {
      await _sharedPrefs.put(
        "currentMonthlyWaterUsage",
        waterFlow + _sharedPrefs.get("currentMonthlyWaterUsage", defaultValue: 0.0)
      );

      if (_sharedPrefs.get("currentMonthlyWaterUsage") >= _sharedPrefs.get("monthlyWaterUsageLimit")) {
        if (_sharedPrefs.get("waterUsageLimitNotify", defaultValue: true)) {
          await CloudMessaging.send(
            FcmTopic.waterLimit,
            const FcmNotification(
              title: "Monthly Water Usage Exceeded",
              body: "Monthly water usage limits have been exceeded, please take actions to reduce your monthly water usage."
            ),
            data: {
              "limit": _sharedPrefs.get("monthlyWaterUsageLimit").toString(),
              "current": _sharedPrefs.get("currentMonthlyWaterUsage").toString()
            }
          );
        }

        await _sharedPrefs.put("lastMonthlyWaterUsageNotifyAt", now.month);
        await _sharedPrefs.delete("currentMonthlyWaterUsage");
      }
    }
  }

  Future<void> _handlePipeFreezeNotify(double waterTemp) async {
    if (!_sharedPrefs.get("pipeFreezeNotify", defaultValue: true)) {
      return;
    }

    double now = DateTime.now().toMinutesSinceEpoch();


    if (waterTemp <= 2.5) {
      if (now - _sharedPrefs.get("lastPipeFreezeNotifyAt", defaultValue: 0) > 60 * 24) {
        await CloudMessaging.send(
          FcmTopic.pipeFreeze,
          const FcmNotification(
            title: "Pipe Freeze Warning",
            body: "Environmental temperatures appear to be close to freezing, make sure you have taken any actions to prevent pipes from freezing."
          )
        );

        await _sharedPrefs.put("lastPipeFreezeNotifyAt", now);
      }
    }
  }

  void insertWaterRecord(
    int timestamp,
    double waterFlow,
    double waterTemp,
    double waterDist
  ) {
    _instance!._database.execute(
      """
        INSERT INTO waterRecord (
          timestamp, waterFlow, waterTemp, waterDist
        ) VALUES (
          '$timestamp', '$waterFlow', '$waterTemp', '$waterDist'
        )
      """
    );

    _handleDailyWaterLimitNotify(waterFlow);
    _handleMonthlyWaterLimitNotify(waterFlow);
    _handlePipeFreezeNotify(waterTemp);
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
          WaterRecord(
            row["id"],
            row["timestamp"],
            row["waterFlow"],
            row["waterTemp"],
            row["waterDist"]
          )
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
          WaterRecord(
            row["id"],
            row["timestamp"],
            row["waterFlow"],
            row["waterTemp"],
            row["waterDist"]
          )
        );
      }
    );

    return result;
  }
}
