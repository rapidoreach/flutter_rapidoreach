import Flutter
import RapidoReachSDK
import UIKit

@objc(SwiftRapidoReachPlugin)
public class SwiftRapidoReachPlugin: NSObject, FlutterPlugin {
  public static func register(with registrar: FlutterPluginRegistrar) {
    let channel = FlutterMethodChannel(name: "rapidoreach", binaryMessenger: registrar.messenger())
    let instance = SwiftRapidoReachPlugin()
    registrar.addMethodCallDelegate(instance, channel: channel)
  }

    public func handle(_ call: FlutterMethodCall, result: @escaping FlutterResult) {
            if call.method == "init" {
                let apiKey = (call.arguments as! Dictionary<String, AnyObject>)["api_token"] as! String
                let userId = (call.arguments as! Dictionary<String, AnyObject>)["user_id"] as! String
                RapidoReach.shared.setRewardCallback { (reward:Int) in
                  print("%d REWARD", reward, apiKey, userId);
                  self.onReward(reward: reward)
                }
                RapidoReach.shared.setsurveysAvailableCallback { (available:Bool) in
                  print("Rapido Reach Survey Available" );
                  self.rapidoreachSurveyAvailable(available: available)
                }
                RapidoReach.shared.setrewardCenterOpenedCallback {
                  print("Reward center opened")
                  self.onRewardCenterOpened()
                }
                RapidoReach.shared.setrewardCenterClosedCallback {
                  print("Reward center closed" );
//               RNRapidoReach.EventEmitter.sendEvent(withName: "onRewardCenterClosed", body: nil)
                  self.onRewardCenterClosed()
                }
                            
                RapidoReach.shared.configure(apiKey: apiKey as String, user: userId as String)
                RapidoReach.shared.fetchAppUserID()
                result(nil)
            } else if (call.method == "show") {
                // we do not keep track of old callbacks on iOS, so nothing to do here
                let iframeController = topMostController()
                if(iframeController == nil) {
                  return
                }
                RapidoReach.shared.presentSurvey(iframeController!)
                result(nil)
            } else if (call.method == "setRewardCenterOpened") {
                print("Native test  RewardCenterClosed");
                result(0)
            } else if (call.method == "setOnRewardListener") {
                let quantity = call.arguments
                result(quantity)
            } else if (call.method == "setRewardCenterClosed") {
                print("Native test  RewardCenterOpened");
                result(0)
            } else if (call.method == "setNavBarText") {
                print("Native test  setNavigationBarText");
                let barText = (call.arguments as! Dictionary<String, AnyObject>)["text"] as! String
                RapidoReach.shared.setNavigationBarText(for: barText);
            } else if (call.method == "setNavBarColor") {
                print("Native test  setNavigationBarColor");
                let barColor = (call.arguments as! Dictionary<String, AnyObject>)["color"] as! String
                RapidoReach.shared.setNavigationBarColor(for: barColor);
            } else if (call.method == "setNavBarTextColor") {
                print("Native test  setNavigationBarTextColor");
                let textColor = (call.arguments as! Dictionary<String, AnyObject>)["text_color"] as! String
                RapidoReach.shared.setNavigationBarTextColor(for: textColor)
            } else if (call.method == "setSurveyAvaiableListener") {
                let surveyAvailable = call.arguments
                var survey = 0;
                if((surveyAvailable) != nil) {
                   survey = 1;
                } else if ((surveyAvailable == nil)) {
                  survey = 0;
               }
                result(survey)
            }
            else {
                result(FlutterMethodNotImplemented)
            }
        }

    func topMostController() -> UIViewController? {
        guard let window = UIApplication.shared.keyWindow, let rootViewController = window.rootViewController else {
            return nil
        }

        var topController = rootViewController

        while let newTopController = topController.presentedViewController {
            topController = newTopController
        }

        return topController
    }

    public func showRewardCenter(_ call: FlutterMethodCall, result: @escaping FlutterResult) -> Void {
      
      
    }

    public func onReward(reward: Int) {
    }

    public func onRewardCenterOpened()  {
      print("Native test  RewardCenterOpened");
    }

    public func onRewardCenterClosed() {
      print("Native test  RewardCenterClosed");
    }
    
    public func setNavBarText(barText: String) {
        print("setNavigationBarText");
        RapidoReach.shared.setNavigationBarText(for: barText);
    }
    
    public func setNavBarColor(barColor: String) {
        print("setNavigationBarColor");
        RapidoReach.shared.setNavigationBarColor(for: barColor);
    }
    
    public func setNavBarTextColor(barTextColor: String) {
        print("setNavigationBarTextColor");
        RapidoReach.shared.setNavigationBarTextColor(for: barTextColor);
    }


    func rapidoreachSurveyAvailable(available: Bool)  {
        print("Native test  rapidoreachSurveyAvailable");
    }
  
     func supportedEvents() -> [String]! {
        return ["onReward", "onRewardCenterOpened", "onRewardCenterClosed", "rapidoreachSurveyAvailable", "setNavBarText", "setNavBarColor", "setNavBarTextColor"]
      }
}


extension SwiftRapidoReachPlugin: RapidoReachDelegate {
    public func didSurveyAvailable(_ available: Bool) {
        
  }

  func didFinishSurvey() {
    
  }
  
  func didCancelSurvey() {
    
  }
  
    public func didGetError(_ error: RapidoReachError) {
    
  }
  
  func didGetAppUser(_ user: RapidoReachUser) {
    
  }
  
    public func didGetRewards(_ reward: RapidoReachReward) {
    
  }
  
    public func didOpenRewardCenter() {
    
  }
  
    public func didClosedRewardCenter() {
    
  }
  
}
