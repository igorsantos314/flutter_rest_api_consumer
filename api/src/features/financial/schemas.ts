import { ValidationError } from '../../utils/errors';
import {
  financialStatuses,
  financialTypes,
  sortableFields,
  type CreateFinancialInput,
  type FinancialStatus,
  type ListFinancialFilters,
  type SortOrder,
  type SortableField,
} from '../../types/financial';

const uuidV4Regex =
  /^[0-9a-f]{8}-[0-9a-f]{4}-[1-5][0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$/i;

function asString(value: unknown): string | null {
  if (typeof value !== 'string') return null;
  const trimmed = value.trim();
  return trimmed.length > 0 ? trimmed : null;
}

function parseDate(value: string, field: string): Date {
  const parsed = new Date(value);
  if (Number.isNaN(parsed.getTime())) {
    throw new ValidationError('Dados invalidos no request', [{ field, message: 'Data invalida' }]);
  }

  return parsed;
}

function parsePositiveNumber(value: unknown, field: string): number {
  if (typeof value !== 'number' || !Number.isFinite(value)) {
    throw new ValidationError('Dados invalidos no request', [{ field, message: 'Valor deve ser numerico' }]);
  }

  if (value <= 0) {
    throw new ValidationError('Dados invalidos no request', [{ field, message: 'Deve ser maior que zero' }]);
  }

  const decimalPlaces = (value.toString().split('.')[1] ?? '').length;
  if (decimalPlaces > 2) {
    throw new ValidationError('Dados invalidos no request', [
      { field, message: 'Aceita no maximo 2 casas decimais' },
    ]);
  }

  return value;
}

function ensureEnum<T extends readonly string[]>(
  value: unknown,
  values: T,
  field: string,
): T[number] {
  if (typeof value !== 'string' || !values.includes(value)) {
    throw new ValidationError('Dados invalidos no request', [
      { field, message: `Valor deve ser um de: ${values.join(', ')}` },
    ]);
  }

  return value;
}

export function validateFinancialId(id: unknown): string {
  if (typeof id !== 'string' || !uuidV4Regex.test(id)) {
    throw new ValidationError('Dados invalidos no request', [{ field: 'id', message: 'UUID invalido' }]);
  }

  return id;
}

export function parseCreateFinancialInput(body: unknown): CreateFinancialInput {
  if (typeof body !== 'object' || body === null) {
    throw new ValidationError('Dados invalidos no request', [{ message: 'Corpo da requisicao invalido' }]);
  }

  const payload = body as Record<string, unknown>;
  const description = asString(payload.description);
  if (!description) {
    throw new ValidationError('Dados invalidos no request', [
      { field: 'description', message: 'Descricao obrigatoria' },
    ]);
  }

  if (description.length > 255) {
    throw new ValidationError('Dados invalidos no request', [
      { field: 'description', message: 'Descricao excede 255 caracteres' },
    ]);
  }

  const category = asString(payload.category);
  if (!category) {
    throw new ValidationError('Dados invalidos no request', [
      { field: 'category', message: 'Categoria obrigatoria' },
    ]);
  }

  const notesRaw = payload.notes;
  const notes = typeof notesRaw === 'string' ? notesRaw.trim() : undefined;
  if (notes && notes.length > 500) {
    throw new ValidationError('Dados invalidos no request', [
      { field: 'notes', message: 'Notas excedem 500 caracteres' },
    ]);
  }

  const dateRaw = asString(payload.date);
  if (!dateRaw) {
    throw new ValidationError('Dados invalidos no request', [{ field: 'date', message: 'Data obrigatoria' }]);
  }

  const date = parseDate(dateRaw, 'date');
  const now = new Date();
  if (date.getTime() > now.getTime()) {
    throw new ValidationError('Dados invalidos no request', [
      { field: 'date', message: 'Data nao pode ser futura' },
    ]);
  }

  return {
    description,
    amount: parsePositiveNumber(payload.amount, 'amount'),
    type: ensureEnum(payload.type, financialTypes, 'type'),
    category,
    date: date.toISOString(),
    notes,
  };
}

export function parseListFinancialFilters(query: unknown): ListFinancialFilters {
  const q = (query ?? {}) as Record<string, unknown>;

  const page = q.page ? Number(q.page) : 1;
  const limit = q.limit ? Number(q.limit) : 10;

  if (!Number.isInteger(page) || page <= 0) {
    throw new ValidationError('Dados invalidos no request', [{ field: 'page', message: 'Pagina invalida' }]);
  }

  if (!Number.isInteger(limit) || limit <= 0 || limit > 100) {
    throw new ValidationError('Dados invalidos no request', [
      { field: 'limit', message: 'Limite deve estar entre 1 e 100' },
    ]);
  }

  let status: FinancialStatus | undefined;
  if (q.status !== undefined) {
    status = ensureEnum(q.status, financialStatuses, 'status');
  }

  let type: (typeof financialTypes)[number] | undefined;
  if (q.type !== undefined) {
    type = ensureEnum(q.type, financialTypes, 'type');
  }

  let sortBy: SortableField | undefined;
  if (q.sortBy !== undefined) {
    sortBy = ensureEnum(q.sortBy, sortableFields, 'sortBy') as SortableField;
  }

  let order: SortOrder | undefined;
  if (q.order !== undefined) {
    order = ensureEnum(q.order, ['ASC', 'DESC'] as const, 'order') as SortOrder;
  }

  let startDate: string | undefined;
  if (q.startDate !== undefined) {
    const raw = asString(q.startDate);
    if (!raw) {
      throw new ValidationError('Dados invalidos no request', [
        { field: 'startDate', message: 'Data inicial invalida' },
      ]);
    }

    startDate = parseDate(raw, 'startDate').toISOString();
  }

  let endDate: string | undefined;
  if (q.endDate !== undefined) {
    const raw = asString(q.endDate);
    if (!raw) {
      throw new ValidationError('Dados invalidos no request', [
        { field: 'endDate', message: 'Data final invalida' },
      ]);
    }

    endDate = parseDate(raw, 'endDate').toISOString();
  }

  if (startDate && endDate && new Date(startDate) > new Date(endDate)) {
    throw new ValidationError('Dados invalidos no request', [
      { field: 'dateRange', message: 'Data inicial deve ser menor ou igual a data final' },
    ]);
  }

  return {
    page,
    limit,
    status,
    type,
    startDate,
    endDate,
    sortBy,
    order,
  };
}

export function parseUpdateStatusInput(body: unknown): FinancialStatus {
  if (typeof body !== 'object' || body === null) {
    throw new ValidationError('Dados invalidos no request', [{ message: 'Corpo da requisicao invalido' }]);
  }

  const payload = body as Record<string, unknown>;
  return ensureEnum(payload.status, financialStatuses, 'status');
}
