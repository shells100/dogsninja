import 'package:dio/dio.dart';

class ApiKeyInterceptor extends Interceptor {
  ApiKeyInterceptor(this.apiKey);

  final String apiKey;

  @override
  void onRequest(RequestOptions options, RequestInterceptorHandler handler) {
    if (apiKey.trim().isEmpty) {
      handler.reject(
        DioException(requestOptions: options, error: 'missingApiKey'),
      );
      return;
    }
    options.headers['X-Api-Key'] = apiKey;
    handler.next(options);
  }
}
