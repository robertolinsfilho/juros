import 'dart:async';
import 'dart:convert';

import '../data/repository.dart';
import 'auth_api.dart';

/// Mantém clientes, empréstimos, caixa e ajustes da conta no servidor.
class AccountSync {
  AccountSync(this.repo, this.api, {this.interval = const Duration(seconds: 4)});

  final Repo repo;
  final AuthApi api;
  final Duration interval;

  String _token = '';
  int _revision = 0;
  String _held = '';
  bool _busy = false;
  Timer? _timer;

  /// Chamado quando a cópia de outro aparelho substitui a desta tela.
  void Function()? onApplied;

  Future<void> start(String token) async {
    _token = token;
    try {
      await _reconcile();
    } catch (_) {
      _held = jsonEncode(repo.accountSnapshot());
    }
    _timer?.cancel();
    _timer = Timer.periodic(interval, (_) => flush());
  }

  Future<void> _reconcile() async {
    final remote = await api.account(_token);
    if (remote.revision == 0) {
      if (!repo.accountIsEmpty) {
        await _push(repo.accountSnapshot());
      } else {
        _revision = 0;
        _held = jsonEncode(repo.accountSnapshot());
        await _forgetLegacy();
      }
      return;
    }
    if (remote.data != null) {
      repo.replaceAccount(remote.data!);
      onApplied?.call();
    }
    _revision = remote.revision;
    _held = jsonEncode(repo.accountSnapshot());
    await _forgetLegacy();
  }

  /// Envia o que mudou aqui e, se esta tela estiver parada, busca o que outro aparelho gravou.
  Future<void> flush({bool pull = true}) async {
    if (_busy || _token.isEmpty) return;
    _busy = true;
    try {
      final current = repo.accountSnapshot();
      final encoded = jsonEncode(current);
      if (encoded != _held) {
        await _push(current);
        return;
      }
      if (!pull) return;
      final remote = await api.account(_token);
      if (remote.revision == _revision || remote.data == null) return;
      repo.replaceAccount(remote.data!);
      _revision = remote.revision;
      _held = jsonEncode(repo.accountSnapshot());
      onApplied?.call();
    } catch (_) {
      // A próxima passagem tenta de novo. A tela continua com o que já carregou.
    } finally {
      _busy = false;
    }
  }

  Future<void> _push(Map<String, dynamic> data) async {
    try {
      _revision = await api.saveAccount(_token, _revision, data);
    } on AuthException catch (error) {
      final revision = error.details['revision'];
      if (revision is! num) rethrow;
      _revision = revision.toInt();
      _revision = await api.saveAccount(_token, _revision, data);
    }
    _held = jsonEncode(repo.accountSnapshot());
    await _forgetLegacy();
  }

  Future<void> _forgetLegacy() async {
    final discard = repo.discardLegacy;
    if (discard == null) return;
    repo.discardLegacy = null;
    try {
      await discard();
    } catch (_) {}
  }

  /// Para o relógio sem apagar os dados. A tela foi fechada.
  void close() {
    _timer?.cancel();
    _timer = null;
    _token = '';
  }

  /// Envia o que falta e tira o movimento desta tela, para a próxima pessoa não herdá-lo.
  Future<void> stop() async {
    _timer?.cancel();
    _timer = null;
    if (_token.isNotEmpty) {
      try {
        await flush(pull: false);
      } catch (_) {}
    }
    _token = '';
    _revision = 0;
    _held = '';
    repo.clearAccount();
  }
}
