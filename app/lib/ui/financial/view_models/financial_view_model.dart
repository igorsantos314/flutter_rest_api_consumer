import 'package:flutter/foundation.dart';
import 'package:flutter_rest_api_consumer/domain/models/financial_model.dart';
import 'package:flutter_rest_api_consumer/domain/repositories/financial_repository.dart';
import 'package:flutter_rest_api_consumer/utils/command.dart';
import 'package:flutter_rest_api_consumer/utils/result.dart';

class FinancialViewModel extends ChangeNotifier {
  FinancialViewModel({required FinancialRepository repository})
    : _repository = repository {
    loadFinancials = Command0<PagedFinancialModel>(_loadFinancials);
    createFinancial = Command1<FinancialModel, CreateFinancialInput>(
      _createFinancial,
    );
    updateStatus = Command1<FinancialModel, (String, FinancialStatus)>(
      _updateStatus,
    );
  }

  final FinancialRepository _repository;

  late final Command0<PagedFinancialModel> loadFinancials;
  late final Command1<FinancialModel, CreateFinancialInput> createFinancial;
  late final Command1<FinancialModel, (String, FinancialStatus)> updateStatus;

  FinancialFilters _filters = const FinancialFilters();
  List<FinancialModel> _items = const [];
  PaginationModel _pagination = const PaginationModel(
    page: 1,
    limit: 10,
    total: 0,
    totalPages: 0,
    hasNextPage: false,
    hasPreviousPage: false,
  );

  FinancialFilters get filters => _filters;
  List<FinancialModel> get items => _items;
  PaginationModel get pagination => _pagination;
  bool get hasData => _items.isNotEmpty;

  Future<Result<PagedFinancialModel>> _loadFinancials() async {
    final result = await _repository.listFinancials(_filters);
    switch (result) {
      case Ok<PagedFinancialModel>():
        _items = result.value.items;
        _pagination = result.value.pagination;
        notifyListeners();
        return Result.ok(result.value);
      case Error<PagedFinancialModel>():
        return Result.error(result.error);
    }
  }

  Future<Result<FinancialModel>> _createFinancial(
    CreateFinancialInput input,
  ) async {
    final result = await _repository.createFinancial(input);
    switch (result) {
      case Ok<FinancialModel>():
        await loadFinancials.execute();
        notifyListeners(); // Notify listeners on success
        return Result.ok(result.value);
      case Error<FinancialModel>():
        notifyListeners(); // Notify listeners on failure
        return Result.error(result.error);
    }
  }

  Future<Result<FinancialModel>> _updateStatus(
    (String, FinancialStatus) params,
  ) async {
    final (id, status) = params;
    final result = await _repository.updateFinancialStatus(id, status);
    switch (result) {
      case Ok<FinancialModel>():
        final updatedItems = [..._items];
        final index = updatedItems.indexWhere((item) => item.id == id);
        if (index >= 0) {
          updatedItems[index] = result.value;
          _items = updatedItems;
          notifyListeners();
        }
        return Result.ok(result.value);
      case Error<FinancialModel>():
        return Result.error(result.error);
    }
  }

  Future<void> refresh() async {
    await loadFinancials.execute();
  }

  Future<void> setStatus(FinancialStatus? status) async {
    _filters = _filters.copyWith(
      page: 1,
      status: status,
      clearStatus: status == null,
    );
    notifyListeners();
    await loadFinancials.execute();
  }

  Future<void> setPage(int page) async {
    if (page <= 0 || page == _filters.page) {
      return;
    }

    _filters = _filters.copyWith(page: page);
    notifyListeners();
    await loadFinancials.execute();
  }

  Future<void> nextPage() async {
    if (!_pagination.hasNextPage) {
      return;
    }
    await setPage(_pagination.page + 1);
  }

  Future<void> previousPage() async {
    if (!_pagination.hasPreviousPage) {
      return;
    }
    await setPage(_pagination.page - 1);
  }

  @override
  void dispose() {
    loadFinancials.dispose();
    createFinancial.dispose();
    updateStatus.dispose();
    super.dispose();
  }
}
