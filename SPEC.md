# Especificação de Requisitos - Sistema de Gestão Financeira

## 1. Visão Geral

Aplicação mobile e backend para gestão de lançamentos financeiros. O sistema permite criar, listar, filtrar e atualizar o status de transações financeiras com suporte a paginação e busca avançada.

### 1.1 Stack Tecnológico

- **Frontend**: Flutter (Multi-plataforma: iOS, Android, Web, Windows, macOS, Linux)
- **Frontend HTTP Client**: Dio com interceptors (auth, refresh token silencioso, logs e loading global)
- **Backend**: Node.js com Fastify + Swagger/OpenAPI
- **Banco de Dados**: PostgreSQL (recomendado) ou MongoDB
- **Arquitetura de Comunicação**: REST API

---

## 2. Autenticação e Segurança Multi-Tenant

### 2.0 Princípios de Segurança

**Regra Fundamental: Isolamento de Dados por Usuário**

Cada usuário só pode acessar seus próprios dados. Essa regra é garantida em múltiplas camadas:

1. **JWT Token**: O claim `sub` contém o userId do usuário autenticado
2. **Backend**: Todos os endpoints de dados validam que o userId do token corresponde ao userId do recurso
3. **Database**: Índices em `(userId, resourceId)` garantem isolamento eficiente
4. **Frontend**: AuthTokenStore armazena userId para validações locais

### 2.1 Fluxo de Autenticação

```
Usuário → Register/Login → Backend valida → JWT gerado com userId
         ↓
    Access Token armazenado com userId
         ↓
Requisições subsequentes adicionam Bearer token no header Authorization
         ↓
Middleware de autenticação valida JWT e extrai userId
         ↓
Todos os endpoints usam userId para filtrar dados
```

### 2.2 Endpoints de Autenticação

#### 2.2.1 Registro de Usuário

**POST /api/v1/auth/register**

**Body**:
```json
{
  "email": "user@example.com",
  "password": "senhaSegura123"
}
```

**Validações**:
- Email deve ser formato válido
- Senha mínimo 6 caracteres
- Email não pode estar já registrado

**Response (201)**:
```json
{
  "success": true,
  "data": {
    "id": "uuid",
    "email": "user@example.com",
    "createdAt": "ISO 8601"
  },
  "message": "Usuario registrado com sucesso"
}
```

#### 2.2.2 Login de Usuário

**POST /api/v1/auth/login**

**Body**:
```json
{
  "email": "user@example.com",
  "password": "senhaSegura123"
}
```

**Validações**:
- Email deve existir
- Senha deve corresponder ao hash armazenado

**Response (200)**:
```json
{
  "success": true,
  "data": {
    "user": {
      "id": "uuid",
      "email": "user@example.com",
      "createdAt": "ISO 8601"
    },
    "accessToken": "JWT com type=access, expiração 15min",
    "refreshToken": "JWT com type=refresh, expiração 7 dias",
    "tokenType": "Bearer"
  },
  "message": "Login realizado com sucesso"
}
```

#### 2.2.3 Renovação de Token

**POST /api/v1/auth/refresh**

**Body**:
```json
{
  "refreshToken": "JWT com type=refresh"
}
```

**Response (200)**:
```json
{
  "success": true,
  "data": {
    "accessToken": "novo JWT com type=access",
    "tokenType": "Bearer"
  },
  "message": "Token renovado com sucesso"
}
```

#### 2.2.4 Dev Token (Apenas Ambiente Local)

**GET /api/v1/auth/dev-token**

Gera tokens para testes locais sem fazer login real. Retorna accessToken e refreshToken com userId dev.

**Response (200)**:
```json
{
  "success": true,
  "data": {
    "userId": "dev-user-123",
    "accessToken": "JWT dev",
    "refreshToken": "JWT dev",
    "tokenType": "Bearer"
  },
  "message": "Token gerado com sucesso"
}
```

---

## 2. Regras de Arquitetura

### 2.1 Estrutura de Pastas Backend

```
api/
├── src/
│   ├── features/
│   │   ├── auth/
│   │   │   ├── routes.ts
│   │   │   ├── service.ts
│   │   │   └── repository.ts
│   │   └── financial/
│   │       ├── routes.ts
│   │       ├── controller.ts
│   │       ├── service.ts
│   │       ├── repository.ts
│   │       └── schemas.ts (validação)
│   ├── middleware/
│   ├── utils/
│   └── types/
├── docs/ (gerado via Swagger/OpenAPI)
├── tests/
└── package.json
```

### 2.2 Fluxo de Requisição Backend

```
Route → Controller → Service → Repository → Database
```

Cada camada é responsável por:
- **Route**: Mapeamento de endpoint e validação inicial
- **Controller**: Orquestração de requisição e resposta
- **Service**: Lógica de negócio
- **Repository**: Acesso a dados, **com filtro de userId**

