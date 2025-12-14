//
//  RapidoReachDeviceInfo.swift
//  RapidoReach
//
//  Created by Vikash Kumar on 25/07/2020.
//

import AdSupport
import AppTrackingTransparency
import CoreTelephony
import UIKit

public class RapidoReachDeviceInfo: RapidoReachDeviceInfoProvider {

    private enum Key {
        static let deviceID = "\(RapidoReach.bundleID).deviceID"
    }

    private func advertisingIdentifier() -> UUID? {
        if #available(iOS 14, *) {
            let status = ATTrackingManager.trackingAuthorizationStatus
            guard status == .authorized else { return nil }
            return ASIdentifierManager.shared().advertisingIdentifier
        } else {
            return ASIdentifierManager.shared().isAdvertisingTrackingEnabled
                ? ASIdentifierManager.shared().advertisingIdentifier
                : nil
        }
    }

    public var deviceID: String {
        guard let id = UserDefaults.standard.string(forKey: Key.deviceID) else {
            let id = (advertisingIdentifier() ?? UIDevice.current.identifierForVendor ?? UUID()).uuidString
            UserDefaults.standard.set(id, forKey: Key.deviceID)
            UserDefaults.standard.synchronize()
            return id
        }
        return id
    }

    // Other parameters
    public var carrier: String? {
        let info = CTTelephonyNetworkInfo()
        if #available(iOS 12.0, *) {
            return info.serviceSubscriberCellularProviders?.values.compactMap { $0.carrierName }.first
        } else {
            return info.subscriberCellularProvider?.carrierName
        }
    }

    public var osVersion: String { UIDevice.current.systemVersion }
    public var appDevice: String { UIDevice.current.model }
    public var locale: String? { Locale.preferredLanguages.first ?? Locale.current.languageCode }

    /// Helper for host apps that want to trigger the ATT prompt before we look for IDFA.
    @available(iOS 14, *)
    @objc public func requestTrackingPermission(completion: ((ATTrackingManager.AuthorizationStatus) -> Void)? = nil) {
        ATTrackingManager.requestTrackingAuthorization { status in
            completion?(status)
        }
    }

    public init() {}
}
