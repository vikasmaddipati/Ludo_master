import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/user_model.dart';
import 'api_service.dart';

class AuthService {
  // Singleton pattern
  static final AuthService _instance = AuthService._internal();

  factory AuthService() {
    return _instance;
  }

  AuthService._internal();

  final FirebaseAuth _auth = FirebaseAuth.instance;

  final GoogleSignIn _googleSignIn = GoogleSignIn(
    clientId: '497629835372-k9a6ut9j1sg4sqooogp88radnv9m43nn.apps.googleusercontent.com',
    scopes: ['email'],
  );

  UserModel? _currentUser;
  UserModel? get currentUser => _currentUser;

  Future<bool> isUsernameSetupCompleted(String userId) async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool('username_setup_done_$userId') ?? false;
  }

  Future<void> syncPersonalizedProfile(UserModel user) async {
    final prefs = await SharedPreferences.getInstance();
    final cachedName = prefs.getString('personalized_name_${user.id}');
    final cachedAvatar = prefs.getString('personalized_avatar_${user.id}');
    
    if (cachedName != null || cachedAvatar != null) {
      _currentUser = UserModel(
        id: user.id,
        googleId: user.googleId,
        name: cachedName ?? user.name,
        email: user.email,
        avatarUrl: cachedAvatar ?? user.avatarUrl,
        coins: user.coins,
        wins: user.wins,
        losses: user.losses,
        fcmToken: user.fcmToken,
      );
    } else {
      _currentUser = user;
    }
  }

  Future<void> updatePersonalizedProfile(String newName, String newAvatar) async {
    if (_currentUser == null) return;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('personalized_name_${_currentUser!.id}', newName);
    await prefs.setString('personalized_avatar_${_currentUser!.id}', newAvatar);
    await prefs.setBool('username_setup_done_${_currentUser!.id}', true);
    
    _currentUser = UserModel(
      id: _currentUser!.id,
      googleId: _currentUser!.googleId,
      name: newName,
      email: _currentUser!.email,
      avatarUrl: newAvatar,
      coins: _currentUser!.coins,
      wins: _currentUser!.wins,
      losses: _currentUser!.losses,
      fcmToken: _currentUser!.fcmToken,
    );
  }

  Future<UserModel?> checkCurrentUserSession() async {
    if (_currentUser != null) return _currentUser;

    try {
      final firebaseUser = _auth.currentUser;
      if (firebaseUser != null) {
        final serverUser = await ApiService.authenticateGoogleUser(
          googleId: firebaseUser.uid,
          name: firebaseUser.displayName ?? 'Player',
          email: firebaseUser.email ?? '',
          avatarUrl: firebaseUser.photoURL ?? 'https://api.dicebear.com/7.x/bottts/png',
        );
        if (serverUser != null) {
          await syncPersonalizedProfile(serverUser);
        }
        return _currentUser;
      }
    } catch (e) {
      print('Firebase session check skipped/failed: $e');
    }
    return null;
  }

  Future<UserModel?> signInWithGoogle() async {
    try {
      // If using the local mock client ID, bypass Google popup to go straight to Sandbox Guest!
      if (_googleSignIn.clientId?.contains('mockclientid') == true) {
        print('Local Sandbox client ID detected. Bypassing Google OAuth popup.');
        final guest = _createSandboxGuestUser();
        await syncPersonalizedProfile(guest);
        return _currentUser;
      }

      final GoogleSignInAccount? googleUser = await _googleSignIn.signIn();
      if (googleUser == null) {
        final guest = _createSandboxGuestUser();
        await syncPersonalizedProfile(guest);
        return _currentUser;
      }

      final GoogleSignInAuthentication googleAuth = await googleUser.authentication;
      final credential = GoogleAuthProvider.credential(
        accessToken: googleAuth.accessToken,
        idToken: googleAuth.idToken,
      );

      final userCredential = await _auth.signInWithCredential(credential);
      final firebaseUser = userCredential.user;

      if (firebaseUser != null) {
        final serverUser = await ApiService.authenticateGoogleUser(
          googleId: firebaseUser.uid,
          name: firebaseUser.displayName ?? 'Player',
          email: firebaseUser.email ?? '',
          avatarUrl: firebaseUser.photoURL ?? 'https://api.dicebear.com/7.x/adventurer/png?seed=${firebaseUser.uid}',
        );
        if (serverUser == null) {
          print('Backend API authentication failed/returned null. Falling back to Sandbox Guest.');
          final guest = _createSandboxGuestUser();
          await syncPersonalizedProfile(guest);
          return _currentUser;
        }
        await syncPersonalizedProfile(serverUser);
        return _currentUser;
      }
    } catch (e) {
      print('Google/Firebase Sign-In failed: $e. Falling back to Sandbox Guest Mode.');
      final guest = _createSandboxGuestUser();
      await syncPersonalizedProfile(guest);
      return _currentUser;
    }
    return null;
  }

  UserModel _createSandboxGuestUser() {
    final guestId = 'sandbox_guest'; // Stable guest ID for local session persistence
    _currentUser = UserModel(
      id: guestId,
      googleId: 'google_$guestId',
      name: 'ProLudoPlayer',
      email: 'guest@sandbox.local',
      avatarUrl: 'https://api.dicebear.com/7.x/adventurer/png?seed=$guestId',
      coins: 1000,
      wins: 0,
      losses: 0,
      fcmToken: '',
    );
    return _currentUser!;
  }

  Future<void> signOut() async {
    try {
      await _googleSignIn.signOut();
      await _auth.signOut();
    } catch (e) {
      print('Firebase signOut error: $e');
    }
    _currentUser = null;
  }
}