part of mapper_server;

class Expression {
  String _type = '';

  List _parts = <String>[];

  Expression(String type, List parts) {
    _type = type;
    addMultiple(parts);
  }

  addMultiple(List parts) {
    parts.forEach((part) => add(part));
  }

  add(dynamic part) {
    if (part != '' || (part is Expression && part.count() > 0))
      _parts.add(part);
  }

  int count() => _parts.length;

  String toString() {
    if (_parts.length == 1) return _parts[0].toString();
    return '(' + _parts.join(') ' + _type + ' (') + ')';
  }

  String getType() => _type;
}

class TSquery {
  String query;

  TSquery(this.query);

  String toString() {
    if (query == null) return null;
    var search = query.trim();
    if (search.length < 2) return null;
    var parts = search.split(new RegExp(r'\s+')).map((e) => e
        .replaceAll('!', '\\!')
        .replaceAll(':', '\\:')
        .replaceAll('\&', '\\&')
        .replaceAll('(', '\\(')
        .replaceAll(')', '\\)')
        .replaceAll('\'', '\\\''));
    return parts.join(' & ') + ':*';
  }
}

class Builder {
  static const int SELECT = 0;

  static const int DELETE = 1;

  static const int INSERT = 2;

  static const int UPDATE = 3;

  var connection;

  String _sql = '';

  int _limit = 0;

  int _offset = 0;

  int _type = Builder.SELECT;

  Map<String, dynamic> _params = {};

  Map _sqlParts = <String, dynamic>{
    'select': new List(),
    'from': new List(),
    'join': new List(),
    'set': new List(),
    'where': '',
    'groupBy': new List(),
    'having': '',
    'orderBy': new List()
  };

  Builder();

  getType() {
    return _type;
  }

  Builder setParameter(String key, dynamic value) {
    _params[key] = value;
    return this;
  }

  Builder setParameters(Map<String, dynamic> params) {
    _params = params;
    return this;
  }

  Map<String, dynamic> getParameters() => _params;

  getParameter(key) {
    return (_params[key] != null) ? _params[key] : null;
  }

