part of mapper_server;

abstract class Entity<E> {

    Manager manager;

    void init(Map data);

    Map toMap();

    Map toJson();

}