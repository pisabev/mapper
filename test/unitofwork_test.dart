import 'package:mapper/mapper.dart';
import 'package:mapper/client.dart';
import 'package:mapper/mapper_test.dart';
import 'package:test/test.dart';

late Manager manager;

main() {
  group('Unit of Work', () {
    setUp(() async {
      manager = await testManager(new DatabaseConfig(),
          executeCreate: false, executeInit: false, sql: sql);
    });
    tearDown(() {});
    test('Basics', () async {
      await manager.begin();
      Test1 t = manager.app.test1.createObject();
      t.field_string = 'test1';
      Test1 t2 = manager.app.test1.createObject();
      t.test1_id = 1;
      t.field_string = 'test2';
      Test1 t3 = manager.app.test1.createObject();
      t.field_string = 'test3';
      manager.addNew(t);
      manager.addNew(t2);
      manager.addNew(t3);
      try {
        await manager.commit();
      } catch (e) {
        expect(e, new isInstanceOf<Exception>());
      }
    }, skip: false);
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

class Test1Mapper extends Mapper<Test1, Test1Collection> {
  String table = 'test1';

  Test1Mapper(m) : super(m);
}

class Test1 with Entity {
  int? test1_id;
  bool? field_bool;
  String? field_string;
  double? field_int;
  Map? field_json;
  Map? field_jsonb;
  DateTime? field_date;
  List? field_list;

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

class Test1Collection extends Collection<Test1> {}

extension AppExt on App {
  Test1Mapper get test1 => new Test1Mapper(m)
    ..entity = (() => new Test1())
    ..collection = () => new Test1Collection();
}
