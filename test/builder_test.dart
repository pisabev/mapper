import 'package:mapper/mapper.dart';
import 'package:test/test.dart';

main() {
  test('Query Builder', querySelector);
}

querySelector() {
  Builder b = new Builder()
    ..select('dummy')
    ..from('table');
  expect(b.toString(), 'SELECT dummy\n FROM table');
  b = new Builder()
    ..select('dummy')
    ..from('table')
    ..orderBy('field');
  expect(b.toString(), 'SELECT dummy\n FROM table\n ORDER BY field ASC');
  b = new Builder()
    ..select('dummy')
    ..from('table')
    ..orderBy('field', 'DESC');
  expect(b.toString(), 'SELECT dummy\n FROM table\n ORDER BY field DESC');
  b = new Builder()
    ..select('dummy')
    ..from('table')
    ..where('sm = 1');
  expect(b.toString(), 'SELECT dummy\n FROM table\n WHERE sm = 1');
  b = new Builder()
    ..select('dummy')
    ..from('table')
    ..limit(10)
    ..offset(5);
  expect(b.toString(), 'SELECT dummy\n FROM table\n LIMIT 10 OFFSET 5');
  b = new Builder()
    ..select('dummy')
    ..from('table')
    ..where('sm = 1')
    ..andWhere('sm2 = 2');
  expect(
      b.toString(), 'SELECT dummy\n FROM table\n WHERE (sm = 1) AND (sm2 = 2)');
  b = new Builder()
    ..select('dummy')
    ..from('table')
    ..where('sm = 1', 'sm2 = 2');
  expect(
      b.toString(), 'SELECT dummy\n FROM table\n WHERE (sm = 1) AND (sm2 = 2)');
  b = new Builder()
    ..select('dummy')
    ..from('table')
    ..where('sm = 1')
    ..orWhere('sm2 = 2');
  expect(
      b.toString(), 'SELECT dummy\n FROM table\n WHERE (sm = 1) OR (sm2 = 2)');
  b = new Builder()
    ..select('dummy')
    ..from('table')
    ..join('table2', 'table2.ref = table.ref');
  expect(b.toString(),
      'SELECT dummy\n FROM table\n INNER JOIN table2 ON table2.ref = table.ref');
  b = new Builder()
    ..select('dummy')
    ..from('table')
    ..having('sm > 1');
  expect(b.toString(), 'SELECT dummy\n FROM table\n HAVING sm > 1');
}
