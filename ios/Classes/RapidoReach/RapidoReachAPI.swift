//
//  RapidoReachAPI.swift
//  RapidoReach
//
//  Created by Vikash Kumar on 25/07/2020.
//

import Foundation

enum RapidoReachAPI {
    case appUserID
    case iFrame
    case abandoned
    
    static let apiVersion = ""

    private var path: String {
        switch self {
        case .appUserID: return "api/sdk/v1/appusers"
        case .iFrame: return "sdk/v2/appuser_entry"
        case .abandoned:  return "api/sdk/v1/appuser_abandoned_campaign"
        }
    }

    private var queryURL: URLComponents? {
        let base = RapidoReachConfiguration.shared.baseURL.appendingPathComponent(RapidoReachAPI.apiVersion)
        return URLComponents(url: base.appendingPathComponent(path), resolvingAgainstBaseURL: false)
    }

    func url(for params: [String: Any?]) -> URL? {
        guard var queryURL = queryURL else { return nil }
        let items = params
            .sorted { $0.key < $1.key }
            .compactMap { element -> URLQueryItem? in
                guard let value = element.value else { return nil }
                return URLQueryItem(name: element.key, value: "\(value)")
            }
        queryURL.queryItems = items
        return queryURL.url
    }
}
