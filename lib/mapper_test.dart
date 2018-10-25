import 'dart:async';
import 'dart:io';

import 'package:mapper/mapper.dart';

Future<void> drop(DatabaseConfig c) async {
  run(await Process.run(
      'psql', [c.userUrl, '-c', 'DROP SCHEMA PUBLIC CASCADE']));
}

Future<void> create(DatabaseConfig c,
    {List<String> dataFolder, bool executeInit = true}) async {
  run(await Process.run('psql', [c.userUrl, '-c', 'CREATE SCHEMA PUBLIC']));
  run(await Process.run(
      'psql', [c.userUrl, '-f', 'lib/src/db/schema/create.sql']));
  if (dataFolder != null)
    for (var scr in dataFolder)
      run(await Process.run(
          'psql', [c.userUrl, '-f', 'lib/src/db/schema/data/$scr.sql']));
  if (executeInit)
    run(await Process.run(
        'psql', [c.userUrl, '-f', 'lib/src/db/schema/init.sql']));
}

Future<Pool> setup(DatabaseConfig c) async {
  final pool = new Pool(c.host, c.port, c.database,
      user: c.username, password: c.password);
  await pool.start();
  new Database().registerPool(pool);
  return pool;
}

Future<Manager<A>> testMapper<A extends Application>(DatabaseConfig c, A app,
    {bool executeInit = true, String sql}) async {
  await drop(c);
  await create(c, executeInit: executeInit);
  await setup(c);
  final m = await new Database().init(app);
  if (sql != null) await m.query(sql);
  return m;
}

void run(ProcessResult processResult) {
  if (processResult.exitCode != 0) throw new Exception(processResult.stderr);
}

class DatabaseConfig {
  final String host;
  final int port;
  final String username;
  final String password;
  final String database;

  DatabaseConfig(
      {this.host = 'localhost',
      this.port = 5432,
      this.username = 'user',
      this.password = 'user',
      this.database = 'test'});

  String get userUrl => 'postgres://$username:$password@$host:$port/$database';
}
