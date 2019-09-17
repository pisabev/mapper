import 'package:mapper/client.dart';
import 'package:mapper/mapper.dart';
import 'package:mapper/mapper_test.dart';
import 'package:test/test.dart';

Manager<App> manager;

class AppMixin {
  Manager m;

  Test1Mapper get test1 => new Test1Mapper(m)
    ..entity = (() => new Test1())
    ..collection = () => new Test1Collection();

  Test3Mapper get test3 => new Test3Mapper(m)
    ..entity = (() => new Test3())
    ..collection = (() => new Test3Collection())
    ..notifier = noty;
}

final noty = new EntityNotifier<Test3>();

class AppMixin2 {
  Manager m;

  Test2Mapper get test2 => new Test2Mapper(m)
    ..entity = (() => new Test2())
    ..collection = () => new Test2Collection();
}

class App extends Application with AppMixin {}

class App2 extends Application with AppMixin, AppMixin2 {}

main() {
  group('Mapper', () {
    setUp(() async {
      manager = await testManager(new DatabaseConfig(), new App(),
          executeCreate: false, executeInit: false, sql: sql);

//      var manager2 = manager.convert(new App2());
//      print(manager2.app.test2);
//      var manager3 = manager.convert(new App());
//      print(manager3.app.test1);
    });
    tearDown(() {});

    test('Basics', () async {
      double test = 320000.000032;
      Test1 t = manager.app.test1.createObject();
      final date = new DateTime.now();
      t.field_string = 'test';
      t.field_int = test;
      t.field_bool = true;
      t.field_json = {'t': 1212, 't2': 'string'};
      t.field_jsonb = {'t': 1212, 't2': 'string'};
      t.field_jsonb_obj = new Obj()
        ..field1 = 'ddd'
        ..field2 = 'bbb';
      t.field_date = date;
      t.field_list = [1, 2, 3];

      var res = await manager.app.test1.insert(t);
      expect(res.test1_id, 1);
      expect(res.field_bool, true);

      //await manager.init();
      var res2 = await manager.app.test1.find(1);
      expect(res2.field_list is List, true);
      //print('got ${res2.field_int} expected: $test');
      expect(res2.field_int, test);
      expect(res2.field_bool, true);
      expect(
          res2.field_date.toLocal().toIso8601String(), date.toIso8601String());
      expect(res2.field_jsonb_obj.field1, 'ddd');

      Test1 t2 = manager.app.test1.createObject();
      //t2.field_int = 11.3;
      await manager.app.test1.insert(t2);
      var all = await manager.app.test1.findAll();
      expect(all.length, 2);

      expect(await manager.app.test1.delete(t2), true);
    }, skip: false);

    test('Performance', () async {
      for (int i = 0; i < 10000; i++) {
        Test1 t = manager.app.test1.createObject();
        t.field_string = 'test';
        t.field_int = 232;
        t.field_bool = true;
//      t.field_json = {'t': 1212,'t2': 'string'};
        t.field_jsonb = {'t': 1212, 't2': 'string'};
        t.field_date = new DateTime.now();
        t.field_list = [1, 2, 3];
        await manager.app.test1.insert(t);
      }
      var start = new DateTime.now();
      await manager.app.test1.findAll();
      //await manager.query('select * from test1');
      var end = new DateTime.now();
      print('${end.difference(start).inMilliseconds} ms');
    });
  }, skip: true);

  group('Mapper', () {
    setUp(() async {
      manager = await testManager(new DatabaseConfig(), new App(),
          executeCreate: false, executeInit: false, sql: sql2);

//      var manager2 = manager.convert(new App2());
//      print(manager2.app.test2);
//      var manager3 = manager.convert(new App());
//      print(manager3.app.test1);
    });
    tearDown(() {});
//    test('Notifiers', () async {
//      noty.onChange.listen((r) async {
//        throw new Exception('sds');
//      });
//      Test3 t = manager.app.test3.createObject()
//        ..field_string = 'testnnn';
//      await manager.begin();
//      //await manager.app.test3.insert(t);
//      manager.addNew(t);
//      await manager.commit();
//      var res = await manager.app.test3.find(1);
//      print(res.toMap());
//    });
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
    "field_jsonb_obj" jsonb      ,
    "field_date"      timestamptz,
    "field_list"      jsonb                
);
''';

var sql2 = '''
CREATE TABLE "test3" (
    "test3_id"        serial     NOT NULL PRIMARY KEY,
    "field_string"    text                     
);
''';

class Test1Mapper extends Mapper<Test1, Test1Collection, App> {
  String table = 'test1';

  Test1Mapper(m) : super(m);
}

class Obj {
  String field1;
  String field2;

  Obj();

  factory Obj.fromMap(Map data) => new Obj()
    ..field1 = data['field1']
    ..field2 = data['field2'];

  Map toMap() => {'field1': field1, 'field2': field2};
}

class Test1 with Entity {
  int test1_id;
  bool field_bool;
  String field_string;
  num field_int;
  Map field_json;
  Map field_jsonb;
  Obj field_jsonb_obj;
  DateTime field_date;
  List field_list;

  Test1();

  Test1.fromMap(Map data) {
    init(data);
  }

  init(Map data) {
    test1_id = data['test1_id'];
    field_bool = data['field_bool'];
    field_string = data['field_string'];
    field_int = data['field_int'];
    field_json = data['field_json'];
    field_jsonb = data['field_jsonb'];
    field_jsonb_obj = (data['field_jsonb_obj'] != null)
        ? new Obj.fromMap(data['field_jsonb_obj'])
        : null;
    field_date = data['field_date'];
    field_list = data['field_list'];
  }

  toMap() => {
        'test1_id': test1_id,
        'field_bool': field_bool,
        'field_string': field_string,
        'field_int': field_int,
        'field_json': field_json,
        'field_jsonb': field_jsonb,
        'field_jsonb_obj': field_jsonb_obj?.toMap(),
        'field_date': field_date,
        'field_list': field_list
      };

  toJson() => toMap();
}

class Test1Collection extends Collection<Test1> {}

class Test2Mapper extends Mapper<Test2, Test2Collection, App2> {
  String table = 'test1';

  Test2Mapper(m) : super(m);
}

class Test2 with Entity {
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

class Test2Collection extends Collection<Test2> {}

class Test3Mapper extends Mapper<Test3, Test3Collection, App> {
  String table = 'test3';

  Test3Mapper(m) : super(m);
}

class Test3 with Entity {
  int test3_id;
  String field_string;

  Test3();

  Test3.fromMap(Map data) {
    init(data);
  }

  init(Map data) {
    test3_id = data['test3_id'];
    field_string = data['field_string'];
  }

  toMap() => {
        'test3_id': test3_id,
        'field_string': field_string,
      };

  toJson() => toMap();
}

class Test3Collection extends Collection<Test3> {}
