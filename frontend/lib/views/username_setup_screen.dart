import 'package:flutter/material.dart';
import '../constants/app_colors.dart';
import '../services/auth_service.dart';
import '../services/accessibility_service.dart';
import '../widgets/accessible_interactive.dart';

class UsernameSetupScreen extends StatefulWidget {
  const UsernameSetupScreen({super.key});

  @override
  State<UsernameSetupScreen> createState() => _UsernameSetupScreenState();
}

class _UsernameSetupScreenState extends State<UsernameSetupScreen> {
  final AuthService _auth = AuthService();
  final TextEditingController _usernameController = TextEditingController();
  final GlobalKey<FormState> _formKey = GlobalKey<FormState>();

  // Curated list of premium seeds for gaming avatars
  final List<String> _avatarSeeds = [
    'gamer1',
    'gamer2',
    'gamer3',
    'gamer4',
    'gamer5',
    'gamer6',
  ];

  late String _selectedAvatarUrl;
  bool _isCheckingAvailability = false;
  bool _isAvailable = false;
  String? _availabilityError;

  // Taken/reserved usernames for simulation uniqueness checks
  final List<String> _reservedNames = [
    'DiceCrusher',
    'LudoQueen',
    'TokenStriker',
    'GuestMaster',
    'CasualRoller',
  ];

  @override
  void initState() {
    super.initState();
    // Default select first avatar seed
    _selectedAvatarUrl = 'https://api.dicebear.com/7.x/adventurer/png?seed=${_avatarSeeds[0]}';
    AccessibilityService.instance.announceScreen("Username Setup");
  }

  @override
  void dispose() {
    _usernameController.dispose();
    super.dispose();
  }

  // Simulated live database uniqueness check
  void _checkAvailability(String username) async {
    final clean = username.trim();
    if (clean.length < 3 || clean.length > 15 || !RegExp(r'^[a-zA-Z0-9]+$').hasMatch(clean)) {
      setState(() {
        _isAvailable = false;
        _availabilityError = null; // Let the form validations catch structure errors
      });
      return;
    }

    setState(() {
      _isCheckingAvailability = true;
      _availabilityError = null;
      _isAvailable = false;
    });

    // 900ms simulated network delay
    await Future.delayed(const Duration(milliseconds: 900));

    if (!mounted) return;

    final isTaken = _reservedNames.any((name) => name.toLowerCase() == clean.toLowerCase());

    setState(() {
      _isCheckingAvailability = false;
      if (isTaken) {
        _isAvailable = false;
        _availabilityError = 'Username is already taken!';
        AccessibilityService.instance.speak("Username $clean is already taken. Please try another.", force: true);
      } else {
        _isAvailable = true;
        _availabilityError = null;
        AccessibilityService.instance.speak("Username $clean is available!", force: true);
      }
    });
  }

  void _saveProfile() async {
    if (!_formKey.currentState!.validate()) {
      AccessibilityService.instance.triggerHaptic(intensity: 'light');
      return;
    }

    final username = _usernameController.text.trim();
    if (!_isAvailable) {
      // Re-trigger a check in case they typed without checking
      _checkAvailability(username);
      return;
    }

    AccessibilityService.instance.triggerHaptic(intensity: 'heavy');
    AccessibilityService.instance.speak("Saving personalized profile, welcome $username!");

    await _auth.updatePersonalizedProfile(username, _selectedAvatarUrl);

    if (mounted) {
      Navigator.pushReplacementNamed(context, '/home');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: SingleChildScrollView(
          physics: const BouncingScrollPhysics(),
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 30),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const SizedBox(height: 10),
                // Heading typography
                const Center(
                  child: Text(
                    'CLAIM YOUR IDENTITY',
                    style: TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.w900,
                      color: Colors.white,
                      letterSpacing: 1.5,
                    ),
                  ),
                ),
                const SizedBox(height: 6),
                const Center(
                  child: Text(
                    'Choose a unique gaming username and profile picture',
                    textAlign: TextAlign.center,
                    style: TextStyle(color: AppColors.textSecondary, fontSize: 12),
                  ),
                ),
                const SizedBox(height: 36),

                // Selected Avatar Preview with gradient border
                Center(
                  child: Container(
                    padding: const EdgeInsets.all(4),
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      gradient: AppColors.primaryGradient,
                      boxShadow: [
                        BoxShadow(
                          color: AppColors.primary.withOpacity(0.3),
                          blurRadius: 16,
                          spreadRadius: 2,
                        ),
                      ],
                    ),
                    child: CircleAvatar(
                      radius: 54,
                      backgroundColor: AppColors.surfaceLight,
                      backgroundImage: NetworkImage(_selectedAvatarUrl),
                    ),
                  ),
                ),
                const SizedBox(height: 24),

