//
//  RapidoReachSwiftUI.swift
//  RapidoReach
//
//  Lightweight SwiftUI helpers to mirror TapResearch convenience components.
//

import Foundation
import SwiftUI
import Combine

@available(iOS 13.0, *)
public final class RapidoReachReadiness: ObservableObject {
    @Published public var isReady: Bool = false
    private var cancellable: AnyCancellable?

    public init(pollInterval: TimeInterval = 1.5) {
        cancellable = Timer.publish(every: pollInterval, on: .main, in: .common)
            .autoconnect()
            .sink { _ in
                self.isReady = RapidoReach.shared.isReady
            }
    }

    deinit {
        cancellable?.cancel()
    }
}

@available(iOS 13.0, *)
public struct RapidoReachOfferwallButton: View {
    public var title: String
    public var placement: String
    public var customParams: [String: Any]?

    @ObservedObject private var readiness = RapidoReachReadiness()

    public init(title: String = "Surveys", placement: String = "default", customParams: [String: Any]? = nil) {
        self.title = title
        self.placement = placement
        self.customParams = customParams
    }

    public var body: some View {
        Button(action: {
            RapidoReach.shared.presentOfferwall(from: RapidoReach.topViewController(), title: title, customParameters: customParams)
        }) {
            Text(title)
                .padding(.vertical, 10)
                .padding(.horizontal, 14)
                .frame(maxWidth: .infinity)
        }
        .background(readiness.isReady ? Color.accentColor : Color.gray)
        .foregroundColor(.white)
        .cornerRadius(10)
        .disabled(!readiness.isReady)
        .onAppear {
            RapidoReach.shared.canShowContent(tag: placement) { result in
                if case .success(let ready) = result {
                    DispatchQueue.main.async {
                        self.readiness.isReady = ready
                    }
                }
            }
        }
    }
}
