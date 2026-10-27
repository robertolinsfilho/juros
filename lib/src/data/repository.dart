import 'package:sqlite3/common.dart';

import '../domain/schedule.dart';
import '../format.dart';

class ClientRecord {
  const ClientRecord({
    required this.id,
    required this.name,
    required this.document,
    required this.phone,
    required this.zip,
    required this.address,
    required this.workAddress,
    required this.overdueCount,
    required this.dueToday,
    required this.deletedAt,
  });

  final int id;
  final String name;
  final String document;
  final String phone;
  final String zip;
  final String address;
  final String workAddress;
  final int overdueCount;
  final int dueToday;
  final String? deletedAt;

  String get statusLabel {
    if (overdueCount > 0) return 'Atrasado';
    if (dueToday > 0) return 'Vence hoje';
    return 'Em dia';
  }
}

class LoanRecord {
  const LoanRecord({
    required this.id,
    required this.clientId,
    required this.clientName,
    required this.clientPhone,
    required this.principalCents,
    required this.rateBps,
    required this.rateMode,
    required this.contractMode,
    required this.frequency,
    required this.intervalDays,
    required this.count,
    required this.contractDate,
    required this.lateMode,
    required this.latePercentBps,
    required this.lateDailyCents,
    required this.lateFixedCents,
    required this.notes,
    required this.status,
    required this.overdueCount,
    required this.nextDue,
    required this.openCents,
    required this.deletedAt,
  });

  final int id;
  final int clientId;
  final String clientName;
  final String clientPhone;
  final int principalCents;
  final int rateBps;
  final String rateMode;
  final String contractMode;
  final String frequency;
  final int intervalDays;
  final int count;
  final String contractDate;
  final String lateMode;
  final int latePercentBps;
  final int lateDailyCents;
  final int lateFixedCents;
  final String notes;
  final String status;
  final int overdueCount;
  final String? nextDue;
  final int openCents;
  final String? deletedAt;

  String get displayStatus {
    if (status == 'perdido') return 'Perdido';
    if (status == 'quitado') return 'Quitado';
    if (overdueCount > 0) return 'Atrasado';
    return 'Aberto';
  }

  String get typeLabel {
    final mode = ContractModeLabel.parse(contractMode).label;
    final freq = FrequencyLabel.parse(frequency).label;
    return '$mode · $freq';
  }
}

class InstallmentRecord {
  const InstallmentRecord({
    required this.id,
    required this.loanId,
    required this.number,
    required this.count,
    required this.dueDate,
    required this.principalCents,
    required this.interestCents,
    required this.lateCents,
    required this.paidAt,
    required this.status,
    required this.clientName,
    required this.clientPhone,
    required this.lateMode,
    required this.latePercentBps,
    required this.lateDailyCents,
    required this.lateFixedCents,
  });

  final int id;
  final int loanId;
  final int number;
  final int count;
  final String dueDate;
  final int principalCents;
  final int interestCents;
  final int lateCents;
  final String? paidAt;
  final String status;
  final String clientName;
  final String clientPhone;
  final String lateMode;
  final int latePercentBps;
  final int lateDailyCents;
  final int lateFixedCents;

  int get faceCents => principalCents + interestCents;

  bool get isOpen => paidAt == null && status == 'aberta';

  int liveLateCents(DateTime today) {
    if (!isOpen) return lateCents;
    final days = dateOnly(today).difference(parseIsoDate(dueDate)).inDays;
    return lateFeeCents(
      baseCents: faceCents,
      days: days,
      mode: lateMode,
      percentBps: latePercentBps,
      dailyCents: lateDailyCents,
      fixedCents: lateFixedCents,
    );
  }

  int dueCents(DateTime today) => faceCents + liveLateCents(today);
}

class DashboardData {
  const DashboardData({
    required this.expectedCents,
    required this.overdueCents,
    required this.receivedMonthCents,
    required this.clientCount,
    required this.capitalCents,
    required this.profitMonthCents,
    required this.openLoans,
    required this.lateLoans,
    required this.settledLoans,
    required this.lostLoans,
    required this.overdueInstallments,
    required this.dueInstallments,
    required this.today,
    required this.nextDays,
    required this.weeks,
  });

  final int expectedCents;
  final int overdueCents;
  final int receivedMonthCents;
  final int clientCount;
  final int capitalCents;
  final int profitMonthCents;
  final int openLoans;
  final int lateLoans;
  final int settledLoans;
  final int lostLoans;
  final int overdueInstallments;
  final int dueInstallments;
  final List<InstallmentRecord> today;
  final List<InstallmentRecord> nextDays;
  final List<WeekBucket> weeks;

  double get delinquency {
    if (dueInstallments == 0) return 0;
    return overdueInstallments / dueInstallments;
  }
}

class WeekBucket {
  const WeekBucket(this.label, this.expectedCents, this.receivedCents);
  final String label;
  final int expectedCents;
  final int receivedCents;
}

