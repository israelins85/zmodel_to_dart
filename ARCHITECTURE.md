# ARCHITECTURE

## Overview

`zmodel_to_dart` is a Dart package focused on turning `.zmodel` files into generated Dart code. The project has two main execution modes:

- `build_runner` integration, generating one Dart library per `.zmodel` file
- Standalone CLI execution, generating a directory with separate files for enums and concrete models

The core is intentionally simple: a text parser walks the schema line by line, builds an in-memory intermediate representation, and a renderer converts that structure into Dart code. There is no formal AST and no external parser dependency.

## Architectural goals

- Keep the package small and free of heavy dependencies
- Generate predictable DTOs from a practical subset of ZModel
- Support both build pipelines and manual execution
- Optionally embed ZenStack RPC support in generated code

## Main components

### Public API

File: `lib/zmodel_to_dart.dart`

This file exposes the public package surface:

- `zmodelToDartBuilder`
- `ZModelToDartConfig`
- `ZModelGenerator`
- `ZModelRpcGenerator`
- `ZenStackRpcTransport` and RPC utilities
- `runZModelStandalone`

### Configuration

File: `lib/src/config.dart`

`ZModelToDartConfig` centralizes loading of `zmodel_to_dart.yaml`. The same configuration is shared by the builder and the CLI.

Responsibilities:

- Read `input_globs`, `output_suffix`, `output_dir`, and `banner`
- Enable or disable RPC generation with `generate_rpc_clients`
- Define `rpc_base_path`
- Resolve the input file in standalone mode
- Filter assets in `build_runner` mode

Important decision:

- `build.yaml` only registers the builder
- Functional generator behavior lives in `zmodel_to_dart.yaml`

### build_runner builder

File: `lib/src/builder.dart`

The builder is the incremental integration point with the `build` ecosystem.

Flow:

1. Load `ZModelToDartConfig`
2. Ignore files that do not match `input_globs`
3. Read the `.zmodel` contents
4. Call `ZModelGenerator.parse`
5. Call `ZModelGenerator.renderSingleLibrary`
6. Write the result next to the source file using `output_suffix`

Important characteristic:

- In builder mode, all output from a `.zmodel` file goes into a single Dart library
- RPC support, when enabled, is also embedded into that same library

### Standalone CLI

Files:

- `bin/zmodel_to_dart.dart`
- `lib/zmodel_standalone.dart`

Standalone mode is a simple entrypoint for generating code outside `build_runner`.

Flow:

1. Load `ZModelToDartConfig`
2. Resolve the source file from CLI arguments or `input_globs`
3. Resolve the output directory from CLI arguments or `output_dir`
4. Call `ZModelGenerator.generateDirectory`

Important characteristic:

- `generateDirectory` deletes the existing output directory by default before recreating it
- Unlike builder mode, this mode generates multiple files, one per enum and one per concrete model
- The current standalone mode does not generate RPC clients

### Generation engine

File: `lib/src/generator.dart`

`ZModelGenerator` is the center of the project. It does three things:

- Parse the schema
- Resolve inheritance and custom types
- Render Dart code

#### Phase 1: text parsing

The parser works line by line and recognizes:

- `model`
- `abstract model`
- `enum`
- simple fields
- `@@id` and `@@unique` directives

Comments starting with `//` and empty lines are ignored.

The parse result is `ParsedZModel`, composed of:

- `List<TableDefinition> tables`
- `List<EnumDefinition> enums`

#### Phase 2: semantic enrichment

After the raw parse, the generator runs two resolution passes:

- `resolveExtends`: links models to their parent definitions by name
- `resolveCustomTypes`: marks custom types that correspond to enums

This allows the renderer to correctly handle:

- inherited fields
- enums
- references to other models

#### Phase 3: rendering

The renderer has two output strategies:

- `renderSingleLibrary`: used by the builder
- `generateDirectory` with `renderEnum` and `renderTable`: used by the CLI

Generated code includes:

- inline `ZModel` base class in consolidated output
- `ZModelEnum` base interface when enums exist
- DTOs with `fromJson` and `toJson`
- static coercion and serialization helpers
- optionally `ZModelRpcClient`, `ZenStackRpcMethod`, and `ZenStackRpcTransport`

## Internal model

### ParsedZModel

Represents the fully parsed schema. It also reports whether output requires:

- `dart:convert`
- `dart:typed_data`

At the moment, this happens when `Bytes` fields are present.

### TableDefinition

Represents a schema `model`.

