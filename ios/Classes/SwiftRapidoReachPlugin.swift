import Flutter
import Foundation
import SafariServices
import UIKit

@objc(SwiftRapidoReachPlugin)
public class SwiftRapidoReachPlugin: NSObject, FlutterPlugin {
  private var channel: FlutterMethodChannel?
  private var surveyAvailability: Bool = false
  private var configuredApiKey: String?
  private var configuredUserId: String?
  private var isInitialized: Bool = false
  private var networkLoggingEnabled: Bool = false
  private var previousLoggerSink: ((RapidoReachLogLevel, String) -> Void)?
  private var previousLoggerLevel: RapidoReachLogLevel?
  private var navBarText: String?
  private var navBarColor: String?
  private var navBarTextColor: String?

  public static func register(with registrar: FlutterPluginRegistrar) {
    let channel = FlutterMethodChannel(name: "rapidoreach", binaryMessenger: registrar.messenger())
    let instance = SwiftRapidoReachPlugin()
    instance.channel = channel
    registrar.addMethodCallDelegate(instance, channel: channel)
  }

  public func handle(_ call: FlutterMethodCall, result: @escaping FlutterResult) {
    switch call.method {
    case "init":
      guard let args = call.arguments as? [String: Any],
            let apiKey = args["api_token"] as? String,
            !apiKey.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty,
            let userId = args["user_id"] as? String,
            !userId.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
        result(FlutterError(code: "invalid_args", message: "api_token and user_id are required", details: nil))
        return
      }

      if isInitialized {
        if let configuredApiKey, configuredApiKey != apiKey {
          result(FlutterError(code: "already_initialized", message: "RapidoReach is already initialized with a different api_token. Restart the app to reinitialize.", details: nil))
          return
        }
        if configuredUserId != userId {
          configuredUserId = userId
          RapidoReach.shared.setUserIdentifier(userId)
        }
        result(nil)
        return
      }

      configuredApiKey = apiKey
      configuredUserId = userId

      RapidoReach.shared.setRewardCallback { [weak self] (reward: Int) in
        self?.sendEvent("onReward", arguments: reward)
      }
      RapidoReach.shared.setsurveysAvailableCallback { [weak self] (available: Bool) in
        self?.surveyAvailability = available
        let value = available ? 1 : 0
        self?.sendEvent("rapidoReachSurveyAvailable", arguments: value)
        self?.sendEvent("rapidoreachSurveyAvailable", arguments: value)
      }
      RapidoReach.shared.setrewardCenterOpenedCallback { [weak self] in
        self?.sendEvent("onRewardCenterOpened", arguments: 0)
      }
      RapidoReach.shared.setrewardCenterClosedCallback { [weak self] in
        self?.sendEvent("onRewardCenterClosed", arguments: 0)
      }

      RapidoReach.shared.configure(apiKey: apiKey, user: userId)
      if let navBarText { RapidoReach.shared.setNavigationBarText(for: navBarText) }
      if let navBarColor { RapidoReach.shared.setNavigationBarColor(for: navBarColor) }
      if let navBarTextColor { RapidoReach.shared.setNavigationBarTextColor(for: navBarTextColor) }
      RapidoReach.shared.fetchAppUserID()
      isInitialized = true
      result(nil)

    case "show":
      guard requireInitialized(result, method: "show") else { return }
      DispatchQueue.main.async {
        RapidoReach.shared.presentSurvey()
        result(nil)
      }

    case "showRewardCenter":
      guard requireInitialized(result, method: "showRewardCenter") else { return }
      DispatchQueue.main.async {
        RapidoReach.shared.presentSurvey()
        result(nil)
      }

    case "setUserIdentifier":
      guard let args = call.arguments as? [String: Any],
            let userId = args["user_id"] as? String,
            !userId.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
        result(FlutterError(code: "invalid_args", message: "user_id is required", details: nil))
        return
      }
      configuredUserId = userId
      guard requireInitialized(result, method: "setUserIdentifier") else { return }
      RapidoReach.shared.setUserIdentifier(userId)
      result(nil)

    case "setNavBarText":
      guard let args = call.arguments as? [String: Any] else {
        result(FlutterError(code: "invalid_args", message: "arguments are required", details: nil))
        return
      }
      let text = args["text"] as? String
      navBarText = text
      if isInitialized, let text {
        RapidoReach.shared.setNavigationBarText(for: text)
      }
      result(nil)

