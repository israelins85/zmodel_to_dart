import 'dart:io';

import 'rpc_generator.dart';

/// Parses `.zmodel` schema source and renders Dart output.
class ZModelGenerator {
  /// Creates a generator with an optional file banner.
  ZModelGenerator({this.banner = '// AUTO GENERATED FILE, DO NOT EDIT'});

  /// Banner written at the top of generated files.
  final String banner;

  /// Parses raw `.zmodel` source into model and enum definitions.
  ParsedZModel parse(String source) {
    final lines = source.split('\n');
    TableDefinition? tableDefinition;
    EnumDefinition? enumDefinition;
    final tables = <String, TableDefinition>{};
    final enums = <EnumDefinition>[];

    for (final line in lines) {
      final trimmedLine = line.trim();

      if (trimmedLine.isEmpty) continue;
      if (trimmedLine.startsWith('//')) continue;

      if (trimmedLine.startsWith('model ') ||
          trimmedLine.startsWith('abstract model ')) {
        if (tableDefinition != null) {
          tables[tableDefinition.name] = tableDefinition;
          tableDefinition = null;
        }
        if (enumDefinition != null) {
          enums.add(enumDefinition);
          enumDefinition = null;
        }

        final isAbstract = trimmedLine.startsWith('abstract model ');
        final modelName = trimmedLine
            .substring((isAbstract ? 'abstract model ' : 'model ').length)
            .split('{')[0]
            .trim();
        final extendsParts = modelName.split(' extends ');
        final extendsName = extendsParts.length > 1
            ? extendsParts[1].trim()
            : '';
        final tableName = extendsParts[0].trim();
        tableDefinition = TableDefinition(
          name: tableName,
          isAbstract: isAbstract,
          extendsTableName: extendsName,
        );
        continue;
      }

      if (trimmedLine.startsWith('enum ')) {
        if (tableDefinition != null) {
          tables[tableDefinition.name] = tableDefinition;
          tableDefinition = null;
        }
        if (enumDefinition != null) {
          enums.add(enumDefinition);
          enumDefinition = null;
        }

        final enumName = trimmedLine
            .substring('enum '.length)
            .split('{')[0]
            .trim();
        enumDefinition = EnumDefinition(name: enumName, values: []);
        continue;
      }

      if (tableDefinition != null) {
        if (trimmedLine == '}') {
          tables[tableDefinition.name] = tableDefinition;
          tableDefinition = null;
        } else {
          tableDefinition.parseColumn(trimmedLine);
        }
        continue;
      }

      if (enumDefinition != null) {
        if (trimmedLine == '}') {
          enums.add(enumDefinition);
          enumDefinition = null;
        } else {
          enumDefinition.addValue(trimmedLine);
        }
      }
    }

    if (tableDefinition != null) {
      tables[tableDefinition.name] = tableDefinition;
    }

    if (enumDefinition != null) {
      enums.add(enumDefinition);
    }

    for (final table in tables.values) {
      table.resolveExtends(tables);
    }

    final enumNames = enums.map((item) => item.name).toSet();
    for (final table in tables.values) {
      table.resolveCustomTypes(enumNames);
    }

    return ParsedZModel(tables: tables.values.toList(), enums: enums);
  }

  /// Generates one file per parsed declaration into [outputDir].
  void generateDirectory({
    required File sourceFile,
    required Directory outputDir,
    bool deleteExisting = true,
  }) {
    if (!sourceFile.existsSync()) {
      throw ArgumentError('ZModel file not found at ${sourceFile.path}');
    }

    if (outputDir.existsSync()) {
      if (deleteExisting) {
        outputDir.deleteSync(recursive: true);
        outputDir.createSync(recursive: true);
      }
    } else {
      outputDir.createSync(recursive: true);
    }

    final parsed = parse(sourceFile.readAsStringSync());

    for (final item in parsed.enums) {
      if (item.isEmpty) continue;
      final file = File('${outputDir.path}/${item.fileName}');
      file.writeAsStringSync(renderEnum(item));
    }

    for (final item in parsed.tables.where((table) => !table.isAbstract)) {
      final file = File('${outputDir.path}/${item.fileName}');
      file.writeAsStringSync(renderTable(item));
    }
  }

