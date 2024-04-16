import 'dart:async';

import 'package:litesync_sqflite/sqlite_api.dart';
import 'package:litesync_sqflite/src/mixin/factory.dart';

Future<void> main() async {
  final factory = buildDatabaseFactory(
      invokeMethod: (String method, [dynamic arguments]) async {
    dynamic result;
    print('$method: $arguments');
    return result;
  });
  final db = await factory.openDatabase(inMemoryDatabasePath);
  await db.getVersion();
}
