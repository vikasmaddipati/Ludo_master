import 'package:flutter/material.dart';
import '../constants/app_colors.dart';
import '../services/voice_assistant_service.dart';
import '../services/voice_command_history.dart';

class VoiceSettingsScreen extends StatefulWidget {
  const VoiceSettingsScreen({super.key});

  @override
  State<VoiceSettingsScreen> createState() => _VoiceSettingsScreenState();
}

class _VoiceSettingsScreenState extends State<VoiceSettingsScreen> {
  final VoiceAssistantService _service = VoiceAssistantService.instance;
  
  bool _wakeWord = false;
  double _rateLimit = 1.0;
  bool _micEnabled = true;
  
  List<VoiceLogEntry> _history = [];
  bool _isLoadingHistory = true;

  @override
  void initState() {
    super.initState();
    _loadCurrentSettings();
    _loadHistoryLogs();
  }

  void _loadCurrentSettings() async {
    await _service.loadSettings();
    if (mounted) {
      setState(() {
        _wakeWord = _service.requireWakeWord;
        _rateLimit = _service.rateLimitSeconds;
        _micEnabled = _service.isMicEnabled;
      });
    }
  }

  void _loadHistoryLogs() async {
    final logs = await VoiceCommandHistory.getLogs();
    if (mounted) {
      setState(() {
        _history = logs;
        _isLoadingHistory = false;
      });
    }
  }

  void _clearLogs() async {
    await VoiceCommandHistory.clearLogs();
    setState(() {
      _history = [];
    });
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text("Voice command history cleared successfully.")),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('Voice Assistant Settings', style: TextStyle(fontWeight: FontWeight.bold)),
        backgroundColor: AppColors.surface,
        elevation: 0,
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          physics: const BouncingScrollPhysics(),
          child: Padding(
            padding: const EdgeInsets.all(20.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // 0. MICROPHONE SWITCH CARD
                _buildSectionHeader("MICROPHONE ACTIVATION"),
                const SizedBox(height: 12),
                Container(
                  padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 16),
                  decoration: BoxDecoration(
                    color: AppColors.surface,
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: Colors.white10, width: 1),
                  ),
                  child: SwitchListTile(
                    activeColor: AppColors.secondary,
                    secondary: Icon(
                      _micEnabled ? Icons.mic : Icons.mic_off,
                      color: _micEnabled ? AppColors.secondary : Colors.grey,
                    ),
                    title: const Text("Voice Recognition Mic", style: TextStyle(fontWeight: FontWeight.bold, color: Colors.white)),
                    subtitle: Text(
                      _micEnabled ? "Microphone is ON and actively listening hands-free." : "Microphone is OFF. Always-on assistant is silenced.",
                      style: const TextStyle(color: AppColors.textSecondary, fontSize: 11),
                    ),
                    value: _micEnabled,
                    onChanged: (val) async {
                      await _service.updateMicEnabled(val);
                      setState(() => _micEnabled = val);
                    },
                  ),
                ),
                const SizedBox(height: 28),

                // 1. MODES CARD
                _buildSectionHeader("SYSTEM MODES"),
                const SizedBox(height: 12),
                Container(
                  padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
                  decoration: BoxDecoration(
                    color: AppColors.surface,
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: Colors.white10, width: 1),
                  ),
                  child: Column(
                    children: [
                      // Direct Command Mode
                      SwitchListTile(
                        activeColor: AppColors.secondary,
                        title: const Text("Direct Command Mode", style: TextStyle(fontWeight: FontWeight.bold, color: Colors.white)),
                        subtitle: const Text("Aria executes your instructions immediately without a wake word.", style: TextStyle(color: AppColors.textSecondary, fontSize: 11)),
                        value: !_wakeWord,
                        onChanged: (val) async {
                          await _service.updateWakeWordMode(!val);
                          setState(() => _wakeWord = !val);
                        },
                      ),
                      const Divider(color: Colors.white10),
                      // Wake Word Mode
                      SwitchListTile(
                        activeColor: AppColors.secondary,
                        title: const Text("Wake Word Mode", style: TextStyle(fontWeight: FontWeight.bold, color: Colors.white)),
                        subtitle: const Text("Only respond when prefixed with 'Ludo', 'Hey Ludo', or 'Ludo Master'.", style: TextStyle(color: AppColors.textSecondary, fontSize: 11)),
                        value: _wakeWord,
                        onChanged: (val) async {
                          await _service.updateWakeWordMode(val);
                          setState(() => _wakeWord = val);
                        },
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 28),

                // 2. SECURITY CONTROLS CARD
                _buildSectionHeader("SECURITY & SPAM LIMITS"),
                const SizedBox(height: 12),
                Container(
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    color: AppColors.surface,
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: Colors.white10, width: 1),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Text("Command Rate Limiter", style: TextStyle(fontWeight: FontWeight.bold, color: Colors.white)),
                          Text("${_rateLimit.toStringAsFixed(1)}s", style: const TextStyle(fontWeight: FontWeight.bold, color: AppColors.secondary)),
                        ],
                      ),
                      const SizedBox(height: 4),
                      const Text(
                        "Sets the buffer cooldown to prevent rapid voice spamming.",
                        style: TextStyle(color: AppColors.textSecondary, fontSize: 11),
                      ),
                      const SizedBox(height: 12),
                      Slider(
                        activeColor: AppColors.secondary,
                        inactiveColor: AppColors.surfaceLight,
                        min: 0.5,
                        max: 3.0,
                        divisions: 5,
                        value: _rateLimit,
                        onChanged: (val) async {
                          await _service.updateRateLimit(val);
                          setState(() => _rateLimit = val);
                        },
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 28),

