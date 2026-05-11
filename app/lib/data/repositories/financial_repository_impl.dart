import 'package:flutter_rest_api_consumer/domain/models/financial_model.dart';
import 'package:flutter_rest_api_consumer/domain/repositories/financial_repository.dart';
import 'package:flutter_rest_api_consumer/domain/services/financial_service.dart';
import 'package:flutter_rest_api_consumer/utils/result.dart';

class FinancialRepositoryImpl implements FinancialRepository {
  FinancialRepositoryImpl({required FinancialService service})
    : _service = service;

  final FinancialService _service;

  @override
  Future<Result<void>> ensureAuthenticated() async {
    try {
      await _service.bootstrapAuthSession();
      return const Result.ok(null);
    } on Exception catch (error) {
      return Result.error(error);
    }
  }

  @override
  Future<Result<PagedFinancialModel>> listFinancials(
    FinancialFilters filters,
  ) async {
    try {
      final authResult = await ensureAuthenticated();
      switch (authResult) {
        case Error<void>():
          return Result.error(authResult.error);
        case Ok<void>():
          break;
      }

      final model = await _service.listFinancials(filters);
      return Result.ok(model);
    } on Exception catch (error) {
      return Result.error(error);
    }
  }

  @override
  Future<Result<FinancialModel>> createFinancial(
    CreateFinancialInput input,
  ) async {
    try {
      final authResult = await ensureAuthenticated();
      switch (authResult) {
        case Error<void>():
          return Result.error(authResult.error);
        case Ok<void>():
          break;
      }

      final created = await _service.createFinancial(input);
      return Result.ok(created);
    } on Exception catch (error) {
      return Result.error(error);
    }
  }

  @override
  Future<Result<FinancialModel>> getFinancialById(String id) async {
    try {
      final authResult = await ensureAuthenticated();
      switch (authResult) {
        case Error<void>():
          return Result.error(authResult.error);
        case Ok<void>():
          break;
      }

      final financial = await _service.getFinancialById(id);
      return Result.ok(financial);
    } on Exception catch (error) {
      return Result.error(error);
    }
  }

  @override
  Future<Result<FinancialModel>> updateFinancialStatus(
    String id,
    FinancialStatus status,
  ) async {
    try {
      final authResult = await ensureAuthenticated();
      switch (authResult) {
        case Error<void>():
          return Result.error(authResult.error);
        case Ok<void>():
          break;
      }

      final updated = await _service.updateFinancialStatus(id, status);
      return Result.ok(updated);
    } on Exception catch (error) {
      return Result.error(error);
    }
  }
}
