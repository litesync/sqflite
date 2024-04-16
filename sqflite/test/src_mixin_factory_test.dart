import 'package:flutter_test/flutter_test.dart';
import 'package:litesync_sqflite/sqlite_api.dart';
import 'package:litesync_sqflite/src/constant.dart';
import 'package:litesync_sqflite/src/mixin/factory.dart';

import 'src_mixin_test.dart';

void main() {
  group('mixin_factory', () {
    test('public', () {
      // ignore: unnecessary_statements
      buildDatabaseFactory;
      // ignore: unnecessary_statements
      SqfliteInvokeHandler;
    });
    test('buildDatabaseFactory', () async {
      final methods = <String>[];
      final factory = buildDatabaseFactory(
          invokeMethod: (String method, [dynamic arguments]) async {
        methods.add(method);
        return mockResult(method);
      });
      expect(factory is SqfliteInvokeHandler, isTrue);
      await factory.openDatabase(inMemoryDatabasePath);
      expect(methods, <String>['openDatabase']);
    });
  });
}
