import 'package:mapper/src/drv/text_codec.dart';

import 'query.dart';
import 'types.dart';

class PostgreSQLFormat {
  static final int _AtSignCodeUnit = '@'.codeUnitAt(0);
  static final int _AtGreaterThanCodeUnit = '>'.codeUnitAt(0);

  static String id(String name, {PostgreSQLDataType? type}) {
    if (type != null) {
      return '@$name:${dataTypeStringForDataType(type)}';
    }

    return '@$name';
  }

  static String? dataTypeStringForDataType(PostgreSQLDataType dt) {
    switch (dt) {
      case PostgreSQLDataType.text:
        return 'text';
      case PostgreSQLDataType.integer:
        return 'int4';
      case PostgreSQLDataType.smallInteger:
        return 'int2';
      case PostgreSQLDataType.bigInteger:
        return 'int8';
      case PostgreSQLDataType.serial:
        return 'int4';
      case PostgreSQLDataType.bigSerial:
        return 'int8';
      case PostgreSQLDataType.real:
        return 'float4';
      case PostgreSQLDataType.double:
        return 'float8';
      case PostgreSQLDataType.boolean:
        return 'boolean';
      case PostgreSQLDataType.timestampWithoutTimezone:
        return 'timestamp';
      case PostgreSQLDataType.timestampWithTimezone:
        return 'timestamptz';
      case PostgreSQLDataType.date:
        return 'date';
      case PostgreSQLDataType.jsonb:
        return 'jsonb';
      case PostgreSQLDataType.json:
        return 'json';
      case PostgreSQLDataType.byteArray:
        return 'bytea';
      case PostgreSQLDataType.name:
        return 'name';
      case PostgreSQLDataType.uuid:
        return 'uuid';
      case PostgreSQLDataType.numeric:
        return 'numeric';
    }
  }

  static String substitute(String fmtString, Map<String, dynamic>? values,
      {SQLReplaceIdentifierFunction? replace}) {
    const converter = const PostgresTextEncoder(true);
    values ??= {};
    replace ??= (spec, index) => converter.convert(values![spec.name]);

    final items = <PostgreSQLFormatToken>[];
    PostgreSQLFormatToken? currentPtr;
    final iterator = new RuneIterator(fmtString);
    while (iterator.moveNext()) {
      if (currentPtr == null) {
        if (iterator.current == _AtSignCodeUnit) {
          currentPtr =
              new PostgreSQLFormatToken(PostgreSQLFormatTokenType.variable);
          currentPtr.buffer.writeCharCode(iterator.current);
          items.add(currentPtr);
        } else {
          currentPtr =
              new PostgreSQLFormatToken(PostgreSQLFormatTokenType.text);
          currentPtr.buffer.writeCharCode(iterator.current);
          items.add(currentPtr);
        }
      } else if (currentPtr.type == PostgreSQLFormatTokenType.text) {
        if (iterator.current == _AtSignCodeUnit) {
          currentPtr =
              new PostgreSQLFormatToken(PostgreSQLFormatTokenType.variable);
          currentPtr.buffer.writeCharCode(iterator.current);
          items.add(currentPtr);
        } else {
          currentPtr.buffer.writeCharCode(iterator.current);
        }
      } else if (currentPtr.type == PostgreSQLFormatTokenType.variable) {
        if (iterator.current == _AtSignCodeUnit ||
            iterator.current == _AtGreaterThanCodeUnit) {
          iterator.movePrevious();
          if (iterator.current == _AtSignCodeUnit) {
            iterator.moveNext();
            currentPtr.buffer.writeCharCode(iterator.current);
            currentPtr.type = PostgreSQLFormatTokenType.text;
          } else {
            currentPtr =
                new PostgreSQLFormatToken(PostgreSQLFormatTokenType.variable);
            currentPtr.buffer.writeCharCode(iterator.current);
            items.add(currentPtr);
            iterator.moveNext();
          }
        } else if (_isIdentifier(iterator.current)) {
          currentPtr.buffer.writeCharCode(iterator.current);
        } else {
          currentPtr =
              new PostgreSQLFormatToken(PostgreSQLFormatTokenType.text);
          currentPtr.buffer.writeCharCode(iterator.current);
          items.add(currentPtr);
        }
      }
    }

    var idx = 1;
    return items.map((t) {
      if (t.type == PostgreSQLFormatTokenType.text) {
        return t.buffer;
      } else if (t.buffer.length == 1 && t.buffer.toString() == '@') {
        return t.buffer;
      } else {
        final identifier = new PostgreSQLFormatIdentifier(t.buffer.toString());

        if (!values!.containsKey(identifier.name)) {
          throw new FormatException('Format string specified identifier with '
              'name ${identifier.name}, but key was not '
              'present in values. Format string: $fmtString');
        }

        final val = replace!(identifier, idx);
        idx++;

        if (identifier.typeCast != null) {
          return '$val::${identifier.typeCast}';
        }

        return val;
      }
    }).join('');
  }

  static final int _lowercaseACodeUnit = 'a'.codeUnitAt(0);
  static final int _uppercaseACodeUnit = 'A'.codeUnitAt(0);
  static final int _lowercaseZCodeUnit = 'z'.codeUnitAt(0);
  static final int _uppercaseZCodeUnit = 'Z'.codeUnitAt(0);
  static final int _0CodeUnit = '0'.codeUnitAt(0);
  static final int _9CodeUnit = '9'.codeUnitAt(0);
  static final int _underscoreCodeUnit = '_'.codeUnitAt(0);
  static final int _ColonCodeUnit = ':'.codeUnitAt(0);

  static bool _isIdentifier(int charCode) =>
      (charCode >= _lowercaseACodeUnit && charCode <= _lowercaseZCodeUnit) ||
      (charCode >= _uppercaseACodeUnit && charCode <= _uppercaseZCodeUnit) ||
      (charCode >= _0CodeUnit && charCode <= _9CodeUnit) ||
      (charCode == _underscoreCodeUnit) ||
      (charCode == _ColonCodeUnit);
}
