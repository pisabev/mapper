part of mapper_server;

class MapperView<E extends Entity, C extends Collection<E>>
    extends MapperBase<E, C> {
  MapperView(manager) : super(manager);
}
