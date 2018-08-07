import 'dart:io';
import 'dart:async';
import 'package:mapper/mapper.dart';

Future initDb<A extends Application>(A app, String sql,
    [doDelete = true]) async {
  if (doDelete) {
    await Process
        .run('psql', ['-d', 'test', '-c', 'DROP SCHEMA public CASCADE']);
    await Process.run('psql', ['-d', 'test', '-c', 'CREATE SCHEMA public']);
    await Process.run('psql', [
      '-d',
      'test',
      '-c',
      'GRANT ALL ON SCHEMA public TO "user" WITH GRANT OPTION'
    ]);
  }
  var pool =
      new Pool('localhost', 5432, 'test', user: 'user', password: 'user');
  await pool.start();
  new Database().registerPool(pool);
  await dbWrap(app, (manager) => manager.query(sql));
}

typedef Future _TrFunction<A extends Application>(Manager<A> manager);
Future dbWrap<A extends Application>(A app, _TrFunction<A> function) async {
  final manager = await new Database().init<A>(app);
  try {
    return await function(manager);
  } finally {
    await manager.close();
  }
}
