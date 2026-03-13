import 'dart:io';

class ZModelGenerator {
  ZModelGenerator({this.banner = '// AUTO GENERATED FILE, DO NOT EDIT'});

  final String banner;

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

    return ParsedZModel(tables: tables.values.toList(), enums: enums);
  }

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

  String renderSingleLibrary(ParsedZModel parsed) {
    final buffer = StringBuffer()
      ..writeln(banner)
      ..writeln();

    if (parsed.requiresConvertImport) {
      buffer.writeln("import 'dart:convert';");
    }
    if (parsed.requiresTypedDataImport) {
      buffer.writeln("import 'dart:typed_data';");
    }
    if (parsed.requiresConvertImport || parsed.requiresTypedDataImport) {
      buffer.writeln();
    }

    var first = true;
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

    return buffer.toString();
  }

  String renderEnum(EnumDefinition definition) {
    final buffer = StringBuffer()
      ..writeln(banner)
      ..writeln()
      ..write(_renderEnumBody(definition));
    return buffer.toString();
  }

  String renderTable(TableDefinition definition) {
    final buffer = StringBuffer()
      ..writeln(banner)
      ..writeln();

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
    buffer.writeln('enum ${definition.className} {');

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
    buffer.writeln('  static ${definition.className} fromJson(String json) {');
    buffer.writeln(
      '    return ${definition.className}.values.firstWhere((e) => e.value == json,',
    );
    buffer.writeln(
      "      orElse: () => throw Exception('Unknown ${definition.className} value: \$json'));",
    );
    buffer.writeln('  }');
    buffer.writeln();
    buffer.writeln('  String toJson() => value;');
    buffer.writeln('}');
    return buffer.toString();
  }

  String _renderTableBody(TableDefinition definition) {
    final buffer = StringBuffer();
    buffer.writeln('class ${definition.className} {');

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
}

class ParsedZModel {
  ParsedZModel({required this.tables, required this.enums});

  final List<TableDefinition> tables;
  final List<EnumDefinition> enums;

  bool get requiresConvertImport => tables.any(
    (table) => table.allColumns.any((column) => column.dartType == 'Uint8List'),
  );

  bool get requiresTypedDataImport => requiresConvertImport;
}

enum StringCase {
  camelCase,
  pascalCase;

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

class EnumDefinition {
  EnumDefinition({required this.name, required this.values});

  final String name;
  final List<String> values;

  String get className => StringCase.pascalCase.convert(name);

  String get fileName => '${name.toLowerCase()}.dart';

  bool get isEmpty => values.isEmpty;

  void addValue(String trimmedLine) {
    trimmedLine = trimmedLine.replaceAll(RegExp(r'//.*'), '').split(' ').first;
    trimmedLine = trimmedLine.trim();
    if (trimmedLine.isEmpty) return;
    values.add(trimmedLine);
  }
}

class TableDefinition {
  TableDefinition({
    required this.name,
    required this.isAbstract,
    required this.extendsTableName,
  });

  final String name;
  final bool isAbstract;
  final String extendsTableName;
  TableDefinition? extendsTable;
  final List<ColumnDefinition> columns = [];

  String get className => StringCase.pascalCase.convert(name);

  String get fileName => '${name.toLowerCase()}.dart';

  List<ColumnDefinition> get allColumns {
    final inherited = extendsTable?.allColumns ?? const <ColumnDefinition>[];
    final mergedByName = <String, ColumnDefinition>{};

    for (final column in inherited) {
      mergedByName[column.name] = column;
    }

    for (final column in columns) {
      final existing = mergedByName[column.name];
      mergedByName[column.name] =
          existing == null ? column : existing.merged(column);
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

  void resolveExtends(Map<String, TableDefinition> tables) {
    if (extendsTableName.isEmpty) return;
    extendsTable = tables[extendsTableName];
  }
}

class ColumnDefinition {
  ColumnDefinition({
    required this.name,
    required this.isNullable,
    required this.isPrimaryKey,
    required this.isUnique,
    required this.isArray,
    required this.isForeignKey,
    required this.zmodelType,
    required this.dartType,
  }) : assert(name.isNotEmpty);

  final String name;
  final String zmodelType;
  final String dartType;
  final bool isArray;
  final bool isForeignKey;
  final bool isNullable;
  final bool isPrimaryKey;
  final bool isUnique;

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
        dartType = 'int';
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
      zmodelType: zmodelType,
      dartType: dartType,
    );
  }

