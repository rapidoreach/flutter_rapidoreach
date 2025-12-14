//
//  RapidoReachDelegate.swift
//  RapidoReach
//
//  Created by Vikash Kumar on 25/07/2020.
//

import Foundation

/// Kind of Errors happened in the SDK
public enum RapidoReachError: Error {
    case generic(Error)
    case unknown
    case customerr(String)
    case coded(code: RapidoReachErrorCode, message: String?)
    case ErrorList([String])
}

/// Simple set of error codes to mirror TapResearch-like responses.
public enum RapidoReachErrorCode: String {
    case sdkNotReady = "SDK_NOT_READY"
    case placementNotReady = "PLACEMENT_NOT_READY"
    case backendUnavailable = "BACKEND_UNAVAILABLE"
    case notSupported = "NOT_SUPPORTED"
    case invalidParams = "INVALID_PARAMS"
    case notFound = "NOT_FOUND"
}

/// Reward payload with richer metadata (aligned with TapResearch-like flows).
public struct RapidoReachRewardPayload: Decodable {
    public let transactionIdentifier: String?
    public let placementIdentifier: String?
    public let placementTag: String?
    public let currencyName: String?
    public let rewardAmount: Double
    public let saleMultiplier: Double?
}

extension RapidoReachError: LocalizedError {
    public var errorDescription: String? {
        switch self {
        case .generic(let error): return error.localizedDescription
        case .customerr(let input): return NSLocalizedString(input, comment: "This is a comment for customized error")
        case .coded(_, let message): return message ?? NSLocalizedString("Unknown error occured", comment: "")
        case .unknown: return NSLocalizedString("Unknown error occured", comment: "")
        case .ErrorList(let list):
            var output: String = "";
            for item in list {
                output += item + "\n";
            }
            return output
        }
    }
}

public extension RapidoReachError {
    var code: RapidoReachErrorCode? {
        switch self {
        case .coded(let code, _): return code
        default: return nil
        }
    }
}

/// Protocol to provide user and device related information for the sdk, uses a default implementation see `RapidoReachDeviceInfo`
public protocol RapidoReachDeviceInfoProvider {
    /// Unique device identifier
    var deviceID: String { get }
    /// iOS version information
    var osVersion: String { get }
    /// Device model
    var appDevice: String { get }
    /// Carrier information
    var carrier: String? { get }
    /// Device language code
    var locale: String? { get }
}

/// Protocol to report back events for the SDK
public protocol RapidoReachDelegate: AnyObject {
    /// Called as soon as the SDK registers or refreshes the app user.
    func didGetUser(_ user: RapidoReachUser)
    /// Did get the reward info for the registered user
    func didGetRewards(_ reward: RapidoReachReward)
    /// Report any error back from the sdk
    func didGetError(_ error: RapidoReachError)
    /// User opened a reward center
    func didOpenRewardCenter()
    /// User closed a reward center
    func didClosedRewardCenter()
    /// Notify if surveys available for user
    func didSurveyAvailable(_ available: Bool)
}

public extension RapidoReachDelegate {
    func didGetUser(_ user: RapidoReachUser) {}
    func didGetRewards(_ reward: RapidoReachReward) {}
    func didGetError(_ error: RapidoReachError) {}
    func didOpenRewardCenter() {}
    func didClosedRewardCenter() {}
    func didSurveyAvailable(_ available: Bool) {}
}

/// More granular delegate for lifecycle and errors.
public protocol RapidoReachSDKDelegate: AnyObject {
    func onSDKReady()
    func onSDKError(_ error: RapidoReachError)
}

public extension RapidoReachSDKDelegate {
    func onSDKReady() {}
    func onSDKError(_ error: RapidoReachError) {}
}

/// Delegate to receive batched rewards with metadata.
public protocol RapidoReachRewardDelegate: AnyObject {
    func onRewards(_ rewards: [RapidoReachRewardPayload])
}

public extension RapidoReachRewardDelegate {
    func onRewards(_ rewards: [RapidoReachRewardPayload]) {}
}

/// Content callbacks for presentation lifecycle.
public protocol RapidoReachContentDelegate: AnyObject {
    func onContentShown(forPlacement placement: String)
    func onContentDismissed(forPlacement placement: String)
}

public extension RapidoReachContentDelegate {
    func onContentShown(forPlacement placement: String) {}
    func onContentDismissed(forPlacement placement: String) {}
}

/// Quick question payload + delegate
public struct RapidoReachQuickQuestionPayload: Decodable {
    public let id: String
    public let questions: [String: AnyDecodable]
}

public protocol RapidoReachQuickQuestionDelegate: AnyObject {
    func onQuickQuestionResponse(_ payload: RapidoReachQuickQuestionPayload)
}

public extension RapidoReachQuickQuestionDelegate {
    func onQuickQuestionResponse(_ payload: RapidoReachQuickQuestionPayload) {}
}

/// Surveys list/preview refresh delegate.
public protocol RapidoReachSurveysDelegate: AnyObject {
    func onSurveysRefreshed(forPlacement placement: String)
}

public extension RapidoReachSurveysDelegate {
    func onSurveysRefreshed(forPlacement placement: String) {}
}
