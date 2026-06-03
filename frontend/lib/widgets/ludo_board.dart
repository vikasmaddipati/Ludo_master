import 'package:flutter/material.dart';
import '../constants/app_colors.dart';
import '../models/game_room_model.dart';
import '../services/accessibility_service.dart';

class LudoBoard extends StatelessWidget {
  final GameRoomModel room;
  final String myColor;
  final List<int> validTokensToMove;
  final Function(int) onTokenTap;

  const LudoBoard({
    super.key,
    required this.room,
    required this.myColor,
    required this.validTokensToMove,
    required this.onTokenTap,
  });

  @override
  Widget build(BuildContext context) {
    return AspectRatio(
      aspectRatio: 1,
      child: Container(
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(20),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.5),
              blurRadius: 20,
              offset: const Offset(0, 10),
            ),
          ],
        ),
        child: GridView.builder(
          physics: const NeverScrollableScrollPhysics(),
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 15,
          ),
          itemCount: 225, // 15 * 15 cells
          itemBuilder: (context, index) {
            final row = index ~/ 15;
            final col = index % 15;

            // 1. Big Quadrant Bases (6x6 corners)
            if (row < 6 && col < 6) return _buildHomeBase(AppColors.red, 'red', row, col);
            if (row < 6 && col > 8) return _buildHomeBase(AppColors.green, 'green', row, col);
            if (row > 8 && col < 6) return _buildHomeBase(AppColors.blue, 'blue', row, col);
            if (row > 8 && col > 8) return _buildHomeBase(AppColors.yellow, 'yellow', row, col);

            // 2. Center Goal Zone (3x3 center)
            if (row >= 6 && row <= 8 && col >= 6 && col <= 8) {
              return _buildCenterGoal(row, col);
            }

            // 3. Grid Paths & Tracks (Remaining cells)
            return _buildPathCell(row, col);
          },
        ),
      ),
    );
  }

  // Large corner base housing un-spawned tokens
  Widget _buildHomeBase(Color color, String colorKey, int row, int col) {
    bool isInnerBox = false;
    bool isPocket = false;
    
    if (colorKey == 'red') {
      isInnerBox = row >= 1 && row <= 4 && col >= 1 && col <= 4;
      isPocket = (row == 2 || row == 3) && (col == 2 || col == 3);
    } else if (colorKey == 'green') {
      isInnerBox = row >= 1 && row <= 4 && col >= 10 && col <= 13;
      isPocket = (row == 2 || row == 3) && (col == 11 || col == 12);
    } else if (colorKey == 'blue') {
      isInnerBox = row >= 10 && row <= 13 && col >= 1 && col <= 4;
      isPocket = (row == 11 || row == 12) && (col == 2 || col == 3);
    } else if (colorKey == 'yellow') {
      isInnerBox = row >= 10 && row <= 13 && col >= 10 && col <= 13;
      isPocket = (row == 11 || row == 12) && (col == 11 || col == 12);
    }

    Color cellBgColor = isInnerBox ? AppColors.surface : color;
    Gradient? baseGradient;
    
    if (!isInnerBox) {
      if (colorKey == 'red') baseGradient = AppColors.boardRedGradient;
      if (colorKey == 'green') baseGradient = AppColors.boardGreenGradient;
      if (colorKey == 'yellow') baseGradient = AppColors.boardYellowGradient;
      if (colorKey == 'blue') baseGradient = AppColors.boardBlueGradient;
    }
    
    return Container(
      decoration: BoxDecoration(
        color: baseGradient == null ? cellBgColor : null,
        gradient: baseGradient,
        border: Border.all(
          color: isInnerBox ? Colors.white10 : color.withValues(alpha: 0.2),
          width: 0.3,
        ),
      ),
      child: Center(
        child: isPocket
            ? Container(
                width: 20,
                height: 20,
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.1),
                  shape: BoxShape.circle,
                  border: Border.all(color: color.withValues(alpha: 0.6), width: 1.5),
                  boxShadow: [
                    BoxShadow(
                      color: color.withValues(alpha: 0.2),
                      blurRadius: 4,
                    )
                  ],
                ),
                child: Center(
                  child: _renderTokensInBase(colorKey, row, col),
                ),
              )
            : const SizedBox.shrink(),
      ),
    );
  }

  // Draw target goal triangles in the center
  Widget _buildCenterGoal(int row, int col) {
    Color cellColor = AppColors.surfaceLight;
    Gradient? goalGradient;
    
    if (row == 7 && col == 7) {
      cellColor = Colors.white;
    } else {
      if (row == 6) goalGradient = AppColors.boardGreenGradient;
      else if (row == 8) goalGradient = AppColors.boardBlueGradient;
      else if (col == 6) goalGradient = AppColors.boardRedGradient;
      else if (col == 8) goalGradient = AppColors.boardYellowGradient;
    }

    return Container(
      decoration: BoxDecoration(
        color: goalGradient == null ? cellColor : null,
        gradient: goalGradient,
        border: Border.all(color: AppColors.background, width: 0.5),
      ),
      child: Center(
        child: _renderTokensAtGoal(row, col),
      ),
    );
  }

  // Path grid cell layouts with specialized safe stars
  Widget _buildPathCell(int row, int col) {
    Color? cellColor;
    bool isSafe = false;

    // Home Stretches
    if (row == 7 && col >= 1 && col <= 5) cellColor = AppColors.red;
    else if (row == 7 && col >= 9 && col <= 13) cellColor = AppColors.yellow;
    else if (col == 7 && row >= 1 && row <= 5) cellColor = AppColors.green;
    else if (col == 7 && row >= 9 && row <= 13) cellColor = AppColors.blue;

    // Starting points
    else if (row == 6 && col == 1) { cellColor = AppColors.red; isSafe = true; }
    else if (row == 1 && col == 8) { cellColor = AppColors.green; isSafe = true; }
    else if (row == 8 && col == 13) { cellColor = AppColors.yellow; isSafe = true; }
    else if (row == 13 && col == 6) { cellColor = AppColors.blue; isSafe = true; }

    // Safe indices on main tracks
    else if ((row == 8 && col == 2) || (row == 6 && col == 12) || (row == 2 && col == 6) || (row == 12 && col == 8)) {
      isSafe = true;
    }

    return Container(
      decoration: BoxDecoration(
        color: cellColor ?? AppColors.surfaceLight,
        border: Border.all(color: AppColors.background, width: 0.5),
        boxShadow: isSafe
            ? [
                BoxShadow(
                  color: (cellColor ?? Colors.white).withValues(alpha: 0.15),
                  blurRadius: 4,
                )
              ]
            : null,
      ),
      child: Stack(
        alignment: Alignment.center,
        children: [
          if (isSafe)
            Icon(
              Icons.star,
              size: 14,
              color: Colors.white.withValues(alpha: 0.6),
            ),
          _renderTokensOnTrack(row, col),
        ],
      ),
    );
  }

  // Render tokens located inside the player home bases (position = -1)
  Widget _renderTokensInBase(String color, int row, int col) {
    int targetTokenId = -1;
    if (color == 'red') {
      if (row == 2 && col == 2) targetTokenId = 0;
      if (row == 2 && col == 3) targetTokenId = 1;
      if (row == 3 && col == 2) targetTokenId = 2;
      if (row == 3 && col == 3) targetTokenId = 3;
    } else if (color == 'green') {
      if (row == 2 && col == 11) targetTokenId = 0;
      if (row == 2 && col == 12) targetTokenId = 1;
      if (row == 3 && col == 11) targetTokenId = 2;
      if (row == 3 && col == 12) targetTokenId = 3;
    } else if (color == 'blue') {
      if (row == 11 && col == 2) targetTokenId = 0;
      if (row == 11 && col == 3) targetTokenId = 1;
      if (row == 12 && col == 2) targetTokenId = 2;
      if (row == 12 && col == 3) targetTokenId = 3;
    } else if (color == 'yellow') {
      if (row == 11 && col == 11) targetTokenId = 0;
      if (row == 11 && col == 12) targetTokenId = 1;
      if (row == 12 && col == 11) targetTokenId = 2;
      if (row == 12 && col == 12) targetTokenId = 3;
    }

    if (targetTokenId == -1) return const SizedBox.shrink();

    final hasToken = room.tokens.any((t) => t.color == color && t.tokenId == targetTokenId && t.position == -1);
    if (!hasToken) return const SizedBox.shrink();

    return _buildInteractiveToken(color, targetTokenId);
  }

  // Render tokens currently on path steps (position 0-56)
  Widget _renderTokensOnTrack(int row, int col) {
    final tokensHere = <LudoTokenModel>[];

    for (var token in room.tokens) {
      if (token.position >= 0 && token.position < 57) {
        final coords = getGridCoords(token.color, token.position);
        if (coords[0] == row && coords[1] == col) {
          tokensHere.add(token);
        }
      }
    }

    if (tokensHere.isEmpty) return const SizedBox.shrink();

    return Stack(
      children: tokensHere.map((token) {
        return Align(
          alignment: _getStackAlignment(tokensHere.indexOf(token), tokensHere.length),
          child: SizedBox(
            width: tokensHere.length > 1 ? 14 : 22,
            height: tokensHere.length > 1 ? 14 : 22,
            child: _buildInteractiveToken(token.color, token.tokenId),
          ),
        );
      }).toList(),
    );
  }

  // Render tokens at Goal Center (position = 99)
  Widget _renderTokensAtGoal(int row, int col) {
    String? filterColor;
    if (row == 7 && col == 6) filterColor = 'red';
    if (row == 6 && col == 7) filterColor = 'green';
    if (row == 7 && col == 8) filterColor = 'yellow';
    if (row == 8 && col == 7) filterColor = 'blue';

    if (filterColor == null) return const SizedBox.shrink();

    final goals = room.tokens.where((t) => t.color == filterColor && t.position == 99).toList();
    if (goals.isEmpty) return const SizedBox.shrink();

    return Wrap(
      spacing: 2,
      runSpacing: 2,
      children: goals.map((t) => Container(
        width: 10,
        height: 10,
        decoration: const BoxDecoration(
          color: Colors.white,
          shape: BoxShape.circle,
        ),
      )).toList(),
    );
  }

  // Interactive glowing token wrapper supporting click triggers
  Widget _buildInteractiveToken(String color, int tokenId) {
    final canMove = room.turn == myColor && color == myColor && validTokensToMove.contains(tokenId);

    Color tokenColor = Colors.white;
    if (color == 'red') tokenColor = AppColors.red;
    if (color == 'green') tokenColor = AppColors.green;
    if (color == 'yellow') tokenColor = AppColors.yellow;
    if (color == 'blue') tokenColor = AppColors.blue;

    return Semantics(
      label: "${color.toUpperCase()} goti number ${tokenId + 1}",
      hint: canMove ? "Tap to move this goti." : "This goti cannot move right now.",
      button: canMove,
      child: GestureDetector(
        onTap: () {
          if (canMove) {
            AccessibilityService.instance.speak("${color.toUpperCase()} goti selected.");
            onTokenTap(tokenId);
          }
        },
        child: TweenAnimationBuilder<double>(
          tween: Tween(begin: 1.0, end: canMove ? 1.25 : 1.0),
          duration: const Duration(milliseconds: 300),
          curve: Curves.elasticOut,
          builder: (context, scale, child) {
            return Transform.scale(
              scale: scale,
              child: Container(
                decoration: BoxDecoration(
                  color: tokenColor,
                  shape: BoxShape.circle,
                  border: Border.all(color: Colors.white, width: 2),
                  boxShadow: [
                    BoxShadow(
                      color: tokenColor.withValues(alpha: canMove ? 0.95 : 0.4),
                      blurRadius: canMove ? 12 : 4,
                      spreadRadius: canMove ? 4 : 0,
                    ),
                  ],
                ),
                child: canMove
                    ? const Center(
                        child: Icon(
                          Icons.touch_app,
                          size: 11,
                          color: Colors.white,
                        ),
                      )
                    : null,
              ),
            );
          },
        ),
      ),
    );
  }

  Alignment _getStackAlignment(int index, int total) {
    if (total == 1) return Alignment.center;
    if (total == 2) return index == 0 ? Alignment.centerLeft : Alignment.centerRight;
    if (total == 3) {
      if (index == 0) return Alignment.topLeft;
      if (index == 1) return Alignment.topRight;
      return Alignment.bottomCenter;
    }
    if (index == 0) return Alignment.topLeft;
    if (index == 1) return Alignment.topRight;
    if (index == 2) return Alignment.bottomLeft;
    return Alignment.bottomRight;
  }

  // Standard static Ludo board coordinate mapper
  List<int> getGridCoords(String color, int position) {
    final List<List<int>> redMainPath = [
      [6, 1], [6, 2], [6, 3], [6, 4], [6, 5],
      [5, 6], [4, 6], [3, 6], [2, 6], [1, 6], [0, 6],
      [0, 7],
      [0, 8], [1, 8], [2, 8], [3, 8], [4, 8], [5, 8],
      [6, 9], [6, 10], [6, 11], [6, 12], [6, 13], [6, 14],
      [7, 14],
      [8, 14], [8, 13], [8, 12], [8, 11], [8, 10], [8, 9],
      [9, 8], [10, 8], [11, 8], [12, 8], [13, 8], [14, 8],
      [14, 7],
      [14, 6], [13, 6], [12, 6], [11, 6], [10, 6], [9, 6],
      [8, 5], [8, 4], [8, 3], [8, 2], [8, 1], [8, 0],
      [7, 0],
    ];

    int globalIdx = 0;
    if (color == 'red') {
      globalIdx = position;
    } else if (color == 'green') {
      globalIdx = (position + 13) % 52;
    } else if (color == 'yellow') {
      globalIdx = (position + 26) % 52;
    } else if (color == 'blue') {
      globalIdx = (position + 39) % 52;
    }

    if (position >= 51 && position < 57) {
      final stretchOffset = position - 51;
      if (color == 'red') return [7, 1 + stretchOffset];
      if (color == 'green') return [1 + stretchOffset, 7];
      if (color == 'yellow') return [7, 13 - stretchOffset];
      if (color == 'blue') return [13 - stretchOffset, 7];
    }

    if (globalIdx < redMainPath.length) {
      return redMainPath[globalIdx];
    }
    return [7, 7];
  }
}
