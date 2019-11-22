import 'dart:async';

import 'connection.dart';
import 'query.dart';
import 'substituter.dart';
import 'types.dart';

abstract class PostgreSQLExecutionContext {
  /// Executes a query on this context.
  ///
  /// This method sends the query described by [fmtString] to the database
  /// and returns a [Future] whose value is the returned rows from the query
  /// after the query completes.
  /// The format string may contain parameters that are provided
  /// in [substitutionValues]. Parameters are prefixed with the '@' character.
  /// Keys to replace the parameters
  /// do not include the '@' character. For example:
  ///
  ///         connection.query("SELECT * FROM table WHERE id = @idParam",
  ///         {"idParam" : 2});
  ///
  /// The type of the value is inferred by default, but should be made more
  /// specific by adding ':type" to the parameter pattern in the format string.
  /// For example:
  ///
  ///         connection.query("SELECT * FROM table WHERE id = @idParam:int4",
  ///         {"idParam" : 2});
  ///
  /// Available types are listed in
  /// [PostgreSQLFormatIdentifier.typeStringToCodeMap]. Some types have
  /// multiple options. It is preferable to use the [PostgreSQLFormat.id]
  /// function to add parameters to a query string. This method inserts a
  /// parameter name and the appropriate ':type' string
  /// for a [PostgreSQLDataType].
  ///
  /// If successful, the returned [Future] completes with a [List] of rows.
  /// Each is row is represented by a [List] of column values for that row
  /// that were returned by the query.
  ///
  /// By default, instances of this class will reuse queries. This allows
  /// significantly more efficient transport to and from the database. You
  /// do not have to do
  /// anything to opt in to this behavior, this connection will track the
  /// necessary information required to reuse queries without intervention.
  /// (The [fmtString] is the unique identifier to look up reuse information.)
  /// You can disable reuse by passing false for [allowReuse].
  Future<List<Map<String, dynamic>>> query(String fmtString,
      {Map<String, dynamic> substitutionValues,
      bool allowReuse = true,
      int timeoutInSeconds});

  /// Executes a query on this context.
  ///
  /// This method sends a SQL string to the database this instance is
  /// connected to. Parameters can be provided in [fmtString], see [query]
  /// for more details.
  ///
  /// This method returns the number of rows affected and no additional
  /// information. This method uses the least efficient and less secure command
  /// for executing queries in the PostgreSQL protocol; [query] is preferred
  /// for queries that will be executed more than once, will contain user input,
  /// or return rows.
  Future<int> execute(String fmtString,
      {Map<String, dynamic> substitutionValues, int timeoutInSeconds});

  /// Cancels a transaction on this context.
  ///
  /// If this context is an instance of [PostgreSQLConnection], this method
  /// has no effect. If the context is a transaction context (passed as the
  /// argument to [PostgreSQLConnection.transaction]), this will rollback
  /// the transaction.
  void cancelTransaction({String reason});
}
