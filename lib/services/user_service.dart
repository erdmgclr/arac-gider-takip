import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class UserService {
  UserService._();

  static final UserService instance = UserService._();

  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  Future<void> createOrUpdateUser(User user) async {
    final DocumentReference<Map<String, dynamic>> reference = _firestore
        .collection('users')
        .doc(user.uid);

    final DocumentSnapshot<Map<String, dynamic>> snapshot = await reference
        .get();

    if (snapshot.exists) {
      await reference.update({
        'displayName': user.displayName,
        'email': user.email,
        'photoUrl': user.photoURL,
        'lastLoginAt': FieldValue.serverTimestamp(),
      });

      return;
    }

    await reference.set({
      'displayName': user.displayName,
      'email': user.email,
      'photoUrl': user.photoURL,
      'isPremium': false,
      'premiumEndDate': null,
      'createdAt': FieldValue.serverTimestamp(),
      'lastLoginAt': FieldValue.serverTimestamp(),
    });
  }
}
