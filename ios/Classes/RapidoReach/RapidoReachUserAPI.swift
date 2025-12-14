//
//  RapidoReachUserAPI.swift
//  RapidoReach
//
//  Created by Vikash Kumar on 28/07/2020.
//

import CommonCrypto
import Foundation

enum RapidoReachUserAPI {
    case rewards

    static let apiVersion = "v2"

    private var path: String {
        switch self {
        case .rewards: return "api/sdk/v2/appusers"
        }
    }

    private func queryURL(for user: String) -> URLComponents? {
        let base = RapidoReachConfiguration.shared.baseURL.appendingPathComponent(RapidoReachAPI.apiVersion)
        let apiURL = base.appendingPathComponent(path)
        let userURL = apiURL.appendingPathComponent(user).appendingPathComponent("appuser_rewards")
        return URLComponents(url: userURL, resolvingAgainstBaseURL: false)
    }

    private func MD5(string: String) -> Data {
        let length = Int(CC_MD5_DIGEST_LENGTH)
        let messageData = string.data(using:.utf8)!
        var digestData = Data(count: length)

        _ = digestData.withUnsafeMutableBytes { digestBytes -> UInt8 in
            messageData.withUnsafeBytes { messageBytes -> UInt8 in
                if let messageBytesBaseAddress = messageBytes.baseAddress, let digestBytesBlindMemory = digestBytes.bindMemory(to: UInt8.self).baseAddress {
                    let messageLength = CC_LONG(messageData.count)
                    CC_MD5(messageBytesBaseAddress, messageLength, digestBytesBlindMemory)
                }
                return 0
            }
        }
        return digestData
    }

    func url(for user: String, params: [String: Any?]) -> URL? {
        guard var queryURL = queryURL(for: user) else { return nil }
        var queryItems = params
            .sorted { $0.key < $1.key }
            .compactMap { element -> URLQueryItem? in
                guard let value = element.value else { return nil }
                return URLQueryItem(name: element.key, value: "\(value)")
            }
        queryURL.queryItems = queryItems
        guard let urlString = queryURL.url else { return nil }
        let hash = MD5(string: "\(urlString)\(RapidoReachConfiguration.shared.rewardHashSalt)")
        let md5Hex = hash.map { String(format: "%02hhx", $0) }.joined()
        queryItems.append(URLQueryItem(name: "enc", value: md5Hex))
        queryURL.queryItems = queryItems
        return queryURL.url
    }
}
