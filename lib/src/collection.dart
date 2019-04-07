part of mapper_shared;

class Collection<E> extends ListBase<E> {
  List<E> innerList = [];

  int totalResults;

  int get length => innerList.length;

  set length(int length) {
    innerList.length = length;
  }

  void operator []=(int index, E value) {
    innerList[index] = value;
  }

  E operator [](int index) => innerList[index];

  void add(E element) => innerList.add(element);

  void addAll(Iterable<E> iterable) => innerList.addAll(iterable);

  Iterable<T> map<T>(T Function(E e) f) => innerList.map(f);
}
