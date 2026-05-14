import type { FastifyInstance } from 'fastify';
import { authenticate } from '../../middleware/auth';
import { FinancialController } from './controller';
import { InMemoryFinancialRepository } from './repository';
import { DefaultFinancialService } from './service';

const repository = new InMemoryFinancialRepository();
const service = new DefaultFinancialService(repository);
const controller = new FinancialController(service);

export async function financialRoutes(app: FastifyInstance): Promise<void> {
  const financialSchema = {
    type: 'object',
    properties: {
      id: { type: 'string' },
      userId: { type: 'string' },
      description: { type: 'string' },
      amount: { type: 'number' },
      type: { type: 'string', enum: ['INCOME', 'EXPENSE'] },
      category: { type: 'string' },
      status: { type: 'string', enum: ['PENDING', 'COMPLETED', 'CANCELLED'] },
      date: { type: 'string', format: 'date-time' },
      notes: { type: 'string', nullable: true },
      createdAt: { type: 'string', format: 'date-time' },
      updatedAt: { type: 'string', format: 'date-time' },
    },
    required: [
      'id',
      'userId',
      'description',
      'amount',
      'type',
      'category',
      'status',
      'date',
      'createdAt',
      'updatedAt',
    ],
  } as const;

  app.post('/financial', {
    preHandler: authenticate,
    schema: {
      tags: ['financial'],
      summary: 'Cria um lancamento financeiro',
      security: [{ bearerAuth: [] }],
      body: {
        type: 'object',
        properties: {
          description: { type: 'string', maxLength: 255 },
          amount: { type: 'number', minimum: 0.01 },
          type: { type: 'string', enum: ['INCOME', 'EXPENSE'] },
          category: { type: 'string' },
          // Date parsing/validation is handled in parseCreateFinancialInput.
          date: { type: 'string' },
          notes: { type: 'string', maxLength: 500, nullable: true },
        },
        required: ['description', 'amount', 'type', 'category', 'date'],
      },
      response: {
        201: {
          type: 'object',
          properties: {
            success: { type: 'boolean' },
            data: financialSchema,
            message: { type: 'string' },
          },
          required: ['success', 'data', 'message'],
        },
      },
    },
  }, async (request, reply) => {
    await controller.create(request, reply);
  });

  app.get('/financial', {
    preHandler: authenticate,
    schema: {
      tags: ['financial'],
      summary: 'Lista lancamentos com paginacao e filtros',
      security: [{ bearerAuth: [] }],
      querystring: {
        type: 'object',
        properties: {
          page: { type: 'integer', minimum: 1, default: 1 },
          limit: { type: 'integer', minimum: 1, maximum: 100, default: 10 },
          status: { type: 'string', enum: ['PENDING', 'COMPLETED', 'CANCELLED'] },
          type: { type: 'string', enum: ['INCOME', 'EXPENSE'] },
          // Date parsing/validation is handled in parseListFinancialFilters.
          startDate: { type: 'string' },
          endDate: { type: 'string' },
          sortBy: { type: 'string', enum: ['date', 'amount', 'description'], default: 'date' },
          order: { type: 'string', enum: ['ASC', 'DESC'], default: 'DESC' },
        },
      },
      response: {
        200: {
          type: 'object',
          properties: {
            success: { type: 'boolean' },
            data: {
              type: 'array',
              items: financialSchema,
            },
            pagination: {
              type: 'object',
              properties: {
                page: { type: 'integer' },
                limit: { type: 'integer' },
                total: { type: 'integer' },
                totalPages: { type: 'integer' },
                hasNextPage: { type: 'boolean' },
                hasPreviousPage: { type: 'boolean' },
              },
              required: ['page', 'limit', 'total', 'totalPages', 'hasNextPage', 'hasPreviousPage'],
            },
            message: { type: 'string' },
          },
          required: ['success', 'data', 'pagination', 'message'],
        },
      },
    },
  }, async (request, reply) => {
    await controller.list(request, reply);
  });

  app.get('/financial/:id', {
    preHandler: authenticate,
    schema: {
      tags: ['financial'],
      summary: 'Retorna detalhes de um lancamento',
      security: [{ bearerAuth: [] }],
      params: {
        type: 'object',
        properties: {
          id: { type: 'string', format: 'uuid' },
        },
        required: ['id'],
      },
      response: {
        200: {
          type: 'object',
          properties: {
            success: { type: 'boolean' },
            data: financialSchema,
            message: { type: 'string' },
          },
          required: ['success', 'data', 'message'],
        },
      },
    },
  }, async (request, reply) => {
    await controller.getById(request, reply);
  });

  app.patch('/financial/:id/status', {
    preHandler: authenticate,
    schema: {
      tags: ['financial'],
      summary: 'Atualiza status de um lancamento',
      security: [{ bearerAuth: [] }],
      params: {
        type: 'object',
        properties: {
          id: { type: 'string', format: 'uuid' },
        },
        required: ['id'],
      },
      body: {
        type: 'object',
        properties: {
          status: { type: 'string', enum: ['PENDING', 'COMPLETED', 'CANCELLED'] },
        },
        required: ['status'],
      },
      response: {
        200: {
          type: 'object',
          properties: {
            success: { type: 'boolean' },
            data: financialSchema,
            message: { type: 'string' },
          },
          required: ['success', 'data', 'message'],
        },
      },
    },
  }, async (request, reply) => {
    await controller.updateStatus(request, reply);
  });
}
