import 'dart:async';

import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_rest_api_consumer/data/network/api_exceptions.dart';
import 'package:flutter_rest_api_consumer/data/network/auth_token_store.dart';
import 'package:flutter_rest_api_consumer/data/network/network_activity_notifier.dart';
import 'package:pretty_dio_logger/pretty_dio_logger.dart';

/// [DioClient] é o cliente HTTP centralizado da aplicação.
///
/// Responsabilidades:
/// 1. Gerenciar todas as requisições HTTP para a API backend
/// 2. Aplicar interceptors globais (autenticação, refresh token, logging, loading)
/// 3. Mapear erros de rede para exceções customizadas
/// 4. Renovar access token automaticamente em caso de 401 (silent refresh)
/// 5. Controlar o estado de carregamento global
///
/// Benefícios da centralização:
/// - Evita duplicação de lógica em diferentes partes da app
/// - Facilita manutenção e debug de problemas de rede
/// - Garante consistência no tratamento de erros
/// - Permite adicionar comportamentos globais facilmente
class DioClient {
  DioClient({
    required Dio dio,
    required AuthTokenStore tokenStore,
    required NetworkActivityNotifier networkActivity,
    this.baseUrl = 'http://localhost:3000/api/v1',
  }) : _dio = dio,
       _tokenStore = tokenStore,
       _networkActivity = networkActivity,
       _refreshDio = Dio() {
    // ==================== CONFIGURAÇÃO DO DIO PRINCIPAL ====================
    // O Dio principal é usado para todas as requisições normais
    _dio.options = BaseOptions(
      baseUrl: baseUrl,
      // Timeout para conectar ao servidor
      connectTimeout: const Duration(seconds: 15),
      // Timeout para receber resposta do servidor
      receiveTimeout: const Duration(seconds: 15),
      // Timeout para enviar dados
      sendTimeout: const Duration(seconds: 15),
      // Define o content-type padrão como JSON
      headers: {'Content-Type': 'application/json'},
      // Espera sempre resposta em formato JSON
      responseType: ResponseType.json,
    );

    // ==================== CONFIGURAÇÃO DO DIO DE REFRESH ====================
    // O Dio de refresh é usado exclusivamente para renovar token
    // É necessário ser uma instância separada para evitar interceptors recursivos
    _refreshDio.options = BaseOptions(
      baseUrl: baseUrl,
      connectTimeout: const Duration(seconds: 15),
      receiveTimeout: const Duration(seconds: 15),
      sendTimeout: const Duration(seconds: 15),
      headers: {'Content-Type': 'application/json'},
      responseType: ResponseType.json,
    );

    // ==================== INTERCEPTOR 1: AUTENTICAÇÃO E LOADING ====================
    // Responsável por:
    // 1. Adicionar o Authorization header com o Bearer token
    // 2. Controlar o indicador de carregamento global
    // 3. Determinar se a requisição precisa de autenticação
    _dio.interceptors.add(
      InterceptorsWrapper(
        onRequest: (options, handler) async {
          // Verifica se o usuário quer pular o indicador de loading (ex: auth/dev-token)
          final skipLoader = options.extra['skipGlobalLoader'] == true;
          if (!skipLoader) {
            // Incrementa contador de requisições ativas
            _networkActivity.startRequest();
          }

          // Verifica se esta requisição precisa de autenticação
          // Por padrão, precisa (requiresAuth = true)
          final requiresAuth = options.extra['requiresAuth'] != false;
          if (requiresAuth &&
              _tokenStore.hasAccessToken &&
              _tokenStore.isAccessTokenExpired) {
            await _refreshAccessToken();
          }

          if (requiresAuth && _tokenStore.hasAccessToken) {
            // Adiciona o token JWT no header Authorization
            options.headers['Authorization'] =
                'Bearer ${_tokenStore.accessToken}';
          }

          // Passa o controle para o próximo interceptor ou requisição
          handler.next(options);
        },
        onResponse: (response, handler) {
          // Na resposta bem-sucedida, decrementa o contador de loading
          final skipLoader =
              response.requestOptions.extra['skipGlobalLoader'] == true;
          if (!skipLoader) {
            _networkActivity.finishRequest();
          }
          handler.next(response);
        },
        onError: (error, handler) async {
          // Na resposta com erro, também decrementa o contador
          final skipLoader =
              error.requestOptions.extra['skipGlobalLoader'] == true;
          if (!skipLoader) {
            _networkActivity.finishRequest();
          }

          // ==================== LÓGICA DE REFRESH TOKEN ====================
          // Detecta se foi erro 401 (não autorizado) e tenta renovar o token
          final shouldRefresh =
              error.response?.statusCode == 401 &&
              // Apenas tenta refresh se a requisição original permitir (retryAfterRefresh != false)
              error.requestOptions.extra['retryAfterRefresh'] != false &&
              // Evita loop infinito: não tenta refresh na requisição de refresh em si
              (error.requestOptions.extra['isRefreshCall'] != true);

          if (shouldRefresh) {
            // Tenta renovar o token e fazer retry da requisição original
            final retried = await _retryWithRefresh(error.requestOptions);
            if (retried != null) {
              // Se conseguiu renovar e fazer retry, resolve com a nova resposta
              handler.resolve(retried);
              return;
            }
          }

          // Se não pode fazer refresh ou falhou, converte o erro para exceção customizada
          handler.reject(_mapDioError(error));
        },
      ),
    );

    // ==================== INTERCEPTOR 2: LOGGING ====================
    // Registra todas as requisições e respostas HTTP para debugging
    // Configurado para não logar em modo release
    _dio.interceptors.add(
      PrettyDioLogger(
        requestHeader: true, // Exibe headers da requisição
        requestBody: true, // Exibe body da requisição
        responseHeader:
            false, // Não exibe headers da resposta (pode ser verbose)
        responseBody: true, // Exibe body da resposta
        error: true, // Exibe erros detalhados
        compact: true, // Formato compacto
        enabled: !kReleaseMode, // Desabilita em modo release
      ),
    );
  }

