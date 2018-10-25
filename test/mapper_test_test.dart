import 'dart:async';

import 'package:mapper/mapper_test.dart';

Future<void> main() async {
  final c = new DatabaseConfig();

  await drop(c);
  try {
    await create(c);
    final p = await setup(c);
    await p.destroy(graceful: false);
  } catch (e) {
    print(e);
  }
}