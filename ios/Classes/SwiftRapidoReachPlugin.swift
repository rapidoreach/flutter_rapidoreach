import Flutter
import RapidoReachSDK
import UIKit

@objc(SwiftRapidoReachPlugin)
public class SwiftRapidoReachPlugin: NSObject, FlutterPlugin {
  public static func register(with registrar: FlutterPluginRegistrar) {
    let channel = FlutterMethodChannel(name: "RapidoReach", binaryMessenger: registrar.messenger())
    let instance = SwiftRapidoReachPlugin()
    registrar.addMethodCallDelegate(instance, channel: channel)
    channel.setMethodCallHandler {(call: FlutterMethodCall, result: FlutterResult) -> Void in
            if (call.method == "init") {
                RapidoReach.shared.setRewardCallback { (reward:Int) in
                  print("%d REWARD", reward);
//                    try? self.onReward(reward: reward)
                }
                RapidoReach.shared.setsurveysAvailableCallback { (available:Bool) in
                  print("Rapido Reach Survey Available" );
            //      RNRapidoReach.EventEmitter.sendEvent(withName: "onRewardCenterClosed", body: nil)
//                  self.rapidoreachSurveyAvailable(available: available)
                }
                RapidoReach.shared.setrewardCenterOpenedCallback {
                  print("Reward centre opened")
//                  self.onRewardCenterOpened()
                }
                RapidoReach.shared.setrewardCenterClosedCallback {
                  print("Reward centre closed" );
            //      RNRapidoReach.EventEmitter.sendEvent(withName: "onRewardCenterClosed", body: nil)
//                  self.onRewardCenterClosed()


                }
//                RapidoReach.shared.configure(apiKey: apiKey as String, user: userId as String)
//                RapidoReach.shared.fetchAppUserID()
            }
        }
    // Override point for customization after application launch.
    
  }
    
    

  public func handle(_ call: FlutterMethodCall, result: @escaping FlutterResult) {
    result("iOS " + UIDevice.current.systemVersion)
  }
    
//    static func moduleName() -> String!{
//      return "RNRapidoReach";
//    }
//
//    static func requiresMainQueueSetup () -> Bool {
//      return true;
//    }
    

    public func initWithApiKeyAndUserId(_ call: FlutterMethodCall, result: @escaping FlutterResult, _ apiKey:NSString, userId:NSString) -> Void {
    // Override point for customization after application launch.
      RapidoReach.shared.setRewardCallback { (reward:Int) in
        print("%d REWARD", reward);
        self.onReward(reward: reward)
      }
      RapidoReach.shared.setsurveysAvailableCallback { (available:Bool) in
        print("Rapido Reach Survey Available" );
  //      RNRapidoReach.EventEmitter.sendEvent(withName: "onRewardCenterClosed", body: nil)
        self.rapidoreachSurveyAvailable(available: available)
      }
      RapidoReach.shared.setrewardCenterOpenedCallback {
        print("Reward centre opened")
        self.onRewardCenterOpened()
      }
      RapidoReach.shared.setrewardCenterClosedCallback {
        print("Reward centre closed" );
  //      RNRapidoReach.EventEmitter.sendEvent(withName: "onRewardCenterClosed", body: nil)
        self.onRewardCenterClosed()


      }
      RapidoReach.shared.configure(apiKey: apiKey as String, user: userId as String)
      RapidoReach.shared.fetchAppUserID()
        //    return true
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
      let iframeController = topMostController()
      if(iframeController == nil) {
        return
      }
        RapidoReach.shared.presentSurvey(iframeController!)
      
    }

    public func onReward(reward: Int) {
          // send our event with some data
//          sendEvent(withName: "onReward", body: reward)
          // body can be anything: int, string, array, object
    }

    public func onRewardCenterOpened()  {
      print("Native test  RewardCenterOpened");
//      sendEvent(withName: "onRewardCenterOpened", body: "opened")
    }

    public func onRewardCenterClosed() {
      print("Native test  RewardCenterClosed");
//      sendEvent(withName: "onRewardCenterClosed", body: "reward")
    }


    func rapidoreachSurveyAvailable(available: Bool)  {
        print("Native test  rapidoreachSurveyAvailable");
//       sendEvent(withName: "rapidoreachSurveyAvailable", body: "true")
    }
  
  
     func supportedEvents() -> [String]! {
        return ["onReward", "onRewardCenterOpened", "onRewardCenterClosed", "rapidoreachSurveyAvailable"]
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
