import 'package:logging/logging.dart';
import 'package:talker_flutter/talker_flutter.dart';

class LogService {
  static final Talker _talker = TalkerFlutter.init(
    settings: TalkerSettings(
      maxHistoryItems: 100,
    ),
  );

  static Talker get talker => _talker;

  static void init() {
    Logger.root.level = Level.ALL;
    Logger.root.onRecord.listen((record) {
      _talker.log(
        record.message,
        logLevel: _mapLevel(record.level),
        exception: record.error,
        stackTrace: record.stackTrace,
      );
    });
  }

  static LogLevel _mapLevel(Level level) {
    if (level == Level.SHOUT) return LogLevel.critical;
    if (level == Level.SEVERE) return LogLevel.error;
    if (level == Level.WARNING) return LogLevel.warning;
    if (level == Level.INFO) return LogLevel.info;
    if (level == Level.FINE) return LogLevel.debug;
    return LogLevel.verbose;
  }

  /// Logs a structured message in format: SUBSYSTEM ACTION metadata
  static void log(
    String subsystem,
    String action, {
    Map<String, dynamic>? metadata,
    Level level = Level.INFO,
    Object? error,
    StackTrace? stackTrace,
  }) {
    final metaStr = metadata != null ? ' $metadata' : '';
    final message = '[$subsystem] [$action]$metaStr';

    _talker.log(
      message,
      logLevel: _mapLevel(level),
      exception: error,
      stackTrace: stackTrace,
    );
  }

  static void info(
    String subsystem,
    String action, [
    Map<String, dynamic>? meta,
  ]) => log(subsystem, action, metadata: meta);

  static void warning(
    String subsystem,
    String action, [
    Map<String, dynamic>? meta,
  ]) => log(subsystem, action, metadata: meta, level: Level.WARNING);

  static void error(
    String subsystem,
    String action,
    Object error, [
    StackTrace? stack,
  ]) => log(
    subsystem,
    action,
    level: Level.SEVERE,
    error: error,
    stackTrace: stack,
  );
}
