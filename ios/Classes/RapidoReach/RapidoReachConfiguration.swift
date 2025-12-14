//
//  RapidoReachConfiguration.swift
//  RapidoReach
//
//  Central place to manage environment specific settings so SDK consumers can
//  point to staging/production without touching the core logic.
//

import Foundation

public final class RapidoReachConfiguration {
    public static var shared = RapidoReachConfiguration()

    /// Backend base URL. Defaults to production.
    public var baseURL: URL

    /// Salt used to generate the MD5 hash for reward validation.
    public var rewardHashSalt: String

    /// Indicates whether the SDK is running against a test/staging environment.
    public private(set) var isTestMode: Bool = false

    /// Create a configuration object. You usually won't need this directly, instead
    /// update `RapidoReachConfiguration.shared`.
    /// For local dev (simulator), you can set env `RAPIDOREACH_BASE_URL`.
    public init(baseURL: URL? = nil,
                rewardHashSalt: String = "12fb172e94cfcb20dd65c315336b919f") {
        if let envBase = ProcessInfo.processInfo.environment["RAPIDOREACH_BASE_URL"],
           let url = URL(string: envBase) {
            self.baseURL = url
        } else if let base = baseURL {
            self.baseURL = base
        } else {
            self.baseURL = URL(string: "https://rorapps.rapidoreach.com")!
        }
        self.rewardHashSalt = rewardHashSalt
        recalcTestMode()
    }

    /// Allow partners to override the backend without touching the main APIs.
    @objc public func update(baseURL: URL) {
        self.baseURL = baseURL
        recalcTestMode()
    }

    /// Allow partners to override the hash salt if backend changes.
    @objc public func update(rewardHashSalt: String) {
        self.rewardHashSalt = rewardHashSalt
    }

    private func recalcTestMode() {
        if let explicit = ProcessInfo.processInfo.environment["RAPIDOREACH_TEST_MODE"] {
            isTestMode = (explicit as NSString).boolValue
            return
        }
        let host = baseURL.host ?? ""
        isTestMode = host.contains("localhost") ||
                     host.contains("dev") ||
                     host.contains("staging") ||
                     host.contains("127.0.0.1")
    }
}