  final Dio _dio;
  final Dio _refreshDio;
  final AuthTokenStore _tokenStore;
  final NetworkActivityNotifier _networkActivity;
  final String baseUrl;

  /// Flag que indica se uma renovação de token está em andamento
  bool _isRefreshing = false;

  /// Completer que aguarda a conclusão da renovação de token
  /// Usado para sincronizar múltiplas requisições que chegam com 401 simultaneamente
  /// Todas aguardam o mesmo completer ao invés de fazerem refresh em paralelo
  Completer<void>? _refreshCompleter;

  /// Faz uma requisição GET
  ///
  /// Parâmetros:
  /// - [path]: rota da API (ex: '/financial')
  /// - [queryParameters]: query string parameters (ex: page=1&limit=10)
  /// - [requiresAuth]: se true (padrão), adiciona o Authorization header
  /// - [skipGlobalLoader]: se true, não exibe indicador de carregamento global
  ///
  /// Retorna: Map com a resposta JSON da API
  Future<Map<String, dynamic>> get(
    String path, {
    Map<String, dynamic>? queryParameters,
    bool requiresAuth = true,
    bool skipGlobalLoader = false,
  }) async {
    final response = await _dio.get<Map<String, dynamic>>(
      path,
      queryParameters: queryParameters,
      options: Options(
        extra: {
          'requiresAuth': requiresAuth,
          'skipGlobalLoader': skipGlobalLoader,
          'retryAfterRefresh': true,
        },
      ),
    );

    return response.data ?? <String, dynamic>{};
  }

