import 'data/repository.dart';
import 'format.dart';
import 'notify.dart';

String noticeLine(InstallmentRecord item, DateTime today, {required bool overdue}) {
  final money = fmtMoney(item.dueCents(today));
  if (!overdue) return '${item.clientName} · $money · vence ${fmtDateIso(item.dueDate)}';
  final days = dateOnly(today).difference(parseIsoDate(item.dueDate)).inDays;
  final late = days == 1 ? '1 dia de atraso' : '$days dias de atraso';
  return '${item.clientName} · $money · $late';
}

/// Mostra o aviso do sistema quando a permissão já existe, ou quando a pessoa pede.
/// O mesmo aviso vale no site aberto e no site instalado pelo navegador.
Future<bool> deliverPaymentNotices(Repo repo, {required bool ask, DateTime? now}) async {
  final today = now ?? DateTime.now();
  final alerts = repo.paymentAlerts(today);
  if (alerts.unpaid.isEmpty && alerts.upcoming.isEmpty) return false;
  final signature = [
    for (final item in alerts.unpaid) 'a${item.id}',
    for (final item in alerts.upcoming) 'v${item.id}',
  ].join(',');
  if (!ask && repo.noticeShown(signature, today)) return false;
  final shown = await publishPaymentNotices(
    unpaid: [for (final item in alerts.unpaid) noticeLine(item, today, overdue: true)],
    upcoming: [for (final item in alerts.upcoming) noticeLine(item, today, overdue: false)],
    ask: ask,
  );
  if (shown) repo.markNoticeShown(signature, today);
  return shown;
}
