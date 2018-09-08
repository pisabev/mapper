import 'dart:async';
import 'dart:io';

import 'package:mapper/mapper.dart';

import 'src/mapper_test/config.dart';
import 'src/mapper_test/private.dart';

export 'src/mapper_test/config.dart';

Future<Null> uninstall(DatabaseConfig c) async {
  try {
    run(await Process.run(
        'psql', [c.userUrl, '-c', 'DROP SCHEMA PUBLIC CASCADE']));
  } catch (e) {
    print('Warning: $e');
  }
  print('UNINSTALL: DONE');
}

Future<Null> install(DatabaseConfig c) async {
  run(await Process.run('psql', [c.userUrl, '-c', 'CREATE SCHEMA PUBLIC']));
  run(await Process.run(
      'psql', [c.userUrl, '-f', '../lib/src/db/schema/create.sql']));
  run(await Process.run(
      'psql', [c.userUrl, '-f', '../lib/src/db/schema/init.sql']));
  print('INSTALL: DONE');
}

Future<Pool> setup(DatabaseConfig c) async {
  final pool = new Pool(c.host, c.port, c.database,
      user: c.username, password: c.password);
  await pool.start();
  new Database().registerPool(pool);
  print('SETUP: DONE');
  return pool;
}
