import 'dart:async';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:googleapis/drive/v3.dart' as drive;
import 'package:shared_preferences/shared_preferences.dart';

class GoogleAuthService {
  GoogleAuthService._();
  static final GoogleAuthService instance = GoogleAuthService._();

  static const _prefKeyEmail = 'google_user_email';
  static const _prefKeyName = 'google_user_name';
  static const _prefKeyPhoto = 'google_user_photo';
  static const _prefKeyIsLoggedIn = 'google_is_logged_in';

  /// Google Cloud Console OAuth 2.0 Web Client ID
  static const String serverClientId =
      '682065182512-oq0g8l0r5n85qavl7jvsrggbbfuaegj8.apps.googleusercontent.com';

  bool _initialized = false;
  GoogleSignInAccount? _currentUser;
  final _userStreamController = StreamController<GoogleSignInAccount?>.broadcast();

  Stream<GoogleSignInAccount?> get authStateChanges => _userStreamController.stream;
  GoogleSignInAccount? get currentUser => _currentUser;

  Future<void> initialize() async {
    if (_initialized) return;
    _initialized = true;

    try {
      await GoogleSignIn.instance.initialize(
        serverClientId: serverClientId,
      );
      GoogleSignIn.instance.authenticationEvents.listen((event) {
        if (event is GoogleSignInAuthenticationEventSignIn) {
          _currentUser = event.user;
          _saveCachedUser(event.user);
          _userStreamController.add(event.user);
        } else if (event is GoogleSignInAuthenticationEventSignOut) {
          _currentUser = null;
          _clearCachedUser();
          _userStreamController.add(null);
        }
      });

      // Attempt silent/lightweight restore
      final restoreFuture = GoogleSignIn.instance.attemptLightweightAuthentication();
      if (restoreFuture != null) {
        final restored = await restoreFuture;
        if (restored != null) {
          _currentUser = restored;
          await _saveCachedUser(restored);
          _userStreamController.add(restored);
        }
      }
    } catch (_) {
      // Ignored for offline mode
    }
  }

  Future<GoogleSignInAccount?> signIn() async {
    try {
      await initialize();
      final account = await GoogleSignIn.instance.authenticate();
      _currentUser = account;
      await _saveCachedUser(account);
      _userStreamController.add(account);
      return account;
    } catch (e) {
      rethrow;
    }
  }

  Future<void> signOut() async {
    try {
      await GoogleSignIn.instance.signOut();
    } catch (_) {}
    _currentUser = null;
    await _clearCachedUser();
    _userStreamController.add(null);
  }

  Future<void> _saveCachedUser(GoogleSignInAccount user) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_prefKeyIsLoggedIn, true);
    await prefs.setString(_prefKeyEmail, user.email);
    if (user.displayName != null) {
      await prefs.setString(_prefKeyName, user.displayName!);
    }
    if (user.photoUrl != null) {
      await prefs.setString(_prefKeyPhoto, user.photoUrl!);
    }
  }

  Future<void> _clearCachedUser() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_prefKeyIsLoggedIn, false);
    await prefs.remove(_prefKeyEmail);
    await prefs.remove(_prefKeyName);
    await prefs.remove(_prefKeyPhoto);
  }

  Future<Map<String, String?>?> getCachedUserData() async {
    final prefs = await SharedPreferences.getInstance();
    final isLoggedIn = prefs.getBool(_prefKeyIsLoggedIn) ?? false;
    if (!isLoggedIn) return null;
    return {
      'email': prefs.getString(_prefKeyEmail),
      'name': prefs.getString(_prefKeyName),
      'photo': prefs.getString(_prefKeyPhoto),
    };
  }
}
