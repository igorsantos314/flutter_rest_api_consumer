import type { FastifyReply, FastifyRequest } from 'fastify';
import type { SuccessResponse } from '../../types/api';
import type { Financial } from '../../types/financial';
import { UnauthorizedError } from '../../utils/errors';
import {
  parseCreateFinancialInput,
  parseListFinancialFilters,
  parseUpdateStatusInput,
  validateFinancialId,
} from './schemas';
import type { FinancialService } from './service';

function toFinancialResponse(financial: Financial) {
  return {
    ...financial,
    date: financial.date.toISOString(),
    createdAt: financial.createdAt.toISOString(),
    updatedAt: financial.updatedAt.toISOString(),
  };
}

export class FinancialController {
  constructor(private readonly service: FinancialService) {}

  async create(request: FastifyRequest, reply: FastifyReply): Promise<void> {
    const userId = request.user?.sub;
    if (!userId) throw new UnauthorizedError();

    const input = parseCreateFinancialInput(request.body);
    const created = await this.service.createFinancial(userId, input);

    const response: SuccessResponse<ReturnType<typeof toFinancialResponse>> = {
      success: true,
      data: toFinancialResponse(created),
      message: 'Lancamento criado com sucesso',
    };

    reply.code(201).send(response);
  }

  async list(request: FastifyRequest, reply: FastifyReply): Promise<void> {
    const userId = request.user?.sub;
    if (!userId) throw new UnauthorizedError();

    const filters = parseListFinancialFilters(request.query);
    const paged = await this.service.listFinancial(userId, filters);

    const response = {
      success: true,
      data: paged.items.map(toFinancialResponse),
      pagination: {
        page: paged.page,
        limit: paged.limit,
        total: paged.total,
        totalPages: paged.totalPages,
        hasNextPage: paged.hasNextPage,
        hasPreviousPage: paged.hasPreviousPage,
      },
      message: 'Operacao concluida com sucesso',
    };

    reply.send(response);
  }

  async getById(request: FastifyRequest, reply: FastifyReply): Promise<void> {
    const userId = request.user?.sub;
    if (!userId) throw new UnauthorizedError();

    const params = request.params as { id?: unknown };
    const id = validateFinancialId(params.id);

    const financial = await this.service.getFinancialById(userId, id);

    const response: SuccessResponse<ReturnType<typeof toFinancialResponse>> = {
      success: true,
      data: toFinancialResponse(financial),
      message: 'Operacao concluida com sucesso',
    };

    reply.send(response);
  }

  async updateStatus(request: FastifyRequest, reply: FastifyReply): Promise<void> {
    const userId = request.user?.sub;
    if (!userId) throw new UnauthorizedError();

    const params = request.params as { id?: unknown };
    const id = validateFinancialId(params.id);
    const status = parseUpdateStatusInput(request.body);

    const financial = await this.service.updateFinancialStatus(userId, id, status);

    const response: SuccessResponse<ReturnType<typeof toFinancialResponse>> = {
      success: true,
      data: toFinancialResponse(financial),
      message: 'Status atualizado com sucesso',
    };

    reply.send(response);
  }
}
