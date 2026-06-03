import 'dart:async';
import 'package:flutter/material.dart';
import '../constants/app_colors.dart';
import '../services/socket_service.dart';
import '../services/livekit_service.dart';
import '../services/accessibility_service.dart';

class DiagnosticsScreen extends StatefulWidget {
  const DiagnosticsScreen({super.key});

  @override
  State<DiagnosticsScreen> createState() => _DiagnosticsScreenState();
}

class _DiagnosticsScreenState extends State<DiagnosticsScreen> {
  final TextEditingController _urlController = TextEditingController();
  late Timer _refreshTimer;

  // Real-time statistics counters
  bool _socketConnected = false;
  double _latency = 0.0;
  int _msgsSent = 0;
  int _msgsRecv = 0;
  int _emojisSent = 0;
  int _emojisRecv = 0;
  int _reconnects = 0;
  String _liveKitStatus = 'Disconnected';

  @override
  void initState() {
    super.initState();
    _urlController.text = SocketService.serverUrl;
    
    // Announce diagnostics entry
    AccessibilityService.instance.announceScreen("Developer Network Diagnostics");

    _updateStats();
    // Periodically update diagnostics numbers every 1 second
    _refreshTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (mounted) {
        setState(() {
          _updateStats();
        });
      }
    });
  }

  void _updateStats() {
    _socketConnected = SocketService.instance.isConnected;
    _latency = SocketService.instance.latencyMs;
    _msgsSent = SocketService.instance.messagesSent;
    _msgsRecv = SocketService.instance.messagesReceived;
    _emojisSent = SocketService.instance.emojisSent;
    _emojisRecv = SocketService.instance.emojisReceived;
    _reconnects = SocketService.instance.reconnectsCount;
    _liveKitStatus = LiveKitService.instance.connectionStatusNotifier.value;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text(
          'Developer Diagnostics',
          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: Colors.white),
        ),
        backgroundColor: AppColors.surface,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.white),
          onPressed: () {
            AccessibilityService.instance.triggerHaptic(intensity: 'light');
            Navigator.pop(context);
          },
        ),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          physics: const BouncingScrollPhysics(),
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Futuristic glow info warning
              Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: Colors.amber.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: Colors.amber.withOpacity(0.3)),
                ),
                child: const Row(
                  children: [
                    Icon(Icons.warning_amber_rounded, color: Colors.amber, size: 22),
                    SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        'WARNING: Overriding server addresses will disrupt active room synchronization. Use only for local environment routing.',
                        style: TextStyle(color: Colors.amber, fontSize: 11, fontWeight: FontWeight.bold),
                      ),
                    )
                  ],
                ),
              ),
              const SizedBox(height: 24),

              // Server URL Override Panel
              _buildSectionHeader("Server IP Override"),
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.all(18),
                decoration: BoxDecoration(
                  color: AppColors.surface,
                  borderRadius: BorderRadius.circular(24),
                  border: Border.all(color: Colors.white.withOpacity(0.06), width: 1.5),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    const Text(
                      'Target Node.js Server URL:',
                      style: TextStyle(color: AppColors.textSecondary, fontSize: 12, fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 10),
                    TextField(
                      controller: _urlController,
                      style: const TextStyle(color: Colors.white, fontSize: 14),
                      decoration: InputDecoration(
                        hintText: 'e.g. http://192.168.1.13:3000',
                        hintStyle: const TextStyle(color: AppColors.textSecondary),
                        fillColor: AppColors.surfaceLight,
                        filled: true,
                        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(14),
                          borderSide: BorderSide.none,
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(14),
                          borderSide: const BorderSide(color: AppColors.secondary, width: 1),
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),
                    SizedBox(
                      height: 46,
                      child: ElevatedButton(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.secondary,
                          foregroundColor: Colors.black,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                          elevation: 3,
                        ),
                        onPressed: _saveAndReconnect,
                        child: const Text(
                          'SAVE & OVERRIDE RECONNECT',
                          style: TextStyle(fontWeight: FontWeight.w900, fontSize: 12, letterSpacing: 0.5),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 28),

              // Network Connection Health Dashboard
              _buildSectionHeader("Connection Metrics"),
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.all(18),
                decoration: BoxDecoration(
                  color: AppColors.surface,
                  borderRadius: BorderRadius.circular(24),
                  border: Border.all(color: Colors.white.withOpacity(0.06), width: 1.5),
                ),
                child: Column(
                  children: [
                    _buildMetricRow(
                      icon: Icons.wifi,
                      label: "Socket Connected",
                      value: _socketConnected ? "CONNECTED" : "DISCONNECTED",
                      color: _socketConnected ? AppColors.green : AppColors.red,
                    ),
                    const Divider(color: Colors.white10, height: 24),
                    _buildMetricRow(
                      icon: Icons.speed,
                      label: "Socket Latency",
                      value: _socketConnected ? "${_latency.toInt()} ms" : "N/A",
                      color: _latency < 80 ? AppColors.green : (_latency < 200 ? Colors.amber : AppColors.red),
                    ),
                    const Divider(color: Colors.white10, height: 24),
                    _buildMetricRow(
                      icon: Icons.sync_problem,
                      label: "Reconnect Triggers",
                      value: "$_reconnects occurrences",
                      color: _reconnects == 0 ? AppColors.green : Colors.amber,
                    ),
                    const Divider(color: Colors.white10, height: 24),
                    _buildMetricRow(
                      icon: Icons.keyboard_voice,
                      label: "LiveKit Room Status",
                      value: _liveKitStatus.toUpperCase(),
                      color: _liveKitStatus == 'Connected' ? AppColors.secondary : Colors.amber,
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 28),

              // Packet Statistics counters
              _buildSectionHeader("Packet counters"),
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.all(18),
                decoration: BoxDecoration(
                  color: AppColors.surface,
                  borderRadius: BorderRadius.circular(24),
                  border: Border.all(color: Colors.white.withOpacity(0.06), width: 1.5),
                ),
                child: Column(
                  children: [
                    _buildCounterRow(Icons.mail_outline, "Texts Sent", _msgsSent),
                    const Divider(color: Colors.white10, height: 20),
                    _buildCounterRow(Icons.mark_email_read_outlined, "Texts Received", _msgsRecv),
                    const Divider(color: Colors.white10, height: 20),
                    _buildCounterRow(Icons.emoji_emotions_outlined, "Emojis Sent", _emojisSent),
                    const Divider(color: Colors.white10, height: 20),
                    _buildCounterRow(Icons.insert_emoticon_outlined, "Emojis Received", _emojisRecv),
                  ],
                ),
              ),
              const SizedBox(height: 20),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSectionHeader(String label) {
    return Padding(
      padding: const EdgeInsets.only(left: 6),
      child: Text(
        label.toUpperCase(),
        style: const TextStyle(
          fontSize: 10,
          fontWeight: FontWeight.w900,
          color: AppColors.textSecondary,
          letterSpacing: 1.2,
        ),
      ),
    );
  }

  Widget _buildMetricRow({
    required IconData icon,
    required String label,
    required String value,
    required Color color,
  }) {
    return Row(
      children: [
        Icon(icon, color: AppColors.textSecondary, size: 18),
        const SizedBox(width: 12),
        Text(
          label,
          style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 13),
        ),
        const Spacer(),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
          decoration: BoxDecoration(
            color: color.withOpacity(0.1),
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: color.withOpacity(0.3)),
          ),
          child: Text(
            value,
            style: TextStyle(color: color, fontSize: 11, fontWeight: FontWeight.w900, letterSpacing: 0.5),
          ),
        ),
      ],
    );
  }

  Widget _buildCounterRow(IconData icon, String label, int count) {
    return Row(
      children: [
        Icon(icon, color: AppColors.textSecondary, size: 18),
        const SizedBox(width: 12),
        Text(
          label,
          style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 13),
        ),
        const Spacer(),
        Text(
          "$count",
          style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w900, fontSize: 14),
        ),
      ],
    );
  }

  void _saveAndReconnect() async {
    final inputUrl = _urlController.text.trim();
    if (inputUrl.isEmpty) return;

    AccessibilityService.instance.triggerHaptic(intensity: 'heavy');
    AccessibilityService.instance.speak("Updating server URL override");

    try {
      await SocketService.instance.updateServerUrl(inputUrl);
      
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Server URL Override successfully updated to: $inputUrl'),
          backgroundColor: AppColors.secondary,
          behavior: SnackBarBehavior.floating,
        ),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Failed to update URL: $e'),
          backgroundColor: AppColors.red,
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  @override
  void dispose() {
    _urlController.dispose();
    _refreshTimer.cancel();
    super.dispose();
  }
}
