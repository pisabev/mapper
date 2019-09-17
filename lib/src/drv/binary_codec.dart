import 'dart:convert';
import 'dart:math';
import 'dart:typed_data';

import 'package:mapper/src/drv/types.dart';
import 'package:mapper/src/postgres.dart';

class PostgresBinaryEncoder extends Converter<dynamic, Uint8List> {
  const PostgresBinaryEncoder(this.dataType);

  final PostgreSQLDataType dataType;

  @override
  Uint8List convert(dynamic input) {
    if (input == null) {
      return null;
    }

    switch (dataType) {
      case PostgreSQLDataType.boolean:
        {
          if (input is! bool) {
            throw new FormatException('Invalid type for parameter value. '
                'Expected: bool Got: ${input.runtimeType}');
          }

          final bd = new ByteData(1)..setUint8(0, input ? 1 : 0);
          return bd.buffer.asUint8List();
        }
      case PostgreSQLDataType.bigSerial:
      case PostgreSQLDataType.bigInteger:
        {
          if (input is! int) {
            throw new FormatException('Invalid type for parameter value. '
                'Expected: int Got: ${input.runtimeType}');
          }

          final bd = new ByteData(8)..setInt64(0, input);
          return bd.buffer.asUint8List();
        }
      case PostgreSQLDataType.serial:
      case PostgreSQLDataType.integer:
        {
          if (input is! int) {
            throw new FormatException('Invalid type for parameter value. '
                'Expected: int Got: ${input.runtimeType}');
          }

          final bd = new ByteData(4)..setInt32(0, input);
          return bd.buffer.asUint8List();
        }
      case PostgreSQLDataType.smallInteger:
        {
          if (input is! int) {
            throw new FormatException('Invalid type for parameter value. '
                'Expected: int Got: ${input.runtimeType}');
          }

          final bd = new ByteData(2)..setInt16(0, input);
          return bd.buffer.asUint8List();
        }
      case PostgreSQLDataType.name:
      case PostgreSQLDataType.text:
        {
          if (input is! String) {
            throw new FormatException('Invalid type for parameter value. '
                'Expected: String Got: ${input.runtimeType}');
          }

          return utf8.encode(input);
        }
      case PostgreSQLDataType.real:
        {
          if (input is! double) {
            throw new FormatException('Invalid type for parameter value. '
                'Expected: double Got: ${input.runtimeType}');
          }

          final bd = new ByteData(4)..setFloat32(0, input);
          return bd.buffer.asUint8List();
        }
      case PostgreSQLDataType.numeric:
      case PostgreSQLDataType.double:
        {
          if (input is! double) {
            throw new FormatException('Invalid type for parameter value. '
                'Expected: double Got: ${input.runtimeType}');
          }

          final bd = new ByteData(8)..setFloat64(0, input);
          return bd.buffer.asUint8List();
        }
      case PostgreSQLDataType.date:
        {
          if (input is! DateTime) {
            throw new FormatException('Invalid type for parameter value. '
                'Expected: DateTime Got: ${input.runtimeType}');
          }

          final bd = new ByteData(4)
            ..setInt32(
                0, input.toUtc().difference(new DateTime.utc(2000)).inDays);
          return bd.buffer.asUint8List();
        }

      case PostgreSQLDataType.timestampWithoutTimezone:
      case PostgreSQLDataType.timestampWithTimezone:
        {
          if (input is! DateTime) {
            throw new FormatException('Invalid type for parameter value. '
                'Expected: DateTime Got: ${input.runtimeType}');
          }

          final bd = new ByteData(8);
          final diff = input.toUtc().difference(new DateTime.utc(2000));
          bd.setInt64(0, diff.inMicroseconds);
          return bd.buffer.asUint8List();
        }

      case PostgreSQLDataType.jsonb:
        {
          final jsonBytes = utf8.encode(json.encode(input));
          final outBuffer = new Uint8List(jsonBytes.length + 1);
          outBuffer[0] = 1;
          for (var i = 0; i < jsonBytes.length; i++) {
            outBuffer[i + 1] = jsonBytes[i];
          }

          return outBuffer;
        }

      case PostgreSQLDataType.json:
        {
          final jsonBytes = utf8.encode(json.encode(input));
          final outBuffer = new Uint8List(jsonBytes.length);
          for (var i = 0; i < jsonBytes.length; i++) {
            outBuffer[i] = jsonBytes[i];
          }

          return outBuffer;
        }

      case PostgreSQLDataType.byteArray:
        {
          if (input is! List) {
            throw new FormatException('Invalid type for parameter value. '
                'Expected: List<int> Got: ${input.runtimeType}');
          }
          return new Uint8List.fromList(input);
        }

      case PostgreSQLDataType.uuid:
        {
          if (input is! String) {
            throw new FormatException('Invalid type for parameter value. '
                'Expected: String Got: ${input.runtimeType}');
          }

          final dashUnit = '-'.codeUnits.first;
          final hexBytes = (input as String)
              .toLowerCase()
              .codeUnits
              .where((c) => c != dashUnit)
              .toList();
          if (hexBytes.length != 32) {
            throw const FormatException(
                'Invalid UUID string. There must be exactly 32 hexadecimal '
                '(0-9 and a-f) characters and any number of "-" '
                'characters.');
          }

          final byteConvert = (charCode) {
            if (charCode >= 48 && charCode <= 57) {
              return charCode - 48;
            } else if (charCode >= 97 && charCode <= 102) {
              return charCode - 87;
            }

            throw const FormatException(
                'Invalid UUID string. Contains non-hexadecimal character '
                '(0-9 and a-f).');
          };

          final outBuffer = new Uint8List(16);
          for (var i = 0; i < hexBytes.length; i += 2) {
            final upperByte = byteConvert(hexBytes[i]);
            final lowerByte = byteConvert(hexBytes[i + 1]);

            outBuffer[i ~/ 2] = upperByte * 16 + lowerByte;
          }
          return outBuffer;
        }
    }

    throw new PostgreSQLException('Unsupported datatype');
  }
}

