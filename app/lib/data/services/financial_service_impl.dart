import 'package:flutter_rest_api_consumer/data/models/financial_dto.dart';
import 'package:flutter_rest_api_consumer/data/network/auth_token_store.dart';
import 'package:flutter_rest_api_consumer/data/network/dio_client.dart';
import 'package:flutter_rest_api_consumer/data/network/api_exceptions.dart';
import 'package:flutter_rest_api_consumer/domain/models/financial_model.dart';
import 'package:flutter_rest_api_consumer/domain/services/financial_service.dart';
import 'package:dio/dio.dart';

class FinancialServiceException implements Exception {
  const FinancialServiceException(this.message);

  final String message;

  @override
  String toString() => message;
}

class FinancialServiceImpl implements FinancialService {
  FinancialServiceImpl({
    required DioClient dioClient,
    required AuthTokenStore tokenStore,
  }) : _dioClient = dioClient,
       _tokenStore = tokenStore;

  final DioClient _dioClient;
  final AuthTokenStore _tokenStore;

  @override
  Future<void> bootstrapAuthSession() async {
    if (_tokenStore.hasAccessToken) {
      return;
    }

    try {
      final json = await _dioClient.get(
        '/auth/dev-token',
        requiresAuth: false,
        skipGlobalLoader: true,
      );

      final data = json['data'];
      if (data is! Map<String, dynamic>) {
        throw const FinancialServiceException(
          'Payload de autenticacao invalido',
        );
      }

      final accessToken = (data['accessToken'] ?? data['token']) as String?;
      final refreshToken = data['refreshToken'] as String?;
      if (accessToken == null || accessToken.isEmpty) {
        throw const FinancialServiceException(
          'Token de acesso nao retornado pela API',
        );
      }

      _tokenStore.setTokens(
        accessToken: accessToken,
        refreshToken: refreshToken,
      );
    } on DioException catch (error) {
      if (error.error is ApiException) {
        throw FinancialServiceException((error.error as ApiException).message);
      }
      throw const FinancialServiceException('Falha ao autenticar no backend');
    }
  }

  @override
  Future<PagedFinancialModel> listFinancials(FinancialFilters filters) async {
    final query = <String, String>{
      'page': '${filters.page}',
      'limit': '${filters.limit}',
      'sortBy': filters.sortBy,
      'order': filters.order,
    };

    if (filters.status != null) {
      query['status'] = financialStatusToApi(filters.status!);
    }

    if (filters.type != null) {
      query['type'] = financialTypeToApi(filters.type!);
    }

    if (filters.startDate != null) {
      query['startDate'] = filters.startDate!.toIso8601String();
    }

    if (filters.endDate != null) {
      query['endDate'] = filters.endDate!.toIso8601String();
    }

    try {
      final json = await _dioClient.get('/financial', queryParameters: query);
      return PagedFinancialDto.fromJson(json).toDomain();
    } on DioException catch (error) {
      throw _toServiceException(error);
    }
  }

  @override
  Future<FinancialModel> createFinancial(CreateFinancialInput input) async {
    try {
      final json = await _dioClient.post(
        '/financial',
        data: {
          'description': input.description,
          'amount': input.amount,
          'type': financialTypeToApi(input.type),
          'category': input.category,
          'date': input.date.toIso8601String(),
          'notes': input.notes,
        },
      );

      return FinancialDto.fromJson(
        json['data'] as Map<String, dynamic>,
      ).toDomain();
    } on DioException catch (error) {
      throw _toServiceException(error);
    }
  }

  @override
  Future<FinancialModel> getFinancialById(String id) async {
    try {
      final json = await _dioClient.get('/financial/$id');
      return FinancialDto.fromJson(
        json['data'] as Map<String, dynamic>,
      ).toDomain();
    } on DioException catch (error) {
      throw _toServiceException(error);
    }
  }

  @override
  Future<FinancialModel> updateFinancialStatus(
    String id,
    FinancialStatus status,
  ) async {
    try {
      final json = await _dioClient.patch(
        '/financial/$id/status',
        data: {'status': financialStatusToApi(status)},
      );

      return FinancialDto.fromJson(
        json['data'] as Map<String, dynamic>,
      ).toDomain();
    } on DioException catch (error) {
      throw _toServiceException(error);
    }
  }

  FinancialServiceException _toServiceException(DioException error) {
    if (error.error is ApiException) {
      return FinancialServiceException((error.error as ApiException).message);
    }

    return FinancialServiceException(
      error.message ?? 'Falha na requisicao HTTP',
    );
  }
}
