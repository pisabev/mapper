import 'package:mapper/src/postgres.dart';
import 'package:test/test.dart';
import 'dart:io';
import 'dart:async';
import 'dart:mirrors';

getConnectionNoPassword() {
  return new PostgreSQLConnection("localhost", 5432, "test",
      username: "user");
}

getConnectionNormal() {
  return new PostgreSQLConnection("localhost", 5432, "test",
      username: "user", password: "user");
}

getConnectionNormalSsl() {
  return new PostgreSQLConnection("localhost", 5432, "test",
      username: "user", password: "user", useSSL: true);
}

getConnectionNoPasswordSsl() {
  return new PostgreSQLConnection("localhost", 5432, "test",
      username: "user", useSSL: true);
}

void main() {
  group("Connection lifecycle", () {
    PostgreSQLConnection conn = null;

    tearDown(() async {
      await conn?.close();
    });

    test("Connect with md5 auth required", () async {
      conn = getConnectionNormal();

      await conn.open();

      expect(await conn.execute("select 1"), equals(1));
    });

    test("SSL Connect with md5 auth required", () async {
      conn = getConnectionNormalSsl();

      await conn.open();

      expect(await conn.execute("select 1"), equals(1));
      var socketMirror = reflect(conn).type.declarations.values.firstWhere(
          (DeclarationMirror dm) =>
              dm.simpleName.toString().contains("_socket"));
      var underlyingSocket =
          reflect(conn).getField(socketMirror.simpleName).reflectee;
      expect(underlyingSocket is SecureSocket, true);
    });

    /*test("Connect with no auth required", () async {
      conn = getConnectionNoPassword();
      await conn.open();

      expect(await conn.execute("select 1"), equals(1));
    });

    test("SSL Connect with no auth required", () async {
      conn = getConnectionNoPasswordSsl();
      await conn.open();

      expect(await conn.execute("select 1"), equals(1));
    });*/

    test("Closing idle connection succeeds, closes underlying socket",
        () async {
      conn = getConnectionNormal();

      await conn.open();

      await conn.close();

      var socketMirror = reflect(conn).type.declarations.values.firstWhere(
          (DeclarationMirror dm) =>
              dm.simpleName.toString().contains("_socket"));
      Socket underlyingSocket =
          reflect(conn).getField(socketMirror.simpleName).reflectee;
      expect(await underlyingSocket.done, isNotNull);

      conn = null;
    });

    test("SSL Closing idle connection succeeds, closes underlying socket",
        () async {
      conn = getConnectionNormalSsl();
      await conn.open();

      await conn.close();

      var socketMirror = reflect(conn).type.declarations.values.firstWhere(
          (DeclarationMirror dm) =>
              dm.simpleName.toString().contains("_socket"));
      Socket underlyingSocket =
          reflect(conn).getField(socketMirror.simpleName).reflectee;
      expect(await underlyingSocket.done, isNotNull);

      conn = null;
    });

    test(
        "Closing connection while busy succeeds, queued queries are all accounted for (canceled), closes underlying socket",
        () async {
      conn = getConnectionNormal();
      await conn.open();

      var errors = [];
      var futures = [
        conn
            .query("select 1", allowReuse: false)
            .catchError((e) => errors.add(e)),
        conn
            .query("select 2", allowReuse: false)
            .catchError((e) => errors.add(e)),
        conn
            .query("select 3", allowReuse: false)
            .catchError((e) => errors.add(e)),
        conn
            .query("select 4", allowReuse: false)
            .catchError((e) => errors.add(e)),
        conn
            .query("select 5", allowReuse: false)
            .catchError((e) => errors.add(e)),
      ];

      await conn.close();
      await Future.wait(futures);
      expect(errors.length, 5);
      expect(errors.map((e) => e.message),
          everyElement(contains("Connection closed")));
    });

    test(
        "SSL Closing connection while busy succeeds, queued queries are all accounted for (canceled), closes underlying socket",
        () async {
      conn = getConnectionNormalSsl();
      await conn.open();

      var errors = [];
      var futures = [
        conn
            .query("select 1", allowReuse: false)
            .catchError((e) => errors.add(e)),
        conn
            .query("select 2", allowReuse: false)
            .catchError((e) => errors.add(e)),
        conn
            .query("select 3", allowReuse: false)
            .catchError((e) => errors.add(e)),
        conn
            .query("select 4", allowReuse: false)
            .catchError((e) => errors.add(e)),
        conn
            .query("select 5", allowReuse: false)
            .catchError((e) => errors.add(e)),
      ];

      await conn.close();
      await Future.wait(futures);
      expect(errors.length, 5);
      expect(errors.map((e) => e.message),
          everyElement(contains("Connection closed")));
    });
  });

  group("Successful queries over time", () {
    PostgreSQLConnection conn = null;

    setUp(() async {
      conn = getConnectionNormal();
      await conn.open();
    });

    tearDown(() async {
      await conn?.close();
    });

    test(
        "Issuing multiple queries and awaiting between each one successfully returns the right value",
        () async {
      expect(
          await conn.query("select 1", allowReuse: false),
          equals([
            [['?column?', 1]]
          ]));
      expect(
          await conn.query("select 2", allowReuse: false),
          equals([
            [['?column?', 2]]
          ]));
      expect(
          await conn.query("select 3", allowReuse: false),
          equals([
            [['?column?', 3]]
          ]));
      expect(
          await conn.query("select 4", allowReuse: false),
          equals([
            [['?column?', 4]]
          ]));
      expect(
          await conn.query("select 5", allowReuse: false),
          equals([
            [['?column?', 5]]
          ]));
    });

    test(
        "Issuing multiple queries without awaiting are returned with appropriate values",
        () async {
      var futures = [
        conn.query("select 1", allowReuse: false),
        conn.query("select 2", allowReuse: false),
        conn.query("select 3", allowReuse: false),
        conn.query("select 4", allowReuse: false),
        conn.query("select 5", allowReuse: false)
      ];

      var results = await Future.wait(futures);

      expect(results, [
        [
          [['?column?', 1]]
        ],
        [
          [['?column?', 2]]
        ],
        [
          [['?column?', 3]]
        ],
        [
          [['?column?', 4]]
        ],
        [
          [['?column?', 5]]
        ]
      ]);
    });
  });

  group("Unintended user-error situations", () {
    PostgreSQLConnection conn = null;

    tearDown(() async {
      await conn?.close();
    });

    test("Sending queries to opening connection triggers error", () async {
      conn = getConnectionNormal();
      conn.open();

      try {
        await conn.execute("select 1");
        expect(true, false);
      } on PostgreSQLException catch (e) {
        expect(e.message, contains("connection is not open"));
      }
    });

    test("SSL Sending queries to opening connection triggers error", () async {
      conn = getConnectionNormalSsl();
      conn.open();

      try {
        await conn.execute("select 1");
        expect(true, false);
      } on PostgreSQLException catch (e) {
        expect(e.message, contains("connection is not open"));
      }
    });

    test("Starting transaction while opening connection triggers error",
        () async {
      conn = getConnectionNormal();
      conn.open();

      try {
        await conn.transaction((ctx) async {
          await ctx.execute("select 1");
        });
        expect(true, false);
      } on PostgreSQLException catch (e) {
        expect(e.message, contains("connection is not open"));
      }
    });

    test("SSL Starting transaction while opening connection triggers error",
        () async {
      conn = getConnectionNormalSsl();
      conn.open();

      try {
        await conn.transaction((ctx) async {
          await ctx.execute("select 1");
        });
        expect(true, false);
      } on PostgreSQLException catch (e) {
        expect(e.message, contains("connection is not open"));
      }
    });

    test("Invalid password reports error, conn is closed, disables conn",
        () async {
      conn = new PostgreSQLConnection("localhost", 5432, "test",
          username: "user", password: "wrongpass");

      try {
        await conn.open();
        expect(true, false);
      } on PostgreSQLException catch (e) {
        expect(e.message, contains("password authentication failed"));
      }

      await expectConnectionIsInvalid(conn);
    });

    test("SSL Invalid password reports error, conn is closed, disables conn",
        () async {
      conn = new PostgreSQLConnection("localhost", 5432, "test",
          username: "user", password: "wrongpass", useSSL: true);

      try {
        await conn.open();
        expect(true, false);
      } on PostgreSQLException catch (e) {
        expect(e.message, contains("password authentication failed"));
      }

      await expectConnectionIsInvalid(conn);
    });

    test("A query error maintains connectivity, allows future queries",
        () async {
      conn = getConnectionNormal();
      await conn.open();

      await conn.execute("CREATE TEMPORARY TABLE t (i int unique)");
      await conn.execute("INSERT INTO t (i) VALUES (1)");
      try {
        await conn.execute("INSERT INTO t (i) VALUES (1)");
        expect(true, false);
      } on PostgreSQLException catch (e) {
        expect(e.message, contains("duplicate key value violates"));
      }

      await conn.execute("INSERT INTO t (i) VALUES (2)");
    });

    test(
        "A query error maintains connectivity, continues processing pending queries",
        () async {
      conn = getConnectionNormal();
      await conn.open();

      await conn.execute("CREATE TEMPORARY TABLE t (i int unique)");

      await conn.execute("INSERT INTO t (i) VALUES (1)");
      conn.execute("INSERT INTO t (i) VALUES (1)").catchError((err) {
        // ignore
      });

      var futures = [
        conn.query("select 1", allowReuse: false),
        conn.query("select 2", allowReuse: false),
        conn.query("select 3", allowReuse: false),
      ];
      var results = await Future.wait(futures);

      expect(results, [
        [
          [['?column?', 1]]
        ],
        [
          [['?column?', 2]]
        ],
        [
          [['?column?', 3]]
        ]
      ]);

      var queueMirror = reflect(conn).type.declarations.values.firstWhere(
          (DeclarationMirror dm) =>
              dm.simpleName.toString().contains("_queryQueue"));
      List<dynamic> queue =
          reflect(conn).getField(queueMirror.simpleName).reflectee;
      expect(queue, isEmpty);
    });

    test(
        "A query error maintains connectivity, continues processing pending transactions",
        () async {
      conn = getConnectionNormal();
      await conn.open();

      await conn.execute("CREATE TEMPORARY TABLE t (i int unique)");
      await conn.execute("INSERT INTO t (i) VALUES (1)");

      var orderEnsurer = [];
      conn.execute("INSERT INTO t (i) VALUES (1)").catchError((err) {
        orderEnsurer.add(1);
        // ignore
      });

      orderEnsurer.add(2);
      var res = await conn.transaction((ctx) async {
        orderEnsurer.add(3);
        return await ctx.query("SELECT i FROM t");
      });
      orderEnsurer.add(4);

      expect(res, [
        [['i', 1]]
      ]);
      expect(orderEnsurer, [2, 1, 3, 4]);
    });

    test(
        "Building query throws error, connection continues processing pending queries",
        () async {
      conn = getConnectionNormal();
      await conn.open();

      // Make some async queries that'll exit the event loop, but then fail on a query that'll die early
      conn.execute("askdl").catchError((err, st) {});
      conn.execute("abdef").catchError((err, st) {});
      conn.execute("select @a").catchError((err, st) {});

      var futures = [
        conn.query("select 1", allowReuse: false),
        conn.query("select 2", allowReuse: false),
      ];
      var results = await Future.wait(futures);

      expect(results, [
        [
          [['?column?', 1]]
        ],
        [
          [['?column?', 2]]
        ]
      ]);

      var queueMirror = reflect(conn).type.declarations.values.firstWhere(
          (DeclarationMirror dm) =>
              dm.simpleName.toString().contains("_queryQueue"));
      List<dynamic> queue =
          reflect(conn).getField(queueMirror.simpleName).reflectee;
      expect(queue, isEmpty);
    });
  });

  group("Network error situations", () {
    ServerSocket serverSocket = null;
    Socket socket = null;

    tearDown(() async {
      await serverSocket?.close();
      await socket?.close();
    });

    test(
        "Socket fails to connect reports error, disables connection for future use",
        () async {
      var conn = new PostgreSQLConnection("localhost", 5431, "test");

      try {
        await conn.open();
        expect(true, false);
      } on SocketException {}

      await expectConnectionIsInvalid(conn);
    });

    test(
        "SSL Socket fails to connect reports error, disables connection for future use",
        () async {
      var conn = new PostgreSQLConnection("localhost", 5431, "test",
          useSSL: true);

      try {
        await conn.open();
        expect(true, false);
      } on SocketException {}

      await expectConnectionIsInvalid(conn);
    });

    test(
        "Connection that times out throws appropriate error and cannot be reused",
        () async {
      serverSocket =
          await ServerSocket.bind(InternetAddress.LOOPBACK_IP_V4, 5433);
      serverSocket.listen((s) {
        socket = s;
        // Don't respond on purpose
        s.listen((bytes) {});
      });

      var conn = new PostgreSQLConnection("localhost", 5433, "test",
          timeoutInSeconds: 2);

      try {
        await conn.open();
      } on PostgreSQLException catch (e) {
        expect(e.message, contains("Timed out trying to connect"));
      }

      await expectConnectionIsInvalid(conn);
    });

    test(
        "SSL Connection that times out throws appropriate error and cannot be reused",
        () async {
      serverSocket =
          await ServerSocket.bind(InternetAddress.LOOPBACK_IP_V4, 5433);
      serverSocket.listen((s) {
        socket = s;
        // Don't respond on purpose
        s.listen((bytes) {});
      });

      var conn = new PostgreSQLConnection("localhost", 5433, "test",
          timeoutInSeconds: 2, useSSL: true);

      try {
        await conn.open();
      } on PostgreSQLException catch (e) {
        expect(e.message, contains("Timed out trying to connect"));
      }

      await expectConnectionIsInvalid(conn);
    });

    test("Connection that times out triggers future for pending queries",
        () async {
      var openCompleter = new Completer();
      serverSocket =
          await ServerSocket.bind(InternetAddress.LOOPBACK_IP_V4, 5433);
      serverSocket.listen((s) {
        socket = s;
        // Don't respond on purpose
        s.listen((bytes) {});
        new Future.delayed(new Duration(milliseconds: 100), () {
          openCompleter.complete();
        });
      });

      var conn = new PostgreSQLConnection("localhost", 5433, "test",
          timeoutInSeconds: 2);
      conn.open().catchError((e) {});

      await openCompleter.future;

      try {
        await conn.execute("select 1");
        expect(true, false);
      } on PostgreSQLException catch (e) {
        expect(e.message, contains("closed or query cancelled"));
      }
    });

    test("SSL Connection that times out triggers future for pending queries",
        () async {
      var openCompleter = new Completer();
      serverSocket =
          await ServerSocket.bind(InternetAddress.LOOPBACK_IP_V4, 5433);
      serverSocket.listen((s) {
        socket = s;
        // Don't respond on purpose
        s.listen((bytes) {});
        new Future.delayed(new Duration(milliseconds: 100), () {
          openCompleter.complete();
        });
      });

      var conn = new PostgreSQLConnection("localhost", 5433, "test",
          timeoutInSeconds: 2, useSSL: true);
      conn.open().catchError((e) {});

      await openCompleter.future;

      try {
        await conn.execute("select 1");
        expect(true, false);
      } on PostgreSQLException catch (e) {
        expect(e.message, contains("but connection is not open"));
      }

      try {
        await conn.open();
        expect(true, false);
      } on PostgreSQLException {}
    });
  });
}

Future expectConnectionIsInvalid(PostgreSQLConnection conn) async {
  try {
    await conn.execute("select 1");
    expect(true, false);
  } on PostgreSQLException catch (e) {
    expect(e.message, contains("connection is not open"));
  }

  try {
    await conn.open();
    expect(true, false);
  } on PostgreSQLException catch (e) {
    expect(e.message, contains("Attempting to reopen a closed connection"));
  }
}