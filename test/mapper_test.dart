import 'package:mapper/mapper.dart';
import 'package:mapper/client.dart';
import 'package:test/test.dart';

import 'common.dart';

Manager<App> manager;

class AppMixin {
  Manager m;
  Test1Mapper get test1 => new Test1Mapper()
    ..manager = m
    ..entity = (() => new Test1())
    ..collection = () => new Test1Collection();
}

class AppMixin2 {
  Manager m;
  Test2Mapper get test2 => new Test2Mapper()
    ..manager = m
    ..entity = (() => new Test2())
    ..collection = () => new Test2Collection();
}

class App extends Application with AppMixin {}

class App2 extends Application with AppMixin, AppMixin2 {}

main() {
  group('Mapper', () {
    setUp(() async {
      await initDb(new App(), sql);
      manager = await new Database().init(new App());
//      var manager2 = manager.convert(new App2());
//      print(manager2.app.test2);
//      var manager3 = manager.convert(new App());
//      print(manager3.app.test1);
    });
    tearDown(() {

    });

    test('Basics', () async {
      double test = 320000.000032;
      Test1 t = manager.app.test1.createObject();
      t.field_string = 'test';
      t.field_int = test;
      t.field_bool = true;
      t.field_json = {'t': 1212,'t2': 'string'};
      t.field_jsonb = {'t': 1212,'t2': 'string'};
      t.field_date = new DateTime.now();
      t.field_list = [1,2,3];

      var res = await manager.app.test1.insert(t);
      expect(res.test1_id, 1);
      expect(res.field_bool, true);

      //await manager.init();
      var res2 = await manager.app.test1.find(1);
      expect(res2.field_list is List, true);
      //print('got ${res2.field_int} expected: $test');
      expect(res2.field_int, test);
      expect(res2.field_bool, true);

      Test1 t2 = manager.app.test1.createObject();
      //t2.field_int = 11.3;
      await manager.app.test1.insert(t2);
      var all = await manager.app.test1.findAll();
      expect(all.length, 2);

      expect(await manager.app.test1.delete(t2), true);
    }, skip: false);
  });

  test('Performance', () async {
    for(int i = 0; i < 50000; i++) {
      Test1 t = manager.app.test1.createObject();
      t.field_string = 'test';
      t.field_int = 232.3;
      t.field_bool = true;
      t.field_json = {'t': 1212,'t2': 'string'};
      t.field_jsonb = {'t': 1212,'t2': 'string'};
      t.field_date = new DateTime.now();
      t.field_list = [1,2,3];
      await manager.app.test1.insert(t);
    }
    var start = new DateTime.now();
    await manager.app.test1.findAll();
    //await manager.query('select * from test1');
    var end = new DateTime.now();
    print('${end.difference(start).inMilliseconds} ms');
  });

}

var sql = '''
CREATE TEMPORARY TABLE "test1" (
    "test1_id"        serial     NOT NULL PRIMARY KEY,
    "field_bool"      bool       ,
    "field_string"    text       ,
    "field_int"       decimal(12,6),
    "field_json"      json       ,
    "field_jsonb"     jsonb      ,
    "field_date"      timestamptz,
    "field_list"      jsonb                
);
''';

class Test1Mapper extends Mapper<Test1, Test1Collection, App> {
  String table = 'test1';
}

class Test1 extends Entity {
  int test1_id;
  bool field_bool;
  String field_string;
  double field_int;
  Map field_json;
  Map field_jsonb;
  DateTime field_date;
  List field_list;

  Test1();

  Test1.fromMap(Map data) {
    init(data);
  }

  init(Map data) {
    test1_id = data['test1_id'];
    field_string = data['field_string'];
    field_int = data['field_int'];
    field_json = data['field_json'];
    field_jsonb = data['field_jsonb'];
    field_date = data['field_date'];
    field_list = data['field_list'];
  }

  toMap() => {
    'test1_id': test1_id,
    'field_string': field_string,
    'field_int': field_int,
    'field_json': field_json,
    'field_jsonb': field_jsonb,
    'field_date': field_date,
    'field_list': field_list
  };

  toJson() => toMap();
}

class Test1Collection extends Collection<Test1> {

}

class Test2Mapper extends Mapper<Test2, Test2Collection, App2> {
  String table = 'test1';
}

class Test2 extends Entity {
  int test1_id;
  bool field_bool;
  String field_string;
  double field_int;
  Map field_json;
  Map field_jsonb;
  DateTime field_date;
  List field_list;

  Test2();

  Test2.fromMap(Map data) {
    init(data);
  }

  init(Map data) {
    test1_id = data['test1_id'];
    field_string = data['field_string'];
    field_int = data['field_int'];
    field_json = data['field_json'];
    field_jsonb = data['field_jsonb'];
    field_date = data['field_data'];
    field_list = data['field_list'];
  }

  toMap() => {
    'test1_id': test1_id,
    'field_string': field_string,
    'field_int': field_int,
    'field_json': field_json,
    'field_jsonb': field_jsonb,
    'field_date': field_date,
    'field_list': field_list
  };

  toJson() => toMap();
}

class Test2Collection extends Collection<Test2> {

}