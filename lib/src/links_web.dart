import 'package:web/web.dart' as web;

Future<bool> openExternal(Uri uri) async {
  final opened = web.window.open(uri.toString(), '_blank');
  return opened != null;
}

/// Abre a aba na hora do clique e só depois aponta para o endereço.
/// O navegador bloqueia uma janela aberta depois da resposta da API.
Future<bool> openWhenReady(Future<Uri?> Function() load) async {
  web.Window? opened;
  try {
    opened = web.window.open('about:blank', '_blank');
  } catch (_) {
    opened = null;
  }
  final uri = await load();
  if (uri == null) {
    try {
      opened?.close();
    } catch (_) {}
    return false;
  }
  try {
    if (opened == null) {
      web.window.location.href = uri.toString();
    } else {
      opened.location.href = uri.toString();
    }
    return true;
  } catch (_) {
    return openExternal(uri);
  }
}
