/// Enum defining log levels for the application
enum LogLevel { DEBUG, INFO, WARNING, ERROR, SUCCESS }

/// Map of log levels to their corresponding color codes for console output
final Map<LogLevel, String> logLevelColors = {
  LogLevel.DEBUG: '\x1B[37m', // White
  LogLevel.INFO: '\x1B[34m', // Blue
  LogLevel.WARNING: '\x1B[33m', // Yellow
  LogLevel.ERROR: '\x1B[31m', // Red
  LogLevel.SUCCESS: '\x1B[32m', // Green
};

/// Reset color code to return console to default color
const String resetColorCode = '\x1B[0m';