                // Curated Avatar Picker label
                const Text(
                  'SELECT GAMING AVATAR',
                  style: TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.w900,
                    color: AppColors.textSecondary,
                    letterSpacing: 1.0,
                  ),
                ),
                const SizedBox(height: 10),

                // Curated Avatar horizontal list
                SizedBox(
                  height: 76,
                  child: ListView.builder(
                    scrollDirection: Axis.horizontal,
                    physics: const BouncingScrollPhysics(),
                    itemCount: _avatarSeeds.length,
                    itemBuilder: (context, index) {
                      final seed = _avatarSeeds[index];
                      final url = 'https://api.dicebear.com/7.x/adventurer/png?seed=$seed';
                      final isSelected = _selectedAvatarUrl == url;

                      return Semantics(
                        label: "Avatar option ${index + 1}",
                        hint: isSelected ? "Currently selected" : "Double tap to choose this avatar",
                        button: true,
                        child: GestureDetector(
                          onTap: () {
                            AccessibilityService.instance.triggerHaptic(intensity: 'light');
                            setState(() {
                              _selectedAvatarUrl = url;
                            });
                          },
                          child: Container(
                            margin: const EdgeInsets.only(right: 12),
                            padding: const EdgeInsets.all(2.5),
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              border: Border.all(
                                color: isSelected ? AppColors.secondary : Colors.transparent,
                                width: 2.5,
                              ),
                            ),
                            child: CircleAvatar(
                              radius: 30,
                              backgroundColor: AppColors.surface,
                              backgroundImage: NetworkImage(url),
                            ),
                          ),
                        ),
                      );
                    },
                  ),
                ),
                const SizedBox(height: 32),

                // Username input field
                const Text(
                  'GAMING USERNAME',
                  style: TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.w900,
                    color: AppColors.textSecondary,
                    letterSpacing: 1.0,
                  ),
                ),
                const SizedBox(height: 10),

                Semantics(
                  label: "Username text entry field",
                  hint: "Enter 3 to 15 characters, alphanumeric only.",
                  child: TextFormField(
                    controller: _usernameController,
                    style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16),
                    maxLength: 15,
                    onChanged: (val) {
                      _checkAvailability(val);
                    },
                    validator: (value) {
                      if (value == null || value.trim().isEmpty) {
                        return 'Username cannot be empty!';
                      }
                      final clean = value.trim();
                      if (clean.length < 3) {
                        return 'Username must be at least 3 characters!';
                      }
                      if (clean.length > 15) {
                        return 'Username cannot exceed 15 characters!';
                      }
                      if (!RegExp(r'^[a-zA-Z0-9]+$').hasMatch(clean)) {
                        return 'Only letters and numbers allowed (no special chars)!';
                      }
                      if (_availabilityError != null) {
                        return _availabilityError;
                      }
                      if (!_isAvailable && !_isCheckingAvailability) {
                        return 'Please choose an available unique username!';
                      }
                      return null;
                    },
                    decoration: InputDecoration(
                      hintText: 'e.g. LudoMaster99',
                      hintStyle: const TextStyle(color: AppColors.textSecondary, fontWeight: FontWeight.normal),
                      filled: true,
                      fillColor: AppColors.surface,
                      counterText: '',
                      contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
                      suffixIcon: Padding(
                        padding: const EdgeInsets.only(right: 12.0),
                        child: _isCheckingAvailability
                            ? const SizedBox(
                                width: 20,
                                height: 20,
                                child: Center(
                                  child: CircularProgressIndicator(color: AppColors.secondary, strokeWidth: 2),
                                ),
                              )
                            : _isAvailable
                                ? const Icon(Icons.check_circle, color: AppColors.green, size: 24)
                                : _usernameController.text.isNotEmpty
                                    ? const Icon(Icons.error, color: AppColors.red, size: 24)
                                    : null,
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(16),
                        borderSide: const BorderSide(color: AppColors.surfaceLight, width: 1.5),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(16),
                        borderSide: const BorderSide(color: AppColors.primary, width: 1.5),
                      ),
                      errorBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(16),
                        borderSide: const BorderSide(color: AppColors.red, width: 1.5),
                      ),
                      focusedErrorBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(16),
                        borderSide: const BorderSide(color: AppColors.red, width: 1.5),
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 60),

                // Save button
                AccessibleButton(
                  label: 'SAVE AND PLAY',
                  hint: 'Saves your custom profile and enters Ludo Master lobby.',
                  onTap: _isCheckingAvailability ? null : _saveProfile,
                  isFullWidth: true,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
