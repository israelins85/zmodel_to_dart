# zmodel_to_dart

A Dart builder that generates DTO classes from `.zmodel` files.

## Features

- Parses `model`, `abstract model`, and `enum` declarations
- Generates DTO classes with `fromJson` and `toJson`
- Supports inherited fields from `extends`
- Handles scalar values, enums, bytes, arrays, and nested model references

## Usage

1. Add to your `pubspec.yaml`:

```yaml
dev_dependencies:
    zmodel_to_dart: ^0.1.0
    build_runner: ^2.7.0
```

2. Create a `.zmodel` file:

```txt
enum role {
    admin
    reader
}

model user {
    id String @id
    name String
    role role
}
```

3. Optionally create `zmodel_to_dart.yaml` in the package root:

```yaml
input_globs:
  - schema/*.zmodel
output_suffix: .zmodel.dart
output_dir: lib/data/dtos
banner: // AUTO GENERATED FILE, DO NOT EDIT
```

4. Run:

```bash
dart run build_runner build
```

This generates a sibling file like `user.zmodel.dart`.

The builder reads `zmodel_to_dart.yaml` automatically. `build_runner` still needs a minimal `build.yaml` entry to enable the builder, but input filtering and output naming can live in `zmodel_to_dart.yaml`.

## Suggestions

- Keep your `.zmodel` files close to the modules that consume the generated DTOs.
- Use the builder when you want generated files to stay synchronized automatically.

## To run standalone

```bash
Usage: dart run zmodel_to_dart <path_to_zmodel_file> [output_dir]
```

If you omit the CLI arguments, `zmodel_to_dart` will try to resolve a single source file from `input_globs` in `zmodel_to_dart.yaml` and will use `output_dir` from that file.

## License

MIT
