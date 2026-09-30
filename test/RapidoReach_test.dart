// ignore_for_file: file_names

import 'dart:convert';
import 'dart:io';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:rapidoreach/rapidoreach.dart';

void main() {
  const MethodChannel channel = MethodChannel('rapidoreach');
  late Map<String, dynamic> sdkFixture;

  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() {
    sdkFixture = Map<String, dynamic>.from(jsonDecode(
      File('contracts/performance-marketing-v2/sdk-golden.json').readAsStringSync(),
    ) as Map);
  });

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
        case 'initializeV2':
          return sdkFixture['session'];
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

  test('v2 facade decodes the canonical session and sends no reward authority',
      () async {
    final sdk = RapidoReachV2(channel: channel);
    final session = await sdk.initialize(
      placementId: 'plc_sdk_android',
      externalUserId: 'sdk-user-001',
      environment: 'sandbox',
      consent: 'GRANTED',
    );

    expect(session.contractVersion, rapidoreachContractVersion);
    expect(session.capabilities.rewardedVideo, isFalse);
    expect(session.adSlots.single['adSlotId'], 'slot_sdk_offerwall');
    final requests = sdkFixture['sessionRequests'] as Map<String, dynamic>;
    for (final request in requests.values.cast<Map<String, dynamic>>()) {
      expect(request, isNot(contains('rewardAmount')));
      expect(request, isNot(contains('rewardCurrency')));
      expect(request, isNot(contains('callbackSecret')));
      expect(request, isNot(contains('providerToken')));
    }
  });

  test('rewarded video facade stays capability and ad-slot gated', () async {
    final enabled = Map<String, dynamic>.from(sdkFixture['session'] as Map);
    enabled['capabilities'] = <String, dynamic>{
      ...Map<String, dynamic>.from(enabled['capabilities'] as Map),
      'rewardedVideo': true,
    };
    enabled['hostedRewardedVideoUrl'] =
        'https://offers.example.test/rewarded-video/session#opaque';
    enabled['adSlots'] = <Map<String, dynamic>>[
      ...List<Map<String, dynamic>>.from(
          (enabled['adSlots'] as List).map((value) => Map<String, dynamic>.from(value as Map))),
      {'adSlotId': 'slot_video_1', 'name': 'Video', 'type': 'REWARDED_VIDEO', 'available': true},
    ];
    MethodCall? shown;
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, (call) async {
      if (call.method == 'initializeV2') return enabled;
      if (call.method == 'showRewardedVideoV2') shown = call;
      return null;
    });
    final sdk = RapidoReachV2(channel: channel);
    await sdk.initialize(placementId: 'plc', externalUserId: 'user');
    expect(sdk.isRewardedVideoAvailable('slot_video_1'), isTrue);
    expect(sdk.isRewardedVideoAvailable('slot_other'), isFalse);
    await sdk.showRewardedVideo('slot_video_1');
    expect(shown?.arguments, {'adSlotId': 'slot_video_1'});
  });
}
