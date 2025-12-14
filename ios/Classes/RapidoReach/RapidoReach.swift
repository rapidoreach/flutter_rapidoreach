//
//  RapidoReach.swift
//  cbofferwallsdk
//
//  Created by Vikash Kumar on 25/07/2020.
//
import Foundation
import UIKit

/// `RapidoReach` is the main entry point for the SDK
@objc public class RapidoReach: NSObject {
    /// `RapidoReach.shared` is the instance to use
    @objc public static let shared = RapidoReach()

    #if DEBUG
    public static var debug = true
    #else
    public static var debug = false
    #endif

    static let bundleName = "RapidoReach"
    static let bundleID = "com.cbofferwallsdk.api"
    static let platformID = "ios"

    /// Set the delegate to get back the events
    public weak var delegate: RapidoReachDelegate?
    public weak var sdkDelegate: RapidoReachSDKDelegate?
    public weak var rewardDelegate: RapidoReachRewardDelegate?
    public weak var contentDelegate: RapidoReachContentDelegate?
    public weak var quickQuestionDelegate: RapidoReachQuickQuestionDelegate?
    public weak var surveysDelegate: RapidoReachSurveysDelegate?

    /// Reset profiler to get a new registered user
    public var resetProfiler = false
    public private(set) var isReady: Bool = false
    
    public var rewardCallbackFunc: (_ reward: Int) -> Void = { arg in }
    public var rewardCenterClosedCallbackFunc: () -> Void = {  }
    public var rewardCenterOpenedCallbackFunc: () -> Void = {  }
    public var surveysAvailableCallbackFunc: (_ available: Bool) -> Void = { arg in }
    
    var apiVersion: String? {
        return Bundle(for: RapidoReach.self).infoDictionary?["CFBundleShortVersionString"] as? String
    }

    private let queue: OperationQueue
    private let session: URLSession
    private let deviceInfoProvider: RapidoReachDeviceInfoProvider
    private var apiKey: String?
    private var userID: String?

    private var user: RapidoReachUser?
    private var navigationBarColor: UIColor = {
        if let branded = UIColor(rr_hex: "#211548") {
            return branded
        }
        if #available(iOS 13.0, *) {
            return UIColor.systemIndigo
        }
        return UIColor(red: 75.0/255.0, green: 0/255.0, blue: 130.0/255.0, alpha: 1)
    }()
    private var navigationBarTextColor: UIColor = .white
    private var navigationBarTitleText: String = "RapidoReach"

    /// Optionally pass a device information provider
    public init(deviceIDProvider: RapidoReachDeviceInfoProvider = RapidoReachDeviceInfo()) {
        self.queue = OperationQueue()
        self.queue.maxConcurrentOperationCount = 4
        self.queue.name = RapidoReach.bundleID
        self.session = URLSession(configuration: URLSessionConfiguration.default,
                                  delegate: nil,
                                  delegateQueue: queue)
        self.deviceInfoProvider = deviceIDProvider
        super.init()
    }

    /// Set up the sdk with an api key and app user id
    @objc public func configure(apiKey: String, user: String) {
        guard !apiKey.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty,
              !user.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            assertionFailure("RapidoReach.configure called with empty parameters")
            return
        }
        self.apiKey = apiKey
        self.userID = user
        self.isReady = false
    }

    /// Update the user identifier if it changes mid-session.
    @objc public func setUserIdentifier(_ user: String) {
        self.userID = user
        self.isReady = false
    }

    /// Point the SDK to a different backend (for staging or regional rollouts)
    @objc public func updateBackend(baseURL: URL, rewardHashSalt: String? = nil) {
        RapidoReachConfiguration.shared.update(baseURL: baseURL)
        if let salt = rewardHashSalt {
            RapidoReachConfiguration.shared.update(rewardHashSalt: salt)
        }
    }

    @objc public func setNavigationBarColor(_ hexColor: String) {
        if let color = UIColor(rr_hex: hexColor) {
            navigationBarColor = color
        }
    }

    @objc public func setNavigationBarColor(for hexColor: String) {
        setNavigationBarColor(hexColor)
    }

    @objc public func setNavigationBarTextColor(_ hexColor: String) {
        if let color = UIColor(rr_hex: hexColor) {
            navigationBarTextColor = color
        }
    }

    @objc public func setNavigationBarTextColor(for hexColor: String) {
        setNavigationBarTextColor(hexColor)
    }

    @objc public func setNavigationBarText(for text: String) {
        navigationBarTitleText = text
    }

    private var baseParams: [String: Any?] {
        guard let apiKey = apiKey else {
            assertionFailure("API Key is not set. Please see RapidoReach.shared.configure")
            return [:]
        }
        return [
            "gps_id": deviceInfoProvider.deviceID,
            "api_key": apiKey
        ]
    }

    private var additionalParams: [String: Any?] {
        let params: [String: Any?] = [
            "sdk_version": apiVersion,
            "carrier": deviceInfoProvider.carrier,
            "os_version": deviceInfoProvider.osVersion,
            "app_device": deviceInfoProvider.appDevice,
            "platform": RapidoReach.platformID,
            "language": deviceInfoProvider.locale,
        ]
        return params
    }

    private static func rootViewControllerFromActiveScene() -> UIViewController? {
        if #available(iOS 13.0, *) {
            // Walk the active scenes to find the current key window on iOS 13+
            return UIApplication.shared.connectedScenes
                .compactMap { $0 as? UIWindowScene }
                .flatMap { $0.windows }
                .first { $0.isKeyWindow }?
                .rootViewController
        } else {
            return UIApplication.shared.keyWindow?.rootViewController
        }
    }

    static func topViewController(root: UIViewController? = RapidoReach.rootViewControllerFromActiveScene()) -> UIViewController? {
        if let nav = root as? UINavigationController {
            return topViewController(root: nav.visibleViewController)
        }
        if let tab = root as? UITabBarController {
            return topViewController(root: tab.selectedViewController)
        }
        if let presented = root?.presentedViewController {
            return topViewController(root: presented)
        }
        return root
    }

    static func log(_ value: String) {
        if debug {
            RapidoReachLogger.shared.log(value, level: .debug)
        } else {
            RapidoReachLogger.shared.log(value, level: .info)
        }
    }

    private func encodeCustomParams(_ params: [String: Any]) -> String? {
        guard JSONSerialization.isValidJSONObject(params),
              let data = try? JSONSerialization.data(withJSONObject: params, options: []) else {
            return nil
        }
        return data.base64EncodedString()
    }

    private func clientSideRewardsEnabled() -> Bool {
        let mode = user?.callback_mode?.lowercased() ?? "server"
        return mode == "client"
    }
}