  /// Renders the parsed schema as a single Dart library.
  String renderSingleLibrary(
    ParsedZModel parsed, {
    bool includeRpcClients = false,
    String rpcBasePath = '/api/model',
  }) {
    final buffer = StringBuffer()
      ..writeln(banner)
      ..writeln('// dart format off')
      ..writeln();

    if (parsed.requiresConvertImport || includeRpcClients) {
      buffer.writeln("import 'dart:convert';");
    }
    if (parsed.requiresTypedDataImport) {
      buffer.writeln("import 'dart:typed_data';");
    }
    if (parsed.requiresConvertImport ||
        parsed.requiresTypedDataImport ||
        includeRpcClients) {
      buffer.writeln();
    }

    var first = true;
    final hasConcreteTables = parsed.tables.any((table) => !table.isAbstract);
    final hasEnums = parsed.enums.any((item) => !item.isEmpty);
    if (hasConcreteTables || includeRpcClients || hasEnums) {
      buffer.write(
        _renderModelScaffolding(
          parsed,
          includeZModel: hasConcreteTables || includeRpcClients,
          includeEnumBase: hasEnums,
        ),
      );
      first = false;
    }

    if (includeRpcClients) {
      if (!first) buffer.writeln();
      buffer.write(_renderRpcSupport());
      first = false;
    }

    for (final item in parsed.enums.where((item) => !item.isEmpty)) {
      if (!first) buffer.writeln();
      buffer.write(_renderEnumBody(item));
      first = false;
    }

    for (final item in parsed.tables.where((table) => !table.isAbstract)) {
      if (!first) buffer.writeln();
      buffer.write(_renderTableBody(item));
      first = false;
    }

    if (includeRpcClients) {
      final rpcClients = ZModelRpcGenerator(
        basePath: rpcBasePath,
      ).renderClient();
      if (rpcClients.isNotEmpty) {
        if (!first) buffer.writeln();
        buffer.write(rpcClients);
      }
    }

    return buffer.toString();
  }

  /// Renders an enum definition as its own Dart file.
  String renderEnum(EnumDefinition definition) {
    final buffer = StringBuffer()
      ..writeln(banner)
      ..writeln('// dart format off')
      ..writeln();
    buffer.write(
      _renderModelScaffolding(
        ParsedZModel(tables: const [], enums: [definition]),
        includeZModel: false,
        includeEnumBase: true,
      ),
    );
    buffer.writeln();
    buffer.write(_renderEnumBody(definition));
    return buffer.toString();
  }

  /// Renders a table definition as its own Dart file.
  String renderTable(TableDefinition definition) {
    final buffer = StringBuffer()
      ..writeln(banner)
      ..writeln('// dart format off')
      ..writeln();

    buffer.writeln("import 'package:zmodel_to_dart/zmodel_to_dart.dart';");
    buffer.writeln();

    if (definition.allColumns.any((column) => column.dartType == 'Uint8List')) {
      buffer.writeln("import 'dart:convert';");
      buffer.writeln("import 'dart:typed_data';");
      buffer.writeln();
    }

    for (final column in definition.allColumns.where(
      (column) => column.isForeignKey,
    )) {
      buffer.writeln("import './${column.zmodelType.toLowerCase()}.dart';");
    }

    if (definition.allColumns.any((column) => column.isForeignKey)) {
      buffer.writeln();
    }

    buffer.write(_renderTableBody(definition));
    return buffer.toString();
  }

  String _renderEnumBody(EnumDefinition definition) {
    final buffer = StringBuffer();
    buffer.writeln('enum ${definition.className} implements ZModelEnum {');

    var first = true;
    for (var value in definition.values) {
      if (!first) {
        buffer.writeln(',');
      } else {
        first = false;
      }
      final normalizedValue = value.replaceAll(',', '').trim();
      buffer.write(
        "  ${StringCase.camelCase.convert(normalizedValue)}('$normalizedValue')",
      );
    }
    buffer.writeln(';');
    buffer.writeln();
    buffer.writeln('  final String value;');
    buffer.writeln('  const ${definition.className}(this.value);');
    buffer.writeln();
    buffer.writeln(
      '  static ${definition.className}? fromJson(String? json) {',
    );
    buffer.writeln(
      '    return ZModelEnum.fromJson<${definition.className}>(${definition.className}.values, json);',
    );
    buffer.writeln('  }');
    buffer.writeln();
    buffer.writeln('  String toJson() => value;');
    buffer.writeln('}');
    return buffer.toString();
  }

  String _renderTableBody(TableDefinition definition) {
    final buffer = StringBuffer();
    buffer.writeln('class ${definition.className} extends ZModel {');

    for (final column in definition.allColumns) {
      buffer.writeln('  ${column.attributeDefinition}');
    }

    buffer.writeln();
    buffer.writeln('  ${definition.className}({');
    for (final column in definition.allColumns) {
      buffer.writeln('    ${column.attributeConstructor}');
    }
    buffer.writeln('  });');
    buffer.writeln();
    buffer.writeln(
      '  factory ${definition.className}.fromJson(Map<String, dynamic> json) {',
    );
    buffer.writeln('    return ${definition.className}(');
    for (final column in definition.allColumns) {
      buffer.writeln('      ${column.castFromJson},');
    }
    buffer.writeln('    );');
    buffer.writeln('  }');
    buffer.writeln();
    buffer.writeln('  Map<String, dynamic> toJson() {');
    buffer.writeln('    return {');
    for (final column in definition.allColumns) {
      buffer.writeln('      ${column.castToJson},');
    }
    buffer.writeln('    };');
    buffer.writeln('  }');
    buffer.writeln('}');
    return buffer.toString();
  }

