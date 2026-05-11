import 'package:flutter_rest_api_consumer/domain/models/auth_model.dart';
import 'package:flutter_rest_api_consumer/domain/repositories/auth_repository.dart';
import 'package:flutter_rest_api_consumer/domain/services/auth_service.dart';
import 'package:flutter_rest_api_consumer/utils/result.dart';

class AuthRepositoryImpl implements AuthRepository {
  AuthRepositoryImpl({required AuthService service}) : _service = service;

  final AuthService _service;

  @override
  Future<Result<AuthUserModel>> login(LoginInput input) async {
    try {
      final user = await _service.login(input);
      return Result.ok(user);
    } on Exception catch (error) {
      return Result.error(error);
    }
  }

  @override
  Future<Result<AuthUserModel>> register(RegisterInput input) async {
    try {
      final user = await _service.register(input);
      return Result.ok(user);
    } on Exception catch (error) {
      return Result.error(error);
    }
  }

  @override
  Future<Result<void>> logout() async {
    try {
      await _service.logout();
      return const Result.ok(null);
    } on Exception catch (error) {
      return Result.error(error);
    }
  }
}
