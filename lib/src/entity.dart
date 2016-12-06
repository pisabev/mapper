part of mapper_server;

abstract class Entity {

    Manager manager;

    void init(Map data);

    Map toMap();

    Map toJson();

}