part of mapper_server;

class _Expression {
  String _type = '';

  final List _parts = <String>[];

  _Expression(String type, List parts) {
    _type = type;
    addMultiple(parts);
  }

  void addMultiple(List parts) => parts.forEach(add);

  void add(dynamic part) {
    if (part != '' || (part is _Expression && part.count() > 0))
      _parts.add(part);
  }

  int count() => _parts.length;

  String toString() {
    if (_parts.length == 1) return _parts[0].toString();
    return '(${_parts.join(') $_type (')})';
  }

  String getType() => _type;
}

abstract class Expression {
  final String key;
  final dynamic value;

  Expression(this.key, this.value);

  void _evaluate(Builder builder);
}

class Equals extends Expression {
  bool applyIfNull;

  Equals(String k, Object v, {this.applyIfNull = true}) : super(k, v);

  void _evaluate(Builder builder) {
    final par = builder.getUniqueKey();
    if (value == null) {
      if (applyIfNull) builder.andWhere('$key IS NULL');
    } else if (value is bool) {
      builder.andWhere('$key = ${value ? 'TRUE' : 'FALSE'}');
    } else if (value is List) {
      if (value is List<String>)
        builder.andWhere('$key IN (\'${value.join('\',\'')}\')');
      else
        builder.andWhere('$key IN (${value.join(',')})');
      builder.setParameter(par, value);
    } else {
      builder
        ..andWhere('$key = @$par')
        ..setParameter(par, value);
    }
  }
}

class TSquery {
  String query;

  TSquery(this.query);

  String toString() {
    if (query == null) return null;
    final search = query.trim();
    if (search.length < 2) return null;
    final parts = search.split(new RegExp(r'\s+')).map((e) => e
        .replaceAll('!', '\\!')
        .replaceAll(':', '\\:')
        .replaceAll('<', '\\<')
        .replaceAll('\&', '\\&')
        .replaceAll('(', '\\(')
        .replaceAll(')', '\\)')
        .replaceAll('\'', '\\\''));
    return '${parts.join(' & ')}:*';
  }
}

class Builder {
  static const int SELECT = 0;

  static const int DELETE = 1;

  static const int INSERT = 2;

  static const int UPDATE = 3;

  int _counter;

  String getUniqueKey() => 'p_unique_${++_counter}';

  drv.PostgreSQLConnection connection;

  String _sql = '';

  int _limit = 0;

  int _offset = 0;

  int _type = Builder.SELECT;

  Map<String, dynamic> _params = {};

  final _sqlParts = <String, dynamic>{
    'select': [],
    'from': [],
    'join': [],
    'set': [],
    'where': '',
    'groupBy': [],
    'having': '',
    'orderBy': []
  };

  Builder() : _counter = 0;

  int getType() => _type;

  void setParameter(String key, dynamic value) => _params[key] = value;

  void setParameters(Map<String, dynamic> params) => _params = params;

  void addParameters(Map<String, dynamic> params) => _params.addAll(params);

  Map<String, dynamic> getParameters() => _params;

  dynamic getParameter(String key) => _params[key];

  String getSQL() {
    if (_sql != '') {
      return _sql;
    }

    var sql = '';

    switch (_type) {
      case SELECT:
        sql = _getSQLForSelect();
        break;
      case DELETE:
        sql = _getSQLForDelete();
        break;
      case INSERT:
        sql = _getSQLForInsert();
        break;
      case UPDATE:
        sql = _getSQLForUpdate();
        break;
    }

    _sql = sql;
    return sql;
  }

  void offset(int offset) => _offset = offset;

  int getOffset() => _offset;

  void limit(int limit) => _limit = limit;

  int getLimit() => _limit;

  void setRaw(String query) => _sql = query;

  void add(String sqlPartName, dynamic sqlPart, [bool append = false]) {
    if ((sqlPart is String && sqlPart == '') ||
        (sqlPart is Map && sqlPart.isEmpty)) return;
    if (append) {
      _sqlParts[sqlPartName].add(sqlPart);
    } else {
      _sqlParts[sqlPartName] = sqlPart;
    }
  }

  void select(String select) {
    _sqlParts['select'] = [];
    return addSelect(select);
  }

  void addSelect(String select) {
    _type = Builder.SELECT;
    return add('select', select, true);
  }

  void delete(String del) {
    _type = Builder.DELETE;
    return add('from', del, true);
  }

  void insert(String update) {
    _type = Builder.INSERT;
    return add('from', update, true);
  }

  void update(String update) {
    _type = Builder.UPDATE;
    return add('from', update, true);
  }

  void from(String from) => add('from', from, true);

  void join(String joinTable, String condition) =>
      innerJoin(joinTable, condition);

