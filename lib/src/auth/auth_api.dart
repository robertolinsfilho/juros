import 'dart:convert';

import 'package:http/http.dart' as http;

import 'api_base.dart';

class AccessInfo {
  const AccessInfo({
    required this.status,
    required this.daysLeft,
    required this.trialEndsAt,
    required this.paidUntil,
    required this.plan,
    required this.blocked,
  });

  static const free = AccessInfo(
    status: 'teste',
    daysLeft: 3,
    trialEndsAt: 0,
    paidUntil: 0,
    plan: '',
    blocked: false,
  );

  /// teste, assinante ou vencido.
  final String status;
  final int daysLeft;
  final int trialEndsAt;
  final int paidUntil;
  final String plan;
  final bool blocked;

  bool get trial => status == 'teste';
  bool get subscriber => status == 'assinante';

  String get label => switch (status) {
    'assinante' => 'Assinatura ativa',
    'vencido' => 'Acesso vencido',
    _ => 'Teste gratuito',
  };

  String get daysText => daysLeft == 1 ? '1 dia restante' : '$daysLeft dias restantes';

  factory AccessInfo.fromJson(Map<String, dynamic>? json) {
    if (json == null) return free;
    return AccessInfo(
      status: json['status'] as String? ?? 'teste',
      daysLeft: (json['days_left'] as num?)?.toInt() ?? 0,
      trialEndsAt: (json['trial_ends_at'] as num?)?.toInt() ?? 0,
      paidUntil: (json['paid_until'] as num?)?.toInt() ?? 0,
      plan: json['plan'] as String? ?? '',
      blocked: json['blocked'] == true,
    );
  }
}

class SessionUser {
  const SessionUser({
    required this.id,
    required this.username,
    required this.name,
    required this.role,
    required this.active,
    this.email = '',
    this.access = AccessInfo.free,
  });

  final int id;
  final String username;
  final String name;
  final String role;
  final bool active;
  final String email;
  final AccessInfo access;

  bool get isAdmin => role == 'admin';

  String get roleLabel => isAdmin ? 'Administrador' : 'Usuário comum';

  factory SessionUser.fromJson(Map<String, dynamic> json) {
    return SessionUser(
      id: (json['id'] as num).toInt(),
      username: json['username'] as String,
      name: json['name'] as String,
      role: json['role'] as String,
      active: json['active'] == true || json['active'] == 1,
      email: json['email'] as String? ?? '',
      access: AccessInfo.fromJson(json['access'] as Map<String, dynamic>?),
    );
  }
}

class AuthException implements Exception {
  AuthException(this.message);

  final String message;

  @override
  String toString() => message;
}

class AuthApi {
  AuthApi({http.Client? client}) : _client = client ?? http.Client();

  final http.Client _client;

  Future<({SessionUser user, String token})> login(String username, String password) async {
    final json = await _send('POST', '/api/login', body: {
      'username': username.trim(),
      'password': password,
    });
    return (
      user: SessionUser.fromJson(json['user'] as Map<String, dynamic>),
      token: json['token'] as String,
    );
  }

  Future<({SessionUser user, String token})> signup({
    required String name,
    required String username,
    required String email,
    required String password,
  }) async {
    final json = await _send('POST', '/api/signup', body: {
      'name': name.trim(),
      'username': username.trim(),
      'email': email.trim(),
      'password': password,
    });
    return (
      user: SessionUser.fromJson(json['user'] as Map<String, dynamic>),
      token: json['token'] as String,
    );
  }

  Future<SessionUser> me(String token) async {
    final json = await _send('GET', '/api/me', token: token);
    return SessionUser.fromJson(json['user'] as Map<String, dynamic>);
  }

  Future<Map<String, String>> settings(String token) async {
    final json = await _send('GET', '/api/settings', token: token);
    final raw = json['settings'];
    if (raw is! Map) return {};
    return {for (final entry in raw.entries) entry.key as String: entry.value as String};
  }

