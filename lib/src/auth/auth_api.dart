import 'dart:convert';

import 'package:http/http.dart' as http;

import 'api_base.dart';

class SessionUser {
  const SessionUser({
    required this.id,
    required this.username,
    required this.name,
    required this.role,
    required this.active,
  });

  final int id;
  final String username;
  final String name;
  final String role;
  final bool active;

  bool get isAdmin => role == 'admin';

  String get roleLabel => isAdmin ? 'Administrador' : 'Usuário comum';

  factory SessionUser.fromJson(Map<String, dynamic> json) {
    return SessionUser(
      id: (json['id'] as num).toInt(),
      username: json['username'] as String,
      name: json['name'] as String,
      role: json['role'] as String,
      active: json['active'] == true || json['active'] == 1,
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

  Future<SessionUser> me(String token) async {
    final json = await _send('GET', '/api/me', token: token);
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

  Future<void> setPassword(String token, int id, String password) async {
    await _send('POST', '/api/users/$id/password', token: token, body: {'password': password});
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
