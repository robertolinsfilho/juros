import 'dart:async';

import '../data/repository.dart';
import 'auth_api.dart';

final _syncedKey = RegExp(
  r'^(creditor_name|company_name|pix_key|pix_keys|font_scale|sig_[a-z_]+|msg_[a-z0-9_]+)$',
);

/// Ajustes que pertencem à pessoa e acompanham o login em qualquer aparelho.
bool isSyncedSetting(String key) => _syncedKey.hasMatch(key);

/// Mantém os ajustes da pessoa iguais no servidor e neste navegador.
class SettingsSync {
  SettingsSync(this.repo, this.api, {this.delay = const Duration(milliseconds: 700)});

  final Repo repo;
  final AuthApi api;
  final Duration delay;

  String _token = '';
  final Map<String, String?> _pending = {};
  Timer? _timer;

  /// Baixa os ajustes do servidor. Se a conta ainda não tem nenhum, envia os deste navegador.
  Future<void> start(String token) async {
    _token = token;
    repo.onSettingChanged = _queue;
    try {
      final remote = await api.settings(token);
      if (remote.isEmpty) {
        final local = repo.syncedSettings();
        if (local.isNotEmpty) await api.saveSettings(token, local);
      } else {
        repo.applySyncedSettings(remote);
      }
    } on AuthException {
      // Sem rede: segue com o que está neste navegador e tenta enviar as próximas mudanças.
    }
  }

  void _queue(String key, String? value) {
    if (_token.isEmpty || !isSyncedSetting(key)) return;
    _pending[key] = value;
    _timer?.cancel();
    _timer = Timer(delay, () => flush());
  }

  /// Envia agora o que ainda não foi enviado. Devolve false se o servidor não respondeu.
  Future<bool> flush() async {
    _timer?.cancel();
    if (_pending.isEmpty) return true;
    if (_token.isEmpty) return false;
    final batch = Map<String, String?>.of(_pending);
    try {
      await api.saveSettings(_token, batch);
    } on AuthException {
      _timer = Timer(const Duration(seconds: 15), () => flush());
      return false;
    }
    batch.forEach((key, value) {
      if (_pending[key] == value) _pending.remove(key);
    });
    return true;
  }

  /// Ao sair: envia o que falta e limpa os ajustes pessoais para a próxima pessoa não herdá-los.
  Future<void> stop() async {
    final saved = await flush();
    _timer?.cancel();
    repo.onSettingChanged = null;
    _token = '';
    if (saved) {
      repo.applySyncedSettings(const {});
    }
    _pending.clear();
  }
}