  void innerJoin(String joinTable, String condition) => add(
      'join',
      {'joinType': 'INNER', 'joinTable': joinTable, 'joinCondition': condition},
      true);

  void leftJoin(String joinTable, String condition) => add(
      'join',
      {'joinType': 'LEFT', 'joinTable': joinTable, 'joinCondition': condition},
      true);

  void rightJoin(String joinTable, String condition) => add(
      'join',
      {'joinType': 'RIGHT', 'joinTable': joinTable, 'joinCondition': condition},
      true);

  void set(String key, dynamic value) => add('set', {key: value}, true);

  void where(String where, [String where2 = '']) {
    if (where2 != '')
      where = new _Expression('AND', [where, where2]).toString();
    return add('where', where);
  }

  void andWhere(String where) => _exprBuilder('where', where, 'AND');

  void orWhere(String where) => _exprBuilder('where', where, 'OR');

  void groupBy(String groupBy) => addGroupBy(groupBy);

  void addGroupBy(String groupBy) => add('groupBy', groupBy, true);

  void having(String having, [String having2 = '']) {
    if (having2 != '')
      having = new _Expression('AND', [having, having2]).toString();
    return add('having', having);
  }

  void andHaving(String having) => _exprBuilder('having', having, 'AND');

  void orHaving(String having) => _exprBuilder('having', having, 'OR');

  void orderBy(String sort, [String order = 'ASC']) {
    _sqlParts['orderBy'] = [];
    return add('orderBy', '$sort $order', true);
  }

  void addOrderBy(String sort, [String order = 'ASC']) =>
      add('orderBy', '$sort $order', true);

  void setQueryPart(String queryPartName, dynamic queryPart) {
    _sqlParts[queryPartName] = queryPart;
  }

  dynamic getQueryPart(String queryPartName) => _sqlParts[queryPartName];

  Map<String, dynamic> getQueryParts() {
    final res = <String, dynamic>{};
    _sqlParts.forEach((k, v) => res[k] = v);
    return res;
  }

  void resetQueryParts(List queryPartNames) {
    if (queryPartNames.isEmpty) {
      final queryPartNames = [];
      _sqlParts.forEach((k, v) => queryPartNames.add(k));
    }
    queryPartNames.forEach(resetQueryPart);
  }

  void resetQueryPart(String queryPartName) {
    _sqlParts[queryPartName] = (_sqlParts[queryPartName] is List) ? [] : '';
    _sql = '';
  }

  bool isJoinPresent(String joinTable) {
    final joins = getQueryPart('join');
    for (var i = 0; i < joins.length; i++)
      if (joins[i]['joinTable'] == joinTable) return true;
    return false;
  }

  void _exprBuilder(String key, args, type, [bool append = false]) {
    var expr = getQueryPart(key);
    expr = new _Expression(type, [expr, args]).toString();
    return add(key, expr, append);
  }

  String _getSQLForSelect() {
    final sb = new StringBuffer()
      ..write('SELECT ')
      ..writeAll(_sqlParts['select'], ', ')
      ..write('\n FROM ')
      ..writeAll(_sqlParts['from'], ', ');
    if (_sqlParts['join'].length > 0) {
      _sqlParts['join'].forEach((e) {
        sb
          ..write('\n ')
          ..write(e['joinType'])
          ..write(' JOIN ')
          ..write(e['joinTable'])
          ..write(' ON ')
          ..write(e['joinCondition']);
      });
    }
    if (_sqlParts['where'] != '') {
      sb..write('\n WHERE ')..write(_sqlParts['where']);
    }
    if (_sqlParts['groupBy'].length > 0) {
      sb
        ..write('\n GROUP BY ')
        ..writeAll(_sqlParts['groupBy'], ', ');
    }
    if (_sqlParts['having'] != '') {
      sb..write('\n HAVING ')..write(_sqlParts['having']);
    }
    if (_sqlParts['orderBy'].length > 0) {
      sb
        ..write('\n ORDER BY ')
        ..writeAll(_sqlParts['orderBy'], ', ');
    }
    if (_limit > 0) {
      sb.write('\n LIMIT ${_limit.toString()}');
      if (_offset > 0) sb.write(' OFFSET ${_offset.toString()}');
    }
    return sb.toString();
  }

  String _getSQLForUpdate() {
    final pairs = [];
    _sqlParts['set'].forEach((s) {
      s.forEach((k, v) {
        pairs.add('$k = $v');
      });
    });
    final sb = new StringBuffer()
      ..write('UPDATE ')
      ..write(_sqlParts['from'][0])
      ..write(' SET ')
      ..writeAll(pairs, ', ');
    if (_sqlParts['where'] != '') {
      sb..write('\n WHERE ')..write(_sqlParts['where']);
    }
    return sb.toString();
  }

