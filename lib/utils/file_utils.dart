import 'dart:io';
import 'dart:math';
import 'package:path_provider/path_provider.dart';
import '../models/log_level.dart';
import 'logging_utils.dart';

class FileUtils {
  final LoggingUtils _logger = LoggingUtils();
  final Random _random = Random();

  Future<String?> generateDummyProfileImage(String userId) async {
    try {
      final Directory tempDir = await getTemporaryDirectory();
      final Directory appDocDir = await getApplicationDocumentsDirectory();

      final String fileName = 'profile.png';
      final Directory profilePicsDir = Directory(
        '${appDocDir.path}/profile_pics/$userId',
      );
      final String localPath = '${profilePicsDir.path}/$fileName';

      final File outputFile = File(localPath);
      if (await outputFile.exists()) {
        return localPath;
      }

      if (!await profilePicsDir.exists()) {
        await profilePicsDir.create(recursive: true);
      }

      final File tempFile = File(
        '${tempDir.path}/temp_profile_${_random.nextInt(1000)}.png',
      );
      await tempFile.writeAsString('Placeholder image content');
      await tempFile.copy(localPath);

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
