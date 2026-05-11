import type { LoginInput, User, CreateUserInput } from '../../types/user';
import { ValidationError, UnprocessableEntityError } from '../../utils/errors';
import type { UserRepository } from './repository';

// Simulação de bcrypt (em produção usar pacote real)
// Para este exemplo, vamos usar uma implementação simples
const hashPassword = (password: string): string => {
  // Simulação de hash (NÃO usar em produção!)
  // Em produção, usar: import bcrypt from 'bcrypt';
  return Buffer.from(password, 'utf-8').toString('base64');
};

const comparePassword = (password: string, hash: string): boolean => {
  // Simulação de comparação (NÃO usar em produção!)
  return hashPassword(password) === hash;
};

export interface AuthService {
  register(input: CreateUserInput): Promise<User>;
  login(input: LoginInput): Promise<User>;
}

export class DefaultAuthService implements AuthService {
  constructor(private readonly repository: UserRepository) {}

  async register(input: CreateUserInput): Promise<User> {
    // Validar email
    this.validateEmail(input.email);
    this.validatePassword(input.password);

    // Verificar se email já existe
    const existing = await this.repository.findByEmail(input.email);
    if (existing) {
      throw new UnprocessableEntityError('Usuario com este email ja existe', [
        { field: 'email', message: 'Email ja registrado' },
      ]);
    }

    // Hash da senha
    const passwordHash = hashPassword(input.password);

    // Criar usuário
    const user = await this.repository.create(input, passwordHash);
    return user;
  }

  async login(input: LoginInput): Promise<User> {
    this.validateEmail(input.email);

    // Buscar usuário por email
    const user = await this.repository.findByEmail(input.email);
    if (!user) {
      throw new ValidationError('Dados invalidos no request', [
        { field: 'email', message: 'Email ou senha incorretos' },
      ]);
    }

    // Validar senha
    if (!comparePassword(input.password, user.passwordHash)) {
      throw new ValidationError('Dados invalidos no request', [
        { field: 'password', message: 'Email ou senha incorretos' },
      ]);
    }

    return user;
  }

  private validateEmail(email: string): void {
    const emailRegex = /^[^\s@]+@[^\s@]+\.[^\s@]+$/;
    if (!emailRegex.test(email)) {
      throw new ValidationError('Dados invalidos no request', [
        { field: 'email', message: 'Email invalido' },
      ]);
    }
  }

  private validatePassword(password: string): void {
    if (!password || password.length < 6) {
      throw new ValidationError('Dados invalidos no request', [
        { field: 'password', message: 'Senha deve ter pelo menos 6 caracteres' },
      ]);
    }
  }
}