class CashState {
  const CashState({
    required this.enabled,
    required this.balanceCents,
    required this.alertCents,
    required this.entries,
  });

  final bool enabled;
  final int balanceCents;
  final int alertCents;
  final List<CashEntry> entries;

  bool get low => enabled && balanceCents < alertCents;
}

class CashEntry {
  const CashEntry({
    required this.id,
    required this.kind,
    required this.amountCents,
    required this.note,
    required this.createdAt,
  });

  final int id;
  final String kind;
  final int amountCents;
  final String note;
  final String createdAt;
}

class ReportData {
  const ReportData({
    required this.lentCents,
    required this.profitCents,
    required this.overdueCents,
    required this.delinquency,
    required this.interestCents,
    required this.lateCents,
    required this.receivedCents,
    required this.capitalBackCents,
    required this.openCapitalCents,
    required this.interestOnlyCents,
    required this.amortizedCents,
  });

  final int lentCents;
  final int profitCents;
  final int overdueCents;
  final double delinquency;
  final int interestCents;
  final int lateCents;
  final int receivedCents;
  final int capitalBackCents;
  final int openCapitalCents;
  final int interestOnlyCents;
  final int amortizedCents;
}

class Repo {
  Repo(this.db, this.dbPath) {
    _ensure();
  }

  final CommonDatabase db;
  final String dbPath;

  void close() => db.close();

  void _ensure() {
    db.execute('PRAGMA foreign_keys = ON');
    try {
      db.execute('PRAGMA journal_mode = WAL');
      db.execute('PRAGMA synchronous = NORMAL');
    } catch (_) {
      db.execute('PRAGMA journal_mode = DELETE');
    }
    db.execute('''
      CREATE TABLE IF NOT EXISTS clients (
        id INTEGER PRIMARY KEY,
        name TEXT NOT NULL,
        document TEXT NOT NULL DEFAULT '',
        phone TEXT NOT NULL,
        zip TEXT NOT NULL DEFAULT '',
        address TEXT NOT NULL DEFAULT '',
        work_address TEXT NOT NULL DEFAULT '',
        created_at TEXT NOT NULL,
        deleted_at TEXT
      )
    ''');
    db.execute('''
      CREATE TABLE IF NOT EXISTS loans (
        id INTEGER PRIMARY KEY,
        client_id INTEGER NOT NULL REFERENCES clients(id),
        principal_cents INTEGER NOT NULL,
        rate_bps INTEGER NOT NULL,
        rate_mode TEXT NOT NULL,
        contract_mode TEXT NOT NULL,
        frequency TEXT NOT NULL,
        interval_days INTEGER NOT NULL DEFAULT 0,
        installment_count INTEGER NOT NULL,
        contract_date TEXT NOT NULL,
        skip_saturday INTEGER NOT NULL,
        skip_sunday INTEGER NOT NULL,
        skip_holiday INTEGER NOT NULL,
        late_mode TEXT NOT NULL,
        late_percent_bps INTEGER NOT NULL DEFAULT 0,
        late_daily_cents INTEGER NOT NULL DEFAULT 0,
        late_fixed_cents INTEGER NOT NULL DEFAULT 0,
        notes TEXT NOT NULL DEFAULT '',
        status TEXT NOT NULL,
        created_at TEXT NOT NULL,
        deleted_at TEXT
      )
    ''');
    db.execute('''
      CREATE TABLE IF NOT EXISTS installments (
        id INTEGER PRIMARY KEY,
        loan_id INTEGER NOT NULL REFERENCES loans(id),
        number INTEGER NOT NULL,
        due_date TEXT NOT NULL,
        principal_cents INTEGER NOT NULL,
        interest_cents INTEGER NOT NULL,
        late_cents INTEGER NOT NULL DEFAULT 0,
        paid_at TEXT,
        status TEXT NOT NULL
      )
    ''');
    db.execute('''
      CREATE TABLE IF NOT EXISTS cash_entries (
        id INTEGER PRIMARY KEY,
        kind TEXT NOT NULL,
        amount_cents INTEGER NOT NULL,
        note TEXT NOT NULL DEFAULT '',
        created_at TEXT NOT NULL
      )
    ''');
    db.execute('''
      CREATE TABLE IF NOT EXISTS settings (
        key TEXT PRIMARY KEY,
        value TEXT NOT NULL
      )
    ''');
    db.execute(
      'CREATE INDEX IF NOT EXISTS idx_installments_loan ON installments(loan_id)',
    );
    db.execute(
      'CREATE INDEX IF NOT EXISTS idx_installments_due ON installments(due_date)',
    );
    db.execute(
      'CREATE INDEX IF NOT EXISTS idx_loans_client ON loans(client_id)',
    );
  }

