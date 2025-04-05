import 'dart:math';
import 'package:cloud_firestore/cloud_firestore.dart';

import '../models/log_level.dart';
import '../models/static_data.dart';
import '../services/batch_manager.dart';
import '../utils/file_utils.dart';
import '../utils/logging_utils.dart';

/// A class dedicated to generating group data and group memberships
class GroupGenerator {
  final FirebaseFirestore _firestore;
  final LoggingUtils _logger = LoggingUtils();
  final FileUtils _fileUtils = FileUtils();
  final Random _random = Random();

  GroupGenerator(this._firestore);

  /// Generate groups with proper structure
  Future<List<String>> generateGroups(
    List<String> userIds,
    List<String> tagIds,
    Map<String, Map<String, dynamic>> userData,
    BatchManager batchManager,
  ) async {
    _logger.log("Starting group generation", level: LogLevel.INFO);

    final List<String> groupIds = [];
    final groupData = StaticData.getGroupData();

    // Pre-generate profile images in parallel
    final Map<String, Future<String?>> groupImageFutures = {};

    for (int i = 0; i < min(StaticData.NUM_GROUPS, groupData.length); i++) {
      final String groupName = groupData[i]['name'] ?? '';
      if (groupName.isEmpty) continue;

      final String groupId =
          'group_${groupName.toLowerCase().replaceAll(' ', '_')}_${_random.nextInt(1000)}';
      groupImageFutures[groupId] = _fileUtils.generateDummyProfileImage(
        'group_$groupId',
      );
    }

    _logger.log(
      "Pre-generating ${groupImageFutures.length} group profile images",
      level: LogLevel.INFO,
    );

    // Wait for all profile images to be generated
    final Map<String, String?> groupImages = {};
    await Future.wait(
      groupImageFutures.entries.map((entry) async {
        groupImages[entry.key] = await entry.value;
      }),
    );

    // Create group documents
    for (int i = 0; i < min(StaticData.NUM_GROUPS, groupData.length); i++) {
      final String groupName = groupData[i]['name'] ?? '';
      if (groupName.isEmpty) {
        _logger.log(
          "WARNING: Skipping group with empty name at index $i",
          level: LogLevel.WARNING,
        );
        continue;
      }

      final String groupId =
          'group_${groupName.toLowerCase().replaceAll(' ', '_')}_${_random.nextInt(1000)}';
      groupIds.add(groupId);
      _logger.log(
        "Creating group: $groupId - ${groupData[i]['name']}",
        level: LogLevel.DEBUG,
      );

      // Select a random creator (mentor)
      final String creatorId = userIds[_random.nextInt(userIds.length)];
      _logger.log("Selected creator: $creatorId", level: LogLevel.DEBUG);

      // Get pre-generated group profile image
      final String? photoURL = groupImages[groupId];
      _logger.log(
        "Group profile image: ${photoURL != null ? 'Available' : 'Failed'}",
        level: LogLevel.DEBUG,
      );

      // Select random tags for this group (2-5 tags)
      final List<String> groupTags = [];
      final int numTags = _random.nextInt(4) + 2;

      final List<String> availableTags = List.from(tagIds);
      availableTags.shuffle(_random);
      groupTags.addAll(availableTags.take(numTags));

      // Create the group document
      final groupRef = _firestore.collection('groups').doc(groupId);

      // Determine if this group requires approval to join
      final bool requiresApproval = _random.nextBool();

      await batchManager.set(groupRef, {
        'name': groupData[i]['name'],
        'description': groupData[i]['description'],
        'createdAt': FieldValue.serverTimestamp(),
        'creatorId': creatorId,
        'photoURL': photoURL,
        'tags': groupTags,
        'settings': {
          'visibility': ['public', 'private'][_random.nextInt(2)],
          'joinApproval': requiresApproval,
        },
      });

      // Add creator as mentor member
      final creatorMemberRef = groupRef.collection('members').doc(creatorId);
      await batchManager.set(creatorMemberRef, {
        'displayName': userData[creatorId]?['displayName'] ?? 'Unknown User',
        'photoURL': userData[creatorId]?['photoURL'],
        'role': 'mentor',
        'joinedAt': FieldValue.serverTimestamp(),
      });

      // Add group to creator's groups collection
      final creatorRef = _firestore.collection('users').doc(creatorId);
      final creatorGroupRef = creatorRef.collection('groups').doc(groupId);
      await batchManager.set(creatorGroupRef, {
        'name': groupData[i]['name'],
        'photoURL': photoURL,
        'role': 'mentor',
        'joinedAt': FieldValue.serverTimestamp(),
      });

      // Create standard channels for this group (in batch)
      await _createGroupChannels(groupId, creatorId, batchManager);

      // Add this group to each of its tags' groups subcollection
      for (String tagId in groupTags) {
        final tagGroupRef = _firestore
            .collection('tags')
            .doc(tagId)
            .collection('groups')
            .doc(groupId);

        await batchManager.set(tagGroupRef, {
          'name': groupData[i]['name'],
          'photoURL': photoURL,
          'addedAt': FieldValue.serverTimestamp(),
        });
      }
    }

    _logger.log(
      "Completed group generation. Created ${groupIds.length} groups",
      level: LogLevel.INFO,
    );
    return groupIds;
  }

