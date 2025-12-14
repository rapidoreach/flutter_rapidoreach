## 1.0.8

* TODO: Describe initial release.

## 1.0.9

* Bug fixes

## 1.1.0

* Upgrade Android native SDK dependency to `com.rapidoreach:cbofferwallsdk:1.1.0` (minSdk 23, compileSdk 35)
* Vendor iOS SDK sources from `RapidoReach` `v1.0.7` into the plugin (avoids CocoaPods name collision on case-insensitive filesystems)
* Fix iOS -> Flutter event callbacks (`onReward`, `rapidoReachSurveyAvailable`, `onRewardCenterOpened`, `onRewardCenterClosed`)
* Ensure Android method calls always return a result (`result.success`)

## 2.0.1

* Improve integration safety: clearer `not_initialized` / `no_activity` errors, and guards to prevent native crashes.
* Make Dart listeners resilient to exceptions (user callbacks no longer crash the app).

## 2.0.0

* Require Dart `^3.8.0` and upgrade `flutter_lints` to `^6.0.0`
* Remove unused `flutter_pollfish` from the example app
