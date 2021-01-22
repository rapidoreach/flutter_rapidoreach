package com.rapidoreach.RapidoReach;

import androidx.annotation.NonNull;
import android.app.Activity;

import io.flutter.Log;
import io.flutter.embedding.engine.plugins.FlutterPlugin;
import io.flutter.embedding.engine.plugins.activity.ActivityPluginBinding;
import io.flutter.plugin.common.MethodCall;
import io.flutter.plugin.common.MethodChannel;
import io.flutter.plugin.common.MethodChannel.MethodCallHandler;
import io.flutter.plugin.common.MethodChannel.Result;
import io.flutter.plugin.common.PluginRegistry.Registrar;

import com.rapidoreach.rapidoreachsdk.RapidoReach;
import com.rapidoreach.rapidoreachsdk.RapidoReachRewardListener;
import com.rapidoreach.rapidoreachsdk.RapidoReachSurveyListener;
import com.rapidoreach.rapidoreachsdk.RapidoReachSurveyAvailableListener;
import io.flutter.embedding.engine.plugins.activity.ActivityAware;
import io.flutter.plugin.common.BinaryMessenger;

import io.flutter.plugin.common.PluginRegistry.Registrar;

public class RapidoReachPlugin implements FlutterPlugin, MethodCallHandler,ActivityAware {
 
  private static MethodChannel channel;
  private static RapidoReachPlugin Instance;
  static Activity activity;
  private static final Listeners listeners = new Listeners();


  static RapidoReachPlugin getInstance() {
    return Instance;
}

  @Override
  public void onAttachedToEngine(@NonNull FlutterPluginBinding flutterPluginBinding) {
    this.OnAttachedToEngine(flutterPluginBinding.getBinaryMessenger());
  }

  private void OnAttachedToEngine(BinaryMessenger messenger) {
    if (RapidoReachPlugin.Instance == null)
    RapidoReachPlugin.Instance = new RapidoReachPlugin();
  if (RapidoReachPlugin.channel == null) {
    RapidoReachPlugin.channel = new MethodChannel(messenger, "rapidoreach");
    RapidoReachPlugin.channel.setMethodCallHandler(this);
    } 
}
void OnMethodCallHandler(final String method, final int args) {
  try {
   RapidoReachPlugin.activity.runOnUiThread(new Runnable() {
             @Override
             public void run() {
                 channel.invokeMethod(method, args);
             }
         });
     } catch (Exception e) {
         Log.e("RapidoReach", "Error " + e.toString());
  }
 }
 private void extractRapidoReachParams(MethodCall call, Result result) {
  String api_token = null;
  if(call.argument("api_token")!=null){
    api_token = call.argument("api_token");
  }else{
    result.error("no_api_token", "a null api token was provided", null);
    return;
  }
  String user_id = null;
  if(call.argument("user_id")!=null){
    user_id = call.argument("user_id");
  }
  RapidoReach.initWithApiKeyAndUserIdAndActivityContext(api_token,user_id,activity);
  RapidoReach.getInstance().setRapidoReachRewardListener(RapidoReachPlugin.listeners);
  RapidoReach.getInstance().setRapidoReachSurveyListener(RapidoReachPlugin.listeners);
  RapidoReach.getInstance().setRapidoReachSurveyAvailableListener(RapidoReachPlugin.listeners);
}
  @Override
  public void onMethodCall(@NonNull MethodCall call, @NonNull Result result) {
    if (call.method.equals("init")) {
      extractRapidoReachParams(call,result);
    } else if (call.method.equals("show")) {
      if(call.argument("placementID")!=null){
        String placement = call.argument("placementID");
        RapidoReach.getInstance().showRewardCenter(placement);
      }else{
          RapidoReach.getInstance().showRewardCenter();
      }
    }else if(call.method.equals("setNavBarText")){
      String text = call.argument("text");
      RapidoReach.getInstance().setNavigationBarText(text);
    }else if(call.method.equals("setNavBarColor")){
      String color = call.argument("color");
      RapidoReach.getInstance().setNavigationBarColor(color);
    }else if(call.method.equals("setNavBarTextColor")){
      String textColor = call.argument("text_color");
      RapidoReach.getInstance().setNavigationBarTextColor(textColor);
    }
    else {
      result.notImplemented();
    }
  }

  @Override
  public void onDetachedFromEngine(@NonNull FlutterPluginBinding binding) {
    channel.setMethodCallHandler(null);
  }

  @Override
  public void onAttachedToActivity(@NonNull ActivityPluginBinding activityPluginBinding) {
    activity = activityPluginBinding.getActivity();
  }

  @Override
  public void onDetachedFromActivityForConfigChanges() {

  }

  @Override
  public void onReattachedToActivityForConfigChanges(@NonNull ActivityPluginBinding activityPluginBinding) {

  }

  @Override
  public void onDetachedFromActivity() {

  }
}
