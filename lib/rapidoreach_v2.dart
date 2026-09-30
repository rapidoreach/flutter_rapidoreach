import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

const rapidoreachContractVersion = '2.0.0';
const rapidoreachSdkVersion = '2.0.0';

@immutable
class RapidoreachCapabilities {
  const RapidoreachCapabilities({
    required this.offerwall,
    required this.offerApi,
    required this.rewardStatus,
    required this.surveywall,
    required this.rewardedVideo,
  });

  factory RapidoreachCapabilities.fromMap(Map<dynamic, dynamic> map) =>
      RapidoreachCapabilities(
        offerwall: map['offerwall'] == true,
        offerApi: map['offerApi'] == true,
        rewardStatus: map['rewardStatus'] == true,
        surveywall: map['surveywall'] == true,
        rewardedVideo: map['rewardedVideo'] == true,
      );

  final bool offerwall;
  final bool offerApi;
  final bool rewardStatus;
  final bool surveywall;
  final bool rewardedVideo;
}

@immutable
class RapidoreachSession {
  const RapidoreachSession({
    required this.sessionId,
    required this.expiresAt,
    required this.contractVersion,
    required this.minimumSdkVersion,
    required this.recommendedSdkVersion,
    required this.capabilities,
    required this.adSlots,
    this.hostedOfferwallUrl,
    this.hostedRewardedVideoUrl,
  });

  factory RapidoreachSession.fromMap(Map<dynamic, dynamic> map) {
    final version = map['contractVersion']?.toString() ?? '';
    if (version != rapidoreachContractVersion) {
      throw StateError('Unsupported RapidReach contract $version.');
    }
    return RapidoreachSession(
      sessionId: map['sessionId'].toString(),
      expiresAt: map['expiresAt'].toString(),
      contractVersion: version,
      minimumSdkVersion: map['minimumSdkVersion'].toString(),
      recommendedSdkVersion: map['recommendedSdkVersion'].toString(),
      capabilities: RapidoreachCapabilities.fromMap(
        Map<dynamic, dynamic>.from(map['capabilities'] as Map),
      ),
      hostedOfferwallUrl: map['hostedOfferwallUrl']?.toString(),
      hostedRewardedVideoUrl: map['hostedRewardedVideoUrl']?.toString(),
      adSlots: (map['adSlots'] as List? ?? const [])
          .map((value) => Map<String, dynamic>.from(value as Map))
          .toList(growable: false),
    );
  }

  final String sessionId;
  final String expiresAt;
  final String contractVersion;
  final String minimumSdkVersion;
  final String recommendedSdkVersion;
  final RapidoreachCapabilities capabilities;
  final String? hostedOfferwallUrl;
  final String? hostedRewardedVideoUrl;
  final List<Map<String, dynamic>> adSlots;
}

@immutable
class RapidoreachReward {
  const RapidoreachReward({
    required this.minorUnits,
    required this.currency,
    required this.decimals,
  });

  factory RapidoreachReward.fromMap(Map<dynamic, dynamic> map) =>
      RapidoreachReward(
        minorUnits: (map['minorUnits'] as num).toInt(),
        currency: map['currency'].toString(),
        decimals: (map['decimals'] as num).toInt(),
      );

  final int minorUnits;
  final String currency;
  final int decimals;
}

@immutable
class RapidoreachOffer {
  const RapidoreachOffer({
    required this.offerId,
    required this.title,
    required this.description,
    required this.totalReward,
    required this.progress,
  });

  factory RapidoreachOffer.fromMap(Map<dynamic, dynamic> map) =>
      RapidoreachOffer(
        offerId: map['offerId'].toString(),
        title: map['title'].toString(),
        description: map['description'].toString(),
        totalReward: RapidoreachReward.fromMap(
          Map<dynamic, dynamic>.from(map['totalReward'] as Map),
        ),
        progress: Map<String, dynamic>.from(map['progress'] as Map),
      );

  final String offerId;
  final String title;
  final String description;
  final RapidoreachReward totalReward;
  final Map<String, dynamic> progress;
}

typedef RapidoreachV2EventListener = void Function(RapidoreachV2Event event);

@immutable
class RapidoreachV2Event {
  const RapidoreachV2Event({
    required this.type,
    this.offerId,
    this.transactionId,
    this.status,
    this.reward,
    this.error,
  });

  factory RapidoreachV2Event.fromMap(Map<dynamic, dynamic> map) =>
      RapidoreachV2Event(
        type: map['type'].toString(),
        offerId: map['offerId']?.toString(),
        transactionId: map['transactionId']?.toString(),
        status: map['status']?.toString(),
        reward: map['reward'] is Map
            ? RapidoreachReward.fromMap(map['reward'] as Map)
            : null,
        error: map['error'] is Map
            ? Map<String, dynamic>.from(map['error'] as Map)
            : null,
      );

