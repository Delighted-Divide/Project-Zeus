import 'dart:io';
import 'package:intl/intl.dart';
import 'package:path_provider/path_provider.dart';
import '../models/log_level.dart';

class LoggingUtils {
  final bool _verbose;
  final StringBuffer _logBuffer = StringBuffer();
  int _logLines = 0;
  final DateFormat _dateFormatter = DateFormat('yyyy-MM-dd HH:mm:ss.SSS');

  static const int LOG_BUFFER_FLUSH_THRESHOLD = 50;
  static LoggingUtils? _instance;

  factory LoggingUtils({bool verbose = true}) {
    _instance ??= LoggingUtils._internal(verbose);
    return _instance!;
  }

  LoggingUtils._internal(this._verbose);

  void log(String message, {LogLevel level = LogLevel.DEBUG}) {
    if (level == LogLevel.DEBUG && !_verbose) return;

    final timestamp = _dateFormatter.format(DateTime.now());
    final levelStr = level.toString().split('.').last;
    final String formattedMessage = '$timestamp [$levelStr] $message';

    final String colorCode = logLevelColors[level] ?? '';
    print('$colorCode$formattedMessage$resetColorCode');

    _logBuffer.writeln(formattedMessage);
    _logLines++;

    if (_verbose && _logLines >= LOG_BUFFER_FLUSH_THRESHOLD) {
      saveLogsToFile();
      _logLines = 0;
    }
  }

  Future<void> saveLogsToFile() async {
    try {
      if (_logBuffer.isEmpty) return;

      final Directory appDocDir = await getApplicationDocumentsDirectory();
      final Directory logsDir = Directory('${appDocDir.path}/dummy_data_logs');

      if (!await logsDir.exists()) {
        await logsDir.create(recursive: true);
      }

      final String fileName =
          'dummy_data_gen_${DateFormat('yyyyMMdd_HHmmss').format(DateTime.now())}.log';
      final File logFile = File('${logsDir.path}/$fileName');

      await logFile.writeAsString(_logBuffer.toString(), mode: FileMode.append);
      _logBuffer.clear();

      print('Logs saved to ${logFile.path}');
    } catch (e) {
      print('Error saving logs: $e');
    }
  }

  void clearBuffer() {
    _logBuffer.clear();
    _logLines = 0;
  }
}
