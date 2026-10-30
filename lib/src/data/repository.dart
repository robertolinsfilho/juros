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
    this.pixKey = '',
  });

  final String pixKey;
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

  /// Apaga a cópia antiga do IndexedDB depois que o servidor já tem os dados.
  Future<void> Function()? discardLegacy;

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
    db.execute('''
      CREATE TABLE IF NOT EXISTS reminders (
        installment_id INTEGER NOT NULL,
        due_date TEXT NOT NULL,
        sent_at TEXT NOT NULL,
        PRIMARY KEY (installment_id, due_date)
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
    _addColumn('loans', 'skip_weekdays', 'INTEGER NOT NULL DEFAULT 0');
    _addColumn('loans', 'fixed_installment', 'INTEGER NOT NULL DEFAULT 0');
    _addColumn('loans', 'charge_frequency', "TEXT NOT NULL DEFAULT ''");
    _addColumn('loans', 'pix_key', "TEXT NOT NULL DEFAULT ''");
  }

  void _addColumn(String table, String name, String definition) {
    final columns = db.select('PRAGMA table_info($table)');
    if (columns.any((row) => row['name'] == name)) return;
    db.execute('ALTER TABLE $table ADD COLUMN $name $definition');
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
    onSettingChanged?.call(key, null);
  }

  /// Chamado quando um ajuste muda; usado para enviar os ajustes pessoais ao servidor.
  void Function(String key, String? value)? onSettingChanged;

  static final _personalKey = RegExp(
    r'^(creditor_name|company_name|pix_key|pix_keys|font_scale|sig_[a-z_]+|msg_[a-z0-9_]+)$',
  );

  /// Ajustes pessoais guardados neste navegador.
  Map<String, String> syncedSettings() {
    final rows = db.select('SELECT key, value FROM settings');
    return {
      for (final row in rows)
        if (_personalKey.hasMatch(row['key'] as String)) row['key'] as String: row['value'] as String,
    };
  }

  /// Troca os ajustes pessoais pelos do servidor, sem avisar de volta.
  void applySyncedSettings(Map<String, String> remote) {
    for (final key in syncedSettings().keys) {
      if (!remote.containsKey(key)) db.execute('DELETE FROM settings WHERE key = ?', [key]);
    }
    remote.forEach((key, value) {
      if (!_personalKey.hasMatch(key)) return;
      db.execute(
        '''
        INSERT INTO settings(key, value) VALUES(?, ?)
        ON CONFLICT(key) DO UPDATE SET value = excluded.value
        ''',
        [key, value],
      );
    });
  }

  void setSetting(String key, String value) {
    db.execute(
      '''
      INSERT INTO settings(key, value) VALUES(?, ?)
      ON CONFLICT(key) DO UPDATE SET value = excluded.value
      ''',
      [key, value],
    );
    onSettingChanged?.call(key, value);
  }

  static const accountTables = ['clients', 'loans', 'installments', 'cash_entries', 'reminders'];

  /// Cópia do movimento desta conta, sem o token de entrada.
  Map<String, dynamic> accountSnapshot() {
    return {
      for (final table in accountTables) table: _tableRows(table),
      'settings': {
        for (final row in db.select('SELECT key, value FROM settings ORDER BY key'))
          if (row['key'] != 'session_token') row['key'] as String: row['value'] as String,
      },
    };
  }

  bool get accountIsEmpty {
    for (final table in accountTables) {
      final count = db.select('SELECT COUNT(*) AS n FROM $table').first['n'] as int;
      if (count > 0) return false;
    }
    final settings = accountSnapshot()['settings'] as Map;
    return settings.isEmpty;
  }

  List<Map<String, Object?>> _tableRows(String table) {
    final order = table == 'reminders' ? 'installment_id, due_date' : 'id';
    final columns = [
      for (final row in db.select('PRAGMA table_info($table)')) row['name'] as String,
    ];
    return [
      for (final row in db.select('SELECT * FROM $table ORDER BY $order'))
        {for (final column in columns) column: row[column]},
    ];
  }

  /// Troca o movimento local pela cópia do servidor. O token de entrada fica.
  void replaceAccount(Map<String, dynamic> data) {
    final listener = onSettingChanged;
    onSettingChanged = null;
    db.execute('PRAGMA foreign_keys = OFF');
    db.execute('BEGIN');
    try {
      for (final table in accountTables.reversed) {
        db.execute('DELETE FROM $table');
      }
      db.execute("DELETE FROM settings WHERE key != 'session_token'");
      for (final table in accountTables) {
        final rows = data[table];
        if (rows is! List) continue;
        for (final raw in rows) {
          if (raw is Map) _insertAccountRow(table, raw);
        }
      }
      final settings = data['settings'];
      if (settings is Map) {
        settings.forEach((key, value) {
          final name = key.toString();
          if (name == 'session_token' || value == null) return;
          db.execute('INSERT INTO settings(key, value) VALUES(?, ?)', [name, value.toString()]);
        });
      }
      db.execute('COMMIT');
    } catch (_) {
      db.execute('ROLLBACK');
      rethrow;
    } finally {
      db.execute('PRAGMA foreign_keys = ON');
      onSettingChanged = listener;
    }
  }

  void clearAccount() {
    replaceAccount(const {
      'clients': [],
      'loans': [],
      'installments': [],
      'cash_entries': [],
      'reminders': [],
      'settings': {},
    });
  }

  void _insertAccountRow(String table, Map raw) {
    final known = {
      for (final row in db.select('PRAGMA table_info($table)')) row['name'] as String,
    };
    final keys = [for (final key in raw.keys) key.toString()].where(known.contains).toList();
    if (keys.isEmpty) return;
    final marks = List.filled(keys.length, '?').join(',');
    db.execute(
      'INSERT INTO $table(${keys.join(',')}) VALUES($marks)',
      [for (final key in keys) raw[key]],
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
          notes, status, created_at, skip_weekdays, fixed_installment, charge_frequency, pix_key
        ) VALUES(?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, 'aberto', ?, ?, ?, ?, ?)
        ''',
        [
          draft.clientId,
          draft.principalCents,
          draft.rateBps,
          draft.rateMode.code,
          draft.contractMode.code,
          draft.frequency.code,
          draft.intervalDays,
          plan.length,
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
          draft.skipWeekdays,
          draft.fixedInstallment ? 1 : 0,
          draft.chargeFrequency?.code ?? '',
          draft.pixKey,
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
             l.late_daily_cents, l.late_fixed_cents, l.contract_mode, l.frequency,
             l.charge_frequency, l.interval_days, l.fixed_installment, l.skip_saturday,
             l.skip_sunday, l.skip_holiday, l.skip_weekdays
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
      _rollFixedInterest(row);
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

  void _rollFixedInterest(Row row) {
    if ((row['fixed_installment'] as int? ?? 0) != 1) return;
    if (row['contract_mode'] != 'apenas_juros') return;
    if ((row['principal_cents'] as int) != 0) return;
    final interest = row['interest_cents'] as int;
    if (interest <= 0) return;
    final loanId = row['loan_id'] as int;
    final stored = (row['charge_frequency'] as String?) ?? '';
    final frequency = FrequencyLabel.parse(stored.isEmpty ? row['frequency'] as String : stored);
    final next = nextChargeDate(
      from: parseIsoDate(row['due_date'] as String),
      frequency: frequency,
      intervalDays: (row['interval_days'] as int?) ?? 1,
      skipSaturday: (row['skip_saturday'] as int) == 1,
      skipSunday: (row['skip_sunday'] as int) == 1,
      skipHoliday: (row['skip_holiday'] as int) == 1,
      skipWeekdays: (row['skip_weekdays'] as int?) ?? 0,
    );
    final capital = db.select(
      '''
      SELECT number FROM installments
      WHERE loan_id = ? AND paid_at IS NULL AND status = 'aberta' AND principal_cents > 0
      ORDER BY number LIMIT 1
      ''',
      [loanId],
    );
    final number = capital.isEmpty
        ? _int('SELECT COALESCE(MAX(number), 0) + 1 AS c FROM installments WHERE loan_id = ?', [loanId])
        : capital.first['number'] as int;
    if (capital.isNotEmpty) {
      db.execute(
        'UPDATE installments SET number = number + 1 WHERE loan_id = ? AND number >= ?',
        [loanId, number],
      );
    }
    db.execute(
      '''
      INSERT INTO installments(loan_id, number, due_date, principal_cents, interest_cents, status)
      VALUES(?, ?, ?, 0, ?, 'aberta')
      ''',
      [loanId, number, isoDate(next), interest],
    );
    db.execute(
      '''
      UPDATE loans SET installment_count = (SELECT COUNT(*) FROM installments WHERE loan_id = ?)
      WHERE id = ?
      ''',
      [loanId, loanId],
    );
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

  bool loanHasPayments(int loanId) {
    final rows = db.select(
      'SELECT COUNT(*) AS total FROM installments WHERE loan_id = ? AND paid_at IS NOT NULL',
      [loanId],
    );
    return (rows.first['total'] as int) > 0;
  }

  /// Reconstrói os dados de criação a partir do contrato salvo.
  LoanDraft? draftOf(int loanId) {
    final rows = db.select('SELECT * FROM loans WHERE id = ?', [loanId]);
    if (rows.isEmpty) return null;
    final row = rows.first;
    final charge = (row['charge_frequency'] as String?) ?? '';
    return LoanDraft(
      clientId: row['client_id'] as int,
      principalCents: row['principal_cents'] as int,
      rateBps: row['rate_bps'] as int,
      rateMode: RateModeLabel.parse(row['rate_mode'] as String),
      contractMode: ContractModeLabel.parse(row['contract_mode'] as String),
      frequency: FrequencyLabel.parse(row['frequency'] as String),
      intervalDays: row['interval_days'] as int,
      count: row['installment_count'] as int,
      contractDate: parseIsoDate(row['contract_date'] as String),
      skipSaturday: (row['skip_saturday'] as int) == 1,
      skipSunday: (row['skip_sunday'] as int) == 1,
      skipHoliday: (row['skip_holiday'] as int) == 1,
      lateMode: row['late_mode'] as String,
      latePercentBps: row['late_percent_bps'] as int,
      lateDailyCents: row['late_daily_cents'] as int,
      lateFixedCents: row['late_fixed_cents'] as int,
      notes: row['notes'] as String,
      skipWeekdays: row['skip_weekdays'] as int,
      fixedInstallment: (row['fixed_installment'] as int) == 1,
      chargeFrequency: charge.isEmpty ? null : FrequencyLabel.parse(charge),
      pixKey: (row['pix_key'] as String?) ?? '',
    );
  }

  /// Parcelas vencidas e em aberto de todos os contratos do cliente.
  List<InstallmentRecord> overdueOfClient(int clientId, [DateTime? today]) {
    final day = isoDate(today ?? DateTime.now());
    final rows = db.select(
      '''
      SELECT i.*, l.installment_count AS count, l.late_mode, l.late_percent_bps,
             l.late_daily_cents, l.late_fixed_cents, c.name AS client_name, c.phone AS client_phone
      FROM installments i
      JOIN loans l ON l.id = i.loan_id
      JOIN clients c ON c.id = l.client_id
      WHERE l.client_id = ? AND l.deleted_at IS NULL AND l.status = 'aberto'
        AND i.paid_at IS NULL AND i.status = 'aberta' AND i.due_date < ?
      ORDER BY i.loan_id, i.due_date
      ''',
      [clientId, day],
    );
    return [for (final row in rows) _installment(row)];
  }

  /// Atualiza um contrato. Com [rebuild], valor, taxa, prazo e datas são
  /// recalculados e as parcelas são substituídas (só vale sem pagamentos).
  /// Sem [rebuild], só mora, dias sem cobrança e observações mudam.
  void updateLoan(int loanId, LoanDraft draft, {required bool rebuild}) {
    if (rebuild && loanHasPayments(loanId)) {
      throw StateError('Contrato com parcelas pagas não pode ser recalculado.');
    }
    db.execute('BEGIN');
    try {
      if (rebuild) {
        final plan = buildSchedule(draft);
        db.execute(
          '''
          UPDATE loans SET principal_cents = ?, rate_bps = ?, rate_mode = ?, frequency = ?,
            interval_days = ?, installment_count = ?, contract_date = ?, skip_saturday = ?,
            skip_sunday = ?, skip_holiday = ?, skip_weekdays = ?, late_mode = ?,
            late_percent_bps = ?, late_daily_cents = ?, late_fixed_cents = ?, notes = ?
          WHERE id = ?
          ''',
          [
            draft.principalCents,
            draft.rateBps,
            draft.rateMode.code,
            draft.frequency.code,
            draft.intervalDays,
            plan.length,
            isoDate(draft.contractDate),
            draft.skipSaturday ? 1 : 0,
            draft.skipSunday ? 1 : 0,
            draft.skipHoliday ? 1 : 0,
            draft.skipWeekdays,
            draft.lateMode,
            draft.latePercentBps,
            draft.lateDailyCents,
            draft.lateFixedCents,
            draft.notes.trim(),
            loanId,
          ],
        );
        db.execute('DELETE FROM installments WHERE loan_id = ?', [loanId]);
        for (final item in plan) {
          db.execute(
            '''
            INSERT INTO installments(loan_id, number, due_date, principal_cents, interest_cents, status)
            VALUES(?, ?, ?, ?, ?, 'aberta')
            ''',
            [loanId, item.number, isoDate(item.due), item.principalCents, item.interestCents],
          );
        }
      } else {
        db.execute(
          '''
          UPDATE loans SET skip_saturday = ?, skip_sunday = ?, skip_holiday = ?, skip_weekdays = ?,
            late_mode = ?, late_percent_bps = ?, late_daily_cents = ?, late_fixed_cents = ?, notes = ?
          WHERE id = ?
          ''',
          [
            draft.skipSaturday ? 1 : 0,
            draft.skipSunday ? 1 : 0,
            draft.skipHoliday ? 1 : 0,
            draft.skipWeekdays,
            draft.lateMode,
            draft.latePercentBps,
            draft.lateDailyCents,
            draft.lateFixedCents,
            draft.notes.trim(),
            loanId,
          ],
        );
      }
      db.execute('COMMIT');
    } catch (_) {
      db.execute('ROLLBACK');
      rethrow;
    }
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

  /// Quantos dias antes do vencimento o aviso entra na fila. Zero avisa só no dia.
  int get reminderDays {
    final value = int.tryParse(setting('aviso_dias', '1')) ?? 1;
    if (value < 0) return 0;
    if (value > 7) return 7;
    return value;
  }

  void setReminderDays(int days) {
    final bounded = days < 0 ? 0 : (days > 7 ? 7 : days);
    setSetting('aviso_dias', '$bounded');
  }

  /// Parcelas em aberto que vencem até o prazo do aviso e ainda não foram avisadas.
  List<InstallmentRecord> dueReminders(DateTime today) {
    final start = dateOnly(today);
    final end = start.add(Duration(days: reminderDays));
    final pending = _dueBetween(isoDate(start), isoDate(end));
    if (pending.isEmpty) return const [];
    final sent = {
      for (final row in db.select('SELECT installment_id, due_date FROM reminders'))
        '${row['installment_id']}|${row['due_date']}',
    };
    return [
      for (final item in pending)
        if (!sent.contains('${item.id}|${item.dueDate}')) item,
    ];
  }

  void markReminderSent(InstallmentRecord item, [DateTime? when]) {
    db.execute(
      '''
      INSERT INTO reminders(installment_id, due_date, sent_at) VALUES(?, ?, ?)
      ON CONFLICT(installment_id, due_date) DO UPDATE SET sent_at = excluded.sent_at
      ''',
      [item.id, item.dueDate, isoDate(when ?? DateTime.now())],
    );
  }

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
      pixKey: (row['pix_key'] as String?) ?? '',
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