  void purgeExpired([DateTime? now]) {
    final cutoff = (now ?? DateTime.now())
        .subtract(const Duration(days: 30))
        .toIso8601String();
    db.execute('BEGIN');
    try {
      db.execute(
        '''
        DELETE FROM installments
        WHERE loan_id IN (SELECT id FROM loans WHERE deleted_at IS NOT NULL AND deleted_at < ?)
        ''',
        [cutoff],
      );
      db.execute(
        'DELETE FROM loans WHERE deleted_at IS NOT NULL AND deleted_at < ?',
        [cutoff],
      );
      db.execute(
        '''
        DELETE FROM clients
        WHERE deleted_at IS NOT NULL AND deleted_at < ?
          AND id NOT IN (SELECT client_id FROM loans)
        ''',
        [cutoff],
      );
      db.execute('COMMIT');
    } catch (_) {
      db.execute('ROLLBACK');
      rethrow;
    }
  }

  String setting(String key, [String fallback = '']) {
    final rows = db.select('SELECT value FROM settings WHERE key = ?', [key]);
    if (rows.isEmpty) return fallback;
    return rows.first['value'] as String;
  }

  void removeSetting(String key) {
    db.execute('DELETE FROM settings WHERE key = ?', [key]);
  }

  void setSetting(String key, String value) {
    db.execute(
      '''
      INSERT INTO settings(key, value) VALUES(?, ?)
      ON CONFLICT(key) DO UPDATE SET value = excluded.value
      ''',
      [key, value],
    );
  }

  double get fontScale => double.tryParse(setting('font_scale', '1')) ?? 1;

  List<ClientRecord> listClients({
    String query = '',
    bool deleted = false,
    DateTime? today,
  }) {
    final day = isoDate(today ?? DateTime.now());
    final needle = '%${query.trim()}%';
    final rows = db.select(
      '''
      SELECT c.*,
        (SELECT COUNT(*) FROM installments i
          JOIN loans l ON l.id = i.loan_id
          WHERE l.client_id = c.id AND l.deleted_at IS NULL AND l.status = 'aberto'
            AND i.paid_at IS NULL AND i.status = 'aberta' AND i.due_date < ?) AS overdue_count,
        (SELECT COUNT(*) FROM installments i
          JOIN loans l ON l.id = i.loan_id
          WHERE l.client_id = c.id AND l.deleted_at IS NULL AND l.status = 'aberto'
            AND i.paid_at IS NULL AND i.status = 'aberta' AND i.due_date = ?) AS due_today
      FROM clients c
      WHERE ${deleted ? 'c.deleted_at IS NOT NULL' : 'c.deleted_at IS NULL'}
        AND (? = '%%' OR c.name LIKE ? OR c.document LIKE ? OR c.phone LIKE ?)
      ORDER BY c.name COLLATE NOCASE
      ''',
      [day, day, needle, needle, needle, needle],
    );
    return [for (final row in rows) _client(row)];
  }

  int saveClient({
    int? id,
    required String name,
    required String document,
    required String phone,
    required String zip,
    required String address,
    required String workAddress,
  }) {
    if (id == null) {
      db.execute(
        '''
        INSERT INTO clients(name, document, phone, zip, address, work_address, created_at)
        VALUES(?, ?, ?, ?, ?, ?, ?)
        ''',
        [
          name.trim(),
          document.trim(),
          digitsOnly(phone),
          digitsOnly(zip),
          address.trim(),
          workAddress.trim(),
          DateTime.now().toIso8601String(),
        ],
      );
      return db.lastInsertRowId;
    }
    db.execute(
      '''
      UPDATE clients
      SET name = ?, document = ?, phone = ?, zip = ?, address = ?, work_address = ?
      WHERE id = ?
      ''',
      [
        name.trim(),
        document.trim(),
        digitsOnly(phone),
        digitsOnly(zip),
        address.trim(),
        workAddress.trim(),
        id,
      ],
    );
    return id;
  }

  String? deleteClient(int id) {
    final open = _int(
      '''
      SELECT COUNT(*) AS c FROM loans
      WHERE client_id = ? AND deleted_at IS NULL AND status = 'aberto'
      ''',
      [id],
    );
    if (open > 0) {
      return 'Este cliente ainda tem empréstimo em aberto.';
    }
    db.execute(
      'UPDATE clients SET deleted_at = ? WHERE id = ?',
      [DateTime.now().toIso8601String(), id],
    );
    return null;
  }

  void restoreClient(int id) {
    db.execute('UPDATE clients SET deleted_at = NULL WHERE id = ?', [id]);
  }

