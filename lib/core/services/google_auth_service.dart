import 'dart:async';
import 'package:extension_google_sign_in_as_googleapis_auth/extension_google_sign_in_as_googleapis_auth.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:google_sign_in_platform_interface/google_sign_in_platform_interface.dart';
import 'package:googleapis/drive/v3.dart' as drive;
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'drive_sync_service.dart';

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
    } catch (_) {
      // Ignored for offline mode
    }
  }

  Future<bool> isLoggedIn() async {
    if (_currentUser != null) return true;
    final cached = await getCachedUserData();
    return cached?['email'] != null;
  }

  /// Dapatkan AuthClient untuk Drive API.
  /// Jika [interactive] bernilai false (mode background sync / auto sync),
  /// pemanggilan ini 100% senyap (SILENT) dan TIDAK AKAN PERNAH memunculkan drawer / dialog pilih akun.
  Future<http.Client?> getDriveAuthClient({bool interactive = false}) async {
    await initialize();

    // 1. Coba via _currentUser di memori secara silent
    if (_currentUser != null) {
      try {
        final authz = await _currentUser!.authorizationClient.authorizationForScopes(
          [drive.DriveApi.driveAppdataScope],
        );
        if (authz != null) {
          return authz.authClient(scopes: [drive.DriveApi.driveAppdataScope]);
        }
      } catch (_) {}
    }

    // 2. Jika tidak ada di memori, coba via GoogleSignInPlatform secara silent dengan email tersimpan
    final cached = await getCachedUserData();
    final cachedEmail = cached?['email'];
    if (cachedEmail != null) {
      try {
        final tokenData = await GoogleSignInPlatform.instance.clientAuthorizationTokensForScopes(
          ClientAuthorizationTokensForScopesParameters(
            request: AuthorizationRequestDetails(
              scopes: const [drive.DriveApi.driveAppdataScope],
              userId: null,
              email: cachedEmail,
              promptIfUnauthorized: false, // JANGAN PERNAH MUNCULKAN UI
            ),
          ),
        );

        if (tokenData != null && tokenData.accessToken.isNotEmpty) {
          final authz = GoogleSignInClientAuthorization(accessToken: tokenData.accessToken);
          return authz.authClient(scopes: [drive.DriveApi.driveAppdataScope]);
        }
      } catch (_) {}
    }

    // 3. Hanya jika dipanggil dari aksi interaktif pengguna (tombol "Masuk" atau "Cadangkan Sekarang"),
    // baru izinkan prompt interaktif jika token silent belum tersedia.
    if (interactive) {
      if (_currentUser != null) {
        try {
          final authz = await _currentUser!.authorizationClient.authorizeScopes(
            [drive.DriveApi.driveAppdataScope],
          );
          return authz.authClient(scopes: [drive.DriveApi.driveAppdataScope]);
        } catch (_) {}
      } else {
        final account = await signIn();
        if (account != null) {
          try {
            final authz = await account.authorizationClient.authorizeScopes(
              [drive.DriveApi.driveAppdataScope],
            );
            return authz.authClient(scopes: [drive.DriveApi.driveAppdataScope]);
          } catch (_) {}
        }
      }
    }

    return null;
  }

  Future<GoogleSignInAccount?> ensureAuthenticated({bool interactive = false}) async {
    if (_currentUser != null) return _currentUser;
    if (interactive) {
      return signIn();
    }
    return null;
  }

  Future<GoogleSignInAccount?> signIn() async {
    try {
      await initialize();
      final account = await GoogleSignIn.instance.authenticate(
        scopeHint: [drive.DriveApi.driveAppdataScope],
      );
      _currentUser = account;
      await _saveCachedUser(account);
      _userStreamController.add(account);

      // Otorisasi Drive scope sekali di awal saat user login interaktif
      try {
        final authz = await account.authorizationClient.authorizeScopes([drive.DriveApi.driveAppdataScope]);
        final client = authz.authClient(scopes: [drive.DriveApi.driveAppdataScope]);
        DriveSyncService.instance.setCachedDriveClient(client);
      } catch (_) {
        DriveSyncService.instance.invalidateCachedDriveApi();
      }

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
    DriveSyncService.instance.invalidateCachedDriveApi();
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