    case "setNavBarColor":
      guard let args = call.arguments as? [String: Any] else {
        result(FlutterError(code: "invalid_args", message: "arguments are required", details: nil))
        return
      }
      let color = args["color"] as? String
      navBarColor = color
      if isInitialized, let color {
        RapidoReach.shared.setNavigationBarColor(for: color)
      }
      result(nil)

    case "setNavBarTextColor":
      guard let args = call.arguments as? [String: Any] else {
        result(FlutterError(code: "invalid_args", message: "arguments are required", details: nil))
        return
      }
      let textColor = args["text_color"] as? String
      navBarTextColor = textColor
      if isInitialized, let textColor {
        RapidoReach.shared.setNavigationBarTextColor(for: textColor)
      }
      result(nil)

    case "enableNetworkLogging":
      guard let args = call.arguments as? [String: Any],
            let enabled = args["enabled"] as? Bool else {
        result(FlutterError(code: "invalid_args", message: "enabled is required", details: nil))
        return
      }
      enableNetworkLogging(enabled)
      result(nil)

    case "getBaseUrl":
      result(RapidoReachConfiguration.shared.baseURL.absoluteString)

    case "updateBackend":
      guard let args = call.arguments as? [String: Any],
            let baseURL = args["baseURL"] as? String,
            let url = URL(string: baseURL) else {
        result(FlutterError(code: "invalid_args", message: "baseURL is required", details: nil))
        return
      }
      RapidoReach.shared.updateBackend(baseURL: url, rewardHashSalt: (args["rewardHashSalt"] as? String))
      emitNetworkLog(name: "updateBackend", method: "CONFIG", url: baseURL)
      result(nil)

    case "isSurveyAvailable":
      guard requireInitialized(result, method: "isSurveyAvailable") else { return }
      result(surveyAvailability)

    case "sendUserAttributes":
      guard requireInitialized(result, method: "sendUserAttributes") else { return }
      guard let args = call.arguments as? [String: Any],
            let attributes = args["attributes"] as? [String: Any] else {
        result(FlutterError(code: "invalid_args", message: "attributes is required", details: nil))
        return
      }
      let clearPrevious = args["clear_previous"] as? Bool ?? false
      let url = buildUrl(path: "/api/sdk/v2/user_attributes")
      var requestPayload = authBodyFields()
      requestPayload["attributes"] = attributes
      requestPayload["clear_previous"] = clearPrevious
      RapidoReach.shared.sendUserAttributes(attributes, clearPrevious: clearPrevious) { [weak self] error in
        if let error = error {
          self?.emitNetworkLog(
            name: "sendUserAttributes",
            method: "POST",
            url: url,
            requestBody: requestPayload,
            error: error
          )
          result(FlutterError(code: "send_user_attributes_error", message: error.localizedDescription, details: nil))
        } else {
          self?.emitNetworkLog(
            name: "sendUserAttributes",
            method: "POST",
            url: url,
            requestBody: requestPayload,
            responseBody: ["status": "success"]
          )
          result(nil)
        }
      }

    case "getPlacementDetails":
      guard requireInitialized(result, method: "getPlacementDetails") else { return }
      guard let args = call.arguments as? [String: Any],
            let tag = args["tag"] as? String else {
        result(FlutterError(code: "invalid_args", message: "tag is required", details: nil))
        return
      }
      let url = buildUrl(path: "/api/sdk/v2/placements/\(tag)/details", queryItems: authQueryItems())
      RapidoReach.shared.getPlacementDetails(tag: tag) { [weak self] sdkResult in
        switch sdkResult {
        case .success(let payload):
          self?.emitNetworkLog(name: "getPlacementDetails", method: "GET", url: url, responseBody: payload)
          result(payload)
        case .failure(let error):
          self?.emitNetworkLog(name: "getPlacementDetails", method: "GET", url: url, error: error)
          result(FlutterError(code: "placement_details_error", message: error.localizedDescription, details: nil))
        }
      }