  List<LoanRecord> listLoans({
    String query = '',
    String status = 'todos',
    String type = 'todos',
    String? from,
    String? to,
    bool deleted = false,
    DateTime? today,
  }) {
    final day = isoDate(today ?? DateTime.now());
    final rows = db.select(
      '''
      SELECT l.*, c.name AS client_name, c.phone AS client_phone,
        (SELECT COUNT(*) FROM installments i
          WHERE i.loan_id = l.id AND i.paid_at IS NULL AND i.status = 'aberta' AND i.due_date < ?) AS overdue_count,
        (SELECT MIN(due_date) FROM installments i
          WHERE i.loan_id = l.id AND i.paid_at IS NULL AND i.status = 'aberta') AS next_due,
        (SELECT COALESCE(SUM(principal_cents + interest_cents), 0) FROM installments i
          WHERE i.loan_id = l.id AND i.paid_at IS NULL AND i.status = 'aberta') AS open_cents
      FROM loans l
      JOIN clients c ON c.id = l.client_id
      WHERE ${deleted ? 'l.deleted_at IS NOT NULL' : 'l.deleted_at IS NULL'}
      ORDER BY l.contract_date DESC, l.id DESC
      ''',
      [day],
    );
    final needle = query.trim().toLowerCase();
    return [
      for (final row in rows)
        if (_loanVisible(row, needle, status, type, from, to)) _loan(row),
    ];
  }

  LoanRecord? loanById(int id, [DateTime? today]) {
    final day = isoDate(today ?? DateTime.now());
    final rows = db.select(
      '''
      SELECT l.*, c.name AS client_name, c.phone AS client_phone,
        (SELECT COUNT(*) FROM installments i
          WHERE i.loan_id = l.id AND i.paid_at IS NULL AND i.status = 'aberta' AND i.due_date < ?) AS overdue_count,
        (SELECT MIN(due_date) FROM installments i
          WHERE i.loan_id = l.id AND i.paid_at IS NULL AND i.status = 'aberta') AS next_due,
        (SELECT COALESCE(SUM(principal_cents + interest_cents), 0) FROM installments i
          WHERE i.loan_id = l.id AND i.paid_at IS NULL AND i.status = 'aberta') AS open_cents
      FROM loans l
      JOIN clients c ON c.id = l.client_id
      WHERE l.id = ?
      ''',
      [day, id],
    );
    if (rows.isEmpty) return null;
    return _loan(rows.first);
  }

  List<InstallmentRecord> installmentsOf(int loanId) {
    final rows = db.select(
      '''
      SELECT i.*, l.installment_count AS count, l.late_mode, l.late_percent_bps,
             l.late_daily_cents, l.late_fixed_cents, c.name AS client_name, c.phone AS client_phone
      FROM installments i
      JOIN loans l ON l.id = i.loan_id
      JOIN clients c ON c.id = l.client_id
      WHERE i.loan_id = ?
      ORDER BY i.number
      ''',
      [loanId],
    );
    return [for (final row in rows) _installment(row)];
  }

  int createLoan(LoanDraft draft) {
    final plan = buildSchedule(draft);
    final now = DateTime.now().toIso8601String();
    db.execute('BEGIN');
    try {
      db.execute(
        '''
        INSERT INTO loans(
          client_id, principal_cents, rate_bps, rate_mode, contract_mode, frequency,
          interval_days, installment_count, contract_date, skip_saturday, skip_sunday,
          skip_holiday, late_mode, late_percent_bps, late_daily_cents, late_fixed_cents,
          notes, status, created_at
        ) VALUES(?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, 'aberto', ?)
        ''',
        [
          draft.clientId,
          draft.principalCents,
          draft.rateBps,
          draft.rateMode.code,
          draft.contractMode.code,
          draft.frequency.code,
          draft.intervalDays,
          draft.count,
          isoDate(draft.contractDate),
          draft.skipSaturday ? 1 : 0,
          draft.skipSunday ? 1 : 0,
          draft.skipHoliday ? 1 : 0,
          draft.lateMode,
          draft.latePercentBps,
          draft.lateDailyCents,
          draft.lateFixedCents,
          draft.notes.trim(),
          now,
        ],
      );
      final id = db.lastInsertRowId;
      for (final item in plan) {
        db.execute(
          '''
          INSERT INTO installments(loan_id, number, due_date, principal_cents, interest_cents, status)
          VALUES(?, ?, ?, ?, ?, 'aberta')
          ''',
          [id, item.number, isoDate(item.due), item.principalCents, item.interestCents],
        );
      }
      db.execute('COMMIT');
      return id;
    } catch (_) {
      db.execute('ROLLBACK');
      rethrow;
    }
  }

