part of mapper_server;

mixin Entity<A extends Application> {
  dynamic _mapper;

  void init(Map data);

  Manager<A> get manager => _mapper.manager;

  Map<String, dynamic> toMap();

  Map<String, dynamic> toJson();
}
