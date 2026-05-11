enum FinancialType { income, expense }

enum FinancialStatus { pending, completed, cancelled }

class FinancialModel {
  const FinancialModel({
    required this.id,
    required this.description,
    required this.amount,
    required this.type,
    required this.category,
    required this.status,
    required this.date,
    this.notes,
    required this.createdAt,
    required this.updatedAt,
  });

  final String id;
  final String description;
  final double amount;
  final FinancialType type;
  final String category;
  final FinancialStatus status;
  final DateTime date;
  final String? notes;
  final DateTime createdAt;
  final DateTime updatedAt;
}

class PaginationModel {
  const PaginationModel({
    required this.page,
    required this.limit,
    required this.total,
    required this.totalPages,
    required this.hasNextPage,
    required this.hasPreviousPage,
  });

  final int page;
  final int limit;
  final int total;
  final int totalPages;
  final bool hasNextPage;
  final bool hasPreviousPage;
}

class PagedFinancialModel {
  const PagedFinancialModel({required this.items, required this.pagination});

  final List<FinancialModel> items;
  final PaginationModel pagination;
}

class FinancialFilters {
  const FinancialFilters({
    this.page = 1,
    this.limit = 10,
    this.status,
    this.type,
    this.startDate,
    this.endDate,
    this.sortBy = 'date',
    this.order = 'DESC',
  });

  final int page;
  final int limit;
  final FinancialStatus? status;
  final FinancialType? type;
  final DateTime? startDate;
  final DateTime? endDate;
  final String sortBy;
  final String order;

  FinancialFilters copyWith({
    int? page,
    int? limit,
    FinancialStatus? status,
    bool clearStatus = false,
    FinancialType? type,
    bool clearType = false,
    DateTime? startDate,
    bool clearStartDate = false,
    DateTime? endDate,
    bool clearEndDate = false,
    String? sortBy,
    String? order,
  }) {
    return FinancialFilters(
      page: page ?? this.page,
      limit: limit ?? this.limit,
      status: clearStatus ? null : (status ?? this.status),
      type: clearType ? null : (type ?? this.type),
      startDate: clearStartDate ? null : (startDate ?? this.startDate),
      endDate: clearEndDate ? null : (endDate ?? this.endDate),
      sortBy: sortBy ?? this.sortBy,
      order: order ?? this.order,
    );
  }
}

class CreateFinancialInput {
  const CreateFinancialInput({
    required this.description,
    required this.amount,
    required this.type,
    required this.category,
    required this.date,
    this.notes,
  });

  final String description;
  final double amount;
  final FinancialType type;
  final String category;
  final DateTime date;
  final String? notes;
}