extension RapidoReach {

    @objc public func setRewardCallback(rewardCallback: @escaping ((_ reward: Int) -> Void)){
        self.rewardCallbackFunc = rewardCallback;
    }
    @objc public func setrewardCenterClosedCallback(rewardCallback: @escaping (() -> Void)){
        self.rewardCenterClosedCallbackFunc = rewardCallback;
    }
    @objc public func setrewardCenterOpenedCallback(rewardCallback: @escaping (() -> Void)){
        self.rewardCenterOpenedCallbackFunc = rewardCallback;
    }
    @objc public func setsurveysAvailableCallback(surveyAvailableCallback: @escaping ((_ available: Bool) -> Void)){
        self.surveysAvailableCallbackFunc = surveyAvailableCallback;
    }
    /// This is entry point of the sdk start by registering a user
    @objc public func fetchAppUserID() {
        guard let userID = user?.id ?? userID else {
            assertionFailure("App User ID is not set. Please see RapidoReach.shared.configure")
            return
        }
        fetchAppUserID(for: userID) { [weak self] user, error in
            if let user = user {
//                self?.delegate?.didGetAppUser(user)
                self?.fetchRewards(for: user.id)
                self?.isReady = true
                DispatchQueue.main.async {
                    self?.sdkDelegate?.onSDKReady()
                }
            } else if let error = error {
                DispatchQueue.main.async {
                    self?.delegate?.didGetError(.generic(error))
                    self?.sdkDelegate?.onSDKError(.generic(error))
                }
            } else {
                DispatchQueue.main.async {
                    self?.delegate?.didGetError(.unknown)
                    self?.sdkDelegate?.onSDKError(.unknown)
                }
            }
        }
    }

