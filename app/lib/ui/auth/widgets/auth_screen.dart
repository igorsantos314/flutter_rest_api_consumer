import 'package:flutter/material.dart';
import 'package:flutter_rest_api_consumer/domain/models/auth_model.dart';
import 'package:flutter_rest_api_consumer/ui/auth/view_models/auth_view_model.dart';
import 'package:flutter_rest_api_consumer/utils/result.dart';
import 'package:provider/provider.dart';

class AuthScreen extends StatefulWidget {
  const AuthScreen({super.key});

  @override
  State<AuthScreen> createState() => _AuthScreenState();
}

class _AuthScreenState extends State<AuthScreen> {
  bool _isLoginMode = true;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 420),
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: _isLoginMode
                  ? LoginForm(onSwitchMode: () => setState(() => _isLoginMode = false))
                  : RegisterForm(onSwitchMode: () => setState(() => _isLoginMode = true)),
            ),
          ),
        ),
      ),
    );
  }
}

class LoginForm extends StatefulWidget {
  const LoginForm({super.key, required this.onSwitchMode});

  final VoidCallback onSwitchMode;

  @override
  State<LoginForm> createState() => _LoginFormState();
}

class _LoginFormState extends State<LoginForm> {
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final authViewModel = context.watch<AuthViewModel>();

    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text('Entrar', style: Theme.of(context).textTheme.headlineMedium),
        const SizedBox(height: 8),
        Text(
          'Acesse sua conta para gerenciar seus lancamentos.',
          style: Theme.of(context).textTheme.bodyMedium,
        ),
        const SizedBox(height: 24),
        Form(
          key: _formKey,
          child: Column(
            children: [
              TextFormField(
                controller: _emailController,
                keyboardType: TextInputType.emailAddress,
                decoration: const InputDecoration(labelText: 'Email'),
                validator: (value) {
                  final email = (value ?? '').trim();
                  if (email.isEmpty) {
                    return 'Informe o email';
                  }

                  final regex = RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$');
                  if (!regex.hasMatch(email)) {
                    return 'Email invalido';
                  }

                  return null;
                },
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _passwordController,
                decoration: const InputDecoration(labelText: 'Senha'),
                obscureText: true,
                validator: (value) {
                  if ((value ?? '').length < 6) {
                    return 'Senha deve ter ao menos 6 caracteres';
                  }
                  return null;
                },
              ),
            ],
          ),
        ),
        const SizedBox(height: 20),
        FilledButton(
          onPressed: authViewModel.login.running
              ? null
              : () async {
                  if (!_formKey.currentState!.validate()) {
                    return;
                  }

                  final messenger = ScaffoldMessenger.of(context);

                  await authViewModel.login.execute(
                    LoginInput(
                      email: _emailController.text.trim(),
                      password: _passwordController.text,
                    ),
                  );

                  if (!mounted) {
                    return;
                  }

                  final result = authViewModel.login.result;
                  if (result is Error<AuthUserModel>) {
                    messenger.showSnackBar(
                      SnackBar(content: Text(result.error.toString())),
                    );
                  }
                },
          child: authViewModel.login.running
              ? const SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : const Text('Entrar'),
        ),
        TextButton(
          onPressed: authViewModel.login.running ? null : widget.onSwitchMode,
          child: const Text('Nao tenho conta. Criar conta'),
        ),
      ],
    );
  }
}

class RegisterForm extends StatefulWidget {
  const RegisterForm({super.key, required this.onSwitchMode});

  final VoidCallback onSwitchMode;

  @override
  State<RegisterForm> createState() => _RegisterFormState();
}

class _RegisterFormState extends State<RegisterForm> {
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final authViewModel = context.watch<AuthViewModel>();

    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text('Criar conta', style: Theme.of(context).textTheme.headlineMedium),
        const SizedBox(height: 8),
        Text(
          'Registre-se para comecar a usar o app financeiro.',
          style: Theme.of(context).textTheme.bodyMedium,
        ),
        const SizedBox(height: 24),
        Form(
          key: _formKey,
          child: Column(
            children: [
              TextFormField(
                controller: _emailController,
                keyboardType: TextInputType.emailAddress,
                decoration: const InputDecoration(labelText: 'Email'),
                validator: (value) {
                  final email = (value ?? '').trim();
                  if (email.isEmpty) {
                    return 'Informe o email';
                  }

                  final regex = RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$');
                  if (!regex.hasMatch(email)) {
                    return 'Email invalido';
                  }

                  return null;
                },
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _passwordController,
                decoration: const InputDecoration(labelText: 'Senha'),
                obscureText: true,
                validator: (value) {
                  if ((value ?? '').length < 6) {
                    return 'Senha deve ter ao menos 6 caracteres';
                  }
                  return null;
                },
              ),
            ],
          ),
        ),
        const SizedBox(height: 20),
        FilledButton(
          onPressed: authViewModel.register.running
              ? null
              : () async {
                  if (!_formKey.currentState!.validate()) {
                    return;
                  }

                  final messenger = ScaffoldMessenger.of(context);

                  await authViewModel.register.execute(
                    RegisterInput(
                      email: _emailController.text.trim(),
                      password: _passwordController.text,
                    ),
                  );

                  if (!mounted) {
                    return;
                  }

                  final result = authViewModel.register.result;
                  if (result is Error<AuthUserModel>) {
                    messenger.showSnackBar(
                      SnackBar(content: Text(result.error.toString())),
                    );
                  }
                },
          child: authViewModel.register.running
              ? const SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : const Text('Registrar'),
        ),
        TextButton(
          onPressed: authViewModel.register.running ? null : widget.onSwitchMode,
          child: const Text('Ja tenho conta. Entrar'),
        ),
      ],
    );
  }
}