  /// Create standard channels for a group
  Future<void> _createGroupChannels(
    String groupId,
    String creatorId,
    BatchManager batchManager,
  ) async {
    final groupRef = _firestore.collection('groups').doc(groupId);

    // Discussion channel
    final discussionChannelId =
        'channel_discussion_${groupId}_${_random.nextInt(1000)}';
    final discussionChannelRef = groupRef
        .collection('channels')
        .doc(discussionChannelId);
    await batchManager.set(discussionChannelRef, {
      'name': 'General Discussion',
      'description': 'Channel for general discussion and announcements',
      'type': 'discussion',
      'createdAt': FieldValue.serverTimestamp(),
      'createdBy': creatorId,
      'instructions':
          'Use this channel for general communication and announcements.',
    });

    // Assessment channel
    final assessmentChannelId =
        'channel_assessment_${groupId}_${_random.nextInt(1000)}';
    final assessmentChannelRef = groupRef
        .collection('channels')
        .doc(assessmentChannelId);
    await batchManager.set(assessmentChannelRef, {
      'name': 'Assessments',
      'description': 'Channel for group assessments and quizzes',
      'type': 'assessment',
      'createdAt': FieldValue.serverTimestamp(),
      'createdBy': creatorId,
      'instructions':
          'Use this channel to access and complete shared assessments.',
    });

    // Resource channel
    final resourceChannelId =
        'channel_resource_${groupId}_${_random.nextInt(1000)}';
    final resourceChannelRef = groupRef
        .collection('channels')
        .doc(resourceChannelId);
    await batchManager.set(resourceChannelRef, {
      'name': 'Resources',
      'description': 'Channel for sharing educational resources',
      'type': 'resource',
      'createdAt': FieldValue.serverTimestamp(),
      'createdBy': creatorId,
      'instructions':
          'Share and access helpful learning resources in this channel.',
    });
  }

  /// Create group memberships and invitations
  Future<void> createGroupMemberships(
    List<String> userIds,
    List<String> groupIds,
    Map<String, Map<String, dynamic>> userData,
    BatchManager batchManager,
  ) async {
    _logger.log("Starting group membership creation", level: LogLevel.INFO);
    int membershipsCreated = 0;
    int invitesCreated = 0;
    int requestsCreated = 0;

    // Get all group data in one batch to avoid repeated reads
    final Map<String, Map<String, dynamic>> groupData = {};
    final List<Future<void>> groupDataFutures = [];

    for (String groupId in groupIds) {
      groupDataFutures.add(
        _firestore.collection('groups').doc(groupId).get().then((snapshot) {
          if (snapshot.exists) {
            groupData[groupId] = snapshot.data() ?? {};
          }
        }),
      );
    }

    await Future.wait(groupDataFutures);
    _logger.log(
      "Retrieved data for ${groupData.length} groups",
      level: LogLevel.INFO,
    );

    // For each group, add members and invitations
    for (String groupId in groupIds) {
      if (!groupData.containsKey(groupId)) {
        _logger.log(
          "WARNING: Group $groupId data not found, skipping",
          level: LogLevel.WARNING,
        );
        continue;
      }

      final String creatorId = groupData[groupId]?['creatorId'] ?? '';
      if (creatorId.isEmpty) {
        _logger.log(
          "WARNING: Group $groupId has no creator ID, skipping",
          level: LogLevel.WARNING,
        );
        continue;
      }

      final bool requiresApproval =
          groupData[groupId]?['settings']?['joinApproval'] ?? false;
      final String groupName = groupData[groupId]?['name'] ?? 'Group $groupId';
      final String? groupPhotoURL = groupData[groupId]?['photoURL'];

      // Get potential members (all users except creator)
      final List<String> potentialMemberIds =
          userIds.where((id) => id != creatorId).toList();

      // Decide how many members this group will have
      final int numberOfMembers = min(
        _random.nextInt(
              StaticData.MAX_GROUP_MEMBERS - StaticData.MIN_GROUP_MEMBERS + 1,
            ) +
            StaticData.MIN_GROUP_MEMBERS,
        potentialMemberIds.length,
      );
      _logger.log(
        "Adding $numberOfMembers members to group $groupId",
        level: LogLevel.DEBUG,
      );

      // Shuffle user list for random selection
      potentialMemberIds.shuffle(_random);

      // Add members to the group
      final List<String> memberIds =
          potentialMemberIds.take(numberOfMembers).toList();
      final List<String> remainingUsers =
          potentialMemberIds.skip(numberOfMembers).toList();

      await _addMembersToGroup(
        groupId,
        memberIds,
        groupName,
        groupPhotoURL,
        userData,
        batchManager,
      );
      membershipsCreated += memberIds.length;

      // Create pending invites for this group (3-6 invites)
      if (remainingUsers.isNotEmpty) {
        invitesCreated += await _createGroupInvites(
          groupId,
          creatorId,
          remainingUsers,
          groupName,
          userData,
          batchManager,
        );
      }

      // Create join requests if group requires approval
      if (requiresApproval && remainingUsers.isNotEmpty) {
        requestsCreated += await _createJoinRequests(
          groupId,
          remainingUsers,
          userData,
          batchManager,
        );
      }
    }

    _logger.log(
      "Completed group membership creation: $membershipsCreated memberships, $invitesCreated invites, $requestsCreated requests",
      level: LogLevel.INFO,
    );
  }

