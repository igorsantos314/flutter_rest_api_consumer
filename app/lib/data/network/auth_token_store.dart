class AuthTokenStore {
  String? _accessToken;
  String? _refreshToken;

  String? get accessToken => _accessToken;
  String? get refreshToken => _refreshToken;
  bool get hasAccessToken => (_accessToken ?? '').isNotEmpty;

  void setTokens({required String accessToken, String? refreshToken}) {
    _accessToken = accessToken;
    if (refreshToken != null && refreshToken.isNotEmpty) {
      _refreshToken = refreshToken;
    }
  }

  void clear() {
    _accessToken = null;
    _refreshToken = null;
  }
}
