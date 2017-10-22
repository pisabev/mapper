import 'dart:io';
import 'package:mapper/mapper.dart';

set(Map dataSymbols, String sql) async {
  await Process.run('psql', ['-d', 'test', '-c', 'DROP SCHEMA public CASCADE']);
  await Process.run('psql', ['-d', 'test', '-c', 'CREATE SCHEMA public']);
  await Process.run('psql', ['-d', 'test', '-c', 'GRANT ALL ON SCHEMA public TO "user" WITH GRANT OPTION']);
  var pool = new Pool('localhost', 5432, 'test', 'user', 'user');
  await pool.start();
  var manager = new Manager(pool, new Application()..data = dataSymbols);
  await manager.init();
  await manager.query(sql);
  return manager;
}
