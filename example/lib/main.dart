import 'package:flutter/material.dart';
import 'package:rapidoreach/RapidoReach.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const MyApp());
}

class MyApp extends StatefulWidget {
  const MyApp({Key? key}) : super(key: key);

  @override
  _MyAppState createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> {
  @override
  void initState() {
    RapidoReach.instance
        .init(apiToken: 'e8ad9ecc9dd75f140cd662565da0954e', userId: '22992929');
    RapidoReach.instance.setOnRewardListener(onRapidoReachReward);
    RapidoReach.instance.setRewardCenterClosed(onRapidoReachRewardCenterClosed);
    RapidoReach.instance.setRewardCenterOpened(onRapidoReachRewardCenterOpened);
    RapidoReach.instance
        .setSurveyAvaiableListener(onRapidoReachSurveyAvailable);
    RapidoReach.instance.setNavBarText(text: 'RapidoReach');
    RapidoReach.instance.setNavBarColor(color: '#211548');
    RapidoReach.instance.setNavBarTextColor(textColor: '#FFFFFF');
    super.initState();
  }

  void onRapidoReachReward(int? quantity) {
    debugPrint('ROR: $quantity');
  }

  void onRapidoReachSurveyAvailable(int? survey) {
    debugPrint('ROR: $survey');
  }

  void onRapidoReachRewardCenterClosed() {
    debugPrint('ROR: closed');
  }

  void onRapidoReachRewardCenterOpened() {
    debugPrint('ROR: opened');
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
            ElevatedButton(
              child: const Text("Launch RapidoReach"),
              onPressed: () => RapidoReach.instance.show(),
            ),
            ElevatedButton(
              child: const Text("Launch RapidoReach Placement"),
              onPressed: () => RapidoReach.instance.show(),
            )
          ],
        )),
      ),
    );
  }
}
