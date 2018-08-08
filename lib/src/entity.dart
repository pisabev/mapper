part of mapper_server;

abstract class Entity {
  Manager manager;
  dynamic _mapper;

  void init(Map data);

  Map toMap();

  Map toJson();
}