    case "listSurveys":
      guard requireInitialized(result, method: "listSurveys") else { return }
      guard let args = call.arguments as? [String: Any],
            let tag = args["tag"] as? String else {
        result(FlutterError(code: "invalid_args", message: "tag is required", details: nil))
        return
      }
      let url = buildUrl(path: "/api/sdk/v2/placements/\(tag)/surveys", queryItems: authQueryItems())
      RapidoReach.shared.listSurveys(tag: tag) { [weak self] sdkResult in
        switch sdkResult {
        case .success(let list):
          self?.emitNetworkLog(name: "listSurveys", method: "GET", url: url, responseBody: list)
          result(list)
        case .failure(let error):
          self?.emitNetworkLog(name: "listSurveys", method: "GET", url: url, error: error)
          result(FlutterError(code: "list_surveys_error", message: error.localizedDescription, details: nil))
        }
      }

    case "hasSurveys":
      guard requireInitialized(result, method: "hasSurveys") else { return }
      guard let args = call.arguments as? [String: Any],
            let tag = args["tag"] as? String else {
        result(FlutterError(code: "invalid_args", message: "tag is required", details: nil))
        return
      }
      let url = buildUrl(path: "/api/sdk/v2/placements/\(tag)/surveys", queryItems: authQueryItems())
      RapidoReach.shared.hasSurveys(tag: tag) { [weak self] sdkResult in
        switch sdkResult {
        case .success(let available):
          self?.emitNetworkLog(name: "hasSurveys", method: "GET", url: url, responseBody: ["hasSurveys": available])
          result(available)
        case .failure(let error):
          self?.emitNetworkLog(name: "hasSurveys", method: "GET", url: url, error: error)
          result(FlutterError(code: "has_surveys_error", message: error.localizedDescription, details: nil))
        }
      }

    case "canShowContent":
      guard requireInitialized(result, method: "canShowContent") else { return }
      guard let args = call.arguments as? [String: Any],
            let tag = args["tag"] as? String else {
        result(FlutterError(code: "invalid_args", message: "tag is required", details: nil))
        return
      }
      let url = buildUrl(path: "/api/sdk/v2/placements/\(tag)/can_show", queryItems: authQueryItems())
      RapidoReach.shared.canShowContent(tag: tag) { [weak self] sdkResult in
        switch sdkResult {
        case .success(let canShow):
          self?.emitNetworkLog(name: "canShowContent", method: "GET", url: url, responseBody: ["canShow": canShow])
          result(canShow)
        case .failure(let error):
          self?.emitNetworkLog(name: "canShowContent", method: "GET", url: url, error: error)
          result(FlutterError(code: "can_show_content_error", message: error.localizedDescription, details: nil))
        }
      }

    case "canShowSurvey":
      guard requireInitialized(result, method: "canShowSurvey") else { return }
      guard let args = call.arguments as? [String: Any],
            let tag = args["tag"] as? String,
            let surveyId = args["surveyId"] as? String else {
        result(FlutterError(code: "invalid_args", message: "tag and surveyId are required", details: nil))
        return
      }
      let url = buildUrl(path: "/api/sdk/v2/placements/\(tag)/surveys/\(surveyId)/can_show", queryItems: authQueryItems())
      RapidoReach.shared.canShowSurvey(surveyId: surveyId, tag: tag) { [weak self] sdkResult in
        switch sdkResult {
        case .success(let canShow):
          self?.emitNetworkLog(name: "canShowSurvey", method: "GET", url: url, responseBody: ["canShow": canShow])
          result(canShow)
        case .failure(let error):
          self?.emitNetworkLog(name: "canShowSurvey", method: "GET", url: url, error: error)
          result(FlutterError(code: "can_show_survey_error", message: error.localizedDescription, details: nil))
        }
      }

