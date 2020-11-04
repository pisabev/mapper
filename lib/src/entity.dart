part of mapper_server;

mixin Entity {
  dynamic _mapper;

  void init(Map data);

  Manager get manager => _mapper.manager;

  Map<String, dynamic> toMap();

  Map<String, dynamic> toJson();
}
