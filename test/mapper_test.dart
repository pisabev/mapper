import 'package:mapper/mapper.dart';
import 'package:mapper/client.dart';
import 'package:test/test.dart';

import 'common.dart';

Manager<App> manager;

class App extends Application {
  Test1Mapper test1;
}

main() {
  test('', () async {
    var app = {};
    app[#test1] = () => new Test1Mapper()
      ..entity = (() => new Test1())
      ..collection = () => new Test1Collection();
    manager = await set(app, sql);
  });
  test('Mapper Basics', () async {
    Test1 t = manager.app.test1.createObject();
    t.field_string = 'test';
    t.field_int = 10.3;
    var res = await manager.app.test1.insert(t);
    expect(res.field_int, 10.3);

    /*var res2 = await manager.app.test1.find(1);
    expect(res2.field_string, 'test');

    Test1 t2 = manager.app.test1.createObject();
    //t2.field_int = 11.3;
    await manager.app.test1.insert(t2);
    var all = await manager.app.test1.findAll();
    expect(all.length, 2);

    expect(await manager.app.test1.delete(t2), true);*/
  });
}



var sql = '''
CREATE TABLE IF NOT EXISTS "test1" (
    "test1_id"        serial     NOT NULL PRIMARY KEY,
    "field_string"    text       ,
    "field_int"       decimal(12,2)     
);
''';

class Test1Mapper extends Mapper<Test1, Test1Collection, App> {
  String table = 'test1';
}

class Test1 extends Entity {
  int test1_id;
  String field_string;
  double field_int;

  Test1();

  Test1.fromMap(Map data) {
    init(data);
  }

  init(Map data) {
    test1_id = data['test1_id'];
    field_string = data['field_string'];
    field_int = data['field_int'];
  }

  toMap() => {
    'test1_id': test1_id,
    'field_string': field_string,
    'field_int': field_int,
  };

  toJson() => toMap();
}

class Test1Collection extends Collection<Test1> {

}