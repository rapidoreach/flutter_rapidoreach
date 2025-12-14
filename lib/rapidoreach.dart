// ignore_for_file: file_names

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

typedef OnRewardListener = void Function(int? quantity);
typedef SurveyAvailableListener = void Function(int? survey);
typedef RewardCenterOpenedListener = void Function();
typedef RewardCenterClosedListener = void Function();
typedef NetworkLogListener = void Function(Map<String, dynamic> payload);
typedef ErrorListener = void Function(String message);

class RapidoReach {
  static RapidoReach get instance => _instance;

  final MethodChannel _channel;
  bool _initialized = false;

  static final RapidoReach _instance = RapidoReach.private(
    const MethodChannel('rapidoreach'),
  );

  RapidoReach.private(MethodChannel channel) : _channel = channel {
    _channel.setMethodCallHandler(_platformCallHandler);
  }

  @visibleForTesting
  void resetForTesting() {
    _initialized = false;
  }

  static OnRewardListener? _onRewardListener;
  static SurveyAvailableListener? _surveyAvailableListener;
  static RewardCenterOpenedListener? _rewardCenterOpenedListener;
  static RewardCenterClosedListener? _rewardCenterClosedListener;
  static NetworkLogListener? _networkLogListener;
  static ErrorListener? _errorListener;

  Never _notInitialized(String method) {
    throw StateError(
      'RapidoReach not initialized. Call `RapidoReach.instance.init(apiToken: ..., userId: ...)` and await it before calling `$method`.',
    );
  }

  int? _coerceInt(dynamic value) {
    if (value == null) return null;
    if (value is int) return value;
    if (value is num) return value.toInt();
    if (value is bool) return value ? 1 : 0;
    final parsed = int.tryParse(value.toString());
    return parsed;
  }

  bool _coerceBool(dynamic value) {
    if (value == null) return false;
    if (value is bool) return value;
    if (value is num) return value != 0;
    final text = value.toString().toLowerCase();
    return text == 'true' || text == '1';
  }

  Future<void> init({String? apiToken, String? userId}) async {
    if (apiToken == null || apiToken.isEmpty) {
      throw ArgumentError.value(apiToken, 'apiToken', 'apiToken is required');
    }
    if (userId == null || userId.isEmpty) {
      throw ArgumentError.value(userId, 'userId', 'userId is required');
    }
    await _channel.invokeMethod(
        "init", <String, dynamic>{"api_token": apiToken, "user_id": userId});
    _initialized = true;
  }

  Future<void> show({String? placementID}) {
    if (!_initialized) _notInitialized('show');
    return _channel
        .invokeMethod("show", <String, dynamic>{"placementID": placementID});
  }

  Future<void> showRewardCenter() {
    if (!_initialized) _notInitialized('showRewardCenter');
    return _channel.invokeMethod("showRewardCenter");
  }

  Future<void> setNavBarText({String? text}) {
    return _channel
        .invokeMethod('setNavBarText', <String, dynamic>{'text': text});
  }

  Future<void> setNavBarColor({String? color}) {
    return _channel
        .invokeMethod('setNavBarColor', <String, dynamic>{'color': color});
  }

  Future<void> setNavBarTextColor({String? textColor}) {
    return _channel.invokeMethod(
        'setNavBarTextColor', <String, dynamic>{'text_color': textColor});
  }

  Future<void> setUserIdentifier({required String userId}) {
    if (!_initialized) _notInitialized('setUserIdentifier');
    return _channel
        .invokeMethod('setUserIdentifier', <String, dynamic>{'user_id': userId});
  }

  Future<void> enableNetworkLogging({required bool enabled}) {
    return _channel.invokeMethod(
        'enableNetworkLogging', <String, dynamic>{'enabled': enabled});
  }

  Future<String?> getBaseUrl() async {
    final res = await _channel.invokeMethod('getBaseUrl');
    return res?.toString();
  }

  Future<void> updateBackend({required String baseURL, String? rewardHashSalt}) {
    return _channel.invokeMethod('updateBackend', <String, dynamic>{
      'baseURL': baseURL,
      'rewardHashSalt': rewardHashSalt,
    });
  }

  Future<bool> isSurveyAvailable() async {
    if (!_initialized) _notInitialized('isSurveyAvailable');
    final res = await _channel.invokeMethod('isSurveyAvailable');
    return _coerceBool(res);
  }

  Future<void> sendUserAttributes(
      {required Map<String, dynamic> attributes, bool clearPrevious = false}) {
    if (!_initialized) _notInitialized('sendUserAttributes');
    return _channel.invokeMethod('sendUserAttributes', <String, dynamic>{
      'attributes': attributes,
      'clear_previous': clearPrevious,
    });
  }

  Future<Map<String, dynamic>> getPlacementDetails({required String tag}) async {
    if (!_initialized) _notInitialized('getPlacementDetails');
    final res = await _channel
        .invokeMethod('getPlacementDetails', <String, dynamic>{'tag': tag});
    if (res is Map) return Map<String, dynamic>.from(res);
    throw StateError(
        'Expected a Map response from getPlacementDetails, got ${res.runtimeType}.');
  }

