import 'dart:math';
import 'package:cloud_firestore/cloud_firestore.dart';

import '../models/log_level.dart';
import '../models/static_data.dart';
import '../services/batch_manager.dart';
import '../utils/logging_utils.dart';

class SocialGenerator {
  final FirebaseFirestore _firestore;
  final LoggingUtils _logger = LoggingUtils();
  final Random _random = Random();

  SocialGenerator(this._firestore);

  Future<void> createFriendships(
    List<String> userIds,
    Map<String, Map<String, dynamic>> userData,
    BatchManager batchManager,
  ) async {
    _logger.log("Starting creating friend relationships", level: LogLevel.INFO);
    int friendshipsCreated = 0;
    int requestsCreated = 0;

    for (String userId in userIds) {
      final int numberOfFriends =
          _random.nextInt(StaticData.MAX_FRIENDS - StaticData.MIN_FRIENDS + 1) +
          StaticData.MIN_FRIENDS;
      _logger.log(
        "Creating $numberOfFriends friendships for user $userId",
        level: LogLevel.DEBUG,
      );

      final List<String> friendIds = [];
      final List<String> potentialFriends = List.from(userIds)..remove(userId);
      potentialFriends.shuffle(_random);

      final selectedFriends = potentialFriends.take(numberOfFriends).toList();

      for (final String friendId in selectedFriends) {
        friendIds.add(friendId);
        _logger.log(
          "Adding friendship between $userId and $friendId",
          level: LogLevel.DEBUG,
        );

        String userDisplayName =
            userData[userId]?['displayName'] ?? 'Unknown User';
        String friendDisplayName =
            userData[friendId]?['displayName'] ?? 'Unknown User';

        final userFriendDoc = _firestore
            .collection('users')
            .doc(userId)
            .collection('friends')
            .doc(friendId);

        await batchManager.set(userFriendDoc, {
          'displayName': friendDisplayName,
          'photoURL': userData[friendId]?['photoURL'],
          'becameFriendsAt': FieldValue.serverTimestamp(),
        });

        final friendUserDoc = _firestore
            .collection('users')
            .doc(friendId)
            .collection('friends')
            .doc(userId);

        await batchManager.set(friendUserDoc, {
          'displayName': userDisplayName,
          'photoURL': userData[userId]?['photoURL'],
          'becameFriendsAt': FieldValue.serverTimestamp(),
        });

        friendshipsCreated++;
      }

      final int numberOfRequests =
          _random.nextInt(
            StaticData.MAX_FRIEND_REQUESTS - StaticData.MIN_FRIEND_REQUESTS + 1,
          ) +
          StaticData.MIN_FRIEND_REQUESTS;
      _logger.log(
        "Creating $numberOfRequests friend requests for user $userId",
        level: LogLevel.DEBUG,
      );

      final List<String> remainingUsers =
          potentialFriends.where((id) => !friendIds.contains(id)).toList();
      remainingUsers.shuffle(_random);

      final requestUsers = remainingUsers.take(numberOfRequests).toList();

      for (final String requestUserId in requestUsers) {
        _logger.log(
          "Creating friend request between $userId and $requestUserId",
          level: LogLevel.DEBUG,
        );

        final bool isSent = _random.nextBool();

        if (isSent) {
          final userRef = _firestore.collection('users').doc(userId);
          final String sentRequestId =
              'sent_${userId}_${requestUserId}_${_random.nextInt(10000)}';
          final requestRef = userRef
              .collection('friendRequests')
              .doc(sentRequestId);

          await batchManager.set(requestRef, {
            'userId': requestUserId,
            'displayName':
                userData[requestUserId]?['displayName'] ?? 'Unknown User',
            'photoURL': userData[requestUserId]?['photoURL'],
            'type': 'sent',
            'status': 'pending',
            'createdAt': FieldValue.serverTimestamp(),
          });

          final otherUserRef = _firestore
              .collection('users')
              .doc(requestUserId);
          final String receivedRequestId =
              'received_${requestUserId}_${userId}_${_random.nextInt(10000)}';
          final otherRequestRef = otherUserRef
              .collection('friendRequests')
              .doc(receivedRequestId);

          await batchManager.set(otherRequestRef, {
            'userId': userId,
            'displayName': userData[userId]?['displayName'] ?? 'Unknown User',
            'photoURL': userData[userId]?['photoURL'],
            'type': 'received',
            'status': 'pending',
            'createdAt': FieldValue.serverTimestamp(),
          });
        } else {
          final userRef = _firestore.collection('users').doc(userId);
          final String receivedRequestId =
              'received_${userId}_${requestUserId}_${_random.nextInt(10000)}';
          final requestRef = userRef
              .collection('friendRequests')
              .doc(receivedRequestId);

          await batchManager.set(requestRef, {
            'userId': requestUserId,
            'displayName':
                userData[requestUserId]?['displayName'] ?? 'Unknown User',
            'photoURL': userData[requestUserId]?['photoURL'],
            'type': 'received',
            'status': 'pending',
            'createdAt': FieldValue.serverTimestamp(),
          });

          final otherUserRef = _firestore
              .collection('users')
              .doc(requestUserId);
          final String sentRequestId =
              'sent_${requestUserId}_${userId}_${_random.nextInt(10000)}';
          final otherRequestRef = otherUserRef
              .collection('friendRequests')
              .doc(sentRequestId);

          await batchManager.set(otherRequestRef, {
            'userId': userId,
            'displayName': userData[userId]?['displayName'] ?? 'Unknown User',
            'photoURL': userData[userId]?['photoURL'],
            'type': 'sent',
            'status': 'pending',
            'createdAt': FieldValue.serverTimestamp(),
          });
        }

        requestsCreated += 2;
      }
    }

    _logger.log(
      "Completed creating friend relationships: $friendshipsCreated friendships and $requestsCreated requests",
      level: LogLevel.INFO,
    );
  }
}
