import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:rapidoreach/RapidoReach.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const MyApp());
}

enum DemoTab { dashboard, rewards, logs }

class LogEntry {
  final String id;
  final int timestampMs;
  final String level; // info | event | error
  final String title;
  final String? request;
  final String? response;

  LogEntry({
    required this.id,
    required this.timestampMs,
    required this.level,
    required this.title,
    this.request,
    this.response,
  });
}

class RewardEntry {
  final String id;
  final int timestampMs;
  final int amount;
  final String placement;
  final String note;
  final String source;

  RewardEntry({
    required this.id,
    required this.timestampMs,
    required this.amount,
    required this.placement,
    required this.note,
    required this.source,
  });
}

class MyApp extends StatefulWidget {
  const MyApp({super.key});

  @override
  State<MyApp> createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> {
  DemoTab _tab = DemoTab.dashboard;

  String _apiKey = '';
  String _userId = Platform.isIOS ? 'DEMO_USER_ID' : 'ANDROID_TEST_ID';
  String _placementTag = 'default';
  String? _baseUrl;

  late final TextEditingController _apiKeyController;
  late final TextEditingController _userIdController;
  late final TextEditingController _placementController;
  late final TextEditingController _customParamsController;
  late final TextEditingController _attributesController;
  late final TextEditingController _questionIdController;
  late final TextEditingController _questionAnswerController;

  bool _sdkInitialized = false;
  bool? _surveyAvailable;
  String? _lastSurveyId;

  bool _usingAltTheme = false;
  String _attributesJson =
      const JsonEncoder.withIndent('  ').convert(<String, dynamic>{
    'qa_timestamp': null, // filled in initState
    'qa_flag': 'default',
  });
  String _customParamsJson =
      const JsonEncoder.withIndent('  ').convert(<String, dynamic>{'qa': true});

  String _questionId = '';
  String _questionAnswer = 'yes';

  final List<LogEntry> _logs = <LogEntry>[];
  final List<RewardEntry> _rewards = <RewardEntry>[];
  int _idCounter = 0;

  String _makeId() => '${DateTime.now().millisecondsSinceEpoch}-${_idCounter++}';

  int get _rewardTotal =>
      _rewards.fold<int>(0, (sum, r) => sum + r.amount);

  String _formatTimestamp(int ms) =>
      DateTime.fromMillisecondsSinceEpoch(ms).toLocal().toString();

  void _addLog({
    required String level,
    required String title,
    String? request,
    String? response,
  }) {
    setState(() {
      _logs.insert(
        0,
        LogEntry(
          id: _makeId(),
          timestampMs: DateTime.now().millisecondsSinceEpoch,
          level: level,
          title: title,
          request: request,
          response: response,
        ),
      );
    });
  }

  void _addReward({
    required int amount,
    required String placement,
    required String note,
    required String source,
  }) {
    setState(() {
      _rewards.insert(
        0,
        RewardEntry(
          id: _makeId(),
          timestampMs: DateTime.now().millisecondsSinceEpoch,
          amount: amount,
          placement: placement,
          note: note,
          source: source,
        ),
      );
    });
  }

  Map<String, dynamic> _tryParseJsonObject(String text) {
    final trimmed = text.trim();
    if (trimmed.isEmpty) return <String, dynamic>{};
    final decoded = jsonDecode(trimmed);
    if (decoded is Map) return Map<String, dynamic>.from(decoded);
    return <String, dynamic>{};
  }

  Future<void> _applyTheme(bool alt) async {
    if (alt) {
      await RapidoReach.instance.setNavBarColor(color: '#FF7043');
      await RapidoReach.instance.setNavBarTextColor(textColor: '#000000');
      await RapidoReach.instance.setNavBarText(text: 'QA Theme');
    } else {
      await RapidoReach.instance.setNavBarColor(color: '#211548');
      await RapidoReach.instance.setNavBarTextColor(textColor: '#FFFFFF');
      await RapidoReach.instance.setNavBarText(text: 'RapidoReach');
    }
  }

  Future<void> _initialize() async {
    final key = _apiKey.trim();
    final uid = _userId.trim();
    if (key.isEmpty || uid.isEmpty) {
      _showSnack('Enter an API key and user id first.');
      return;
    }

    _addLog(
      level: 'info',
      title: 'Initialize SDK',
      request:
          'init(apiKey: ${key.length > 6 ? '${key.substring(0, 6)}…' : key}, userId: $uid)',
    );

    try {
      await RapidoReach.instance.init(apiToken: key, userId: uid);
      await _applyTheme(_usingAltTheme);
      setState(() {
        _sdkInitialized = true;
      });
      _addLog(level: 'info', title: 'SDK initialized');

      final available = await RapidoReach.instance.isSurveyAvailable();
      setState(() {
        _surveyAvailable = available;
      });
    } catch (e) {
      _addLog(level: 'error', title: 'Initialization failed', response: '$e');
      _showSnack('Init failed: $e');
    }
  }

  Future<void> _updateUserIdentifier() async {
    final uid = _userId.trim();
    if (uid.isEmpty) {
      _showSnack('Enter a user id first.');
      return;
    }
    _addLog(level: 'info', title: 'setUserIdentifier', request: uid);
    try {
      await RapidoReach.instance.setUserIdentifier(userId: uid);
      _addLog(level: 'info', title: 'User identifier updated');
    } catch (e) {
      _addLog(
          level: 'error', title: 'setUserIdentifier failed', response: '$e');
      _showSnack('setUserIdentifier failed: $e');
    }
  }

  Future<void> _openOfferwall() async {
    _addLog(level: 'info', title: 'showRewardCenter');
    try {
      await RapidoReach.instance.showRewardCenter();
    } catch (e) {
      _addLog(level: 'error', title: 'showRewardCenter failed', response: '$e');
      _showSnack('showRewardCenter failed: $e');
    }
  }

  Future<void> _checkPlacement() async {
    final tag = _placementTag.trim();
    if (tag.isEmpty) {
      _showSnack('Enter a placement tag first.');
      return;
    }
    _addLog(
      level: 'info',
      title: 'Check Placement',
      request: 'canShowContent(tag: $tag)',
    );
    try {
      final canShow = await RapidoReach.instance.canShowContent(tag: tag);
      _addLog(
          level: 'info',
          title: canShow ? 'Placement ready' : 'Placement not ready');
      _showSnack(canShow ? 'Placement ready' : 'Placement not ready');
    } catch (e) {
      _addLog(level: 'error', title: 'Check Placement failed', response: '$e');
      _showSnack('Check Placement failed: $e');
    }
  }

  Future<void> _getPlacementDetails() async {
    final tag = _placementTag.trim();
    if (tag.isEmpty) {
      _showSnack('Enter a placement tag first.');
      return;
    }
    _addLog(
      level: 'info',
      title: 'Get Placement Details',
      request: 'getPlacementDetails(tag: $tag)',
    );
    try {
      final details = await RapidoReach.instance.getPlacementDetails(tag: tag);
      final pretty = const JsonEncoder.withIndent('  ').convert(details);
      _addLog(level: 'info', title: 'Placement details received', response: pretty);
      await _showDialog('Placement details', pretty);
    } catch (e) {
      _addLog(
          level: 'error', title: 'Get Placement Details failed', response: '$e');
      _showSnack('Get Placement Details failed: $e');
    }
  }

  Future<void> _listSurveys() async {
    final tag = _placementTag.trim();
    if (tag.isEmpty) {
      _showSnack('Enter a placement tag first.');
      return;
    }
    _addLog(level: 'info', title: 'List Surveys', request: 'listSurveys(tag: $tag)');
    try {
      final surveys = await RapidoReach.instance.listSurveys(tag: tag);
      String? firstId;
      if (surveys.isNotEmpty && surveys.first is Map) {
        final first = Map<String, dynamic>.from(surveys.first as Map);
        final dynamic id = first['surveyIdentifier'] ??
            first['survey_id'] ??
            first['surveyId'] ??
            first['surveyID'];
        if (id is String) firstId = id;
      }
      setState(() {
        _lastSurveyId = firstId;
      });
      _addLog(
        level: 'info',
        title: 'Surveys: ${surveys.length}',
        response: firstId != null ? 'First survey id: $firstId' : 'No surveys',
      );
    } catch (e) {
      setState(() {
        _lastSurveyId = null;
      });
      _addLog(level: 'error', title: 'List Surveys failed', response: '$e');
      _showSnack('List Surveys failed: $e');
    }
  }

  Future<void> _showLastSurvey() async {
    final tag = _placementTag.trim();
    final surveyId = (_lastSurveyId ?? '').trim();
    if (tag.isEmpty) {
      _showSnack('Enter a placement tag first.');
      return;
    }
    if (surveyId.isEmpty) {
      _showSnack('List surveys first to get a survey id.');
      return;
    }
    _addLog(
      level: 'info',
      title: 'Show Survey',
      request: 'showSurvey(tag: $tag, surveyId: $surveyId)',
    );
    try {
      final params = _tryParseJsonObject(_customParamsJson);
      await RapidoReach.instance
          .showSurvey(tag: tag, surveyId: surveyId, customParams: params);
      _addLog(level: 'info', title: 'Show Survey triggered');
    } catch (e) {
      _addLog(level: 'error', title: 'Show Survey failed', response: '$e');
      _showSnack('Show Survey failed: $e');
    }
  }

  Future<void> _sendAttributes() async {
    _addLog(level: 'info', title: 'Send Attributes', request: 'sendUserAttributes(clearPrevious: false)');
    try {
      final attrs = _tryParseJsonObject(_attributesJson);
      await RapidoReach.instance.sendUserAttributes(attributes: attrs);
      _addLog(
          level: 'info',
          title: 'Attributes synced',
          response: const JsonEncoder.withIndent('  ').convert(attrs));
      _showSnack('Attributes synced');
    } catch (e) {
      _addLog(level: 'error', title: 'Send Attributes failed', response: '$e');
      _showSnack('Send Attributes failed: $e');
    }
  }

  Future<void> _toggleTheme() async {
    final next = !_usingAltTheme;
    setState(() {
      _usingAltTheme = next;
    });
    await _applyTheme(next);
    _addLog(level: 'info', title: next ? 'Theme: alt' : 'Theme: default');
  }

  Future<void> _fetchQuickQuestions() async {
    final tag = _placementTag.trim();
    if (tag.isEmpty) {
      _showSnack('Enter a placement tag first.');
      return;
    }
    _addLog(level: 'info', title: 'Fetch QQ', request: 'fetchQuickQuestions(tag: $tag)');
    try {
      final payload = await RapidoReach.instance.fetchQuickQuestions(tag: tag);
      final pretty = const JsonEncoder.withIndent('  ').convert(payload);
      _addLog(level: 'info', title: 'Quick questions received', response: pretty);
      await _showDialog('Quick questions', pretty);
    } catch (e) {
      _addLog(level: 'error', title: 'Fetch QQ failed', response: '$e');
      _showSnack('Fetch QQ failed: $e');
    }
  }

  Future<void> _answerQuickQuestion() async {
    final tag = _placementTag.trim();
    final qid = _questionId.trim();
    if (tag.isEmpty) {
      _showSnack('Enter a placement tag first.');
      return;
    }
    if (qid.isEmpty) {
      _showSnack('Enter a quick question id first.');
      return;
    }
    _addLog(level: 'info', title: 'Answer QQ', request: 'answerQuickQuestion(tag: $tag, questionId: $qid)');
    try {
      final payload = await RapidoReach.instance.answerQuickQuestion(
        tag: tag,
        questionId: qid,
        answer: _questionAnswer,
      );
      final pretty = const JsonEncoder.withIndent('  ').convert(payload);
      _addLog(level: 'info', title: 'Quick question answered', response: pretty);
      _showSnack('Quick question answered');
    } catch (e) {
      _addLog(level: 'error', title: 'Answer QQ failed', response: '$e');
      _showSnack('Answer QQ failed: $e');
    }
  }

  void _clearLogs() {
    setState(() {
      _logs.clear();
    });
  }

  void _clearRewards() {
    setState(() {
      _rewards.clear();
    });
  }

  void _simulateReward() {
    _addReward(
      amount: 25,
      placement: _placementTag,
      note: 'Manual QA bonus',
      source: 'Example app',
    );
    _addLog(level: 'event', title: 'Simulated reward: +25');
  }

  void _showSnack(String text) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(text)));
  }

  Future<void> _showDialog(String title, String body) async {
    if (!mounted) return;
    await showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(title),
        content: SingleChildScrollView(child: Text(body)),
        actions: <Widget>[
          TextButton(onPressed: () => Navigator.of(ctx).pop(), child: const Text('Close')),
        ],
      ),
    );
  }

  @override
  void initState() {
    super.initState();

    _attributesJson = const JsonEncoder.withIndent('  ').convert(<String, dynamic>{
      'qa_timestamp': DateTime.now().millisecondsSinceEpoch,
      'qa_flag': 'default',
    });

    _apiKeyController = TextEditingController(text: _apiKey);
    _userIdController = TextEditingController(text: _userId);
    _placementController = TextEditingController(text: _placementTag);
    _customParamsController = TextEditingController(text: _customParamsJson);
    _attributesController = TextEditingController(text: _attributesJson);
    _questionIdController = TextEditingController(text: _questionId);
    _questionAnswerController = TextEditingController(text: _questionAnswer);

    RapidoReach.instance.setOnRewardListener((amount) {
      final safe = amount ?? 0;
      _addReward(
        amount: safe,
        placement: _placementTag,
        note: 'SDK reward callback',
        source: 'RapidoReach SDK',
      );
      _addLog(level: 'event', title: 'onReward: +$safe');
    });

    RapidoReach.instance.setRewardCenterOpened(() {
      _addLog(level: 'event', title: 'onRewardCenterOpened');
    });

    RapidoReach.instance.setRewardCenterClosed(() {
      _addLog(level: 'event', title: 'onRewardCenterClosed');
    });

    RapidoReach.instance.setSurveyAvaiableListener((survey) {
      final normalized = (survey ?? 0) != 0;
      setState(() {
        _surveyAvailable = normalized;
      });
      _addLog(level: 'event', title: 'rapidoreachSurveyAvailable: $normalized');
    });

    RapidoReach.instance.setNetworkLogListener((payload) {
      final name = payload['name']?.toString() ?? 'SDK';
      final method = payload['method']?.toString();
      final url = payload['url']?.toString();
      final requestBody = payload['requestBody']?.toString();
      final responseBody = payload['responseBody']?.toString();
      final error = payload['error']?.toString();

      final requestParts = <String>[
        if (method != null && url != null) '$method $url',
        if (requestBody != null && requestBody.isNotEmpty) 'Body: $requestBody',
      ];

      _addLog(
        level: error != null ? 'error' : 'info',
        title: method == 'LOG' ? name : 'NET $name',
        request: requestParts.isNotEmpty ? requestParts.join('\n') : null,
        response: error ?? responseBody,
      );
    });

    RapidoReach.instance.setOnErrorListener((message) {
      if (message.trim().isEmpty) return;
      _addLog(level: 'error', title: 'onError', response: message);
    });

    RapidoReach.instance.enableNetworkLogging(enabled: true);
    RapidoReach.instance.getBaseUrl().then((value) {
      setState(() {
        _baseUrl = value;
      });
    }).catchError((_) {
      setState(() {
        _baseUrl = null;
      });
    });
  }

  @override
  void dispose() {
    _apiKeyController.dispose();
    _userIdController.dispose();
    _placementController.dispose();
    _customParamsController.dispose();
    _attributesController.dispose();
    _questionIdController.dispose();
    _questionAnswerController.dispose();
    super.dispose();
  }

  Widget _card({required String title, required List<Widget> children}) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFF151518),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFF2A2A2E), width: 0.5),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Text(title, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: Colors.white)),
          const SizedBox(height: 10),
          ...children,
        ],
      ),
    );
  }

  Widget _label(String text) => Padding(
        padding: const EdgeInsets.only(bottom: 6),
        child: Text(text, style: const TextStyle(fontSize: 12, color: Color(0xFF9AA0A6))),
      );

  Widget _kvRow(String label, String value) => Padding(
        padding: const EdgeInsets.only(bottom: 6),
        child: Row(
          children: <Widget>[
            Expanded(child: Text(label, style: const TextStyle(fontSize: 13, color: Color(0xFF9AA0A6)))),
            const SizedBox(width: 12),
            Expanded(
              child: Text(value, textAlign: TextAlign.right, style: const TextStyle(fontSize: 13, color: Colors.white)),
            ),
          ],
        ),
      );

  Widget _dashboard() {
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 90),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          const Text(
            'RapidoReach SDK Smoke Test (Flutter)',
            style: TextStyle(fontSize: 20, fontWeight: FontWeight.w700, color: Colors.white),
          ),
          const SizedBox(height: 12),
          _card(
            title: 'Setup',
            children: <Widget>[
              _label('API Key'),
              TextField(
                controller: _apiKeyController,
                onChanged: (v) => _apiKey = v,
                decoration: const InputDecoration(
                  hintText: 'YOUR_API_KEY',
                  filled: true,
                  fillColor: Color(0xFF0F0F12),
                  border: OutlineInputBorder(),
                ),
                style: const TextStyle(color: Colors.white),
              ),
              const SizedBox(height: 10),
              _label('User Id'),
              TextField(
                controller: _userIdController,
                onChanged: (v) => _userId = v,
                decoration: const InputDecoration(
                  hintText: 'YOUR_USER_ID',
                  filled: true,
                  fillColor: Color(0xFF0F0F12),
                  border: OutlineInputBorder(),
                ),
                style: const TextStyle(color: Colors.white),
              ),
              const SizedBox(height: 10),
              _label('Placement Tag'),
              TextField(
                controller: _placementController,
                onChanged: (v) => _placementTag = v,
                decoration: const InputDecoration(
                  hintText: 'default',
                  filled: true,
                  fillColor: Color(0xFF0F0F12),
                  border: OutlineInputBorder(),
                ),
                style: const TextStyle(color: Colors.white),
              ),
              const SizedBox(height: 10),
              Wrap(
                spacing: 10,
                runSpacing: 10,
                children: <Widget>[
                  ElevatedButton(
                    onPressed: _initialize,
                    child: const Text('Initialize'),
                  ),
                  OutlinedButton(
                    onPressed: _updateUserIdentifier,
                    child: const Text('Set User Id'),
                  ),
                ],
              ),
            ],
          ),
          _card(
            title: 'Status',
            children: <Widget>[
              _kvRow('Platform', Platform.isIOS ? 'ios' : 'android'),
              _kvRow('Base URL', _baseUrl ?? '—'),
              _kvRow('SDK Initialized', _sdkInitialized ? 'Yes' : 'No'),
              _kvRow(
                'Survey Available',
                _surveyAvailable == null
                    ? 'Unknown'
                    : (_surveyAvailable! ? 'Yes' : 'No'),
              ),
              _kvRow('Last Survey Id', _lastSurveyId ?? '—'),
              _kvRow('Lifetime Rewards', '$_rewardTotal coins'),
            ],
          ),
          _card(
            title: 'Offerwall',
            children: <Widget>[
              Wrap(
                spacing: 10,
                runSpacing: 10,
                children: <Widget>[
                  ElevatedButton(
                    onPressed: !_sdkInitialized || _surveyAvailable == false
                        ? null
                        : _openOfferwall,
                    child: const Text('Open Offerwall'),
                  ),
                  OutlinedButton(
                    onPressed: _toggleTheme,
                    child: const Text('Toggle Theme'),
                  ),
                ],
              ),
            ],
          ),
          _card(
            title: 'Placements & Surveys',
            children: <Widget>[
              Wrap(
                spacing: 10,
                runSpacing: 10,
                children: <Widget>[
                  OutlinedButton(
                    onPressed: _checkPlacement,
                    child: const Text('Check Placement'),
                  ),
                  OutlinedButton(
                    onPressed: _getPlacementDetails,
                    child: const Text('Details'),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              Wrap(
                spacing: 10,
                runSpacing: 10,
                children: <Widget>[
                  OutlinedButton(
                    onPressed: _listSurveys,
                    child: const Text('List Surveys'),
                  ),
                  ElevatedButton(
                    onPressed: _lastSurveyId == null ? null : _showLastSurvey,
                    child: const Text('Show Last Survey'),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              _label('Custom Params (JSON)'),
              TextField(
                controller: _customParamsController,
                maxLines: 6,
                onChanged: (v) => _customParamsJson = v,
                decoration: const InputDecoration(
                  hintText: '{}',
                  filled: true,
                  fillColor: Color(0xFF0F0F12),
                  border: OutlineInputBorder(),
                ),
                style: const TextStyle(color: Colors.white, fontFamily: 'monospace'),
              ),
            ],
          ),
          _card(
            title: 'Quick Questions',
            children: <Widget>[
              Wrap(
                spacing: 10,
                runSpacing: 10,
                children: <Widget>[
                  OutlinedButton(
                    onPressed: _fetchQuickQuestions,
                    child: const Text('Fetch QQ'),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              _label('Question Id'),
              TextField(
                controller: _questionIdController,
                onChanged: (v) => _questionId = v,
                decoration: const InputDecoration(
                  hintText: 'question_id',
                  filled: true,
                  fillColor: Color(0xFF0F0F12),
                  border: OutlineInputBorder(),
                ),
                style: const TextStyle(color: Colors.white),
              ),
              const SizedBox(height: 10),
              _label('Answer'),
              TextField(
                controller: _questionAnswerController,
                onChanged: (v) => _questionAnswer = v,
                decoration: const InputDecoration(
                  hintText: 'yes',
                  filled: true,
                  fillColor: Color(0xFF0F0F12),
                  border: OutlineInputBorder(),
                ),
                style: const TextStyle(color: Colors.white),
              ),
              const SizedBox(height: 10),
              ElevatedButton(
                onPressed: _answerQuickQuestion,
                child: const Text('Answer QQ'),
              ),
            ],
          ),
          _card(
            title: 'User Attributes',
            children: <Widget>[
              _label('Attributes (JSON)'),
              TextField(
                controller: _attributesController,
                maxLines: 6,
                onChanged: (v) => _attributesJson = v,
                decoration: const InputDecoration(
                  hintText: '{"key":"value"}',
                  filled: true,
                  fillColor: Color(0xFF0F0F12),
                  border: OutlineInputBorder(),
                ),
                style: const TextStyle(color: Colors.white, fontFamily: 'monospace'),
              ),
              const SizedBox(height: 10),
              ElevatedButton(
                onPressed: _sendAttributes,
                child: const Text('Send Attributes'),
              ),
            ],
          ),
          _card(
            title: 'Notes',
            children: const <Widget>[
              Text(
                'This app mirrors the React Native example: initialize the SDK, watch survey availability events, open the offerwall, test placements/surveys/quick questions, and record rewards/logs.',
                style: TextStyle(fontSize: 14, color: Color(0xFFD6D6D6), height: 1.4),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _rewardsTab() {
    return Column(
      children: <Widget>[
        Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              const Text('Rewards', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700, color: Colors.white)),
              const SizedBox(height: 6),
              Text('$_rewardTotal coins total', style: const TextStyle(color: Color(0xFFD6D6D6))),
              const SizedBox(height: 10),
              Wrap(
                spacing: 10,
                children: <Widget>[
                  OutlinedButton(onPressed: _simulateReward, child: const Text('Simulate +25')),
                  OutlinedButton(onPressed: _clearRewards, child: const Text('Clear')),
                ],
              ),
            ],
          ),
        ),
        Expanded(
          child: ListView.builder(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 90),
            itemCount: _rewards.isEmpty ? 1 : _rewards.length,
            itemBuilder: (context, index) {
              if (_rewards.isEmpty) {
                return const Text('No rewards yet. Complete a survey.',
                    style: TextStyle(color: Color(0xFF9AA0A6)));
              }
              final item = _rewards[index];
              return Container(
                margin: const EdgeInsets.only(bottom: 10),
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: const Color(0xFF151518),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: const Color(0xFF2A2A2E), width: 0.5),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Text('+${item.amount} coins · ${item.placement}',
                        style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w700)),
                    const SizedBox(height: 4),
                    Text('${item.note} · ${_formatTimestamp(item.timestampMs)}',
                        style: const TextStyle(color: Color(0xFF9AA0A6))),
                  ],
                ),
              );
            },
          ),
        ),
      ],
    );
  }

  Widget _logsTab() {
    return Column(
      children: <Widget>[
        Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: <Widget>[
              const Text('Logs', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700, color: Colors.white)),
              OutlinedButton(onPressed: _clearLogs, child: const Text('Clear')),
            ],
          ),
        ),
        Expanded(
          child: ListView.builder(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 90),
            itemCount: _logs.isEmpty ? 1 : _logs.length,
            itemBuilder: (context, index) {
              if (_logs.isEmpty) {
                return const Text('No logs yet. Trigger an action.',
                    style: TextStyle(color: Color(0xFF9AA0A6)));
              }
              final item = _logs[index];
              return Container(
                margin: const EdgeInsets.only(bottom: 10),
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: const Color(0xFF151518),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: const Color(0xFF2A2A2E), width: 0.5),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Text('[${item.level}] ${item.title}',
                        style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w700)),
                    const SizedBox(height: 4),
                    Text(_formatTimestamp(item.timestampMs),
                        style: const TextStyle(color: Color(0xFF9AA0A6))),
                    if (item.request != null && item.request!.isNotEmpty) ...<Widget>[
                      const SizedBox(height: 6),
                      Text('Request: ${item.request!}',
                          style: const TextStyle(color: Color(0xFFB7BBC0), fontFamily: 'monospace', fontSize: 12)),
                    ],
                    if (item.response != null && item.response!.isNotEmpty) ...<Widget>[
                      const SizedBox(height: 6),
                      Text('Response: ${item.response!}',
                          style: const TextStyle(color: Color(0xFFB7BBC0), fontFamily: 'monospace', fontSize: 12)),
                    ],
                  ],
                ),
              );
            },
          ),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final Widget body;
    if (_tab == DemoTab.dashboard) {
      body = _dashboard();
    } else if (_tab == DemoTab.rewards) {
      body = _rewardsTab();
    } else {
      body = _logsTab();
    }

    return MaterialApp(
      theme: ThemeData.dark().copyWith(
        scaffoldBackgroundColor: const Color(0xFF0B0B0C),
        snackBarTheme: const SnackBarThemeData(backgroundColor: Color(0xFF23232A)),
      ),
      home: Scaffold(
        body: SafeArea(
          child: body,
        ),
        bottomNavigationBar: BottomNavigationBar(
          currentIndex: _tab.index,
          onTap: (idx) => setState(() => _tab = DemoTab.values[idx]),
          items: const <BottomNavigationBarItem>[
            BottomNavigationBarItem(icon: Icon(Icons.dashboard), label: 'Dashboard'),
            BottomNavigationBarItem(icon: Icon(Icons.card_giftcard), label: 'Rewards'),
            BottomNavigationBarItem(icon: Icon(Icons.list), label: 'Logs'),
          ],
        ),
      ),
    );
  }
}
