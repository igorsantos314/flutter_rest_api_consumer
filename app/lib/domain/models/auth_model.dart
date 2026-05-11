class AuthUserModel {
  const AuthUserModel({
    required this.id,
    required this.email,
    required this.createdAt,
  });

  final String id;
  final String email;
  final DateTime createdAt;
}

class LoginInput {
  const LoginInput({required this.email, required this.password});

  final String email;
  final String password;
}

class RegisterInput {
  const RegisterInput({required this.email, required this.password});

  final String email;
  final String password;
}