  String _renderModelScaffolding(
    ParsedZModel parsed, {
    required bool includeZModel,
    required bool includeEnumBase,
  }) {
    final tables = parsed.tables.where((table) => !table.isAbstract).toList();
    final buffer = StringBuffer();
    if (includeEnumBase) {
      buffer.writeln('abstract interface class ZModelEnum {');
      buffer.writeln('  String get value;');
      buffer.writeln();
      buffer.writeln('  static T? fromJson<T extends Enum>(');
      buffer.writeln('    List<T> values,');
      buffer.writeln('    String? json,');
      buffer.writeln('  ) {');
      buffer.writeln('    if (json == null) return null;');
      buffer.writeln('    for (final value in values) {');
      buffer.writeln('      final enumValue = value as Object;');
      buffer.writeln(
        '      if (enumValue is ZModelEnum && enumValue.value == json) {',
      );
      buffer.writeln('        return value;');
      buffer.writeln('      }');
      buffer.writeln('    }');
      buffer.writeln('    return null;');
      buffer.writeln('  }');
      buffer.writeln('}');
    }
    if (includeEnumBase && includeZModel) {
      buffer.writeln();
    }
    if (includeZModel) {
      buffer.writeln('abstract class ZModel {');
      buffer.writeln('  const ZModel();');
      buffer.writeln();
      buffer.writeln('  Map<String, dynamic> toJson();');
      buffer.writeln();
      buffer.writeln('  static String modelNameOf<T extends ZModel>() {');
      buffer.writeln('    switch (T) {');
      for (final table in tables) {
        buffer.writeln(
          "      case const (${table.className}): return '${table.name}';",
        );
      }
      buffer.writeln(
        "      default: throw ArgumentError('Unknown ZModel type: \$T');",
      );
      buffer.writeln('    }');
      buffer.writeln('  }');
      buffer.writeln();
      buffer.writeln(
        '  static T fromJson<T extends ZModel>(Map<String, dynamic> json) {',
      );
      buffer.writeln('    switch (T) {');
      for (final table in tables) {
        buffer.writeln(
          '      case const (${table.className}): return ${table.className}.fromJson(json) as T;',
        );
      }
      buffer.writeln(
        "      default: throw ArgumentError('Unknown ZModel type: \$T');",
      );
      buffer.writeln('    }');
      buffer.writeln('  }');
      buffer.writeln();
      buffer.writeln(
        '  static List<T> listFromJson<T extends ZModel>(List<dynamic> items) {',
      );
      buffer.writeln(
        '    return items.map((item) => fromJson<T>(item as Map<String, dynamic>)).toList();',
      );
      buffer.writeln('  }');
      buffer.writeln();
      buffer.writeln(
        '  static T? modelOrNull<T extends ZModel>(Object? value) {',
      );
      buffer.writeln('    if (value == null) return null;');
      buffer.writeln(
        '    if (value is Map<String, dynamic>) return fromJson<T>(value);',
      );
      buffer.writeln('    if (value is Map<Object?, Object?>) {');
      buffer.writeln('      return fromJson<T>({');
      buffer.writeln(
        '        for (final entry in value.entries) entry.key.toString(): entry.value,',
      );
      buffer.writeln('      });');
      buffer.writeln('    }');
      buffer.writeln('    return null;');
      buffer.writeln('  }');
      buffer.writeln();
      buffer.writeln(
        '  static Map<String, dynamic>? modelToJsonOrNull(ZModel? value) {',
      );
      buffer.writeln('    return value?.toJson();');
      buffer.writeln('  }');
      buffer.writeln();
      buffer.writeln(
        '  static List<T>? listOrNull<T extends ZModel>(Object? value) {',
      );
      buffer.writeln('    if (value == null) return null;');
      buffer.writeln(
        '    if (value is List<dynamic>) return listFromJson<T>(value);',
      );
      buffer.writeln(
        '    if (value is List) return listFromJson<T>(value.toList());',
      );
      buffer.writeln('    return null;');
      buffer.writeln('  }');
      buffer.writeln();
      buffer.writeln(
        '  static List<Map<String, dynamic>>? listToJsonOrNull<T extends ZModel>(List<T>? value) {',
      );
      buffer.writeln(
        '    return value?.map((item) => item.toJson()).toList();',
      );
      buffer.writeln('  }');
      buffer.writeln();
      buffer.writeln('  static T? enumOrNull<T extends Enum>(');
      buffer.writeln('    List<T> values,');
      buffer.writeln('    Object? value,');
      buffer.writeln('  ) {');
      buffer.writeln(
        '    return ZModelEnum.fromJson<T>(values, stringOrNull(value));',
      );
      buffer.writeln('  }');
      buffer.writeln();
      buffer.writeln(
        '  static String? enumToJsonOrNull<T extends Enum>(T? value) {',
      );
      buffer.writeln('    final enumValue = value as Object?;');
      buffer.writeln(
        '    if (enumValue is ZModelEnum) return enumValue.value;',
      );
      buffer.writeln('    return null;');
      buffer.writeln('  }');
      buffer.writeln();
      buffer.writeln('  static List<T>? enumListOrNull<T extends Enum>(');
      buffer.writeln('    List<T> values,');
      buffer.writeln('    Object? value,');
      buffer.writeln('  ) {');
      buffer.writeln('    if (value == null) return null;');
      buffer.writeln('    if (value is! List) return null;');
      buffer.writeln(
        '    return value.map((item) => enumOrNull<T>(values, item)).whereType<T>().toList();',
      );
      buffer.writeln('  }');
      buffer.writeln();
      buffer.writeln(
        '  static List<String?>? enumListToJsonOrNull<T extends Enum>(List<T>? value) {',
      );
      buffer.writeln(
        '    return value?.map((item) => enumToJsonOrNull<T>(item)).toList();',
      );
      buffer.writeln('  }');
      buffer.writeln();
      buffer.writeln('  static String? stringOrNull(Object? value) {');
      buffer.writeln('    if (value == null) return null;');
      buffer.writeln('    if (value is String) return value;');
      buffer.writeln('    return value.toString();');
      buffer.writeln('  }');
      buffer.writeln();
      buffer.writeln('  static String stringOrEmpty(Object? value) {');
      buffer.writeln("    return stringOrNull(value) ?? '';");
      buffer.writeln('  }');
      buffer.writeln();
      buffer.writeln('  static String? stringToJsonOrNull(String? value) {');
      buffer.writeln('    return value;');
      buffer.writeln('  }');
      buffer.writeln();
      buffer.writeln('  static int? intOrNull(Object? value) {');
      buffer.writeln('    if (value == null) return null;');
      buffer.writeln('    if (value is int) return value;');
      buffer.writeln('    if (value is num) return value.toInt();');
      buffer.writeln('    return int.tryParse(value.toString());');
      buffer.writeln('  }');
      buffer.writeln();
      buffer.writeln('  static int intOrZero(Object? value) {');
      buffer.writeln('    return intOrNull(value) ?? 0;');
      buffer.writeln('  }');
      buffer.writeln();
      buffer.writeln('  static int? intToJsonOrNull(int? value) {');
      buffer.writeln('    return value;');
      buffer.writeln('  }');
      buffer.writeln();
      buffer.writeln('  static num? numOrNull(Object? value) {');
      buffer.writeln('    if (value == null) return null;');
      buffer.writeln('    if (value is num) return value;');
      buffer.writeln('    return num.tryParse(value.toString());');
      buffer.writeln('  }');
      buffer.writeln();
      buffer.writeln('  static num numOrZero(Object? value) {');
      buffer.writeln('    return numOrNull(value) ?? 0;');
      buffer.writeln('  }');
      buffer.writeln();
      buffer.writeln('  static num? numToJsonOrNull(num? value) {');
      buffer.writeln('    return value;');
      buffer.writeln('  }');
      buffer.writeln();
      buffer.writeln('  static bool? boolOrNull(Object? value) {');
      buffer.writeln('    if (value == null) return null;');
      buffer.writeln('    if (value is bool) return value;');
      buffer.writeln('    if (value is num) return value != 0;');
      buffer.writeln('    if (value is String) {');
      buffer.writeln('      switch (value.toLowerCase()) {');
      buffer.writeln("        case 'true':");
      buffer.writeln("        case '1':");
      buffer.writeln('          return true;');
      buffer.writeln("        case 'false':");
      buffer.writeln("        case '0':");
      buffer.writeln('          return false;');
      buffer.writeln('      }');
      buffer.writeln('    }');
      buffer.writeln('    return null;');
      buffer.writeln('  }');
      buffer.writeln();
      buffer.writeln('  static bool boolOrFalse(Object? value) {');
      buffer.writeln('    return boolOrNull(value) ?? false;');
      buffer.writeln('  }');
      buffer.writeln();
      buffer.writeln('  static bool? boolToJsonOrNull(bool? value) {');
      buffer.writeln('    return value;');
      buffer.writeln('  }');
      buffer.writeln();
      buffer.writeln('  static BigInt? bigIntOrNull(Object? value) {');
      buffer.writeln('    if (value == null) return null;');
      buffer.writeln('    if (value is BigInt) return value;');
      buffer.writeln('    if (value is int) return BigInt.from(value);');
      buffer.writeln(
        '    if (value is num) return BigInt.from(value.toInt());',
      );
      buffer.writeln('    return BigInt.tryParse(value.toString());');
      buffer.writeln('  }');
      buffer.writeln();
      buffer.writeln('  static BigInt bigIntOrZero(Object? value) {');
      buffer.writeln('    return bigIntOrNull(value) ?? BigInt.zero;');
      buffer.writeln('  }');
      buffer.writeln();
      buffer.writeln('  static String? bigIntToJsonOrNull(BigInt? value) {');
      buffer.writeln('    return value?.toString();');
      buffer.writeln('  }');
      buffer.writeln();
      buffer.writeln('  static DateTime? dateTimeOrNull(Object? value) {');
      buffer.writeln('    if (value is DateTime) return value;');
      buffer.writeln(
        '    if (value is String) return DateTime.tryParse(value);',
      );
      buffer.writeln('    return null;');
      buffer.writeln('  }');
      buffer.writeln();
      buffer.writeln('  static DateTime dateTimeOrZero(Object? value) {');
      buffer.writeln('    return dateTimeOrNull(value) ?? DateTime(0);');
      buffer.writeln('  }');
      buffer.writeln();
      buffer.writeln(
        '  static String? dateTimeToJsonOrNull(DateTime? value) {',
      );
      buffer.writeln('    return value?.toIso8601String();');
      buffer.writeln('  }');
      if (parsed.requiresConvertImport) {
        buffer.writeln();
        buffer.writeln('  static Uint8List? bytesOrNull(Object? value) {');
        buffer.writeln('    if (value == null) return null;');
        buffer.writeln('    if (value is Uint8List) return value;');
        buffer.writeln(
          '    if (value is List<int>) return Uint8List.fromList(value);',
        );
        buffer.writeln(
          '    if (value is List<dynamic>) return Uint8List.fromList(value.cast<int>());',
        );
        buffer.writeln(
          '    if (value is String) return Uint8List.fromList(base64Decode(value));',
        );
        buffer.writeln('    return null;');
        buffer.writeln('  }');
        buffer.writeln();
        buffer.writeln('  static Uint8List bytesOrEmpty(Object? value) {');
        buffer.writeln('    return bytesOrNull(value) ?? Uint8List(0);');
        buffer.writeln('  }');
        buffer.writeln();
        buffer.writeln(
          '  static String? bytesToJsonOrNull(Uint8List? value) {',
        );
        buffer.writeln(
          '    return value == null ? null : base64Encode(value.toList());',
        );
        buffer.writeln('  }');
      }
      buffer.writeln('}');
    }
    return buffer.toString();
  }

