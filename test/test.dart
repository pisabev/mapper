library test;

import 'dart:io';
import 'dart:mirrors';
import 'package:mapper/mapper.dart';
import 'package:test/test.dart';

part 'builder_test.dart';
part 'mapper_test.dart';

class A extends Application<A> {
    init() => new A();
}

Manager<A> manager;

String database = 'test';

startUp() {
    test('_Startup_', () => Process.run('./install.sh', ['-d ' + database, '-m 0'], workingDirectory: '../bin', runInShell:true)
    .then((_) => Process.run('./install.sh', ['-d ' + database, '-m 1'], workingDirectory: '../bin', runInShell:true))
    .then((_) {
        manager = new Manager(new Connection('postgres://user:dummy@localhost:5432/' + database), new A());
        return manager.init();
    }));
}

cleanUp() {
    test('_Cleanup_', () => manager.destroy());
}

main() {
    //startUp();
    group('Manager performance', () async {
        var t = new Stopwatch()..start();
        for(int i = 0; i < 100; i ++) {
            await manager.close();
            manager = await new Database().init();
        }
        print(t.elapsedMilliseconds);
    });
    /*group('DateTime', () {
        test("Insert and select timestamp and timestamptz from using UTC and local DateTime", () async {

            await manager.query("insert into dart_unit_test values (@timestamptz)", {"timestamptz" : new DateTime.now().toUtc()});

            var rows = await manager.query("select date from dart_unit_test");
            print(rows[0][0]);
        });
    });*/
    /*group('Builder', () {
        test('Select', querySelector);
        //test('annotations', ttt);
        /*var s = new Serialization()..addRule(new TestDBRule());
        var p = new Test();
        p.title = 'title';
        p._price = 122;
        print(s.write(p));
        var r = s.read(s.write(p));
        print(r);*/
        //print(inpsector(new Test2('asdasdas', 123)));
    });*/
    //cleanUp();
}