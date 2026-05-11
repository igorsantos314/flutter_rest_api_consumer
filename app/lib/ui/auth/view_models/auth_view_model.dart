import 'package:flutter/foundation.dart';
import 'package:flutter_rest_api_consumer/data/network/auth_token_store.dart';
import 'package:flutter_rest_api_consumer/domain/models/auth_model.dart';
import 'package:flutter_rest_api_consumer/domain/repositories/auth_repository.dart';
import 'package:flutter_rest_api_consumer/utils/command.dart';
import 'package:flutter_rest_api_consumer/utils/result.dart';

class AuthViewModel extends ChangeNotifier {
  AuthViewModel({
    required AuthRepository repository,
    required AuthTokenStore tokenStore,
  }) : _repository = repository,
       _tokenStore = tokenStore {
    login = Command1<AuthUserModel, LoginInput>(_login);
    register = Command1<AuthUserModel, RegisterInput>(_register);
    logout = Command0<void>(_logout);

    _isAuthenticated = _tokenStore.hasAccessToken;
    _tokenStore.addListener(_onTokenStoreChanged);
  }

  final AuthRepository _repository;
  final AuthTokenStore _tokenStore;

  late final Command1<AuthUserModel, LoginInput> login;
  late final Command1<AuthUserModel, RegisterInput> register;
  late final Command0<void> logout;

  bool _isAuthenticated = false;
  AuthUserModel? _currentUser;

  bool get isAuthenticated => _isAuthenticated;
  AuthUserModel? get currentUser => _currentUser;

  Future<Result<AuthUserModel>> _login(LoginInput input) async {
    final result = await _repository.login(input);

    switch (result) {
      case Ok<AuthUserModel>():
        _currentUser = result.value;
        _isAuthenticated = true;
        notifyListeners();
        return Result.ok(result.value);
      case Error<AuthUserModel>():
        return Result.error(result.error);
    }
  }

  Future<Result<AuthUserModel>> _register(RegisterInput input) async {
    final registerResult = await _repository.register(input);
    switch (registerResult) {
      case Error<AuthUserModel>():
        return Result.error(registerResult.error);
      case Ok<AuthUserModel>():
        break;
    }

    // Auto-login apos registro bem sucedido.
    return _login(LoginInput(email: input.email, password: input.password));
  }

  Future<Result<void>> _logout() async {
    final result = await _repository.logout();
    switch (result) {
      case Ok<void>():
        _currentUser = null;
        _isAuthenticated = false;
        notifyListeners();
        return const Result.ok(null);
      case Error<void>():
        return Result.error(result.error);
    }
  }

  void _onTokenStoreChanged() {
    final nextAuthenticated = _tokenStore.hasAccessToken;
    if (_isAuthenticated == nextAuthenticated) {
      return;
    }

    _isAuthenticated = nextAuthenticated;
    if (!nextAuthenticated) {
      _currentUser = null;
    }
    notifyListeners();
  }

  @override
  void dispose() {
    _tokenStore.removeListener(_onTokenStoreChanged);
    login.dispose();
    register.dispose();
    logout.dispose();
    super.dispose();
  }
}
