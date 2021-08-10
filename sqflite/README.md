# octodb_sqflite

[![pub package](https://img.shields.io/pub/v/sqflite.svg)](https://pub.dev/packages/octodb_sqflite)
[![Build Status](https://travis-ci.org/tekartik/sqflite.svg?branch=master)](https://travis-ci.org/tekartik/sqflite)
[![codecov](https://codecov.io/gh/tekartik/sqflite/branch/master/graph/badge.svg)](https://codecov.io/gh/tekartik/sqflite)

OctoDB & SQLite plugin for [Flutter](https://flutter.io).
Supports iOS, Android and MacOS.

* Support transactions and batches
* Helpers for insert/query/update/delete queries
* DB operation executed in a background thread on iOS and Android

Other platforms support:
* Linux/Windows/DartVM support using [sqflite_common_ffi](https://pub.dev/packages/sqflite_common_ffi)
* Web [is not supported](https://github.com/tekartik/sqflite/blob/master/sqflite/doc/troubleshooting.md#error-in-flutter-web).

Usage example: 
* [notepad_sqflite](https://github.com/alextekartik/flutter_app_example/tree/master/notepad_sqflite): Simple flutter notepad working on iOS/Android/Windows/linux/Mac


## Getting Started

In your flutter project add the dependency:

```yml
dependencies:
  ...
  octodb_sqflite:
```

Then run:

```
flutter pub get
```

For help getting started with Flutter, view the online [documentation](https://flutter.io/).


## Native libraries

To install the free version of OctoDB native libraries, execute the following:

```
export FLUTTER_PATH=/path/to/flutter/sdk     # <-- put the path to the Flutter SDK here
wget http://octodb.io/download/octodb.aar
wget http://octodb.io/download/octodb-free-ios-native-libs.tar.gz
tar zxvf octodb-free-ios-native-libs.tar.gz lib
mv lib $(FLUTTER_PATH)/.pub-cache/hosted/pub.dartlang.org/octodb_sqflite-*/ios/
mv octodb.aar $(FLUTTER_PATH)/.pub-cache/hosted/pub.dartlang.org/octodb_sqflite-*/android/
```

When moving to the full version of OctoDB just copy the libraries to the respective folders as done above, replacing the existing files.


## Usage example

Import `sqflite.dart`

```dart
import 'package:octodb_sqflite/sqflite.dart';
```

### Opening a database

A SQLite database is a file in the file system. If no full path is given, the file is saved in the folder obtained by `getDatabasesPath()`, which is the default database directory on Android and the documents directory on iOS/MacOS.

```dart
var uri = 'file:my_db.db?node=secondary&connect=tcp://111.222.33.44:1234'
var db = await openDatabase(uri);
```

Many applications use one database and would never need to close it (it will be closed when the application is
terminated). If you want to release resources, you can close the database.

```dart
await db.close();
```

* See [more information on opening a database](https://github.com/octodb/sqflite/blob/master/sqflite/doc/opening_db.md).

### Raw SQL queries
    
Demo code to perform Raw SQL queries

```dart
// Get a location using getDatabasesPath
var databasesPath = await getDatabasesPath();
String path = join(databasesPath, 'demo.db');
String uri = 'file:' + path + '?node=secondary&connect=tcp://server:port';

// open the database
Database database = await openDatabase(uri);

// Insert some records in a transaction
await database.transaction((txn) async {
  int id1 = await txn.rawInsert(
      'INSERT INTO Test(name, value, num) VALUES("some name", 1234, 456.789)');
  print('inserted1: $id1');
  int id2 = await txn.rawInsert(
      'INSERT INTO Test(name, value, num) VALUES(?, ?, ?)',
      ['another name', 12345678, 3.1416]);
  print('inserted2: $id2');
});

// Update some record
int count = await database.rawUpdate(
    'UPDATE Test SET name = ?, value = ? WHERE name = ?',
    ['updated name', '9876', 'some name']);
print('updated: $count');

// Get the records
List<Map> list = await database.rawQuery('SELECT * FROM Test');
List<Map> expectedList = [
  {'name': 'updated name', 'id': 1, 'value': 9876, 'num': 456.789},
  {'name': 'another name', 'id': 2, 'value': 12345678, 'num': 3.1416}
];
print(list);
print(expectedList);
assert(const DeepCollectionEquality().equals(list, expectedList));

// Count the records
count = Sqflite
    .firstIntValue(await database.rawQuery('SELECT COUNT(*) FROM Test'));
assert(count == 2);

// Delete a record
count = await database
    .rawDelete('DELETE FROM Test WHERE name = ?', ['another name']);
assert(count == 1);

// Close the database
await database.close();
```

Basic information on SQL [here](https://github.com/octodb/sqflite/blob/master/sqflite/doc/sql.md).

### SQL helpers

Example using the helpers

```dart
final String tableTodo = 'todo';
final String columnId = '_id';
final String columnTitle = 'title';
final String columnDone = 'done';

class Todo {
  int id;
  String title;
  bool done;

  Map<String, Object?> toMap() {
    var map = <String, Object?>{
      columnTitle: title,
      columnDone: done == true ? 1 : 0
    };
    if (id != null) {
      map[columnId] = id;
    }
    return map;
  }

  Todo();

  Todo.fromMap(Map<String, Object?> map) {
    id = map[columnId];
    title = map[columnTitle];
    done = map[columnDone] == 1;
  }
}

class TodoProvider {
  Database db;

  Future open(String path) async {
    db = await openDatabase(path);
  }

  Future<Todo> insert(Todo todo) async {
    todo.id = await db.insert(tableTodo, todo.toMap());
    return todo;
  }

  Future<Todo> getTodo(int id) async {
    List<Map> maps = await db.query(tableTodo,
        columns: [columnId, columnDone, columnTitle],
        where: '$columnId = ?',
        whereArgs: [id]);
    if (maps.length > 0) {
      return Todo.fromMap(maps.first);
    }
    return null;
  }

  Future<int> delete(int id) async {
    return await db.delete(tableTodo, where: '$columnId = ?', whereArgs: [id]);
  }

  Future<int> update(Todo todo) async {
    return await db.update(tableTodo, todo.toMap(),
        where: '$columnId = ?', whereArgs: [todo.id]);
  }

  Future close() async => db.close();
}
```

### Read results

Assuming the following read results:

```dart
List<Map<String, Object?>> records = await db.query('my_table');
```

Resulting map items are read-only

```dart
// get the first record
Map<String, Object?> mapRead = records.first;
// Update it in memory...this will throw an exception
mapRead['my_column'] = 1;
// Crash... `mapRead` is read-only
```

You need to create a new map if you want to modify it in memory:

```dart
// get the first record
Map<String, Object?> map = Map<String, Object?>.from(mapRead);
// Update it in memory now
map['my_column'] = 1;
```

### Transaction

Don't use the database but only use the Transaction object in a transaction
to access the database.

```dart
await database.transaction((txn) async {
  // Ok
  await txn.execute('CREATE TABLE Test1 (id INTEGER PRIMARY KEY)');
  
  // DON'T  use the database object in a transaction
  // this will deadlock!
  await database.execute('CREATE TABLE Test2 (id INTEGER PRIMARY KEY)');
});
```

A transaction is committed if the callback does not throw an error. If an error is thrown,
the transaction is cancelled. So to rollback a  transaction one way is to throw an exception.


### Batch support

To avoid ping-pong between dart and native code, you can use `Batch`:

```dart
batch = db.batch();
batch.insert('Test', {'name': 'item'});
batch.update('Test', {'name': 'new_item'}, where: 'name = ?', whereArgs: ['item']);
batch.delete('Test', where: 'name = ?', whereArgs: ['item']);
results = await batch.commit();
```

Getting the result for each operation has a cost (id for insertion and number of changes for
update and delete), especially on Android where an extra SQL request is executed.
If you don't care about the result and worry about performance in big batches, you can use

```dart
await batch.commit(noResult: true);
```

Warning, during a transaction, the batch won't be committed until the transaction is committed

```dart
await database.transaction((txn) async {
  var batch = txn.batch();
  
  // ...
  
  // commit but the actual commit will happen when the transaction is committed
  // however the data is available in this transaction
  await batch.commit();
  
  //  ...
});
```

By default a batch stops as soon as it encounters an error (which typically reverts the uncommitted changes). You 
can ignore errors so that every successfull operation is ran and committed even if one operation fails:

```dart
await batch.commit(continueOnError: true);
```

## Table and column names

In general it is better to avoid using SQLite keywords for entity names. If any of the following
name is used:

    "add","all","alter","and","as","autoincrement","between","case","check","collate","commit","constraint","create","default","deferrable","delete","distinct","drop","else","escape","except","exists","foreign","from","group","having","if","in","index","insert","intersect","into","is","isnull","join","limit","not","notnull","null","on","or","order","primary","references","select","set","table","then","to","transaction","union","unique","update","using","values","when","where"
    
the helper will *escape* the name i.e.

```dart
db.query('table')
```
will be equivalent to manually adding double-quote around the table name (confusingly here named `table`)

```dart
db.rawQuery('SELECT * FROM "table"');
```

However in any other raw statement (including `orderBy`, `where`, `groupBy`), make sure to escape the name
properly using double quote. For example see below where the column name `group` is not escaped in the columns
argument, but is escaped in the `where` argument.

```dart
db.query('table', columns: ['group'], where: '"group" = ?', whereArgs: ['my_group']);
```

## Supported SQLite types

No validity check is done on values yet so please avoid non supported types [https://www.sqlite.org/datatype3.html](https://www.sqlite.org/datatype3.html)

`DateTime` is not a supported SQLite type. Personally I store them as 
int (millisSinceEpoch) or string (iso8601)

`bool` is not a supported SQLite type. Use `INTEGER` and 0 and 1 values.

More information on supported types [here](https://github.com/tekartik/sqflite/blob/master/sqflite/doc/supported_types.md).

### INTEGER

* Dart type: `int`
* Supported values: from -2^63 to 2^63 - 1

### REAL

* Dart type: `num`

### TEXT

* Dart type: `String`

### BLOB

* Dart type: `Uint8List`

## Current issues

* Due to the way transaction works in SQLite (threads), concurrent read and write transaction are not supported. 
All calls are currently synchronized and transactions block are exclusive. I thought that a basic way to support 
concurrent access is to open a database multiple times but it only works on iOS as Android reuses the same database object.
I also thought a native thread could be a potential future solution however on android accessing the database in another
thread is blocked while in a transaction...

## More

* [How to](https://github.com/octodb/sqflite/blob/master/sqflite/doc/how_to.md) guide
* [Notes about Desktop support](https://github.com/octodb/sqflite/blob/master/sqflite/doc/desktop_support.md)
