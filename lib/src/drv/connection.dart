library postgres.connection;

import 'dart:async';
import 'dart:io';
import 'dart:typed_data';

import 'package:collection/collection.dart';
import 'package:mapper/mapper.dart';
import 'package:mapper/src/drv/execution_context.dart';
import 'package:mapper/src/drv/query_cache.dart';
import 'package:mapper/src/drv/query_queue.dart';

import 'client_messages.dart';
import 'message_window.dart';
import 'query.dart';
import 'server_messages.dart';

part 'connection_fsm.dart';

part 'exceptions.dart';

part 'transaction_proxy.dart';

/// Instances of this class connect to and communicate with a PostgreSQL
/// database.
///
/// The primary type of this library, a connection is responsible for
/// connecting to databases and executing queries.
/// A connection may be opened with [open] after it is created.
class PostgreSQLConnection extends Object
    with _PostgreSQLExecutionContextMixin
    implements PostgreSQLExecutionContext {
  /// Creates an instance of [PostgreSQLConnection].
  ///
  /// [host] must be a hostname, e.g. "foobar.com" or IP address. Do not
  /// include scheme or port. [port] is the port to connect to the database
  /// on. It is typically 5432 for default PostgreSQL settings [databaseName]
  /// is the name of the database to connect to. [username] and [password] are
  /// optional if the database requires user authentication. [timeoutInSeconds]
  /// refers to the amount of time [PostgreSQLConnection] will wait while
  /// establishing a connection before it gives up. [timeZone] is the timezone
  /// the connection is in. Defaults to 'UTC'. [useSSL] when true, uses a
  /// secure socket when connecting to a PostgreSQL database.
  PostgreSQLConnection(this.host, this.port, this.databaseName,
      {this.username,
      this.password,
      this.timeoutInSeconds = 30,
      this.timeZone = 'UTC',
      this.useSSL = false}) {
    _connectionState = new _PostgreSQLConnectionStateClosed()
      ..connection = this;
  }

  final StreamController<Notification> _notifications =
      new StreamController<Notification>.broadcast();

  /// Hostname of database this connection refers to.
  String host;

  /// Port of database this connection refers to.
  int port;

  /// Name of database this connection refers to.
  String databaseName;

  /// Username for authenticating this connection.
  String? username;

  /// Password for authenticating this connection.
  String? password;

  /// Whether or not this connection should connect securely.
  bool useSSL;

  /// The amount of time this connection will wait during connecting
  /// before giving up.
  int timeoutInSeconds;

  /// The timezone of this connection for date operations that don't
  /// specify a timezone.
  String timeZone;

  /// The processID of this backend.
  int? processID;

  /// Stream of notification from the database.
  ///
  /// Listen to this [Stream] to receive events from PostgreSQL NOTIFY commands.
  ///
  /// To determine whether or not the NOTIFY came from this instance,
  /// compare [processID]
  /// to [Notification.processID].
  Stream<Notification> get notifications => _notifications.stream;

  /// Whether or not this connection is open or not.
  ///
  /// This is `true` when this instance is first created and after it has
  /// been closed or encountered an unrecoverable error. If a connection has
  /// already been opened and this value is now true, the connection cannot
  /// be reopened and a new instance must be created.
  bool get isClosed => _connectionState is _PostgreSQLConnectionStateClosed;

  bool get isInTransaction =>
      _connectionState is _PostgreSQLConnectionStateReadyInTransaction;

  /// Settings values from the connected database.
  ///
  /// After connecting to a database, this map will contain the settings values
  /// that the database returns. Prior to connection, it is the empty map.
  Map<String, String> settings = {};

  final QueryCache _cache = new QueryCache();
  Socket? _socket;
  MessageFramer _framer = new MessageFramer();
  int? _secretKey;
  List<int>? _salt;

  bool _hasConnectedPreviously = false;
  late _PostgreSQLConnectionState _connectionState;

  PostgreSQLExecutionContext? get _transaction => null;

  PostgreSQLConnection get _connection => this;

  /// Establishes a connection with a PostgreSQL database.
  ///
  /// This method will return a [Future] that completes when the connection is
  /// established. Queries can be executed on this connection afterwards.
  /// If the connection fails to be established for any reason - including
  /// authentication - the returned [Future] will return with an error.
  ///
  /// Connections may not be reopened after they are closed or opened more
  /// than once. If a connection has already been opened and this method is
  /// called, an exception will be thrown.
  Future open() async {
    if (_hasConnectedPreviously) {
      throw new PostgreSQLException('Attempting to reopen a closed connection. '
          'Create a new instance instead.');
    }

    try {
      _hasConnectedPreviously = true;
      _socket = await Socket.connect(host, port)
          .timeout(new Duration(seconds: timeoutInSeconds));

      _framer = new MessageFramer();
      if (useSSL) {
        _socket =
            await _upgradeSocketToSSL(_socket!, timeout: timeoutInSeconds);
      }

      final connectionComplete = new Completer();
      _socket!.listen(_readData, onError: _close, onDone: _close);

      _transitionToState(
          new _PostgreSQLConnectionStateSocketConnected(connectionComplete));

      await connectionComplete.future
          .timeout(new Duration(seconds: timeoutInSeconds));
    } on TimeoutException catch (e, st) {
      final err = new PostgreSQLException(
          'Failed to connect to database $host:$port/$databaseName failed to connect.');
      await _close(err, st);
      rethrow;
    } catch (e, st) {
      await _close(e, st);

      rethrow;
    }
  }

  /// Closes a connection.
  ///
  /// After the returned [Future] completes, this connection can no longer
  /// be used to execute queries. Any queries in progress or queued are
  /// cancelled.
  Future close() => _close();

  /// Executes a series of queries inside a transaction on this connection.
  ///
  /// Queries executed inside [queryBlock] will be grouped together in a
  /// transaction. The return value of the [queryBlock] will be the wrapped
  /// in the [Future] returned by this method if the transaction completes
  /// successfully.
  ///
  /// If a query or execution fails - for any reason - within a transaction
  /// block, the transaction will fail and previous statements within the
  /// transaction will not be committed. The [Future] returned from this
  /// method will be completed with the error from the first failing query.
  ///
  /// Transactions may be cancelled by invoking
  /// [PostgreSQLExecutionContext.cancelTransaction] within the transaction.
  /// This will cause this method to return a [Future] with a value of
  /// [PostgreSQLRollback]. This method does not throw an exception
  /// if the transaction is cancelled in this way.
  ///
  /// All queries within a transaction block must be executed using the
  /// [PostgreSQLExecutionContext] passed into the [queryBlock]. You must not
  /// issue queries to the receiver of this method from within the [queryBlock],
  /// otherwise the connection will deadlock.
  ///
  /// Queries within a transaction may be executed asynchronously or be
  /// awaited on. The order is still guaranteed. Example:
  ///
  ///         connection.transaction((ctx) {
  ///           var rows = await ctx.query("SELECT id FROM t);
  ///           if (!rows.contains([2])) {
  ///             ctx.query("INSERT INTO t (id) VALUES (2)");
  ///           }
  ///         });
  Future<dynamic> transaction(
      Future<dynamic> Function(PostgreSQLExecutionContext) queryBlock) async {
    if (isClosed) {
      throw new PostgreSQLException(
          'Attempting to execute query, but connection is not open.');
    }

    final proxy = new _TransactionProxy(this, queryBlock);

    await _enqueue(proxy.beginQuery);

    return proxy.completer.future;
  }

  void cancelTransaction({String? reason}) {
    // Default is no-op
  }

  ////////

  void _transitionToState(_PostgreSQLConnectionState newState) {
    if (identical(newState, _connectionState)) {
      return;
    }

    _connectionState.onExit();

    _connectionState = newState..connection = this;

    _connectionState = _connectionState.onEnter()..connection = this;
  }

  Future _close([dynamic error, StackTrace? trace]) async {
    _connectionState = new _PostgreSQLConnectionStateClosed();

    await _socket?.close();
    await _notifications.close();

    _queue.cancel(error, trace);
  }

  void _readData(Uint8List bytes) {
    // Note that the way this method works, if a query is in-flight, and we
    // move to the closed state manually, the delivery of the bytes from the
    // socket is sent to the 'Closed State', and the state node managing
    // delivering data to the query no longer exists. Therefore, as soon as
    // a close occurs, we detach the data stream from anything that actually
    // does anything with that data.
    _framer.addBytes(bytes);
    while (_framer.hasMessage) {
      final msg = _framer.popMessage().message;
      try {
        if (msg is ErrorResponseMessage) {
          _transitionToState(_connectionState.onErrorResponse(msg));
        } else if (msg is NotificationResponseMessage) {
          _notifications
              .add(new Notification(msg.processID, msg.channel, msg.payload));
        } else {
          _transitionToState(_connectionState.onMessage(msg));
        }
      } catch (e, st) {
        _close(e, st);
      }
    }
  }

  Future<Socket> _upgradeSocketToSSL(Socket originalSocket,
      {int timeout = 30}) {
    final sslCompleter = new Completer<int>();

    originalSocket.listen((data) {
      if (data.length != 1) {
        sslCompleter.completeError(new PostgreSQLException(
            'Could not initalize SSL connection, received '
            'unknown byte stream.'));
        return;
      }

      sslCompleter.complete(data.first);
    },
        onDone: () => sslCompleter.completeError(
            new PostgreSQLException('Could not initialize SSL connection, '
                'connection closed during handshake.')),
        onError: sslCompleter.completeError);

    final byteBuffer = new ByteData(8)..setUint32(0, 8)..setUint32(4, 80877103);
    originalSocket.add(byteBuffer.buffer.asUint8List());

    return sslCompleter.future
        .timeout(new Duration(seconds: timeout))
        .then((responseByte) {
      if (responseByte != 83) {
        throw new PostgreSQLException(
            'The database server is not accepting SSL connections.');
      }

      return SecureSocket.secure(originalSocket,
              onBadCertificate: (certificate) => true)
          .timeout(new Duration(seconds: timeout));
    });
  }
}

