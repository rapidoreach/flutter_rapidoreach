## 1.0.8

* TODO: Describe initial release.

## 1.1.0

* Bundle the native SDKs so end users don’t need any CocoaPods/Maven credentials anymore:
  * Android: ship `RapidoReach` as a local Maven artifact under `android/maven/com/rapidoreach/cbofferwallsdk/1.1.0`.
  * iOS: include the RapidoReach source files (`RapidoReach` v1.0.8) inside `ios/Classes/RapidoReach`.
* Harden the Dart and platform APIs with clear `StateError`/`PlatformException` codes (`not_initialized`, `no_activity`, `no_presenter`, etc.) and keep native listener callbacks safe from user crashes.
* Upgrade the example app to mirror the React Native feature set (placements, quick questions, logs, etc.) and document the protected APIs.

## 1.0.9

* Bug fixes

## 1.0.8

* TODO: Describe initial release.
