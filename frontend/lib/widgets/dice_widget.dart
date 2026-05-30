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

  @override
  Widget build(BuildContext context) {
    final canRoll = widget.isMyTurn && !widget.hasRolled;

    return GestureDetector(
      onTap: () {
        if (canRoll) {
          _animController.forward(from: 0.0);
          widget.onTap();
        }
      },
      child: AnimatedBuilder(
        animation: _animController,
        builder: (context, child) {
          // 3D rotation micro-animation
          final angle = _rotationAnim.value * pi * 2;
          final scale = 1.0 + sin(_rotationAnim.value * pi) * 0.15;

          return Transform(
            alignment: Alignment.center,
            transform: Matrix4.identity()
              ..scale(scale)
              ..rotateZ(angle),
            child: Container(
              width: 60,
              height: 60,
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(12),
                boxShadow: [
                  BoxShadow(
                    color: (canRoll ? AppColors.secondary : Colors.black).withOpacity(0.35),
                    blurRadius: canRoll ? 12 : 6,
                    spreadRadius: canRoll ? 2 : 0,
                  ),
                ],
                border: Border.all(
                  color: canRoll ? AppColors.secondary : Colors.grey.shade300,
                  width: canRoll ? 3 : 1,
                ),
              ),
              child: _buildDiceFace(widget.value),
            ),
          );
        },
      ),
    );
  }

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

  // Draw traditional Ludo dice dot patterns
  Widget _buildDiceFace(int val) {
    final dotColor = AppColors.background;
    
    // Position mappings for dots on 3x3 grids
    final dotsConfig = {
      1: [4],
      2: [0, 8],
      3: [0, 4, 8],
      4: [0, 2, 6, 8],
      5: [0, 2, 4, 6, 8],
      6: [0, 2, 3, 5, 6, 8],
    };

    final activeDots = dotsConfig[val] ?? [4];

    return Padding(
      padding: const EdgeInsets.all(8.0),
      child: GridView.builder(
        physics: const NeverScrollableScrollPhysics(),
        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: 3,
          mainAxisSpacing: 4,
          crossAxisSpacing: 4,
        ),
        itemCount: 9,
        itemBuilder: (context, index) {
          final showDot = activeDots.contains(index);
          return Center(
            child: Container(
              width: 8,
              height: 8,
              decoration: BoxDecoration(
                color: showDot ? dotColor : Colors.transparent,
                shape: BoxShape.circle,
              ),
            ),
          );
        },
      ),
    );
  }
}
