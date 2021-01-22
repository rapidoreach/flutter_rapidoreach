package com.rapidoreach.RapidoReach;

import io.flutter.Log;

import com.rapidoreach.rapidoreachsdk.RapidoReach;
import com.rapidoreach.rapidoreachsdk.RapidoReachRewardListener;
import com.rapidoreach.rapidoreachsdk.RapidoReachSurveyListener;
import com.rapidoreach.rapidoreachsdk.RapidoReachSurveyAvailableListener;

public class Listeners implements RapidoReachRewardListener, RapidoReachSurveyAvailableListener, RapidoReachSurveyListener {

   @Override
    public void onRewardCenterClosed() {
      Log.i("RapidoReach", "onRewardCenterClosed");
        RapidoReachPlugin.getInstance().OnMethodCallHandler("onRewardCenterClosed",0);
    }

     @Override
    public void onRewardCenterOpened() {
        Log.i("RapidoReach", "onRewardCenterOpened");
         RapidoReachPlugin.getInstance().OnMethodCallHandler("onRewardCenterOpened",0);
    }

 @Override
    public void onReward(final int quantity) {
        Log.i("RapidoReach", "onRewardCenterOpened");
     RapidoReachPlugin.getInstance().OnMethodCallHandler("onReward", quantity);
    }

 @Override
    public void rapidoReachSurveyAvailable(final boolean surveyAvailable) {
        int survey = 0;
        if(surveyAvailable) {
            survey = 1;
        } else if (!surveyAvailable) {
           survey = 0;
        }
        Log.i("RapidoReach", "rapidoReachSurveyAvailable");
     RapidoReachPlugin.getInstance().OnMethodCallHandler("rapidoReachSurveyAvailable", survey);
    }
}