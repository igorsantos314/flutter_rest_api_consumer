/// Tipo para usuário no banco de dados
export interface User {
  id: string;
  email: string;
  passwordHash: string; // Nunca retornar nos responses
  createdAt: Date;
  updatedAt: Date;
}

/// Tipo para criar usuário
export interface CreateUserInput {
  email: string;
  password: string;
}

/// Tipo para login
export interface LoginInput {
  email: string;
  password: string;
}

/// Resposta de login/registro (sem senha)
export interface UserResponse {
  id: string;
  email: string;
  createdAt: string;
}