### 2.3 Estrutura de Pastas Frontend (Flutter)

```
app/lib/
├── domain/
│   ├── models/          # Modelos puros de negócio
│   ├── repositories/    # Interfaces de repositório
│   └── services/        # Interfaces de serviço
├── data/
│   ├── models/          # DTOs (financial_dto)
│   ├── repositories/    # Implementação concreta
│   ├── services/        # Implementação de requisições HTTP
│   ├── network/         # DioClient, interceptors, token store, exceções
│   └── datasources/     # Fonte de dados (API/Cache)
├── ui/
│   ├── core/            # Widgets reutilizáveis
│   ├── financial/       # Feature financeira
│   │   ├── screens/
│   │   ├── widgets/
│   │   └── controllers/
│   └── theme/
└── utils/
    ├── command.dart
    ├── result.dart
    └── constants.dart
```

### 2.4 Padrões de Código

- **Clean Architecture**: Separação clara entre camadas
- **Repository Pattern**: Abstração de acesso a dados
- **Service Layer**: Lógica de negócio isolada
- **DTO Pattern**: Data Transfer Objects para serialização
- **Centralized HTTP Client**: DioClient com BaseOptions e interceptors globais
- **Silent Refresh**: Renovação automática de access token ao receber 401 com retry
- **Exception Mapping**: DioException mapeada para exceções de domínio da camada data
- **Multi-Tenant Security**: Todos os dados filtrados por userId do JWT

---

## 3. Especificação de Requisitos - Feature Financeira

### 3.1 Requisitos Funcionais

#### 3.1.1 Criar Lançamento Financeiro

**Descrição**: Usuário deve ser capaz de criar um novo lançamento financeiro.

**Autenticação**: Obrigatória (Bearer token com access type)

**Segurança**: Lançamento será associado ao userId do token JWT

**Dados de Entrada**:
- `description` (string, obrigatório): Descrição da transação (máx 255 caracteres)
- `amount` (number, obrigatório): Valor da transação (positivo)
- `type` (enum, obrigatório): Tipo da transação [INCOME, EXPENSE]
- `category` (string, obrigatório): Categoria (ex: "Salário", "Alimentação", etc.)
- `date` (ISO 8601 string, obrigatório): Data da transação
- `notes` (string, opcional): Notas adicionais (máx 500 caracteres)

**Validações**:
- Amount deve ser maior que 0
- Description não pode estar vazia
- Date não pode ser futura (padrão: data atual)

**Retorno**: Lançamento criado com ID gerado

#### 3.1.2 Listar Lançamentos Financeiros

**Descrição**: Recuperar lista paginada de lançamentos com suporte a filtros.

**Parâmetros de Query**:
- `page` (number, padrão: 1): Número da página
- `limit` (number, padrão: 10, máx: 100): Itens por página
- `status` (enum, opcional): PENDING, COMPLETED, CANCELLED
- `type` (enum, opcional): INCOME, EXPENSE (filtro por tipo)
- `startDate` (ISO 8601, opcional): Data inicial (incluída)
- `endDate` (ISO 8601, opcional): Data final (incluída)
- `sortBy` (string, padrão: 'date'): Campo para ordenação (date, amount, description)
- `order` (enum, padrão: 'DESC'): ASC ou DESC

**Retorno**:
```json
{
  "data": [
    {
      "id": "uuid",
      "description": "string",
      "amount": "number",
      "type": "INCOME|EXPENSE",
      "category": "string",
      "status": "PENDING|COMPLETED|CANCELLED",
      "date": "ISO 8601",
      "notes": "string",
      "createdAt": "ISO 8601",
      "updatedAt": "ISO 8601"
    }
  ],
  "pagination": {
    "page": 1,
    "limit": 10,
    "total": 150,
    "totalPages": 15,
    "hasNextPage": true,
    "hasPreviousPage": false
  }
}
```

#### 3.1.3 Atualizar Status de Lançamento

**Descrição**: Modificar o status de um lançamento financeiro.

**Parâmetros**:
- `id` (UUID, obrigatório): ID do lançamento
- `status` (enum, obrigatório): Novo status [PENDING, COMPLETED, CANCELLED]

**Validações**:
- Lançamento deve existir
- Transições de status permitidas (definir fluxo de máquina de estados se necessário)

**Retorno**: Lançamento atualizado

#### 3.1.4 Obter Detalhes de Lançamento

**Descrição**: Recuperar detalhes completos de um lançamento específico.

**Parâmetros**: `id` (UUID)

**Retorno**: Objeto completo do lançamento

---

## 4. Modelos de Dados

### 4.1 Domain Model (Negócio)

