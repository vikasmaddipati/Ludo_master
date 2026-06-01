import 'package:flutter/material.dart';
import '../constants/app_colors.dart';
import '../services/voice_recognition_service.dart';
import '../services/voice_feedback_service.dart';
import '../views/voice_settings_screen.dart';
import 'voice_debug_console.dart';

class VoiceAssistantWrapper extends StatefulWidget {
  final Widget child;

  const VoiceAssistantWrapper({super.key, required this.child});

  @override
  State<VoiceAssistantWrapper> createState() => _VoiceAssistantWrapperState();
}

class _VoiceAssistantWrapperState extends State<VoiceAssistantWrapper> {
  Offset _position = const Offset(-1, -1);
  bool _isCollapsed = true;

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;
    
    // Set default initial position on screen (top-right side of screen layout)
    if (_position.dx == -1 && _position.dy == -1) {
      _position = Offset(size.width - 64, 100);
    }

    return Stack(
      children: [
        widget.child,
        Positioned(
          left: _position.dx,
          top: _position.dy,
          child: GestureDetector(
            onPanUpdate: (details) {
              setState(() {
                double newX = _position.dx + details.delta.dx;
                double newY = _position.dy + details.delta.dy;
                
                // Keep pill boundary constraints active
                double maxW = _isCollapsed ? 60.0 : 180.0;
                _position = Offset(
                  newX.clamp(10.0, size.width - maxW),
                  newY.clamp(40.0, size.height - 120.0),
                );
              });
            },
            child: VoiceAssistantStatusPill(
              isCollapsed: _isCollapsed,
              onTap: () {
                setState(() {
                  _isCollapsed = !_isCollapsed;
                });
              },
              onDoubleTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (context) => const VoiceSettingsScreen()),
                );
              },
            ),
          ),
        ),
        const VoiceDebugConsole(),
      ],
    );
  }
}

class VoiceAssistantStatusPill extends StatefulWidget {
  final bool isCollapsed;
  final VoidCallback onTap;
  final VoidCallback onDoubleTap;

  const VoiceAssistantStatusPill({
    super.key,
    required this.isCollapsed,
    required this.onTap,
    required this.onDoubleTap,
  });

  @override
  State<VoiceAssistantStatusPill> createState() => _VoiceAssistantStatusPillState();
}

class _VoiceAssistantStatusPillState extends State<VoiceAssistantStatusPill> with SingleTickerProviderStateMixin {
  late AnimationController _pulseController;
  VoiceState _state = VoiceState.offline;
  String _overlayText = "";

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1500),
    )..repeat(reverse: true);

    _state = VoiceRecognitionService.instance.state;

    // Listen to STT updates
    VoiceRecognitionService.instance.onStateChanged = (state) {
      if (mounted) {
        Future.microtask(() {
          if (mounted) {
            setState(() {
              _state = state;
            });
          }
        });
      }
    };

    // Listen to overlays
    VoiceFeedbackService.instance.onOverlayMessage = (text) {
      if (mounted) {
        Future.microtask(() {
          if (mounted) {
            setState(() {
              _overlayText = text;
            });
          }
        });
        // Auto fade out overlay text after 3 seconds
        Future.delayed(const Duration(seconds: 3), () {
          if (mounted) {
            Future.microtask(() {
              if (mounted) {
                setState(() {
                  _overlayText = "";
                });
              }
            });
          }
        });
      }
    };
  }

  @override
  void dispose() {
    _pulseController.dispose();
    super.dispose();
  }

  Color _getStateColor() {
    switch (_state) {
      case VoiceState.listening:
        return AppColors.secondary;
      case VoiceState.thinking:
        return Colors.amber;
      case VoiceState.executing:
        return Colors.purpleAccent;
      case VoiceState.speaking:
        return Colors.pinkAccent;
      case VoiceState.offline:
        return Colors.grey.shade600;
    }
  }

  String _getStateString() {
    switch (_state) {
      case VoiceState.listening:
        return "Listening";
      case VoiceState.thinking:
        return "Thinking";
      case VoiceState.executing:
        return "Running";
      case VoiceState.speaking:
        return "Speaking";
      case VoiceState.offline:
        return "Offline";
    }
  }

  IconData _getStateIcon() {
    switch (_state) {
      case VoiceState.listening:
        return Icons.mic;
      case VoiceState.thinking:
        return Icons.hourglass_empty;
      case VoiceState.executing:
        return Icons.bolt;
      case VoiceState.speaking:
        return Icons.volume_up;
      case VoiceState.offline:
        return Icons.mic_off;
    }
  }

  @override
  Widget build(BuildContext context) {
    final stateColor = _getStateColor();

    return Material(
      color: Colors.transparent,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.end,
        mainAxisSize: MainAxisSize.min,
        children: [
          // Speech Overlay Feedback Box (only shown if not collapsed)
          if (!widget.isCollapsed && _overlayText.isNotEmpty) ...[
            Container(
              margin: const EdgeInsets.only(bottom: 8),
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
              decoration: BoxDecoration(
                color: Colors.black87,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: stateColor.withValues(alpha: 0.4), width: 1),
                boxShadow: const [
                  BoxShadow(color: Colors.black38, blurRadius: 6),
                ],
              ),
              child: Text(
                _overlayText,
                style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.w600),
              ),
            ),
          ],

          // Draggable Collapsible Pill
          GestureDetector(
            onTap: widget.onTap,
            onDoubleTap: widget.onDoubleTap,
            child: AnimatedBuilder(
              animation: _pulseController,
              builder: (context, child) {
                return Container(
                  width: widget.isCollapsed ? 48 : null,
                  height: widget.isCollapsed ? 48 : null,
                  padding: widget.isCollapsed
                      ? const EdgeInsets.all(0)
                      : const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  decoration: BoxDecoration(
                    color: const Color(0xFF160F2C).withValues(alpha: 0.9),
                    borderRadius: BorderRadius.circular(24),
                    border: Border.all(color: stateColor.withValues(alpha: 0.6), width: 1.5),
                    boxShadow: [
                      BoxShadow(
                        color: stateColor.withValues(alpha: 0.2 + (_pulseController.value * 0.2)),
                        blurRadius: 10 + (_pulseController.value * 6),
                        spreadRadius: 1 + (_pulseController.value * 1.5),
                      ),
                    ],
                  ),
                  child: Center(
                    child: widget.isCollapsed
                        ? Icon(_getStateIcon(), color: Colors.white, size: 22)
                        : Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Container(
                                width: 8,
                                height: 8,
                                decoration: BoxDecoration(
                                  shape: BoxShape.circle,
                                  color: stateColor,
                                ),
                              ),
                              const SizedBox(width: 8),
                              Icon(_getStateIcon(), color: Colors.white, size: 14),
                              const SizedBox(width: 6),
                              Text(
                                _getStateString(),
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 11,
                                  fontWeight: FontWeight.bold,
                                  letterSpacing: 0.5,
                                ),
                              ),
                            ],
                          ),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}
