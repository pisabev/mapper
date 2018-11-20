part of mapper_server;

class MapperView<E extends Entity<Application>, C extends Collection<E>,
    A extends Application> extends MapperBase<E, C, A> {
  MapperView(manager) : super(manager);
}