    case "showSurvey":
      guard requireInitialized(result, method: "showSurvey") else { return }
      guard let args = call.arguments as? [String: Any],
            let tag = args["tag"] as? String,
            let surveyId = args["surveyId"] as? String else {
        result(FlutterError(code: "invalid_args", message: "tag and surveyId are required", details: nil))
        return
      }
      let customParams = args["customParams"] as? [String: Any]
      let requestUrl = buildUrl(path: "/api/sdk/v2/placements/\(tag)/surveys/\(surveyId)/show")
      var requestPayload = authBodyFields()
      if let customParams { requestPayload["custom_params"] = customParams }
      RapidoReach.shared.showSurvey(surveyId: surveyId, tag: tag, customParameters: customParams) { [weak self] sdkResult in
        switch sdkResult {
        case .success(let url):
          self?.emitNetworkLog(
            name: "showSurvey",
            method: "POST",
            url: requestUrl,
            requestBody: requestPayload,
            responseBody: ["surveyEntryUrl": url.absoluteString]
          )
          guard let presenter = self?.topMostController() else {
            result(FlutterError(code: "no_presenter", message: "Unable to present survey UI because no active UIViewController was found.", details: nil))
            return
          }
          DispatchQueue.main.async {
            let controller = SFSafariViewController(url: url)
            presenter.present(controller, animated: true) {
              result(nil)
            }
          }
        case .failure(let error):
          self?.emitNetworkLog(name: "showSurvey", method: "POST", url: requestUrl, requestBody: requestPayload, error: error)
          result(FlutterError(code: "show_survey_error", message: error.localizedDescription, details: nil))
        }
      }

    case "fetchQuickQuestions":
      guard requireInitialized(result, method: "fetchQuickQuestions") else { return }
      guard let args = call.arguments as? [String: Any],
            let tag = args["tag"] as? String else {
        result(FlutterError(code: "invalid_args", message: "tag is required", details: nil))
        return
      }
      let url = buildUrl(path: "/api/sdk/v2/placements/\(tag)/quick_questions", queryItems: authQueryItems())
      RapidoReach.shared.fetchQuickQuestions(tag: tag) { [weak self] sdkResult in
        switch sdkResult {
        case .success(let payload):
          self?.emitNetworkLog(name: "fetchQuickQuestions", method: "GET", url: url, responseBody: payload)
          result(payload)
        case .failure(let error):
          self?.emitNetworkLog(name: "fetchQuickQuestions", method: "GET", url: url, error: error)
          result(FlutterError(code: "fetch_quick_questions_error", message: error.localizedDescription, details: nil))
        }
      }

    case "hasQuickQuestions":
      guard requireInitialized(result, method: "hasQuickQuestions") else { return }
      guard let args = call.arguments as? [String: Any],
            let tag = args["tag"] as? String else {
        result(FlutterError(code: "invalid_args", message: "tag is required", details: nil))
        return
      }
      let url = buildUrl(path: "/api/sdk/v2/placements/\(tag)/quick_questions", queryItems: authQueryItems())
      RapidoReach.shared.hasQuickQuestions(tag: tag) { [weak self] sdkResult in
        switch sdkResult {
        case .success(let hasQuestions):
          self?.emitNetworkLog(name: "hasQuickQuestions", method: "GET", url: url, responseBody: ["hasQuickQuestions": hasQuestions])
          result(hasQuestions)
        case .failure(let error):
          self?.emitNetworkLog(name: "hasQuickQuestions", method: "GET", url: url, error: error)
          result(FlutterError(code: "has_quick_questions_error", message: error.localizedDescription, details: nil))
        }
      }

    case "answerQuickQuestion":
      guard requireInitialized(result, method: "answerQuickQuestion") else { return }
      guard let args = call.arguments as? [String: Any],
            let tag = args["tag"] as? String,
            let questionId = args["questionId"] as? String,
            let answer = args["answer"] else {
        result(FlutterError(code: "invalid_args", message: "tag, questionId, and answer are required", details: nil))
        return
      }
      let url = buildUrl(path: "/api/sdk/v2/placements/\(tag)/quick_questions/\(questionId)/answer")
      var requestPayload = authBodyFields()
      requestPayload["answer"] = answer
      RapidoReach.shared.answerQuickQuestion(id: questionId, placement: tag, answer: answer) { [weak self] sdkResult in
        switch sdkResult {
        case .success(let payload):
          self?.emitNetworkLog(name: "answerQuickQuestion", method: "POST", url: url, requestBody: requestPayload, responseBody: payload)
          result(payload)
        case .failure(let error):
          self?.emitNetworkLog(name: "answerQuickQuestion", method: "POST", url: url, requestBody: requestPayload, error: error)
          result(FlutterError(code: "answer_quick_question_error", message: error.localizedDescription, details: nil))
        }
      }

