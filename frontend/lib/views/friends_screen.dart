import 'package:flutter/material.dart';
import '../constants/app_colors.dart';
import '../models/user_model.dart';
import '../models/friend_model.dart';
import '../services/api_service.dart';
import '../services/global_voice_manager.dart';
import '../services/voice_command_registry.dart';
import '../services/voice_assistant_service.dart';
import '../services/accessibility_service.dart';
import '../widgets/accessible_interactive.dart';

class FriendsScreen extends StatefulWidget {
  final UserModel currentUser;

  const FriendsScreen({super.key, required this.currentUser});

  @override
  State<FriendsScreen> createState() => _FriendsScreenState();
}

class _FriendsScreenState extends State<FriendsScreen> with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final TextEditingController _searchController = TextEditingController();

  List<FriendModel> _friends = [];
  List<FriendRequestModel> _incomingRequests = [];
  List<UserModel> _searchResults = [];

  bool _isLoadingFriends = false;
  bool _isLoadingRequests = false;
  bool _isSearching = false;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    _loadFriends();
    _loadRequests();

    // Register voice handlers for social actions
    final registry = VoiceCommandRegistry.instance;
    registry.registerHandler("ADD_FRIEND", (params) async => _handleVoiceAction("ADD_FRIEND", params));
    registry.registerHandler("ACCEPT_FRIEND", (params) async => _handleVoiceAction("ACCEPT_FRIEND", params));
    registry.registerHandler("REJECT_FRIEND", (params) async => _handleVoiceAction("REJECT_FRIEND", params));
    registry.registerHandler("REMOVE_FRIEND", (params) async => _handleVoiceAction("REMOVE_FRIEND", params));
  }

  void _handleVoiceAction(String action, Map<String, dynamic> params) {
    if (!mounted) return;

    if (action == "ADD_FRIEND") {
      // Search by name and send friend request
      final nameQuery = (params['name'] ?? "").toString().toLowerCase().trim();
      if (nameQuery.isNotEmpty) {
        _searchController.text = nameQuery;
        _handleSearch().then((_) {
          if (_searchResults.isNotEmpty) {
            final match = _searchResults.firstWhere(
              (u) => u.name.toLowerCase().contains(nameQuery),
              orElse: () => _searchResults.first,
            );
            _sendFriendRequest(match);
            VoiceAssistantService.instance.speak(
              "Sending friend request to ${match.name}.", context);
          } else {
            VoiceAssistantService.instance.speak(
              "Could not find player named $nameQuery.", context);
          }
        });
      } else {
        // Navigate to search tab
        _tabController.animateTo(1);
        VoiceAssistantService.instance.speak("Opening friend search.", context);
      }
    } else if (action == "ACCEPT_FRIEND") {
      final nameQuery = (params['name'] ?? "").toString().toLowerCase().trim();
      if (_incomingRequests.isEmpty) {
        VoiceAssistantService.instance.speak("You have no pending friend requests.", context);
      } else {
        final req = nameQuery.isNotEmpty
            ? _incomingRequests.firstWhere(
                (r) => r.requester.name.toLowerCase().contains(nameQuery),
                orElse: () => _incomingRequests.first,
              )
            : _incomingRequests.first;
        _acceptRequest(req);
        VoiceAssistantService.instance.speak(
          "Accepting friend request from ${req.requester.name}.", context);
      }
    } else if (action == "REJECT_FRIEND") {
      final nameQuery = (params['name'] ?? "").toString().toLowerCase().trim();
      if (_incomingRequests.isEmpty) {
        VoiceAssistantService.instance.speak("You have no pending friend requests.", context);
      } else {
        final req = nameQuery.isNotEmpty
            ? _incomingRequests.firstWhere(
                (r) => r.requester.name.toLowerCase().contains(nameQuery),
                orElse: () => _incomingRequests.first,
              )
            : _incomingRequests.first;
        _rejectRequest(req);
        VoiceAssistantService.instance.speak(
          "Rejecting friend request from ${req.requester.name}.", context);
      }
    } else if (action == "REMOVE_FRIEND") {
      final nameQuery = (params['name'] ?? "").toString().toLowerCase().trim();
      if (_friends.isEmpty) {
        VoiceAssistantService.instance.speak("Your friends list is empty.", context);
      } else if (nameQuery.isEmpty) {
        VoiceAssistantService.instance.speak("Please say the name of the friend to remove.", context);
      } else {
        try {
          final match = _friends.firstWhere(
            (f) => f.friend.name.toLowerCase().contains(nameQuery),
          );
          _unfriend(match);
          VoiceAssistantService.instance.speak(
            "Removing ${match.friend.name} from your friends list.", context);
        } catch (e) {
          VoiceAssistantService.instance.speak(
            "Could not find $nameQuery in your friends list.", context);
        }
      }
    }
  }

  Future<void> _loadFriends() async {
    setState(() => _isLoadingFriends = true);
    final list = await ApiService.getFriendsList(widget.currentUser.id);
    if (mounted) {
      setState(() {
        _friends = list;
        _isLoadingFriends = false;
      });
    }
  }

  Future<void> _loadRequests() async {
    setState(() => _isLoadingRequests = true);
    final res = await ApiService.getFriendRequests(widget.currentUser.id);
    if (mounted) {
      setState(() {
        _incomingRequests = res['incoming'] ?? [];
        _isLoadingRequests = false;
      });
    }
  }

  Future<void> _handleSearch() async {
    final query = _searchController.text.trim();
    if (query.isEmpty) return;

    setState(() => _isSearching = true);
    final results = await ApiService.searchUsers(query, widget.currentUser.id);
    if (mounted) {
      setState(() {
        _searchResults = results;
        _isSearching = false;
      });
      if (results.isEmpty) {
        AccessibilityService.instance.speak("No players found matching $query.");
      } else {
        AccessibilityService.instance.speak("Found ${results.length} players matching $query.");
      }
    }
  }

  void _sendFriendRequest(UserModel targetUser) async {
    final success = await ApiService.sendFriendRequest(widget.currentUser.id, targetUser.id);
    if (mounted) {
      if (success) {
        AccessibilityService.instance.speak("Friend request sent to ${targetUser.name}");
      } else {
        AccessibilityService.instance.speak("Failed to send friend request.");
      }
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(success 
            ? 'Friend request sent to ${targetUser.name}!' 
            : 'Failed to send friend request.'
          ),
          backgroundColor: success ? AppColors.green : AppColors.red,
        ),
      );
    }
  }

  void _acceptRequest(FriendRequestModel req) async {
    final success = await ApiService.acceptFriendRequest(req.id);
    if (mounted) {
      if (success) {
        setState(() {
          _incomingRequests.removeWhere((element) => element.id == req.id);
        });
        _loadFriends();
        AccessibilityService.instance.speak("Accepted friend request from ${req.requester.name}!");
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Accepted friend request from ${req.requester.name}!'), backgroundColor: AppColors.green),
        );
      } else {
        AccessibilityService.instance.speak("Failed to accept friend request.");
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Failed to accept friend request.'), backgroundColor: AppColors.red),
        );
      }
    }
  }

  void _rejectRequest(FriendRequestModel req) async {
    final success = await ApiService.rejectFriendRequest(req.id);
    if (mounted) {
      if (success) {
        setState(() {
          _incomingRequests.removeWhere((element) => element.id == req.id);
        });
        AccessibilityService.instance.speak("Declined friend request from ${req.requester.name}.");
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Declined friend request from ${req.requester.name}.')),
        );
      }
    }
  }

  void _unfriend(FriendModel friendship) async {
    final success = await ApiService.rejectFriendRequest(friendship.id);
    if (mounted) {
      if (success) {
        setState(() {
          _friends.removeWhere((element) => element.id == friendship.id);
        });
        AccessibilityService.instance.speak("Removed ${friendship.friend.name} from friends list.");
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Unfriended ${friendship.friend.name}.')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        // Tab bar container
        Container(
          color: AppColors.surface,
          child: TabBar(
            controller: _tabController,
            indicatorColor: AppColors.secondary,
            labelColor: AppColors.secondary,
            unselectedLabelColor: AppColors.textSecondary,
            tabs: const [
              Tab(icon: Icon(Icons.people), text: 'Friends'),
              Tab(icon: Icon(Icons.search), text: 'Search'),
              Tab(icon: Icon(Icons.mail), text: 'Requests'),
            ],
          ),
        ),
        Expanded(
          child: TabBarView(
            controller: _tabController,
            children: [
              _buildFriendsTab(),
              _buildSearchTab(),
              _buildRequestsTab(),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildFriendsTab() {
    if (_isLoadingFriends) {
      return const Center(child: CircularProgressIndicator(color: AppColors.primary));
    }

    if (_friends.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.people_outline, size: 64, color: AppColors.textSecondary.withOpacity(0.5)),
            const SizedBox(height: 16),
            const Text(
              'No friends added yet!',
              style: TextStyle(fontSize: 16, color: AppColors.textSecondary, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            TextButton.icon(
              icon: const Icon(Icons.search, color: AppColors.secondary),
              label: const Text('Find Players', style: TextStyle(color: AppColors.secondary)),
              onPressed: () => _tabController.animateTo(1),
            ),
          ],
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: _loadFriends,
      color: AppColors.primary,
      backgroundColor: AppColors.surface,
      child: ListView.builder(
        padding: const EdgeInsets.all(16),
        itemCount: _friends.length,
        itemBuilder: (context, index) {
          final f = _friends[index];
          return Semantics(
            label: "Friend: ${f.friend.name}. Wins: ${f.friend.wins}, Losses: ${f.friend.losses}.",
            hint: "Double tap to view friend actions.",
            child: Container(
              margin: const EdgeInsets.only(bottom: 12),
              decoration: BoxDecoration(
                color: AppColors.surface,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: AppColors.surfaceLight, width: 1),
              ),
              child: ListTile(
                contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                leading: Stack(
                  children: [
                    CircleAvatar(
                      radius: 26,
                      backgroundImage: NetworkImage(f.friend.avatarUrl),
                    ),
                    Positioned(
                      bottom: 0,
                      right: 0,
                      child: Container(
                        width: 14,
                        height: 14,
                        decoration: BoxDecoration(
                          color: AppColors.green,
                          shape: BoxShape.circle,
                          border: Border.all(color: AppColors.surface, width: 2),
                        ),
                      ),
                    ),
                  ],
                ),
                title: Text(
                  f.friend.name,
                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: Colors.white),
                ),
                subtitle: Text(
                  'Wins: ${f.friend.wins} | Losses: ${f.friend.losses}',
                  style: const TextStyle(color: AppColors.textSecondary, fontSize: 12),
                ),
                trailing: Semantics(
                  label: "Friend Actions",
                  hint: "Open menu to unfriend ${f.friend.name}.",
                  button: true,
                  child: PopupMenuButton<String>(
                    color: AppColors.surfaceLight,
                    icon: const Icon(Icons.more_vert, color: Colors.white),
                    onSelected: (val) {
                      if (val == 'unfriend') {
                        _showUnfriendConfirmDialog(f);
                      }
                    },
                    itemBuilder: (context) => [
                      const PopupMenuItem(
                        value: 'unfriend',
                        child: Row(
                          children: [
                            Icon(Icons.person_remove, color: AppColors.red, size: 18),
                            SizedBox(width: 8),
                            Text('Unfriend', style: TextStyle(color: Colors.white)),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  void _showUnfriendConfirmDialog(FriendModel f) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: AppColors.surface,
        title: const Text('Unfriend', style: TextStyle(color: Colors.white)),
        content: Text(
          'Are you sure you want to unfriend ${f.friend.name}?',
          style: const TextStyle(color: AppColors.textSecondary),
        ),
        actions: [
          TextButton(
            child: const Text('Cancel', style: TextStyle(color: AppColors.textSecondary)),
            onPressed: () => Navigator.pop(context),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.red),
            child: const Text('Unfriend', style: TextStyle(color: Colors.white)),
            onPressed: () {
              Navigator.pop(context);
              _unfriend(f);
            },
          ),
        ],
      ),
    );
  }

  Widget _buildSearchTab() {
    return Padding(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        children: [
          // Search input field
          Row(
            children: [
              Expanded(
                child: Semantics(
                  label: "Search player by name or email input field",
                  textField: true,
                  child: TextField(
                    controller: _searchController,
                    style: const TextStyle(color: Colors.white),
                    decoration: InputDecoration(
                      hintText: 'Search by player name or email...',
                      hintStyle: const TextStyle(color: AppColors.textSecondary),
                      prefixIcon: const Icon(Icons.search, color: AppColors.textSecondary),
                      filled: true,
                      fillColor: AppColors.surface,
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(16),
                        borderSide: BorderSide.none,
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(16),
                        borderSide: const BorderSide(color: AppColors.primary, width: 1.5),
                      ),
                    ),
                    onSubmitted: (_) => _handleSearch(),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              AccessibleInkWell(
                label: "Search button",
                hint: "Search user database.",
                onTap: _handleSearch,
                child: Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    gradient: AppColors.primaryGradient,
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: const Icon(Icons.arrow_forward, color: Colors.white),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Expanded(
            child: _isSearching
                ? const Center(child: CircularProgressIndicator(color: AppColors.primary))
                : _searchResults.isEmpty
                    ? Center(
                        child: Text(
                          _searchController.text.isEmpty
                              ? 'Enter a name to search for other players'
                              : 'No players found.',
                          style: const TextStyle(color: AppColors.textSecondary),
                        ),
                      )
                    : ListView.builder(
                        itemCount: _searchResults.length,
                        itemBuilder: (context, index) {
                          final user = _searchResults[index];
                          return Semantics(
                            label: "${user.name}. Email: ${user.email}. Wins: ${user.wins}.",
                            hint: "Double tap to send friend request.",
                            child: Container(
                              margin: const EdgeInsets.only(bottom: 12),
                              decoration: BoxDecoration(
                                color: AppColors.surface,
                                borderRadius: BorderRadius.circular(16),
                                border: Border.all(color: AppColors.surfaceLight, width: 1),
                              ),
                              child: ListTile(
                                contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                                leading: CircleAvatar(
                                  radius: 24,
                                  backgroundImage: NetworkImage(user.avatarUrl),
                                ),
                                title: Text(
                                  user.name,
                                  style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.white),
                                ),
                                subtitle: Text(
                                  '${user.email}\nWins: ${user.wins}',
                                  style: const TextStyle(color: AppColors.textSecondary, fontSize: 11),
                                ),
                                trailing: AccessibleButton(
                                  label: 'Add',
                                  hint: 'Send friend request to ${user.name}',
                                  onTap: () => _sendFriendRequest(user),
                                  icon: const Icon(Icons.person_add, size: 16, color: Colors.white),
                                ),
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

  Widget _buildRequestsTab() {
    if (_isLoadingRequests) {
      return const Center(child: CircularProgressIndicator(color: AppColors.primary));
    }

    if (_incomingRequests.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.mail_outline, size: 64, color: AppColors.textSecondary.withOpacity(0.5)),
            const SizedBox(height: 16),
            const Text(
              'No pending friend requests!',
              style: TextStyle(fontSize: 16, color: AppColors.textSecondary, fontWeight: FontWeight.bold),
            ),
          ],
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: _loadRequests,
      color: AppColors.primary,
      backgroundColor: AppColors.surface,
      child: ListView.builder(
        padding: const EdgeInsets.all(16),
        itemCount: _incomingRequests.length,
        itemBuilder: (context, index) {
          final req = _incomingRequests[index];
          return Semantics(
            label: "Friend request from ${req.requester.name}. Wins: ${req.requester.wins}, Losses: ${req.requester.losses}.",
            hint: "Use accept or decline buttons on the right.",
            child: Container(
              margin: const EdgeInsets.only(bottom: 12),
              decoration: BoxDecoration(
                color: AppColors.surface,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: AppColors.surfaceLight, width: 1),
              ),
              child: ListTile(
                contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                leading: CircleAvatar(
                  radius: 24,
                  backgroundImage: NetworkImage(req.requester.avatarUrl),
                ),
                title: Text(
                  req.requester.name,
                  style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.white),
                ),
                subtitle: Text(
                  'Wins: ${req.requester.wins} | Losses: ${req.requester.losses}',
                  style: const TextStyle(color: AppColors.textSecondary, fontSize: 12),
                ),
                trailing: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // Accept button
                    AccessibleInkWell(
                      label: "Accept",
                      hint: "Accept friend request from ${req.requester.name}.",
                      onTap: () => _acceptRequest(req),
                      child: const Padding(
                        padding: EdgeInsets.all(4.0),
                        child: Icon(Icons.check_circle, color: AppColors.green, size: 28),
                      ),
                    ),
                    const SizedBox(width: 8),
                    // Decline button
                    AccessibleInkWell(
                      label: "Decline",
                      hint: "Decline friend request from ${req.requester.name}.",
                      onTap: () => _rejectRequest(req),
                      child: const Padding(
                        padding: EdgeInsets.all(4.0),
                        child: Icon(Icons.cancel, color: AppColors.red, size: 28),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  @override
  void dispose() {
    // Unregister voice handlers
    final registry = VoiceCommandRegistry.instance;
    registry.unregisterHandler("ADD_FRIEND");
    registry.unregisterHandler("ACCEPT_FRIEND");
    registry.unregisterHandler("REJECT_FRIEND");
    registry.unregisterHandler("REMOVE_FRIEND");

    _tabController.dispose();
    _searchController.dispose();
    super.dispose();
  }
}
