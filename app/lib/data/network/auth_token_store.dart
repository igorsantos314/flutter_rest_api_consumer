import 'dart:convert';

import 'package:flutter/foundation.dart';

/// Armazena tokens JWT e informacoes do usuario.
///
/// Mantem os credenciais em memoria durante a sessao e notifica listeners
/// quando o estado de autenticacao muda.
class AuthTokenStore extends ChangeNotifier {
  String? _accessToken;
  String? _refreshToken;
  String? _userId;
  DateTime? _accessTokenExpiresAt;
  DateTime? _refreshTokenExpiresAt;

  String? get accessToken => _accessToken;
  String? get refreshToken => _refreshToken;
  String? get userId => _userId;
  bool get hasAccessToken => (_accessToken ?? '').isNotEmpty;
  bool get hasRefreshToken => (_refreshToken ?? '').isNotEmpty;

  DateTime? get accessTokenExpiresAt => _accessTokenExpiresAt;
  DateTime? get refreshTokenExpiresAt => _refreshTokenExpiresAt;

  bool get isAccessTokenExpired {
    final expiresAt = _accessTokenExpiresAt;
    if (expiresAt == null) {
      return false;
    }

    // Considera uma margem de 5 segundos para evitar corrida de expiracao.
    return DateTime.now().isAfter(expiresAt.subtract(const Duration(seconds: 5)));
  }

  bool get isRefreshTokenExpired {
    final expiresAt = _refreshTokenExpiresAt;
    if (expiresAt == null) {
      return false;
    }

    return DateTime.now().isAfter(expiresAt.subtract(const Duration(seconds: 5)));
  }

  /// Armazena tokens após login bem-sucedido
  /// userId: identificador do usuário (vem do JWT claim 'sub')
  /// accessToken: token para usar nas requisições
  /// refreshToken: token para renovar o access token
  void setTokens({
    required String userId,
    required String accessToken,
    String? refreshToken,
  }) {
    _userId = userId;
    _accessToken = accessToken;
    _accessTokenExpiresAt = _extractExpiryFromJwt(accessToken);

    if (refreshToken != null && refreshToken.isNotEmpty) {
      _refreshToken = refreshToken;
      _refreshTokenExpiresAt = _extractExpiryFromJwt(refreshToken);
    }

    notifyListeners();
  }

  /// Limpa os tokens (logout)
  void clear() {
    _accessToken = null;
    _refreshToken = null;
    _userId = null;
    _accessTokenExpiresAt = null;
    _refreshTokenExpiresAt = null;
    notifyListeners();
  }

  DateTime? _extractExpiryFromJwt(String token) {
    final parts = token.split('.');
    if (parts.length < 2) {
      return null;
    }

    try {
      final normalized = base64Url.normalize(parts[1]);
      final decoded = utf8.decode(base64Url.decode(normalized));
      final payload = jsonDecode(decoded);
      if (payload is! Map<String, dynamic>) {
        return null;
      }

      final exp = payload['exp'];
      if (exp is int) {
        return DateTime.fromMillisecondsSinceEpoch(exp * 1000);
      }

      if (exp is num) {
        return DateTime.fromMillisecondsSinceEpoch(exp.toInt() * 1000);
      }

      return null;
    } catch (_) {
      return null;
    }
  }
}
