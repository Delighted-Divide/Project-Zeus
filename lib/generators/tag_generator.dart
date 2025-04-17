import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/log_level.dart';
import '../models/static_data.dart';
import '../services/batch_manager.dart';
import '../utils/logging_utils.dart';
import 'dart:math';

class TagGenerator {
  final FirebaseFirestore _firestore;
  final LoggingUtils _logger = LoggingUtils();

  TagGenerator(this._firestore);

  Future<List<String>> generateTags(BatchManager batchManager) async {
    final List<String> tagIds = [];
    _logger.log("Starting tag generation", level: LogLevel.INFO);

    final List<Map<String, String>> subjectTags = StaticData.getSubjectTags();
    final List<Map<String, String>> topicTags = StaticData.getTopicTags();
    final List<Map<String, String>> skillTags = StaticData.getSkillTags();

    final List<Map<String, String>> allTags = [
      ...subjectTags,
      ...topicTags,
      ...skillTags,
    ];

    for (var tag in allTags) {
      final String tagName = tag['name'] ?? '';
      if (tagName.isEmpty) {
        _logger.log(
          "WARNING: Skipping tag with empty name",
          level: LogLevel.WARNING,
        );
        continue;
      }

      final String tagId = 'tag_${tagName.toLowerCase().replaceAll(' ', '_')}';
      tagIds.add(tagId);

      _logger.log(
        "Creating tag: $tagId - ${tag['name']} (${tag['category']})",
        level: LogLevel.DEBUG,
      );

      final tagRef = _firestore.collection('tags').doc(tagId);
      await batchManager.set(tagRef, {
        'name': tag['name'],
        'category': tag['category'],
        'description': tag['description'],
        'createdAt': FieldValue.serverTimestamp(),
      });
    }

    _logger.log("Created ${tagIds.length} tags", level: LogLevel.INFO);
    return tagIds;
  }

  Future<void> assignFavoriteTags(
    List<String> userIds,
    List<String> tagIds,
    BatchManager batchManager,
  ) async {
    _logger.log(
      "Starting assigning favorite tags to users",
      level: LogLevel.INFO,
    );
    final Random _random = Random();

    for (String userId in userIds) {
      final int numFavTags = _random.nextInt(5) + 2;
      _logger.log(
        "Assigning $numFavTags favorite tags to user $userId",
        level: LogLevel.DEBUG,
      );

      final List<String> userFavTags = [];

      final List<String> availableTags = List.from(tagIds);
      availableTags.shuffle(_random);

      userFavTags.addAll(availableTags.take(numFavTags));

      final userRef = _firestore.collection('users').doc(userId);
      await batchManager.update(userRef, {'favTags': userFavTags});

      _logger.log(
        "Added ${userFavTags.length} tags to user $userId",
        level: LogLevel.DEBUG,
      );
    }

    _logger.log("Completed assigning favorite tags", level: LogLevel.INFO);
  }
}
