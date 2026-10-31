import 'package:dio/dio.dart';

import '../models/dog_breed.dart';

class DogsApi {
  DogsApi(this.dio);

  final Dio dio;

  Future<List<DogBreed>> search(
    Map<String, dynamic> filters, {
    int offset = 0,
    CancelToken? cancelToken,
  }) async {
    if (filters.isEmpty) {
      throw ArgumentError('At least one filter is required');
    }
    final response = await dio.get<dynamic>(
      'dogs',
      queryParameters: {...filters, 'offset': offset},
      cancelToken: cancelToken,
    );
    if (response.data is! List) {
      throw const FormatException('Expected a list of breeds');
    }
    return (response.data as List).map((item) {
      if (item is! Map<String, dynamic>) {
        throw const FormatException('Invalid breed');
      }
      return DogBreed.fromJson(item);
    }).toList();
  }
}

String apiErrorMessage(Object error) {
  if (error is FormatException) {
    return 'API вернул данные в неизвестном формате.';
  }
  if (error is! DioException) {
    return 'Не удалось загрузить породы. Повтори запрос.';
  }
  if (error.error == 'missingApiKey') {
    return 'Не задан ключ API. Запусти приложение с параметром DOGS_API_KEY.';
  }
  switch (error.response?.statusCode) {
    case 400:
      return 'API отклонил параметры поиска. Измени фильтры.';
    case 401:
    case 403:
      return 'API отклонил доступ. Проверь ключ и доступность Dogs API в тарифе.';
    case 429:
      return 'Превышен лимит запросов API. Попробуй позже.';
  }
  if (error.type == DioExceptionType.connectionTimeout ||
      error.type == DioExceptionType.receiveTimeout ||
      error.type == DioExceptionType.sendTimeout) {
    return 'Сервер не ответил вовремя. Попробуй ещё раз.';
  }
  if (error.type == DioExceptionType.connectionError) {
    return 'Нет соединения с API. Проверь интернет и доступность сервиса.';
  }
  return 'Сервис временно недоступен. Попробуй ещё раз.';
}
