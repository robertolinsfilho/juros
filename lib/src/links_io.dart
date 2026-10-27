import 'dart:io';

Future<bool> openExternal(Uri uri) async {
  try {
    if (Platform.isWindows) {
      final result = await Process.run('cmd', ['/c', 'start', '', uri.toString()]);
      return result.exitCode == 0;
    }
    if (Platform.isLinux) {
      final result = await Process.run('xdg-open', [uri.toString()]);
      return result.exitCode == 0;
    }
    if (Platform.isMacOS) {
      final result = await Process.run('open', [uri.toString()]);
      return result.exitCode == 0;
    }
  } catch (_) {
    return false;
  }
  return false;
}
