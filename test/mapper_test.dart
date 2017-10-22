import 'package:mapper/mapper.dart';
import 'package:mapper/client.dart';
import 'package:test/test.dart';

import 'common.dart';

Manager<App> manager;

class App extends Application {
  Test1Mapper test1;
}

main() {
  var app = {};
  app[#test1] = () => new Test1Mapper()
    ..entity = (() => new Test1())
    ..collection = () => new Test1Collection();
  test('', () async {
    manager = await set(app, sql);
  });
  test('Mapper Basics', () async {
    double test = 122.0;
    Test1 t = manager.app.test1.createObject();
    t.field_string = 'test';
    t.field_int = test;
    t.field_json = {'t': 1212,'t2': 'string'};
    t.field_jsonb = {'t': 1212,'t2': 'string'};
    t.field_date = new DateTime.now();
    t.field_list = [1,2,3];

    var res = await manager.app.test1.insert(t);
    expect(res.field_int, test);

    //await manager.init();
    var res2 = await manager.app.test1.find(1);
    expect(res2.field_list is List, true);

    Test1 t2 = manager.app.test1.createObject();
    //t2.field_int = 11.3;
    await manager.app.test1.insert(t2);
    var all = await manager.app.test1.findAll();
    expect(all.length, 2);

    expect(await manager.app.test1.delete(t2), true);
  });
}



var sql = '''
CREATE TABLE IF NOT EXISTS "test1" (
    "test1_id"        serial     NOT NULL PRIMARY KEY,
    "field_string"    text       ,
    "field_int"       decimal(12,2),
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

class Test1Collection extends Collection<Test1> {

}