  Future<List<dynamic>> listSurveys({required String tag}) async {
    if (!_initialized) _notInitialized('listSurveys');
    final res =
        await _channel.invokeMethod('listSurveys', <String, dynamic>{'tag': tag});
    return (res as List?) ?? <dynamic>[];
  }

  Future<bool> hasSurveys({required String tag}) async {
    if (!_initialized) _notInitialized('hasSurveys');
    final res =
        await _channel.invokeMethod('hasSurveys', <String, dynamic>{'tag': tag});
    return _coerceBool(res);
  }

  Future<bool> canShowContent({required String tag}) async {
    if (!_initialized) _notInitialized('canShowContent');
    final res = await _channel
        .invokeMethod('canShowContent', <String, dynamic>{'tag': tag});
    return _coerceBool(res);
  }

  Future<bool> canShowSurvey({required String tag, required String surveyId}) async {
    if (!_initialized) _notInitialized('canShowSurvey');
    final res = await _channel.invokeMethod('canShowSurvey',
        <String, dynamic>{'tag': tag, 'surveyId': surveyId});
    return _coerceBool(res);
  }

  Future<void> showSurvey(
      {required String tag,
      required String surveyId,
      Map<String, dynamic>? customParams}) {
    if (!_initialized) _notInitialized('showSurvey');
    return _channel.invokeMethod('showSurvey', <String, dynamic>{
      'tag': tag,
      'surveyId': surveyId,
      'customParams': customParams ?? <String, dynamic>{},
    });
  }

  Future<Map<String, dynamic>> fetchQuickQuestions({required String tag}) async {
    if (!_initialized) _notInitialized('fetchQuickQuestions');
    final res = await _channel
        .invokeMethod('fetchQuickQuestions', <String, dynamic>{'tag': tag});
    if (res is Map) return Map<String, dynamic>.from(res);
    throw StateError(
        'Expected a Map response from fetchQuickQuestions, got ${res.runtimeType}.');
  }

  Future<bool> hasQuickQuestions({required String tag}) async {
    if (!_initialized) _notInitialized('hasQuickQuestions');
    final res = await _channel
        .invokeMethod('hasQuickQuestions', <String, dynamic>{'tag': tag});
    return _coerceBool(res);
  }

  Future<Map<String, dynamic>> answerQuickQuestion(
      {required String tag,
      required String questionId,
      required dynamic answer}) async {
    if (!_initialized) _notInitialized('answerQuickQuestion');
    final res = await _channel.invokeMethod('answerQuickQuestion',
        <String, dynamic>{'tag': tag, 'questionId': questionId, 'answer': answer});
    if (res is Map) return Map<String, dynamic>.from(res);
    throw StateError(
        'Expected a Map response from answerQuickQuestion, got ${res.runtimeType}.');
  }

  Future _platformCallHandler(MethodCall call) async {
    void safe(String name, void Function() fn) {
      try {
        fn();
      } catch (e, st) {
        debugPrint('RapidoReach listener `$name` threw: $e\n$st');
      }
    }

    switch (call.method) {
      case "onReward":
        safe('onReward', () => _onRewardListener?.call(_coerceInt(call.arguments)));
        break;

      case "rapidoReachSurveyAvailable":
        safe('rapidoReachSurveyAvailable',
            () => _surveyAvailableListener?.call(_coerceInt(call.arguments)));
        break;

      case "rapidoreachSurveyAvailable":
        safe('rapidoreachSurveyAvailable',
            () => _surveyAvailableListener?.call(_coerceInt(call.arguments)));
        break;

      case "onRewardCenterOpened":
        safe('onRewardCenterOpened', () => _rewardCenterOpenedListener?.call());
        break;

      case "onRewardCenterClosed":
        safe('onRewardCenterClosed', () => _rewardCenterClosedListener?.call());
        break;

      case "rapidoreachNetworkLog":
        final payload = call.arguments;
        safe('rapidoreachNetworkLog', () {
          if (payload is Map) {
            _networkLogListener?.call(Map<String, dynamic>.from(payload));
          }
        });
        break;

      case "onError":
        safe('onError', () => _errorListener?.call(call.arguments?.toString() ?? ''));
        break;
      default:
        debugPrint('RapidoReach: unhandled native event `${call.method}`');
    }
  }

  void setOnRewardListener(OnRewardListener? onRewardListener) =>
      _onRewardListener = onRewardListener;

  void setSurveyAvaiableListener(
          SurveyAvailableListener? surveyAvailableListener) =>
      _surveyAvailableListener = surveyAvailableListener;

  void setRewardCenterOpened(
          RewardCenterOpenedListener? rewardCenterOpenedListener) =>
      _rewardCenterOpenedListener = rewardCenterOpenedListener;

  void setRewardCenterClosed(
          RewardCenterClosedListener? rewardCenterClosedListener) =>
      _rewardCenterClosedListener = rewardCenterClosedListener;

  void setNetworkLogListener(NetworkLogListener? listener) =>
      _networkLogListener = listener;

  void setOnErrorListener(ErrorListener? listener) => _errorListener = listener;
}