class _TransactionRollbackException implements Exception {
  _TransactionRollbackException(this.reason);

  String? reason;
}

/// Represents a notification from PostgreSQL.
///
/// Instances of this type are created and sent
/// via [PostgreSQLConnection.notifications].
class Notification {
  /// Creates an instance of this type.
  Notification(this.processID, this.channel, this.payload);

  /// The backend ID from which the notification was generated.
  final int processID;

  /// The name of the PostgreSQL channel that this notification occurred on.
  final String channel;

  /// An optional data payload accompanying this notification.
  final String payload;
}

mixin _PostgreSQLExecutionContextMixin implements PostgreSQLExecutionContext {
  //Map<int, String> _tableOIDNameMap = {};
  final _queue = new QueryQueue();

  PostgreSQLConnection get _connection;

  PostgreSQLExecutionContext? get _transaction;

  Future<List<Map<String, dynamic>>> query(String fmtString,
      {Map<String, dynamic>? substitutionValues,
      bool allowReuse = true,
      int timeoutInSeconds = 30}) async {
    if (_connection.isClosed) {
      throw new PostgreSQLException(
          'Attempting to execute query, but connection is not open.');
    }

    final query = new Query<List<Map<String, dynamic>>>(
        fmtString, substitutionValues, _connection, _transaction);
    if (allowReuse) {
      query.statementIdentifier = _connection._cache.identifierForQuery(query);
    }

    return _enqueue(query, timeoutInSeconds: timeoutInSeconds);
  }

  Future<C> queryToEntityCollection<C extends Collection>(String fmtString,
      Entity Function(Map<String, dynamic>) build, Collection<Entity> col,
      {Map<String, dynamic>? substitutionValues,
      bool allowReuse = true,
      int timeoutInSeconds = 30}) async {
    if (_connection.isClosed) {
      throw new PostgreSQLException(
          'Attempting to execute query, but connection is not open.');
    }

    final query = new QueryCollection<C>(
        fmtString, substitutionValues, _connection, _transaction)
      ..buildEntity = build
      ..collection = col;
    if (allowReuse) {
      query.statementIdentifier = _connection._cache.identifierForQuery(query);
    }

    return _enqueue(query, timeoutInSeconds: timeoutInSeconds);
  }

  Future<int> execute(String fmtString,
      {Map<String, dynamic>? substitutionValues, int timeoutInSeconds = 30}) {
    if (_connection.isClosed) {
      throw new PostgreSQLException(
          'Attempting to execute query, but connection is not open.');
    }

    final query =
        new Query<int>(fmtString, substitutionValues, _connection, _transaction)
          ..onlyReturnAffectedRowCount = true;

    return _enqueue(query, timeoutInSeconds: timeoutInSeconds);
  }

  void cancelTransaction({String reason});

  Future<T> _enqueue<T>(Query<T> query, {int timeoutInSeconds = 30}) async {
    if (_queue.add(query)) {
      _connection._transitionToState(_connection._connectionState.awake());

      try {
        final result =
            await query.future.timeout(new Duration(seconds: timeoutInSeconds));
        _connection._cache.add(query);
        _queue.remove(query);
        return result;
      } catch (e, st) {
        _queue.remove(query);
        await _onQueryError(query, e, st);
        rethrow;
      }
    } else {
      // wrap the synchronous future in an async future to ensure that
      // the caller behaves correctly in this condition. otherwise,
      // the caller would complete synchronously. This future
      // will always complete as a cancellation error.
      return new Future(() async => query.future);
    }
  }

  Future _onQueryError(Query query, dynamic error, [StackTrace? trace]) async {}
}