    func fetchAppUserID(for userID: String, _ completion: @escaping (RapidoReachUser?, Error?) -> Void) {
        var params = baseParams
        params.append(additionalParams)
        params["user_id"] = userID

        if resetProfiler { params["reset_profiler"] = true }

        guard let queryURL = RapidoReachAPI.appUserID.url(for: params) else { return }
        RapidoReach.log("fetchAppUserID: queryURL \(queryURL)")
        let task = session.dataTask(with: queryURL) { [weak self] data, response, error in
            guard let self = self else { return }
            RapidoReach.log("ROR: fetchAppUserID: response size \(data?.count ?? -1) error \(error?.localizedDescription ?? "")")
            guard let data = data else {
                DispatchQueue.main.async {
                    completion(nil, error)
                }
                return
            }
            do {
                let model = try JSONDecoder().decode(ReplyObject.self, from: data)
                if(model.ErrorCode == "SUCCESS"){
                    let fetchedUser = model.Data[0]
                    self.user = fetchedUser
                    DispatchQueue.main.async {
                        self.surveysAvailableCallbackFunc(fetchedUser.survey_available)
                        self.delegate?.didSurveyAvailable(fetchedUser.survey_available)
                        self.delegate?.didGetUser(fetchedUser)
                        completion(fetchedUser, nil)
                    }
                    return;
                }
                DispatchQueue.main.async {
                    completion(nil, RapidoReachError.ErrorList(model.Errors));
                }
            } catch {
                DispatchQueue.main.async {
                    completion(nil, error)
                }
            }
        }
        task.resume()
    }

    /// Fetch a user's rewards, uses the registerd user by default
    @objc public func fetchRewards(for userID: String? = nil) {
        guard let userID = userID ?? user?.id else {
            assertionFailure("App User ID is not available. Please see RapidoReach.shared.fetchAppUserID")
            return
        }
        guard clientSideRewardsEnabled() else {
            RapidoReach.log("fetchRewards: skipping in-app reward callbacks because app is configured for server-side callbacks")
            return
        }
        self.fetchRewards(for: userID) { [weak self] reward, error in
            if let reward = reward {
                self?.rewardCallbackFunc(Int(reward.total_rewards))
                self?.delegate?.didGetRewards(reward)
            } else if let error = error {
                self?.delegate?.didGetError(.generic(error))
            } else {
                self?.delegate?.didGetError(.unknown)
            }
        }
    }

    func fetchRewards(for user: String, _ completion: @escaping (RapidoReachReward?, Error?) -> Void) {
        guard let key = apiKey else {
            assertionFailure("API Key is not set. Please see RapidoReach.shared.configure")
            DispatchQueue.main.async {
                completion(nil, RapidoReachError.customerr("Missing API key"))
            }
            return
        }
        let params = ["api_key" : key]
        guard let url = RapidoReachUserAPI.rewards.url(for: user, params: params) else { return }
        let task = session.dataTask(with: url) { [weak self] data, response, error in
            guard let self = self else { return }
            RapidoReach.log("fetchRewards: response size \(data?.count ?? -1) error \(error?.localizedDescription ?? "")")
            guard let data = data else {
                DispatchQueue.main.async {
                    completion(nil, error)
                }
                return
            }
            do {
                let model = try JSONDecoder().decode(fetchRewardsReplyObject.self, from: data)
                if(model.ErrorCode == "SUCCESS"){
                    self.user?.rewards = model.Data[0];
                    DispatchQueue.main.async {
                        completion(model.Data[0], nil)
                        let payloads: [RapidoReachRewardPayload]
                        if let rich = model.Data[0].rewards {
                            payloads = rich.map {
                                RapidoReachRewardPayload(transactionIdentifier: $0.transactionIdentifier ?? model.Data[0].appuser_reward_ids,
                                                         placementIdentifier: $0.placementIdentifier,
                                                         placementTag: $0.placementTag,
                                                         currencyName: $0.currencyName,
                                                         rewardAmount: $0.rewardAmount,
                                                         saleMultiplier: $0.saleMultiplier)
                            }
                        } else {
                            payloads = [RapidoReachRewardPayload(transactionIdentifier: model.Data[0].appuser_reward_ids,
                                                                  placementIdentifier: nil,
                                                                  placementTag: nil,
                                                                  currencyName: nil,
                                                                  rewardAmount: Double(model.Data[0].total_rewards),
                                                                  saleMultiplier: nil)]
                        }
                        self.rewardDelegate?.onRewards(payloads)
                    }
                    return;
                }
                DispatchQueue.main.async {
                    completion(nil, RapidoReachError.ErrorList(model.Errors));
                }
            } catch {
                DispatchQueue.main.async {
                    completion(nil, error)
                }
            }
        }
        task.resume()
    }

