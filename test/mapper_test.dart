part of test;

class Field {
  final String name;
  final dynamic def;
  final String type;
  const Field({this.name: null, this.def: 'DEFAULT', this.type: null});
}

class Table {
  final String name;
  const Table(this.name);
}

@Table('product')
class Product {
  @Field()
  var title;

  @Field()
  var price;

  Product();
}

class ProductExt extends Product {}

ttt() {
  var obj = new Product();
  obj.title = 'ssss';
  var data = readClassData();
  var date = new DateTime.now();
  for (int i = 0; i < 1000000; i++) {
    //readObject(obj, data);
    //readObject2(obj);
    setObject(obj, data, {'title': 'dddd'});
    //setObject2(obj, {'title':'dddd'});
    //print(data);
  }
  print(new DateTime.now().difference(date).inMilliseconds);
}

readClassData() {
  Map field_map = new Map();
  var classMirror = reflectClass(ProductExt);
  //var metadata = classMirror.superclass.metadata;
  classMirror.superclass.declarations.forEach((k, v) {
    var f =
        v.metadata.firstWhere((e) => e.reflectee is Field, orElse: () => null);
    if (f != null) {
      Field field = f.reflectee;
      var name = MirrorSystem.getName(k);
      field_map[name] = {
        'symbol': k,
        'db': field.name != null ? field.name : name,
        'default': field.def
      };
    }
  });
  return field_map;
}

readObject(obj, Map field_map) {
  var refl = reflect(obj);
  Map data = new Map();
  field_map
      .forEach((k, v) => data[v['db']] = refl.getField(v['symbol']).reflectee);
  return data;
}

setObject(obj, Map field_map, Map data) {
  var refl = reflect(obj);
  data.forEach((k, v) => refl.setField(field_map[k]['symbol'], v));
}

class Product2 {
  var title;
  var price;

  Product2();

  Product2.fromMap(Map data) {
    init(data);
  }

  init(Map data) {
    title = data['title'];
    price = data['price'];
  }

  toMap() => {
        'title': title,
        'price': price,
      };
}

productToDb(Product2 product) => product.toMap();

class Product2ext extends Product2 {}

readObject2(obj) {
  return obj.toMap();
}

setObject2(obj, Map data) {
  obj.init(data);
}

productToMap(a) => {"title": a.title, "price": a.price};
createProduct(Map m) => new Product2.fromMap(m);
fillInProduct(Product a, Map m) {
  a.title = m["title"];
  a.price = m['price'];
}
