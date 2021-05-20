import 'package:mapper/src/postgres.dart';
import 'package:test/test.dart';

void main() {
  late PostgreSQLConnection connection;

  setUp(() async {
    connection = new PostgreSQLConnection("localhost", 5432, "test", username: "user", password: "user");
    await connection.open();

    await connection.execute("""
        CREATE TEMPORARY TABLE t (j jsonb)
    """);
  });

  tearDown(() async {
    await connection.close();
  });

  group("Storage", () {
    test("Can store JSON String", () async {
      var result = await connection.query("INSERT INTO t (j) VALUES ('\"xyz\"'::jsonb) RETURNING j");
      var r = result.map((v) => v.values.toList()).toList();
      expect(r, [["xyz"]]);
      result = await connection.query("SELECT j FROM t");
      r = result.map((v) => v.values.toList()).toList();
      expect(r, [["xyz"]]);
    });

    test("Can store JSON String with driver type annotation", () async {
      var result = await connection.query("INSERT INTO t (j) VALUES (@a:jsonb) RETURNING j", substitutionValues: {
        "a" : "xyz"
      });
      var r = result.map((v) => v.values.toList()).toList();
      expect(r, [["xyz"]]);
      result = await connection.query("SELECT j FROM t");
      r = result.map((v) => v.values.toList()).toList();
      expect(r, [["xyz"]]);
    });

    test("Can store JSON Number", () async {
      var result = await connection.query("INSERT INTO t (j) VALUES ('4'::jsonb) RETURNING j");
      var r = result.map((v) => v.values.toList()).toList();
      expect(r, [[4]]);
      result = await connection.query("SELECT j FROM t");
      r = result.map((v) => v.values.toList()).toList();
      expect(r, [[4]]);
    });

    test("Can store JSON Number with driver type annotation", () async {
      var result = await connection.query("INSERT INTO t (j) VALUES (@a:jsonb) RETURNING j", substitutionValues: {
        "a": 4
      });
      var r = result.map((v) => v.values.toList()).toList();
      expect(r, [[4]]);
      result = await connection.query("SELECT j FROM t");
      r = result.map((v) => v.values.toList()).toList();
      expect(r, [[4]]);
    });

    test("Can store JSON map", () async {
      var result = await connection.query("INSERT INTO t (j) VALUES ('{\"a\":4}') RETURNING j");
      var r = result.map((v) => v.values.toList()).toList();
      expect(r, [[{"a":4}]]);
      result = await connection.query("SELECT j FROM t");
      r = result.map((v) => v.values.toList()).toList();
      expect(r, [[{"a":4}]]);
    });

    test("Can store JSON map with driver type annotation", () async {
      var result = await connection.query("INSERT INTO t (j) VALUES (@a:jsonb) RETURNING j", substitutionValues: {
        "a": {"a":4}
      });
      var r = result.map((v) => v.values.toList()).toList();
      expect(r, [[{"a":4}]]);
      result = await connection.query("SELECT j FROM t");
      r = result.map((v) => v.values.toList()).toList();
      expect(r, [[{"a":4}]]);
    });

    test("Can store JSON list", () async {
      var result = await connection.query("INSERT INTO t (j) VALUES ('[{\"a\":4}]') RETURNING j");
      var r = result.map((v) => v.values.toList()).toList();
      expect(r, [[[{"a":4}]]]);
      result = await connection.query("SELECT j FROM t");
      r = result.map((v) => v.values.toList()).toList();
      expect(r, [[[{"a":4}]]]);
    });

    test("Can store JSON list with driver type annotation", () async {
      var result = await connection.query("INSERT INTO t (j) VALUES (@a:jsonb) RETURNING j", substitutionValues: {
        "a": [{"a":4}]
      });
      var r = result.map((v) => v.values.toList()).toList();
      expect(r, [[[{"a":4}]]]);
      result = await connection.query("SELECT j FROM t");
      r = result.map((v) => v.values.toList()).toList();
      expect(r, [[[{"a":4}]]]);
    });
  });
}
