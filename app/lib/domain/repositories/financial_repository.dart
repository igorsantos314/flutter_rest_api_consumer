import 'package:flutter_rest_api_consumer/domain/models/financial_model.dart';
import 'package:flutter_rest_api_consumer/utils/result.dart';

abstract class FinancialRepository {
  Future<Result<PagedFinancialModel>> listFinancials(FinancialFilters filters);

  Future<Result<FinancialModel>> createFinancial(CreateFinancialInput input);

  Future<Result<FinancialModel>> getFinancialById(String id);

  Future<Result<FinancialModel>> updateFinancialStatus(
    String id,
    FinancialStatus status,
  );
}