```dart
// Domain - Representa a entidade de negócio pura
abstract class Financial {
  String get id;
  String get description;
  double get amount;
  FinancialType get type;
  String get category;
  FinancialStatus get status;
  DateTime get date;
  String? get notes;
  DateTime get createdAt;
  DateTime get updatedAt;
}

enum FinancialType { income, expense }
enum FinancialStatus { pending, completed, cancelled }
```

### 4.2 Data Transfer Object (DTO)

```dart
// Data - Para serialização/desserialização HTTP
@freezed
class FinancialDTO with _$FinancialDTO {
  const factory FinancialDTO({
    required String id,
    required String description,
    required double amount,
    required String type, // 'INCOME' ou 'EXPENSE'
    required String category,
    required String status, // 'PENDING', 'COMPLETED', 'CANCELLED'
    required String date,
    String? notes,
    required String createdAt,
    required String updatedAt,
  }) = _FinancialDTO;

  factory FinancialDTO.fromJson(Map<String, dynamic> json) =>
      _$FinancialDTOFromJson(json);
}
```

### 4.3 Request/Response Models

```typescript
// Backend - TypeScript

// Criação de Lançamento
interface CreateFinancialRequest {
  description: string;
  amount: number;
  type: 'INCOME' | 'EXPENSE';
  category: string;
  date: string; // ISO 8601
  notes?: string;
}

// Atualização de Status
interface UpdateFinancialStatusRequest {
  status: 'PENDING' | 'COMPLETED' | 'CANCELLED';
}

// Resposta Paginada
interface PaginatedResponse<T> {
  data: T[];
  pagination: {
    page: number;
    limit: number;
    total: number;
    totalPages: number;
    hasNextPage: boolean;
    hasPreviousPage: boolean;
  };
}
```

---

## 5. API REST - Endpoints

### 5.1 Base URL
```
http://localhost:3000/api/v1
```

### 5.2 Endpoints da Feature Financeira

| Método | Endpoint | Descrição | Autenticação |
|--------|----------|-----------|--------------|
| POST | `/financial` | Criar lançamento | Requerida |
| GET | `/financial` | Listar lançamentos com filtros | Requerida |
| GET | `/financial/:id` | Obter detalhes do lançamento | Requerida |
| PATCH | `/financial/:id/status` | Atualizar status | Requerida |

### 5.3 Endpoints de Autenticação Técnica (Ambiente de Desenvolvimento)

| Método | Endpoint | Descrição | Autenticação |
|--------|----------|-----------|--------------|
| GET | `/auth/dev-token` | Gera access token e refresh token para ambiente local | Não |
| POST | `/auth/refresh` | Renova access token a partir de refresh token | Não |

### 5.4 Documentação Swagger/OpenAPI

- **Swagger UI**: `http://localhost:3000/docs`
- **Spec OpenAPI JSON**: `http://localhost:3000/docs/json`
- A documentação inclui:
  - Schemas de request/response dos endpoints financeiros
  - Segurança `bearerAuth`
  - Tags por domínio (`auth`, `financial`)

### 5.5 Exemplos de Requisições

#### Criar Lançamento
```http
POST /api/v1/financial
Content-Type: application/json

{
  "description": "Salário Mensal",
  "amount": 5000.00,
  "type": "INCOME",
  "category": "Salário",
  "date": "2026-05-10",
  "notes": "Salário de maio"
}
```

#### Listar com Filtros
```http
GET /api/v1/financial?page=1&limit=10&status=COMPLETED&type=INCOME&startDate=2026-05-01&endDate=2026-05-31&sortBy=date&order=DESC
```

#### Atualizar Status
```http
PATCH /api/v1/financial/550e8400-e29b-41d4-a716-446655440000/status
Content-Type: application/json

{
  "status": "COMPLETED"
}
```

---

## 6. Fluxo da Aplicação Flutter

### 6.1 Arquitetura em Camadas

```
UI Layer (Screens/Widgets)
    ↓
State Management (Provider/Riverpod)
    ↓
Repository Layer
    ↓
Service Layer
  ↓
DioClient (BaseOptions + Interceptors)
  ↓
Auth Interceptor (Bearer + Silent Refresh)
  ↓
Pretty Logger Interceptor
    ↓
Data Models (DTO)
    ↓
API Backend
```

### 6.1.1 Diretrizes do Cliente HTTP (Best Practices)

- Não instanciar `Dio()` dentro de Repository/ViewModel.
- Toda configuração de rede deve existir em um cliente central (`DioClient`).
- `BaseOptions` obrigatórios: `baseUrl`, `connectTimeout`, `receiveTimeout`, `sendTimeout`, headers padrão.
- Interceptors obrigatórios:
  - **Auth Interceptor**: injeta bearer token automaticamente.
  - **Refresh Interceptor**: ao receber 401, tenta renovar token e repete a requisição original.
  - **Log Interceptor**: logs de request/response para debug local.
  - **Loading Interceptor**: sinaliza estado global de carregamento para UI.