  String _renderRpcSupport() {
    final buffer = StringBuffer();
    buffer.writeln('enum ZenStackRpcMethod { get, post }');
    buffer.writeln();
    buffer.writeln('abstract interface class ZenStackRpcTransport {');
    buffer.writeln('  Future<Object?> send(');
    buffer.writeln('    ZenStackRpcMethod method,');
    buffer.writeln('    String path, {');
    buffer.writeln('    Map<String, String>? queryParameters,');
    buffer.writeln('    Object? body,');
    buffer.writeln('  });');
    buffer.writeln('}');
    return buffer.toString();
  }
}

/// Parsed representation of a `.zmodel` file.
class ParsedZModel {
  /// Creates a parsed schema with tables and enums.
  ParsedZModel({required this.tables, required this.enums});

  /// Parsed model definitions.
  final List<TableDefinition> tables;

  /// Parsed enum definitions.
  final List<EnumDefinition> enums;

  /// Whether generated output needs `dart:convert`.
  bool get requiresConvertImport => tables.any(
    (table) => table.allColumns.any((column) => column.dartType == 'Uint8List'),
  );

  /// Whether generated output needs `dart:typed_data`.
  bool get requiresTypedDataImport => requiresConvertImport;
}

/// String case conversion helpers used for generated identifiers.
enum StringCase {
  /// Converts identifiers to `camelCase`.
  camelCase,

