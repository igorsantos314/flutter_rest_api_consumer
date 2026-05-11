class ApiException implements Exception {
  const ApiException(this.message);

  final String message;

  @override
  String toString() => message;
}

class NetworkException extends ApiException {
  const NetworkException([super.message = 'Falha de conectividade com a API']);
}

class ServerException extends ApiException {
  const ServerException([super.message = 'Erro interno no servidor']);
}

class UnauthorizedException extends ApiException {
  const UnauthorizedException([super.message = 'Nao autorizado']);
}

class ValidationApiException extends ApiException {
  const ValidationApiException([super.message = 'Erro de validacao da API']);
}