Responsibilities:

- store the name, inheritance, and `abstract` flag
- accumulate declared columns
- merge inherited columns in `allColumns`
- prioritize primary keys and relations in final ordering

Important note:

- Abstract models are kept in the parse result and participate in inheritance
- Only concrete models are rendered as final DTOs

### ColumnDefinition

Represents a field or a fragment derived from table directives.

Responsibilities:

- map ZModel types to Dart types
- track nullability, list shape, primary key, uniqueness, foreign key, and enum state
- produce code snippets for attributes, constructor parameters, `fromJson`, and `toJson`

Relevant mappings:

- `String -> String`
- `Int -> int`
- `BigInt -> BigInt`
- `Float -> num`
- `Boolean -> bool`
- `DateTime -> DateTime`
- `Json -> dynamic`
- `Bytes -> Uint8List`
- all other types -> model or enum references

### EnumDefinition

Represents a schema `enum` and knows how to derive:

- the Dart type name in PascalCase
- the lowercase filename
- the ordered list of declared values

## Main flows

### Flow 1: build_runner

```text
.zmodel
  -> Builder
  -> Config
  -> ZModelGenerator.parse
  -> inheritance/type resolution
  -> renderSingleLibrary
  -> .zmodel.dart file
```

### Flow 2: standalone CLI

```text
.zmodel
  -> runZModelStandalone
  -> Config.resolveSourceFile
  -> ZModelGenerator.generateDirectory
  -> renderEnum/renderTable
  -> DTO output directory
```

### Flow 3: optional RPC

```text
config.generate_rpc_clients = true
  -> renderSingleLibrary(..., includeRpcClients: true)
  -> inline RPC scaffolding
  -> ZModelRpcGenerator.renderClient()
  -> generic client typed by T extends ZModel
```

## RPC layer

Files:

- `lib/src/rpc_generator.dart`
- `lib/src/rpc_support.dart`

There are two distinct parts:

- `rpc_generator.dart`: generates the inline Dart source for the RPC client that is emitted into generated files
- `rpc_support.dart`: provides manual utilities for package consumers, especially `ZModelRequest` and the `ZenStackRpcTransport` abstraction

Characteristics of the generated client:

- generic `ZModelRpcClient`
- endpoints inferred from `ZModel.modelNameOf<T>()`
- typed methods such as `findMany<T>()`, `findUnique<T>()`, `create<T>()`, `update<T>()`, `aggregate<T>()`, and `groupBy<T>()`
- JSON payload normalization
- best-effort deserialization of `superjson` envelopes

Important decision:

- RPC generation is coupled to the consolidated `renderSingleLibrary` output
- Standalone mode stays focused on DTO generation only

## Stable contracts

Today, the most central external contracts are:

- `ZModelToDartConfig.load()`
- `zmodelToDartBuilder()`
- `ZModelGenerator.parse()`
- `ZModelGenerator.renderSingleLibrary()`
- `runZModelStandalone()`
- `ZenStackRpcTransport.send()`

Changes to these points are the most likely to affect external compatibility.

## Current limitations

The current implementation makes pragmatic choices and has clear limits:

- The parser is text-based and depends on relatively simple line formats
- There is no full AST and no deep structural schema validation
- Only a small subset of table directives is interpreted directly: `@@id` and `@@unique`
- Custom type recognition only distinguishes enums after the full parse finishes
- Standalone mode deletes the output directory by default
- RPC support is only emitted in consolidated output, not in multi-file standalone output

These limitations match the package goal: lightweight, predictable generation with low operational complexity.

## Tests and architectural coverage

File: `test/zmodel_to_dart_test.dart`

Current tests mainly cover:

- enum and model parsing/rendering
- primitive and materialized scalar coercion
- inheritance through `extends`
- YAML configuration loading
- RPC client generation
- deserialization of serialized envelopes expected by the generated RPC client

This shows that project reliability is concentrated on generated output behavior, not on a large internal infrastructure layer.

## Evolution guidelines

When evolving the project, these invariants are worth preserving:

- `build_runner` still generates one output file per schema
- CLI still works without depending on `build_runner`
- `ZModelGenerator` remains the single center for parsing and rendering
- type mappings and serialization helpers stay deterministic
- new schema features should first enter the intermediate model and only then the renderer

If parser complexity grows, the natural next step is to separate:

- lexer/parser
- semantic model
- Dart renderer

That still does not seem necessary today, because the codebase remains small and the cognitive cost of the current approach is low.
