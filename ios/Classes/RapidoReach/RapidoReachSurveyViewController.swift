//
//  RapidoReachSurveyViewController.swift
//  RapidoReach
//
//  Created by Vikash Kumar on 28/07/2020.
//

import UIKit
import WebKit

final class RapidoReachSurveyViewController: UIViewController {

    private lazy var webView: WKWebView = {
        let webView = WKWebView()
        webView.autoresizingMask = [.flexibleHeight, .flexibleWidth]
        webView.uiDelegate = self
        webView.navigationDelegate = self
        return webView
    }()

    var url: URL?
    private var testModeLabel: UILabel?
    private lazy var loadingView: UIView = {
        let view = UIView(frame: .zero)
        view.backgroundColor = UIColor.black.withAlphaComponent(0.4)
        view.autoresizingMask = [.flexibleWidth, .flexibleHeight]
        let spinner: UIActivityIndicatorView
        if #available(iOS 13.0, *) {
            spinner = UIActivityIndicatorView(style: .large)
        } else {
            spinner = UIActivityIndicatorView(style: .whiteLarge)
        }
        spinner.startAnimating()
        spinner.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(spinner)
        NSLayoutConstraint.activate([
            spinner.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            spinner.centerYAnchor.constraint(equalTo: view.centerYAnchor)
        ])
        return view
    }()
    
    override func viewDidLoad() {
        super.viewDidLoad()
        RapidoReach.shared.delegate?.didOpenRewardCenter();
        RapidoReach.shared.rewardCenterOpenedCallbackFunc();
        // Do any additional setup after loading the view, typically from a nib.
        navigationItem.rightBarButtonItem = UIBarButtonItem(barButtonSystemItem: .done,
                                                            target: self,
                                                            action:#selector(closeSurvey))
        webView.frame = view.bounds
        view.addSubview(webView)
        attachTestBannerIfNeeded()

        showLoading()
        guard let url = url else { return }
        webView.load(URLRequest(url: url))
    }

    @objc
    func closeSurvey() {
        RapidoReach.shared.reportAbandon()
        RapidoReach.shared.fetchAppUserID()
        RapidoReach.shared.delegate?.didClosedRewardCenter();
        RapidoReach.shared.rewardCenterClosedCallbackFunc();
        RapidoReach.shared.contentDelegate?.onContentDismissed(forPlacement: title ?? "")
        dismiss(animated: true, completion: nil)
    }

    private func showLoading() {
        loadingView.frame = view.bounds
        view.addSubview(loadingView)
    }

    private func hideLoading() {
        loadingView.removeFromSuperview()
    }

    private func attachTestBannerIfNeeded() {
        guard RapidoReachConfiguration.shared.isTestMode else { return }
        let label = UILabel()
        label.text = "Test mode: use a test user/device ID"
        label.textColor = .white
        label.textAlignment = .center
        label.backgroundColor = UIColor.systemOrange.withAlphaComponent(0.9)
        label.font = UIFont.boldSystemFont(ofSize: 12)
        label.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(label)
        NSLayoutConstraint.activate([
            label.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            label.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            label.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor),
            label.heightAnchor.constraint(equalToConstant: 28)
        ])
        testModeLabel = label
        // Push webView below the banner
        webView.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            webView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            webView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            webView.bottomAnchor.constraint(equalTo: view.bottomAnchor),
            webView.topAnchor.constraint(equalTo: label.bottomAnchor)
        ])
    }
}

extension RapidoReachSurveyViewController: WKUIDelegate {
    func webView(_ webView: WKWebView, createWebViewWith configuration: WKWebViewConfiguration, for navigationAction: WKNavigationAction, windowFeatures: WKWindowFeatures) -> WKWebView? {
        let isMainFrame = navigationAction.targetFrame?.isMainFrame ?? false
        guard !isMainFrame, let url = navigationAction.request.url else {
                return nil
        }
        RapidoReach.shared.presentWebView(self, with: url)
        return nil
    }
}

extension RapidoReachSurveyViewController: WKNavigationDelegate {
    func webView(_ webView: WKWebView, didStartProvisionalNavigation navigation: WKNavigation!) {
        RapidoReach.log("didStartProvisionalNavigation")
    }

    func webView(_ webView: WKWebView, didFailProvisionalNavigation navigation: WKNavigation!, withError error: Error) {
        RapidoReach.log("didFailProvisionalNavigation \(error)")
        hideLoading()
        self.alert(title: RapidoReach.bundleName, message: error.localizedDescription)
        
    }

    func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
        hideLoading()

        RapidoReach.log("didFinish")
    }

    func webView(_ webView: WKWebView, didFail navigation: WKNavigation!, withError error: Error) {
        RapidoReach.log("didFail \(error)")
        hideLoading()
        self.alert(title: RapidoReach.bundleName, message: error.localizedDescription)
    }

    func webViewWebContentProcessDidTerminate(_ webView: WKWebView) {
        RapidoReach.log("webViewWebContentProcessDidTerminate")
    }
}

extension UIViewController {
    @discardableResult
    func alert(title: String?, message: String?, _ handler: ((UIAlertAction) -> Void)? = nil) -> UIAlertController {
        let alert = UIAlertController(title: title, message: message, preferredStyle: .alert)
        alert.addAction(UIAlertAction(title: "Ok", style: .default, handler: handler))
        present(alert, animated: true, completion: nil)
        return alert
    }
}
