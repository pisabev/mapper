import 'dart:async';

import 'package:mapper/mapper_test.dart';

Future<Null> main() async {
  var c = new DatabaseConfig(
    'localhost',
    5432,
    'dbadmin',
    '1234',
    'testdatabase',
  );

  await uninstall(c);
  try {
    await install(c);
    var p = await setup(c);
    await p.destroy(graceful: false);
  } catch (e) {
    print(e);
  }
}