    /// Present a survey screen to the user
    @objc public func presentSurvey(_ presenter: UIViewController? = nil, title: String = "", customParameters: [String: Any]? = nil, completion: (() -> Void)? = nil) {
        guard let userID = userID ?? user?.id else {
            RapidoReach.log("presentSurvey: missing user id, calling fetchAppUserID and failing gracefully")
            delegate?.didGetError(.customerr("User id missing. Call configure(apiKey:user:) first, then fetchAppUserID"))
            sdkDelegate?.onSDKError(.customerr("User id missing. Call configure(apiKey:user:) first, then fetchAppUserID"))
            fetchAppUserID()
            return
        }

        var params = baseParams
        params["user_id"] = userID
        if let customParameters = customParameters, let encoded = encodeCustomParams(customParameters) {
            params["custom_params"] = encoded
        }
        guard let url = RapidoReachAPI.iFrame.url(for: params) else { return }
        RapidoReach.log("presentSurvey URL: \(url)")
        let presenterVC = presenter ?? RapidoReach.topViewController()
        guard let viewController = presenterVC else {
            RapidoReach.log("presentSurvey: unable to resolve a presenter")
            delegate?.didGetError(.customerr("No active view controller to present from"))
            return
        }
        presentWebView(viewController, with: url, title: title, completion: completion)
    }

    /// Convenience alias that mirrors other offerwall SDK naming
    @objc public func presentOfferwall(from presenter: UIViewController? = nil, title: String = "", customParameters: [String: Any]? = nil, completion: (() -> Void)? = nil) {
        presentSurvey(presenter, title: title, customParameters: customParameters, completion: completion)
    }

    func presentWebView(_ presenter: UIViewController, with url: URL, title: String = "", completion: (() -> Void)? = nil) {
        DispatchQueue.main.async {
            let viewController = RapidoReachSurveyViewController()
            viewController.title = title
            viewController.url = url
            self.contentDelegate?.onContentShown(forPlacement: title)
            let navController = UINavigationController(rootViewController: viewController)
            navController.navigationBar.barTintColor = self.navigationBarColor
            navController.navigationBar.backgroundColor = self.navigationBarColor
            navController.navigationBar.tintColor = self.navigationBarTextColor
            navController.navigationBar.titleTextAttributes = [
                NSAttributedString.Key.foregroundColor: self.navigationBarTextColor
            ]
            viewController.title = title.isEmpty ? self.navigationBarTitleText : title
            presenter.present(navController,
                              animated: true,
                              completion: completion)
        }
    }

    /// Report that a user's abandoned the survey
    @objc public func reportAbandon(for userID: String? = nil) {
        guard let userID = userID ?? user?.id else {
            assertionFailure("App User ID is not available. Please see RapidoReach.shared.fetchAppUserID")
            return
        }

        reportAbandon(for: userID) { [weak self] success, error in
            if let error = error {
                self?.delegate?.didGetError(.generic(error))
            } else if !success {
                self?.delegate?.didGetError(.unknown)
            }
        }
    }

    func reportAbandon(for user: String, _ completion: @escaping (Bool, Error?) -> Void) {
        let params = ["id": user]
        guard let url = RapidoReachAPI.abandoned.url(for: params) else { return }
        let task = session.dataTask(with: url) { data, response, error in
            RapidoReach.log("reportAbandon: response size \(data?.count ?? -1) error \(error?.localizedDescription ?? "")")
            guard let _ = data else {
                DispatchQueue.main.async {
                    completion(false, error)
                }
                return
            }
            DispatchQueue.main.async {
                completion(true, nil)
            }
        }
        task.resume()
    }