- Exceções de rede devem ser mapeadas para classes próprias (`NetworkException`, `ServerException`, etc.).

### 6.2 Telas da Aplicação

#### 6.2.1 Tela de Lista de Lançamentos
- **Widget**: `FinancialListScreen`
- **Funcionalidades**:
  - Exibição paginada de lançamentos
  - Carregamento lazy (infinite scroll ou paginação manual)
  - Filtro por status (dropdown)
  - Filtro por data (date range picker)
  - Ordenação por data, valor, descrição
  - Pull-to-refresh
  - Estados de carregamento, erro e vazio

#### 6.2.2 Tela de Criação/Edição de Lançamento
- **Widget**: `FinancialFormScreen`
- **Funcionalidades**:
  - Formulário com validação em tempo real
  - Seletor de tipo (INCOME/EXPENSE)
  - Seletor de categoria
  - Data picker
  - Mask de valores monetários
  - Botão de salvar com loading
  - Feedback de sucesso/erro

#### 6.2.3 Tela de Detalhes de Lançamento
- **Widget**: `FinancialDetailScreen`
- **Funcionalidades**:
  - Exibição de dados completos
  - Botão para atualizar status
  - Opções para editar ou deletar
  - Histórico de status (futuro)

### 6.3 State Management

Usar Provider ou Riverpod para:
- Gerenciar estado da lista (dados, loading, erro)
- Gerenciar estado do formulário
- Caching de dados
- Sincronização com backend

### 6.4 Tratamento de Erros

- **Erros HTTP**: Mapear status codes para mensagens user-friendly
- **Validação**: Exibir mensagens em real-time nos campos
- **Offline**: Implementar fallback para modo offline (futuro)
- **Camada Data**: Nunca propagar `DioException` diretamente para UI/Domain

---

## 7. Implementação de MVVM com Command Pattern e ChangeNotifier

