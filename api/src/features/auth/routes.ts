import type { FastifyInstance, FastifyReply, FastifyRequest } from 'fastify';
import type { SuccessResponse } from '../../types/api';
import type { UserResponse, CreateUserInput, LoginInput, User } from '../../types/user';
import { ValidationError } from '../../utils/errors';
import { InMemoryUserRepository } from './repository';
import { DefaultAuthService } from './service';

const repository = new InMemoryUserRepository();
const service = new DefaultAuthService(repository);

function toUserResponse(user: User): UserResponse {
  return {
    id: user.id,
    email: user.email,
    createdAt: user.createdAt.toISOString(),
  };
}

function parseRegisterInput(body: unknown): CreateUserInput {
  if (typeof body !== 'object' || body === null) {
    throw new ValidationError('Dados invalidos no request', [
      { message: 'Corpo da requisicao invalido' },
    ]);
  }

  const payload = body as Record<string, unknown>;
  const email = payload.email;
  const password = payload.password;

  if (typeof email !== 'string' || !email.trim()) {
    throw new ValidationError('Dados invalidos no request', [
      { field: 'email', message: 'Email obrigatorio' },
    ]);
  }

  if (typeof password !== 'string' || !password.trim()) {
    throw new ValidationError('Dados invalidos no request', [
      { field: 'password', message: 'Senha obrigatoria' },
    ]);
  }

  return {
    email: email.trim(),
    password: password.trim(),
  };
}

function parseLoginInput(body: unknown): LoginInput {
  return parseRegisterInput(body) as LoginInput;
}

export async function authRoutes(app: FastifyInstance): Promise<void> {
  app.post(
    '/register',
    {
      schema: {
        tags: ['auth'],
        summary: 'Registra um novo usuario',
        body: {
          type: 'object',
          properties: {
            email: { type: 'string', format: 'email' },
            password: { type: 'string', minLength: 6 },
          },
          required: ['email', 'password'],
        },
        response: {
          201: {
            type: 'object',
            properties: {
              success: { type: 'boolean' },
              data: {
                type: 'object',
                properties: {
                  id: { type: 'string' },
                  email: { type: 'string' },
                  createdAt: { type: 'string', format: 'date-time' },
                },
                required: ['id', 'email', 'createdAt'],
              },
              message: { type: 'string' },
            },
            required: ['success', 'data', 'message'],
          },
        },
      },
    },
    async (request: FastifyRequest, reply: FastifyReply) => {
      const input = parseRegisterInput(request.body);
      const user = await service.register(input);

      const response: SuccessResponse<UserResponse> = {
        success: true,
        data: toUserResponse(user),
        message: 'Usuario registrado com sucesso',
      };

      reply.code(201).send(response);
    },
  );

  app.post(
    '/login',
    {
      schema: {
        tags: ['auth'],
        summary: 'Faz login e retorna access token e refresh token',
        body: {
          type: 'object',
          properties: {
            email: { type: 'string', format: 'email' },
            password: { type: 'string' },
          },
          required: ['email', 'password'],
        },
        response: {
          200: {
            type: 'object',
            properties: {
              success: { type: 'boolean' },
              data: {
                type: 'object',
                properties: {
                  user: {
                    type: 'object',
                    properties: {
                      id: { type: 'string' },
                      email: { type: 'string' },
                      createdAt: { type: 'string', format: 'date-time' },
                    },
                    required: ['id', 'email', 'createdAt'],
                  },
                  accessToken: { type: 'string' },
                  refreshToken: { type: 'string' },
                  tokenType: { type: 'string' },
                },
                required: ['user', 'accessToken', 'refreshToken', 'tokenType'],
              },
              message: { type: 'string' },
            },
            required: ['success', 'data', 'message'],
          },
        },
      },
    },
    async (request: FastifyRequest, reply: FastifyReply) => {
      const input = parseLoginInput(request.body);
      const user = await service.login(input);

      // Gera tokens com userId (sub claim = user ID)
      const payload = { sub: user.id, type: 'access' as const };
      const accessToken = app.jwt.sign(payload, { expiresIn: '15m' });
      const refreshToken = app.jwt.sign(
        { sub: user.id, type: 'refresh' as const },
        { expiresIn: '7d' },
      );

      const response = {
        success: true,
        data: {
          user: toUserResponse(user),
          accessToken,
          refreshToken,
          tokenType: 'Bearer',
        },
        message: 'Login realizado com sucesso',
      };

      reply.send(response);
    },
  );
}
