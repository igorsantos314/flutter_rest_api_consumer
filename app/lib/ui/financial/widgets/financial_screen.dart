import 'package:flutter/material.dart';
import 'package:flutter_rest_api_consumer/domain/models/financial_model.dart';
import 'package:flutter_rest_api_consumer/ui/auth/view_models/auth_view_model.dart';
import 'package:flutter_rest_api_consumer/ui/financial/view_models/financial_view_model.dart';
import 'package:flutter_rest_api_consumer/utils/result.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

class FinancialScreen extends StatefulWidget {
  const FinancialScreen({super.key});

  @override
  State<FinancialScreen> createState() => _FinancialScreenState();
}

class _FinancialScreenState extends State<FinancialScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<FinancialViewModel>().refresh();
    });
  }

  @override
  Widget build(BuildContext context) {
    final viewModel = context.watch<FinancialViewModel>();
    final formatter = NumberFormat.currency(locale: 'pt_BR', symbol: 'R\$');

    return Scaffold(
      appBar: AppBar(
        title: const Text('Gestao Financeira'),
        actions: [
          IconButton(
            onPressed: () => viewModel.refresh(),
            icon: const Icon(Icons.refresh),
          ),
          IconButton(
            onPressed: () => context.read<AuthViewModel>().logout.execute(),
            icon: const Icon(Icons.logout),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _openCreateDialog(context),
        icon: const Icon(Icons.add),
        label: const Text('Novo'),
      ),
      body: Column(
        children: [
          _FilterBar(viewModel: viewModel),
          Expanded(
            child: ListenableBuilder(
              listenable: viewModel.loadFinancials,
              builder: (context, _) {
                if (viewModel.loadFinancials.running) {
                  return const Center(child: CircularProgressIndicator());
                }

                if (viewModel.loadFinancials.error) {
                  final result = viewModel.loadFinancials.result;
                  final message = result is Error<PagedFinancialModel>
                      ? result.error.toString()
                      : 'Falha ao carregar lancamentos';

                  return _StateBox(
                    title: 'Erro ao carregar',
                    subtitle: message,
                    actionLabel: 'Tentar novamente',
                    onPressed: () => viewModel.refresh(),
                  );
                }

                if (!viewModel.hasData) {
                  return _StateBox(
                    title: 'Nenhum lancamento encontrado',
                    subtitle:
                        'Crie um lancamento para iniciar o controle financeiro.',
                    actionLabel: 'Criar lancamento',
                    onPressed: () => _openCreateDialog(context),
                  );
                }

                return RefreshIndicator(
                  onRefresh: () => viewModel.refresh(),
                  child: ListView.separated(
                    physics: const AlwaysScrollableScrollPhysics(),
                    padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
                    itemCount: viewModel.items.length,
                    separatorBuilder: (_, _) => const SizedBox(height: 12),
                    itemBuilder: (context, index) {
                      final item = viewModel.items[index];
                      final amountColor = item.type == FinancialType.income
                          ? Colors.green.shade700
                          : Colors.red.shade700;

                      return Card(
                        child: Padding(
                          padding: const EdgeInsets.all(16),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  Expanded(
                                    child: Text(
                                      item.description,
                                      style: Theme.of(
                                        context,
                                      ).textTheme.titleMedium,
                                    ),
                                  ),
                                  Container(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 10,
                                      vertical: 4,
                                    ),
                                    decoration: BoxDecoration(
                                      color: _statusColor(
                                        item.status,
                                      ).withValues(alpha: 0.15),
                                      borderRadius: BorderRadius.circular(12),
                                    ),
                                    child: Text(
                                      _statusLabel(item.status),
                                      style: TextStyle(
                                        fontWeight: FontWeight.w600,
                                        color: _statusColor(item.status),
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 8),
                              Text('Categoria: ${item.category}'),
                              Text(
                                'Data: ${DateFormat('dd/MM/yyyy').format(item.date)}',
                              ),
                              const SizedBox(height: 8),
                              Text(
                                formatter.format(item.amount),
                                style: TextStyle(
                                  fontSize: 18,
                                  fontWeight: FontWeight.w700,
                                  color: amountColor,
                                ),
                              ),
                              if ((item.notes ?? '').isNotEmpty) ...[
                                const SizedBox(height: 8),
                                Text('Notas: ${item.notes}'),
                              ],
                              const SizedBox(height: 12),
                              Align(
                                alignment: Alignment.centerRight,
                                child: DropdownButton<FinancialStatus>(
                                  value: item.status,
                                  onChanged: (nextStatus) {
                                    if (nextStatus == null) {
                                      return;
                                    }
                                    viewModel.updateStatus.execute((
                                      item.id,
                                      nextStatus,
                                    ));
                                  },
                                  items: FinancialStatus.values
                                      .map(
                                        (status) =>
                                            DropdownMenuItem<FinancialStatus>(
                                              value: status,
                                              child: Text(_statusLabel(status)),
                                            ),
                                      )
                                      .toList(),
                                ),
                              ),
                            ],
                          ),
                        ),
                      );
                    },
                  ),
                );
              },
            ),
          ),
          _PaginationBar(viewModel: viewModel),
        ],
      ),
    );
  }

  Future<void> _openCreateDialog(BuildContext context) async {
    final descriptionController = TextEditingController();
    final amountController = TextEditingController();
    final categoryController = TextEditingController();
    final notesController = TextEditingController();

    FinancialType selectedType = FinancialType.expense;
    DateTime selectedDate = DateTime.now();

    await showDialog<void>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          title: const Text('Novo lancamento'),
          content: StatefulBuilder(
            builder: (context, setState) {
              return SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    TextField(
                      controller: descriptionController,
                      decoration: const InputDecoration(labelText: 'Descricao'),
                    ),
                    TextField(
                      controller: amountController,
                      keyboardType: const TextInputType.numberWithOptions(
                        decimal: true,
                      ),
                      decoration: const InputDecoration(labelText: 'Valor'),
                    ),
                    TextField(
                      controller: categoryController,
                      decoration: const InputDecoration(labelText: 'Categoria'),
                    ),
                    const SizedBox(height: 12),
                    DropdownButtonFormField<FinancialType>(
                      initialValue: selectedType,
                      items: FinancialType.values
                          .map(
                            (type) => DropdownMenuItem<FinancialType>(
                              value: type,
                              child: Text(
                                type == FinancialType.income
                                    ? 'Receita'
                                    : 'Despesa',
                              ),
                            ),
                          )
                          .toList(),
                      onChanged: (value) {
                        if (value != null) {
                          setState(() => selectedType = value);
                        }
                      },
                      decoration: const InputDecoration(labelText: 'Tipo'),
                    ),
                    const SizedBox(height: 12),
                    ListTile(
                      contentPadding: EdgeInsets.zero,
                      title: const Text('Data'),
                      subtitle: Text(
                        DateFormat('dd/MM/yyyy').format(selectedDate),
                      ),
                      trailing: const Icon(Icons.calendar_today),
                      onTap: () async {
                        final picked = await showDatePicker(
                          context: context,
                          firstDate: DateTime(2000),
                          lastDate: DateTime.now(),
                          initialDate: selectedDate,
                        );

                        if (picked != null) {
                          setState(() => selectedDate = picked);
                        }
                      },
                    ),
                    TextField(
                      controller: notesController,
                      maxLines: 3,
                      decoration: const InputDecoration(
                        labelText: 'Notas (opcional)',
                      ),
                    ),
                  ],
                ),
              );
            },
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(),
              child: const Text('Cancelar'),
            ),
            FilledButton(
              onPressed: () async {
                final amount = double.tryParse(
                  amountController.text.replaceAll(',', '.'),
                );
                if (descriptionController.text.trim().isEmpty ||
                    categoryController.text.trim().isEmpty ||
                    amount == null ||
                    amount <= 0) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text(
                        'Preencha os campos obrigatorios corretamente.',
                      ),
                    ),
                  );
                  return;
                }

                final viewModel = context.read<FinancialViewModel>();
                await viewModel.createFinancial.execute(
                  CreateFinancialInput(
                    description: descriptionController.text.trim(),
                    amount: amount,
                    type: selectedType,
                    category: categoryController.text.trim(),
                    date: selectedDate,
                    notes: notesController.text.trim().isEmpty
                        ? null
                        : notesController.text.trim(),
                  ),
                );

                if (context.mounted) {
                  Navigator.of(dialogContext).pop();
                }
              },
              child: const Text('Salvar'),
            ),
          ],
        );
      },
    );

    descriptionController.dispose();
    amountController.dispose();
    categoryController.dispose();
    notesController.dispose();
  }

  String _statusLabel(FinancialStatus status) {
    switch (status) {
      case FinancialStatus.pending:
        return 'Pendente';
      case FinancialStatus.completed:
        return 'Concluido';
      case FinancialStatus.cancelled:
        return 'Cancelado';
    }
  }

  Color _statusColor(FinancialStatus status) {
    switch (status) {
      case FinancialStatus.pending:
        return Colors.orange.shade700;
      case FinancialStatus.completed:
        return Colors.green.shade700;
      case FinancialStatus.cancelled:
        return Colors.red.shade700;
    }
  }
}

