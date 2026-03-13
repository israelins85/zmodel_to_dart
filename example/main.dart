import 'package:zmodel_to_dart/zmodel_to_dart.dart';

void main() {
  const source = '''
enum role {
  admin
  reader
}

model user {
  id String @id
  name String
  role role
}
''';

  final parsed = ZModelGenerator().parse(source);
  final generated = ZModelGenerator().renderSingleLibrary(parsed);
  print(generated);
}