  void payInstallment(int installmentId, [DateTime? now]) {
    final today = now ?? DateTime.now();
    final rows = db.select(
      '''
      SELECT i.*, l.status AS loan_status, l.late_mode, l.late_percent_bps,
             l.late_daily_cents, l.late_fixed_cents
      FROM installments i
      JOIN loans l ON l.id = i.loan_id
      WHERE i.id = ?
      ''',
      [installmentId],
    );
    if (rows.isEmpty) return;
    final row = rows.first;
    if (row['paid_at'] != null || row['status'] != 'aberta') return;
    final face = (row['principal_cents'] as int) + (row['interest_cents'] as int);
    final days = dateOnly(today).difference(parseIsoDate(row['due_date'] as String)).inDays;
    final late = lateFeeCents(
      baseCents: face,
      days: days,
      mode: row['late_mode'] as String,
      percentBps: row['late_percent_bps'] as int,
      dailyCents: row['late_daily_cents'] as int,
      fixedCents: row['late_fixed_cents'] as int,
    );
    final loanId = row['loan_id'] as int;
    db.execute('BEGIN');
    try {
      db.execute(
        '''
        UPDATE installments SET paid_at = ?, late_cents = ?, status = 'paga' WHERE id = ?
        ''',
        [isoDate(today), late, installmentId],
      );
      final open = _int(
        '''
        SELECT COUNT(*) AS c FROM installments
        WHERE loan_id = ? AND paid_at IS NULL AND status = 'aberta'
        ''',
        [loanId],
      );
      if (open == 0) {
        db.execute("UPDATE loans SET status = 'quitado' WHERE id = ?", [loanId]);
      }
      db.execute('COMMIT');
    } catch (_) {
      db.execute('ROLLBACK');
      rethrow;
    }
  }

  void markLost(int loanId) {
    db.execute('BEGIN');
    try {
      db.execute("UPDATE loans SET status = 'perdido' WHERE id = ?", [loanId]);
      db.execute(
        '''
        UPDATE installments SET status = 'perdida'
        WHERE loan_id = ? AND paid_at IS NULL
        ''',
        [loanId],
      );
      db.execute('COMMIT');
    } catch (_) {
      db.execute('ROLLBACK');
      rethrow;
    }
  }

  void deleteLoan(int loanId) {
    db.execute(
      'UPDATE loans SET deleted_at = ? WHERE id = ?',
      [DateTime.now().toIso8601String(), loanId],
    );
  }

  void restoreLoan(int loanId) {
    db.execute('UPDATE loans SET deleted_at = NULL WHERE id = ?', [loanId]);
  }

  DashboardData dashboard([DateTime? now]) {
    final today = dateOnly(now ?? DateTime.now());
    final day = isoDate(today);
    final monthStart = isoDate(DateTime(today.year, today.month, 1));
    final nextMonth = isoDate(DateTime(today.year, today.month + 1, 1));
    final totals = db.select(
      '''
      SELECT
        COALESCE(SUM(i.principal_cents + i.interest_cents), 0) AS expected,
        COALESCE(SUM(CASE WHEN i.due_date < ? THEN i.principal_cents + i.interest_cents ELSE 0 END), 0) AS overdue,
        COALESCE(SUM(i.principal_cents), 0) AS capital,
        COALESCE(SUM(CASE WHEN i.due_date >= ? AND i.due_date < ? THEN i.interest_cents ELSE 0 END), 0) AS profit
      FROM installments i
      JOIN loans l ON l.id = i.loan_id
      WHERE l.deleted_at IS NULL AND l.status = 'aberto'
        AND i.paid_at IS NULL AND i.status = 'aberta'
      ''',
      [day, monthStart, nextMonth],
    ).first;
    final received = _int(
      '''
      SELECT COALESCE(SUM(i.principal_cents + i.interest_cents + i.late_cents), 0) AS c
      FROM installments i
      JOIN loans l ON l.id = i.loan_id
      WHERE l.deleted_at IS NULL AND i.paid_at >= ? AND i.paid_at < ?
      ''',
      [monthStart, nextMonth],
    );
    final counts = db.select(
      '''
      SELECT
        SUM(CASE WHEN l.status = 'perdido' THEN 1 ELSE 0 END) AS perdido,
        SUM(CASE WHEN l.status = 'quitado' THEN 1 ELSE 0 END) AS quitado,
        SUM(CASE WHEN l.status = 'aberto' AND EXISTS (
          SELECT 1 FROM installments i
          WHERE i.loan_id = l.id AND i.paid_at IS NULL AND i.status = 'aberta' AND i.due_date < ?
        ) THEN 1 ELSE 0 END) AS atrasado,
        SUM(CASE WHEN l.status = 'aberto' AND NOT EXISTS (
          SELECT 1 FROM installments i
          WHERE i.loan_id = l.id AND i.paid_at IS NULL AND i.status = 'aberta' AND i.due_date < ?
        ) THEN 1 ELSE 0 END) AS aberto
      FROM loans l
      WHERE l.deleted_at IS NULL
      ''',
      [day, day],
    ).first;
    final dueCount = _int(
      '''
      SELECT COUNT(*) AS c FROM installments i
      JOIN loans l ON l.id = i.loan_id
      WHERE l.deleted_at IS NULL AND l.status != 'perdido' AND i.due_date <= ?
      ''',
      [day],
    );
    final lateCount = _int(
      '''
      SELECT COUNT(*) AS c FROM installments i
      JOIN loans l ON l.id = i.loan_id
      WHERE l.deleted_at IS NULL AND l.status = 'aberto'
        AND i.paid_at IS NULL AND i.status = 'aberta' AND i.due_date < ?
      ''',
      [day],
    );
    return DashboardData(
      expectedCents: totals['expected'] as int,
      overdueCents: totals['overdue'] as int,
      receivedMonthCents: received,
      clientCount: _int(
        'SELECT COUNT(*) AS c FROM clients WHERE deleted_at IS NULL',
      ),
      capitalCents: totals['capital'] as int,
      profitMonthCents: totals['profit'] as int,
      openLoans: (counts['aberto'] as int?) ?? 0,
      lateLoans: (counts['atrasado'] as int?) ?? 0,
      settledLoans: (counts['quitado'] as int?) ?? 0,
      lostLoans: (counts['perdido'] as int?) ?? 0,
      overdueInstallments: lateCount,
      dueInstallments: dueCount,
      today: _dueBetween(day, day),
      nextDays: _dueBetween(day, isoDate(today.add(const Duration(days: 6)))),
      weeks: _weeks(today),
    );
  }

