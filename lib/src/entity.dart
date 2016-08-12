part of mapper_server;

abstract class Entity<A extends Application> {

    Manager<A> manager;

    void init(Map data);

    Map toMap();

    Map toJson();

}