  String _getSQLForInsert() {
    final columns = [];
    final values = [];
    _sqlParts['set'].forEach((s) {
      s.forEach((k, v) {
        columns.add(k);
        values.add(v);
      });
    });
    final sb = new StringBuffer()
      ..write('INSERT INTO ')
      ..write(_sqlParts['from'][0])
      ..write(' (')
      ..writeAll(columns, ', ')
      ..write(') VALUES (')
      ..writeAll(values, ', ')
      ..write(') RETURNING *');
    return sb.toString();
  }

  String _getSQLForDelete() {
    final sb = new StringBuffer()
      ..write('DELETE FROM ')
      ..write(_sqlParts['from'][0]);
    if (_sqlParts['where'] != '') {
      sb..write('\n WHERE ')..write(_sqlParts['where']);
    }
    return sb.toString();
  }

  Builder clone() {
    final clone = new Builder();
    _sqlParts.forEach((k, v) {
      if (v is List)
        v.forEach((s) => clone._sqlParts[k].add(s));
      else
        clone._sqlParts[k] = v;
    });
    clone
      .._limit = _limit
      .._offset = _offset
      .._params = new Map.from(_params);
    return clone;
  }

  Builder cloneFilter() {
    final clone = new Builder();
    ['join', 'where', 'having'].forEach((k) {
      final v = _sqlParts[k];
      if (v is List)
        v.forEach((s) => clone._sqlParts[k].add(s));
      else
        clone._sqlParts[k] = v;
    });
    clone._params = new Map.from(_params);
    return clone;
  }

  String toString() => getSQL();
}

class FilterRule {
  List<String> eq;
  List<String> gt;
  List<String> lt;
  List<String> gte;
  List<String> lte;
  List<String> like;
  List<String> rlike;
  List<String> llike;
  List<String> tsquery;
  List<String> tsvector;
  List<String> date;
  Map<String, String> map;
}

class CollectionMeta {
  Map<String, dynamic> filter;
  String orderField;
  String orderWay;
  int page;
  int limit;
}

class CollectionBuilder<E extends Entity, C extends Collection<E>> {
  static int _unique = 0;

  final Builder query;

  final MapperBase<E, C> mapper;

  Map<String, dynamic> filter = {};

  CollectionMeta _collectionMeta;

  FilterRule filterRule;

  C collection;

  CollectionBuilder(this.query, this.mapper);

  set collectionMeta(CollectionMeta cm) => _collectionMeta = cm;

  CollectionMeta get collectionMeta =>
      _collectionMeta = _collectionMeta ?? new CollectionMeta();

  set limit(int limit) => collectionMeta.limit = limit;

  set page(int page) => collectionMeta.page = page;

  @Deprecated('Use filterRule! instead')
  set filter_way(Map<String, List<String>> m) {
    filterRule = filterRule ?? new FilterRule()
      ..eq = m['eq']
      ..gt = m['gt']
      ..lt = m['lt']
      ..gte = m['gte']
      ..lte = m['lte']
      ..like = m['like']
      ..rlike = m['rlike']
      ..llike = m['llike']
      ..tsquery = m['tsquery']
      ..tsvector = m['tsvector']
      ..date = m['date'];
  }

  @Deprecated('Use filterRule instead!')
  set filter_map(Map<String, String> m) {
    filterRule = filterRule ?? new FilterRule()
      ..map = m;
  }

  void order(String order, String way) {
    if (order != null) {
      collectionMeta
        ..orderField = order
        ..orderWay = way;
    }
  }

  Future<CollectionBuilder<E, C>> process([bool total = false]) async {
    _queryFilter(query);
    _queryFinalize(query);
    collection = await mapper.loadC(query, total);
    return this;
  }

  Future<int> count() async {
    final q = query.clone();
    _queryFilter(q);
    _queryFinalize(q);
    final res =
        await mapper.manager.execute(q..select('COUNT(*) OVER() AS total'));
    return res.isNotEmpty ? res.first['total'] : 0;
  }

  String queryToString() {
    final q = query.clone();
    _queryFilter(q);
    _queryFinalize(q);
    return '$q\n${q._params}';
  }

  int get total => collection.totalResults ?? 0;

