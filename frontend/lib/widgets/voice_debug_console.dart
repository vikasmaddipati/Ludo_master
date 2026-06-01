import 'dart:ui';
import 'package:flutter/material.dart';
import '../constants/app_colors.dart';
import '../services/global_voice_manager.dart';
import '../services/voice_command_registry.dart';
import '../services/intent_engine.dart';

class VoiceDebugConsole extends StatefulWidget {
  const VoiceDebugConsole({super.key});

  @override
  State<VoiceDebugConsole> createState() => _VoiceDebugConsoleState();
}

class _VoiceDebugConsoleState extends State<VoiceDebugConsole>
    with TickerProviderStateMixin {
  late AnimationController _slideController;
  late TabController _tabController;
  bool _isOpen = false;
  bool _isRunningTests = false;
  List<Map<String, dynamic>> _testResults = [];

  // Representative test phrases for each intent
  static const List<Map<String, String>> _testCases = [
    {"phrase": "open profile", "expectedIntent": "NAVIGATE_PROFILE"},
    {"phrase": "leaderboard", "expectedIntent": "NAVIGATE_LEADERBOARD"},
    {"phrase": "claim daily reward", "expectedIntent": "CLAIM_DAILY_REWARD"},
    {"phrase": "open settings", "expectedIntent": "NAVIGATE_SETTINGS"},
    {"phrase": "show friends", "expectedIntent": "SHOW_FRIENDS"},
    {"phrase": "create room", "expectedIntent": "CREATE_ROOM"},
    {"phrase": "create private room", "expectedIntent": "CREATE_ROOM_PRIVATE"},
    {"phrase": "create public room", "expectedIntent": "CREATE_ROOM_PUBLIC"},
    {"phrase": "join room", "expectedIntent": "JOIN_ROOM"},
    {"phrase": "join with room code 123456", "expectedIntent": "JOIN_ROOM_CODE"},
    {"phrase": "start match", "expectedIntent": "START_MATCH"},
    {"phrase": "start multiplayer", "expectedIntent": "START_MATCH"},
    {"phrase": "leave room", "expectedIntent": "LEAVE_ROOM"},
    {"phrase": "add bot", "expectedIntent": "ADD_BOT"},
    {"phrase": "ready", "expectedIntent": "TOGGLE_READY"},
    {"phrase": "invite rahul", "expectedIntent": "INVITE_FRIEND"},
    {"phrase": "roll dice", "expectedIntent": "ROLL_DICE"},
    {"phrase": "dice fenko", "expectedIntent": "ROLL_DICE"},
    {"phrase": "token one", "expectedIntent": "SELECT_TOKEN_INDEX"},
    {"phrase": "token 2", "expectedIntent": "SELECT_TOKEN_INDEX"},
    {"phrase": "red token", "expectedIntent": "SELECT_TOKEN"},
    {"phrase": "send emoji laughing", "expectedIntent": "SEND_EMOJI"},
    {"phrase": "open chat", "expectedIntent": "OPEN_CHAT"},
    {"phrase": "join voice chat", "expectedIntent": "JOIN_VOICE_CHAT"},
    {"phrase": "mute mic", "expectedIntent": "MUTE_MIC"},
    {"phrase": "unmute mic", "expectedIntent": "UNMUTE_MIC"},
    {"phrase": "add friend rahul", "expectedIntent": "ADD_FRIEND"},
    {"phrase": "accept friend request", "expectedIntent": "ACCEPT_FRIEND"},
    {"phrase": "reject friend request", "expectedIntent": "REJECT_FRIEND"},
    {"phrase": "show coins", "expectedIntent": "GET_COINS"},
    {"phrase": "show wins", "expectedIntent": "GET_WINS"},
  ];

  @override
  void initState() {
    super.initState();
    _slideController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 320),
    );
    _tabController = TabController(length: 3, vsync: this);
  }

  @override
  void dispose() {
    _slideController.dispose();
    _tabController.dispose();
    super.dispose();
  }

  void _toggleConsole() {
    setState(() => _isOpen = !_isOpen);
    if (_isOpen) {
      _slideController.forward();
    } else {
      _slideController.reverse();
    }
  }

  Future<void> _runTestSuite() async {
    setState(() {
      _isRunningTests = true;
      _testResults = [];
    });

    final results = <Map<String, dynamic>>[];

    for (final tc in _testCases) {
      // Short delay for visual effect
      await Future.delayed(const Duration(milliseconds: 80));

      final phrase = tc['phrase']!;
      final expectedIntent = tc['expectedIntent']!;

      // Step 1: Parse intent
      final intent = IntentEngine.parseIntent(phrase);
      final recognized = intent != null;
      final intentMatch = recognized && intent.action == expectedIntent;

      // Step 2: Check registry handler
      final hasHandler = recognized
          ? VoiceCommandRegistry.instance.hasHandler(intent.action)
          : false;

      final pass = intentMatch && hasHandler;

      results.add({
        "phrase": phrase,
        "expectedIntent": expectedIntent,
        "detectedIntent": intent?.action ?? "NOT_RECOGNIZED",
        "intentMatch": intentMatch,
        "hasHandler": hasHandler,
        "pass": pass,
        "reason": !recognized
            ? "Intent not recognized"
            : !intentMatch
                ? "Intent mismatch: got '${intent.action}'"
                : !hasHandler
                    ? "No handler registered for '${intent.action}'"
                    : "OK",
      });

      if (mounted) {
        setState(() => _testResults = List.from(results));
      }
    }

    setState(() => _isRunningTests = false);
  }

  @override
  Widget build(BuildContext context) {
    final passCount = _testResults.where((r) => r['pass'] == true).length;
    final failCount = _testResults.where((r) => r['pass'] == false).length;
    final totalTests = _testResults.length;

    return AnimatedBuilder(
      animation: _slideController,
      builder: (context, child) {
        final heightOffset = (1 - _slideController.value) * 380.0;
        return Positioned(
          bottom: 0,
          left: 0,
          right: 0,
          child: Transform.translate(
            offset: Offset(0, heightOffset),
            child: child,
          ),
        );
      },
      child: GestureDetector(
        onVerticalDragUpdate: (details) {
          if (details.delta.dy > 5 && _isOpen) _toggleConsole();
          if (details.delta.dy < -5 && !_isOpen) _toggleConsole();
        },
        child: ClipRRect(
          borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
            child: Container(
              height: 440,
              width: double.infinity,
              decoration: BoxDecoration(
                color: const Color(0xF00E0A24),
                borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
                border: Border.all(
                    color: AppColors.primary.withOpacity(0.25), width: 1.5),
                boxShadow: const [
                  BoxShadow(
                      color: Colors.black54, blurRadius: 24, offset: Offset(0, -6)),
                ],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // ── Header / pull handle ──
                  InkWell(
                    onTap: _toggleConsole,
                    child: Container(
                      padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
                      child: Column(
                        children: [
                          Container(
                            width: 36,
                            height: 4,
                            decoration: BoxDecoration(
                                color: Colors.white24,
                                borderRadius: BorderRadius.circular(2)),
                          ),
                          const SizedBox(height: 6),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Row(children: [
                                const Icon(Icons.developer_mode,
                                    color: AppColors.secondary, size: 14),
                                const SizedBox(width: 6),
                                const Text(
                                  "VOICE DEBUG DASHBOARD",
                                  style: TextStyle(
                                      color: AppColors.secondary,
                                      fontSize: 9,
                                      fontWeight: FontWeight.w900,
                                      letterSpacing: 1.2),
                                ),
                              ]),
                              Row(children: [
                                _statusPill(
                                    "CTX",
                                    GlobalVoiceManager.instance.activeScreen
                                        .toUpperCase()),
                                const SizedBox(width: 6),
                                if (totalTests > 0)
                                  _statusPill(
                                      "PASS",
                                      "$passCount/$totalTests",
                                      color: passCount == totalTests
                                          ? AppColors.green
                                          : AppColors.red),
                              ]),
                            ],
                          ),
                          const SizedBox(height: 6),
                        ],
                      ),
                    ),
                  ),

                  // ── Tab bar ──
                  TabBar(
                    controller: _tabController,
                    indicatorColor: AppColors.secondary,
                    labelColor: AppColors.secondary,
                    unselectedLabelColor: Colors.white38,
                    labelStyle: const TextStyle(
                        fontSize: 10, fontWeight: FontWeight.bold),
                    tabs: const [
                      Tab(text: "LIVE LOGS"),
                      Tab(text: "TEST RUNNER"),
                      Tab(text: "REGISTRY"),
                    ],
                  ),

                  const Divider(color: Colors.white10, height: 1),

                  // ── Tab content ──
                  Expanded(
                    child: TabBarView(
                      controller: _tabController,
                      children: [
                        _buildLiveLogsTab(),
                        _buildTestRunnerTab(passCount, failCount),
                        _buildRegistryTab(),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  // ── TAB 1: Live Execution Logs ──
  Widget _buildLiveLogsTab() {
    return StreamBuilder<int>(
      stream:
          Stream<int>.periodic(const Duration(milliseconds: 400), (x) => x),
      builder: (context, snapshot) {
        final logs = List.from(GlobalVoiceManager.executionLogs.reversed);
        if (logs.isEmpty) {
          return const Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.mic, color: AppColors.secondary, size: 32),
                SizedBox(height: 8),
                Text(
                  "Voice assistant is active.\nSay a command to see resolution logs.",
                  textAlign: TextAlign.center,
                  style: TextStyle(color: AppColors.textSecondary, fontSize: 11),
                ),
              ],
            ),
          );
        }
        return ListView.builder(
          physics: const BouncingScrollPhysics(),
          padding: const EdgeInsets.all(10),
          itemCount: logs.length,
          itemBuilder: (context, index) {
            final log = logs[index];
            final isSuccess = log['status'] == "SUCCESS";
            final isContext = log['text'] == "CONTEXT_SHIFT";
            final accent = isSuccess
                ? AppColors.green
                : isContext
                    ? AppColors.secondary
                    : AppColors.red;

            return Container(
              margin: const EdgeInsets.symmetric(vertical: 3),
              padding: const EdgeInsets.all(9),
              decoration: BoxDecoration(
                color: accent.withOpacity(0.05),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: accent.withOpacity(0.2)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        "[${log['time']}]  ${log['intent']}",
                        style: TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 10,
                            color: accent),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 6, vertical: 1),
                        decoration: BoxDecoration(
                            color: accent.withOpacity(0.15),
                            borderRadius: BorderRadius.circular(6)),
                        child: Text(log['status'],
                            style: TextStyle(
                                fontSize: 8,
                                fontWeight: FontWeight.bold,
                                color: accent)),
                      ),
                    ],
                  ),
                  const SizedBox(height: 3),
                  Text(
                    "\"${log['text']}\"",
                    style: const TextStyle(color: Colors.white70, fontSize: 10),
                  ),
                  if ((log['reason'] as String).isNotEmpty) ...[
                    const SizedBox(height: 2),
                    Text(
                      "⚠ ${log['reason']}",
                      style: const TextStyle(
                          color: AppColors.textSecondary, fontSize: 9),
                    ),
                  ],
                ],
              ),
            );
          },
        );
      },
    );
  }

  // ── TAB 2: Test Runner ──
  Widget _buildTestRunnerTab(int passCount, int failCount) {
    return Column(
      children: [
        // Run button and stats row
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          child: Row(
            children: [
              Expanded(
                child: ElevatedButton.icon(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: _isRunningTests
                        ? AppColors.surfaceLight
                        : AppColors.primary,
                    padding: const EdgeInsets.symmetric(vertical: 10),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12)),
                  ),
                  icon: _isRunningTests
                      ? const SizedBox(
                          width: 14,
                          height: 14,
                          child: CircularProgressIndicator(
                              color: AppColors.secondary, strokeWidth: 2))
                      : const Icon(Icons.play_arrow,
                          color: Colors.white, size: 18),
                  label: Text(
                    _isRunningTests
                        ? "Running ${_testResults.length}/${_testCases.length}..."
                        : "▶  Run Full Test Suite",
                    style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                        fontSize: 12),
                  ),
                  onPressed: _isRunningTests ? null : _runTestSuite,
                ),
              ),
              if (_testResults.isNotEmpty) ...[
                const SizedBox(width: 8),
                _miniStatBadge(passCount.toString(), AppColors.green, "PASS"),
                const SizedBox(width: 4),
                _miniStatBadge(failCount.toString(), AppColors.red, "FAIL"),
              ]
            ],
          ),
        ),
        // Results list
        Expanded(
          child: _testResults.isEmpty
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.science_outlined,
                          color: AppColors.secondary.withOpacity(0.5),
                          size: 36),
                      const SizedBox(height: 8),
                      Text(
                        "${_testCases.length} test cases ready.\nPress 'Run Full Test Suite' to begin.",
                        textAlign: TextAlign.center,
                        style: const TextStyle(
                            color: AppColors.textSecondary, fontSize: 11),
                      ),
                    ],
                  ),
                )
              : ListView.builder(
                  physics: const BouncingScrollPhysics(),
                  padding: const EdgeInsets.fromLTRB(10, 0, 10, 10),
                  itemCount: _testResults.length,
                  itemBuilder: (context, index) {
                    final r = _testResults[index];
                    final pass = r['pass'] == true;
                    final accent =
                        pass ? AppColors.green : AppColors.red;

                    return Container(
                      margin: const EdgeInsets.symmetric(vertical: 3),
                      padding: const EdgeInsets.all(9),
                      decoration: BoxDecoration(
                        color: accent.withOpacity(0.05),
                        borderRadius: BorderRadius.circular(10),
                        border:
                            Border.all(color: accent.withOpacity(0.25)),
                      ),
                      child: Row(
                        children: [
                          Icon(
                              pass
                                  ? Icons.check_circle
                                  : Icons.cancel,
                              color: accent,
                              size: 16),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  "\"${r['phrase']}\"",
                                  style: const TextStyle(
                                      color: Colors.white,
                                      fontSize: 10,
                                      fontWeight: FontWeight.bold),
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  "Expected: ${r['expectedIntent']}  →  Got: ${r['detectedIntent']}",
                                  style: TextStyle(
                                      color: accent.withOpacity(0.8),
                                      fontSize: 9),
                                ),
                                if (!pass) ...[
                                  const SizedBox(height: 2),
                                  Text(
                                    "⚠ ${r['reason']}",
                                    style: const TextStyle(
                                        color: AppColors.textSecondary,
                                        fontSize: 8),
                                  ),
                                ],
                              ],
                            ),
                          ),
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 5, vertical: 2),
                            decoration: BoxDecoration(
                                color: accent.withOpacity(0.2),
                                borderRadius: BorderRadius.circular(5)),
                            child: Text(
                              pass ? "PASS" : "FAIL",
                              style: TextStyle(
                                  fontSize: 8,
                                  fontWeight: FontWeight.bold,
                                  color: accent),
                            ),
                          ),
                        ],
                      ),
                    );
                  },
                ),
        ),
      ],
    );
  }

  // ── TAB 3: Command Registry ──
  Widget _buildRegistryTab() {
    final commands = VoiceCommandRegistry.instance.commands;
    final contextGroups = <String, List<VoiceCommand>>{};
    for (final cmd in commands) {
      contextGroups.putIfAbsent(cmd.allowedContext, () => []).add(cmd);
    }
    final contexts = contextGroups.keys.toList()..sort();

    return ListView.builder(
      physics: const BouncingScrollPhysics(),
      padding: const EdgeInsets.all(10),
      itemCount: contexts.length,
      itemBuilder: (context, i) {
        final ctx = contexts[i];
        final cmds = contextGroups[ctx]!;
        final ctxColor = _contextColor(ctx);

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 6),
              child: Row(children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                      color: ctxColor.withOpacity(0.15),
                      borderRadius: BorderRadius.circular(6),
                      border: Border.all(color: ctxColor.withOpacity(0.3))),
                  child: Text(
                    ctx.toUpperCase(),
                    style: TextStyle(
                        color: ctxColor,
                        fontSize: 9,
                        fontWeight: FontWeight.w900,
                        letterSpacing: 0.8),
                  ),
                ),
                const SizedBox(width: 8),
                Text("${cmds.length} commands",
                    style: const TextStyle(
                        color: AppColors.textSecondary, fontSize: 9)),
              ]),
            ),
            ...cmds.map((cmd) {
              final hasHandler =
                  VoiceCommandRegistry.instance.hasHandler(cmd.intent);
              return Container(
                margin: const EdgeInsets.only(bottom: 4),
                padding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
                decoration: BoxDecoration(
                  color: Colors.black26,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(
                      color: (hasHandler ? AppColors.green : AppColors.red)
                          .withOpacity(0.2)),
                ),
                child: Row(children: [
                  Icon(
                    hasHandler ? Icons.check : Icons.warning,
                    size: 12,
                    color: hasHandler ? AppColors.green : AppColors.red,
                  ),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(cmd.intent,
                              style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 10,
                                  fontWeight: FontWeight.bold)),
                          Text(
                            cmd.phrases.take(2).join(" / "),
                            style: const TextStyle(
                                color: AppColors.textSecondary, fontSize: 8),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ]),
                  ),
                  Text(
                    hasHandler ? "WIRED" : "NO HANDLER",
                    style: TextStyle(
                        color: hasHandler ? AppColors.green : AppColors.red,
                        fontSize: 8,
                        fontWeight: FontWeight.bold),
                  ),
                ]),
              );
            }),
            const SizedBox(height: 4),
          ],
        );
      },
    );
  }

  Color _contextColor(String ctx) {
    switch (ctx) {
      case 'home':
        return AppColors.primary;
      case 'lobby':
        return AppColors.secondary;
      case 'game':
        return AppColors.green;
      case 'friends':
        return Colors.pinkAccent;
      default:
        return Colors.white54;
    }
  }

  Widget _statusPill(String label, String value, {Color? color}) {
    final c = color ?? Colors.white54;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
      decoration: BoxDecoration(
          color: c.withOpacity(0.12),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: c.withOpacity(0.3))),
      child: Text(
        "$label: $value",
        style: TextStyle(
            color: c, fontSize: 8, fontWeight: FontWeight.bold),
      ),
    );
  }

  Widget _miniStatBadge(String value, Color color, String label) {
    return Column(children: [
      Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        decoration: BoxDecoration(
            color: color.withOpacity(0.15),
            borderRadius: BorderRadius.circular(8)),
        child: Text(value,
            style: TextStyle(
                color: color, fontSize: 12, fontWeight: FontWeight.bold)),
      ),
      Text(label,
          style: TextStyle(
              color: color.withOpacity(0.7),
              fontSize: 7,
              fontWeight: FontWeight.bold)),
    ]);
  }
}
