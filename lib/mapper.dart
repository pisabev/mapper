library mapper_server;

import 'dart:async';
import 'package:logging/logging.dart';
import 'package:postgresql/pool.dart';
import 'package:postgresql/postgresql.dart';
import 'client.dart';

part 'src/application.dart';
part 'src/builder.dart';
part 'src/mapper.dart';
part 'src/connection.dart';
part 'src/manager.dart';
part 'src/unit.dart';
part 'src/entity.dart';
part 'src/cache.dart';
part 'src/exception.dart';

final Logger log = new Logger('Mapper');

class Database<A extends Application> {

    static const String _base = '_';
    static Database instance;

    static Map<String, Function> _managers = new Map();

    factory Database() {
        if (instance == null)
            instance = new Database._();
        return instance;
    }

    Database._();

    static add(Function f, [String namespace = _base]) {
        _managers[namespace] = f;
    }

    Future<Manager<A>> init([String debugId, String namespace = _base]) {
        return _managers[namespace](debugId);
    }
}