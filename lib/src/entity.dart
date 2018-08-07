part of mapper_server;

abstract class Entity<A extends Application> {
  Manager<A> manager;
  dynamic _mapper;

  void init(Map data);

  Map toMap();

  Map toJson();
}
