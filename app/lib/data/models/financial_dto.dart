import 'package:flutter_rest_api_consumer/domain/models/financial_model.dart';

FinancialType financialTypeFromApi(String value) {
  switch (value) {
    case 'INCOME':
      return FinancialType.income;
    case 'EXPENSE':
      return FinancialType.expense;
    default:
      throw FormatException('Tipo financeiro invalido: $value');
  }
}

String financialTypeToApi(FinancialType type) {
  switch (type) {
    case FinancialType.income:
      return 'INCOME';
    case FinancialType.expense:
      return 'EXPENSE';
  }
}

FinancialStatus financialStatusFromApi(String value) {
  switch (value) {
    case 'PENDING':
      return FinancialStatus.pending;
    case 'COMPLETED':
      return FinancialStatus.completed;
    case 'CANCELLED':
      return FinancialStatus.cancelled;
    default:
      throw FormatException('Status financeiro invalido: $value');
  }
}

String financialStatusToApi(FinancialStatus status) {
  switch (status) {
    case FinancialStatus.pending:
      return 'PENDING';
    case FinancialStatus.completed:
      return 'COMPLETED';
    case FinancialStatus.cancelled:
      return 'CANCELLED';
  }
}

class FinancialDto {
  const FinancialDto({
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
  final String type;
  final String category;
  final String status;
  final String date;
  final String? notes;
  final String createdAt;
  final String updatedAt;

  factory FinancialDto.fromJson(Map<String, dynamic> json) {
    return FinancialDto(
      id: json['id'] as String,
      description: json['description'] as String,
      amount: (json['amount'] as num).toDouble(),
      type: json['type'] as String,
      category: json['category'] as String,
      status: json['status'] as String,
      date: json['date'] as String,
      notes: json['notes'] as String?,
      createdAt: json['createdAt'] as String,
      updatedAt: json['updatedAt'] as String,
    );
  }

  FinancialModel toDomain() {
    return FinancialModel(
      id: id,
      description: description,
      amount: amount,
      type: financialTypeFromApi(type),
      category: category,
      status: financialStatusFromApi(status),
      date: DateTime.parse(date),
      notes: notes,
      createdAt: DateTime.parse(createdAt),
      updatedAt: DateTime.parse(updatedAt),
    );
  }
}

class PagedFinancialDto {
  const PagedFinancialDto({required this.items, required this.pagination});

  final List<FinancialDto> items;
  final PaginationModel pagination;

  factory PagedFinancialDto.fromJson(Map<String, dynamic> json) {
    final list = (json['data'] as List<dynamic>)
        .cast<Map<String, dynamic>>()
        .map(FinancialDto.fromJson)
        .toList();

    final paginationJson = json['pagination'] as Map<String, dynamic>;
    final pagination = PaginationModel(
      page: paginationJson['page'] as int,
      limit: paginationJson['limit'] as int,
      total: paginationJson['total'] as int,
      totalPages: paginationJson['totalPages'] as int,
      hasNextPage: paginationJson['hasNextPage'] as bool,
      hasPreviousPage: paginationJson['hasPreviousPage'] as bool,
    );

    return PagedFinancialDto(items: list, pagination: pagination);
  }

  PagedFinancialModel toDomain() {
    return PagedFinancialModel(
      items: items.map((item) => item.toDomain()).toList(),
      pagination: pagination,
    );
  }
}
