enum LogLevel { DEBUG, INFO, WARNING, ERROR, SUCCESS }

final Map<LogLevel, String> logLevelColors = {
  LogLevel.DEBUG: '\x1B[37m',
  LogLevel.INFO: '\x1B[34m',
  LogLevel.WARNING: '\x1B[33m',
  LogLevel.ERROR: '\x1B[31m',
  LogLevel.SUCCESS: '\x1B[32m',
};

const String resetColorCode = '\x1B[0m';
