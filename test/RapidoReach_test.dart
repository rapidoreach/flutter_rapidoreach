// ignore_for_file: file_names

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:rapidoreach/RapidoReach.dart';

void main() {
  const MethodChannel channel = MethodChannel('rapidoreach');

  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    RapidoReach.instance.resetForTesting();
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, (MethodCall methodCall) async {
      switch (methodCall.method) {
        case 'init':
          return null;
        case 'getBaseUrl':
          return 'https://example.rapidoreach.test';
        case 'isSurveyAvailable':
          return 1;
        default:
          return null;
      }
    });
  });

  tearDown(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, null);
  });

  test('getBaseUrl returns string', () async {
    expect(
      await RapidoReach.instance.getBaseUrl(),
      'https://example.rapidoreach.test',
    );
  });

  test('isSurveyAvailable coerces truthy values', () async {
    await RapidoReach.instance.init(apiToken: 'token', userId: 'user');
    expect(await RapidoReach.instance.isSurveyAvailable(), isTrue);
  });

  test('methods requiring init throw StateError before init', () async {
    expect(
      () => RapidoReach.instance.showRewardCenter(),
      throwsA(isA<StateError>()),
    );
  });
}
