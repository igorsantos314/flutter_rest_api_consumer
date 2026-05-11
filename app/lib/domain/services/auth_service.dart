import 'package:flutter_rest_api_consumer/domain/models/auth_model.dart';

abstract class AuthService {
  Future<AuthUserModel> login(LoginInput input);

  Future<AuthUserModel> register(RegisterInput input);

  Future<void> logout();
}
