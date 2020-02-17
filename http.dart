import 'package:dio/dio.dart';
import 'package:walk_app/config/appConfig.dart';
import 'package:dio_cookie_manager/dio_cookie_manager.dart';
import 'package:cookie_jar/cookie_jar.dart';
import 'package:walk_app/apis/baseResponse.dart';

class HttpRequest {
  static Future request(String url, String method, [Map<String, dynamic> params]) async {
    Dio dio = new Dio();

    dio.options.baseUrl = AppConfig.BASE_URL;
    dio.options.connectTimeout = AppConfig.CONNECT_TIMEOUT;
    dio.options.receiveTimeout = AppConfig.RECEIVE_TIMEOUT;

    CookieJar cookieJar = new CookieJar();

    dio.interceptors.add(CookieManager(cookieJar));
    dio.interceptors.add(LogInterceptor(responseBody: AppConfig.IS_DEBUG));

    try {
      Response response;

      /// 设置请求公用参数
      Map<String, dynamic> _requestParams = _setCommonParams(url, params);

      if (method == "GET") {
        response = await dio.get(url, queryParameters: _requestParams);
      }

      if (method == "POST") {
        response = await dio.post(url, data: _requestParams);
      }

      return Future.value(response.data);
    } on DioError catch (ex) {
      print(ex);
      /// 处理系统错误, 接口404、响应超时、请求超时等错误
      return _systemError(ex);
    }
  }
  
  /// 统一响应结果为 如: {code: 1, data: {}, message: "请求成功" }
  static get(String url, {Map<String, dynamic> params}) async{
    var res = await request(url, "GET", params);
    var finalResult = _setCommonResponse(res);

    return Future.value(finalResult);
  }
  
  /// 统一响应结果为 如: {code: 1, data: {}, message: "请求成功" }
  static Future post(String url, {Map<String, dynamic> params}) async {
    var res = await request(url, "POST", params);
    var finalResult = _setCommonResponse(res);

    return Future.value(finalResult);
  }

  /// 设置全局统一请求头
  static Map _setCommonParams(String url, Map reqBody) {
    Map<String, dynamic> reqHeader = {
      "apiName": url,
      "platformId": AppConfig.PLATFORM_ID,
      "token": "70152e3bfce44b48836523e70ff9dc06",
      "clientType": 3,
      "callTime": DateTime.now().millisecondsSinceEpoch,
      "sign": "nosign",
      "apiVersion": "1"
    };

    Map<String, dynamic> params = {"header": reqHeader, "body": reqBody ?? {}};

    return params;
  }

  /// 设置全局统一响应体
  static Map<String, dynamic> _setCommonResponse(dynamic res) {
    /// 系统错误
    if (res['code'] == -999) return res;
    /// 解析jSON
    Map<String, dynamic> response = {'code': -998, 'data': null, 'message': ''};

    try {
      Map dataMap = new Map<String, dynamic>.from(res);
      var result = new BaseResponse.fromJson(dataMap);

      if (result.body != null) {
        response['code'] = result.body.code;
        response['data'] = result.body.data;
        response['message'] = result.body.message ?? "";
      }
    } catch (ex) {
      response['message'] = ex.toString();
    }

    return response;
  }

  static Future _systemError(DioError error) {
    String errorMsg = "";

    switch (error.type) {
      case DioErrorType.CANCEL:
        errorMsg = "请求已取消";
        break;
      case DioErrorType.CONNECT_TIMEOUT:
        errorMsg = "连接超时,请检查你的网络";
        break;
      case DioErrorType.SEND_TIMEOUT:
        errorMsg = "发送请求超时,请检查你的网络";
        break;
      case DioErrorType.RECEIVE_TIMEOUT:
        errorMsg = "服务器响应超时, 请稍后再试";
        break;
      case DioErrorType.RESPONSE:
        errorMsg = _httpErrorCodeToString(error);
        break;
      case DioErrorType.DEFAULT:
        errorMsg = "系统错误";
    }

    return Future.value({"code": -999, "message": errorMsg, "data": null});
  }

  static String _httpErrorCodeToString(DioError error) {
    String string = "";

    try {
      int statusCode = error.response.statusCode;
      String statusMessage = error.response.statusMessage;
      switch (statusCode) {
        case 404:
          string = "请求接口错误, 请检查接口地址是否正确";
          break;
        case 500:
        case 502:
        case 503:
        case 504:
          string = "服务器异常,请检查服务器配置";
          break;
        default:
          string = statusMessage ?? "系统错误";
      }
    } catch (ex) {
      string = "系统异常";
    }

    return string;
  }
}
