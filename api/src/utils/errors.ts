import type { ErrorDetail } from '../types/api';

export class AppError extends Error {
  constructor(
    public readonly statusCode: number,
    public readonly code: string,
    message: string,
    public readonly details?: ErrorDetail[],
  ) {
    super(message);
  }
}

export class ValidationError extends AppError {
  constructor(message: string, details?: ErrorDetail[]) {
    super(400, 'VALIDATION_ERROR', message, details);
  }
}

export class UnauthorizedError extends AppError {
  constructor(message = 'Token ausente ou invalido') {
    super(401, 'UNAUTHORIZED', message);
  }
}

export class NotFoundError extends AppError {
  constructor(message = 'Recurso nao encontrado') {
    super(404, 'NOT_FOUND', message);
  }
}

export class UnprocessableEntityError extends AppError {
  constructor(message: string, details?: ErrorDetail[]) {
    super(422, 'UNPROCESSABLE_ENTITY', message, details);
  }
}
