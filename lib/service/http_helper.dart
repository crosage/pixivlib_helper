import 'dart:io';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:dio/io.dart';

class HttpHelper {
  final String? _globalProxyHost;
  final String? _globalProxyPort;
  final bool _globalSkipBadCertificates;

  late final Dio _dioStandard;
  late final Dio? _dioWithProxy;

  static HttpHelper? _instance;

  HttpHelper._internal({
    BaseOptions? baseOptions,
    String? globalProxyHost,
    String? globalProxyPort,
    bool globalSkipBadCertificates = false,
  })  : _globalProxyHost = globalProxyHost,
        _globalProxyPort = globalProxyPort,
        _globalSkipBadCertificates = globalSkipBadCertificates {
    _dioStandard = Dio(_baseOptions(baseOptions));
    _dioWithProxy = _initProxyDio(baseOptions);
  }

  static HttpHelper getInstance({
    BaseOptions? baseOptions,
    String? globalProxyHost,
    String? globalProxyPort,
    bool globalSkipBadCertificates = false,
  }) {
    _instance ??= HttpHelper._internal(
      baseOptions: baseOptions,
      globalProxyHost: globalProxyHost,
      globalProxyPort: globalProxyPort,
      globalSkipBadCertificates: globalSkipBadCertificates,
    );
    return _instance!;
  }

  Dio? _initProxyDio(BaseOptions? baseOptions) {
    final hasProxy = _globalProxyHost != null &&
        _globalProxyHost!.isNotEmpty &&
        _globalProxyPort != null &&
        _globalProxyPort!.isNotEmpty;
    if (!hasProxy) {
      return null;
    }

    final dio = Dio(_baseOptions(baseOptions));
    final adapter = dio.httpClientAdapter;
    if (adapter is! IOHttpClientAdapter) {
      return null;
    }

    adapter.createHttpClient = () {
      final client = HttpClient();
      client.findProxy = (_) => 'PROXY $_globalProxyHost:$_globalProxyPort;';
      if (_globalSkipBadCertificates) {
        client.badCertificateCallback =
            (X509Certificate cert, String host, int port) => true;
      }
      return client;
    };
    return dio;
  }

  BaseOptions _baseOptions(BaseOptions? baseOptions) {
    final options = baseOptions ?? BaseOptions();
    options.validateStatus = (_) => true;
    return options;
  }

  Options _mergeOptions({
    Options? requestSpecificOptions,
    Map<String, dynamic>? headers,
  }) {
    final mergedOptions = requestSpecificOptions ?? Options();
    final mergedHeaders =
        Map<String, dynamic>.from(mergedOptions.headers ?? {});
    if (headers != null) {
      mergedHeaders.addAll(headers);
    }
    mergedOptions.headers = mergedHeaders;
    mergedOptions.validateStatus = (_) => true;
    return mergedOptions;
  }

  Future<Response> _executeRequest(
    String method,
    String url, {
    dynamic data,
    Map<String, dynamic>? queryParameters,
    Map<String, dynamic>? headers,
    bool useProxy = false,
    Options? options,
  }) async {
    final client =
        useProxy && _dioWithProxy != null ? _dioWithProxy! : _dioStandard;
    final requestOptions = _mergeOptions(
      requestSpecificOptions: options,
      headers: headers,
    );

    switch (method.toUpperCase()) {
      case 'GET':
        return client.get(
          url,
          queryParameters: queryParameters,
          options: requestOptions,
        );
      case 'POST':
        return client.post(
          url,
          data: data,
          queryParameters: queryParameters,
          options: requestOptions,
        );
      case 'PUT':
        return client.put(
          url,
          data: data,
          queryParameters: queryParameters,
          options: requestOptions,
        );
      case 'DELETE':
        return client.delete(
          url,
          data: data,
          queryParameters: queryParameters,
          options: requestOptions,
        );
      case 'DOWNLOAD':
        if (data is! String) {
          throw ArgumentError(
            'For DOWNLOAD method, "data" must be the save path (String).',
          );
        }
        await client.download(
          url,
          data,
          queryParameters: queryParameters,
          options: requestOptions,
        );
        return Response(
          requestOptions: RequestOptions(path: url),
          statusCode: 200,
          statusMessage: 'Download Complete',
        );
      default:
        throw UnimplementedError('HTTP method $method not implemented.');
    }
  }

  Future<Response> getRequest(
    String url, {
    Map<String, dynamic>? params,
    Map<String, dynamic>? headers,
    bool useProxy = false,
  }) {
    return _executeRequest(
      'GET',
      url,
      queryParameters: params,
      headers: headers,
      useProxy: useProxy,
    );
  }

  Future<Response> postRequest(
    String url,
    dynamic data, {
    Map<String, dynamic>? queryParameters,
    Map<String, dynamic>? headers,
    bool useProxy = false,
  }) {
    return _executeRequest(
      'POST',
      url,
      data: data,
      queryParameters: queryParameters,
      headers: headers,
      useProxy: useProxy,
    );
  }

  Future<Response> putRequest(
    String url,
    dynamic data, {
    Map<String, dynamic>? queryParameters,
    Map<String, dynamic>? headers,
    bool useProxy = false,
  }) {
    return _executeRequest(
      'PUT',
      url,
      data: data,
      queryParameters: queryParameters,
      headers: headers,
      useProxy: useProxy,
    );
  }

  Future<Response> deleteRequest(
    String url, {
    dynamic data,
    Map<String, dynamic>? params,
    Map<String, dynamic>? headers,
    bool useProxy = false,
  }) {
    return _executeRequest(
      'DELETE',
      url,
      data: data,
      queryParameters: params,
      headers: headers,
      useProxy: useProxy,
    );
  }

  Future<Response> uploadFile(
    String url,
    String filePath, {
    Map<String, dynamic>? headers,
    bool useProxy = false,
    String fileFieldName = 'file',
  }) async {
    final fileName = filePath.split('/').last;
    final formData = FormData.fromMap({
      fileFieldName: await MultipartFile.fromFile(filePath, filename: fileName),
    });
    return _executeRequest(
      'POST',
      url,
      data: formData,
      headers: headers,
      useProxy: useProxy,
      options: Options(contentType: Headers.multipartFormDataContentType),
    );
  }

  Future<Response> downloadFile(
    String url,
    String savePath, {
    Map<String, dynamic>? queryParameters,
    Map<String, dynamic>? headers,
    bool useProxy = false,
  }) {
    return _executeRequest(
      'DOWNLOAD',
      url,
      data: savePath,
      queryParameters: queryParameters,
      headers: headers,
      useProxy: useProxy,
    );
  }

  Future<Uint8List?> getBytesRequest(
    String url, {
    Map<String, dynamic>? params,
    Map<String, dynamic>? headers,
    bool useProxy = false,
  }) async {
    try {
      final response = await _executeRequest(
        'GET',
        url,
        queryParameters: params,
        headers: headers,
        useProxy: useProxy,
        options: Options(responseType: ResponseType.bytes),
      );
      if (response.statusCode == 200 && response.data is List<int>) {
        return Uint8List.fromList(response.data as List<int>);
      }
    } catch (_) {
      return null;
    }
    return null;
  }

  void dispose() {
    _dioStandard.close();
    _dioWithProxy?.close();
  }
}