  void _queryFilter(Builder query) {
    if (filterRule == null) return;
    filter.forEach((k, value) {
      if (value != null) {
        var key = k;
        if (filterRule.map != null && filterRule.map.containsKey(k))
          key = filterRule.map[k];
        if (filterRule.eq != null && filterRule.eq.contains(k))
          _setEq(query, key, value);
        else if (filterRule.gt != null && filterRule.gt.contains(k))
          _setGt(query, key, value);
        else if (filterRule.lt != null && filterRule.lt.contains(k))
          _setLt(query, key, value);
        else if (filterRule.gte != null && filterRule.gte.contains(k))
          _setGte(query, key, value);
        else if (filterRule.lte != null && filterRule.lte.contains(k))
          _setLte(query, key, value);
        else if (filterRule.like != null && filterRule.like.contains(k))
          _setLike(query, key, value);
        else if (filterRule.rlike != null && filterRule.rlike.contains(k))
          _setRlike(query, key, value);
        else if (filterRule.llike != null && filterRule.llike.contains(k))
          _setLlike(query, key, value);
        else if (filterRule.tsquery != null && filterRule.tsquery.contains(k))
          _setTsquery(query, key, value);
        else if (filterRule.tsvector != null && filterRule.tsvector.contains(k))
          _setTsvector(query, key, value);
        else if (filterRule.date != null && filterRule.date.contains(k))
          _setDate(query, key, value);
      }
    });
  }

  void _queryFinalize(Builder query) {
    final meta = collectionMeta;
    if (meta.limit != null) {
      query.limit(meta.limit);
      if (meta.page != null) query.offset((meta.page - 1) * meta.limit);
    }
    if (meta.orderField != null) {
      var k = meta.orderField;
      if (filterRule.map != null && filterRule.map.containsKey(k))
        k = filterRule.map[k];
      query.orderBy(k, meta.orderWay ?? 'ASC');
    }
  }

  void _setEq(Builder query, String key, dynamic value) {
    var ph = _cleanPlaceHolder(key);
    if (value is List) {
      value.removeWhere((v) => v == null);
      if (value.isEmpty) return;
      final q = value.map((v) {
        if (v == 'null') {
          return '$key IS NULL';
        } else {
          ph = _cleanPlaceHolder(key);
          query.setParameter(ph, v);
          return '$key = @$ph';
        }
      });
      query.andWhere(q.join(' OR '));
    } else if (value == 'null') {
      query.andWhere('$key IS NULL');
    } else {
      query
        ..andWhere('$key = @$ph')
        ..setParameter(ph, value);
    }
  }

  void _setGt(Builder query, String key, dynamic value) {
    final ph = _cleanPlaceHolder(key);
    query
      ..andWhere('$key > @$ph')
      ..setParameter(ph, value);
  }

  void _setLt(Builder query, String key, dynamic value) {
    final ph = _cleanPlaceHolder(key);
    query
      ..andWhere('$key < @$ph')
      ..setParameter(ph, value);
  }

  void _setGte(Builder query, String key, dynamic value) {
    final ph = _cleanPlaceHolder(key);
    query
      ..andWhere('$key >= @$ph')
      ..setParameter(ph, value);
  }

  void _setLte(Builder query, String key, dynamic value) {
    final ph = _cleanPlaceHolder(key);
    query
      ..andWhere('$key <= @$ph')
      ..setParameter(ph, value);
  }

  void _setLike(Builder query, String key, dynamic value) {
    final ph = _cleanPlaceHolder(key);
    query
      ..andWhere('CAST($key AS text) ILIKE @$ph')
      ..setParameter(ph, '%$value%');
  }

  void _setLlike(Builder query, String key, dynamic value) {
    final ph = _cleanPlaceHolder(key);
    query
      ..andWhere('CAST($key AS text) ILIKE @$ph')
      ..setParameter(ph, '$value%');
  }

  void _setRlike(Builder query, String key, dynamic value) {
    final ph = _cleanPlaceHolder(key);
    query
      ..andWhere('CAST($key AS text) ILIKE @$ph')
      ..setParameter(ph, '%$value');
  }

  void _setTsquery(Builder query, String key, dynamic value) {
    final ph = _cleanPlaceHolder(key);
    query
      ..andWhere('to_tsvector($key) @@ to_tsquery(@$ph)')
      ..setParameter(ph, new TSquery(value).toString());
  }

  void _setTsvector(Builder query, String key, dynamic value) {
    final ph = _cleanPlaceHolder(key);
    query
      ..andWhere('$key @@ to_tsquery(@$ph)')
      ..setParameter(ph, new TSquery(value).toString());
  }

  void _setDate(Builder query, String key, dynamic value) {
    if (value is List && value.isNotEmpty && value.length == 2) {
      if (value[0] != null) {
        final from = DateTime.parse(value[0]);
        query
          ..andWhere('$key >= @date_from')
          ..setParameter('date_from', from);
      }
      if (value[1] != null) {
        var to = DateTime.parse(value[1]);
        to = (to.isUtc)
            ? to.add(const Duration(seconds: 86400))
            : new DateTime(to.year, to.month, to.day + 1);
        query
          ..andWhere('$key < @date_to')
          ..setParameter('date_to', to);
      }
    }
  }

  String _cleanPlaceHolder(String key) =>
      key.replaceAll(new RegExp(r'\.'), '_') + (++_unique).toString();
}
