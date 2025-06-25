import 'dart:io';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:evaluatix/user_model.dart';
import 'package:flutter/foundation.dart';

class UserRepository {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  Future<void> signUp({
    required String email,
    required String password,
    required String faceImage,
    String? displayName,
    bool useCloud = false,
  }) async {
    try {
      final UserCredential credential = await _auth.createUserWithEmailAndPassword(
        email: email,
        password: password,
      );
      await _firestore.collection('users').doc(credential.user!.uid).set({
        'email': email,
        'displayName': displayName,
        useCloud ? 'faceImageUrl' : 'faceImagePath': faceImage,
        'useCloud': useCloud,
        'createdAt': FieldValue.serverTimestamp(),
      });
    } catch (e) {
      rethrow;
    }
  }

  Future<void> updateUser({
    required String userId,
    required String newFaceImage,
    bool useCloud = false,
  }) async {
    try {
      await _firestore.collection('users').doc(userId).update({
        useCloud ? 'faceImageUrl' : 'faceImagePath': newFaceImage,
        'useCloud': useCloud,
      });
    } catch (e) {
      rethrow;
    }
  }

  Future<UserModel?> getUser(String userId) async {
    try {
      final doc = await _firestore.collection('users').doc(userId).get();
      if (doc.exists) {
        return UserModel.fromMap(doc.data()!, doc.id);
      }
      return null;
    } catch (e) {
      debugPrint('Erreur lors de la récupération de l\'utilisateur: $e');
      return null;
    }
  }
}