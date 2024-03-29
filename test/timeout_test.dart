import 'package:mapper/src/postgres.dart';
import 'package:test/test.dart';
import 'dart:async';

void main() {
  late PostgreSQLConnection conn;

  setUp(() async {
    conn = new PostgreSQLConnection("localhost", 5432, "test", username: "user", password: "user");
    await conn.open();
    await conn.execute("CREATE TEMPORARY TABLE t (id INT UNIQUE)");
  });

  tearDown(() async {
    await conn.close();
  });

  test("Timeout fires on query while in queue does not execute query, query throws exception", () async {
    //ignore: unawaited_futures
    final f = conn.query("SELECT pg_sleep(2)");
    try {
      await conn.query("SELECT 1", timeoutInSeconds: 1);
      fail('unreachable');
    } on TimeoutException {}

    expect(f, completes);
  });

  test("Timeout fires during transaction rolls ack transaction", () async {
    try {
      await conn.transaction((ctx) async {
        await ctx.query("INSERT INTO t (id) VALUES (1)");
        await ctx.query("SELECT pg_sleep(2)", timeoutInSeconds: 1);
      });
      fail('unreachable');
    } on TimeoutException {}

    expect(await conn.query("SELECT * from t"), hasLength(0));
  });

  test("Query on parent context for transaction completes (with error) after timeout", () async {
    try {
      await conn.transaction((ctx) async {
        await conn.query("SELECT 1", timeoutInSeconds: 1);
        await ctx.query("INSERT INTO t (id) VALUES (1)");
      });
      fail('unreachable');
    } on TimeoutException {}

    expect(await conn.query("SELECT * from t"), hasLength(0));
  });

  test("If query is already on the wire and times out, safely throws timeoutexception and nothing else", () async {
    try {
      await conn.query("SELECT pg_sleep(2)", timeoutInSeconds: 1);
      fail('unreachable');
    } on TimeoutException {}
  });

  test("Query times out, next query in the queue runs", () async {
    //ignore: unawaited_futures
    conn.query("SELECT pg_sleep(2)", timeoutInSeconds: 1).catchError((_) => null);
    var res = await conn.query("SELECT 1");
    var result = res.map((r) => r.values.toList()).toList();
    expect(result, [[1]]);
  });

  test("Query that succeeds does not timeout", () async {
    await conn.query("SELECT 1", timeoutInSeconds: 1);
    expect(new Future.delayed(new Duration(seconds: 2)), completes);
  });

  test("Query that fails does not timeout", () async {
    await conn.query("INSERT INTO t (id) VALUES ('foo')", timeoutInSeconds: 1).catchError((_) {
      return new Future.value([{'no': 'res'}]);
    });
    expect(new Future.delayed(new Duration(seconds: 2)), completes);
  }, solo: true);
}
