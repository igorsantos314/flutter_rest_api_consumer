/// Armazena tokens JWT e informações do usuário
/// Responsável por manter os credentials em memória durante a sessão
class AuthTokenStore {
  String? _accessToken;
  String? _refreshToken;
  String? _userId;

  String? get accessToken => _accessToken;
  String? get refreshToken => _refreshToken;
  String? get userId => _userId;
  bool get hasAccessToken => (_accessToken ?? '').isNotEmpty;

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
    if (refreshToken != null && refreshToken.isNotEmpty) {
      _refreshToken = refreshToken;
    }
  }

  /// Limpa os tokens (logout)
  void clear() {
    _accessToken = null;
    _refreshToken = null;
    _userId = null;
  }
}
