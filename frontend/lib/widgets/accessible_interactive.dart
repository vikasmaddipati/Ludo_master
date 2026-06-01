import 'package:flutter/material.dart';
import '../services/accessibility_service.dart';
import '../constants/app_colors.dart';

class AccessibleInkWell extends StatelessWidget {
  final Widget child;
  final String label;
  final String hint;
  final VoidCallback? onTap;
  final String haptic;
  final bool isSelected;

  const AccessibleInkWell({
    super.key,
    required this.child,
    required this.label,
    this.hint = '',
    this.onTap,
    this.haptic = 'light',
    this.isSelected = false,
  });

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: label,
      hint: hint,
      button: true,
      selected: isSelected,
      enabled: onTap != null,
      child: Focus(
        onFocusChange: (hasFocus) {
          if (hasFocus && AccessibilityService.instance.isBlindModeEnabled) {
            String speechText = label;
            if (hint.isNotEmpty) {
              speechText = "$label. $hint";
            }
            AccessibilityService.instance.speak(speechText);
          }
        },
        child: InkWell(
          borderRadius: BorderRadius.circular(16),
          onTap: onTap == null
              ? null
              : () {
                  AccessibilityService.instance.triggerHaptic(intensity: haptic);
                  
                  // Voice Guided Navigation / Blind Mode announcement on press
                  String announceText = "$label selected";
                  if (AccessibilityService.instance.isBlindModeEnabled && hint.isNotEmpty) {
                    announceText = "$label. $hint";
                  }
                  AccessibilityService.instance.speak(announceText);
                  
                  onTap!();
                },
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(16),
              boxShadow: isSelected
                  ? [
                      BoxShadow(
                        color: AppColors.secondary.withValues(alpha: 0.3),
                        blurRadius: 10,
                        spreadRadius: 2,
                      )
                    ]
                  : [],
            ),
            child: child,
          ),
        ),
      ),
    );
  }
}

class AccessibleButton extends StatelessWidget {
  final String label;
  final String hint;
  final VoidCallback? onTap;
  final Widget? icon;
  final bool isSecondary;
  final bool isFullWidth;

  const AccessibleButton({
    super.key,
    required this.label,
    this.hint = '',
    this.onTap,
    this.icon,
    this.isSecondary = false,
    this.isFullWidth = false,
  });

  @override
  Widget build(BuildContext context) {
    final themeButton = ElevatedButton.styleFrom(
      backgroundColor: isSecondary ? AppColors.surfaceLight : AppColors.primary,
      foregroundColor: Colors.white,
      padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 24),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(20),
        side: BorderSide(
          color: isSecondary ? Colors.white24 : AppColors.secondary.withValues(alpha: 0.3),
          width: 1,
        ),
      ),
      elevation: 4,
    );

    Widget buttonChild = Row(
      mainAxisAlignment: MainAxisAlignment.center,
      mainAxisSize: isFullWidth ? MainAxisSize.max : MainAxisSize.min,
      children: [
        if (icon != null) ...[
          icon!,
          const SizedBox(width: 8),
        ],
        Text(
          label,
          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15, letterSpacing: 0.5),
        ),
      ],
    );

    return AccessibleInkWell(
      label: label,
      hint: hint,
      haptic: 'medium',
      onTap: onTap,
      child: Container(
        width: isFullWidth ? double.infinity : null,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(20),
          gradient: isSecondary ? null : AppColors.primaryGradient,
          boxShadow: isSecondary
              ? []
              : [
                  BoxShadow(
                    color: AppColors.primary.withValues(alpha: 0.3),
                    blurRadius: 12,
                    offset: const Offset(0, 4),
                  ),
                ],
        ),
        child: ElevatedButton(
          style: themeButton,
          onPressed: onTap == null
              ? null
              : () {
                  AccessibilityService.instance.triggerHaptic(intensity: 'medium');
                  AccessibilityService.instance.speak("$label selected");
                  onTap!();
                },
          child: buttonChild,
        ),
      ),
    );
  }
}
