import 'dart:io';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:logger/logger.dart';
import 'package:uuid/uuid.dart';
import 'package:flutter/material.dart';

import '../models/assessment.dart';
import '../utils/constants.dart';

class StorageService {
  final Logger _logger = Logger();
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseStorage _storage = FirebaseStorage.instance;
  final FlutterSecureStorage _secureStorage = const FlutterSecureStorage();
  final Uuid _uuid = const Uuid();

  Future<String?> loadApiKey() async {
    try {
      final apiKey = await _secureStorage.read(
        key: AppConstants.apiKeyStorageKey,
      );
      if (apiKey != null && apiKey.isNotEmpty) {
        _logger.i('API key loaded from secure storage');
        return apiKey;
      }
      _logger.i('No API key found in secure storage');
      return null;
    } catch (e) {
      _logger.e('Error loading API key from secure storage', error: e);
      return null;
    }
  }

  Future<bool> saveApiKey(String apiKey) async {
    try {
      await _secureStorage.write(
        key: AppConstants.apiKeyStorageKey,
        value: apiKey,
      );
      _logger.i('API key saved to secure storage');
      return true;
    } catch (e) {
      _logger.e('Error saving API key to secure storage', error: e);
      return false;
    }
  }

  Future<bool> checkFirstTimeUser() async {
    try {
      final currentUser = _auth.currentUser;
      if (currentUser == null) {
        _logger.w('No authenticated user found');
        return true;
      }

      final userData =
          await _firestore
              .collection(AppConstants.usersCollection)
              .doc(currentUser.uid)
              .get();

      if (!userData.exists || userData.data() == null) {
        _logger.w('User document is empty');
        return true;
      }

      final isFirstTime = userData['hasUsedAIAssistant'] != true;

      if (isFirstTime) {
        await _firestore
            .collection(AppConstants.usersCollection)
            .doc(currentUser.uid)
            .update({'hasUsedAIAssistant': true});
      }

      return isFirstTime;
    } catch (e) {
      _logger.e('Error checking first time user', error: e);
      return true;
    }
  }

  Future<String?> uploadPdfToStorage(File pdfFile, String fileName) async {
    try {
      if (!pdfFile.existsSync()) {
        throw FileSystemException('PDF file does not exist');
      }

      _logger.i('Uploading PDF to Firebase Storage');

      final currentUser = _auth.currentUser;
      if (currentUser == null) {
        throw StateError('User not authenticated');
      }

      final storageRef = _storage.ref().child(
        'pdfs/${currentUser.uid}/$fileName',
      );

      final uploadTask = storageRef.putFile(pdfFile);

      uploadTask.snapshotEvents.listen((TaskSnapshot snapshot) {
        final progress = snapshot.bytesTransferred / snapshot.totalBytes;
        _logger.d('Upload progress: ${(progress * 100).toStringAsFixed(2)}%');
      });

      final snapshot = await uploadTask.whenComplete(() => null);
      final downloadUrl = await snapshot.ref.getDownloadURL();

      _logger.i('PDF uploaded successfully');
      return downloadUrl;
    } catch (e) {
      _logger.e('Error uploading PDF to storage', error: e);
      return null;
    }
  }

  Future<bool> saveAssessmentToFirestore(
    Map<String, dynamic> generatedQuestions, {
    required String pdfName,
    required String pdfUrl,
    required RangeValues pageRange,
    required String difficulty,
    required int totalPoints,
  }) async {
    try {
      _logger.i('Saving assessment to Firestore');

      final currentUser = _auth.currentUser;
      if (currentUser == null) {
        throw Exception('User not logged in');
      }

      final assessmentId = _uuid.v4();
      final assessmentRef = _firestore
          .collection(AppConstants.assessmentsCollection)
          .doc(assessmentId);

      await assessmentRef.set({
        'title': 'Assessment on $pdfName',
        'creatorId': currentUser.uid,
        'sourceDocumentId': pdfUrl,
        'createdAt': FieldValue.serverTimestamp(),
        'description':
            'Generated from pages ${pageRange.start.toInt()} to ${pageRange.end.toInt()} of $pdfName',
        'difficulty': difficulty,
        'isPublic': false,
        'totalPoints': totalPoints,
        'tags':
            generatedQuestions['tags'] != null
                ? generatedQuestions['tags'].map((tag) => tag['tagId']).toList()
                : [],
        'rating': 0,
        'madeByAI': true,
      });

      final questions = generatedQuestions['questions'] as List<dynamic>;
      for (final question in questions) {
        await assessmentRef
            .collection(AppConstants.questionsCollection)
            .doc(question['questionId'])
            .set({
              'questionType': question['questionType'],
              'questionText': question['questionText'],
              'options': question['options'] ?? [],
              'points': question['points'],
            });
      }

      final answers = generatedQuestions['answers'] as List<dynamic>;
      for (final answer in answers) {
        await assessmentRef
            .collection(AppConstants.answersCollection)
            .doc(answer['answerId'])
            .set({
              'questionId': answer['questionId'],
              'answerType': answer['answerType'],
              'answerText': answer['answerText'],
              'reasoning': answer['reasoning'],
            });
      }

      if (generatedQuestions['tags'] != null) {
        final tags = generatedQuestions['tags'] as List<dynamic>;
        for (final tag in tags) {
          final tagRef = _firestore
              .collection(AppConstants.tagsCollection)
              .doc(tag['tagId']);
          final tagDoc = await tagRef.get();

          if (!tagDoc.exists) {
            await tagRef.set({
              'name': tag['name'],
              'description': tag['description'],
              'category': tag['category'],
            });
          }
        }
      }

      await _firestore
          .collection(AppConstants.usersCollection)
          .doc(currentUser.uid)
          .collection(AppConstants.assessmentsCollection)
          .doc(assessmentId)
          .set({
            'title': 'Assessment on $pdfName',
            'createdAt': FieldValue.serverTimestamp(),
            'description':
                'Generated from pages ${pageRange.start.toInt()} to ${pageRange.end.toInt()} of $pdfName',
            'difficulty': difficulty,
            'totalPoints': totalPoints,
            'rating': 0,
            'sourceDocumentId': pdfUrl,
            'madeByAI': true,
            'wasSharedWithUser': false,
            'wasSharedInGroup': false,
          });

      _logger.i('Assessment saved successfully with ID: $assessmentId');
      return true;
    } catch (e) {
      _logger.e('Error saving assessment to Firestore', error: e);
      return false;
    }
  }
}
