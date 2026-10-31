import 'dart:async';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:dogsninjapi/main.dart';
import 'package:dogsninjapi/models/dog_breed.dart';
import 'package:dogsninjapi/network/api_key_interceptor.dart';
import 'package:dogsninjapi/network/dogs_api.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

class TestAdapter implements HttpClientAdapter {
  int calls = 0;
  RequestOptions? request;

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    calls++;
    request = options;
    return ResponseBody.fromString(
      '[{"name":"Husky","energy":5}]',
      200,
      headers: {
        Headers.contentTypeHeader: [Headers.jsonContentType],
      },
    );
  }

  @override
  void close({bool force = false}) {}
}

class PendingApi extends DogsApi {
  PendingApi() : super(Dio());
  final requests =
      <
        ({
          Map<String, dynamic> filters,
          int offset,
          Completer<List<DogBreed>> result,
        })
      >[];

  @override
  Future<List<DogBreed>> search(
    Map<String, dynamic> filters, {
    int offset = 0,
    CancelToken? cancelToken,
  }) {
    final result = Completer<List<DogBreed>>();
    requests.add((filters: Map.of(filters), offset: offset, result: result));
    return result.future;
  }
}

void main() {
  test(
    'Dio sends filters, pagination and the API key through its interceptor',
    () async {
      final adapter = TestAdapter();
      final dio = Dio(BaseOptions(baseUrl: 'https://api.api-ninjas.com/v1/'));
      dio.httpClientAdapter = adapter;
      dio.interceptors.add(ApiKeyInterceptor('test-key'));
      final rows = await DogsApi(
        dio,
      ).search({'name': 'husky', 'energy': 5}, offset: 20);
      expect(adapter.request!.uri.path, '/v1/dogs');
      expect(adapter.request!.queryParameters, {
        'name': 'husky',
        'energy': 5,
        'offset': 20,
      });
      expect(adapter.request!.headers['X-Api-Key'], 'test-key');
      expect(rows.single.name, 'Husky');
      expect(rows.single.number('energy'), 5);
    },
  );

  test('Missing key is rejected before sending the request', () async {
    final adapter = TestAdapter();
    final dio = Dio()..httpClientAdapter = adapter;
    dio.interceptors.add(ApiKeyInterceptor(''));
    await expectLater(
      DogsApi(dio).search({'name': 'husky'}),
      throwsA(isA<DioException>()),
    );
    expect(adapter.calls, 0);
  });

  test('API dimensions are converted from imperial units', () {
    final breed = DogBreed.fromJson({
      'name': 'Husky',
      'min_height_male': 20,
      'max_height_male': 24,
    });
    expect(
      breed.range('min_height_male', 'max_height_male', factor: 2.54),
      '50.8–61.0',
    );
    expect(breed.range('min_weight_male', 'max_weight_male'), 'Нет данных');
    expect(() => DogBreed.fromJson({}), throwsFormatException);
  });

  testWidgets('Empty form does not issue a request', (tester) async {
    final api = PendingApi();
    await tester.pumpWidget(DogsApp(api: api));
    await tester.tap(find.text('Найти породы'));
    await tester.pump();
    expect(api.requests, isEmpty);
    expect(
      find.text('Введи название породы или выбери характеристику.'),
      findsOneWidget,
    );
  });

  testWidgets('A late response cannot replace a more recent search', (
    tester,
  ) async {
    final api = PendingApi();
    await tester.pumpWidget(DogsApp(api: api));
    await tester.enterText(find.byType(TextField), 'husky');
    await tester.tap(find.text('Найти породы'));
    await tester.pump();
    await tester.enterText(find.byType(TextField), 'poodle');
    await tester.tap(find.text('Найти породы'));
    await tester.pump();
    api.requests[1].result.complete([
      DogBreed.fromJson({'name': 'Poodle'}),
    ]);
    await tester.pumpAndSettle();
    api.requests[0].result.complete([
      DogBreed.fromJson({'name': 'Husky'}),
    ]);
    await tester.pumpAndSettle();
    expect(find.text('Poodle'), findsOneWidget);
    expect(find.text('Husky'), findsNothing);
  });

  testWidgets(
    'Pagination keeps submitted filters and empty pages allow going back',
    (tester) async {
      final api = PendingApi();
      await tester.pumpWidget(DogsApp(api: api));
      await tester.enterText(find.byType(TextField), 'terrier');
      await tester.tap(find.text('Найти породы'));
      await tester.pump();
      api.requests[0].result.complete(
        List.generate(20, (i) => DogBreed.fromJson({'name': 'Terrier $i'})),
      );
      await tester.pumpAndSettle();
      await tester.enterText(find.byType(TextField), 'unsent');
      await tester.ensureVisible(find.byTooltip('Следующая страница'));
      await tester.tap(find.byTooltip('Следующая страница'));
      await tester.pump();
      expect(api.requests[1].filters, {'name': 'terrier'});
      expect(api.requests[1].offset, 20);
      api.requests[1].result.complete([]);
      await tester.pumpAndSettle();
      await tester.ensureVisible(find.byTooltip('Предыдущая страница'));
      await tester.tap(find.byTooltip('Следующая страница'));
      await tester.pump();
      expect(api.requests.length, 2);
      await tester.tap(find.byTooltip('Предыдущая страница'));
      await tester.pump();
      expect(api.requests[2].offset, 0);
      expect(api.requests[2].filters, {'name': 'terrier'});
      api.requests[2].result.complete([]);
      await tester.pumpAndSettle();
    },
  );

  testWidgets('Rate limit error is shown and retry repeats the same query', (
    tester,
  ) async {
    final api = PendingApi();
    await tester.pumpWidget(DogsApp(api: api));
    await tester.enterText(find.byType(TextField), 'husky');
    await tester.tap(find.text('Найти породы'));
    await tester.pump();
    api.requests[0].result.completeError(
      DioException(
        requestOptions: RequestOptions(),
        response: Response(requestOptions: RequestOptions(), statusCode: 429),
      ),
    );
    await tester.pumpAndSettle();
    expect(
      find.text('Превышен лимит запросов API. Попробуй позже.'),
      findsOneWidget,
    );
    await tester.ensureVisible(find.text('Повторить'));
    await tester.tap(find.text('Повторить'));
    await tester.pump();
    expect(api.requests[1].filters, {'name': 'husky'});
    api.requests[1].result.complete([]);
    await tester.pumpAndSettle();
    expect(
      find.text('Породы не найдены. Попробуй другое название или фильтры.'),
      findsOneWidget,
    );
  });
}
