import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_sign_in/google_sign_in.dart';
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

  Future<UserModel?> checkCurrentUserSession() async {
    if (_currentUser != null) return _currentUser;

    try {
      final firebaseUser = _auth.currentUser;
      if (firebaseUser != null) {
        _currentUser = await ApiService.authenticateGoogleUser(
          googleId: firebaseUser.uid,
          name: firebaseUser.displayName ?? 'Player',
          email: firebaseUser.email ?? '',
          avatarUrl: firebaseUser.photoURL ?? 'https://api.dicebear.com/7.x/bottts/png',
        );
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
        return _createSandboxGuestUser();
      }

      final GoogleSignInAccount? googleUser = await _googleSignIn.signIn();
      if (googleUser == null) {
        return _createSandboxGuestUser();
      }

      final GoogleSignInAuthentication googleAuth = await googleUser.authentication;
      final credential = GoogleAuthProvider.credential(
        accessToken: googleAuth.accessToken,
        idToken: googleAuth.idToken,
      );

      final userCredential = await _auth.signInWithCredential(credential);
      final firebaseUser = userCredential.user;

      if (firebaseUser != null) {
        _currentUser = await ApiService.authenticateGoogleUser(
          googleId: firebaseUser.uid,
          name: firebaseUser.displayName ?? 'Player',
          email: firebaseUser.email ?? '',
          avatarUrl: firebaseUser.photoURL ?? 'https://api.dicebear.com/7.x/adventurer/png?seed=${firebaseUser.uid}',
        );
        if (_currentUser == null) {
          print('Backend API authentication failed/returned null. Falling back to Sandbox Guest.');
          return _createSandboxGuestUser();
        }
        return _currentUser;
      }
    } catch (e) {
      print('Google/Firebase Sign-In failed: $e. Falling back to Sandbox Guest Mode.');
      return _createSandboxGuestUser();
    }
    return null;
  }

  UserModel _createSandboxGuestUser() {
    final guestId = 'sandbox_guest_${DateTime.now().millisecondsSinceEpoch.toString().substring(8)}';
    _currentUser = UserModel(
      id: guestId,
      googleId: 'google_$guestId',
      name: 'vikas',
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