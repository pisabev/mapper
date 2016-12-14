part of mapper_shared;

class Collection<E> extends ListBase<E> {

    List<E> innerList = new List();

    int get length => innerList.length;

    void set length(int length) {
        innerList.length = length;
    }

    void operator []=(int index, E value) {
        innerList[index] = value;
    }

    E operator [](int index) => innerList[index];

    void add(E value) => innerList.add(value);

    void addAll(Iterable<E> all) => innerList.addAll(all);

    Iterable<T> map<T>(T f(E e)) => innerList.map(f);

}