Esta seção detalha como implementar o padrão sugerido pela comunidade Flutter usando Command Pattern com ChangeNotifier, baseado na implementação do [compass_app](https://github.com/flutter/samples/tree/main/compass_app).

### 7.1 Padrão de Arquitetura

```
┌─────────────────────────────────────────┐
│         UI Layer (Widgets)              │
│  - FinancialListScreen                  │
│  - ListenableBuilder(viewModel)         │
└─────────────┬───────────────────────────┘
              │
              │ Listening to changes
              │
┌─────────────▼───────────────────────────┐
│      ViewModel (ChangeNotifier)         │
│  - FinancialListViewModel               │
│  - Commands (load, filter, paginate)    │
│  - State exposure (_financials, etc)    │
└─────────────┬───────────────────────────┘
              │
              │ Calls execute()
              │
┌─────────────▼───────────────────────────┐
│    Command<T> (extends ChangeNotifier)  │
│  - Manages loading/error/completion     │
│  - Prevents multiple executions         │
│  - Exposes Result<T>                    │
└─────────────┬───────────────────────────┘
              │
              │ Calls action
              │
┌─────────────▼───────────────────────────┐
│    Repository/UseCase Layer             │
│  - FinancialRepository                  │
│  - Calls DataSource (API)               │
└─────────────┬───────────────────────────┘
              │
              │ HTTP Request
              │
┌─────────────▼───────────────────────────┐
│         API / Backend                   │
└─────────────────────────────────────────┘
```

### 7.2 Classe Command<T>

A classe `Command<T>` é o coração do padrão. Estende `ChangeNotifier` e gerencia o estado de execução de uma ação assíncrona:

```dart
// lib/utils/command.dart

typedef CommandAction0<T> = Future<Result<T>> Function();
typedef CommandAction1<T, A> = Future<Result<T>> Function(A);

/// Encapsula uma ação assíncrona com controle de estado
/// - Previne execução múltipla (one-at-a-time)
/// - Expõe estados: running, error, completed
/// - Notifica listeners sobre mudanças
/// - Armazena resultado da execução
abstract class Command<T> extends ChangeNotifier {
  Command();

  bool _running = false;
  Result<T>? _result;

  /// True quando a ação está em execução
  bool get running => _running;

  /// True quando completou com erro
  bool get error => _result is Error;

  /// True quando completou com sucesso
  bool get completed => _result is Ok;

  /// Resultado da última execução
  Result<T>? get result => _result;

  /// Limpa o resultado e notifica listeners
  void clearResult() {
    _result = null;
    notifyListeners();
  }

  /// Implementação interna de execução
  Future<void> _execute(CommandAction0<T> action) async {
    // Previne múltiplas execuções
    if (_running) return;

    _running = true;
    _result = null;
    notifyListeners(); // UI mostra loading

    try {
      _result = await action();
    } finally {
      _running = false;
      notifyListeners(); // UI atualiza com resultado
    }
  }
}

/// Command sem argumentos
class Command0<T> extends Command<T> {
  Command0(this._action);
  final CommandAction0<T> _action;

  Future<void> execute() async {
    await _execute(() => _action());
  }
}

/// Command com um argumento
class Command1<T, A> extends Command<T> {
  Command1(this._action);
  final CommandAction1<T, A> _action;

  Future<void> execute(A argument) async {
    await _execute(() => _action(argument));
  }
}
```

### 7.3 Classe Result<T>

Encapsula sucesso ou erro de forma type-safe:

```dart
// lib/utils/result.dart

/// Representa sucesso ou erro
abstract class Result<T> {
  R map<R>({
    required R Function(T value) ok,
    required R Function(Exception error) error,
  });
}

/// Resultado de sucesso
class Ok<T> extends Result<T> {
  Ok(this.value);
  final T value;

  @override
  R map<R>({
    required R Function(T value) ok,
    required R Function(Exception error) error,
  }) => ok(value);
}

/// Resultado de erro
class Error<T> extends Result<T> {
  Error(this.error);
  final Exception error;

  @override
  R map<R>({
    required R Function(T value) ok,
    required R Function(Exception error) error,
  }) => error(this.error);
}

// Extensões para facilitar acesso
extension ResultOk<T> on Result<T> {
  T get asOk => (this as Ok<T>).value;
}

extension ResultError<T> on Result<T> {
  Exception get asError => (this as Error<T>).error;
}
```

### 7.4 ViewModel com MVVM

O ViewModel estende `ChangeNotifier` e orquestra a lógica de apresentação usando Commands:

```dart
// lib/ui/financial/view_models/financial_list_viewmodel.dart

import 'package:flutter/foundation.dart';
import '../../../data/repositories/financial/financial_repository.dart';
import '../../../domain/models/financial/financial.dart';
import '../../../utils/command.dart';
import '../../../utils/result.dart';

class FinancialListViewModel extends ChangeNotifier {
  FinancialListViewModel({
    required FinancialRepository financialRepository,
  }) : _repository = financialRepository {
    // Inicializa Commands na construção
    load = Command1<void, FinancialFilterParams>(_loadFinancials);
    updateStatus = Command1<void, (String id, String status)>(_updateStatus);
    
    // Carrega dados automaticamente na primeira vez
    load.execute(
      FinancialFilterParams(page: 1, limit: 10),
    );
  }

  final FinancialRepository _repository;

  // ========== STATE ==========
  List<Financial> _financials = [];
  int _currentPage = 1;
  int _totalPages = 1;
  String? _filterStatus;
  DateTime? _filterStartDate;
  DateTime? _filterEndDate;

  // Getters para exposição de state (read-only)
  List<Financial> get financials => _financials;
  int get currentPage => _currentPage;
  int get totalPages => _totalPages;
  bool get hasNextPage => _currentPage < _totalPages;
  bool get hasPreviousPage => _currentPage > 1;

  // ========== COMMANDS ==========
  late Command1<void, FinancialFilterParams> load;
  late Command1<void, (String id, String status)> updateStatus;

  // ========== PRIVATE METHODS ==========
  
  /// Carrega lista de financeiros com filtros
  Future<Result<void>> _loadFinancials(
    FinancialFilterParams params,
  ) async {
    final result = await _repository.listFinancials(
      page: params.page,
      limit: params.limit,
      status: _filterStatus,
      startDate: _filterStartDate,
      endDate: _filterEndDate,
    );

    return result.map(
      ok: (data) {
        _financials = data.items;
        _currentPage = data.page;
        _totalPages = data.totalPages;
        notifyListeners(); // Notifica UI sobre mudanças
        return;
      },
      error: (error) {
        throw error;
      },
    );
  }

  /// Atualiza status de um financeiro
  Future<Result<void>> _updateStatus(
    (String id, String status) params,
  ) async {
    final (id, status) = params;
    
    final result = await _repository.updateFinancialStatus(id, status);

    return result.map(
      ok: (updatedFinancial) {
        // Atualiza lista local
        final index = _financials.indexWhere((f) => f.id == id);
        if (index != -1) {
          _financials[index] = updatedFinancial;
          notifyListeners();
        }
        return;
      },
      error: (error) {
        throw error;
      },
    );
  }

  // ========== PUBLIC METHODS ==========

  /// Aplica filtro de status
  void setStatusFilter(String? status) {
    _filterStatus = status;
    _currentPage = 1; // Reseta para primeira página
    // Recarrega com novo filtro
    load.execute(
      FinancialFilterParams(page: 1, limit: 10),
    );
  }

  /// Aplica filtro de data
  void setDateFilter(DateTime? start, DateTime? end) {
    _filterStartDate = start;
    _filterEndDate = end;
    _currentPage = 1;
    load.execute(
      FinancialFilterParams(page: 1, limit: 10),
    );
  }

  /// Navega para próxima página
  void nextPage() {
    if (hasNextPage) {
      _currentPage++;
      load.execute(
        FinancialFilterParams(page: _currentPage, limit: 10),
      );
    }
  }

  /// Navega para página anterior
  void previousPage() {
    if (hasPreviousPage) {
      _currentPage--;
      load.execute(
        FinancialFilterParams(page: _currentPage, limit: 10),
      );
    }
  }

  @override
  void dispose() {
    load.dispose();
    updateStatus.dispose();
    super.dispose();
  }
}

class FinancialFilterParams {
  final int page;
  final int limit;

  FinancialFilterParams({required this.page, required this.limit});
}
```

### 7.5 Widget com ListenableBuilder

O Widget consome o ViewModel usando `ListenableBuilder`, que rebuilda quando há mudanças:

```dart
// lib/ui/financial/screens/financial_list_screen.dart

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../view_models/financial_list_viewmodel.dart';

class FinancialListScreen extends StatefulWidget {
  const FinancialListScreen({super.key});

  @override
  State<FinancialListScreen> createState() => _FinancialListScreenState();
}

class _FinancialListScreenState extends State<FinancialListScreen> {
  @override
  Widget build(BuildContext context) {
    // Obtém o ViewModel do Provider
    final viewModel = context.watch<FinancialListViewModel>();

    return Scaffold(
      appBar: AppBar(
        title: const Text('Financeiro'),
        actions: [
          // Botão de refresh
          IconButton(
            onPressed: () {
              viewModel.load.execute(
                FinancialFilterParams(page: 1, limit: 10),
              );
            },
            icon: const Icon(Icons.refresh),
          ),
        ],
      ),
      body: Column(
        children: [
          // Filtros
          _FilterBar(viewModel: viewModel),
          
          // Lista com controle de estado
          Expanded(
            child: ListenableBuilder(
              listenable: viewModel.load,
              builder: (context, _) {
                // Verificar estado de carregamento
                if (viewModel.load.running) {
                  return const Center(
                    child: CircularProgressIndicator(),
                  );
                }

                // Verificar erro
                if (viewModel.load.error) {
                  return Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Text('Erro ao carregar'),
                        ElevatedButton(
                          onPressed: () {
                            viewModel.load.execute(
                              FinancialFilterParams(
                                page: viewModel.currentPage,
                                limit: 10,
                              ),
                            );
                          },
                          child: const Text('Tentar novamente'),
                        ),
                      ],
                    ),
                  );
                }

                // Lista vazia
                if (viewModel.financials.isEmpty) {
                  return const Center(
                    child: Text('Nenhum lançamento encontrado'),
                  );
                }

                // Lista de financeiros
                return ListView.builder(
                  itemCount: viewModel.financials.length,
                  itemBuilder: (context, index) {
                    final financial = viewModel.financials[index];
                    return _FinancialCard(
                      financial: financial,
                      onStatusChange: (newStatus) {
                        viewModel.updateStatus.execute(
                          (financial.id, newStatus),
                        );
                      },
                    );
                  },
                );
              },
            ),
          ),

          // Paginação
          _PaginationBar(viewModel: viewModel),
        ],
      ),
    );
  }
}

// Widget dos filtros
class _FilterBar extends StatelessWidget {
  const _FilterBar({required this.viewModel});
  final FinancialListViewModel viewModel;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        children: [
          // Filtro de status
          DropdownButton<String?>(
            value: viewModel._filterStatus,
            onChanged: (value) {
              viewModel.setStatusFilter(value);
            },
            items: [
              const DropdownMenuItem(
                value: null,
                child: Text('Todos os status'),
              ),
              const DropdownMenuItem(
                value: 'PENDING',
                child: Text('Pendente'),
              ),
              const DropdownMenuItem(
                value: 'COMPLETED',
                child: Text('Concluído'),
              ),
              const DropdownMenuItem(
                value: 'CANCELLED',
                child: Text('Cancelado'),
              ),
            ],
          ),
          // Filtro de data, etc...
        ],
      ),
    );
  }
}

// Widget de paginação
class _PaginationBar extends StatelessWidget {
  const _PaginationBar({required this.viewModel});
  final FinancialListViewModel viewModel;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          ElevatedButton(
            onPressed: viewModel.hasPreviousPage
                ? () => viewModel.previousPage()
                : null,
            child: const Text('Anterior'),
          ),
          Text(
            'Página ${viewModel.currentPage}/${viewModel.totalPages}',
          ),
          ElevatedButton(
            onPressed: viewModel.hasNextPage
                ? () => viewModel.nextPage()
                : null,
            child: const Text('Próxima'),
          ),
        ],
      ),
    );
  }
}
```

### 7.6 Integração com Provider

Configurar o Provider no main.dart:

```dart
// lib/main.dart

void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        // Repository
        ChangeNotifierProvider<FinancialRepository>(
          create: (_) => FinancialRepositoryImpl(
            httpClient: HttpClientImpl(),
          ),
        ),
        
        // ViewModel
        ChangeNotifierProxyProvider<FinancialRepository, FinancialListViewModel>(
          create: (context) => FinancialListViewModel(
            financialRepository: context.read<FinancialRepository>(),
          ),
          update: (context, repo, previous) =>
              previous ?? FinancialListViewModel(
                financialRepository: repo,
              ),
        ),
      ],
      child: MaterialApp(
        title: 'Financial App',
        theme: ThemeData(
          primarySwatch: Colors.blue,
        ),
        home: const FinancialListScreen(),
      ),
    );
  }
}
```

### 7.7 Vantagens do Padrão

✅ **Separação de responsabilidades**: UI, lógica e dados bem definidos  
✅ **Testabilidade**: Commands e ViewModels são fáceis de testar  
✅ **Reutilização**: ViewModels podem ser usados por múltiplas Screens  
✅ **Prevenção de múltiplas execuções**: Command evita cliques duplos  
✅ **Gestão de estado limpa**: ChangeNotifier notifica listeners automaticamente  
✅ **Type-safe**: Result<T> e typings fortes  
✅ **Imutabilidade**: State é imutável, mudanças via método público  
✅ **Offline-ready**: Fácil adicionar cache ou modo offline  

### 7.8 Fluxo Completo de Exemplo

```
Usuário clica em "Filtrar por Concluído"
         ↓
_FilterBar.onChanged() chama viewModel.setStatusFilter('COMPLETED')
         ↓
ViewModel define _filterStatus = 'COMPLETED'
ViewModel chama load.execute(params)
         ↓
Command1.execute(params) valida se não está em execução
Command1._running = true
Command1.notifyListeners() → UI mostra CircularProgressIndicator
         ↓
Command1 chama _loadFinancials(params)
ViewModel chama repository.listFinancials(...)
         ↓
Repository chama httpClient.get('/api/v1/financial?status=COMPLETED')
         ↓
Backend retorna response com dados filtrados
         ↓
Repository retorna Result.ok(data)
         ↓
ViewModel recebe resultado
ViewModel atualiza _financials
ViewModel chama notifyListeners()
         ↓
Command1._running = false
Command1._result = Result.ok(null)
Command1.notifyListeners()
         ↓
ListenableBuilder detecta mudança
ListenableBuilder rebuilda
         ↓
Usuário vê lista filtrada
```

---

## 8. Critérios de Aceitação

### Critério 1: Criar Lançamento
- [ ] Usuário consegue preencher formulário completo
- [ ] Validações são exibidas em tempo real
- [ ] Após submissão, lançamento é criado no backend
- [ ] Usuário recebe confirmação visual
- [ ] Lista é atualizada automaticamente

### Critério 2: Listar Lançamentos
- [ ] Lista carrega com paginação padrão (10 itens)
- [ ] Filtros por status funcionam corretamente
- [ ] Filtros por data (range) funcionam
- [ ] Ordenação por data DESC por padrão
- [ ] Pull-to-refresh atualiza dados
- [ ] Navegação entre páginas funciona
- [ ] Estados de loading/erro são exibidos

### Critério 3: Atualizar Status
- [ ] Usuário consegue alterar status via UI
- [ ] Backend confirma atualização
- [ ] Lista reflete a mudança imediatamente
- [ ] Mensagem de sucesso é exibida

---

## 9. Tratamento de Erros e Validações

### 9.1 Validações Backend

```typescript
// Regras de validação
- description: não vazio, máx 255 caracteres
- amount: positivo, máx 2 casas decimais
- type: enum [INCOME, EXPENSE]
- category: não vazio
- date: ISO 8601 válido, não pode ser futura
- status: enum [PENDING, COMPLETED, CANCELLED]
```

### 9.2 Códigos de Erro

| Código HTTP | Erro | Descrição |
|-------------|------|-----------|
| 400 | BAD_REQUEST | Dados inválidos no request |
| 401 | UNAUTHORIZED | Token ausente ou inválido |
| 403 | FORBIDDEN | Usuário sem permissão |
| 404 | NOT_FOUND | Lançamento não encontrado |
| 422 | UNPROCESSABLE_ENTITY | Validação de negócio falhou |
| 500 | INTERNAL_SERVER_ERROR | Erro no servidor |

---

## 10. Testes

### 10.1 Backend - Testes Unitários

```typescript
// Arquivo: tests/financial/service.test.ts
- [x] createFinancial: validar entrada
- [x] createFinancial: persistir no banco
- [x] listFinancial: retornar com paginação correta
- [x] listFinancial: aplicar filtros corretamente
- [x] updateStatus: validar transição de status
- [x] getById: retornar lançamento existente
- [x] getById: lançar erro para inexistente
```

### 10.2 Backend - Testes de Integração

```typescript
// Testes end-to-end dos endpoints
- [x] POST /financial: criar com sucesso
- [x] POST /financial: rejeitar dados inválidos
- [x] GET /financial: listar com filtros
- [x] PATCH /financial/:id/status: atualizar status
```

### 10.3 Flutter - Testes Unitários

```dart
// Arquivo: test/domain/models/financial_test.dart
- [x] Financial domain model criação
- [x] FinancialDTO serialização/desserialização

// Arquivo: test/data/repositories/financial_repository_test.dart
- [x] Chamar service HTTP corretamente
- [x] Mapear erro para domain exception
- [x] Cachear resultados

// Arquivo: test/data/services/financial_service_test.dart
- [x] Requisição GET com filtros
- [x] Requisição POST com validação
- [x] Tratamento de timeout
```

### 10.4 Flutter - Testes de Widget

```dart
// Arquivo: test/ui/financial/screens/list_screen_test.dart
- [x] Renderizar lista de lançamentos
- [x] Filtros funcionam corretamente
- [x] Paginação navega entre páginas
- [x] Pull-to-refresh atualiza dados
- [x] Erro é exibido corretamente
```

### 10.5 Cobertura de Testes

- **Backend**: Mínimo 80% de cobertura
- **Flutter**: Mínimo 75% de cobertura
- Usar tools: `jest` (backend), `flutter test` (app)

---

## 11. Performance e Segurança

### 11.1 Performance

- **API**: Implementar paginação (máx 100 itens por página)
- **Cache**: Implementar cache local no Flutter para dados recentes
- **Indexes**: Banco deve ter índices em `date`, `status`, `userId`
- **Lazy Loading**: Carregar dados conforme scroll/paginação

### 11.2 Segurança

- **Autenticação**: JWT token obrigatório em todos endpoints (exceto register/login/dev-token)
- **Autorização Multi-Tenant**: 
  - Cada usuário só acessa seus próprios lançamentos
  - Backend valida userId do token JWT em **todas** as operações de dados
  - Repository filtra por userId para garantir isolamento
  - Cliente nunca consegue acessar dados de outro usuário
- **Validação**: Validar e sanitizar entrada no backend
- **Refresh Token**: Renovação de access token transparente para o usuário (retry automático em 401)
- **HTTPS**: Usar HTTPS em produção
- **CORS**: Configurar CORS corretamente
- **Hash de Senha**: Senhas sempre armazenadas com hash criptográfico (não em plain text)

### 11.3 Desenvolvimento Seguro

#### 11.3.1 Requisitos de Segurança Durante o Desenvolvimento

- **Lint de segurança obrigatório**: Executar lint de segurança no backend (`api`) com regra de falha em qualquer alerta.
- **Dependências sem vulnerabilidade**: Validar dependências com auditoria de segurança antes de merge/release.
- **Sem legados**: Não utilizar métodos, funções, APIs ou infraestrutura legada/depreciada em código novo.
- **Gate de qualidade**: PR só pode ser aprovado se lint de segurança e auditoria de dependências estiverem verdes.

#### 11.3.2 Requisitos de Execução no Backend (`api`)

- `npm run lint`: validação estática TypeScript.
- `npm run lint:security`: lint de segurança (ESLint + plugin de segurança).
- `npm run security:audit`: verificação de vulnerabilidades em dependências.
- `npm run test:lint`: execução agregada obrigatória para validação de lint no backend.

---

## 12. Padrões de Resposta

### 12.1 Sucesso

```json
{
  "success": true,
  "data": {...},
  "message": "Operação concluída com sucesso"
}
```

### 12.2 Erro

```json
{
  "success": false,
  "error": {
    "code": "VALIDATION_ERROR",
    "message": "Descrição do erro",
    "details": [
      {
        "field": "amount",
        "message": "Deve ser maior que zero"
      }
    ]
  }
}
```

---

## 13. Considerações Futuras

- [ ] Relatórios e gráficos de gastos
- [ ] Categorização automática com ML
- [ ] Sincronização offline
- [ ] Integração com bancos
- [ ] Exportação de dados (PDF, CSV)
- [ ] Notificações push
- [ ] Dark mode
- [ ] Multi-idioma (i18n)