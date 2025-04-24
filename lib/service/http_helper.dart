import 'dart:io';
import 'package:dio/dio.dart';
import 'dart:typed_data';
import 'package:dio/io.dart';
class HttpHelper {
  late Dio _dio;

  HttpHelper() {
    _dio = Dio(BaseOptions());
  }

  Future<Response> getRequest(String url, {String? token, Map<String, dynamic>? params}) async {
    try {
      if (token != null) {
        _dio.options.headers['Authorization'] = 'Bearer $token';
      } else {
        _dio.options.headers.remove('Authorization');
      }
      Response response = await _dio.get(url, queryParameters: params);
      return response;
    } catch (e) {
      if (e is DioException && e.response != null) {
        return e.response!;
      } else {
        return Future.error(e);
      }
    }
  }

  Future<Response> postRequest(String url, dynamic data, {String? token}) async {
    try {
      if (token != null) {
        _dio.options.headers['Authorization'] = 'Bearer $token';
      } else {
        _dio.options.headers.remove('Authorization');
      }
      Response response = await _dio.post(url, data: data);
      return response;
    } catch (e) {
      if (e is DioException && e.response != null) {
        return e.response!;
      } else {
        return Future.error(e);
      }
    }
  }

  Future<Response> deleteRequest(String url, {String? token, Map<String, dynamic>? params}) async {
    try {
      if (token != null) {
        _dio.options.headers['Authorization'] = 'Bearer $token';
      } else {
        _dio.options.headers.remove('Authorization');
      }
      Response response = await _dio.delete(url, queryParameters: params);
      return response;
    } catch (e) {
      if (e is DioException && e.response != null) {
        return e.response!;
      } else {
        return Future.error(e);
      }
    }
  }

  Future<Response> uploadFile(String url, String filePath, {String? token}) async {
    try {
      if (token != null) {
        _dio.options.headers['Authorization'] = 'Bearer $token';
      } else {
        _dio.options.headers.remove('Authorization');
      }

      FormData formData = FormData.fromMap({
        'file': await MultipartFile.fromFile(filePath, filename: filePath.split('/').last),
      });

      Response response = await _dio.post(url, data: formData);
      return response;
    } catch (e) {
      if (e is DioException && e.response != null) {
        return e.response!;
      } else {
        return Future.error(e);
      }
    }
  }

  Future<void> downloadFile(String url, String savePath, {String? token}) async {
    try {
      if (token != null) {
        _dio.options.headers['Authorization'] = 'Bearer $token';
      } else {
        _dio.options.headers.remove('Authorization');
      }

      await _dio.download(
        url,
        savePath,
        onReceiveProgress: (received, total) {
          if (total != -1) {
            print('${(received / total * 100).toStringAsFixed(0)}%');
          }
        },
      );
    } catch (e) {
      if (e is DioException && e.response != null) {
        print('Download failed with status code: ${e.response?.statusCode}');
      } else {
        return Future.error(e);
      }
    }
  }
  Future<Uint8List?> getImageBytesWithProxy({
    required String url,
    required String proxyHost,
    required String proxyPort,
    Map<String, String>? headers,
    bool skipBadCertificates = false,
  }) async {
    final dioForProxy = Dio();
    final adapter = dioForProxy.httpClientAdapter;
    if (adapter is IOHttpClientAdapter) {
      adapter.createHttpClient = () {
        final client = HttpClient();
        client.findProxy = (uri) {
          return "PROXY $proxyHost:$proxyPort;";
        };
        if (skipBadCertificates) {
          client.badCertificateCallback =
              (X509Certificate cert, String host, int port) => true;
          print('Warning: Skipping bad certificate checks for proxy request.');
        }
        return client;
      };
    } else {
      print('Error: Cannot configure proxy. Invalid HttpClientAdapter type: ${adapter.runtimeType}');
      return null;
    }
    try {
      final response = await dioForProxy.get<List<int>>(
        url,
        options: Options(
          responseType: ResponseType.bytes,
          headers: headers,
        ),
      );

      if (response.statusCode == 200 && response.data != null) {
        return Uint8List.fromList(response.data!);
      } else {
        print('Failed to get image with proxy: Status code ${response.statusCode}');
        return null;
      }
    } on DioException catch (e) {
      print('DioError getting image with proxy: $e');
      if (e.response != null) {
        print('Error Response Data: ${e.response?.data}');
      }
      return null;
    } catch (e) {
      print('Error getting image with proxy: $e');
      return null;
    }
  }
}
