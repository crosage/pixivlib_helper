import 'dart:io';
import 'package:dio/dio.dart';
import 'dart:typed_data';
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
    _dioStandard = Dio(baseOptions ?? BaseOptions());
    print('Standard Dio instance initialized.');
    _dioWithProxy = _initProxyDio(baseOptions);
    print('HttpHelper instance fully constructed.');
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
    if (_globalProxyHost != null &&
        _globalProxyHost!.isNotEmpty &&
        _globalProxyPort != null &&
        _globalProxyPort!.isNotEmpty) {
      print(
          'Attempting to initialize Dio instance with proxy: $_globalProxyHost:$_globalProxyPort');
      final dio = Dio(baseOptions ?? BaseOptions());
      final adapter = dio.httpClientAdapter;
      if (adapter is IOHttpClientAdapter) {
        adapter.createHttpClient = () {
          final client = HttpClient();
          client.findProxy = (uri) {
            return "PROXY $_globalProxyHost:$_globalProxyPort;";
          };
          if (_globalSkipBadCertificates) {
            client.badCertificateCallback =
                (X509Certificate cert, String host, int port) => true;
            print(
                'Warning: Skipping bad certificate checks for proxy connection (global setting).');
          }
          return client;
        };
        print(
            'Proxy Dio instance configured successfully for $_globalProxyHost:$_globalProxyPort.');
        return dio;
      } else {
        print(
            'Error: Cannot configure proxy. Invalid HttpClientAdapter type: ${adapter.runtimeType}. Proxy features will be unavailable.');
        return null;
      }
    } else {
      print(
          'Global proxy configuration not provided or incomplete. Proxy Dio instance will not be created.');
      return null;
    }
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
    return mergedOptions;
  }

  Future<Response> _executeRequest(String method, String url,
      {dynamic data,
      Map<String, dynamic>? queryParameters,
      Map<String, dynamic>? headers,
      bool useProxy = false,
      Options? options}) async {
    Dio clientToUse;
    if (useProxy) {
      if (_dioWithProxy != null) {
        clientToUse = _dioWithProxy!;
        print('Using pre-configured proxy Dio for request to $url.');
      } else {
        print(
            'Warning: useProxy=true requested for $url, but proxy client is not available. Falling back to standard client.');
        clientToUse = _dioStandard;
      }
    } else {
      clientToUse = _dioStandard;
    }
    final requestOptions =
        _mergeOptions(requestSpecificOptions: options, headers: headers);
    try {
      switch (method.toUpperCase()) {
        case 'GET':
          return await clientToUse.get(url,
              queryParameters: queryParameters, options: requestOptions);
        case 'POST':
          return await clientToUse.post(url,
              data: data,
              queryParameters: queryParameters,
              options: requestOptions);
        case 'PUT':
          return await clientToUse.put(url,
              data: data,
              queryParameters: queryParameters,
              options: requestOptions);
        case 'DELETE':
          return await clientToUse.delete(url,
              data: data,
              queryParameters: queryParameters,
              options: requestOptions);
        case 'DOWNLOAD':
          if (data is! String) {
            throw ArgumentError(
                'For DOWNLOAD method, "data" must be the save path (String).');
          }
          await clientToUse.download(url, data,
              queryParameters: queryParameters,
              options: requestOptions, onReceiveProgress: (received, total) {
            if (total != -1) {
              print(
                  'Download progress: ${(received / total * 100).toStringAsFixed(0)}%');
            }
          });
          return Response(
              requestOptions: RequestOptions(path: url),
              statusCode: 200,
              statusMessage: "Download Complete");
        default:
          throw UnimplementedError('HTTP method $method not implemented.');
      }
    } on DioException catch (e) {
      print(
          'DioException during $method request to $url (using ${useProxy ? "proxy" : "standard"} client): ${e.message}');
      if (e.response != null) {
        print(
            'Error Response: Status ${e.response?.statusCode}, Data: ${e.response?.data}');
        return e.response!;
      } else {
        print('Error details: ${e.error}');
        throw e;
      }
    } catch (e) {
      print('Unexpected error during $method request to $url: $e');
      throw e;
    }
  }

  Future<Response> getRequest(String url,
      {Map<String, dynamic>? params,
      Map<String, dynamic>? headers,
      bool useProxy = false}) async {
    return _executeRequest('GET', url,
        queryParameters: params, headers: headers, useProxy: useProxy);
  }

  Future<Response> postRequest(String url, dynamic data,
      {Map<String, dynamic>? queryParameters,
      Map<String, dynamic>? headers,
      bool useProxy = false}) async {
    return _executeRequest('POST', url,
        data: data,
        queryParameters: queryParameters,
        headers: headers,
        useProxy: useProxy);
  }

  Future<Response> putRequest(String url, dynamic data,
      {Map<String, dynamic>? queryParameters,
      Map<String, dynamic>? headers,
      bool useProxy = false}) async {
    return _executeRequest('PUT', url,
        data: data,
        queryParameters: queryParameters,
        headers: headers,
        useProxy: useProxy);
  }

  Future<Response> deleteRequest(String url,
      {dynamic data,
      Map<String, dynamic>? params,
      Map<String, dynamic>? headers,
      bool useProxy = false}) async {
    return _executeRequest('DELETE', url,
        data: data,
        queryParameters: params,
        headers: headers,
        useProxy: useProxy);
  }

  Future<Response> uploadFile(String url, String filePath,
      {Map<String, dynamic>? headers,
      bool useProxy = false,
      String fileFieldName = 'file'}) async {
    String fileName = filePath.split('/').last;
    FormData formData = FormData.fromMap({
      fileFieldName: await MultipartFile.fromFile(filePath, filename: fileName)
    });
    return _executeRequest('POST', url,
        data: formData,
        headers: headers,
        useProxy: useProxy,
        options: Options(contentType: Headers.multipartFormDataContentType));
  }

  Future<Response> downloadFile(String url, String savePath,
      {Map<String, dynamic>? queryParameters,
      Map<String, dynamic>? headers,
      bool useProxy = false}) async {
    return _executeRequest('DOWNLOAD', url,
        data: savePath,
        queryParameters: queryParameters,
        headers: headers,
        useProxy: useProxy);
  }

  Future<Uint8List?> getBytesRequest(String url,
      {Map<String, dynamic>? params,
      Map<String, dynamic>? headers,
      bool useProxy = false}) async {
    try {
      final response = await _executeRequest('GET', url,
          queryParameters: params,
          headers: headers,
          useProxy: useProxy,
          options: Options(responseType: ResponseType.bytes));
      if (response.statusCode == 200 && response.data != null) {
        if (response.data is List<int>) {
          return Uint8List.fromList(response.data as List<int>);
        } else {
          print(
              'Error: Expected List<int> but got ${response.data.runtimeType}');
          return null;
        }
      } else {
        print('Failed to get bytes: Status code ${response.statusCode}');
        return null;
      }
    } catch (e) {
      print('Error fetching bytes for $url: $e');
      return null;
    }
  }

  void dispose() {
    print('Closing Dio instances in HttpHelper...');
    _dioStandard.close();
    _dioWithProxy?.close();
    print('Dio instances closed.');
  }
}
