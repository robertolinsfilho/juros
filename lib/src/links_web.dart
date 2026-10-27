import 'package:web/web.dart' as web;

Future<bool> openExternal(Uri uri) async {
  final opened = web.window.open(uri.toString(), '_blank');
  return opened != null;
}
