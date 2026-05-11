import type { FastifyReply, FastifyRequest } from 'fastify';

/// Middleware de autenticação que valida JWT
/// Regra: Token deve ser access token (type = 'access')
/// O userId fica em request.user.sub
export async function authenticate(request: FastifyRequest, reply: FastifyReply): Promise<void> {
  try {
    await request.jwtVerify();
    // Valida que é um access token (não refresh token)
    if (request.user.type !== 'access') {
      throw new Error('Invalid token type');
    }
  } catch {
    reply.code(401).send({
      success: false,
      error: {
        code: 'UNAUTHORIZED',
        message: 'Token ausente ou invalido',
      },
    });
  }
}
