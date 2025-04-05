import 'dart:io';
import 'dart:math';
import 'package:path_provider/path_provider.dart';
import '../models/log_level.dart';
import 'logging_utils.dart';

/// A utility class for file operations
class FileUtils {
  final LoggingUtils _logger = LoggingUtils();
  final Random _random = Random();

  /// Generate a dummy profile image and save it locally
  Future<String?> generateDummyProfileImage(String userId) async {
    try {
      final Directory tempDir = await getTemporaryDirectory();
      final Directory appDocDir = await getApplicationDocumentsDirectory();

      // Generate more meaningful file and directory names
      final String fileName = 'profile.png';
      final Directory profilePicsDir = Directory(
        '${appDocDir.path}/profile_pics/$userId',
      );
      final String localPath = '${profilePicsDir.path}/$fileName';

      // Check if the file already exists, return it if it does
      final File outputFile = File(localPath);
      if (await outputFile.exists()) {
        return localPath;
      }

      // Create the directory if it doesn't exist
      if (!await profilePicsDir.exists()) {
        await profilePicsDir.create(recursive: true);
      }

      // Use a temporary file as our placeholder image
      final File tempFile = File(
        '${tempDir.path}/temp_profile_${_random.nextInt(1000)}.png',
      );
      await tempFile.writeAsString('Placeholder image content');

      // Copy to destination
      await tempFile.copy(localPath);

      // Clean up temp file
      if (await tempFile.exists()) {
        await tempFile.delete();
      }

      return localPath;
    } catch (e) {
      _logger.log(
        "ERROR generating dummy profile image: $e",
        level: LogLevel.ERROR,
      );
      return null;
    }
  }
}
