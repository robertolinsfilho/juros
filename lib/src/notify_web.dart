import 'dart:async';
import 'dart:js_interop';

import 'package:web/web.dart';

Future<bool> publishPaymentNotices({
  required List<String> unpaid,
  required List<String> upcoming,
  required bool ask,
}) async {
  if (unpaid.isEmpty && upcoming.isEmpty) return false;
  var permission = Notification.permission;
  if (permission == 'default') {
    if (!ask) return false;
    permission = (await Notification.requestPermission().toDart).toDart;
  }
  if (permission != 'granted') return false;
  final registration = await _registration();
  await _show(registration, 'Tem gente que não pagou', unpaid, 'acerta-atraso');
  await _show(registration, 'Tem cobrança chegando', upcoming, 'acerta-vence');
  return true;
}

Future<String> noticePermission() async => Notification.permission;

Future<ServiceWorkerRegistration?> _registration() async {
  try {
    final registration = await window.navigator.serviceWorker
        .register('notify-sw.js'.toJS, RegistrationOptions(scope: 'avisos/'))
        .toDart;
    final pending = registration.installing ?? registration.waiting;
    if (pending != null && pending.state != 'activated') {
      final done = Completer<void>();
      pending.onstatechange = ((Event _) {
        if (pending.state == 'activated' || pending.state == 'redundant') {
          if (!done.isCompleted) done.complete();
        }
      }).toJS;
      await done.future.timeout(const Duration(seconds: 4), onTimeout: () {});
    }
    return registration;
  } catch (_) {
    return null;
  }
}

Future<void> _show(
  ServiceWorkerRegistration? registration,
  String title,
  List<String> lines,
  String tag,
) async {
  if (lines.isEmpty) return;
  final extra = lines.length > 4 ? '\ne mais ${lines.length - 4}' : '';
  final options = NotificationOptions(
    body: '${lines.take(4).join('\n')}$extra',
    tag: tag,
    renotify: true,
    lang: 'pt-BR',
    icon: 'icons/Icon-192.png',
  );
  if (registration != null) {
    try {
      await registration.showNotification(title, options).toDart;
      return;
    } catch (_) {}
  }
  Notification(title, options);
}