class PostgresBinaryDecoder extends Converter<Uint8List, dynamic> {
  const PostgresBinaryDecoder(this.typeCode);

  final int typeCode;

  @override
  dynamic convert(Uint8List input) {
    final dataType = typeMap[typeCode];

    if (input == null) {
      return null;
    }

    final buffer = new ByteData.view(
        input.buffer, input.offsetInBytes, input.lengthInBytes);

    switch (dataType) {
      case PostgreSQLDataType.name:
      case PostgreSQLDataType.text:
        return utf8.decode(
            input.buffer.asUint8List(input.offsetInBytes, input.lengthInBytes));
      case PostgreSQLDataType.boolean:
        return buffer.getInt8(0) != 0;
      case PostgreSQLDataType.smallInteger:
        return buffer.getInt16(0);
      case PostgreSQLDataType.serial:
      case PostgreSQLDataType.integer:
        return buffer.getInt32(0);
      case PostgreSQLDataType.bigSerial:
      case PostgreSQLDataType.bigInteger:
        return buffer.getInt64(0);
      case PostgreSQLDataType.real:
        return buffer.getFloat32(0);
      case PostgreSQLDataType.double:
        return buffer.getFloat64(0);
      case PostgreSQLDataType.timestampWithoutTimezone:
      case PostgreSQLDataType.timestampWithTimezone:
        return new DateTime.utc(2000)
            .add(new Duration(microseconds: buffer.getInt64(0)));

      case PostgreSQLDataType.date:
        return new DateTime.utc(2000)
            .add(new Duration(days: buffer.getInt32(0)));

      case PostgreSQLDataType.numeric:
        {
          final e =
              input.buffer.asByteData(input.offsetInBytes, input.lengthInBytes);

          final allWords = e.getInt16(0);
          if (allWords == 0) return 0.0;
          final beforeWords = e.getInt16(2) + 1;
          final isNegative = (e.getInt16(4) & 16384) == 16384;
          final afterWords = allWords - beforeWords;
          final precision = e.getInt16(6);

          var offset = 8;
          var beforeDigit = 0;
          for (var i = 0; i < beforeWords; i++) {
            beforeDigit = beforeDigit * 10000;
            if (offset < e.lengthInBytes) {
              beforeDigit += e.getInt16(offset);
              offset += 2;
            } else {
              break;
            }
          }

          var afterDigit = 0;
          for (var i = 0; i < afterWords; i++) {
            if (offset < e.lengthInBytes) {
              afterDigit = afterDigit * 10000 + e.getInt16(offset);
              offset += 2;
            } else {
              break;
            }
          }

          var result = afterDigit / pow(10000, afterWords) + beforeDigit;

          final fac = pow(10, precision);
          result = (result * fac).round() / fac;

          return isNegative ? -result : result;
        }

      case PostgreSQLDataType.jsonb:
        {
          // Removes version which is first character and currently always '1'
          final bytes = input.buffer
              .asUint8List(input.offsetInBytes + 1, input.lengthInBytes - 1);
          return json.decode(utf8.decode(bytes));
        }

      case PostgreSQLDataType.json:
        {
          final bytes = input.buffer
              .asUint8List(input.offsetInBytes, input.lengthInBytes);
          return json.decode(utf8.decode(bytes));
        }

      case PostgreSQLDataType.byteArray:
        return input.buffer
            .asUint8List(input.offsetInBytes, input.lengthInBytes);

      case PostgreSQLDataType.uuid:
        {
          final codeDash = '-'.codeUnitAt(0);

          final cipher = [
            '0',
            '1',
            '2',
            '3',
            '4',
            '5',
            '6',
            '7',
            '8',
            '9',
            'a',
            'b',
            'c',
            'd',
            'e',
            'f'
          ];
          final byteConvert = (value) => cipher[value];

          final buf = new StringBuffer();
          for (var i = 0; i < buffer.lengthInBytes; i++) {
            final byteValue = buffer.getUint8(i);
            final upperByteValue = byteValue ~/ 16;

            final upperByteHex = byteConvert(upperByteValue);
            final lowerByteHex = byteConvert(byteValue - (upperByteValue * 16));
            buf..write(upperByteHex)..write(lowerByteHex);
            if (i == 3 || i == 5 || i == 7 || i == 9) {
              buf.writeCharCode(codeDash);
            }
          }

          return buf.toString();
        }
    }

    // We'll try and decode this as a utf8 string and return that
    // for many internal types, this is valid. If it fails,
    // we just return the bytes and let the caller figure out what to
    // do with it.
    try {
      return utf8.decode(input);
    } catch (_) {
      return input;
    }
  }

  static final Map<int, PostgreSQLDataType> typeMap = {
    16: PostgreSQLDataType.boolean,
    17: PostgreSQLDataType.byteArray,
    19: PostgreSQLDataType.name,
    20: PostgreSQLDataType.bigInteger,
    21: PostgreSQLDataType.smallInteger,
    23: PostgreSQLDataType.integer,
    25: PostgreSQLDataType.text,
    1042: PostgreSQLDataType.text,
    1043: PostgreSQLDataType.text,
    700: PostgreSQLDataType.real,
    701: PostgreSQLDataType.double,
    1082: PostgreSQLDataType.date,
    1114: PostgreSQLDataType.timestampWithoutTimezone,
    1184: PostgreSQLDataType.timestampWithTimezone,
    2950: PostgreSQLDataType.uuid,
    3802: PostgreSQLDataType.jsonb,
    114: PostgreSQLDataType.json,
    1700: PostgreSQLDataType.numeric
  };
}
