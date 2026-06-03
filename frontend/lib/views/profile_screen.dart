import 'package:flutter/material.dart';
import '../constants/app_colors.dart';
import '../models/user_model.dart';
import '../services/auth_service.dart';
import '../services/accessibility_service.dart';
import '../widgets/accessible_interactive.dart';

class ProfileScreen extends StatefulWidget {
  final UserModel user;

  const ProfileScreen({
    super.key,
    required this.user,
  });

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  final AuthService _auth = AuthService();
  late String _currentName;
  late String _currentAvatarUrl;

  // Selected avatar list seeds for identity customization
  final List<String> _avatarSeeds = [
    'gamer1',
    'gamer2',
    'gamer3',
    'gamer4',
    'gamer5',
    'gamer6',
  ];

  // Simulator for username database uniqueness
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
    _currentName = _auth.currentUser?.name ?? widget.user.name;
    _currentAvatarUrl = _auth.currentUser?.avatarUrl ?? widget.user.avatarUrl;
  }

  void _openEditProfileDialog() {
    final nameController = TextEditingController(text: _currentName);
    String selectedAvatar = _currentAvatarUrl;
    bool isChecking = false;
    bool isAvailable = true;
    String? localError;

    showDialog(
      context: context,
      barrierDismissible: true,
      builder: (dialogCtx) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            void checkUniqueness(String username) async {
              final clean = username.trim();
              if (clean.length < 3 || clean.length > 15 || !RegExp(r'^[a-zA-Z0-9]+$').hasMatch(clean)) {
                setDialogState(() {
                  isAvailable = false;
                  localError = null;
                });
                return;
              }

              // If unchanged, it is available by default
              if (clean.toLowerCase() == _currentName.toLowerCase()) {
                setDialogState(() {
                  isAvailable = true;
                  localError = null;
                  isChecking = false;
                });
                return;
              }

              setDialogState(() {
                isChecking = true;
                localError = null;
                isAvailable = false;
              });

              await Future.delayed(const Duration(milliseconds: 600));

              final isTaken = _reservedNames.any((name) => name.toLowerCase() == clean.toLowerCase());

              setDialogState(() {
                isChecking = false;
                if (isTaken) {
                  isAvailable = false;
                  localError = 'Username is already taken!';
                } else {
                  isAvailable = true;
                  localError = null;
                }
              });
            }

            void attemptSave() {
              final newName = nameController.text.trim();
              if (newName.length < 3 || newName.length > 15 || !RegExp(r'^[a-zA-Z0-9]+$').hasMatch(newName)) {
                AccessibilityService.instance.triggerHaptic(intensity: 'light');
                return;
              }

              if (!isAvailable) return;

              // Confirmation Dialog Loop
              Navigator.pop(dialogCtx); // Close edit dialog first
              _showConfirmProfileUpdate(newName, selectedAvatar);
            }

            return AlertDialog(
              backgroundColor: AppColors.surface,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
              title: const Text(
                'EDIT PROFILE IDENTITY',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: Colors.white, letterSpacing: 0.5),
                textAlign: TextAlign.center,
              ),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // Avatar display
                    CircleAvatar(
                      radius: 36,
                      backgroundColor: AppColors.surfaceLight,
                      backgroundImage: NetworkImage(selectedAvatar),
                    ),
                    const SizedBox(height: 16),

                    // Avatar Selector Picker Grid
                    const Text('Select Gaming Avatar:', style: TextStyle(color: AppColors.textSecondary, fontSize: 11, fontWeight: FontWeight.bold)),
                    const SizedBox(height: 8),
                    SizedBox(
                      height: 52,
                      width: 240,
                      child: ListView.builder(
                        scrollDirection: Axis.horizontal,
                        physics: const BouncingScrollPhysics(),
                        itemCount: _avatarSeeds.length,
                        itemBuilder: (context, index) {
                          final seed = _avatarSeeds[index];
                          final url = 'https://api.dicebear.com/7.x/adventurer/png?seed=$seed';
                          final isSelected = selectedAvatar == url;

                          return GestureDetector(
                            onTap: () {
                              setDialogState(() {
                                selectedAvatar = url;
                              });
                            },
                            child: Container(
                              margin: const EdgeInsets.only(right: 8),
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                border: Border.all(
                                  color: isSelected ? AppColors.secondary : Colors.transparent,
                                  width: 2.0,
                                ),
                              ),
                              child: CircleAvatar(
                                radius: 20,
                                backgroundColor: AppColors.surfaceLight,
                                backgroundImage: NetworkImage(url),
                              ),
                            ),
                          );
                        },
                      ),
                    ),
                    const SizedBox(height: 20),

                    // Text Field for Username
                    TextField(
                      controller: nameController,
                      style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                      maxLength: 15,
                      onChanged: (val) {
                        checkUniqueness(val);
                      },
                      decoration: InputDecoration(
                        labelText: 'Username',
                        labelStyle: const TextStyle(color: AppColors.textSecondary),
                        filled: true,
                        fillColor: AppColors.surfaceLight,
                        counterText: '',
                        errorText: nameController.text.trim().isNotEmpty && nameController.text.trim().length < 3
                            ? 'Min length is 3'
                            : !RegExp(r'^[a-zA-Z0-9]+$').hasMatch(nameController.text.trim()) && nameController.text.trim().isNotEmpty
                                ? 'Alphanumeric only'
                                : localError,
                        suffixIcon: isChecking
                            ? const Padding(
                                padding: EdgeInsets.all(12),
                                child: SizedBox(width: 14, height: 14, child: CircularProgressIndicator(strokeWidth: 2, color: AppColors.secondary)),
                              )
                            : isAvailable
                                ? const Icon(Icons.check_circle, color: AppColors.green)
                                : const Icon(Icons.error, color: AppColors.red),
                        enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: AppColors.surfaceLight)),
                        focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: AppColors.primary)),
                      ),
                    ),
                  ],
                ),
              ),
              actions: [
                TextButton(
                  child: const Text('Cancel', style: TextStyle(color: AppColors.textSecondary)),
                  onPressed: () => Navigator.pop(dialogCtx),
                ),
                ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                  onPressed: isChecking ? null : attemptSave,
                  child: const Text('Save', style: TextStyle(color: Colors.white)),
                ),
              ],
            );
          },
        );
      },
    );
  }

  void _showConfirmProfileUpdate(String newName, String newAvatar) {
    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          backgroundColor: AppColors.surface,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          title: const Text('Confirm Identity Change', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text('Are you sure you want to update your Ludo Master gaming identity to:', style: TextStyle(color: AppColors.textSecondary)),
              const SizedBox(height: 16),
              CircleAvatar(
                radius: 30,
                backgroundImage: NetworkImage(newAvatar),
              ),
              const SizedBox(height: 8),
              Text(newName, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18, color: Colors.white)),
            ],
          ),
          actions: [
            TextButton(
              child: const Text('Cancel', style: TextStyle(color: AppColors.textSecondary)),
              onPressed: () => Navigator.pop(context),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(backgroundColor: AppColors.green),
              child: const Text('Confirm', style: TextStyle(color: Colors.white)),
              onPressed: () async {
                Navigator.pop(context); // Close confirm
                
                await _auth.updatePersonalizedProfile(newName, newAvatar);
                
                setState(() {
                  _currentName = newName;
                  _currentAvatarUrl = newAvatar;
                });
                
                AccessibilityService.instance.triggerHaptic(intensity: 'heavy');
                AccessibilityService.instance.speak("Identity updated successfully!");

                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Identity updated successfully!'), backgroundColor: AppColors.green),
                );
              },
            ),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final totalMatches = widget.user.wins + widget.user.losses;
    final winPercentage = totalMatches > 0 ? (widget.user.wins / totalMatches * 100).toStringAsFixed(1) : '0';

    return Padding(
      padding: const EdgeInsets.all(24.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Profile Details Card
          Semantics(
            label: "User Profile: $_currentName. Email: ${widget.user.email}.",
            child: Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: AppColors.surface,
                borderRadius: BorderRadius.circular(24),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.2),
                    blurRadius: 10,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: Column(
                children: [
                  Stack(
                    children: [
                      CircleAvatar(
                        radius: 40,
                        backgroundColor: AppColors.surfaceLight,
                        backgroundImage: _currentAvatarUrl.isNotEmpty ? NetworkImage(_currentAvatarUrl) : null,
                        child: _currentAvatarUrl.isEmpty
                            ? const Icon(Icons.person, size: 40, color: Colors.white)
                            : null,
                      ),
                      Positioned(
                        bottom: 0,
                        right: 0,
                        child: Semantics(
                          label: "Edit profile details button",
                          hint: "Tap to change username or avatar photo.",
                          button: true,
                          child: GestureDetector(
                            onTap: _openEditProfileDialog,
                            child: Container(
                              padding: const EdgeInsets.all(6),
                              decoration: const BoxDecoration(
                                color: AppColors.primary,
                                shape: BoxShape.circle,
                              ),
                              child: const Icon(Icons.edit, color: Colors.white, size: 14),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  Text(
                    _currentName,
                    style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    widget.user.email,
                    style: const TextStyle(color: AppColors.textSecondary, fontSize: 13),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 24),

          // Statistics Grid
          Expanded(
            child: GridView.count(
              crossAxisCount: 2,
              crossAxisSpacing: 16,
              mainAxisSpacing: 16,
              childAspectRatio: 1.5,
              children: [
                _buildStatCard('Total Matches', '$totalMatches', Icons.sports_esports, AppColors.primary),
                _buildStatCard('Win Percentage', '$winPercentage%', Icons.percent, AppColors.secondary),
                _buildStatCard('Matches Won', '${widget.user.wins}', Icons.emoji_events, Colors.amber),
                _buildStatCard('Matches Lost', '${widget.user.losses}', Icons.trending_down, AppColors.red),
              ],
            ),
          ),

          // Log Out Button
          AccessibleButton(
            label: 'LOG OUT',
            hint: 'Sign out of your Ludo Master account.',
            isSecondary: true,
            isFullWidth: true,
            icon: const Icon(Icons.logout, color: AppColors.red),
            onTap: () async {
              AccessibilityService.instance.speak("Signing out.");
              await _auth.signOut();
              if (context.mounted) {
                Navigator.pushReplacementNamed(context, '/login');
              }
            },
          ),
        ],
      ),
    );
  }

  Widget _buildStatCard(String label, String value, IconData icon, Color color) {
    return Semantics(
      label: "$label: $value",
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(20),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Row(
              children: [
                Icon(icon, color: color, size: 20),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    label,
                    style: const TextStyle(fontSize: 11, color: AppColors.textSecondary, fontWeight: FontWeight.bold),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Text(
              value,
              style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: Colors.white),
            ),
          ],
        ),
      ),
    );
  }
}
