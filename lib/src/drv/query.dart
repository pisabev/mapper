import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:mapper/mapper.dart';
import 'package:mapper/src/drv/binary_codec.dart';
import 'package:mapper/src/drv/execution_context.dart';
import 'package:mapper/src/drv/text_codec.dart';

import 'client_messages.dart';
import 'connection.dart';
import 'substituter.dart';
import 'types.dart';

class Query<T> {
  Query(this.statement, this.substitutionValues, this.connection,
      this.transaction);

  bool onlyReturnAffectedRowCount = false;

  String? statementIdentifier;

  Future<T> get future => _onComplete.future;

  final String statement;
  final Map<String, dynamic>? substitutionValues;
  final PostgreSQLExecutionContext? transaction;
  final PostgreSQLConnection connection;

  late List<PostgreSQLDataType?> specifiedParameterTypeCodes;
  List<Map<String, dynamic>> rows = [];

  CachedQuery? cache;

  final Completer<T> _onComplete = new Completer.sync();
  List<FieldDescription>? _fieldDescriptions;

  List<FieldDescription>? get fieldDescriptions => _fieldDescriptions;

  set fieldDescriptions(List<FieldDescription>? fds) {
    _fieldDescriptions = fds;
    cache?.fieldDescriptions = fds;
  }

  void sendSimple(Socket socket) {
    final sqlString =
        PostgreSQLFormat.substitute(statement, substitutionValues);
    final queryMessage = new QueryMessage(sqlString);

    socket.add(queryMessage.asBytes());
  }

  void sendExtended(Socket socket, {CachedQuery? cacheQuery}) {
    if (cacheQuery != null) {
      fieldDescriptions = cacheQuery.fieldDescriptions;
      sendCachedQuery(socket, cacheQuery, substitutionValues);

      return;
    }

    final String statementName = statementIdentifier ?? '';
    final formatIdentifiers = <PostgreSQLFormatIdentifier>[];
    final sqlString = PostgreSQLFormat.substitute(statement, substitutionValues,
        replace: (identifier, index) {
      formatIdentifiers.add(identifier);
      return '\$$index';
    });

    specifiedParameterTypeCodes = formatIdentifiers.map((i) => i.type).toList();

    final parameterList = formatIdentifiers
        .map((id) => new ParameterValue(id, substitutionValues))
        .toList();

    final messages = [
      new ParseMessage(sqlString, statementName: statementName),
      new DescribeMessage(statementName: statementName),
      new BindMessage(parameterList, statementName: statementName),
      new ExecuteMessage(),
      new SyncMessage()
    ];

    if (statementIdentifier != null) {
      cache = new CachedQuery(statementIdentifier!, formatIdentifiers);
    }

    socket.add(ClientMessage.aggregateBytes(messages));
  }

  void sendCachedQuery(Socket socket, CachedQuery cacheQuery,
      Map<String, dynamic>? substitutionValues) {
    final statementName = cacheQuery.preparedStatementName;
    final parameterList = cacheQuery.orderedParameters
        .map((identifier) => new ParameterValue(identifier, substitutionValues))
        .toList();

    final bytes = ClientMessage.aggregateBytes([
      new BindMessage(parameterList, statementName: statementName),
      new ExecuteMessage(),
      new SyncMessage()
    ]);

    socket.add(bytes);
  }

  PostgreSQLException? validateParameters(List<int> parameterTypeIDs) {
    final actualParameterTypeCodeIterator = parameterTypeIDs.iterator;
    final parametersAreMismatched =
        specifiedParameterTypeCodes.map((specifiedType) {
      actualParameterTypeCodeIterator.moveNext();

      if (specifiedType == null) {
        return true;
      }

      final actualType = PostgresBinaryDecoder
          .typeMap[actualParameterTypeCodeIterator.current];
      return actualType == specifiedType;
    }).any((v) => v == false);

    if (parametersAreMismatched) {
      return new PostgreSQLException(
          'Specified parameter types do not match column parameter '
          'types in query $statement');
    }

    return null;
  }

  void addRow(List<ByteData?> rawRowData) {
    if (onlyReturnAffectedRowCount) {
      return;
    }

    final iterator = fieldDescriptions!.iterator;
    final m = <String, dynamic>{};
    for (final bd in rawRowData) {
      iterator.moveNext();
      m[iterator.current.fieldName] = iterator.current.converter
          .convert(bd?.buffer.asUint8List(bd.offsetInBytes, bd.lengthInBytes));
    }

    rows.add(m);
  }

  void complete(int rowsAffected) {
    if (_onComplete.isCompleted) {
      return;
    }

    if (onlyReturnAffectedRowCount) {
      _onComplete.complete(rowsAffected as T);
      return;
    }

    _onComplete.complete(rows as T);
  }

  void completeError(dynamic error, [StackTrace? stackTrace]) {
    if (_onComplete.isCompleted) {
      return;
    }

    _onComplete.completeError(error, stackTrace);
  }

  String toString() => statement;
}

class QueryCollection<T> extends Query<T> {
  late Entity Function(Map<String, dynamic>) buildEntity;
  late Collection<Entity> collection;

  QueryCollection(statement, substitutionValues, connection, transaction)
      : super(statement, substitutionValues, connection, transaction);