  List<InstallmentRecord> dueOn(DateTime day) => _dueBetween(isoDate(day), isoDate(day));

  ({int expected, int received, int receivedToday, int lentToday}) monthPulse(DateTime day) {
    final start = isoDate(DateTime(day.year, day.month, 1));
    final end = isoDate(DateTime(day.year, day.month + 1, 1));
    final today = isoDate(day);
    final expected = _int(
      '''
      SELECT COALESCE(SUM(i.principal_cents + i.interest_cents), 0) AS c
      FROM installments i
      JOIN loans l ON l.id = i.loan_id
      WHERE l.deleted_at IS NULL AND l.status != 'perdido'
        AND i.due_date >= ? AND i.due_date < ?
      ''',
      [start, end],
    );
    final received = _int(
      '''
      SELECT COALESCE(SUM(i.principal_cents + i.interest_cents + i.late_cents), 0) AS c
      FROM installments i JOIN loans l ON l.id = i.loan_id
      WHERE l.deleted_at IS NULL AND i.paid_at >= ? AND i.paid_at < ?
      ''',
      [start, end],
    );
    final receivedToday = _int(
      '''
      SELECT COALESCE(SUM(i.principal_cents + i.interest_cents + i.late_cents), 0) AS c
      FROM installments i JOIN loans l ON l.id = i.loan_id
      WHERE l.deleted_at IS NULL AND i.paid_at = ?
      ''',
      [today],
    );
    final lentToday = _int(
      '''
      SELECT COALESCE(SUM(principal_cents), 0) AS c FROM loans
      WHERE deleted_at IS NULL AND contract_date = ?
      ''',
      [today],
    );
    return (
      expected: expected,
      received: received,
      receivedToday: receivedToday,
      lentToday: lentToday,
    );
  }

  Map<int, int> dueCountsInMonth(DateTime day) {
    final start = isoDate(DateTime(day.year, day.month, 1));
    final end = isoDate(DateTime(day.year, day.month + 1, 1));
    final rows = db.select(
      '''
      SELECT i.due_date AS due, COUNT(*) AS c
      FROM installments i
      JOIN loans l ON l.id = i.loan_id
      WHERE l.deleted_at IS NULL AND l.status = 'aberto'
        AND i.paid_at IS NULL AND i.status = 'aberta'
        AND i.due_date >= ? AND i.due_date < ?
      GROUP BY i.due_date
      ''',
      [start, end],
    );
    return {
      for (final row in rows) parseIsoDate(row['due'] as String).day: row['c'] as int,
    };
  }

