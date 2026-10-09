import 'dart:io';

import 'package:code_assets/code_assets.dart';
import 'package:flutter_rust_bridge_hooks/flutter_rust_bridge_hooks.dart';
import 'package:rust_api/src/bindgen_libclang.dart';

void main(List<String> args) async {
  await build(args, (input, output) async {
    if (input.userDefines['build_assets'] == false) {
      stdout.writeln('Skipping the Rust build: user-define build_assets=false');
      return;
    }
    await FlutterRustBridgeNativeAssetsBuilder(
      cratePath: 'rust',
      extraCargoEnvironmentVariables: _bindgenEnvironment(input),
    ).run(input: input, output: output);
  });
}

// rquickjs runs bindgen on Android, which must load a libclang.
Map<String, String> _bindgenEnvironment(BuildInput input) {
  if (!input.config.buildCodeAssets ||
      input.config.code.targetOS != OS.android) {
    return const {};
  }
  final compiler = input.config.code.cCompiler?.compiler;
  if (compiler == null) {
    return const {};
  }
  final directory = libclangDirectory(
    compilerPath: compiler.toFilePath(),
    override: Platform.environment['LIBCLANG_PATH'],
  );
  if (directory == null) {
    throw StateError(
      'No libclang for bindgen: neither LIBCLANG_PATH nor the NDK Flutter '
      'passed ($compiler) holds one. Windows NDKs from r27 keep none, so point '
      'LIBCLANG_PATH at an LLVM installation that ships libclang.',
    );
  }
  return {'LIBCLANG_PATH': directory};
}
