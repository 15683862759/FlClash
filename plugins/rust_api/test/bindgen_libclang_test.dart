import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:rust_api/src/bindgen_libclang.dart';

void main() {
  String join(List<String> parts) => parts.join(Platform.pathSeparator);

  final prebuilt = ['ndk', 'toolchains', 'llvm', 'prebuilt', 'linux-x86_64'];

  DirectoryEntries entriesFrom(Map<String, List<String>> entries) {
    return (directory) => entries[directory] ?? const [];
  }

  test('finds the libclang the NDK keeps under lib', () {
    final lib = join([...prebuilt, 'lib']);
    expect(
      libclangDirectory(
        compilerPath: join([...prebuilt, 'bin', 'clang']),
        entriesOf: entriesFrom({
          lib: ['libclang.so.18', 'libLLVM.so'],
        }),
      ),
      lib,
    );
  });

  test('falls back to lib64 for the NDKs that keep it there', () {
    final lib64 = join([...prebuilt, 'lib64']);
    expect(
      libclangDirectory(
        compilerPath: join([...prebuilt, 'bin', 'clang']),
        entriesOf: entriesFrom({
          lib64: ['libclang.so'],
        }),
      ),
      lib64,
    );
  });

  test('takes the directory LIBCLANG_PATH names', () {
    final llvm = join(['C:', 'Program Files', 'LLVM', 'bin']);
    expect(
      libclangDirectory(
        compilerPath: join([...prebuilt, 'bin', 'clang']),
        override: llvm,
        entriesOf: entriesFrom({
          llvm: ['libclang.dll'],
        }),
      ),
      llvm,
    );
  });

  test('keeps looking in the NDK when LIBCLANG_PATH holds no libclang', () {
    final lib = join([...prebuilt, 'lib']);
    expect(
      libclangDirectory(
        compilerPath: join([...prebuilt, 'bin', 'clang']),
        override: join(['somewhere', 'empty']),
        entriesOf: entriesFrom({
          lib: ['libclang.so'],
        }),
      ),
      lib,
    );
  });

  test('reports nothing when the host NDK ships no libclang', () {
    expect(
      libclangDirectory(
        compilerPath: join([
          'ndk',
          'toolchains',
          'llvm',
          'prebuilt',
          'windows-x86_64',
          'bin',
          'clang.exe',
        ]),
        entriesOf: entriesFrom(const {}),
      ),
      isNull,
    );
  });

  test('reads a real directory beside the compiler', () {
    final root = Directory.systemTemp.createTempSync('libclang-search');
    addTearDown(() => root.deleteSync(recursive: true));
    final lib = Directory(join([root.path, 'lib']))..createSync();
    File(join([lib.path, 'libclang.so'])).writeAsStringSync('');

    expect(
      libclangDirectory(compilerPath: join([root.path, 'bin', 'clang.exe'])),
      lib.path,
    );
  });
}
