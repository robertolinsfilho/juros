import '../data/repository.dart';
import '../domain/schedule.dart';
import '../format.dart';
import 'templates.dart';

String numberEmoji(int number) {
  if (number >= 1 && number <= 9) return '$number\uFE0F\u20E3';
  if (number == 10) return '🔟';
  return '$number.';
}

String progressBar(int paid, int total) {
  if (total <= 1) return '';
  final percent = (paid * 100 / total).round().clamp(0, 100);
  final filled = (percent / 10).round();
  return '${'▓' * filled}${'░' * (10 - filled)} $percent%';
}

({String period, String periodOf}) periodWords(Frequency frequency, int intervalDays) {
  return switch (frequency) {
    Frequency.diario => (period: 'dia', periodOf: 'do dia'),
    Frequency.semanal => (period: 'semana', periodOf: 'da semana'),
    Frequency.dezDias => (period: '10 dias', periodOf: 'de 10 dias'),
    Frequency.quinzenal => (period: 'quinzena', periodOf: 'da quinzena'),
    Frequency.mensal => (period: 'mês', periodOf: 'do mês'),
    Frequency.nDias => (period: '$intervalDays dias', periodOf: 'de $intervalDays dias'),
    Frequency.personalizado => (period: 'período', periodOf: 'do período'),
  };
}

String _days(int days) => days == 1 ? '1 dia' : '$days dias';

/// Monta o texto de cada tipo de mensagem a partir dos dados do contrato.
class MessageBuilder {
  MessageBuilder(this.repo) : config = MessageConfig(repo);

  final Repo repo;
  final MessageConfig config;

  String _render(String kind, Map<String, String> vars, LoanRecord? loan) {
    final all = {...vars, 'assinatura': config.signature(pixOverride: loan?.pixKey ?? '')};
    return renderTemplate(config.bodyFor(kind), all);
  }

  String _mark(int number, int count) => config.fraction ? '$number/$count' : numberEmoji(number);

  String _statusEmoji(InstallmentRecord item, DateTime today) {
    if (item.paidAt != null) return '✅';
    if (item.status == 'perdida') return '❌';
    if (parseIsoDate(item.dueDate).isBefore(today)) return '⚠️';
    return '⏳';
  }

  String _lines(List<InstallmentRecord> items, DateTime today) {
    final lines = <String>[];
    for (var index = 0; index < items.length; index++) {
      final item = items[index];
      final mark = _mark(index + 1, items.length);
      lines.add('$mark ${_statusEmoji(item, today)} ${fmtDateIso(item.dueDate)} · ${fmtMoney(item.faceCents)}');
    }
    return lines.join('\n');
  }

  List<InstallmentRecord> _interestRows(List<InstallmentRecord> items) {
    return [for (final item in items) if (item.principalCents == 0 && item.interestCents > 0) item];
  }

  String _percent(int bps) => (bps / 100).toStringAsFixed(2).replaceAll('.', ',');

  /// Mensagem de empréstimo recém-criado.
  String registered(int loanId, {DateTime? today}) {
    final now = dateOnly(today ?? DateTime.now());
    final loan = repo.loanById(loanId, now)!;
    final items = repo.installmentsOf(loanId);
    final base = {
      'contrato_id': '${loan.id}',
      'data_contrato': fmtDateIso(loan.contractDate),
      'cliente_nome': loan.clientName,
      'valor_principal': fmtMoney(loan.principalCents),
    };
    if (loan.contractMode == ContractMode.apenasJuros.code) {
      final rows = _interestRows(items);
      final words = periodWords(FrequencyLabel.parse(loan.frequency), loan.intervalDays);
      return _render('registrado_juros', {
        ...base,
        'juros_mensal': fmtMoney(rows.isEmpty ? 0 : rows.first.faceCents),
        'periodo': words.period,
        'periodo_do': words.periodOf,
        'valor_quitar': fmtMoney(loan.principalCents),
        'lista_parcelas': _lines(rows, now),
      }, loan);
    }
    final interest = items.fold<int>(0, (sum, item) => sum + item.interestCents);
    final total = items.fold<int>(0, (sum, item) => sum + item.faceCents);
    return _render('registrado', {
      ...base,
      'taxa_juros': _percent(loan.rateBps),
      'total_juros': fmtMoney(interest),
      'total_pagar': fmtMoney(total),
      'primeiro_vencimento': items.isEmpty ? '' : fmtDateIso(items.first.dueDate),
      'lista_parcelas': _lines(items, now),
    }, loan);
  }

