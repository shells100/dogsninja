import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:get_it/get_it.dart';
import 'package:pretty_dio_logger/pretty_dio_logger.dart';

import 'network/api_key_interceptor.dart';
import 'network/dogs_api.dart';

final getIt = GetIt.instance;

void configureDependencies() {
  getIt.registerLazySingleton<Dio>(() {
    final dio = Dio(
      BaseOptions(
        baseUrl: 'https://api.api-ninjas.com/v1/',
        connectTimeout: const Duration(seconds: 15),
        receiveTimeout: const Duration(seconds: 20),
        headers: {'Accept': 'application/json'},
      ),
    );
    dio.interceptors.addAll([
      ApiKeyInterceptor(const String.fromEnvironment('DOGS_API_KEY')),
      PrettyDioLogger(
        enabled: kDebugMode,
        requestHeader: false,
        requestBody: false,
        responseHeader: false,
        responseBody: false,
        error: false,
        compact: true,
      ),
    ]);
    return dio;
  });
  getIt.registerLazySingleton<DogsApi>(() => DogsApi(getIt<Dio>()));
}