  /// Converts identifiers to `PascalCase`.
  pascalCase;

  /// Converts [input] to the selected casing style.
  String convert(String input) {
    if (input.isEmpty) return '';

    final parts = _normalizeName(input);
    final buffer = StringBuffer();

    for (int i = 0; i < parts.length; i++) {
      final part = parts[i].toLowerCase();
      final isFirst = i == 0;

      switch (this) {
        case StringCase.camelCase:
          buffer.write(isFirst ? part : _capitalize(part));
          break;
        case StringCase.pascalCase:
          buffer.write(_capitalize(part));
          break;
      }
    }

    return buffer.toString();
  }
}

String _capitalize(String word) =>
    word.isEmpty ? '' : word[0].toUpperCase() + word.substring(1);

List<String> _normalizeName(String input) {
  final intermediate = input.replaceAllMapped(
    RegExp(r'([a-z0-9])([A-Z])'),
    (m) => '${m[1]}_${m[2]}',
  );
  return intermediate
      .split(RegExp(r'[_\s]+'))
      .where((part) => part.isNotEmpty)
      .toList();
}

/// Parsed enum declaration from a `.zmodel` file.
class EnumDefinition {
  /// Creates an enum definition.
  EnumDefinition({required this.name, required this.values});

  /// Original enum name from the schema.
  final String name;

