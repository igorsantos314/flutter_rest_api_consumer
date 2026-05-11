import 'package:flutter/material.dart';
import 'package:flutter_rest_api_consumer/data/network/auth_token_store.dart';
import 'package:flutter_rest_api_consumer/data/network/dio_client.dart';
import 'package:flutter_rest_api_consumer/data/network/network_activity_notifier.dart';
import 'package:flutter_rest_api_consumer/data/repositories/financial_repository_impl.dart';
import 'package:flutter_rest_api_consumer/data/services/financial_service_impl.dart';
import 'package:flutter_rest_api_consumer/domain/repositories/financial_repository.dart';
import 'package:flutter_rest_api_consumer/domain/services/financial_service.dart';
import 'package:flutter_rest_api_consumer/ui/financial/view_models/financial_view_model.dart';
import 'package:flutter_rest_api_consumer/ui/financial/widgets/financial_screen.dart';
import 'package:dio/dio.dart';
import 'package:provider/provider.dart';

void main() {
  runApp(const MainApp());
}

class MainApp extends StatelessWidget {
  const MainApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        Provider<Dio>(create: (_) => Dio()),
        Provider<AuthTokenStore>(create: (_) => AuthTokenStore()),
        ChangeNotifierProvider<NetworkActivityNotifier>(
          create: (_) => NetworkActivityNotifier(),
        ),
        Provider<DioClient>(
          create: (context) => DioClient(
            dio: context.read<Dio>(),
            tokenStore: context.read<AuthTokenStore>(),
            networkActivity: context.read<NetworkActivityNotifier>(),
          ),
        ),
        Provider<FinancialService>(
          create: (context) => FinancialServiceImpl(
            dioClient: context.read<DioClient>(),
            tokenStore: context.read<AuthTokenStore>(),
          ),
        ),
        Provider<FinancialRepository>(
          create: (context) => FinancialRepositoryImpl(
            service: context.read<FinancialService>(),
          ),
        ),
        ChangeNotifierProvider<FinancialViewModel>(
          create: (context) => FinancialViewModel(
            repository: context.read<FinancialRepository>(),
          ),
        ),
      ],
      child: MaterialApp(
        title: 'Financial App',
        theme: ThemeData(
          colorScheme: ColorScheme.fromSeed(seedColor: const Color(0xFF1E5AA8)),
          useMaterial3: true,
        ),
        home: Stack(
          children: [
            const FinancialScreen(),
            Consumer<NetworkActivityNotifier>(
              builder: (context, activity, _) {
                if (!activity.isLoading) {
                  return const SizedBox.shrink();
                }

                return IgnorePointer(
                  child: ColoredBox(
                    color: Colors.black12,
                    child: const Center(child: CircularProgressIndicator()),
                  ),
                );
              },
            ),
          ],
        ),
      ),
    );
  }
}