class _FilterBar extends StatelessWidget {
  const _FilterBar({required this.viewModel});

  final FinancialViewModel viewModel;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Row(
        children: [
          const Text('Status: '),
          const SizedBox(width: 8),
          Expanded(
            child: DropdownButtonFormField<FinancialStatus?>(
              initialValue: viewModel.filters.status,
              decoration: const InputDecoration(
                isDense: true,
                border: OutlineInputBorder(),
              ),
              items: [
                const DropdownMenuItem<FinancialStatus?>(
                  value: null,
                  child: Text('Todos'),
                ),
                ...FinancialStatus.values.map(
                  (status) => DropdownMenuItem<FinancialStatus?>(
                    value: status,
                    child: Text(switch (status) {
                      FinancialStatus.pending => 'Pendente',
                      FinancialStatus.completed => 'Concluido',
                      FinancialStatus.cancelled => 'Cancelado',
                    }),
                  ),
                ),
              ],
              onChanged: (value) => viewModel.setStatus(value),
            ),
          ),
        ],
      ),
    );
  }
}

class _PaginationBar extends StatelessWidget {
  const _PaginationBar({required this.viewModel});

  final FinancialViewModel viewModel;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
      child: Row(
        children: [
          OutlinedButton(
            onPressed: viewModel.pagination.hasPreviousPage
                ? viewModel.previousPage
                : null,
            child: const Text('Anterior'),
          ),
          const Spacer(),
          Text(
            'Pagina ${viewModel.pagination.page}/${viewModel.pagination.totalPages}',
          ),
          const Spacer(),
          OutlinedButton(
            onPressed: viewModel.pagination.hasNextPage
                ? viewModel.nextPage
                : null,
            child: const Text('Proxima'),
          ),
        ],
      ),
    );
  }
}

class _StateBox extends StatelessWidget {
  const _StateBox({
    required this.title,
    required this.subtitle,
    required this.actionLabel,
    required this.onPressed,
  });

  final String title;
  final String subtitle;
  final String actionLabel;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(title, style: Theme.of(context).textTheme.titleLarge),
            const SizedBox(height: 8),
            Text(subtitle, textAlign: TextAlign.center),
            const SizedBox(height: 12),
            FilledButton(onPressed: onPressed, child: Text(actionLabel)),
          ],
        ),
      ),
    );
  }
}
