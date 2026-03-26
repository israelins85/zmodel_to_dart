import 'dart:convert';

/// Supported HTTP verbs for the generated ZenStack RPC client.
enum ZenStackRpcMethod {
  /// Sends request data using HTTP GET.
  get,

  /// Sends request data using HTTP POST.
  post,

  /// Sends request data using HTTP PATCH.
  patch,

  /// Sends request data using HTTP DELETE.
  delete,
}

/// Transport abstraction used by generated RPC clients.
abstract interface class ZenStackRpcTransport {
  /// Sends a request to the RPC backend and returns the decoded response body.
  Future<Object?> send(
    ZenStackRpcMethod method,
    String path, {
    Map<String, String>? queryParameters,
    Object? body,
  });
}

/// Mutable helper for building ZenStack RPC query strings and request bodies.
class ZModelRequest {
  /// Creates an empty request builder.
  ZModelRequest();

  /// Creates a request builder from prebuilt payload and meta maps.
  ZModelRequest.from({Map<String, dynamic>? data, Map<String, dynamic>? meta}) {
    _data.addAll(data ?? const {});
    _meta.addAll(meta ?? const {});
  }

  final Map<String, dynamic> _data = {};
  final Map<String, dynamic> _meta = {};

  /// Sets the `select` clause.
  ZModelRequest select(Map<String, dynamic> fields) {
    _data['select'] = fields;
    return this;
  }

  /// Sets the `where` clause.
  ZModelRequest where(Map<String, dynamic> conditions) {
    _data['where'] = conditions;
    return this;
  }

  /// Sets the `orderBy` clause.
  ZModelRequest orderBy(List<Map<String, String>> orders) {
    _data['orderBy'] = orders;
    return this;
  }

  /// Sets the `include` clause.
  ZModelRequest include(Map<String, dynamic> relations) {
    _data['include'] = relations;
    return this;
  }

  /// Sets the `take` limit.
  ZModelRequest take(int limit) {
    _data['take'] = limit;
    return this;
  }

  /// Sets the `skip` offset.
  ZModelRequest skip(int offset) {
    _data['skip'] = offset;
    return this;
  }

  /// Adds serialization metadata for special value handling.
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

  /// Sets the `data` payload for create operations.
  ZModelRequest create(Map<String, dynamic> data) {
    _data['data'] = data;
    return this;
  }

  /// Sets the `data` payload and optional `where` clause for update operations.
  ZModelRequest update(
    Map<String, dynamic> data, {
    Map<String, dynamic>? where,
  }) {
    _data.addAll({'data': data, 'where': ?where});
    return this;
  }

  /// Sets the payload for upsert operations.
  ZModelRequest upsert({
    required Map<String, dynamic> create,
    required Map<String, dynamic> update,
    Map<String, dynamic>? where,
  }) {
    _data.addAll({'create': create, 'update': update, 'where': ?where});
    return this;
  }

  /// Sets the `where` clause for delete operations.
  ZModelRequest delete(Map<String, dynamic> where) {
    _data['where'] = where;
    return this;
  }

  /// Sets the `where` clause for deleteMany operations.
  ZModelRequest deleteMany([Map<String, dynamic>? where]) {
    if (where != null) {
      _data['where'] = where;
    }
    return this;
  }

  /// Sets the `data` payload for createMany operations.
  ZModelRequest createMany(List<Map<String, dynamic>> data) {
    _data['data'] = data;
    return this;
  }

  /// Sets the payload for createManyAndReturn operations.
  ZModelRequest createManyAndReturn(
    List<Map<String, dynamic>> data, {
    Map<String, dynamic>? select,
    Map<String, dynamic>? include,
  }) {
    _data.addAll({'data': data, 'select': ?select, 'include': ?include});
    return this;
  }

  /// Sets the payload for updateMany operations.
  ZModelRequest updateMany(
    Map<String, dynamic> data, {
    Map<String, dynamic>? where,
  }) {
    _data.addAll({'data': data, 'where': ?where});
    return this;
  }

  /// Sets the payload for updateManyAndReturn operations.
  ZModelRequest updateManyAndReturn(
    Map<String, dynamic> data, {
    Map<String, dynamic>? where,
    Map<String, dynamic>? select,
    Map<String, dynamic>? include,
  }) {
    _data.addAll({
      'data': data,
      'where': ?where,
      'select': ?select,
      'include': ?include,
    });
    return this;
  }

  /// Sets the payload for aggregate operations.
  ZModelRequest aggregate({
    Map<String, dynamic>? where,
    List<Map<String, String>>? orderBy,
    int? take,
    int? skip,
    Map<String, dynamic>? count,
    Map<String, dynamic>? avg,
    Map<String, dynamic>? sum,
    Map<String, dynamic>? min,
    Map<String, dynamic>? max,
  }) {
    _data.addAll({
      'where': ?where,
      'orderBy': ?orderBy,
      'take': ?take,
      'skip': ?skip,
      '_count': ?count,
      '_avg': ?avg,
      '_sum': ?sum,
      '_min': ?min,
      '_max': ?max,
    });
    return this;
  }

  /// Sets the payload for groupBy operations.
  ZModelRequest groupBy({
    required List<String> by,
    Map<String, dynamic>? where,
    Map<String, dynamic>? having,
    List<Map<String, String>>? orderBy,
    int? take,
    int? skip,
    Map<String, dynamic>? count,
    Map<String, dynamic>? avg,
    Map<String, dynamic>? sum,
    Map<String, dynamic>? min,
    Map<String, dynamic>? max,
  }) {
    _data.addAll({
      'by': by,
      'where': ?where,
      'having': ?having,
      'orderBy': ?orderBy,
      'take': ?take,
      'skip': ?skip,
      '_count': ?count,
      '_avg': ?avg,
      '_sum': ?sum,
      '_min': ?min,
      '_max': ?max,
    });
    return this;
  }

  /// Encodes the request into a raw query string.
  String get asQueryString {
    final query = <String>[];
    query.add('q=${Uri.encodeComponent(jsonEncode(_data))}');
    if (_meta.isNotEmpty) {
      query.add('meta=${Uri.encodeComponent(jsonEncode(_meta))}');
    }
    return query.join('&');
  }

  /// Encodes the request into query parameters expected by ZenStack RPC.
  Map<String, String> get asQueryParameters {
    final params = <String, String>{'q': jsonEncode(_data)};
    if (_meta.isNotEmpty) {
      params['meta'] = jsonEncode(_meta);
    }
    return params;
  }

  /// Returns the request body payload.
  Map<String, dynamic> get asBody => Map<String, dynamic>.unmodifiable(_data);

  /// Returns the accumulated data map.
  Map<String, dynamic> get data => Map<String, dynamic>.unmodifiable(_data);

  /// Returns the accumulated metadata map.
  Map<String, dynamic> get meta => Map<String, dynamic>.unmodifiable(_meta);
}