  /// Valor nulo apaga o ajuste no servidor.
  Future<void> saveSettings(String token, Map<String, String?> changes) async {
    await _send('POST', '/api/settings', token: token, body: {'settings': changes});
  }

  /// Abre o checkout do Mercado Pago. `period` é `mes` ou `ano`.
  Future<({String checkoutUrl, String message})> subscribe(
    String token,
    String plan, {
    String period = 'mes',
  }) async {
    final json = await _send('POST', '/api/subscribe', token: token, body: {'plan': plan, 'period': period});
    return (
      checkoutUrl: json['checkout_url'] as String? ?? '',
      message: json['message'] as String? ?? '',
    );
  }

  Future<List<({int id, String name, String username, String planLabel, int createdAt, String status})>>
  requests(String token) async {
    final json = await _send('GET', '/api/requests', token: token);
    return [
      for (final item in json['requests'] as List<dynamic>)
        (
          id: ((item as Map)['id'] as num).toInt(),
          name: item['name'] as String,
          username: item['username'] as String,
          planLabel: item['plan_label'] as String,
          createdAt: (item['created_at'] as num).toInt(),
          status: item['status'] as String,
        ),
    ];
  }

  /// Libera (ou encerra, com zero dias) o acesso de alguém.
  Future<SessionUser> setAccess(String token, int id, {required int days, String plan = ''}) async {
    final json = await _send('POST', '/api/users/$id/access', token: token, body: {'days': days, 'plan': plan});
    return SessionUser.fromJson(json['user'] as Map<String, dynamic>);
  }

  Future<void> logout(String token) async {
    try {
      await _send('POST', '/api/logout', token: token);
    } catch (_) {}
  }

  Future<List<SessionUser>> users(String token) async {
    final json = await _send('GET', '/api/users', token: token);
    final list = json['users'] as List<dynamic>;
    return [for (final item in list) SessionUser.fromJson(item as Map<String, dynamic>)];
  }

  Future<SessionUser> createUser(
    String token, {
    required String username,
    required String name,
    required String password,
    required String role,
  }) async {
    final json = await _send('POST', '/api/users', token: token, body: {
      'username': username,
      'name': name,
      'password': password,
      'role': role,
    });
    return SessionUser.fromJson(json['user'] as Map<String, dynamic>);
  }

  Future<void> setRole(String token, int id, String role) async {
    await _send('POST', '/api/users/$id/role', token: token, body: {'role': role});
  }

  Future<void> setActive(String token, int id, bool active) async {
    await _send('POST', '/api/users/$id/active', token: token, body: {'active': active});
  }

  Future<SessionUser> updateProfile(String token, {required String name}) async {
    final json = await _send('POST', '/api/me', token: token, body: {'name': name});
    return SessionUser.fromJson(json['user'] as Map<String, dynamic>);
  }

  Future<void> setPassword(String token, int id, String password, {String? current}) async {
    await _send('POST', '/api/users/$id/password', token: token, body: {
      'password': password,
      'current': ?current,
    });
  }

  Future<Map<String, dynamic>> _send(
    String method,
    String path, {
    String? token,
    Map<String, dynamic>? body,
  }) async {
    final headers = <String, String>{'Content-Type': 'application/json'};
    if (token != null && token.isNotEmpty) headers['Authorization'] = 'Bearer $token';
    final encoded = body == null ? null : jsonEncode(body);
    late http.Response response;
    try {
      final uri = Uri.parse('$apiBase$path');
      response = await switch (method) {
        'POST' => _client.post(uri, headers: headers, body: encoded),
        _ => _client.get(uri, headers: headers),
      }.timeout(const Duration(seconds: 20));
    } catch (_) {
      throw AuthException('Não foi possível falar com o servidor.');
    }
    Map<String, dynamic> json = {};
    if (response.body.isNotEmpty) {
      final decoded = jsonDecode(response.body);
      if (decoded is Map<String, dynamic>) json = decoded;
    }
    if (response.statusCode >= 400) {
      throw AuthException(json['error'] as String? ?? 'Não foi possível concluir.');
    }
    return json;
  }
}