    default:
      result(FlutterMethodNotImplemented)
    }
  }

  private func requireInitialized(_ result: FlutterResult, method: String) -> Bool {
    if isInitialized { return true }
    result(
      FlutterError(
        code: "not_initialized",
        message: "RapidoReach not initialized. Call RapidoReach.instance.init(apiToken: ..., userId: ...) and await it before calling `\(method)`.",
        details: ["method": method]
      )
    )
    return false
  }

  private func enableNetworkLogging(_ enabled: Bool) {
    if enabled == networkLoggingEnabled {
      return
    }

    networkLoggingEnabled = enabled

    if enabled {
      previousLoggerSink = RapidoReachLogger.shared.sink
      previousLoggerLevel = RapidoReachLogger.shared.level
      RapidoReachLogger.shared.level = .debug
      RapidoReachLogger.shared.sink = { [weak self] level, line in
        self?.previousLoggerSink?(level, line)
        self?.emitNetworkLog(
          name: "RapidoReachLogger",
          method: "LOG",
          url: nil,
          requestBody: line
        )
      }
    } else {
      RapidoReachLogger.shared.sink = previousLoggerSink
      if let previousLoggerLevel {
        RapidoReachLogger.shared.level = previousLoggerLevel
      }
      previousLoggerSink = nil
      previousLoggerLevel = nil
    }
  }

  private func rootViewControllerFromActiveScene() -> UIViewController? {
    if #available(iOS 13.0, *) {
      return UIApplication.shared.connectedScenes
        .compactMap { $0 as? UIWindowScene }
        .flatMap { $0.windows }
        .first { $0.isKeyWindow }?
        .rootViewController
    }
    return UIApplication.shared.keyWindow?.rootViewController
  }

  private func topMostController(root: UIViewController? = nil) -> UIViewController? {
    let rootController = root ?? rootViewControllerFromActiveScene()
    if let nav = rootController as? UINavigationController {
      return topMostController(root: nav.visibleViewController)
    }
    if let tab = rootController as? UITabBarController {
      return topMostController(root: tab.selectedViewController)
    }
    if let presented = rootController?.presentedViewController {
      return topMostController(root: presented)
    }
    return rootController
  }

  private func stringifyForLog(_ value: Any?) -> String? {
    guard let value else { return nil }
    if let string = value as? String { return string }
    if JSONSerialization.isValidJSONObject(value),
       let data = try? JSONSerialization.data(withJSONObject: value, options: [.prettyPrinted]),
       let text = String(data: data, encoding: .utf8) {
      return text
    }
    return String(describing: value)
  }

  private func authQueryItems() -> [URLQueryItem]? {
    var items: [URLQueryItem] = []
    if let configuredApiKey {
      items.append(URLQueryItem(name: "api_key", value: configuredApiKey))
    }
    if let configuredUserId {
      items.append(URLQueryItem(name: "sdk_user_id", value: configuredUserId))
    }
    return items.isEmpty ? nil : items
  }

  private func authBodyFields() -> [String: Any] {
    var fields: [String: Any] = [:]
    if let configuredApiKey {
      fields["api_key"] = configuredApiKey
    }
    if let configuredUserId {
      fields["sdk_user_id"] = configuredUserId
    }
    return fields
  }

  private func buildUrl(path: String, queryItems: [URLQueryItem]? = nil) -> String? {
    guard var components = URLComponents(
      url: RapidoReachConfiguration.shared.baseURL,
      resolvingAgainstBaseURL: false
    ) else {
      return nil
    }
    components.path = path
    components.queryItems = queryItems
    return components.url?.absoluteString
  }

  private func emitNetworkLog(
    name: String,
    method: String,
    url: String?,
    requestBody: Any? = nil,
    responseBody: Any? = nil,
    error: Error? = nil
  ) {
    guard networkLoggingEnabled else { return }

    var payload: [String: Any] = [
      "name": name,
      "method": method,
      "timestampMs": Int(Date().timeIntervalSince1970 * 1000),
    ]
    if let url { payload["url"] = url }
    if let requestBody = stringifyForLog(requestBody) { payload["requestBody"] = requestBody }
    if let responseBody = stringifyForLog(responseBody) { payload["responseBody"] = responseBody }
    if let error { payload["error"] = error.localizedDescription }

    sendEvent("rapidoreachNetworkLog", arguments: payload)
  }

  private func sendEvent(_ method: String, arguments: Any?) {
    DispatchQueue.main.async { [weak self] in
      self?.channel?.invokeMethod(method, arguments: arguments)
    }
  }
}
