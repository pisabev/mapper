import 'dart:convert';

import 'package:mapper/src/postgres.dart';

class PostgresTextEncoder extends Converter<dynamic, String> {
  const PostgresTextEncoder(this.escapeStrings);

  final bool escapeStrings;

  @override
  String convert(dynamic input) {
    if (input == null) {
      return 'null';
    }

    if (input is int) {
      return encodeNumber(input);
    }

    if (input is double) {
      return encodeDouble(input);
    }

    if (input is String) {
      return encodeString(input, escapeStrings);
    }

    if (input is DateTime) {
      return encodeDateTime(input, isDateOnly: false);
    }

    if (input is bool) {
      return encodeBoolean(input);
    }

    if (input is Map) {
      return encodeJSON(input);
    }

    throw new PostgreSQLException("Could not infer type of value '$input'.");
  }

  String encodeString(String text, bool escapeStrings) {
    if (!escapeStrings) {
      return text;
    }

    final backslashCodeUnit = r'\'.codeUnitAt(0);
    final quoteCodeUnit = r"'".codeUnitAt(0);

    var quoteCount = 0;
    var backslashCount = 0;
    final it = new RuneIterator(text);
    while (it.moveNext()) {
      if (it.current == backslashCodeUnit) {
        backslashCount++;
      } else if (it.current == quoteCodeUnit) {
        quoteCount++;
      }
    }

    final buf = new StringBuffer();

    if (backslashCount > 0) {
      buf.write(' E');
    }

    buf.write("'");

    if (quoteCount == 0 && backslashCount == 0) {
      buf.write(text);
    } else {
      text.codeUnits.forEach((i) {
        if (i == quoteCodeUnit || i == backslashCodeUnit) {
          buf..writeCharCode(i)..writeCharCode(i);
        } else {
          buf.writeCharCode(i);
        }
      });
    }

    buf.write("'");

    return buf.toString();
  }

  String encodeNumber(num value) {
    if (value.isNaN) {
      return "'nan'";
    }

    if (value.isInfinite) {
      return value.isNegative ? "'-infinity'" : "'infinity'";
    }

    return value.toInt().toString();
  }

  String encodeDouble(double value) {
    if (value.isNaN) {
      return "'nan'";
    }

    if (value.isInfinite) {
      return value.isNegative ? "'-infinity'" : "'infinity'";
    }

    return value.toString();
  }

  String encodeBoolean(bool value) => value ? 'TRUE' : 'FALSE';

  String encodeDateTime(DateTime value, {bool isDateOnly = false}) {
    var string = value.toIso8601String();

    if (isDateOnly) {
      string = string.split('T').first;
    } else {
      if (!value.isUtc) {
        final timezoneHourOffset = value.timeZoneOffset.inHours;
        final timezoneMinuteOffset = value.timeZoneOffset.inMinutes % 60;

        var hourComponent = timezoneHourOffset.abs().toString().padLeft(2, '0');
        final minuteComponent =
            timezoneMinuteOffset.abs().toString().padLeft(2, '0');

        if (timezoneHourOffset >= 0) {
          hourComponent = '+${hourComponent}';
        } else {
          hourComponent = '-${hourComponent}';
        }

        var timezoneString = [hourComponent, minuteComponent].join(':');
        string = [string, timezoneString].join('');
      }
    }

    if (string.substring(0, 1) == '-') {
      string = '${string.substring(1)} BC';
    } else if (string.substring(0, 1) == '+') {
      string = string.substring(1);
    }

    return "'$string'";
  }

  String encodeJSON(dynamic value) {
    if (value == null) {
      return 'null';
    }

    if (value is String) {
      return "'${json.encode(value)}'";
    }

    return '${json.encode(value)}';
  }
}
