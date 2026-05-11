import 'package:dio/dio.dart';
import 'package:flutter_rest_api_consumer/data/network/api_exceptions.dart';
import 'package:flutter_rest_api_consumer/data/network/auth_token_store.dart';
import 'package:flutter_rest_api_consumer/data/network/dio_client.dart';
import 'package:flutter_rest_api_consumer/domain/models/auth_model.dart';
import 'package:flutter_rest_api_consumer/domain/services/auth_service.dart';

class AuthServiceException implements Exception {
  const AuthServiceException(this.message);

  final String message;

  @override
  String toString() => message;
}

class AuthServiceImpl implements AuthService {
  AuthServiceImpl({
    required DioClient dioClient,
    required AuthTokenStore tokenStore,
  }) : _dioClient = dioClient,
       _tokenStore = tokenStore;

  final DioClient _dioClient;
  final AuthTokenStore _tokenStore;

  @override
  Future<AuthUserModel> login(LoginInput input) async {
    try {
      final json = await _dioClient.post(
        '/auth/login',
        data: {'email': input.email, 'password': input.password},
        requiresAuth: false,
      );

      final data = json['data'];
      if (data is! Map<String, dynamic>) {
        throw const AuthServiceException('Payload de login invalido');
      }

      final user = _parseUser(data['user']);
      final accessToken = data['accessToken'];
      final refreshToken = data['refreshToken'];

      if (accessToken is! String || accessToken.isEmpty) {
        throw const AuthServiceException('Access token invalido');
      }

      _tokenStore.setTokens(
        userId: user.id,
        accessToken: accessToken,
        refreshToken: refreshToken is String ? refreshToken : null,
      );

      return user;
    } on DioException catch (error) {
      throw _toServiceException(error);
    }
  }

  @override
  Future<AuthUserModel> register(RegisterInput input) async {
    try {
      final json = await _dioClient.post(
        '/auth/register',
        data: {'email': input.email, 'password': input.password},
        requiresAuth: false,
      );

      final data = json['data'];
      if (data is! Map<String, dynamic>) {
        throw const AuthServiceException('Payload de registro invalido');
      }

      return _parseUser(data);
    } on DioException catch (error) {
      throw _toServiceException(error);
    }
  }

  @override
  Future<void> logout() async {
    _tokenStore.clear();
  }

  AuthUserModel _parseUser(Object? raw) {
    if (raw is! Map<String, dynamic>) {
      throw const AuthServiceException('Dados de usuario invalidos');
    }

    final id = raw['id'];
    final email = raw['email'];
    final createdAt = raw['createdAt'];

    if (id is! String || id.isEmpty) {
      throw const AuthServiceException('Id do usuario invalido');
    }

    if (email is! String || email.isEmpty) {
      throw const AuthServiceException('Email do usuario invalido');
    }

    if (createdAt is! String) {
      throw const AuthServiceException('Data de criacao invalida');
    }

    final createdAtDate = DateTime.tryParse(createdAt);
    if (createdAtDate == null) {
      throw const AuthServiceException('Data de criacao invalida');
    }

    return AuthUserModel(id: id, email: email, createdAt: createdAtDate);
  }

  AuthServiceException _toServiceException(DioException error) {
    if (error.error is ApiException) {
      return AuthServiceException((error.error as ApiException).message);
    }

    return AuthServiceException(error.message ?? 'Falha na autenticacao');
  }
}