  /// Enum values in declaration order.
  final List<String> values;

  /// Generated Dart enum class name.
  String get className => StringCase.pascalCase.convert(name);

  /// Default filename for the enum when emitted separately.
  String get fileName => '${name.toLowerCase()}.dart';

  /// Whether the enum has no values.
  bool get isEmpty => values.isEmpty;

  /// Adds a parsed enum value line.
  void addValue(String trimmedLine) {
    trimmedLine = trimmedLine.replaceAll(RegExp(r'//.*'), '').split(' ').first;
    trimmedLine = trimmedLine.trim();
    if (trimmedLine.isEmpty) return;
    values.add(trimmedLine);
  }
}

/// Parsed model declaration from a `.zmodel` file.
class TableDefinition {
  /// Creates a model definition.
  TableDefinition({
    required this.name,
    required this.isAbstract,
    required this.extendsTableName,
  });

  /// Original model name from the schema.
  final String name;

  /// Whether the model is declared as `abstract`.
  final bool isAbstract;

  /// Name of the inherited base model, if any.
  final String extendsTableName;

  /// Resolved parent table definition when `extends` is used.
  TableDefinition? extendsTable;

  /// Columns declared directly on the model.
  final List<ColumnDefinition> columns = [];

  /// Generated Dart class name.
  String get className => StringCase.pascalCase.convert(name);

  /// Default filename for the model when emitted separately.
  String get fileName => '${name.toLowerCase()}.dart';

  /// All columns including inherited and merged directive metadata.
  List<ColumnDefinition> get allColumns {
    final inherited = extendsTable?.allColumns ?? const <ColumnDefinition>[];
    final mergedByName = <String, ColumnDefinition>{};

    for (final column in inherited) {
      mergedByName[column.name] = column;
    }

    for (final column in columns) {
      final existing = mergedByName[column.name];
      mergedByName[column.name] = existing == null
          ? column
          : existing.merged(column);
    }

    final ret = mergedByName.values.toList();

    ret.sort((a, b) {
      if (a.isPrimaryKey != b.isPrimaryKey) {
        return a.isPrimaryKey ? -1 : 1;
      }
      if (a.isForeignKey != b.isForeignKey) {
        return a.isForeignKey ? -1 : 1;
      }
      return a.name.compareTo(b.name);
    });

    return ret;
  }

  /// Parses and merges a single model body line.
  void parseColumn(String trimmedLine) {
    final definitions = ColumnDefinition.parse(trimmedLine);
    for (final definition in definitions) {
      final index = columns.indexWhere(
        (element) => element.name == definition.name,
      );
      if (index == -1) {
        columns.add(definition);
      } else {
        columns[index] = columns[index].merged(definition);
      }
    }
  }

  /// Resolves the inherited table reference from the parsed schema map.
  void resolveExtends(Map<String, TableDefinition> tables) {
    if (extendsTableName.isEmpty) return;
    extendsTable = tables[extendsTableName];
  }

  /// Marks custom column types such as enums after the schema is fully parsed.
  void resolveCustomTypes(Set<String> enumNames) {
    for (var i = 0; i < columns.length; i++) {
      columns[i] = columns[i].resolvedCustomType(enumNames);
    }
  }
}

/// Parsed column definition or table directive fragment.
class ColumnDefinition {
  /// Creates a column definition.
  ColumnDefinition({
    required this.name,
    required this.isNullable,
    required this.isPrimaryKey,
    required this.isUnique,
    required this.isArray,
    required this.isForeignKey,
    required this.isEnum,
    required this.zmodelType,
    required this.dartType,
  }) : assert(name.isNotEmpty);

  /// Original column name from the schema.
  final String name;

  /// Original ZModel type name.
  final String zmodelType;

  /// Generated Dart type name.
  final String dartType;

