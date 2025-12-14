# rapidoreach (Flutter)

RapidoReach is a Flutter plugin for showing rewarded survey content (offerwall / placements / quick questions) using the RapidoReach native SDKs.

## Before you start

### Get an API key

Sign up for a developer account, create an app in the RapidoReach dashboard, and copy your API key.

### Requirements

- Flutter: `>= 3.0.0`
- Dart: `^3.8.0`
- Android: minSdk `23`
- iOS: minimum deployment target `12.0`

Notes:
- iOS uses `AdSupport` / `CoreTelephony` / `WebKit`. If you use IDFA, implement App Tracking Transparency (ATT) in your app and include `NSUserTrackingUsageDescription` in your iOS `Info.plist`.
- This plugin vendors the native SDKs:
  - iOS sources are included in `ios/Classes/RapidoReach` (based on `RapidoReach` `v1.0.7`).
  - Android SDK is included as a bundled AAR under `android/maven` (based on `cbofferwallsdk` `1.1.0`).

## Installation

Add the dependency:

```yaml
dependencies:
  rapidoreach: ^2.0.1
```

Then run:

`flutter pub get`

## Quick start

### Import

```dart
import 'package:rapidoreach/RapidoReach.dart';
```

### Initialize (required)

Call `init` once (typically on app start, or after login) and `await` it.

```dart
await RapidoReach.instance.init(
  apiToken: 'YOUR_API_TOKEN',
  userId: 'YOUR_USER_ID',
);
```

### Show the reward center (offerwall)

```dart
await RapidoReach.instance.showRewardCenter();
```

## Error handling (recommended)

Most APIs return `Future`s and can throw.

- Dart-side integration mistakes throw `StateError` (e.g., calling a method before `init`).
- Native failures typically throw `PlatformException` with a `code` and `message`.

Common error codes:
- `not_initialized`: call and await `init` first
- `no_activity` (Android): call from a foreground Activity (don’t call from a background isolate)
- `no_presenter` (iOS): no active `UIViewController` available to present UI

Example:

```dart
try {
  await RapidoReach.instance.showRewardCenter();
} catch (e) {
  // show a toast/snackbar in debug builds
  // print('$e');
}
```

## Events (rewards, lifecycle, survey availability, errors)

### Reward callback

You should use server-to-server callbacks for production reward attribution whenever possible.
If you need a client-side signal, listen for `onReward`:

```dart
RapidoReach.instance.setOnRewardListener((quantity) {
  // quantity is your converted virtual currency amount
  // Update UI or enqueue a backend verification call
});
```

### Reward center open/close

```dart
RapidoReach.instance.setRewardCenterOpened(() {
  // UI opened
});
RapidoReach.instance.setRewardCenterClosed(() {
  // UI closed
});
```

### Survey availability

```dart
RapidoReach.instance.setSurveyAvaiableListener((available) {
  // available is typically 1/0
});
```

### Error events (optional)

```dart
RapidoReach.instance.setOnErrorListener((message) {
  // Native errors can be forwarded here (in addition to thrown exceptions).
});
```

## Customization (navigation bar)

Call these after `init` (or set them before init; the SDK will apply when possible):

```dart
await RapidoReach.instance.setNavBarText(text: 'Rewards');
await RapidoReach.instance.setNavBarColor(color: '#211548');
await RapidoReach.instance.setNavBarTextColor(textColor: '#FFFFFF');
```

## Placement-based flows (recommended)

If you use multiple placements or want a guided UX, query placement state and show a specific survey:

```dart
final tag = 'default';
final canShow = await RapidoReach.instance.canShowContent(tag: tag);
if (!canShow) return;

final surveys = await RapidoReach.instance.listSurveys(tag: tag);
final firstSurveyId = surveys.isNotEmpty ? surveys.first['surveyIdentifier']?.toString() : null;
if (firstSurveyId == null || firstSurveyId.isEmpty) return;

await RapidoReach.instance.showSurvey(
  tag: tag,
  surveyId: firstSurveyId,
  customParams: {'source': 'home_screen'},
);
```

Placement helpers:
- `getPlacementDetails(tag)`
- `listSurveys(tag)`
- `hasSurveys(tag)`
- `canShowContent(tag)`
- `canShowSurvey(tag, surveyId)`
- `showSurvey(tag, surveyId, customParams?)`

## Quick Questions

```dart
final tag = 'default';
final payload = await RapidoReach.instance.fetchQuickQuestions(tag: tag);
final hasQuestions = await RapidoReach.instance.hasQuickQuestions(tag: tag);

if (hasQuestions) {
  await RapidoReach.instance.answerQuickQuestion(
    tag: tag,
    questionId: 'QUESTION_ID',
    answer: 'yes',
  );
}
```

## User attributes

Send attributes to improve targeting/eligibility (only send values you have consent for):

```dart
await RapidoReach.instance.sendUserAttributes(
  attributes: {'country': 'US', 'premium': true},
  clearPrevious: false,
);
```

## Backends / environments

If you use a staging/regional backend, configure it via:

```dart
await RapidoReach.instance.updateBackend(
  baseURL: 'https://your-backend.example',
  rewardHashSalt: null,
);
```

## Network logging (debug)

Enable network logs (helpful during QA) and subscribe:

```dart
RapidoReach.instance.setNetworkLogListener((payload) {
  // payload: { name, method, url?, requestBody?, responseBody?, error?, timestampMs }
  // print(payload);
});

await RapidoReach.instance.enableNetworkLogging(enabled: true);
```

You can also read the configured base URL:

```dart
final baseUrl = await RapidoReach.instance.getBaseUrl();
```

## Android multidex (only if you hit dex limits)

If you hit dex method count issues, enable multidex in your app:

- In `android/app/build.gradle`:

```gradle
android {
  defaultConfig {
    multiDexEnabled true
  }
}

dependencies {
  implementation "androidx.multidex:multidex:2.0.1"
}
```

## Example app

This repo includes a full example app that demonstrates:
- init + user id updates
- reward center
- placement APIs + survey listing/showing
- user attributes
- quick questions
- network logging

Run it locally:

`cd example && flutter run`

## Publishing to pub.dev (CI)

This repo includes a GitHub Actions workflow at `.github/workflows/pubdev-publish.yml` that builds/tests the plugin + example and publishes to pub.dev on tags like `v2.0.1`.