    /// Send/merge user attributes to backend for targeting.
    @objc public func sendUserAttributes(_ attributes: [String: Any], clearPrevious: Bool = false, completion: ((Error?) -> Void)? = nil) {
        guard let apiKey = apiKey else {
            completion?(RapidoReachError.customerr("API Key is not set. Please see RapidoReach.shared.configure"))
            return
        }
        guard let sdkUserId = user?.id ?? userID else {
            completion?(RapidoReachError.customerr("User ID is not available. Call configure/api registration first."))
            return
        }
        if attributes.keys.contains(where: { $0.lowercased().hasPrefix("tapresearch_") }) {
            completion?(RapidoReachError.coded(code: .invalidParams, message: "Attributes prefixed with tapresearch_ are reserved."))
            return
        }

        guard var components = URLComponents(url: RapidoReachConfiguration.shared.baseURL, resolvingAgainstBaseURL: false) else {
            completion?(RapidoReachError.customerr("Invalid base URL"))
            return
        }
        components.path = "/api/sdk/v2/user_attributes"
        guard let url = components.url else {
            completion?(RapidoReachError.customerr("Invalid attributes URL"))
            return
        }

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        let payload: [String: Any] = [
            "api_key": apiKey,
            "sdk_user_id": sdkUserId,
            "attributes": attributes,
            "clear_previous": clearPrevious
        ]
        request.httpBody = try? JSONSerialization.data(withJSONObject: payload, options: [])

        let task = session.dataTask(with: request) { data, response, error in
            if let error = error {
                RapidoReachLogger.shared.log("sendUserAttributes failed: \(error.localizedDescription)", level: .error)
                completion?(error)
                return
            }
            RapidoReachLogger.shared.log("sendUserAttributes success", level: .info)
            completion?(nil)
        }
        task.resume()
    }

    // MARK: - Placements & Surveys (initial scaffold)

    public func getPlacementDetails(tag: String, completion: @escaping (Result<[String: Any], Error>) -> Void) {
        guard let apiKey = apiKey else {
            completion(.failure(RapidoReachError.customerr("API Key is not set. Please see RapidoReach.shared.configure")))
            return
        }
        guard var components = URLComponents(url: RapidoReachConfiguration.shared.baseURL, resolvingAgainstBaseURL: false) else {
            completion(.failure(RapidoReachError.customerr("Invalid base URL")))
            return
        }
        components.path = "/api/sdk/v2/placements/\(tag)/details"
        components.queryItems = [URLQueryItem(name: "api_key", value: apiKey),
                                 URLQueryItem(name: "sdk_user_id", value: user?.id ?? userID)]
        guard let url = components.url else {
            completion(.failure(RapidoReachError.customerr("Invalid placement URL")))
            return
        }
        session.dataTask(with: url) { data, _, error in
          if let error = error { completion(.failure(error)); return }
          guard let data = data,
                let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
                let payload = (json["Data"] as? [Any])?.first as? [String: Any] else {
              completion(.failure(RapidoReachError.unknown))
              return
          }
          completion(.success(payload))
        }.resume()
    }

    public func canShowContent(tag: String, completion: @escaping (Result<Bool, Error>) -> Void) {
        guard let apiKey = apiKey else {
            completion(.failure(RapidoReachError.customerr("API Key is not set. Please see RapidoReach.shared.configure")))
            return
        }
        guard var components = URLComponents(url: RapidoReachConfiguration.shared.baseURL, resolvingAgainstBaseURL: false) else {
            completion(.failure(RapidoReachError.customerr("Invalid base URL")))
            return
        }
        components.path = "/api/sdk/v2/placements/\(tag)/can_show"
        components.queryItems = [URLQueryItem(name: "api_key", value: apiKey),
                                 URLQueryItem(name: "sdk_user_id", value: user?.id ?? userID)]
        guard let url = components.url else {
            completion(.failure(RapidoReachError.customerr("Invalid can_show URL")))
            return
        }
        session.dataTask(with: url) { data, _, error in
          if let error = error { completion(.failure(error)); return }
          guard let data = data,
                let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
                let payload = (json["Data"] as? [Any])?.first as? [String: Any],
                let canShow = payload["can_show"] as? Bool else {
              completion(.failure(RapidoReachError.unknown))
              return
          }
          if !canShow, let reason = payload["reason"] as? String {
              let code: RapidoReachErrorCode = reason == "BACKEND_UNAVAILABLE" ? .backendUnavailable : .placementNotReady
              completion(.failure(RapidoReachError.coded(code: code, message: reason)))
              return
          }
          completion(.success(canShow))
        }.resume()
    }

    public func listSurveys(tag: String, completion: @escaping (Result<[[String: Any]], Error>) -> Void) {
        guard let apiKey = apiKey else {
            completion(.failure(RapidoReachError.customerr("API Key is not set. Please see RapidoReach.shared.configure")))
            return
        }
        guard var components = URLComponents(url: RapidoReachConfiguration.shared.baseURL, resolvingAgainstBaseURL: false) else {
            completion(.failure(RapidoReachError.customerr("Invalid base URL")))
            return
        }
        components.path = "/api/sdk/v2/placements/\(tag)/surveys"
        components.queryItems = [URLQueryItem(name: "api_key", value: apiKey),
                                 URLQueryItem(name: "sdk_user_id", value: user?.id ?? userID)]
        guard let url = components.url else {
            completion(.failure(RapidoReachError.customerr("Invalid surveys URL")))
            return
        }
        session.dataTask(with: url) { data, _, error in
          if let error = error { completion(.failure(error)); return }
          guard let data = data,
                let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
                let array = json["Data"] as? [[String: Any]] else {
            completion(.failure(RapidoReachError.unknown))
            return
          }
          completion(.success(array))
        }.resume()
    }

