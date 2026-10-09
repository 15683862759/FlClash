import 'dart:io';

import 'package:dio/dio.dart';
import 'package:fl_clash/common/request.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('getTextResponseForUrl propagates the typed DioException', () async {
    // flutter_test's mocked HttpClient answers every request with HTTP 400,
    // which Dio surfaces as a badResponse DioException.
    await expectLater(
      request.getTextResponseForUrl('http://127.0.0.1/anything'),
      throwsA(
        isA<DioException>().having(
          (e) => e.type,
          'type',
          DioExceptionType.badResponse,
        ),
      ),
    );
  });

  test('getFileResponseForUrl propagates the typed DioException', () async {
    await expectLater(
      request.getFileResponseForUrl('http://127.0.0.1/anything'),
      throwsA(
        isA<DioException>().having(
          (e) => e.type,
          'type',
          DioExceptionType.badResponse,
        ),
      ),
    );
  });

  test('both clients wait with a timeout', () {
    final client = Request();

    expect(client.dio.options.connectTimeout, isNotNull);
    expect(client.dio.options.receiveTimeout, isNotNull);
    expect(client.clashDio.options.connectTimeout, isNotNull);
    expect(client.clashDio.options.receiveTimeout, isNotNull);
  });

  test(
    'a subscription that stops answering fails instead of hanging',
    () async {
      final server = await ServerSocket.bind(InternetAddress.loopbackIPv4, 0);
      final sockets = <Socket>[];
      server.listen(sockets.add);
      addTearDown(() async {
        for (final socket in sockets) {
          socket.destroy();
        }
        await server.close();
      });
      final client = Request(receiveTimeout: const Duration(milliseconds: 300));
      final stopwatch = Stopwatch()..start();

      await HttpOverrides.runZoned(() async {
        await expectLater(
          client.getFileResponseForUrl('http://127.0.0.1:${server.port}/sub'),
          throwsA(isA<DioException>()),
        );
      }, createHttpClient: (context) => HttpClient(context: context));
      stopwatch.stop();

      expect(stopwatch.elapsed, lessThan(const Duration(seconds: 3)));
    },
  );
}
