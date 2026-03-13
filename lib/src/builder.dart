import 'package:build/build.dart';

import 'config.dart';
import 'generator.dart';

Builder zmodelToDartBuilder(BuilderOptions options) {
  final configPath =
      options.config['config_path'] as String? ?? 'zmodel_to_dart.yaml';
  final config = ZModelToDartConfig.load(configPath: configPath);
  return _ZModelToDartBuilder(config);
}

class _ZModelToDartBuilder implements Builder {
  _ZModelToDartBuilder(this._config)
    : _generator = ZModelGenerator(banner: _config.banner);

  final ZModelToDartConfig _config;
  final ZModelGenerator _generator;

  @override
  Map<String, List<String>> get buildExtensions => {
    '.zmodel': [_config.outputSuffix],
  };

  @override
  Future<void> build(BuildStep buildStep) async {
    final inputId = buildStep.inputId;
    if (!_config.matchesAssetPath(inputId.path)) {
      return;
    }

    final source = await buildStep.readAsString(inputId);
    final parsed = _generator.parse(source);
    final output = _generator.renderSingleLibrary(parsed);
    final outputId = inputId.changeExtension(_config.outputSuffix);
    await buildStep.writeAsString(outputId, output);
  }
}
