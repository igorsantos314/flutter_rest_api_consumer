import 'package:flutter_rest_api_consumer/domain/models/auth_model.dart';
import 'package:flutter_rest_api_consumer/utils/result.dart';

abstract class AuthRepository {
  Future<Result<AuthUserModel>> login(LoginInput input);

  Future<Result<AuthUserModel>> register(RegisterInput input);

  Future<Result<void>> logout();
}
