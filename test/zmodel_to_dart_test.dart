import 'dart:io';

import 'package:path/path.dart' as path;
import 'package:test/test.dart';
import 'package:zmodel_to_dart/zmodel_to_dart.dart';

void main() {
  test('generates enum and model output from zmodel source', () {
    const source = '''
enum role {
  admin
  reader
}

model post {
  id String @id
  title String
}

model user {
  id String @id
  name String
  age Int
  active Boolean
  score Float
  role role
  roles role[]
  bestPost post
  posts post[]
  createdAt DateTime
}
''';

    final generator = ZModelGenerator();
    final parsed = generator.parse(source);
    final output = generator.renderSingleLibrary(parsed);

    expect(output, contains('// dart format off'));
    expect(output, contains('abstract class ZModel {'));
    expect(output, contains("case const (User): return 'user';"));
    expect(
      output,
      contains('case const (User): return User.fromJson(json) as T;'),
    );
    expect(output, contains('abstract interface class ZModelEnum {'));
    expect(output, contains('enum Role implements ZModelEnum {'));
    expect(output, contains("admin('admin')"));
    expect(output, contains('static T? fromJson<T extends Enum>('));
    expect(output, contains('static Role? fromJson(String? json) {'));
    expect(
      output,
      contains('return ZModelEnum.fromJson<Role>(Role.values, json);'),
    );
    expect(output, contains('class User extends ZModel {'));
    expect(output, contains('final String? id;'));
    expect(output, contains('final int? age;'));
    expect(output, contains('final bool? active;'));
    expect(output, contains('final num? score;'));
    expect(output, contains('final Role? role;'));
    expect(output, contains('final List<Role>? roles;'));
    expect(output, contains('final Post? bestPost;'));
    expect(output, contains('final List<Post>? posts;'));
    expect(output, contains('final DateTime? createdAt;'));
    expect(
      output,
      contains('factory User.fromJson(Map<String, dynamic> json)'),
    );
    expect(output, contains('static String? stringOrNull(Object? value) {'));
    expect(
      output,
      contains('static String? stringToJsonOrNull(String? value) {'),
    );
    expect(output, contains('static String stringOrEmpty(Object? value) {'));
    expect(
      output,
      contains('static T? modelOrNull<T extends ZModel>(Object? value) {'),
    );
    expect(
      output,
      contains('static List<T>? listOrNull<T extends ZModel>(Object? value) {'),
    );
    expect(output, contains('static T? enumOrNull<T extends Enum>('));
    expect(output, contains('static List<T>? enumListOrNull<T extends Enum>('));
    expect(output, contains('static int? intOrNull(Object? value) {'));
    expect(output, contains('static int? intToJsonOrNull(int? value) {'));
    expect(output, contains('static int intOrZero(Object? value) {'));
    expect(output, contains('static num? numOrNull(Object? value) {'));
    expect(output, contains('static num? numToJsonOrNull(num? value) {'));
    expect(output, contains('static num numOrZero(Object? value) {'));
    expect(output, contains('static bool? boolOrNull(Object? value) {'));
    expect(output, contains('static bool? boolToJsonOrNull(bool? value) {'));
    expect(output, contains('static bool boolOrFalse(Object? value) {'));
    expect(
      output,
      contains('static DateTime? dateTimeOrNull(Object? value) {'),
    );
    expect(output, contains('static DateTime dateTimeOrZero(Object? value) {'));
    expect(
      output,
      contains('static String? dateTimeToJsonOrNull(DateTime? value) {'),
    );
    expect(output, contains('static BigInt? bigIntOrNull(Object? value) {'));
    expect(output, contains('static BigInt bigIntOrZero(Object? value) {'));
    expect(
      output,
      contains('static String? bigIntToJsonOrNull(BigInt? value) {'),
    );
    expect(
      output,
      contains(
        'static Map<String, dynamic>? modelToJsonOrNull(ZModel? value) {',
      ),
    );
    expect(
      output,
      contains(
        'static List<Map<String, dynamic>>? listToJsonOrNull<T extends ZModel>(List<T>? value) {',
      ),
    );
    expect(
      output,
      contains('static String? enumToJsonOrNull<T extends Enum>(T? value) {'),
    );
    expect(
      output,
      contains(
        'static List<String?>? enumListToJsonOrNull<T extends Enum>(List<T>? value) {',
      ),
    );
    expect(output, contains("id: ZModel.stringOrNull(json['id'])"));
    expect(output, contains("name: ZModel.stringOrNull(json['name'])"));
    expect(output, contains("age: ZModel.intOrNull(json['age'])"));
    expect(output, contains("active: ZModel.boolOrNull(json['active'])"));
    expect(output, contains("score: ZModel.numOrNull(json['score'])"));
    expect(
      output,
      contains("role: ZModel.enumOrNull<Role>(Role.values, json['role'])"),
    );
    expect(
      output,
      contains(
        "roles: ZModel.enumListOrNull<Role>(Role.values, json['roles'])",
      ),
    );
    expect(
      output,
      contains("bestPost: ZModel.modelOrNull<Post>(json['bestPost'])"),
    );
    expect(output, contains("posts: ZModel.listOrNull<Post>(json['posts'])"));
    expect(
      output,
      contains("createdAt: ZModel.dateTimeOrNull(json['createdAt'])"),
    );
    expect(output, contains("'name': ZModel.stringToJsonOrNull(name)"));
    expect(output, contains("'age': ZModel.intToJsonOrNull(age)"));
    expect(output, contains("'active': ZModel.boolToJsonOrNull(active)"));
    expect(output, contains("'score': ZModel.numToJsonOrNull(score)"));
    expect(output, contains("'role': ZModel.enumToJsonOrNull<Role>(role)"));
    expect(
      output,
      contains("'roles': ZModel.enumListToJsonOrNull<Role>(roles)"),
    );
    expect(output, contains("'bestPost': ZModel.modelToJsonOrNull(bestPost)"));
    expect(output, contains("'posts': ZModel.listToJsonOrNull<Post>(posts)"));
    expect(
      output,
      contains("'createdAt': ZModel.dateTimeToJsonOrNull(createdAt)"),
    );
  });

  test('renders standalone enums with local ZModelEnum base', () {
    const source = '''
enum role {
  admin
  reader
}
''';

    final generator = ZModelGenerator();
    final parsed = generator.parse(source);
    final output = generator.renderEnum(parsed.enums.single);

    expect(output, contains('// dart format off'));
    expect(
      output,
      isNot(contains("import 'package:zmodel_to_dart/zmodel_to_dart.dart';")),
    );
    expect(output, contains('abstract interface class ZModelEnum {'));
    expect(output, contains('enum Role implements ZModelEnum {'));
    expect(output, contains('static Role? fromJson(String? json) {'));
  });

  test(
    'uses helpers for primitive and materialized scalar values in fromJson',
    () {
      const source = '''
model user {
  id BigInt @id
  name String
  count Int
  enabled Boolean
  score Float
  createdAt DateTime
}
''';

      final generator = ZModelGenerator();
      final parsed = generator.parse(source);
      final output = generator.renderSingleLibrary(parsed);

      expect(output, contains('final BigInt? id;'));
      expect(output, contains("id: ZModel.bigIntOrNull(json['id'])"));
      expect(output, contains("'id': ZModel.bigIntToJsonOrNull(id)"));
      expect(output, contains("name: ZModel.stringOrNull(json['name'])"));
      expect(output, contains("count: ZModel.intOrNull(json['count'])"));
      expect(output, contains("enabled: ZModel.boolOrNull(json['enabled'])"));
      expect(output, contains("score: ZModel.numOrNull(json['score'])"));
      expect(
        output,
        contains("createdAt: ZModel.dateTimeOrNull(json['createdAt'])"),
      );
    },
  );

  test('loads project config from zmodel_to_dart.yaml', () {
    final tempDir = Directory.systemTemp.createTempSync('zmodel_to_dart_test_');
    addTearDown(() => tempDir.deleteSync(recursive: true));

    final configFile = File(path.join(tempDir.path, 'zmodel_to_dart.yaml'));
    configFile.writeAsStringSync('''
input_globs:
  - schema/*.zmodel
output_suffix: .models.dart
output_dir: generated/dtos
banner: // GENERATED BY TEST
''');

    final config = ZModelToDartConfig.load(workingDirectory: tempDir.path);

    expect(config.inputGlobs, ['schema/*.zmodel']);
    expect(config.outputSuffix, '.models.dart');
    expect(config.outputDir, 'generated/dtos');
    expect(config.banner, '// GENERATED BY TEST');
    expect(config.matchesAssetPath('schema/app.zmodel'), isTrue);
    expect(config.matchesAssetPath('lib/app.zmodel'), isFalse);
  });

  test('merges inherited columns referenced by table directives', () {
    const source = '''
abstract model base_model {
  UUID String
}

model tb_parameter extends base_model {
  PARAMETER_ID Int @id
  @@unique([UUID, PARAMETER_ID])
}
''';

    final generator = ZModelGenerator();
    final parsed = generator.parse(source);
    final output = generator.renderSingleLibrary(parsed);

    expect(RegExp(r'final String\? uuid;').allMatches(output).length, 1);
    expect(RegExp(r'required this\.uuid').allMatches(output), isEmpty);
    expect(
      output.split("uuid: ZModel.stringOrNull(json['UUID'])").length - 1,
      1,
    );
    expect(
      output.split("'UUID': ZModel.stringToJsonOrNull(uuid)").length - 1,
      1,
    );
  });

  test('loads rpc config from zmodel_to_dart.yaml', () {
    final tempDir = Directory.systemTemp.createTempSync('zmodel_to_dart_test_');
    addTearDown(() => tempDir.deleteSync(recursive: true));

    final configFile = File(path.join(tempDir.path, 'zmodel_to_dart.yaml'));
    configFile.writeAsStringSync('''
generate_rpc_clients: true
rpc_base_path: /api/rpc/model
''');

    final config = ZModelToDartConfig.load(workingDirectory: tempDir.path);

    expect(config.generateRpcClients, isTrue);
    expect(config.rpcBasePath, '/api/rpc/model');
  });

  test('generates a generic rpc client with direct method parameters', () {
    const source = '''
model user {
  id String @id
  name String
}
''';

    final generator = ZModelGenerator();
    final parsed = generator.parse(source);
    final output = generator.renderSingleLibrary(
      parsed,
      includeRpcClients: true,
      rpcBasePath: '/api/rpc/model',
    );

    expect(
      output,
      contains('enum ZenStackRpcMethod { get, post, patch, delete }'),
    );
    expect(output, contains('abstract interface class ZenStackRpcTransport {'));
    expect(output, contains('class ZModelRpcClient {'));
    expect(
      output,
      contains(
        'Future<List<T>> findMany<T extends ZModel>({Map<String, dynamic>? where, Map<String, dynamic>? select, Map<String, dynamic>? include, List<Map<String, String>>? orderBy, int? take, int? skip, Map<String, dynamic>? meta}) async {',
      ),
    );
    expect(
      output,
      contains(
        r"String _path<T extends ZModel>(String operation) => '$basePath/${ZModel.modelNameOf<T>()}/$operation';",
      ),
    );
    expect(output, contains('Map<String, String>? _queryParameters({'));
    expect(output, contains("_path<T>('findMany')"));
    expect(output, contains('return ZModel.listFromJson<T>(items);'));
    expect(
      output,
      contains('return ZModel.fromJson<T>(response as Map<String, dynamic>);'),
    );
    expect(output, contains('Future<Object?> _send('));
    expect(output, contains('return _decodeResponse(response);'));
    expect(
      output,
      contains('bool _looksLikeSerializedEnvelope(Object? value) {'),
    );
    expect(output, contains('Object? _deserializeSerializedResponse('));
    expect(output, contains("final data = value['data'] ?? value['json'];"));
    expect(
      output,
      contains("if (data is List || data is Map<Object?, Object?>) return true;"),
    );
    expect(output, contains("final serialization = meta['serialization'];"));
    expect(
      output,
      contains(
        "final data = _normalizeJsonValue(response.containsKey('data') ? response['data'] : response['json']);",
      ),
    );
    expect(output, contains("case 'date':"));
    expect(output, contains("case 'bigint':"));
    expect(
      output,
      contains("final params = <String, String>{'q': jsonEncode(payload)};"),
    );
    expect(
      output,
      contains(
        "final response = await _send(ZenStackRpcMethod.get, _path<T>('findMany')",
      ),
    );
    expect(
      output,
      contains(
        "final response = await _send(ZenStackRpcMethod.patch, _path<T>('update')",
      ),
    );
    expect(
      output,
      contains(
        "final response = await _send(ZenStackRpcMethod.delete, _path<T>('delete')",
      ),
    );
    expect(
      output,
      contains(
        "final response = await _send(ZenStackRpcMethod.post, _path<T>('createManyAndReturn')",
      ),
    );
    expect(
      output,
      contains(
        "final response = await _send(ZenStackRpcMethod.patch, _path<T>('updateManyAndReturn')",
      ),
    );
    expect(output, contains("_path<T>('aggregate')"));
    expect(output, contains("_path<T>('groupBy')"));
    expect(output, contains("'data': data.toJson()"));
    expect(output, contains("'where': where"));
  });
}
