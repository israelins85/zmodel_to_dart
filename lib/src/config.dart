import 'dart:io';

import 'package:glob/glob.dart';
import 'package:path/path.dart' as path;
import 'package:yaml/yaml.dart';

class ZModelToDartConfig {
  ZModelToDartConfig({
    this.configPath = 'zmodel_to_dart.yaml',
    List<String>? inputGlobs,
    this.outputSuffix = '.zmodel.dart',
    this.outputDir = 'lib/data/dtos',
    this.banner = '// AUTO GENERATED FILE, DO NOT EDIT',
  }) : inputGlobs = List.unmodifiable(inputGlobs ?? const ['schema/*.zmodel']) {
    if (!outputSuffix.startsWith('.')) {
      throw ArgumentError.value(
        outputSuffix,
        'outputSuffix',
        'Must start with a dot.',
      );
    }
  }

  final String configPath;
  final List<String> inputGlobs;
  final String outputSuffix;
  final String outputDir;
  final String banner;

  List<Glob> get _compiledGlobs => inputGlobs.map(Glob.new).toList();

  static ZModelToDartConfig load({
    String configPath = 'zmodel_to_dart.yaml',
    String? workingDirectory,
  }) {
    final root = workingDirectory ?? Directory.current.path;
    final file = File(path.join(root, configPath));
    if (!file.existsSync()) {
      return ZModelToDartConfig(configPath: configPath);
    }

    final document = loadYaml(file.readAsStringSync());
    if (document != null && document is! YamlMap) {
      throw FormatException('$configPath must contain a YAML map at the root.');
    }

    final map = document as YamlMap?;
    return ZModelToDartConfig(
      configPath: configPath,
      inputGlobs: _readStringList(map, 'input_globs') ?? const ['schema/*.zmodel'],
      outputSuffix: _readString(map, 'output_suffix') ?? '.zmodel.dart',
      outputDir: _readString(map, 'output_dir') ?? 'lib/data/dtos',
      banner: _readString(map, 'banner') ?? '// AUTO GENERATED FILE, DO NOT EDIT',
    );
  }

  bool matchesAssetPath(String assetPath) {
    final normalized = path.posix.normalize(assetPath);
    for (final glob in _compiledGlobs) {
      if (glob.matches(normalized)) {
        return true;
      }
    }
    return false;
  }

  File? resolveSourceFile({String? workingDirectory}) {
    final root = workingDirectory ?? Directory.current.path;
    final matches = <String>[];
    final rootDirectory = Directory(root);
    if (!rootDirectory.existsSync()) {
      return null;
    }

    for (final entity in rootDirectory.listSync(recursive: true)) {
      if (entity is! File) continue;
      final relativePath = path.relative(entity.path, from: root);
      final normalized = path.posix.normalize(relativePath);

      for (final glob in _compiledGlobs) {
        if (glob.matches(normalized)) {
          matches.add(entity.path);
          break;
        }
      }
    }

    final uniqueMatches = matches.toSet().toList()..sort();
    if (uniqueMatches.isEmpty) {
      return null;
    }
    if (uniqueMatches.length > 1) {
      throw ArgumentError(
        'Multiple source files match zmodel_to_dart.yaml: ${uniqueMatches.join(', ')}',
      );
    }
    return File(uniqueMatches.single);
  }

  static String? _readString(YamlMap? map, String key) {
    final value = map?[key];
    if (value == null) return null;
    if (value is! String) {
      throw FormatException('"$key" in zmodel_to_dart.yaml must be a string.');
    }
    return value;
  }

  static List<String>? _readStringList(YamlMap? map, String key) {
    final value = map?[key];
    if (value == null) return null;
    if (value is! YamlList) {
      throw FormatException('"$key" in zmodel_to_dart.yaml must be a list.');
    }

    return value.map((item) {
      if (item is! String) {
        throw FormatException(
          'All entries in "$key" in zmodel_to_dart.yaml must be strings.',
        );
      }
      return item;
    }).toList(growable: false);
  }
}