  /// Mensagem de cobrança de uma parcela. Escolhe o modelo pela situação.
  String charge(InstallmentRecord item, {DateTime? today}) {
    final now = dateOnly(today ?? DateTime.now());
    final loan = repo.loanById(item.loanId, now);
    final days = parseIsoDate(item.dueDate).difference(now).inDays;
    if (loan != null && days < 0) {
      final overdue = repo.overdueOfClient(loan.clientId, now);
      if (overdue.map((entry) => entry.loanId).toSet().length > 1) {
        return consolidated(overdue, now);
      }
    }
    final items = repo.installmentsOf(item.loanId);
    final open = [for (final entry in items) if (entry.isOpen) entry];
    final late = item.liveLateCents(now);
    final others = [
      for (final entry in open)
        if (entry.id != item.id && parseIsoDate(entry.dueDate).isBefore(now)) entry,
    ];
    final othersTotal = others.fold<int>(0, (sum, entry) => sum + entry.faceCents + entry.liveLateCents(now));
    final balance = open.fold<int>(0, (sum, entry) => sum + entry.faceCents);
    final payoff = balance + open.fold<int>(0, (sum, entry) => sum + entry.liveLateCents(now));
    final paid = items.where((entry) => entry.paidAt != null).length;
    String overdueLine(InstallmentRecord entry) {
      final delay = now.difference(parseIsoDate(entry.dueDate)).inDays;
      return '${fmtDateIso(entry.dueDate)} · ${fmtMoney(entry.faceCents + entry.liveLateCents(now))} (${_days(delay)})';
    }

    final lateBlock = others.isEmpty
        ? ''
        : '📌 *Outras parcelas em atraso (${others.length}):*\n'
              '${others.map((entry) => '• ${overdueLine(entry)}').join('\n')}\n\n'
              '🧾 Total em atraso: ${fmtMoney(othersTotal)}\n'
              '💰 Saldo devedor: ${fmtMoney(balance)}\n'
              '✅ Para quitar: ${fmtMoney(payoff)}\n';
    final interestOnly = loan?.contractMode == ContractMode.apenasJuros.code;
    final words = periodWords(
      FrequencyLabel.parse(loan?.frequency ?? 'mensal'),
      loan?.intervalDays ?? 0,
    );
    final vars = <String, String>{
      'cliente_nome': item.clientName,
      'parcela_valor': fmtMoney(item.faceCents),
      'valor_total': fmtMoney(item.faceCents + late),
      'parcela_numero': '${item.number}',
      'total_parcelas': '${item.count}',
      'parcela_vencimento': fmtDateIso(item.dueDate),
      'progresso_bar': progressBar(paid, items.length),
      'bloco_atrasos': lateBlock,
      'parcelas_atrasadas_lista': others.isEmpty ? '' : '${others.map((entry) => '⚠️ ${overdueLine(entry)}').join('\n')}\n',
      'qtd_atrasadas': '${others.length}',
      'total_atrasado': fmtMoney(othersTotal),
      'saldo_devedor': fmtMoney(balance),
      'total_quitacao': fmtMoney(payoff),
      'dias_atraso': '${days < 0 ? -days : 0}',
      'mora_valor': fmtMoney(late),
      'mora_texto': late > 0 ? '💸 Mora: ${fmtMoney(late)}' : '',
      'total_com_mora': fmtMoney(item.faceCents + late),
      'periodo': words.period,
      'periodo_do': words.periodOf,
      'capital_aberto': fmtMoney(open.fold<int>(0, (sum, entry) => sum + entry.principalCents)),
      'total_juros_aberto': fmtMoney(open.fold<int>(0, (sum, entry) => sum + entry.interestCents)),
    };
    final kind = interestOnly
        ? 'aberto'
        : days > 0
        ? 'pre_vencimento'
        : days == 0
        ? 'vencimento_hoje'
        : 'atrasado';
    return _render(kind, vars, loan);
  }