  /// Faz uma requisição POST
  ///
  /// Parâmetros:
  /// - [path]: rota da API
  /// - [data]: body da requisição (será convertido para JSON automaticamente)
  /// - [queryParameters]: query string parameters
  /// - [requiresAuth]: se true (padrão), adiciona o Authorization header
  /// - [skipGlobalLoader]: se true, não exibe indicador de carregamento global
  ///
  /// Retorna: Map com a resposta JSON da API
  Future<Map<String, dynamic>> post(
    String path, {
    Object? data,
    Map<String, dynamic>? queryParameters,
    bool requiresAuth = true,
    bool skipGlobalLoader = false,
  }) async {
    final response = await _dio.post<Map<String, dynamic>>(
      path,
      data: data,
      queryParameters: queryParameters,
      options: Options(
        extra: {
          'requiresAuth': requiresAuth,
          'skipGlobalLoader': skipGlobalLoader,
          'retryAfterRefresh': true,
        },
      ),
    );

    return response.data ?? <String, dynamic>{};
  }

  /// Faz uma requisição PATCH (atualização parcial)
  ///
  /// Parâmetros:
  /// - [path]: rota da API
  /// - [data]: body da requisição
  /// - [queryParameters]: query string parameters
  /// - [requiresAuth]: se true (padrão), adiciona o Authorization header
  /// - [skipGlobalLoader]: se true, não exibe indicador de carregamento global
  ///
  /// Retorna: Map com a resposta JSON da API
  Future<Map<String, dynamic>> patch(
    String path, {
    Object? data,
    Map<String, dynamic>? queryParameters,
    bool requiresAuth = true,
    bool skipGlobalLoader = false,
  }) async {
    final response = await _dio.patch<Map<String, dynamic>>(
      path,
      data: data,
      queryParameters: queryParameters,
      options: Options(
        extra: {
          'requiresAuth': requiresAuth,
          'skipGlobalLoader': skipGlobalLoader,
          'retryAfterRefresh': true,
        },
      ),
    );

    return response.data ?? <String, dynamic>{};
  }

  /// ==================== LÓGICA DE REFRESH TOKEN ====================
  ///
  /// Este é o coração do silent refresh. Quando uma requisição recebe 401:
  /// 1. Se não há refresh token, limpa os tokens e retorna null
  /// 2. Se outro refresh já está em andamento, aguarda seu resultado
  /// 3. Se ninguém está fazendo refresh, torna-se responsável pelo refresh:
  ///    - Faz POST para /auth/refresh com o refresh token
  ///    - Recebe o novo access token
  ///    - Armazena na token store
  ///    - Notifica todos que aguardavam
  /// 4. Então faz retry da requisição original com o novo token
  ///
  /// Benefício: Se 5 requisições chegam com 401 simultaneamente,
  /// apenas 1 faz refresh. As outras 4 aguardam o resultado e usam o mesmo token.
  Future<Response<dynamic>?> _retryWithRefresh(
    RequestOptions requestOptions,
  ) async {
    final refreshed = await _refreshAccessToken();
    if (!refreshed) {
      return null;
    }

    // Verifica se conseguiu renovar o token (alguém no fluxo acima armazenou um novo)
    if (!_tokenStore.hasAccessToken) {
      return null;
    }

    // Prepara a requisição original para ser refeita com o novo token
    final headers = Map<String, dynamic>.from(requestOptions.headers);
    headers['Authorization'] = 'Bearer ${_tokenStore.accessToken}';

    final retryOptions = Options(
      method: requestOptions.method,
      headers: headers,
      responseType: requestOptions.responseType,
      contentType: requestOptions.contentType,
      // Define retryAfterRefresh como false para não tentar refresh novamente
      extra: {...requestOptions.extra, 'retryAfterRefresh': false},
    );

    // Faz a requisição original novamente, agora com o novo token
    return _dio.request<dynamic>(
      requestOptions.path,
      data: requestOptions.data,
      queryParameters: requestOptions.queryParameters,
      options: retryOptions,
    );
  }