  ColumnDefinition merged(ColumnDefinition other) {
    return ColumnDefinition(
      name: name,
      dartType: dartType.isEmpty ? other.dartType : dartType,
      isArray: isArray || other.isArray,
      isForeignKey: isForeignKey || other.isForeignKey,
      zmodelType: zmodelType.isEmpty ? other.zmodelType : zmodelType,
      isNullable: isNullable || other.isNullable,
      isPrimaryKey: isPrimaryKey || other.isPrimaryKey,
      isUnique: isUnique || other.isUnique,
    );
  }

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
            isNullable: false,
            isPrimaryKey: isPrimaryKey,
            isUnique: isUnique,
          ),
        )
        .toList();
  }

  String get attributeName => StringCase.camelCase.convert(name);

  String get typeDefinition => isArray ? 'List<$dartType>' : dartType;

  String get attributeDefinition {
    if ((isNullable || isForeignKey) && typeDefinition != 'dynamic') {
      return 'final $typeDefinition? $attributeName;';
    }
    return 'final $typeDefinition $attributeName;';
  }

  String get attributeConstructor {
    if (isNullable || isForeignKey) {
      return 'this.$attributeName,';
    }
    return 'required this.$attributeName,';
  }

  String get castFromJson {
    var cast = '';

    if (dartType == 'int') {
      if (zmodelType == 'BigInt') {
        if (isNullable) {
          return "$attributeName: json['$name'] != null ? int.tryParse(json['$name'].toString()) : null";
        }
        return "$attributeName: int.tryParse(json['$name'].toString()) ?? 0";
      }
      cast = ' as int';
    } else if (dartType == 'num') {
      cast = ' as num';
    } else if (dartType == 'bool') {
      cast = ' as bool';
    } else if (dartType == 'String') {
      cast = ' as String';
    } else if (dartType == 'DateTime') {
      if (isNullable) {
        return "$attributeName: DateTime.tryParse(json['$name'])";
      }
      return "$attributeName: DateTime.tryParse(json['$name']) ?? DateTime(0)";
    } else if (dartType == 'Uint8List') {
      if (isNullable) {
        return "$attributeName: json['$name'] != null ? base64Decode(json['$name']) : null";
      }
      return "$attributeName: base64Decode(json['$name'])";
    } else if (isArray) {
      if (isForeignKey) {
        return "$attributeName: (json['$name'] as List<dynamic>${isNullable ? '?' : ''})${isNullable ? '?' : ''}.map<$dartType>((e) => $dartType.fromJson(e as Map<String, dynamic>)).toList()";
      }
      if (isNullable) {
        return "$attributeName: (json['$name'] as List<dynamic>?)?.cast<$dartType>()";
      }
      return "$attributeName: (json['$name'] as List<dynamic>).cast<$dartType>()";
    } else if (isForeignKey) {
      return "$attributeName: json['$name'] != null ? $dartType.fromJson(json['$name']) : null";
    }

    if (isNullable && cast.isNotEmpty) {
      return "$attributeName: json['$name'] != null ? json['$name']$cast : null";
    }

    return "$attributeName: json['$name']$cast";
  }

  String get castToJson {
    var cast = '';

    if (dartType == 'DateTime') {
      cast = '.toIso8601String()';
    } else if (dartType == 'Uint8List') {
      if (isNullable) {
        return "'$name': $attributeName != null ? base64Encode($attributeName!.toList()) : null";
      }
      return "'$name': base64Encode($attributeName.toList())";
    } else if (isArray && isForeignKey) {
      if (isNullable || isForeignKey) {
        return "'$name': $attributeName?.map((e) => e.toJson()).toList()";
      }
      return "'$name': $attributeName.map((e) => e.toJson()).toList()";
    } else if (isForeignKey) {
      if (isNullable || isForeignKey) {
        return "'$name': $attributeName?.toJson()";
      }
      return "'$name': $attributeName.toJson()";
    }

    if (isNullable && cast.isNotEmpty) {
      return "'$name': $attributeName?$cast";
    }

    return "'$name': $attributeName$cast";
  }
}