  /// Cobrança de todas as parcelas vencidas de um cliente com mais de um contrato.
  String consolidated(List<InstallmentRecord> overdue, DateTime today) {
    final loanIds = <int>[];
    for (final entry in overdue) {
      if (!loanIds.contains(entry.loanId)) loanIds.add(entry.loanId);
    }
    final buffer = <String>[];
    var face = 0;
    var lateTotal = 0;
    for (final id in loanIds) {
      buffer.add('📋 *Contrato nº $id*');
      for (final entry in overdue.where((candidate) => candidate.loanId == id)) {
        final late = entry.liveLateCents(today);
        final delay = today.difference(parseIsoDate(entry.dueDate)).inDays;
        face += entry.faceCents;
        lateTotal += late;
        buffer.add('• ${fmtDateIso(entry.dueDate)} · ${fmtMoney(entry.faceCents + late)} (${_days(delay)})');
      }
    }
    final loan = repo.loanById(overdue.first.loanId, today);
    return _render('consolidada', {
      'cliente_nome': overdue.first.clientName,
      'qtd_atrasadas': '${overdue.length}',
      'qtd_contratos': '${loanIds.length}',
      'lista_contratos_atraso': buffer.join('\n'),
      'total_atrasado': fmtMoney(face),
      'mora_texto': lateTotal > 0 ? '💸 Mora: ${fmtMoney(lateTotal)}' : '',
      'total_regularizar': fmtMoney(face + lateTotal),
    }, loan);
  }

  /// Resumo da situação do contrato.
  String status(int loanId, {DateTime? today}) {
    final now = dateOnly(today ?? DateTime.now());
    final loan = repo.loanById(loanId, now)!;
    final items = repo.installmentsOf(loanId);
    final paid = items.where((entry) => entry.paidAt != null).length;
    final next = items.where((entry) => entry.isOpen).toList();
    final situation = switch (loan.displayStatus) {
      'Atrasado' => '⚠️ Situação: em atraso',
      'Quitado' => '✅ Situação: quitado',
      'Perdido' => '❌ Situação: encerrado',
      _ => '✅ Situação: em dia',
    };
    final bar = progressBar(paid, items.length);
    return _render('situacao', {
      'cliente_nome': loan.clientName,
      'bloco_status': '📋 Contrato nº ${loan.id}\n💵 Emprestado: ${fmtMoney(loan.principalCents)}\n$situation',
      'bloco_progresso': bar.isEmpty ? '' : '$bar ($paid de ${items.length} pagas)',
      'bloco_proximo': next.isEmpty
          ? ''
          : '📅 Próximo vencimento: ${fmtDateIso(next.first.dueDate)} · ${fmtMoney(next.first.faceCents)}',
      'lista_parcelas_status': _lines(items, now),
    }, loan);
  }

  /// Confirmação enviada depois de registrar um recebimento.
  String payment(InstallmentRecord original, {DateTime? today}) {
    final now = dateOnly(today ?? DateTime.now());
    final loan = repo.loanById(original.loanId, now);
    final items = repo.installmentsOf(original.loanId);
    final paidItem = items.firstWhere((entry) => entry.id == original.id, orElse: () => original);
    final paidCount = items.where((entry) => entry.paidAt != null).length;
    final open = [for (final entry in items) if (entry.isOpen) entry];
    final balance = open.fold<int>(0, (sum, entry) => sum + entry.faceCents);
    final payoff = balance + open.fold<int>(0, (sum, entry) => sum + entry.liveLateCents(now));
    final bar = progressBar(paidCount, items.length);
    final received = paidItem.faceCents + paidItem.lateCents;
    return _render('pagamento', {
      'cliente_nome': paidItem.clientName,
      'contrato_id': '${paidItem.loanId}',
      'valor_emprestimo': fmtMoney(loan?.principalCents ?? 0),
      'data_pagamento': fmtDateIso(paidItem.paidAt ?? isoDate(now)),
      'bloco_parcela': '💵 Parcela ${paidItem.number} de ${paidItem.count}: ${fmtMoney(received)}',
      'bloco_progresso': bar.isEmpty ? '' : '$bar\n\n',
      'lista_parcelas_status': _lines(items, now),
      'proximo_vencimento': open.isEmpty ? '—' : fmtDateIso(open.first.dueDate),
      'bloco_saldo': open.isEmpty ? '' : '💰 Saldo devedor: ${fmtMoney(balance)}\n',
      'bloco_saldo_quitacao': open.isEmpty
          ? '🎉 Contrato quitado!\n\n'
          : '💰 Saldo devedor: ${fmtMoney(balance)}\n✅ Para quitar: ${fmtMoney(payoff)}\n\n',
    }, loan);
  }
}
