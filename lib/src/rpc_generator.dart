/// Generates the inline ZenStack RPC client source code.
class ZModelRpcGenerator {
  /// Creates an RPC generator with the given base path.
  ZModelRpcGenerator({this.basePath = '/api/model'});

  /// Base path used by generated RPC endpoints.
  final String basePath;

  /// Renders the generic RPC client class source.
  String renderClient() {
    final buffer = StringBuffer();
    buffer.writeln('class ZModelRpcClient {');
    buffer.writeln('  ZModelRpcClient(this._transport, {String? basePath})');
    buffer.writeln("    : basePath = basePath ?? '$basePath';");
    buffer.writeln();
    buffer.writeln('  final ZenStackRpcTransport _transport;');
    buffer.writeln('  final String basePath;');
    buffer.writeln();
    buffer.writeln(
      '  String _path<T extends ZModel>(String operation) => \'\$basePath/\${ZModel.modelNameOf<T>()}/\$operation\';',
    );
    buffer.writeln();
    buffer.writeln('  Future<Object?> _send(');
    buffer.writeln('    ZenStackRpcMethod method,');
    buffer.writeln('    String path, {');
    buffer.writeln('    Map<String, String>? queryParameters,');
    buffer.writeln('    Object? body,');
    buffer.writeln('  }) async {');
    buffer.writeln(
      '    final response = await _transport.send(method, path, queryParameters: queryParameters, body: body);',
    );
    buffer.writeln('    return _decodeResponse(response);');
    buffer.writeln('  }');
    buffer.writeln();
    buffer.writeln('  Object? _decodeResponse(Object? response) {');
    buffer.writeln('    if (response is String) {');
    buffer.writeln('      try {');
    buffer.writeln('        return _decodeResponse(jsonDecode(response));');
    buffer.writeln('      } catch (_) {');
    buffer.writeln('        return response;');
    buffer.writeln('      }');
    buffer.writeln('    }');
    buffer.writeln();
    buffer.writeln('    if (_looksLikeSerializedEnvelope(response)) {');
    buffer.writeln(
      '      return _deserializeSerializedResponse(response as Map<Object?, Object?>);',
    );
    buffer.writeln('    }');
    buffer.writeln();
    buffer.writeln('    return _normalizeJsonValue(response);');
    buffer.writeln('  }');
    buffer.writeln();
    buffer.writeln('  bool _looksLikeSerializedEnvelope(Object? value) {');
    buffer.writeln('    if (value is! Map<Object?, Object?>) return false;');
    buffer.writeln("    final data = value['data'] ?? value['json'];");
    buffer.writeln(
      "    if (data is List || data is Map<Object?, Object?>) return true;",
    );
    buffer.writeln(
      "    return value.containsKey('json') && value.containsKey('meta');",
    );
    buffer.writeln('  }');
    buffer.writeln();
    buffer.writeln(
      '  Object? _deserializeSerializedResponse(Map<Object?, Object?> response) {',
    );
    buffer.writeln(
      "    final data = _normalizeJsonValue(response.containsKey('data') ? response['data'] : response['json']);",
    );
    buffer.writeln("    final values = _serializedValues(response['meta']);");
    buffer.writeln('    if (values is! Map<Object?, Object?>) return data;');
    buffer.writeln('    for (final entry in values.entries) {');
    buffer.writeln('      final key = entry.key?.toString();');
    buffer.writeln('      if (key == null || key.isEmpty) continue;');
    buffer.writeln(
      "      _applySuperJsonAnnotation(data, key.split('.'), entry.value);",
    );
    buffer.writeln('    }');
    buffer.writeln('    return data;');
    buffer.writeln('  }');
    buffer.writeln();
    buffer.writeln('  Object? _serializedValues(Object? meta) {');
    buffer.writeln('    if (meta is! Map<Object?, Object?>) return null;');
    buffer.writeln("    final values = meta['values'];");
    buffer.writeln('    if (values is Map<Object?, Object?>) return values;');
    buffer.writeln("    final serialization = meta['serialization'];");
    buffer.writeln(
      '    if (serialization is! Map<Object?, Object?>) return null;',
    );
    buffer.writeln("    final serializationValues = serialization['values'];");
    buffer.writeln(
      '    if (serializationValues is Map<Object?, Object?>) return serializationValues;',
    );
    buffer.writeln('    return null;');
    buffer.writeln('  }');
    buffer.writeln();
    buffer.writeln('  void _applySuperJsonAnnotation(');
    buffer.writeln('    Object? current,');
    buffer.writeln('    List<String> path,');
    buffer.writeln('    Object? annotation,');
    buffer.writeln('  ) {');
    buffer.writeln('    if (path.isEmpty) return;');
    buffer.writeln();
    buffer.writeln('    final segment = path.first;');
    buffer.writeln('    if (current is List) {');
    buffer.writeln('      final index = int.tryParse(segment);');
    buffer.writeln(
      '      if (index == null || index < 0 || index >= current.length) return;',
    );
    buffer.writeln('      if (path.length == 1) {');
    buffer.writeln(
      '        current[index] = _deserializeSuperJsonValue(current[index], annotation);',
    );
    buffer.writeln('        return;');
    buffer.writeln('      }');
    buffer.writeln(
      '      _applySuperJsonAnnotation(current[index], path.sublist(1), annotation);',
    );
    buffer.writeln('      return;');
    buffer.writeln('    }');
    buffer.writeln();
    buffer.writeln('    if (current is Map<String, dynamic>) {');
    buffer.writeln("      if (!current.containsKey(segment)) return;");
    buffer.writeln('      if (path.length == 1) {');
    buffer.writeln(
      '        current[segment] = _deserializeSuperJsonValue(current[segment], annotation);',
    );
    buffer.writeln('        return;');
    buffer.writeln('      }');
    buffer.writeln(
      '      _applySuperJsonAnnotation(current[segment], path.sublist(1), annotation);',
    );
    buffer.writeln('    }');
    buffer.writeln('  }');
    buffer.writeln();
    buffer.writeln('  Object? _deserializeSuperJsonValue(');
    buffer.writeln('    Object? value,');
    buffer.writeln('    Object? annotation,');
    buffer.writeln('  ) {');
    buffer.writeln('    final type = _superJsonType(annotation);');
    buffer.writeln('    switch (type) {');
    buffer.writeln("      case 'date':");
    buffer.writeln(
      '        if (value is String) return DateTime.tryParse(value) ?? value;',
    );
    buffer.writeln('        return value;');
    buffer.writeln("      case 'bigint':");
    buffer.writeln('        if (value is BigInt) return value;');
    buffer.writeln('        if (value is int) return BigInt.from(value);');
    buffer.writeln(
      '        if (value is num) return BigInt.from(value.toInt());',
    );
    buffer.writeln(
      '        if (value is String) return BigInt.tryParse(value) ?? value;',
    );
    buffer.writeln('        return value;');
    buffer.writeln('      default:');
    buffer.writeln('        return value;');
    buffer.writeln('    }');
    buffer.writeln('  }');
    buffer.writeln();
    buffer.writeln('  String? _superJsonType(Object? annotation) {');
    buffer.writeln('    if (annotation is List && annotation.isNotEmpty) {');
    buffer.writeln('      return annotation.first?.toString().toLowerCase();');
    buffer.writeln('    }');
    buffer.writeln('    return annotation?.toString().toLowerCase();');
    buffer.writeln('  }');
    buffer.writeln();
    buffer.writeln('  Object? _normalizeJsonValue(Object? value) {');
    buffer.writeln('    if (value is List) {');
    buffer.writeln('      return value.map(_normalizeJsonValue).toList();');
    buffer.writeln('    }');
    buffer.writeln();
    buffer.writeln('    if (value is Map<Object?, Object?>) {');
    buffer.writeln('      return <String, dynamic>{');
    buffer.writeln(
      '        for (final entry in value.entries) entry.key.toString(): _normalizeJsonValue(entry.value),',
    );
    buffer.writeln('      };');
    buffer.writeln('    }');
    buffer.writeln();
    buffer.writeln('    return value;');
    buffer.writeln('  }');
    buffer.writeln();
    buffer.writeln(
      '  Map<String, String>? _queryParameters({'
      'Map<String, dynamic>? where, '
      'Map<String, dynamic>? select, '
      'Map<String, dynamic>? include, '
      'Map<String, dynamic>? having, '
      'List<Map<String, String>>? orderBy, '
      'List<String>? by, '
      'int? take, '
      'int? skip, '
      'Map<String, dynamic>? count, '
      'Map<String, dynamic>? avg, '
      'Map<String, dynamic>? sum, '
      'Map<String, dynamic>? min, '
      'Map<String, dynamic>? max, '
      'Map<String, dynamic>? meta'
      '}) {',
    );
    buffer.writeln('    final payload = <String, dynamic>{');
    buffer.writeln("      'where': ?where,");
    buffer.writeln("      'select': ?select,");
    buffer.writeln("      'include': ?include,");
    buffer.writeln("      'having': ?having,");
    buffer.writeln("      'orderBy': ?orderBy,");
    buffer.writeln("      'by': ?by,");
    buffer.writeln("      'take': ?take,");
    buffer.writeln("      'skip': ?skip,");
    buffer.writeln("      '_count': ?count,");
    buffer.writeln("      '_avg': ?avg,");
    buffer.writeln("      '_sum': ?sum,");
    buffer.writeln("      '_min': ?min,");
    buffer.writeln("      '_max': ?max,");
    buffer.writeln('    };');
    buffer.writeln(
      '    if (payload.isEmpty && (meta == null || meta.isEmpty)) return null;',
    );
    buffer.writeln(
      "    final params = <String, String>{'q': jsonEncode(payload)};",
    );
    buffer.writeln('    if (meta != null && meta.isNotEmpty) {');
    buffer.writeln("      params['meta'] = jsonEncode(meta);");
    buffer.writeln('    }');
    buffer.writeln('    return params;');
    buffer.writeln('  }');
    buffer.writeln();
    buffer.writeln(
      '  Future<List<T>> findMany<T extends ZModel>({'
      'Map<String, dynamic>? where, '
      'Map<String, dynamic>? select, '
      'Map<String, dynamic>? include, '
      'List<Map<String, String>>? orderBy, '
      'int? take, '
      'int? skip, '
      'Map<String, dynamic>? meta'
      '}) async {',
    );
    buffer.writeln(
      "    final response = await _send(ZenStackRpcMethod.get, _path<T>('findMany'), queryParameters: _queryParameters(where: where, select: select, include: include, orderBy: orderBy, take: take, skip: skip, meta: meta));",
    );
    buffer.writeln('    final items = response as List<dynamic>? ?? const [];');
    buffer.writeln('    return ZModel.listFromJson<T>(items);');
    buffer.writeln('  }');
    buffer.writeln();
    buffer.writeln(
      '  Future<T?> findUnique<T extends ZModel>({'
      'Map<String, dynamic>? where, '
      'Map<String, dynamic>? select, '
      'Map<String, dynamic>? include, '
      'Map<String, dynamic>? meta'
      '}) async {',
    );
    buffer.writeln(
      "    final response = await _send(ZenStackRpcMethod.get, _path<T>('findUnique'), queryParameters: _queryParameters(where: where, select: select, include: include, meta: meta));",
    );
    buffer.writeln('    if (response == null) return null;');
    buffer.writeln(
      '    return ZModel.fromJson<T>(response as Map<String, dynamic>);',
    );
    buffer.writeln('  }');
    buffer.writeln();
    buffer.writeln(
      '  Future<T?> findFirst<T extends ZModel>({'
      'Map<String, dynamic>? where, '
      'Map<String, dynamic>? select, '
      'Map<String, dynamic>? include, '
      'List<Map<String, String>>? orderBy, '
      'int? skip, '
      'Map<String, dynamic>? meta'
      '}) async {',
    );
    buffer.writeln(
      "    final response = await _send(ZenStackRpcMethod.get, _path<T>('findFirst'), queryParameters: _queryParameters(where: where, select: select, include: include, orderBy: orderBy, skip: skip, meta: meta));",
    );
    buffer.writeln('    if (response == null) return null;');
    buffer.writeln(
      '    return ZModel.fromJson<T>(response as Map<String, dynamic>);',
    );
    buffer.writeln('  }');
    buffer.writeln();
    buffer.writeln(
      '  Future<T> create<T extends ZModel>('
      'T data, {'
      'Map<String, dynamic>? select, '
      'Map<String, dynamic>? include'
      '}) async {',
    );
    buffer.writeln(
      "    final response = await _send(ZenStackRpcMethod.post, _path<T>('create'), body: {'data': data.toJson(), 'select': ?select, 'include': ?include});",
    );
    buffer.writeln(
      '    return ZModel.fromJson<T>(response as Map<String, dynamic>);',
    );
    buffer.writeln('  }');
    buffer.writeln();
    buffer.writeln(
      '  Future<T> update<T extends ZModel>('
      'T data, {'
      'Map<String, dynamic>? where, '
      'Map<String, dynamic>? select, '
      'Map<String, dynamic>? include'
      '}) async {',
    );
    buffer.writeln(
      "    final response = await _send(ZenStackRpcMethod.put, _path<T>('update'), body: {'data': data.toJson(), 'where': ?where, 'select': ?select, 'include': ?include});",
    );
    buffer.writeln(
      '    return ZModel.fromJson<T>(response as Map<String, dynamic>);',
    );
    buffer.writeln('  }');
    buffer.writeln();
    buffer.writeln(
      '  Future<T> upsert<T extends ZModel>({'
      'required T create, '
      'required T update, '
      'Map<String, dynamic>? where, '
      'Map<String, dynamic>? select, '
      'Map<String, dynamic>? include'
      '}) async {',
    );
    buffer.writeln(
      "    final response = await _send(ZenStackRpcMethod.post, _path<T>('upsert'), body: {'create': create.toJson(), 'update': update.toJson(), 'where': ?where, 'select': ?select, 'include': ?include});",
    );
    buffer.writeln(
      '    return ZModel.fromJson<T>(response as Map<String, dynamic>);',
    );
    buffer.writeln('  }');
    buffer.writeln();
    buffer.writeln(
      '  Future<T> delete<T extends ZModel>({'
      'required Map<String, dynamic> where'
      '}) async {',
    );
    buffer.writeln(
      "    final response = await _send(ZenStackRpcMethod.delete, _path<T>('delete'), queryParameters: _queryParameters(where: where));",
    );
    buffer.writeln(
      '    return ZModel.fromJson<T>(response as Map<String, dynamic>);',
    );
    buffer.writeln('  }');
    buffer.writeln();
    buffer.writeln(
      '  Future<Map<String, dynamic>> createMany<T extends ZModel>('
      'List<T> data'
      ') async {',
    );
    buffer.writeln(
      "    final response = await _send(ZenStackRpcMethod.post, _path<T>('createMany'), body: {'data': data.map((item) => item.toJson()).toList()});",
    );
    buffer.writeln(
      '    return Map<String, dynamic>.from(response as Map<String, dynamic>);',
    );
    buffer.writeln('  }');
    buffer.writeln();
    buffer.writeln(
      '  Future<List<T>> createManyAndReturn<T extends ZModel>('
      'List<T> data, {'
      'Map<String, dynamic>? select, '
      'Map<String, dynamic>? include'
      '}) async {',
    );
    buffer.writeln(
      "    final response = await _send(ZenStackRpcMethod.post, _path<T>('createManyAndReturn'), body: {'data': data.map((item) => item.toJson()).toList(), 'select': ?select, 'include': ?include});",
    );
    buffer.writeln('    final items = response as List<dynamic>? ?? const [];');
    buffer.writeln('    return ZModel.listFromJson<T>(items);');
    buffer.writeln('  }');
    buffer.writeln();
    buffer.writeln(
      '  Future<Map<String, dynamic>> updateMany<T extends ZModel>({'
      'required Map<String, dynamic> data, '
      'required Map<String, dynamic> where'
      '}) async {',
    );
    buffer.writeln(
      "    final response = await _send(ZenStackRpcMethod.put, _path<T>('updateMany'), body: {'data': data, 'where': where});",
    );
    buffer.writeln(
      '    return Map<String, dynamic>.from(response as Map<String, dynamic>);',
    );
    buffer.writeln('  }');
    buffer.writeln();
    buffer.writeln(
      '  Future<Map<String, dynamic>> deleteMany<T extends ZModel>({'
      'required Map<String, dynamic> where'
      '}) async {',
    );
    buffer.writeln(
      "    final response = await _send(ZenStackRpcMethod.delete, _path<T>('deleteMany'), queryParameters: _queryParameters(where: where));",
    );
    buffer.writeln(
      '    return Map<String, dynamic>.from(response as Map<String, dynamic>);',
    );
    buffer.writeln('  }');
    buffer.writeln();
    buffer.writeln(
      '  Future<int> count<T extends ZModel>({'
      'Map<String, dynamic>? where, '
      'Map<String, dynamic>? meta'
      '}) async {',
    );
    buffer.writeln(
      "    final response = await _send(ZenStackRpcMethod.get, _path<T>('count'), queryParameters: _queryParameters(where: where, meta: meta));",
    );
    buffer.writeln('    return (response as num?)?.toInt() ?? 0;');
    buffer.writeln('  }');
    buffer.writeln();
    buffer.writeln(
      '  Future<Map<String, dynamic>> aggregate<T extends ZModel>({'
      'Map<String, dynamic>? where, '
      'List<Map<String, String>>? orderBy, '
      'int? take, '
      'int? skip, '
      'Map<String, dynamic>? count, '
      'Map<String, dynamic>? avg, '
      'Map<String, dynamic>? sum, '
      'Map<String, dynamic>? min, '
      'Map<String, dynamic>? max, '
      'Map<String, dynamic>? meta'
      '}) async {',
    );
    buffer.writeln(
      "    final response = await _send(ZenStackRpcMethod.get, _path<T>('aggregate'), queryParameters: _queryParameters(where: where, orderBy: orderBy, take: take, skip: skip, count: count, avg: avg, sum: sum, min: min, max: max, meta: meta));",
    );
    buffer.writeln(
      '    return Map<String, dynamic>.from(response as Map<String, dynamic>? ?? const <String, dynamic>{});',
    );
    buffer.writeln('  }');
    buffer.writeln();
    buffer.writeln(
      '  Future<List<Map<String, dynamic>>> groupBy<T extends ZModel>({'
      'required List<String> by, '
      'Map<String, dynamic>? where, '
      'Map<String, dynamic>? having, '
      'List<Map<String, String>>? orderBy, '
      'int? take, '
      'int? skip, '
      'Map<String, dynamic>? count, '
      'Map<String, dynamic>? avg, '
      'Map<String, dynamic>? sum, '
      'Map<String, dynamic>? min, '
      'Map<String, dynamic>? max, '
      'Map<String, dynamic>? meta'
      '}) async {',
    );
    buffer.writeln(
      "    final response = await _send(ZenStackRpcMethod.get, _path<T>('groupBy'), queryParameters: _queryParameters(by: by, where: where, having: having, orderBy: orderBy, take: take, skip: skip, count: count, avg: avg, sum: sum, min: min, max: max, meta: meta));",
    );
    buffer.writeln('    final items = response as List<dynamic>? ?? const [];');
    buffer.writeln(
      '    return items.map((item) => Map<String, dynamic>.from(item as Map)).toList();',
    );
    buffer.writeln('  }');
    buffer.writeln('}');
    return buffer.toString();
  }
}