  /// Whether the column is a list.
  final bool isArray;

  /// Whether the column references another model or enum-like object.
  final bool isForeignKey;

  /// Whether the column references a generated enum.
  final bool isEnum;

  /// Whether the column is nullable.
  final bool isNullable;

  /// Whether the column participates in the primary key.
  final bool isPrimaryKey;

  /// Whether the column is marked unique.
  final bool isUnique;

  /// Builds a column definition from a schema field declaration.
  factory ColumnDefinition.build(String name, String type, String decorators) {
    var isNullable = true;
    final isPrimaryKey = decorators.contains('@id');
    final isUnique = decorators.contains('@unique');
    var isArray = false;
    var isForeignKey = false;
    late final String zmodelType;
    late final String dartType;

    if (type.endsWith('?')) {
      type = type.substring(0, type.length - 1);
      isNullable = true;
    }

    if (type.endsWith('[]')) {
      type = type.substring(0, type.length - 2);
      isArray = true;
    }

    zmodelType = type;

    switch (zmodelType) {
      case 'String':
        dartType = 'String';
        break;
      case 'Int':
        dartType = 'int';
        break;
      case 'BigInt':
        dartType = 'BigInt';
        break;
      case 'Float':
        dartType = 'num';
        break;
      case 'Boolean':
        dartType = 'bool';
        break;
      case 'DateTime':
        dartType = 'DateTime';
        break;
      case 'Json':
        dartType = 'dynamic';
        break;
      case 'Bytes':
        dartType = 'Uint8List';
        break;
      default:
        isForeignKey = true;
        dartType = StringCase.pascalCase.convert(zmodelType);
        break;
    }

    if ({
      'String',
      'Int',
      'BigInt',
      'Float',
      'Boolean',
      'DateTime',
      'Json',
      'Bytes',
    }.contains(zmodelType)) {
      isForeignKey = false;
    }

    return ColumnDefinition(
      name: name,
      isNullable: isNullable,
      isPrimaryKey: isPrimaryKey,
      isUnique: isUnique,
      isArray: isArray,
      isForeignKey: isForeignKey,
      isEnum: false,
      zmodelType: zmodelType,
      dartType: dartType,
    );
  }

  /// Merges metadata from another column definition with the same name.
  ColumnDefinition merged(ColumnDefinition other) {
    return ColumnDefinition(
      name: name,
      dartType: dartType.isEmpty ? other.dartType : dartType,
      isArray: isArray || other.isArray,
      isForeignKey: isForeignKey || other.isForeignKey,
      isEnum: isEnum || other.isEnum,
      zmodelType: zmodelType.isEmpty ? other.zmodelType : zmodelType,
      isNullable: isNullable || other.isNullable,
      isPrimaryKey: isPrimaryKey || other.isPrimaryKey,
      isUnique: isUnique || other.isUnique,
    );
  }

  /// Resolves custom parsed types once all enums are known.
  ColumnDefinition resolvedCustomType(Set<String> enumNames) {
    if (!enumNames.contains(zmodelType)) return this;
    return ColumnDefinition(
      name: name,
      isNullable: isNullable,
      isPrimaryKey: isPrimaryKey,
      isUnique: isUnique,
      isArray: isArray,
      isForeignKey: isForeignKey,
      isEnum: true,
      zmodelType: zmodelType,
      dartType: dartType,
    );
  }

  /// Parses a single schema line into zero or more column definitions.
  static List<ColumnDefinition> parse(String line) {
    if (line.startsWith('@@id')) {
      return _parseTableDirective(line, isPrimaryKey: true);
    }

    if (line.startsWith('@@unique')) {
      return _parseTableDirective(line, isUnique: true);
    }

    if (line.startsWith('@@')) {
      return const [];
    }

    final simplified = line.replaceAll(RegExp(r'\s+'), ' ').trim();
    final parts = simplified.split(' ');
    if (parts.length < 2) return const [];

    final name = parts[0];
    final type = parts[1];
    final decorators = parts.sublist(2).join(' ');
    return [ColumnDefinition.build(name, type, decorators)];
  }

  static List<ColumnDefinition> _parseTableDirective(
    String line, {
    bool isPrimaryKey = false,
    bool isUnique = false,
  }) {
    final parts = line.split('(');
    if (parts.length < 2) return const [];

    final ids = parts[1]
        .substring(0, parts[1].length - 1)
        .replaceAll('[', '')
        .replaceAll(']', '')
        .split(',');

    return ids
        .map(
          (id) => ColumnDefinition(
            name: id.trim(),
            zmodelType: '',
            dartType: '',
            isArray: false,
            isForeignKey: false,
            isEnum: false,
            isNullable: false,
            isPrimaryKey: isPrimaryKey,
            isUnique: isUnique,
          ),
        )
        .toList();
  }