  void addRow(List<ByteData?> rawRowData) {
    final iterator = fieldDescriptions!.iterator;
    final m = <String, dynamic>{};
    for (final bd in rawRowData) {
      iterator.moveNext();
      m[iterator.current.fieldName] = iterator.current.converter
          .convert(bd?.buffer.asUint8List(bd.offsetInBytes, bd.lengthInBytes));
    }

    if (m['__total__'] != null) collection.totalResults = m['__total__'];

    collection.add(buildEntity(m));
  }

  void complete(int rowsAffected) {
    if (_onComplete.isCompleted) {
      return;
    }

    _onComplete.complete(collection as T);
  }
}

class CachedQuery {
  CachedQuery(this.preparedStatementName, this.orderedParameters);

  final String preparedStatementName;
  final List<PostgreSQLFormatIdentifier> orderedParameters;
  List<FieldDescription>? fieldDescriptions;

  bool get isValid => fieldDescriptions != null;
}

class ParameterValue {
  factory ParameterValue(PostgreSQLFormatIdentifier identifier,
      Map<String, dynamic>? substitutionValues) {
    if (identifier.type == null) {
      return new ParameterValue.text(substitutionValues?[identifier.name]);
    }

    return new ParameterValue.binary(
        substitutionValues?[identifier.name], identifier.type!);
  }

  ParameterValue.binary(dynamic value, PostgreSQLDataType postgresType)
      : isBinary = true {
    final converter = new PostgresBinaryEncoder(postgresType);
    bytes = converter.convert(value);
    length = bytes?.length ?? 0;
  }

  ParameterValue.text(dynamic value) : isBinary = false {
    if (value != null) {
      const converter = const PostgresTextEncoder(false);
      bytes = utf8.encode(converter.convert(value)) as Uint8List;
    }
    length = bytes?.length ?? 0;
  }

  final bool isBinary;
  Uint8List? bytes;
  late int length;
}

class FieldDescription {
  late Converter converter;

  late String fieldName;
  late int tableID;
  late int columnID;
  late int typeID;
  late int dataTypeSize;
  late int typeModifier;
  late int formatCode;

  late String resolvedTableName;

  int parse(ByteData byteData, int initialOffset) {
    var offset = initialOffset;
    final buf = new StringBuffer();
    var byte = 0;
    do {
      byte = byteData.getUint8(offset);
      offset += 1;
      if (byte != 0) {
        buf.writeCharCode(byte);
      }
    } while (byte != 0);

    fieldName = buf.toString();

    tableID = byteData.getUint32(offset);
    offset += 4;
    columnID = byteData.getUint16(offset);
    offset += 2;
    typeID = byteData.getUint32(offset);
    offset += 4;
    dataTypeSize = byteData.getUint16(offset);
    offset += 2;
    typeModifier = byteData.getInt32(offset);
    offset += 4;
    formatCode = byteData.getUint16(offset);
    offset += 2;

    converter = new PostgresBinaryDecoder(typeID);

    return offset;
  }

  String toString() => '$fieldName $tableID $columnID $typeID $dataTypeSize '
      '$typeModifier $formatCode';
}

typedef String SQLReplaceIdentifierFunction(
    PostgreSQLFormatIdentifier identifier, int index);

enum PostgreSQLFormatTokenType { text, variable }

class PostgreSQLFormatToken {
  PostgreSQLFormatToken(this.type);

  PostgreSQLFormatTokenType type;
  StringBuffer buffer = new StringBuffer();
}

class PostgreSQLFormatIdentifier {
  static Map<String, PostgreSQLDataType> typeStringToCodeMap = {
    'text': PostgreSQLDataType.text,
    'int2': PostgreSQLDataType.smallInteger,
    'int4': PostgreSQLDataType.integer,
    'int8': PostgreSQLDataType.bigInteger,
    'float4': PostgreSQLDataType.real,
    'float8': PostgreSQLDataType.double,
    'boolean': PostgreSQLDataType.boolean,
    'date': PostgreSQLDataType.date,
    'timestamp': PostgreSQLDataType.timestampWithoutTimezone,
    'timestamptz': PostgreSQLDataType.timestampWithTimezone,
    'jsonb': PostgreSQLDataType.jsonb,
    'json': PostgreSQLDataType.json,
    'numeric': PostgreSQLDataType.numeric,
    'bytea': PostgreSQLDataType.byteArray,
    'name': PostgreSQLDataType.name,
    'uuid': PostgreSQLDataType.uuid
  };

  PostgreSQLFormatIdentifier(String t) {
    final components = t.split('::');
    if (components.length > 1) {
      typeCast = components.sublist(1).join('');
    }

    final variableComponents = components.first.split(':');
    if (variableComponents.length == 1) {
      name = variableComponents.first;
    } else if (variableComponents.length == 2) {
      name = variableComponents.first;

      final dataTypeString = variableComponents.last;
      type = typeStringToCodeMap[dataTypeString];
      if (type == null) {
        throw new FormatException(
            "Invalid type code in substitution variable '$t'");
      }
    } else {
      throw new FormatException(
          'Invalid format string identifier, must contain identifier name '
          "and optionally one data type in format '@identifier:dataType' "
          '(offending identifier: $t)');
    }

    // Strip @
    name = name.substring(1, name.length);
  }

  late String name;
  PostgreSQLDataType? type;
  String? typeCast;
}