  final String type;
  final String? offerId;
  final String? transactionId;
  final String? status;
  final RapidoreachReward? reward;
  final Map<String, dynamic>? error;
}

class RapidoReachV2 {
  RapidoReachV2({MethodChannel? channel})
      : _channel = channel ?? const MethodChannel('rapidoreach');

  final MethodChannel _channel;
  RapidoreachSession? _session;
  static RapidoreachV2EventListener? _eventListener;

  RapidoreachSession? get session => _session;
  RapidoreachCapabilities? get capabilities => _session?.capabilities;

  void setEventListener(RapidoreachV2EventListener? listener) {
    _eventListener = listener;
  }

  static void dispatchPlatformEvent(Map<dynamic, dynamic> payload) {
    _eventListener?.call(RapidoreachV2Event.fromMap(payload));
  }

  Future<RapidoreachSession> initialize({
    required String placementId,
    required String externalUserId,
    String environment = 'production',
    String consent = 'UNKNOWN',
    String attStatus = 'NOT_APPLICABLE',
    String? adSlotId,
    String? language,
  }) async {
    if (placementId.trim().isEmpty || externalUserId.trim().isEmpty) {
      throw ArgumentError('placementId and externalUserId are required.');
    }
    final response = await _channel.invokeMapMethod<dynamic, dynamic>(
      'initializeV2',
      <String, dynamic>{
        'placementId': placementId,
        'externalUserId': externalUserId,
        'environment': environment,
        'consent': consent,
        'attStatus': attStatus,
        if (adSlotId != null) 'adSlotId': adSlotId,
        if (language != null) 'language': language,
      },
    );
    _session = RapidoreachSession.fromMap(response ?? const {});
    return _session!;
  }

  Future<RapidoreachSession> refreshSession() async {
    _requireSession();
    final response = await _channel.invokeMapMethod<dynamic, dynamic>('refreshSessionV2');
    _session = RapidoreachSession.fromMap(response ?? const {});
    return _session!;
  }

  Future<List<RapidoreachOffer>> getOffers(String adSlotId, {String? cursor}) async {
    final current = _requireSession();
    if (!current.capabilities.offerApi) {
      throw StateError('Offer API is disabled by server capability.');
    }
    final response = await _channel.invokeMapMethod<dynamic, dynamic>(
      'getOffersV2',
      {'adSlotId': adSlotId, if (cursor != null) 'cursor': cursor},
    );
    return (response?['items'] as List? ?? const [])
        .map((value) => RapidoreachOffer.fromMap(value as Map))
        .toList(growable: false);
  }

  Future<Map<String, dynamic>> getRewardStatus(String offerId) async {
    final current = _requireSession();
    if (!current.capabilities.rewardStatus) {
      throw StateError('Reward status is disabled by server capability.');
    }
    final response = await _channel.invokeMapMethod<dynamic, dynamic>(
      'getRewardStatusV2',
      {'offerId': offerId},
    );
    return Map<String, dynamic>.from(response ?? const {});
  }

  Future<void> showOfferwall() async {
    final current = _requireSession();
    if (!current.capabilities.offerwall) {
      throw StateError('Offerwall is disabled by server capability.');
    }
    await _channel.invokeMethod<void>('showOfferwallV2');
  }

  bool isRewardedVideoAvailable(String adSlotId) {
    final current = _session;
    if (current == null || !current.capabilities.rewardedVideo || current.hostedRewardedVideoUrl == null) {
      return false;
    }
    return current.adSlots.any((slot) =>
        slot['adSlotId'] == adSlotId && slot['type'] == 'REWARDED_VIDEO' && slot['available'] == true);
  }

  Future<void> showRewardedVideo(String adSlotId) async {
    _requireSession();
    if (!isRewardedVideoAvailable(adSlotId)) {
      throw StateError('Rewarded video is disabled or unavailable for this ad slot.');
    }
    await _channel.invokeMethod<void>('showRewardedVideoV2', {'adSlotId': adSlotId});
  }

  Future<void> revokeSession() async {
    _requireSession();
    await _channel.invokeMethod<void>('revokeSessionV2');
    _session = null;
  }

  void destroy() {
    _session = null;
    _channel.invokeMethod<void>('destroyV2');
  }

  RapidoreachSession _requireSession() {
    final current = _session;
    if (current == null) throw StateError('Initialize RapidReach v2 first.');
    return current;
  }
}