    public func canShowSurvey(surveyId: String, tag: String, completion: @escaping (Result<Bool, Error>) -> Void) {
        guard let apiKey = apiKey else {
            completion(.failure(RapidoReachError.customerr("API Key is not set. Please see RapidoReach.shared.configure")))
            return
        }
        guard var components = URLComponents(url: RapidoReachConfiguration.shared.baseURL, resolvingAgainstBaseURL: false) else {
            completion(.failure(RapidoReachError.customerr("Invalid base URL")))
            return
        }
        components.path = "/api/sdk/v2/placements/\(tag)/surveys/\(surveyId)/can_show"
        components.queryItems = [URLQueryItem(name: "api_key", value: apiKey),
                                 URLQueryItem(name: "sdk_user_id", value: user?.id ?? userID)]
        guard let url = components.url else {
            completion(.failure(RapidoReachError.customerr("Invalid can_show survey URL")))
            return
        }
        session.dataTask(with: url) { data, _, error in
            if let error = error { completion(.failure(error)); return }
            guard let data = data,
                  let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
                  let payload = (json["Data"] as? [Any])?.first as? [String: Any],
                  let canShow = payload["can_show"] as? Bool else {
                completion(.failure(RapidoReachError.unknown))
                return
            }
            if !canShow, let reason = payload["reason"] as? String {
                let code: RapidoReachErrorCode = reason == "NOT_FOUND" ? .notFound : .placementNotReady
                completion(.failure(RapidoReachError.coded(code: code, message: reason)))
                return
            }
            completion(.success(canShow))
        }.resume()
    }

    public func hasSurveys(tag: String, completion: @escaping (Result<Bool, Error>) -> Void) {
        listSurveys(tag: tag) { result in
          switch result {
          case .success(let surveys):
            completion(.success(!surveys.isEmpty))
          case .failure(let error):
            completion(.failure(error))
          }
        }
    }

    public func showSurvey(surveyId: String, tag: String, customParameters: [String: Any]? = nil, completion: @escaping (Result<URL, Error>) -> Void) {
        guard let apiKey = apiKey else {
            completion(.failure(RapidoReachError.customerr("API Key is not set. Please see RapidoReach.shared.configure")))
            return
        }
        guard let sdkUserId = user?.id ?? userID else {
            completion(.failure(RapidoReachError.customerr("User ID is not available. Call configure/api registration first.")))
            return
        }
        guard let url = URL(string: "/api/sdk/v2/placements/\(tag)/surveys/\(surveyId)/show", relativeTo: RapidoReachConfiguration.shared.baseURL) else {
            completion(.failure(RapidoReachError.customerr("Invalid show survey URL")))
            return
        }
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        var payload: [String: Any] = ["api_key": apiKey, "sdk_user_id": sdkUserId]
        if let custom = customParameters {
            payload["custom_params"] = custom
        }
        request.httpBody = try? JSONSerialization.data(withJSONObject: payload, options: [])
        session.dataTask(with: request) { data, _, error in
            if let error = error { completion(.failure(error)); return }
            guard let data = data,
                  let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
                  let dataArr = json["Data"] as? [Any],
                  let first = dataArr.first else {
                completion(.failure(RapidoReachError.unknown))
                return
            }
            if let str = first as? String, let url = URL(string: str) {
                completion(.success(url))
                return
            }
            if let dict = first as? [String: Any],
               let link = dict["SurveyEntryLink"] as? String ?? dict["SupplierLink"] as? String,
               let url = URL(string: link) {
                completion(.success(url))
                return
            }
            completion(.failure(RapidoReachError.unknown))
        }.resume()
    }

    public func hasQuickQuestions(tag: String, completion: @escaping (Result<Bool, Error>) -> Void) {
        fetchQuickQuestions(tag: tag) { result in
            switch result {
            case .success(let payload):
                let enabled = payload["enabled"] as? Bool ?? false
                let qq = payload["quick_questions"] as? [Any] ?? []
                completion(.success(enabled && !qq.isEmpty))
            case .failure(let error):
                completion(.failure(error))
            }
        }
    }

