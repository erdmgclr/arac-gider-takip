import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_sign_in/google_sign_in.dart';

import 'google_drive_service.dart';

class AuthService {
  AuthService._();

  static final AuthService instance = AuthService._();

  static const String _webClientId =
      '283458492848-fnggb4sjhdnnj922searur3engk3ih38.apps.googleusercontent.com';

  final FirebaseAuth _firebaseAuth = FirebaseAuth.instance;
  final GoogleSignIn _googleSignIn = GoogleSignIn.instance;

  bool _googleSignInInitialized = false;

  User? get currentUser => _firebaseAuth.currentUser;

  Stream<User?> get authStateChanges => _firebaseAuth.authStateChanges();

  Future<void> initializeGoogleSignIn() async {
    if (_googleSignInInitialized) return;

    await _googleSignIn.initialize(serverClientId: _webClientId);

    _googleSignInInitialized = true;
  }

  Future<UserCredential> signInWithGoogle() async {
    await initializeGoogleSignIn();

    try {
      final GoogleSignInAccount googleUser = await _googleSignIn.authenticate();
      GoogleDriveService.cacheAccount(googleUser);
      final GoogleSignInAuthentication googleAuthentication =
          googleUser.authentication;
      final String? idToken = googleAuthentication.idToken;

      if (idToken == null || idToken.isEmpty) {
        throw FirebaseAuthException(
          code: 'missing-google-id-token',
          message: 'Google hesabından kimlik belirteci alınamadı.',
        );
      }

      final OAuthCredential credential = GoogleAuthProvider.credential(
        idToken: idToken,
      );

      return _firebaseAuth.signInWithCredential(credential);
    } on GoogleSignInException catch (error) {
      throw FirebaseAuthException(
        code: 'google-sign-in-${error.code.name}',
        message: error.description ?? error.toString(),
      );
    }
  }

  Future<void> signOut() async {
    GoogleDriveService.clearSession();
    try {
      await _googleSignIn.signOut();
    } finally {
      await _firebaseAuth.signOut();
    }
  }
}
