import 'dart:io';

import 'package:path/path.dart' as path;

import 'package:zmodel_to_dart/src/config.dart';
import 'package:zmodel_to_dart/src/generator.dart';

void runZModelStandalone(List<String> arguments) {
  final config = ZModelToDartConfig.load();

  File? sourceFile;
  if (arguments.isNotEmpty) {
    sourceFile = File(arguments[0]);
  } else {
    sourceFile = config.resolveSourceFile();
  }

  if (sourceFile == null) {
    stdout.writeln(
      'Usage: dart run zmodel_to_dart <path_to_zmodel_file> [output_dir]',
    );
    stdout.writeln(
      'Or configure input_globs in zmodel_to_dart.yaml so the source file can be resolved automatically.',
    );
    exitCode = 64;
    return;
  }

  final outputDir = Directory(
    arguments.length > 1 ? arguments[1] : path.normalize(config.outputDir),
  );

  try {
    ZModelGenerator(
      banner: config.banner,
    ).generateDirectory(sourceFile: sourceFile, outputDir: outputDir);
    stdout.writeln('Generated DTOs into ${outputDir.path}');
  } on ArgumentError catch (error) {
    stderr.writeln(error.message);
    exitCode = 64;
  } on FormatException catch (error) {
    stderr.writeln(error.message);
    exitCode = 64;
  }
}
