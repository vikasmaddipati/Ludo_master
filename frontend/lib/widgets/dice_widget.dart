import 'package:flutter/material.dart';
import 'dart:math';
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
  late Animation<double> _rotationAnim;
  bool _isSpinning = false;

  @override
  void initState() {
    super.initState();
    _animController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 600),
    );

    _rotationAnim = CurvedAnimation(
      parent: _animController,
      curve: Curves.easeInOutBack,
    );

    _animController.addStatusListener((status) {
      if (status == AnimationStatus.completed) {
        print("[DICE] Animation completed.");
        if (_isSpinning) {
          setState(() {
            _isSpinning = false;
          });
          print("[DICE] Triggering game state roll update after animation finishes.");
          widget.onTap();
        }
      }
    });
  }

  @override
  void didUpdateWidget(covariant DiceWidget oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.value != oldWidget.value) {
      _animController.forward(from: 0.0);
    }
  }

  @override
  void dispose() {
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
          print("[DICE] Animation started");
          setState(() {
            _isSpinning = true;
          });
          _animController.forward(from: 0.0);
        } else if (!canRoll) {
          // Only trigger onTap (error feedback) if it's not our turn or already rolled
          // Do nothing if it's currently spinning to prevent duplicate events
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
              // 3D rotation & scale micro-animation
              final angle = _rotationAnim.value * pi * 2;
              final scale = 1.0 + sin(_rotationAnim.value * pi) * 0.15;

              // Pulsing glow size based on the canRoll glow value
              final pulseGlow = glowVal * (1.0 + sin(DateTime.now().millisecondsSinceEpoch / 150) * 0.12);

              return Transform(
                alignment: Alignment.center,
                transform: Matrix4.identity()
                  ..scale(scale)
                  ..rotateZ(angle),
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
                        color: Colors.black.withOpacity(0.4),
                        blurRadius: 10,
                        offset: const Offset(0, 5),
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
                          child: _buildDiceFace(widget.value, canRoll),
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

