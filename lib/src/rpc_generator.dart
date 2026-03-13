class ZModelRpcGenerator {
  ZModelRpcGenerator({this.basePath = '/api/model'});

  final String basePath;

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
      '  String _path<T extends ZModel>(String operation) => "\$basePath/\${ZModel.modelNameOf<T>()}/\$operation";',
    );
    buffer.writeln();
    buffer.writeln(
      '  Map<String, String>? _queryParameters({'
      'Map<String, dynamic>? where, '
      'Map<String, dynamic>? select, '
      'Map<String, dynamic>? include, '
      'List<Map<String, String>>? orderBy, '
      'int? take, '
      'int? skip, '
      'Map<String, dynamic>? meta'
      '}) {',
    );
    buffer.writeln('    final payload = <String, dynamic>{');
    buffer.writeln("      ...?_let(where, (value) => {'where': value}),");
    buffer.writeln("      ...?_let(select, (value) => {'select': value}),");
    buffer.writeln("      ...?_let(include, (value) => {'include': value}),");
    buffer.writeln("      ...?_let(orderBy, (value) => {'orderBy': value}),");
    buffer.writeln("      ...?_let(take, (value) => {'take': value}),");
    buffer.writeln("      ...?_let(skip, (value) => {'skip': value}),");
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
      '  R? _let<TValue, R>(TValue? value, R Function(TValue value) builder) => value == null ? null : builder(value);',
    );
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
      "    final response = await _transport.send(ZenStackRpcMethod.get, _path<T>('findMany'), queryParameters: _queryParameters(where: where, select: select, include: include, orderBy: orderBy, take: take, skip: skip, meta: meta));",
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
      "    final response = await _transport.send(ZenStackRpcMethod.get, _path<T>('findUnique'), queryParameters: _queryParameters(where: where, select: select, include: include, meta: meta));",
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
      "    final response = await _transport.send(ZenStackRpcMethod.get, _path<T>('findFirst'), queryParameters: _queryParameters(where: where, select: select, include: include, orderBy: orderBy, skip: skip, meta: meta));",
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
      "    final response = await _transport.send(ZenStackRpcMethod.post, _path<T>('create'), body: {'data': data.toJson(), if (select != null) 'select': select, if (include != null) 'include': include});",
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
      "    final response = await _transport.send(ZenStackRpcMethod.post, _path<T>('update'), body: {'data': data.toJson(), if (where != null) 'where': where, if (select != null) 'select': select, if (include != null) 'include': include});",
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
      "    final response = await _transport.send(ZenStackRpcMethod.post, _path<T>('upsert'), body: {'create': create.toJson(), 'update': update.toJson(), if (where != null) 'where': where, if (select != null) 'select': select, if (include != null) 'include': include});",
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
      "    final response = await _transport.send(ZenStackRpcMethod.post, _path<T>('delete'), body: {'where': where});",
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
      "    final response = await _transport.send(ZenStackRpcMethod.post, _path<T>('createMany'), body: {'data': data.map((item) => item.toJson()).toList()});",
    );
    buffer.writeln(
      '    return Map<String, dynamic>.from(response as Map<String, dynamic>);',
    );
    buffer.writeln('  }');
    buffer.writeln();
    buffer.writeln(
      '  Future<Map<String, dynamic>> updateMany<T extends ZModel>('
      'Map<String, dynamic> data, {'
      'Map<String, dynamic>? where'
      '}) async {',
    );
    buffer.writeln(
      "    final response = await _transport.send(ZenStackRpcMethod.post, _path<T>('updateMany'), body: {'data': data, if (where != null) 'where': where});",
    );
    buffer.writeln(
      '    return Map<String, dynamic>.from(response as Map<String, dynamic>);',
    );
    buffer.writeln('  }');
    buffer.writeln();
    buffer.writeln(
      '  Future<Map<String, dynamic>> deleteMany<T extends ZModel>({'
      'Map<String, dynamic>? where'
      '}) async {',
    );
    buffer.writeln(
      "    final response = await _transport.send(ZenStackRpcMethod.post, _path<T>('deleteMany'), body: {if (where != null) 'where': where});",
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
      "    final response = await _transport.send(ZenStackRpcMethod.get, _path<T>('count'), queryParameters: _queryParameters(where: where, meta: meta));",
    );
    buffer.writeln('    return (response as num?)?.toInt() ?? 0;');
    buffer.writeln('  }');
    buffer.writeln('}');
    return buffer.toString();
  }
}