  ReportData report(DateTime start, DateTime end) {
    final from = isoDate(start);
    final to = isoDate(end.add(const Duration(days: 1)));
    final today = isoDate(DateTime.now());
    final lent = _int(
      '''
      SELECT COALESCE(SUM(principal_cents), 0) AS c FROM loans
      WHERE deleted_at IS NULL AND contract_date >= ? AND contract_date < ?
      ''',
      [from, to],
    );
    final paid = db.select(
      '''
      SELECT
        COALESCE(SUM(i.interest_cents), 0) AS interest,
        COALESCE(SUM(i.late_cents), 0) AS late,
        COALESCE(SUM(i.principal_cents), 0) AS capital,
        COALESCE(SUM(CASE WHEN l.contract_mode = 'apenas_juros' THEN i.principal_cents + i.interest_cents + i.late_cents ELSE 0 END), 0) AS only_interest,
        COALESCE(SUM(CASE WHEN l.contract_mode = 'amortizacao' THEN i.principal_cents + i.interest_cents + i.late_cents ELSE 0 END), 0) AS amortized
      FROM installments i
      JOIN loans l ON l.id = i.loan_id
      WHERE l.deleted_at IS NULL AND i.paid_at >= ? AND i.paid_at < ?
      ''',
      [from, to],
    ).first;
    final overdue = _int(
      '''
      SELECT COALESCE(SUM(i.principal_cents + i.interest_cents), 0) AS c
      FROM installments i JOIN loans l ON l.id = i.loan_id
      WHERE l.deleted_at IS NULL AND l.status = 'aberto'
        AND i.paid_at IS NULL AND i.status = 'aberta' AND i.due_date < ?
      ''',
      [today],
    );
    final dueCount = _int(
      '''
      SELECT COUNT(*) AS c FROM installments i
      JOIN loans l ON l.id = i.loan_id
      WHERE l.deleted_at IS NULL AND l.status != 'perdido' AND i.due_date <= ?
      ''',
      [today],
    );
    final lateCount = _int(
      '''
      SELECT COUNT(*) AS c FROM installments i
      JOIN loans l ON l.id = i.loan_id
      WHERE l.deleted_at IS NULL AND l.status = 'aberto'
        AND i.paid_at IS NULL AND i.status = 'aberta' AND i.due_date < ?
      ''',
      [today],
    );
    final openCapital = _int(
      '''
      SELECT COALESCE(SUM(i.principal_cents), 0) AS c
      FROM installments i JOIN loans l ON l.id = i.loan_id
      WHERE l.deleted_at IS NULL AND l.status = 'aberto'
        AND i.paid_at IS NULL AND i.status = 'aberta'
      ''',
    );
    final interest = paid['interest'] as int;
    final late = paid['late'] as int;
    final capital = paid['capital'] as int;
    return ReportData(
      lentCents: lent,
      profitCents: interest + late,
      overdueCents: overdue,
      delinquency: dueCount == 0 ? 0 : lateCount / dueCount,
      interestCents: interest,
      lateCents: late,
      receivedCents: interest + late + capital,
      capitalBackCents: capital,
      openCapitalCents: openCapital,
      interestOnlyCents: paid['only_interest'] as int,
      amortizedCents: paid['amortized'] as int,
    );
  }

  CashState cash() {
    final enabled = setting('cash_enabled') == '1';
    final alert = int.tryParse(setting('cash_alert', '0')) ?? 0;
    final rows = db.select(
      'SELECT * FROM cash_entries ORDER BY created_at DESC, id DESC',
    );
    final entries = [
      for (final row in rows)
        CashEntry(
          id: row['id'] as int,
          kind: row['kind'] as String,
          amountCents: row['amount_cents'] as int,
          note: row['note'] as String,
          createdAt: row['created_at'] as String,
        ),
    ];
    var balance = 0;
    for (final entry in entries) {
      balance += entry.kind == 'saida' ? -entry.amountCents : entry.amountCents;
    }
    return CashState(
      enabled: enabled,
      balanceCents: balance,
      alertCents: alert,
      entries: entries,
    );
  }

  void enableCash({required int initialCents, required int alertCents}) {
    if (setting('cash_enabled') == '1') return;
    db.execute('BEGIN');
    try {
      db.execute(
        '''
        INSERT INTO cash_entries(kind, amount_cents, note, created_at)
        VALUES('saldo_inicial', ?, 'Saldo inicial', ?)
        ''',
        [initialCents, DateTime.now().toIso8601String()],
      );
      setSetting('cash_enabled', '1');
      setSetting('cash_alert', '$alertCents');
      db.execute('COMMIT');
    } catch (_) {
      db.execute('ROLLBACK');
      rethrow;
    }
  }

  void addCash({required bool outflow, required int amountCents, required String note}) {
    db.execute(
      '''
      INSERT INTO cash_entries(kind, amount_cents, note, created_at)
      VALUES(?, ?, ?, ?)
      ''',
      [
        outflow ? 'saida' : 'entrada',
        amountCents,
        note.trim(),
        DateTime.now().toIso8601String(),
      ],
    );
  }

  void resetCash() {
    db.execute('BEGIN');
    try {
      db.execute('DELETE FROM cash_entries');
      db.execute("DELETE FROM settings WHERE key IN ('cash_enabled', 'cash_alert')");
      db.execute('COMMIT');
    } catch (_) {
      db.execute('ROLLBACK');
      rethrow;
    }
  }

  List<InstallmentRecord> _dueBetween(String start, String end) {
    final rows = db.select(
      '''
      SELECT i.*, l.installment_count AS count, l.late_mode, l.late_percent_bps,
             l.late_daily_cents, l.late_fixed_cents, c.name AS client_name, c.phone AS client_phone
      FROM installments i
      JOIN loans l ON l.id = i.loan_id
      JOIN clients c ON c.id = l.client_id
      WHERE l.deleted_at IS NULL AND l.status = 'aberto'
        AND i.paid_at IS NULL AND i.status = 'aberta'
        AND i.due_date >= ? AND i.due_date <= ?
      ORDER BY i.due_date, c.name COLLATE NOCASE
      ''',
      [start, end],
    );
    return [for (final row in rows) _installment(row)];
  }

