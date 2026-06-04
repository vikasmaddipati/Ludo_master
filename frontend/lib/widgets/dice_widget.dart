import 'package:flutter/material.dart';
import 'dart:math';
import 'dart:async';
import '../constants/app_colors.dart';

class DiceWidget extends StatefulWidget {
  final int value;
  final bool isMyTurn;
  final bool hasRolled;
  final VoidCallback onTap;

  const DiceWidget({
    super.key,
    required this.value,
    required this.isMyTurn,
    required this.hasRolled,
    required this.onTap,
  });

  @override
  State<DiceWidget> createState() => _DiceWidgetState();
}

class _DiceWidgetState extends State<DiceWidget> with SingleTickerProviderStateMixin {
  late AnimationController _animController;
  bool _isSpinning = false;
  int _displayValue = 1;
  Timer? _cycleTimer;
  int? _targetValue;

  @override
  void initState() {
    super.initState();
    _displayValue = widget.value;
    _animController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 650),
    );
  }

  @override
  void didUpdateWidget(covariant DiceWidget oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.value != oldWidget.value) {
      if (_isSpinning) {
        // We triggered the roll, now the final value is here. Settle the animation.
        _targetValue = widget.value;
        _animController.forward(from: 0.0).then((_) {
          _stopCycling(widget.value);
          if (mounted) {
            setState(() {
              _isSpinning = false;
              _targetValue = null;
            });
          }
        });
      } else {
        // External trigger (opponent roll/bot roll). Roll visually.
        _runOpponentRoll(widget.value);
      }
    }
  }

  void _runOpponentRoll(int target) async {
    if (!mounted) return;
    setState(() {
      _isSpinning = true;
      _targetValue = target;
    });
    _startCycling();
    _animController.forward(from: 0.0);
    await Future.delayed(const Duration(milliseconds: 650));
    if (mounted) {
      _stopCycling(target);
      setState(() {
        _isSpinning = false;
        _targetValue = null;
      });
    }
  }

  void _startCycling() {
    _cycleTimer?.cancel();
    _cycleTimer = Timer.periodic(const Duration(milliseconds: 60), (timer) {
      if (mounted) {
        setState(() {
          _displayValue = Random().nextInt(6) + 1;
        });
      }
    });
  }

  void _stopCycling(int finalValue) {
    _cycleTimer?.cancel();
    if (mounted) {
      setState(() {
        _displayValue = finalValue;
      });
    }
  }

  @override
  void dispose() {
    _cycleTimer?.cancel();
    _animController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final canRoll = widget.isMyTurn && !widget.hasRolled;

    return GestureDetector(
      onTap: () {
        final actualCanRoll = canRoll && !_isSpinning;
        print("[DICE] Dice tapped. canRoll: $canRoll, isSpinning: $_isSpinning");
        if (actualCanRoll) {
          print("[ROLL_BUTTON_CLICKED] User initiated a dice roll");
          setState(() {
            _isSpinning = true;
            _targetValue = null;
          });
          _startCycling();
          _animController.repeat();
          widget.onTap(); // Send roll command immediately to server

          // Safety timeout in case of packet loss
          Future.delayed(const Duration(milliseconds: 1800), () {
            if (mounted && _isSpinning && _targetValue == null) {
              _stopCycling(widget.value);
              _animController.forward(from: 0.0);
              setState(() {
                _isSpinning = false;
              });
            }
          });
        } else if (!canRoll) {
          widget.onTap();
        }
      },
      child: TweenAnimationBuilder<double>(
        tween: Tween<double>(begin: 0.0, end: canRoll ? 1.0 : 0.0),
        duration: const Duration(milliseconds: 800),
        curve: Curves.easeInOut,
        builder: (context, glowVal, child) {
          return AnimatedBuilder(
            animation: _animController,
            builder: (context, child) {
              // 3D rotation variables
              final double angleX;
              final double angleY;
              final double angleZ;

              if (_isSpinning && _targetValue == null) {
                // Repeating spin while waiting
                final time = DateTime.now().millisecondsSinceEpoch / 150;
                angleX = time % (2 * pi);
                angleY = (time * 1.2) % (2 * pi);
                angleZ = (time * 0.8) % (2 * pi);
              } else {
                // Settle animation smoothly returning to flat 0 degrees
                final progress = 1.0 - _animController.value;
                angleX = progress * pi * 3;
                angleY = progress * pi * 3;
                angleZ = progress * pi * 2;
              }

              // Dynamic scale bump during rolling
              final scale = 1.0 + (sin(_animController.value * pi) * (_isSpinning ? 0.18 : 0.0));

              // Pulsing glow size based on the canRoll glow value
              final pulseGlow = glowVal * (1.0 + sin(DateTime.now().millisecondsSinceEpoch / 150) * 0.12);

              return Transform(
                alignment: Alignment.center,
                transform: Matrix4.identity()
                  ..setEntry(3, 2, 0.002) // Perspective factor
                  ..scale(scale)
                  ..rotateX(angleX)
                  ..rotateY(angleY)
                  ..rotateZ(angleZ),
                child: Container(
                  width: 68,
                  height: 68,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(16),
                    boxShadow: [
                      // Active neon pulse halo glow
                      if (canRoll)
                        BoxShadow(
                          color: AppColors.secondary.withOpacity(0.4 * pulseGlow),
                          blurRadius: 16 * pulseGlow,
                          spreadRadius: 4 * pulseGlow,
                        ),
                      // Soft drop shadow
                      BoxShadow(
                        color: Colors.black.withOpacity(0.35),
                        blurRadius: _isSpinning ? 18 : 14,
                        spreadRadius: _isSpinning ? 2 : 1,
                        offset: _isSpinning ? const Offset(0, 8) : const Offset(0, 5),
                      ),
                    ],
                  ),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(16),
                    child: Stack(
                      children: [
                        // Glassmorphic 3D embossed dice base
                        Container(
                          decoration: BoxDecoration(
                            gradient: const LinearGradient(
                              colors: [Colors.white, Color(0xFFE2E8F0)],
                              begin: Alignment.topLeft,
                              end: Alignment.bottomRight,
                            ),
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(
                              color: canRoll
                                  ? AppColors.secondary.withOpacity(0.9)
                                  : Colors.white.withOpacity(0.8),
                              width: canRoll ? 3.0 : 1.5,
                            ),
                          ),
                          child: _buildDiceFace(_displayValue, canRoll),
                        ),
                        // Premium Glossy / Specular overlay reflection
                        Positioned(
                          top: 0,
                          left: 0,
                          right: 0,
                          height: 30,
                          child: Container(
                            decoration: BoxDecoration(
                              gradient: LinearGradient(
                                colors: [
                                  Colors.white.withOpacity(0.45),
                                  Colors.white.withOpacity(0.0),
                                ],
                                begin: Alignment.topCenter,
                                end: Alignment.bottomCenter,
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              );
            },
          );
        },
      ),
    );
  }

  // Draw modern debossed 3D Ludo dice dot patterns
  Widget _buildDiceFace(int val, bool isActive) {
    // Dots configuration for a traditional 3x3 layout
    final dotsConfig = {
      1: [4],
      2: [0, 8],
      3: [0, 4, 8],
      4: [0, 2, 6, 8],
      5: [0, 2, 4, 6, 8],
      6: [0, 2, 3, 5, 6, 8],
    };

    final activeDots = dotsConfig[val] ?? [4];
    final activeDotColor = isActive ? AppColors.primary : AppColors.background;

    return Padding(
      padding: const EdgeInsets.all(10.0),
      child: GridView.builder(
        physics: const NeverScrollableScrollPhysics(),
        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: 3,
          mainAxisSpacing: 5,
          crossAxisSpacing: 5,
        ),
        itemCount: 9,
        itemBuilder: (context, index) {
          final showDot = activeDots.contains(index);
          if (!showDot) return const SizedBox.shrink();

          return Center(
            child: Container(
              width: 10,
              height: 10,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: RadialGradient(
                  colors: [
                    activeDotColor.withOpacity(0.7),
                    activeDotColor,
                  ],
                  center: const Alignment(-0.2, -0.2),
                  radius: 0.65,
                ),
                boxShadow: [
                  // Inner shadow effect
                  BoxShadow(
                    color: Colors.black.withOpacity(0.4),
                    offset: const Offset(0.5, 0.5),
                    blurRadius: 1,
                  ),
                  // Outer premium glowing outline ring
                  BoxShadow(
                    color: Colors.white.withOpacity(0.9),
                    offset: const Offset(-0.5, -0.5),
                    blurRadius: 1,
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}

