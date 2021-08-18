#### Create entity object

```dart
import 'package:mapper/mapper.dart';

class Person with Entity {
  int? person_id;
  bool? active;
  String? name;
  DateTime? born;
  Map? settings;

  Person();

  // Usually using code generators for the following methods
  void init(Map data) {
    person_id = data['person_id'];
    active = data['active'];
    name = data['name'];
    born = data['born'];
    settings = data['settings'];
  }

  Map<String, dynamic> toMap() =>
      {
        'person_id': person_id,
        'active': active,
        'name': name,
        'born': born,
        'settings': settings
      };

  Map<String, dynamic> toJson() => toMap();
}
```

#### Create person collection object

```dart
import 'package:mapper/mapper.dart';

class PersonCollection extends Collection<Person> {}
```

#### Create the entity mapper object

```dart
import 'package:mapper/mapper.dart';

class PersonMapper extends Mapper<Person, PersonCollection> {
  const String table = 'person_table';

  PersonMapper(m) : super(m);
}
```

#### Create notifier object object

```dart
import 'package:mapper/mapper.dart';

final personNotifier = new EntityNotifier<Person>();
```

#### Setup our application

```dart
import 'package:mapper/mapper.dart';

extension AppExt on App {
  PersonMapper get person =>
      new PersonMapper(m)
        ..entity = (() => new Person())
        ..collection = (() => new PersonCollection())
        ..notifier = personNotifier;
}
```

#### Example use case

```dart
import 'package:mapper/mapper.dart';

Future<void> main() async {
  final pool = new Pool('host', 5432, 'databse',
      user: 'user', password: 'password');
  await pool.start();
  new Database().registerPool(pool);

  final manager = new Database().init();

  // Observe all changes to person
  personNotifier.onChange.listen((e) {
    print(e.diff);
  });
  
  final ent = manager.app.person.createObject()
    ..name = 'John Doe'
    ..active = true
    ..born = new DateTime(1988, 7, 20)
    ..settings = {'some_data': 'value'};
  
  // Persisting
  await manager.app.person.insert(ent); //ent.person_id == 1
  
  // Fetching
  final found = await manager.app.person.find(1);
  PersonCollection col = await manager.app.person.findAll();
}
```
