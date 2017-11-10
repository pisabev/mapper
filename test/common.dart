import 'dart:io';
import 'package:mapper/mapper.dart';

set(Map dataSymbols, String sql, [doDelete = true]) async {
  if(doDelete) {
    await Process.run('psql', ['-d', 'testdatabase', '-c', 'DROP SCHEMA public CASCADE']);
    await Process.run('psql', ['-d', 'testdatabase', '-c', 'CREATE SCHEMA public']);
    await Process.run('psql', ['-d', 'testdatabase', '-c', 'GRANT ALL ON SCHEMA public TO "dbadmin" WITH GRANT OPTION']);
  }
  var pool = new Pool('localhost', 5432, 'test', 'user', 'user');
  await pool.start();
  var manager = new Manager(pool, new Application()..data = dataSymbols);
  await manager.init();
  await manager.query(sql);
  return manager;
}
