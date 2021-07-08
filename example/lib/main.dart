import 'package:flutter/material.dart';
import 'package:rapidoreach/RapidoReach.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(MyApp());
}

class MyApp extends StatefulWidget {
  @override
  _MyAppState createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> {
  @override
  void initState() {
    RapidoReach.instance.init(apiToken: 'YOUR_APP_API_KEY', userId: 'ANDROID_TEST_ID');
    RapidoReach.instance.setOnRewardListener(onRapidoReachReward);
    RapidoReach.instance
        .setRewardCenterClosed(onRapidoReachRewardCenterClosed);
    RapidoReach.instance
        .setRewardCenterOpened(onRapidoReachRewardCenterOpened);
    RapidoReach.instance
        .setSurveyAvaiableListener(onRapidoReachSurveyAvailable);
    RapidoReach.instance.setNavBarText(text: 'RapidoReach');
    RapidoReach.instance.setNavBarColor(color: '#211548');   
    RapidoReach.instance.setNavBarTextColor(text_color: '#FFFFFF');         
    super.initState();
  }

  void onRapidoReachReward(int quantity) {
    print('TR: $quantity');
  }

  void onRapidoReachSurveyAvailable(int survey) {
    print('TR: $survey');
  }

  void onRapidoReachRewardCenterClosed() {
    print('TR: closed');
  }

  void onRapidoReachRewardCenterOpened() {
    print('TR: opened');
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      home: Scaffold(
        appBar: AppBar(
          title: const Text('Plugin example app'),
        ),
        body: Center(
            child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: <Widget>[
            RaisedButton(
              child: Text("Launch RapidoReach"),
              onPressed: () => RapidoReach.instance.show(),
            ),
            RaisedButton(
              child: Text("Launch RapidoReach Placement"),
              onPressed: () =>
                  RapidoReach.instance.show(),
            )
          ],
        )),
      ),
    );
  }
}
