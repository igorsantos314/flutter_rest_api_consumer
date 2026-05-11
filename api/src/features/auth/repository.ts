import { randomUUID } from 'node:crypto';
import type { CreateUserInput, User } from '../../types/user';

export interface UserRepository {
  create(input: CreateUserInput, passwordHash: string): Promise<User>;
  findByEmail(email: string): Promise<User | null>;
  findById(id: string): Promise<User | null>;
}

/// Implementação em memória de UserRepository
export class InMemoryUserRepository implements UserRepository {
  private readonly items: User[] = [];

  async create(input: CreateUserInput, passwordHash: string): Promise<User> {
    const now = new Date();
    const user: User = {
      id: randomUUID(),
      email: input.email,
      passwordHash,
      createdAt: now,
      updatedAt: now,
    };

    this.items.push(user);
    return user;
  }

  async findByEmail(email: string): Promise<User | null> {
    return this.items.find((user) => user.email === email) ?? null;
  }

  async findById(id: string): Promise<User | null> {
    return this.items.find((user) => user.id === id) ?? null;
  }
}
