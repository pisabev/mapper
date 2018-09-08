class DatabaseConfig {
  final String host;
  final int port;
  final String username;
  final String password;
  final String database;

  String get userUrl => 'postgres://$username:$password@$host:$port/$database';

  DatabaseConfig(this.host, this.port, this.username, this.password, this.database);
}