    public func fetchQuickQuestions(tag: String, completion: @escaping (Result<[String: Any], Error>) -> Void) {
        guard let apiKey = apiKey else {
            completion(.failure(RapidoReachError.customerr("API Key is not set. Please see RapidoReach.shared.configure")))
            return
        }
        guard var components = URLComponents(url: RapidoReachConfiguration.shared.baseURL, resolvingAgainstBaseURL: false) else {
            completion(.failure(RapidoReachError.customerr("Invalid base URL")))
            return
        }
        components.path = "/api/sdk/v2/placements/\(tag)/quick_questions"
        components.queryItems = [URLQueryItem(name: "api_key", value: apiKey),
                                 URLQueryItem(name: "sdk_user_id", value: user?.id ?? userID)]
        guard let url = components.url else {
            completion(.failure(RapidoReachError.customerr("Invalid quick questions URL")))
            return
        }
        session.dataTask(with: url) { data, _, error in
            if let error = error { completion(.failure(error)); return }
            guard let data = data,
                  let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
                  let payload = (json["Data"] as? [Any])?.first as? [String: Any] else {
                completion(.failure(RapidoReachError.unknown))
                return
            }
            if let reason = payload["reason"] as? String, reason == "NOT_ENABLED" {
                completion(.failure(RapidoReachError.coded(code: .notSupported, message: reason)))
                return
            }
            completion(.success(payload))
        }.resume()
    }

    public func answerQuickQuestion(id: String, placement: String, answer: Any, completion: @escaping (Result<[String: Any], Error>) -> Void) {
        guard let apiKey = apiKey else {
            completion(.failure(RapidoReachError.customerr("API Key is not set. Please see RapidoReach.shared.configure")))
            return
        }
        guard let url = URL(string: "/api/sdk/v2/placements/\(placement)/quick_questions/\(id)/answer", relativeTo: RapidoReachConfiguration.shared.baseURL) else {
            completion(.failure(RapidoReachError.customerr("Invalid quick questions URL")))
            return
        }
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        let payload: [String: Any] = [
            "api_key": apiKey,
            "sdk_user_id": (user?.id ?? userID) as Any,
            "answer": answer
        ]
        request.httpBody = try? JSONSerialization.data(withJSONObject: payload, options: [])
        session.dataTask(with: request) { data, _, error in
            if let error = error { completion(.failure(error)); return }
            guard let data = data,
                  let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
                  let first = (json["Data"] as? [Any])?.first as? [String: Any] else {
                completion(.failure(RapidoReachError.unknown))
                return
            }
            if let status = first["status"] as? String, status == "NOT_ENABLED" {
                completion(.failure(RapidoReachError.coded(code: .notSupported, message: status)))
                return
            }
            completion(.success(first))
        }.resume()
    }
}

extension Dictionary where Key == String, Value == Any? {
    mutating func append(_ anotherDict:[String: Any?]) {
        for (key, value) in anotherDict {
            self.updateValue(value, forKey: key)
        }
    }
}

private extension UIColor {
    convenience init?(rr_hex: String) {
        var hexString = rr_hex.trimmingCharacters(in: .whitespacesAndNewlines)
        if hexString.hasPrefix("#") {
            hexString.removeFirst()
        }
        guard hexString.count == 6 || hexString.count == 8,
              let hexValue = UInt64(hexString, radix: 16) else { return nil }
        let alpha: CGFloat
        let red: CGFloat
        let green: CGFloat
        let blue: CGFloat
        if hexString.count == 8 {
            alpha = CGFloat((hexValue & 0xFF000000) >> 24) / 255.0
            red = CGFloat((hexValue & 0x00FF0000) >> 16) / 255.0
            green = CGFloat((hexValue & 0x0000FF00) >> 8) / 255.0
            blue = CGFloat(hexValue & 0x000000FF) / 255.0
        } else {
            alpha = 1.0
            red = CGFloat((hexValue & 0xFF0000) >> 16) / 255.0
            green = CGFloat((hexValue & 0x00FF00) >> 8) / 255.0
            blue = CGFloat(hexValue & 0x0000FF) / 255.0
        }
        self.init(red: red, green: green, blue: blue, alpha: alpha)
    }
}