  Future<bool> _refreshAccessToken() async {
    // Se nao tem refresh token, nao consegue renovar.
    final refreshToken = _tokenStore.refreshToken;
    if (refreshToken == null || refreshToken.isEmpty) {
      _tokenStore.clear();
      return false;
    }

    if (_tokenStore.isRefreshTokenExpired) {
      _tokenStore.clear();
      return false;
    }

    if (_isRefreshing) {
      // Se outro refresh já está em andamento, aguarda seu resultado
      // Isso evita múltiplas requisições de refresh simultâneas
      try {
        await _refreshCompleter?.future;
      } catch (_) {
        return false;
      }
    } else {
      // Marca que agora este código é responsável pelo refresh
      _isRefreshing = true;
      // Cria um novo Completer que outros aguardarão
      _refreshCompleter = Completer<void>();
      try {
        // Usa o _refreshDio (sem interceptors de refresh) para evitar recursão
        final refreshed = await _refreshDio.post<Map<String, dynamic>>(
          '/auth/refresh',
          data: {'refreshToken': refreshToken},
          options: Options(
            extra: {'isRefreshCall': true, 'requiresAuth': false},
          ),
        );

        final data = refreshed.data ?? <String, dynamic>{};
        final payload = data['data'];
        if (payload is! Map<String, dynamic>) {
          throw const UnauthorizedException('Resposta de refresh invalida');
        }

        final newAccessToken = payload['accessToken'];
        if (newAccessToken is! String || newAccessToken.isEmpty) {
          throw const UnauthorizedException('Access token invalido');
        }

        // Armazena o novo token na token store com o mesmo userId
        final userId = _tokenStore.userId;
        if (userId == null || userId.isEmpty) {
          throw const UnauthorizedException('UserId invalido');
        }

        _tokenStore.setTokens(userId: userId, accessToken: newAccessToken);
        // Notifica todos os que estavam aguardando que o refresh terminou com sucesso
        _refreshCompleter?.complete();
      } catch (_) {
        // Se algo deu errado durante refresh, limpa os tokens
        // Força o usuário a se autenticar novamente
        _tokenStore.clear();
        // Notifica que o refresh falhou
        _refreshCompleter?.completeError(const UnauthorizedException());
        return false;
      } finally {
        // Marca que ninguém mais está fazendo refresh
        _isRefreshing = false;
      }
    }

    return _tokenStore.hasAccessToken;
  }

  /// ==================== MAPEAMENTO DE ERROS ====================
  ///
  /// Converte erros de rede (DioException) para exceções de domínio customizadas.
  /// Isso fornece uma abstração clara para camadas superiores (Service, ViewModel)
  /// sem que elas precisem conhecer detalhes de implementação de rede (Dio).
  ///
  /// Mapeamento:
  /// - Timeout/Conexão → NetworkException (erro de conectividade)
  /// - 401 → UnauthorizedException (não autenticado)
  /// - 400/422 → ValidationApiException (validação falhou)
  /// - 500+ → ServerException (erro interno do servidor)
  /// - Outros → ApiException genérica
  DioException _mapDioError(DioException error) {
    final responseData = error.response?.data;

    // Erros de timeout ou conexão recusada
    if (error.type == DioExceptionType.connectionTimeout ||
        error.type == DioExceptionType.receiveTimeout ||
        error.type == DioExceptionType.connectionError) {
      return error.copyWith(error: const NetworkException());
    }

    final status = error.response?.statusCode ?? 0;

    // 401: Não autenticado (não deveria chegar aqui depois de refresh, mas é possível)
    if (status == 401) {
      return error.copyWith(error: const UnauthorizedException());
    }

    // 400: Requisição inválida ou 422: Entidade não processável
    // Tenta extrair a mensagem de erro do backend
    if (status == 400 || status == 422) {
      final message = responseData is Map<String, dynamic>
          ? ((responseData['error'] as Map<String, dynamic>?)?['message']
                as String?)
          : null;
      return error.copyWith(
        error: ValidationApiException(message ?? 'Erro de validacao da API'),
      );
    }

    // 500+: Erro no servidor
    if (status >= 500) {
      return error.copyWith(error: const ServerException());
    }

    // Qualquer outro erro
    return error.copyWith(
      error: ApiException(error.message ?? 'Erro inesperado de rede'),
    );
  }
}
