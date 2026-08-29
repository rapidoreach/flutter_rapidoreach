## 2.0.0

* Add the typed RapidReach v2 session, offer, reward-status, presentation, and
  event APIs.
* Consume exact-version native Android and iOS SDK dependencies instead of
  duplicating native business logic in the Flutter package.
* Keep reward amounts and transaction state server-authoritative; the client
  SDK no longer signs or computes rewards.

## 1.0.9

* TODO: Describe initial release.

## 1.1.2

* Bundle the native SDKs so end users don’t need any CocoaPods/Maven credentials anymore:
  * Android: pull `com.rapidoreach:cbofferwallsdk:1.1.0` from Maven Central.
  * iOS: include the RapidoReach source files (`RapidoReach` v1.0.9) inside `ios/Classes/RapidoReach`.
* Harden the Dart and platform APIs with clear `StateError`/`PlatformException` codes (`not_initialized`, `no_activity`, `no_presenter`, etc.) and keep native listener callbacks safe from user crashes.
* Upgrade the example app to mirror the React Native feature set (placements, quick questions, logs, etc.) and document the protected APIs.

## 1.0.9

* Bug fixes

## 1.0.9

* TODO: Describe initial release.
