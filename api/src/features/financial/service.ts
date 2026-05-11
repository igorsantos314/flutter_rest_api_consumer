import { NotFoundError, UnprocessableEntityError } from '../../utils/errors';
import type {
  CreateFinancialInput,
  Financial,
  FinancialStatus,
  ListFinancialFilters,
  PaginatedResult,
} from '../../types/financial';
import type { FinancialRepository } from './repository';

const validTransitions: Record<FinancialStatus, FinancialStatus[]> = {
  PENDING: ['COMPLETED', 'CANCELLED'],
  COMPLETED: [],
  CANCELLED: [],
};

export interface FinancialService {
  createFinancial(userId: string, input: CreateFinancialInput): Promise<Financial>;
  listFinancial(userId: string, filters: ListFinancialFilters): Promise<PaginatedResult<Financial>>;
  getFinancialById(userId: string, id: string): Promise<Financial>;
  updateFinancialStatus(userId: string, id: string, status: FinancialStatus): Promise<Financial>;
}

export class DefaultFinancialService implements FinancialService {
  constructor(private readonly repository: FinancialRepository) {}

  async createFinancial(userId: string, input: CreateFinancialInput): Promise<Financial> {
    return this.repository.create(userId, input);
  }

  async listFinancial(userId: string, filters: ListFinancialFilters): Promise<PaginatedResult<Financial>> {
    return this.repository.list(userId, filters);
  }

  async getFinancialById(userId: string, id: string): Promise<Financial> {
    const financial = await this.repository.getById(userId, id);
    if (!financial) {
      throw new NotFoundError('Lancamento nao encontrado');
    }

    return financial;
  }

  async updateFinancialStatus(userId: string, id: string, status: FinancialStatus): Promise<Financial> {
    const existing = await this.repository.getById(userId, id);
    if (!existing) {
      throw new NotFoundError('Lancamento nao encontrado');
    }

    if (existing.status === status) {
      return existing;
    }

    const allowed = validTransitions[existing.status];
    if (!allowed.includes(status)) {
      throw new UnprocessableEntityError('Transicao de status invalida', [
        {
          field: 'status',
          message: `Nao permitido transitar de ${existing.status} para ${status}`,
        },
      ]);
    }

    const updated = await this.repository.updateStatus(userId, id, status);
    if (!updated) {
      throw new NotFoundError('Lancamento nao encontrado');
    }

    return updated;
  }
}
