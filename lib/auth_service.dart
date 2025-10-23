import 'package:firebase_auth/firebase_auth.dart';
// Make sure this path is correct now
import 'package:flut1/firestore_service.dart'; 
import 'package:google_sign_in/google_sign_in.dart';
import 'package:firebase_messaging/firebase_messaging.dart';

class AuthService {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  
  // VERIFY: Initialization - this is the standard way
  final GoogleSignIn _googleSignIn = GoogleSignIn.instance;  
  final FirestoreService _firestoreService = FirestoreService(); 

  Stream<User?> get authStateChanges => _auth.authStateChanges();
  User? get currentUser => _auth.currentUser;

  // --- ANONYMOUS SIGN-IN ---
  Future<User?> signInAnonymously() async {
    try {
      final userCredential = await _auth.signInAnonymously();
      print("Signed in anonymously: ${userCredential.user?.uid}");
      // Optionally create Firestore doc for anonymous user if needed
      // Note: Anonymous users often don't need a Firestore doc unless you plan to upgrade them later.
      return userCredential.user;
    } on FirebaseAuthException catch (e) {
      print("Anonymous Sign-In Error: ${e.message}");
      rethrow; 
    }
  }

  // --- EMAIL & PASSWORD SIGN-UP ---
  Future<User?> createUserWithEmailAndPassword(String email, String password) async {
    try {
      final userCredential = await _auth.createUserWithEmailAndPassword(
        email: email,
        password: password,
      );
      print("Signed up with email: ${userCredential.user?.uid}");
      
      // --- Create user document in Firestore ---
      if (userCredential.user != null) {
         print("New Email user detected, creating Firestore entry.");
         // Get FCM token first
         final fcmToken = await FirebaseMessaging.instance.getToken() ?? 'no_token_yet'; 
         await _firestoreService.createUser(userCredential.user!, fcmToken);
         print("Firestore document created for email user.");
      }
      // ------------------------------------------

      return userCredential.user;
    } on FirebaseAuthException catch (e) {
      print("Email Sign-Up Error: ${e.message}");
      rethrow; 
    }
  }

  // --- EMAIL & PASSWORD SIGN-IN ---
  Future<User?> signInWithEmailAndPassword(String email, String password) async {
    try {
      final userCredential = await _auth.signInWithEmailAndPassword(
        email: email,
        password: password,
      );
      print("Signed in with email: ${userCredential.user?.uid}");
      
      // TODO: Update FCM token in Firestore upon login if needed
      // (Good practice to ensure the token list is current)

      return userCredential.user;
    } on FirebaseAuthException catch (e) {
      print("Email Sign-In Error: ${e.message}");
      rethrow;
    }
  }

  // --- GOOGLE SIGN-IN ---
  Future<User?> signInWithGoogle() async {
    try {
      // FIX: Use authenticate() instead of signIn()
      final GoogleSignInAccount? googleUser = await _googleSignIn.authenticate(); // <--- CHANGE HERE

      if (googleUser == null) {
        // The user canceled the sign-in
        print("Google Sign-In cancelled by user.");
        return null;
      }

      // Obtain the auth details (This part relies on GoogleSignInAuthentication being recognized)
      final GoogleSignInAuthentication googleAuth = googleUser.authentication;

      // Create a Firebase credential
      final OAuthCredential credential = GoogleAuthProvider.credential(
        accessToken: null, // Note: accessToken might be null depending on platform/scopes
        idToken: googleAuth.idToken,         // idToken is generally what Firebase needs
      );

      // Sign in to Firebase
      final UserCredential userCredential = await _auth.signInWithCredential(credential);
      print("Signed in with Google: ${userCredential.user?.uid}");

      // Create/Update Firestore document
      if (userCredential.user != null) {
         final fcmToken = await FirebaseMessaging.instance.getToken() ?? 'no_token_yet';
         if (userCredential.additionalUserInfo?.isNewUser ?? false) {
            print("New Google user, creating Firestore entry.");
            User firebaseUser = userCredential.user!;
            await _firestoreService.createUser(firebaseUser, fcmToken);
            print("Firestore document created.");
         } else {
           print("Existing Google user logged in.");
            // Ensure updateUserToken is implemented in FirestoreService
            await _firestoreService.updateUserToken(userCredential.user!.uid, fcmToken);
         }
      }

      return userCredential.user;
    } on FirebaseAuthException catch (e) {
      print("Google Sign-In Firebase Error: ${e.message}");
      // Handle specific errors like 'account-exists-with-different-credential' if needed
      rethrow;
    } catch (e) {
      print("Google Sign-In General Error: $e");
      throw Exception('An unexpected error occurred during Google Sign-In.');
    }
  }

  // --- SIGN OUT ---
  Future<void> signOut() async {
    try {
      bool isGoogleUser = false;
      if (_auth.currentUser != null) {
        for (UserInfo userInfo in _auth.currentUser!.providerData) {
          if (userInfo.providerId == GoogleAuthProvider.PROVIDER_ID) {
            isGoogleUser = true;
            break;
          }
        }
      }
      
      if (isGoogleUser) {
        await _googleSignIn.signOut(); // Sign out from Google
        print("Signed out from Google");
      }
      await _auth.signOut(); // Sign out from Firebase
      print("Signed out from Firebase");
    } catch (e) {
      print("Sign Out Error: $e");
    }
  }
}