  /// Generated Dart field name.
  String get attributeName => StringCase.camelCase.convert(name);

  /// Generated Dart type declaration, including list wrappers when needed.
  String get typeDefinition => isArray ? 'List<$dartType>' : dartType;

  /// Generated Dart field declaration.
  String get attributeDefinition {
    if ((isNullable || isForeignKey) && typeDefinition != 'dynamic') {
      return 'final $typeDefinition? $attributeName;';
    }
    return 'final $typeDefinition $attributeName;';
  }

  /// Generated constructor parameter snippet.
  String get attributeConstructor {
    if (isNullable || isForeignKey) {
      return 'this.$attributeName,';
    }
    return 'required this.$attributeName,';
  }

  /// Generated `fromJson` expression for the field.
  String get castFromJson {
    if (dartType == 'String') {
      if (isNullable) {
        return "$attributeName: ZModel.stringOrNull(json['$name'])";
      }
      return "$attributeName: ZModel.stringOrEmpty(json['$name'])";
    } else if (dartType == 'int') {
      if (isNullable) {
        return "$attributeName: ZModel.intOrNull(json['$name'])";
      }
      return "$attributeName: ZModel.intOrZero(json['$name'])";
    } else if (dartType == 'num') {
      if (isNullable) {
        return "$attributeName: ZModel.numOrNull(json['$name'])";
      }
      return "$attributeName: ZModel.numOrZero(json['$name'])";
    } else if (dartType == 'bool') {
      if (isNullable) {
        return "$attributeName: ZModel.boolOrNull(json['$name'])";
      }
      return "$attributeName: ZModel.boolOrFalse(json['$name'])";
    } else if (dartType == 'BigInt') {
      if (isNullable) {
        return "$attributeName: ZModel.bigIntOrNull(json['$name'])";
      }
      return "$attributeName: ZModel.bigIntOrZero(json['$name'])";
    } else if (dartType == 'DateTime') {
      if (isNullable) {
        return "$attributeName: ZModel.dateTimeOrNull(json['$name'])";
      }
      return "$attributeName: ZModel.dateTimeOrZero(json['$name'])";
    } else if (dartType == 'Uint8List') {
      if (isNullable) {
        return "$attributeName: ZModel.bytesOrNull(json['$name'])";
      }
      return "$attributeName: ZModel.bytesOrEmpty(json['$name'])";
    } else if (isArray) {
      if (isEnum) {
        return "$attributeName: ZModel.enumListOrNull<$dartType>($dartType.values, json['$name'])";
      }
      if (isForeignKey) {
        return "$attributeName: ZModel.listOrNull<$dartType>(json['$name'])";
      }
      if (isNullable) {
        return "$attributeName: (json['$name'] as List<dynamic>?)?.cast<$dartType>()";
      }
      return "$attributeName: (json['$name'] as List<dynamic>).cast<$dartType>()";
    } else if (isEnum) {
      return "$attributeName: ZModel.enumOrNull<$dartType>($dartType.values, json['$name'])";
    } else if (isForeignKey) {
      return "$attributeName: ZModel.modelOrNull<$dartType>(json['$name'])";
    }
    return "$attributeName: json['$name']";
  }

  /// Generated `toJson` expression for the field.
  String get castToJson {
    if (dartType == 'String') {
      return "'$name': ZModel.stringToJsonOrNull($attributeName)";
    }
    if (dartType == 'int') {
      return "'$name': ZModel.intToJsonOrNull($attributeName)";
    }
    if (dartType == 'num') {
      return "'$name': ZModel.numToJsonOrNull($attributeName)";
    }
    if (dartType == 'bool') {
      return "'$name': ZModel.boolToJsonOrNull($attributeName)";
    }
    if (dartType == 'BigInt') {
      return "'$name': ZModel.bigIntToJsonOrNull($attributeName)";
    }
    if (dartType == 'DateTime') {
      return "'$name': ZModel.dateTimeToJsonOrNull($attributeName)";
    }
    if (dartType == 'Uint8List') {
      return "'$name': ZModel.bytesToJsonOrNull($attributeName)";
    }
    if (isArray) {
      if (isEnum) {
        return "'$name': ZModel.enumListToJsonOrNull<$dartType>($attributeName)";
      }
      if (isForeignKey) {
        return "'$name': ZModel.listToJsonOrNull<$dartType>($attributeName)";
      }
      return "'$name': $attributeName";
    }
    if (isEnum) {
      return "'$name': ZModel.enumToJsonOrNull<$dartType>($attributeName)";
    }
    if (isForeignKey) {
      return "'$name': ZModel.modelToJsonOrNull($attributeName)";
    }
    return "'$name': $attributeName";
  }
}
