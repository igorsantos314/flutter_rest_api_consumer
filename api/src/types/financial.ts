export const financialTypes = ['INCOME', 'EXPENSE'] as const;
export type FinancialType = (typeof financialTypes)[number];

export const financialStatuses = ['PENDING', 'COMPLETED', 'CANCELLED'] as const;
export type FinancialStatus = (typeof financialStatuses)[number];

export const sortableFields = ['date', 'amount', 'description'] as const;
export type SortableField = (typeof sortableFields)[number];

export type SortOrder = 'ASC' | 'DESC';

export interface Financial {
  id: string;
  userId: string;
  description: string;
  amount: number;
  type: FinancialType;
  category: string;
  status: FinancialStatus;
  date: Date;
  notes?: string;
  createdAt: Date;
  updatedAt: Date;
}

export interface CreateFinancialInput {
  description: string;
  amount: number;
  type: FinancialType;
  category: string;
  date: string;
  notes?: string;
}

export interface ListFinancialFilters {
  page?: number;
  limit?: number;
  status?: FinancialStatus;
  type?: FinancialType;
  startDate?: string;
  endDate?: string;
  sortBy?: SortableField;
  order?: SortOrder;
}

export interface PaginatedResult<T> {
  items: T[];
  page: number;
  limit: number;
  total: number;
  totalPages: number;
  hasNextPage: boolean;
  hasPreviousPage: boolean;
}