  getSQL() {
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

  Builder offset(int offset) {
    _offset = offset;
    return this;
  }

  getOffset() {
    return _offset;
  }

  Builder limit(int limit) {
    _limit = limit;
    return this;
  }

  getLimit() {
    return _limit;
  }

  Builder add(String sqlPartName, dynamic sqlPart, [bool append = false]) {
    if ((sqlPart is String && sqlPart == '') ||
        (sqlPart is Map && sqlPart.isEmpty)) return this;
    if (append) {
      _sqlParts[sqlPartName].add(sqlPart);
    } else {
      _sqlParts[sqlPartName] = sqlPart;
    }
    return this;
  }

  Builder select(String select) {
    _sqlParts['select'] = new List();
    return addSelect(select);
  }

  Builder addSelect(String select) {
    _type = Builder.SELECT;
    return this.add('select', select, true);
  }

  Builder delete(String del) {
    _type = Builder.DELETE;
    return this.add('from', del, true);
  }

  Builder insert(String update) {
    _type = Builder.INSERT;
    return this.add('from', update, true);
  }

  Builder update(String update) {
    _type = Builder.UPDATE;
    return this.add('from', update, true);
  }

  Builder from(String from) {
    return this.add('from', from, true);
  }

  Builder join(String joinTable, String condition) {
    return innerJoin(joinTable, condition);
  }

  Builder innerJoin(String joinTable, String condition) {
    return this.add(
        'join',
        {
          'joinType': 'INNER',
          'joinTable': joinTable,
          'joinCondition': condition
        },
        true);
  }

  Builder leftJoin(String joinTable, String condition) {
    return this.add(
        'join',
        {
          'joinType': 'LEFT',
          'joinTable': joinTable,
          'joinCondition': condition
        },
        true);
  }

  Builder rightJoin(String joinTable, String condition) {
    return this.add(
        'join',
        {
          'joinType': 'RIGHT',
          'joinTable': joinTable,
          'joinCondition': condition
        },
        true);
  }

  Builder set(String key, dynamic value) {
    return this.add('set', {key: value}, true);
  }

  Builder where(String where, [String where2 = '']) {
    if (where2 != '') where = new Expression('AND', [where, where2]).toString();
    return this.add('where', where);
  }

  Builder andWhere(String where) {
    return _exprBuilder('where', where, 'AND');
  }

  Builder orWhere(String where) {
    return _exprBuilder('where', where, 'OR');
  }

  Builder groupBy(String groupBy) {
    return addGroupBy(groupBy);
  }

  Builder addGroupBy(String groupBy) {
    return this.add('groupBy', groupBy, true);
  }

  Builder having(String having, [String having2 = '']) {
    if (having2 != '')
      having = new Expression('AND', [having, having2]).toString();
    return this.add('having', having);
  }

  Builder andHaving(String having) {
    return _exprBuilder('having', having, 'AND');
  }

  Builder orHaving(String having) {
    return _exprBuilder('having', having, 'OR');
  }

  Builder orderBy(String sort, [String order = 'ASC']) {
    _sqlParts['orderBy'] = new List();
    return this.add('orderBy', sort + ' ' + order, true);
  }

  Builder addOrderBy(String sort, [String order = 'ASC']) {
    return this.add('orderBy', sort + ' ' + order, true);
  }

  Builder setQueryPart(String queryPartName, dynamic queryPart) {
    _sqlParts[queryPartName] = queryPart;
    return this;
  }

  getQueryPart(String queryPartName) {
    return _sqlParts[queryPartName];
  }

  getQueryParts() {
    Map res = <String, dynamic>{};
    _sqlParts.forEach((k, v) => res[k] = v);
    return res;
  }

  Builder resetQueryParts(List queryPartNames) {
    if (queryPartNames.length == 0) {
      var queryPartNames = [];
      _sqlParts.forEach((k, v) => queryPartNames.add(k));
    }
    queryPartNames.forEach((e) => resetQueryPart(e));
    return this;
  }

  Builder resetQueryPart(String queryPartName) {
    _sqlParts[queryPartName] = (_sqlParts[queryPartName] is List) ? [] : '';
    _sql = '';
    return this;
  }

  isJoinPresent(String joinTable) {
    List joins = getQueryPart('join');
    for (int i = 0; i < joins.length; i++)
      if (joins[i]['joinTable'] == joinTable) return true;
    return false;
  }

  Builder _exprBuilder(String key, args, type, [bool append = false]) {
    var expr = this.getQueryPart(key);
    expr = (new Expression(type, [expr, args])).toString();
    return this.add(key, expr, append);
  }

  _getSQLForSelect() {
    StringBuffer sb = new StringBuffer()
      ..write('SELECT ')
      ..writeAll(_sqlParts['select'], ', ')
      ..write('\n FROM ')
      ..writeAll(_sqlParts['from'], ', ');
    if (_sqlParts['join'].length > 0) {
      _sqlParts['join'].forEach((e) {
        sb.write('\n ');
        sb.write(e['joinType']);
        sb.write(' JOIN ');
        sb.write(e['joinTable']);
        sb.write(' ON ');
        sb.write(e['joinCondition']);
      });
    }
    if (_sqlParts['where'] != '') {
      sb.write('\n WHERE ');
      sb.write(_sqlParts['where']);
    }
    if (_sqlParts['groupBy'].length > 0) {
      sb.write('\n GROUP BY ');
      sb.writeAll(_sqlParts['groupBy'], ', ');
    }
    if (_sqlParts['having'] != '') {
      sb.write('\n HAVING ');
      sb.write(_sqlParts['having']);
    }
    if (_sqlParts['orderBy'].length > 0) {
      sb.write('\n ORDER BY ');
      sb.writeAll(_sqlParts['orderBy'], ', ');
    }
    if (_limit > 0) {
      sb.write('\n LIMIT ' + _limit.toString());
      if (_offset > 0) sb.write(' OFFSET ' + _offset.toString());
    }
    return sb.toString();
  }

  _getSQLForUpdate() {
    List pairs = new List();
    _sqlParts['set'].forEach((s) {
      s.forEach((k, v) {
        pairs.add(k + ' = ' + v);
      });
    });
    StringBuffer sb = new StringBuffer()
      ..write('UPDATE ')
      ..write(_sqlParts['from'][0])
      ..write(' SET ')
      ..writeAll(pairs, ', ');
    if (_sqlParts['where'] != '') {
      sb.write('\n WHERE ');
      sb.write(_sqlParts['where']);
    }
    return sb.toString();
  }

  _getSQLForInsert() {
    List columns = new List();
    List values = new List();
    _sqlParts['set'].forEach((s) {
      s.forEach((k, v) {
        columns.add(k);
        values.add(v);
      });
    });
    StringBuffer sb = new StringBuffer()
      ..write('INSERT INTO ')
      ..write(_sqlParts['from'][0])
      ..write(' (')
      ..writeAll(columns, ', ')
      ..write(') VALUES (')
      ..writeAll(values, ', ')
      ..write(') RETURNING *');
    return sb.toString();
  }

  _getSQLForDelete() {
    StringBuffer sb = new StringBuffer()
      ..write('DELETE FROM ')
      ..write(_sqlParts['from'][0]);
    if (_sqlParts['where'] != '') {
      sb.write('\n WHERE ');
      sb.write(_sqlParts['where']);
    }
    return sb.toString();
  }

  Builder clone() {
    Builder clone = new Builder();
    _sqlParts.forEach((k, v) {
      if (v is List)
        v.forEach((s) => clone._sqlParts[k].add(s));
      else
        clone._sqlParts[k] = v;
    });
    clone._limit = _limit;
    clone._offset = _offset;
    clone._params = new Map.from(_params);
    return clone;
  }

  Builder cloneFilter() {
    Builder clone = new Builder();
    ['join', 'where', 'having'].forEach((k) {
      var v = _sqlParts[k];
      if (v is List)
        v.forEach((s) => clone._sqlParts[k].add(s));
      else
        clone._sqlParts[k] = v;
    });
    clone._params = new Map.from(_params);
    return clone;
  }

  toString() => getSQL();
}

class CollectionBuilder<E extends Entity<Application>, C extends Collection<E>,
    A extends Application> {
  static int _unique = 0;

  Builder query;

  Mapper<E, C, A> mapper;

  Map<String, dynamic> filter = new Map();

  Map<String, List<String>> filter_way = new Map();

  Map<String, String> filter_map = new Map();

  String order_field;

  String order_way;

  int _page = 0;

  int _limit = 0;

  C collection;

  CollectionBuilder(Builder q, Mapper<E, C, A> m) {
    query = q;
    mapper = m;
  }

  set limit(int limit) => _limit = limit;

  set page(int page) => _page = (page > 0) ? page : 0;

  void order(String order, String way) {
    if (order != null) {
      order_field = order;
      order_way = way ?? 'ASC';
    }
  }

  Future<CollectionBuilder<E, C, A>> process([total = false]) async {
    _queryFilter(query);
    _queryResult(query);
    collection = await mapper.loadC(query, total);
    return this;
  }

  String queryToString() {
    var q = query.clone();
    _queryFilter(q);
    _queryResult(q);
    return q.getSQL();
  }

  int get total => collection.totalResults;

  void _queryFilter(Builder query) {
    filter.forEach((k, value) {
      if (value != null) {
        filter_way.forEach((way, List a) {
          if (a.contains(k)) {
            var key = k;
            if (filter_map[k] != null) key = filter_map[k];
            _set(query, way, key, value);
          }
        });
      }
    });
  }

  void _queryResult(Builder query) {
    if (_limit != null) {
      query.limit(_limit);
      if (_page > 0) query.offset((_page - 1) * _limit);
    }
    if (order_field != null) {
      String k = order_field;
      if (filter_map[k] != null) k = filter_map[k];
      query.orderBy(k, order_way);
    }
  }

  void _set(Builder query, String way, String key, dynamic value) {
    String ph = _cleanPlaceHolder(key);
    switch (way) {
      case 'eq':
        if (value is List) {
          value.removeWhere((v) => v == null);
          if (value.isEmpty) return;
          var q = value.map((v) {
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
          query.andWhere('$key = @$ph').setParameter(ph, value);
        }
        break;
      case 'gt':
        query.andWhere('$key > @$ph').setParameter(ph, value);
        break;
      case 'lt':
        query.andWhere('$key < @$ph').setParameter(ph, value);
        break;
      case 'gte':
        query.andWhere('$key >= @$ph').setParameter(ph, value);
        break;
      case 'lte':
        query.andWhere('$key <= @$ph').setParameter(ph, value);
        break;
      case 'like':
        query
            .andWhere('CAST($key AS text) ILIKE @$ph')
            .setParameter(ph, '%$value%');
        break;
      case 'rlike':
        query
            .andWhere('CAST($key AS text) ILIKE @$ph')
            .setParameter(ph, '%$value');
        break;
      case 'llike':
        query
            .andWhere('CAST($key AS text) ILIKE @$ph')
            .setParameter(ph, '$value%');
        break;
      case 'tsquery':
        query
            .andWhere('to_tsvector($key) @@ to_tsquery(@$ph)')
            .setParameter(ph, new TSquery(value).toString());
        break;
      case 'date':
        if (value is List) {
          if (value[0] != null) {
            DateTime from = DateTime.parse(value[0]);
            query
                .andWhere('$key >= @date_from')
                .setParameter('date_from', from);
          }
          if (value[1] != null) {
            DateTime to = DateTime.parse(value[1]);
            to = to.add(new Duration(seconds: 86400));
            query.andWhere('$key < @date_to').setParameter('date_to', to);
          }
        }
        break;
    }
  }

  String _cleanPlaceHolder(String key) {
    return key.replaceAll(new RegExp(r'\.'), '_') + (++_unique).toString();
  }
}
