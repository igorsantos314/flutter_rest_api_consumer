import { randomUUID } from 'node:crypto';
import type {
  CreateFinancialInput,
  Financial,
  FinancialStatus,
  ListFinancialFilters,
  PaginatedResult,
} from '../../types/financial';

export interface FinancialRepository {
  create(userId: string, input: CreateFinancialInput): Promise<Financial>;
  list(userId: string, filters: ListFinancialFilters): Promise<PaginatedResult<Financial>>;
  getById(userId: string, id: string): Promise<Financial | null>;
  updateStatus(userId: string, id: string, status: FinancialStatus): Promise<Financial | null>;
}

const defaultSort = { sortBy: 'date' as const, order: 'DESC' as const };

export class InMemoryFinancialRepository implements FinancialRepository {
  private readonly items: Financial[] = [];

  async create(userId: string, input: CreateFinancialInput): Promise<Financial> {
    const now = new Date();
    const created: Financial = {
      id: randomUUID(),
      userId,
      description: input.description,
      amount: input.amount,
      type: input.type,
      category: input.category,
      status: 'PENDING',
      date: new Date(input.date),
      notes: input.notes,
      createdAt: now,
      updatedAt: now,
    };

    this.items.push(created);
    return created;
  }

  async list(userId: string, filters: ListFinancialFilters): Promise<PaginatedResult<Financial>> {
    const page = filters.page ?? 1;
    const limit = filters.limit ?? 10;
    const sortBy = filters.sortBy ?? defaultSort.sortBy;
    const order = filters.order ?? defaultSort.order;

    const startDate = filters.startDate ? new Date(filters.startDate) : null;
    const endDate = filters.endDate ? new Date(filters.endDate) : null;

    const filtered = this.items.filter((item) => {
      if (item.userId !== userId) return false;
      if (filters.status && item.status !== filters.status) return false;
      if (filters.type && item.type !== filters.type) return false;
      if (startDate && item.date < startDate) return false;
      if (endDate && item.date > endDate) return false;
      return true;
    });

    filtered.sort((a, b) => {
      const left =
        sortBy === 'date'
          ? a.date
          : sortBy === 'amount'
            ? a.amount
            : a.description;
      const right =
        sortBy === 'date'
          ? b.date
          : sortBy === 'amount'
            ? b.amount
            : b.description;
      const result =
        left instanceof Date && right instanceof Date
          ? left.getTime() - right.getTime()
          : typeof left === 'number' && typeof right === 'number'
            ? left - right
            : String(left).localeCompare(String(right), 'pt-BR', { sensitivity: 'base' });

      return order === 'ASC' ? result : -result;
    });

    const offset = (page - 1) * limit;
    const paged = filtered.slice(offset, offset + limit);
    const total = filtered.length;
    const totalPages = total === 0 ? 0 : Math.ceil(total / limit);

    return {
      items: paged,
      page,
      limit,
      total,
      totalPages,
      hasNextPage: page < totalPages,
      hasPreviousPage: page > 1 && totalPages > 0,
    };
  }

  async getById(userId: string, id: string): Promise<Financial | null> {
    return this.items.find((item) => item.id === id && item.userId === userId) ?? null;
  }

  async updateStatus(userId: string, id: string, status: FinancialStatus): Promise<Financial | null> {
    const index = this.items.findIndex((item) => item.id === id && item.userId === userId);
    if (index < 0) return null;

    const current = this.items.at(index);
    if (!current) return null;

    const updated: Financial = {
      ...current,
      status,
      updatedAt: new Date(),
    };

    this.items.splice(index, 1, updated);
    return updated;
  }
}
