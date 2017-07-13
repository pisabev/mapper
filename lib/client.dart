library mapper_shared;

import 'dart:collection';

part 'src/collection.dart';

DateTime setDateTime(dynamic date) {
  if (date != null) {
    if (date is DateTime)
      return date;
    else if (date is String) {
      if (date == '0') return new DateTime.fromMillisecondsSinceEpoch(0);
      return DateTime.parse(date);
    } else if (date is int)
      return new DateTime.fromMillisecondsSinceEpoch(date);
  }
  return null;
}

double setDouble(dynamic value) {
  if (value != null) {
    if (value is int) return value.toDouble();
    if (value is double)
      return value;
    else if (value is String) return double.parse(value);
  }
  return null;
}
