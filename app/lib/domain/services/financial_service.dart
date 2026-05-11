import 'package:flutter_rest_api_consumer/domain/models/financial_model.dart';

abstract class FinancialService {
  Future<void> bootstrapAuthSession();

  Future<PagedFinancialModel> listFinancials(FinancialFilters filters);

  Future<FinancialModel> createFinancial(CreateFinancialInput input);

  Future<FinancialModel> getFinancialById(String id);

  Future<FinancialModel> updateFinancialStatus(
    String id,
    FinancialStatus status,
  );
}
