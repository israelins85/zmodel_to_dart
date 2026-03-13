import 'dart:convert';

enum ZenStackRpcMethod { get, post }

abstract interface class ZenStackRpcTransport {
  Future<Object?> send(
    ZenStackRpcMethod method,
    String path, {
    Map<String, String>? queryParameters,
    Object? body,
  });
}

class ZModelRequest {
  ZModelRequest();

  ZModelRequest.from({Map<String, dynamic>? data, Map<String, dynamic>? meta}) {
    if (data != null) {
      _data.addAll(data);
    }
    if (meta != null) {
      _meta.addAll(meta);
    }
  }

  final Map<String, dynamic> _data = {};
  final Map<String, dynamic> _meta = {};

  ZModelRequest select(Map<String, dynamic> fields) {
    _data['select'] = fields;
    return this;
  }

  ZModelRequest where(Map<String, dynamic> conditions) {
    _data['where'] = conditions;
    return this;
  }

  ZModelRequest orderBy(List<Map<String, String>> orders) {
    _data['orderBy'] = orders;
    return this;
  }

  ZModelRequest include(Map<String, dynamic> relations) {
    _data['include'] = relations;
    return this;
  }

  ZModelRequest take(int limit) {
    _data['take'] = limit;
    return this;
  }

  ZModelRequest skip(int offset) {
    _data['skip'] = offset;
    return this;
  }

  ZModelRequest addMeta(String path, List<String> types) {
    final serialization =
        _meta.putIfAbsent('serialization', () => <String, dynamic>{})
            as Map<String, dynamic>;
    final values =
        serialization.putIfAbsent('values', () => <String, dynamic>{})
            as Map<String, dynamic>;
    values[path] = types;
    return this;
  }

  ZModelRequest create(Map<String, dynamic> data) {
    _data['data'] = data;
    return this;
  }

  ZModelRequest update(
    Map<String, dynamic> data, {
    Map<String, dynamic>? where,
  }) {
    _data['data'] = data;
    if (where != null) {
      _data['where'] = where;
    }
    return this;
  }

  ZModelRequest upsert({
    required Map<String, dynamic> create,
    required Map<String, dynamic> update,
    Map<String, dynamic>? where,
  }) {
    _data['create'] = create;
    _data['update'] = update;
    if (where != null) {
      _data['where'] = where;
    }
    return this;
  }

  ZModelRequest delete(Map<String, dynamic> where) {
    _data['where'] = where;
    return this;
  }

  ZModelRequest deleteMany(Map<String, dynamic> where) {
    _data['where'] = where;
    return this;
  }

  String get asQueryString {
    final query = <String>[];
    query.add('q=${Uri.encodeComponent(jsonEncode(_data))}');
    if (_meta.isNotEmpty) {
      query.add('meta=${Uri.encodeComponent(jsonEncode(_meta))}');
    }
    return query.join('&');
  }

  Map<String, String> get asQueryParameters {
    final params = <String, String>{'q': jsonEncode(_data)};
    if (_meta.isNotEmpty) {
      params['meta'] = jsonEncode(_meta);
    }
    return params;
  }

  Map<String, dynamic> get asBody => Map<String, dynamic>.unmodifiable(_data);

  Map<String, dynamic> get data => Map<String, dynamic>.unmodifiable(_data);

  Map<String, dynamic> get meta => Map<String, dynamic>.unmodifiable(_meta);
}
