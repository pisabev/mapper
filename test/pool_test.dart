import 'dart:async';
import 'package:mapper/mapper.dart';
import 'package:mapper/client.dart';
import 'package:test/test.dart';

main() {
  test('Pool 1', () async {
    var connection = new Pool('postgres://user:user@localhost:5432/test');
    await connection.start();
    connection.obtain();
    connection.obtain();
    connection.obtain();
    connection.obtain();
    connection.obtain();
    expect(connection.obtain().then((con) {
      // Not able to obtain
    }).timeout(new Duration(seconds: 2)), throwsA(new isInstanceOf<TimeoutException>()));

  });
  test('Pool 2', () async {
    var connection = new Pool('postgres://user:user@localhost:5432/test');
    await connection.start();
    connection.obtain().then((conn) async {
      await new Future.delayed(new Duration(seconds: 1));
      connection.release(conn);
    });
    connection.obtain();
    connection.obtain();
    connection.obtain();
    connection.obtain();
    var con = await connection.obtain(timeout: new Duration(seconds: 2));
    expect(con != null, true);

  }, skip: false);
  test('Pool 3', () async {
    var connection = new Pool('postgres://user:user@localhost:5432/test');
    await connection.start();
    var con1 = await connection.obtain();
    var con2 = await connection.obtain();
    var con3 = await connection.obtain();
    var con4 = await connection.obtain();
    var con5 = await connection.obtain();
    expect(connection.obtain().then((con) {
      // Not able to obtain
    }).timeout(new Duration(seconds: 2)), throwsA(new isInstanceOf<TimeoutException>()));
  }, skip: false);
  test('Pool 4', () async {
    var connection = new Pool('postgres://user:user@localhost:5432/test');
    await connection.start();
    var con1 = await connection.obtain().then((conn) async {
      await new Future.delayed(new Duration(seconds: 1));
      connection.release(conn);
    });
    var con2 = await connection.obtain();
    var con3 = await connection.obtain();
    var con4 = await connection.obtain();
    var con5 = await connection.obtain();
    var con = await connection.obtain(timeout: new Duration(seconds: 2));
    expect(con != null, true);
  }, skip: false);
  test('Pool 5', () async {
    var connection = new Pool('postgres://user:user@localhost:5432/test');
    await connection.start();
    expect(connection.connectionsIdle.length, 1);
  }, skip: false);
  test('Pool 6', () async {
    var connection = new Pool('postgres://user:user@localhost:5432/test', 2, 5);
    await connection.start();
    expect(connection.connectionsIdle.length, 2);
  }, skip: false);
  test('Pool 7', () async {
    var connection = new Pool('postgres://user:user@localhost:5432/test', 6, 5);
    await connection.start();
    expect(connection.connectionsIdle.length, 6);
  }, skip: false);
  test('Pool 8', () async {
    var connection = new Pool('postgres://user:user@localhost:5432/test');
    await connection.start();
    var con1 = await connection.obtain();
    var con2 = await connection.obtain();
    var con3 = await connection.obtain();

    await connection.release(con1);
    expect(connection.connectionsIdle.length, 1);
  }, skip: false);
}