  List<WeekBucket> _weeks(DateTime today) {
    final start = DateTime(today.year, today.month, 1);
    final end = DateTime(today.year, today.month + 1, 1);
    final rows = db.select(
      '''
      SELECT i.due_date AS due, i.principal_cents + i.interest_cents AS face, i.paid_at AS paid,
             i.principal_cents + i.interest_cents + i.late_cents AS received
      FROM installments i
      JOIN loans l ON l.id = i.loan_id
      WHERE l.deleted_at IS NULL AND l.status != 'perdido'
        AND i.due_date >= ? AND i.due_date < ?
      ''',
      [isoDate(start), isoDate(end)],
    );
    final expected = [0, 0, 0, 0];
    final received = [0, 0, 0, 0];
    for (final row in rows) {
      final day = parseIsoDate(row['due'] as String).day;
      final index = day <= 7 ? 0 : day <= 14 ? 1 : day <= 21 ? 2 : 3;
      expected[index] += row['face'] as int;
      if (row['paid'] != null) received[index] += row['received'] as int;
    }
    final last = DateTime(today.year, today.month + 1, 0).day;
    return [
      WeekBucket('1–7', expected[0], received[0]),
      WeekBucket('8–14', expected[1], received[1]),
      WeekBucket('15–21', expected[2], received[2]),
      WeekBucket('22–$last', expected[3], received[3]),
    ];
  }

  bool _loanVisible(Row row, String needle, String status, String type, String? from, String? to) {
    final name = (row['client_name'] as String).toLowerCase();
    if (needle.isNotEmpty && !name.contains(needle)) return false;
    final contractDate = row['contract_date'] as String;
    if (from != null && from.isNotEmpty && contractDate.compareTo(from) < 0) return false;
    if (to != null && to.isNotEmpty && contractDate.compareTo(to) > 0) return false;
    if (type == 'apenas_juros' && row['contract_mode'] != 'apenas_juros') return false;
    if (type != 'todos' && type != 'apenas_juros' && row['frequency'] != type) return false;
    final display = _displayStatus(row);
    return switch (status) {
      'aberto' => display == 'Aberto',
      'atrasado' => display == 'Atrasado',
      'quitado' => display == 'Quitado',
      'perdido' => display == 'Perdido',
      _ => true,
    };
  }

  String _displayStatus(Row row) {
    final status = row['status'] as String;
    if (status == 'perdido') return 'Perdido';
    if (status == 'quitado') return 'Quitado';
    if ((row['overdue_count'] as int) > 0) return 'Atrasado';
    return 'Aberto';
  }

  int _int(String sql, [List<Object?> params = const []]) {
    final rows = db.select(sql, params);
    final value = rows.first['c'];
    return (value as int?) ?? 0;
  }

  ClientRecord _client(Row row) {
    return ClientRecord(
      id: row['id'] as int,
      name: row['name'] as String,
      document: row['document'] as String,
      phone: row['phone'] as String,
      zip: row['zip'] as String,
      address: row['address'] as String,
      workAddress: row['work_address'] as String,
      overdueCount: (row['overdue_count'] as int?) ?? 0,
      dueToday: (row['due_today'] as int?) ?? 0,
      deletedAt: row['deleted_at'] as String?,
    );
  }

  LoanRecord _loan(Row row) {
    return LoanRecord(
      id: row['id'] as int,
      clientId: row['client_id'] as int,
      clientName: row['client_name'] as String,
      clientPhone: row['client_phone'] as String,
      principalCents: row['principal_cents'] as int,
      rateBps: row['rate_bps'] as int,
      rateMode: row['rate_mode'] as String,
      contractMode: row['contract_mode'] as String,
      frequency: row['frequency'] as String,
      intervalDays: row['interval_days'] as int,
      count: row['installment_count'] as int,
      contractDate: row['contract_date'] as String,
      lateMode: row['late_mode'] as String,
      latePercentBps: row['late_percent_bps'] as int,
      lateDailyCents: row['late_daily_cents'] as int,
      lateFixedCents: row['late_fixed_cents'] as int,
      notes: row['notes'] as String,
      status: row['status'] as String,
      overdueCount: (row['overdue_count'] as int?) ?? 0,
      nextDue: row['next_due'] as String?,
      openCents: (row['open_cents'] as int?) ?? 0,
      deletedAt: row['deleted_at'] as String?,
    );
  }

  InstallmentRecord _installment(Row row) {
    return InstallmentRecord(
      id: row['id'] as int,
      loanId: row['loan_id'] as int,
      number: row['number'] as int,
      count: row['count'] as int,
      dueDate: row['due_date'] as String,
      principalCents: row['principal_cents'] as int,
      interestCents: row['interest_cents'] as int,
      lateCents: row['late_cents'] as int,
      paidAt: row['paid_at'] as String?,
      status: row['status'] as String,
      clientName: row['client_name'] as String,
      clientPhone: row['client_phone'] as String,
      lateMode: row['late_mode'] as String,
      latePercentBps: row['late_percent_bps'] as int,
      lateDailyCents: row['late_daily_cents'] as int,
      lateFixedCents: row['late_fixed_cents'] as int,
    );
  }
}
