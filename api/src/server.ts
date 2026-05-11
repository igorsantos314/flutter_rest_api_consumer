import Fastify from 'fastify';
import fastifyJwt from '@fastify/jwt';
import fastifySwagger from '@fastify/swagger';
import fastifySwaggerUi from '@fastify/swagger-ui';
import { financialRoutes } from './features/financial/routes';
import { AppError } from './utils/errors';

export function buildServer() {
  const app = Fastify({ logger: true });

  app.register(fastifySwagger, {
    openapi: {
      info: {
        title: 'Financial API',
        description: 'API REST para gestao de lancamentos financeiros',
        version: '1.0.0',
      },
      servers: [{ url: 'http://localhost:3000' }],
      tags: [{ name: 'auth' }, { name: 'financial' }],
      components: {
        securitySchemes: {
          bearerAuth: {
            type: 'http',
            scheme: 'bearer',
            bearerFormat: 'JWT',
          },
        },
      },
    },
  });

  app.register(fastifySwaggerUi, {
    routePrefix: '/docs',
  });

  app.register(fastifyJwt, {
    secret: process.env.JWT_SECRET ?? 'dev-secret',
  });

  app.setErrorHandler((error, _request, reply) => {
    if (error instanceof AppError) {
      reply.code(error.statusCode).send({
        success: false,
        error: {
          code: error.code,
          message: error.message,
          details: error.details,
        },
      });
      return;
    }

    app.log.error(error);
    reply.code(500).send({
      success: false,
      error: {
        code: 'INTERNAL_SERVER_ERROR',
        message: 'Erro interno no servidor',
      },
    });
  });

  app.get('/health', async () => ({ success: true }));

  app.get(
    '/api/v1/auth/dev-token',
    {
      schema: {
        tags: ['auth'],
        summary: 'Gera access token e refresh token para ambiente local',
        response: {
          200: {
            type: 'object',
            properties: {
              success: { type: 'boolean' },
              data: {
                type: 'object',
                properties: {
                  accessToken: { type: 'string' },
                  refreshToken: { type: 'string' },
                  tokenType: { type: 'string' },
                },
                required: ['accessToken', 'refreshToken', 'tokenType'],
              },
              message: { type: 'string' },
            },
            required: ['success', 'data', 'message'],
          },
        },
      },
    },
    async () => {
      const payload = { sub: 'dev-user', type: 'access' as const };
      const accessToken = app.jwt.sign(payload, { expiresIn: '15m' });
      const refreshToken = app.jwt.sign({ sub: 'dev-user', type: 'refresh' as const }, { expiresIn: '7d' });

      return {
        success: true,
        data: { accessToken, refreshToken, tokenType: 'Bearer' },
        message: 'Token gerado com sucesso',
      };
    },
  );

  app.post(
    '/api/v1/auth/refresh',
    {
      schema: {
        tags: ['auth'],
        summary: 'Renova access token usando refresh token',
        body: {
          type: 'object',
          properties: {
            refreshToken: { type: 'string' },
          },
          required: ['refreshToken'],
        },
        response: {
          200: {
            type: 'object',
            properties: {
              success: { type: 'boolean' },
              data: {
                type: 'object',
                properties: {
                  accessToken: { type: 'string' },
                  tokenType: { type: 'string' },
                },
                required: ['accessToken', 'tokenType'],
              },
              message: { type: 'string' },
            },
            required: ['success', 'data', 'message'],
          },
          401: {
            type: 'object',
            properties: {
              success: { type: 'boolean' },
              error: {
                type: 'object',
                properties: {
                  code: { type: 'string' },
                  message: { type: 'string' },
                },
                required: ['code', 'message'],
              },
            },
            required: ['success', 'error'],
          },
        },
      },
    },
    async (request, reply) => {
      const body = request.body as { refreshToken?: unknown };
      if (typeof body?.refreshToken !== 'string') {
        reply.code(401).send({
          success: false,
          error: {
            code: 'UNAUTHORIZED',
            message: 'Refresh token invalido',
          },
        });
        return;
      }

      try {
        const payload = await app.jwt.verify<{ sub: string; type: 'access' | 'refresh' }>(body.refreshToken);
        if (payload.type !== 'refresh') {
          throw new Error('Invalid token type');
        }

        const accessToken = app.jwt.sign({ sub: payload.sub, type: 'access' }, { expiresIn: '15m' });

        reply.send({
          success: true,
          data: { accessToken, tokenType: 'Bearer' },
          message: 'Token renovado com sucesso',
        });
      } catch {
        reply.code(401).send({
          success: false,
          error: {
            code: 'UNAUTHORIZED',
            message: 'Refresh token invalido',
          },
        });
      }
    },
  );

  app.get('/docs/json', async () => app.swagger());

  app.register(financialRoutes, { prefix: '/api/v1' });

  return app;
}

async function start() {
  const app = buildServer();

  const port = Number(process.env.PORT ?? 3000);
  const host = process.env.HOST ?? '0.0.0.0';

  try {
    await app.listen({ port, host });
  } catch (error) {
    app.log.error(error);
    process.exit(1);
  }
}

void start();
