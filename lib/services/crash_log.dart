import 'dart:io';
import 'package:flutter/material.dart';

/// Minimal on-device crash logger.
///
/// Writes Dart-level crash reports to a file inside the app's cache
/// directory so they survive an app restart (until the cache is cleared).
/// The next successful launch surfaces the last report via
/// [CrashLog.showRecoveryDialogIfNeeded], which turns a "the app won't
/// open" report into a screen with the stack trace the user can read.
class CrashLog {
  CrashLog._();

  static const String _fileName = 'private_agent_crash.txt';
  static const String _nativeFileName = 'private_agent_native_crash.txt';
  static const int _maxEntries = 3;
  static final List<String> _pending = [];

  static File _file() =>
      File('${Directory.systemTemp.path}${Platform.pathSeparator}$_fileName');

  static File _nativeFile() =>
      File('${Directory.systemTemp.path}${Platform.pathSeparator}$_nativeFileName');

  static void record(Object error, StackTrace? stack, String tag) {
    final now = DateTime.now().toIso8601String();
    final entry = StringBuffer()
      ..writeln('[$now] [$tag]')
      ..writeln('$error');
    final st = stack?.toString() ?? '';
    if (st.isNotEmpty) {
      // Trim to the most meaningful frames to keep the file readable.
      final lines = st.split('\n').where((l) => l.trim().isNotEmpty);
      var kept = 0;
      for (final l in lines) {
        if (kept >= 20) break;
        entry.writeln(l);
        kept++;
      }
    }
    entry.writeln('---');
    _pending.add(entry.toString());
    try {
      final file = _file();
      final previous = file.existsSync() ? file.readAsStringSync() : '';
      final blob = previous + (previous.isEmpty ? '' : '\n') + entry.toString();
      final lines = blob.split('\n');
      final trimmed = lines.length > _maxEntries * 25
          ? lines.sublist(lines.length - _maxEntries * 25)
          : lines;
      file.createSync(recursive: true);
      file.writeAsStringSync(trimmed.join('\n'));
    } catch (_) {
      // Logging must never crash the app under test.
    }
  }

  static String? peekRecent() {
    try {
      final parts = <String>[];
      for (final f in [_file(), _nativeFile()]) {
        if (f.existsSync()) {
          final text = f.readAsStringSync().trim();
          if (text.isNotEmpty) parts.add(text);
        }
      }
      return parts.isEmpty ? null : parts.join('\n');
    } catch (_) {
      return null;
    }
  }

  /// Records that the Flutter UI actually reached its first frame. The native
  /// side uses this to detect "the app died before rendering" (engine-abort)
  /// cases that generate no Java exception to write.
  static void markBootOk() {
    try {
      final f = File(
        '${Directory.systemTemp.path}${Platform.pathSeparator}boot_ok.txt',
      );
      f.createSync(recursive: true);
      f.writeAsStringSync(DateTime.now().toIso8601String());
    } catch (_) {}
  }

  /// Shows a dialog with the last recorded crash, if any. Called once after
  /// the first frame so the user can screenshot the stack trace instead of
  /// (or in addition to) the "app keeps stopping" system dialog.
  static void showRecoveryDialogIfNeeded(BuildContext context) {
    final report = peekRecent();
    if (report == null) return;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!context.mounted) return;
      showDialog<void>(
        context: context,
        barrierDismissible: false,
        builder: (dialogContext) => AlertDialog(
          title: const Text('Registro de error del arranque'),
          content: SingleChildScrollView(
            child: SelectableText(
              report,
              style: const TextStyle(fontFamily: 'monospace', fontSize: 12),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () {
                CrashLog.clear();
                Navigator.of(dialogContext).pop();
              },
              child: const Text('Borrar y continuar'),
            ),
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(),
              child: const Text('Cerrar'),
            ),
          ],
        ),
      );
    });
  }

  static void clear() {
    try {
      for (final f in [_file(), _nativeFile()]) {
        if (f.existsSync()) f.deleteSync();
      }
    } catch (_) {}
    _pending.clear();
  }
}