                // 3. VOICE HISTORY CARD
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    _buildSectionHeader("VOICE COMMAND HISTORY"),
                    if (_history.isNotEmpty)
                      TextButton.icon(
                        onPressed: _clearLogs,
                        icon: const Icon(Icons.delete_sweep, color: AppColors.red, size: 16),
                        label: const Text("Clear Logs", style: TextStyle(color: AppColors.red, fontSize: 12, fontWeight: FontWeight.bold)),
                      ),
                  ],
                ),
                const SizedBox(height: 12),
                
                _isLoadingHistory
                    ? const Center(child: CircularProgressIndicator(color: AppColors.secondary))
                    : _history.isEmpty
                        ? Container(
                            padding: const EdgeInsets.symmetric(vertical: 40),
                            decoration: BoxDecoration(
                              color: AppColors.surface.withOpacity(0.3),
                              borderRadius: BorderRadius.circular(20),
                            ),
                            child: const Center(
                              child: Text(
                                "No voice commands recorded yet.",
                                style: TextStyle(color: AppColors.textSecondary, fontSize: 13),
                              ),
                            ),
                          )
                        : ListView.builder(
                            shrinkWrap: true,
                            physics: const NeverScrollableScrollPhysics(),
                            itemCount: _history.length,
                            itemBuilder: (context, index) {
                              final entry = _history[index];
                              return Card(
                                color: AppColors.surface,
                                margin: const EdgeInsets.symmetric(vertical: 6),
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                                borderOnForeground: true,
                                child: ListTile(
                                  contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                                  title: Text(
                                    '"${entry.text}"',
                                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: Colors.white),
                                  ),
                                  subtitle: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      const SizedBox(height: 4),
                                      Row(
                                        children: [
                                          const Icon(Icons.data_object, size: 10, color: AppColors.textSecondary),
                                          const SizedBox(width: 4),
                                          Text(
                                            "Intent: ${entry.action}",
                                            style: const TextStyle(color: AppColors.textSecondary, fontSize: 11),
                                          ),
                                        ],
                                      ),
                                      const SizedBox(height: 2),
                                      Row(
                                        children: [
                                          const Icon(Icons.access_time, size: 10, color: AppColors.textSecondary),
                                          const SizedBox(width: 4),
                                          Text(
                                            entry.timestamp,
                                            style: const TextStyle(color: AppColors.textSecondary, fontSize: 11),
                                          ),
                                        ],
                                      ),
                                    ],
                                  ),
                                  trailing: Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                    decoration: BoxDecoration(
                                      color: entry.success ? AppColors.green.withOpacity(0.15) : AppColors.red.withOpacity(0.15),
                                      borderRadius: BorderRadius.circular(8),
                                      border: Border.all(color: entry.success ? AppColors.green : AppColors.red, width: 1),
                                    ),
                                    child: Text(
                                      entry.success ? "SUCCESS" : "FAILED",
                                      style: TextStyle(
                                        color: entry.success ? AppColors.green : AppColors.red,
                                        fontSize: 9,
                                        fontWeight: FontWeight.w900,
                                      ),
                                    ),
                                  ),
                                ),
                              );
                            },
                          ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildSectionHeader(String label) {
    return Text(
      label,
      style: const TextStyle(
        fontSize: 10,
        fontWeight: FontWeight.w900,
        color: AppColors.textSecondary,
        letterSpacing: 1.2,
      ),
    );
  }
}