  /// Add members to a group
  Future<void> _addMembersToGroup(
    String groupId,
    List<String> memberIds,
    String groupName,
    String? groupPhotoURL,
    Map<String, Map<String, dynamic>> userData,
    BatchManager batchManager,
  ) async {
    final groupRef = _firestore.collection('groups').doc(groupId);

    // Add all members in batch
    for (String memberId in memberIds) {
      // Add user as student member to group
      final memberRef = groupRef.collection('members').doc(memberId);
      await batchManager.set(memberRef, {
        'displayName': userData[memberId]?['displayName'] ?? 'Unknown User',
        'photoURL': userData[memberId]?['photoURL'],
        'role': 'student',
        'joinedAt': FieldValue.serverTimestamp(),
      });

      // Add group to user's groups subcollection
      final userRef = _firestore.collection('users').doc(memberId);
      final userGroupRef = userRef.collection('groups').doc(groupId);
      await batchManager.set(userGroupRef, {
        'name': groupName,
        'photoURL': groupPhotoURL,
        'role': 'student',
        'joinedAt': FieldValue.serverTimestamp(),
      });
    }
  }

  /// Create group invites
  Future<int> _createGroupInvites(
    String groupId,
    String creatorId,
    List<String> remainingUsers,
    String groupName,
    Map<String, Map<String, dynamic>> userData,
    BatchManager batchManager,
  ) async {
    int invitesCreated = 0;
    final int numberOfInvites = min(
      _random.nextInt(4) + 3,
      remainingUsers.length,
    );

    // Use shuffle and take for randomness
    final List<String> usersToInvite = List.from(remainingUsers);
    usersToInvite.shuffle(_random);
    final invitedUsers = usersToInvite.take(numberOfInvites).toList();

    final groupRef = _firestore.collection('groups').doc(groupId);

    for (String invitedUserId in invitedUsers) {
      // Add to group's pendingInvites subcollection
      final pendingInviteRef = groupRef
          .collection('pendingInvites')
          .doc(invitedUserId);
      await batchManager.set(pendingInviteRef, {
        'displayName':
            userData[invitedUserId]?['displayName'] ?? 'Unknown User',
        'invitedBy': creatorId,
        'invitedAt': FieldValue.serverTimestamp(),
        'status': 'pending',
      });

      // Add to user's groupInvites subcollection with a unique ID
      final userRef = _firestore.collection('users').doc(invitedUserId);
      final userInviteRef = userRef
          .collection('groupInvites')
          .doc('invite_${groupId}_${invitedUserId}_${_random.nextInt(10000)}');
      await batchManager.set(userInviteRef, {
        'groupId': groupId,
        'groupName': groupName,
        'invitedBy': creatorId,
        'inviterName': userData[creatorId]?['displayName'] ?? 'Unknown User',
        'createdAt': FieldValue.serverTimestamp(),
        'status': 'pending',
      });

      invitesCreated++;
    }

    return invitesCreated;
  }

  /// Create join requests for a group
  Future<int> _createJoinRequests(
    String groupId,
    List<String> remainingUsers,
    Map<String, Map<String, dynamic>> userData,
    BatchManager batchManager,
  ) async {
    int requestsCreated = 0;
    final int numberOfRequests = min(
      _random.nextInt(3) + 2,
      remainingUsers.length,
    );

    // Use shuffle and take for randomness
    final List<String> usersToRequest = List.from(remainingUsers);
    usersToRequest.shuffle(_random);
    final requestUsers = usersToRequest.take(numberOfRequests).toList();

    final groupRef = _firestore.collection('groups').doc(groupId);

    for (String requestUserId in requestUsers) {
      // Add to group's joinRequests subcollection
      final joinRequestRef = groupRef
          .collection('joinRequests')
          .doc(requestUserId);
      await batchManager.set(joinRequestRef, {
        'displayName':
            userData[requestUserId]?['displayName'] ?? 'Unknown User',
        'photoURL': userData[requestUserId]?['photoURL'],
        'requestedAt': FieldValue.serverTimestamp(),
        'status': 'pending',
        'message': 'I would like to join this group',
      });

      requestsCreated++;
    }

    return requestsCreated;
  }
}
