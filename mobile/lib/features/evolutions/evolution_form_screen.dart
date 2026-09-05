import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:garagem_mobile/core/network/api_client.dart';
import 'package:garagem_mobile/features/evolutions/evolution.dart';
import 'package:garagem_mobile/features/evolutions/evolutions_repository.dart';

final class EvolutionFormScreen extends StatefulWidget {
  const EvolutionFormScreen({
    required this.carId,
    required this.carModel,
    required this.repository,
    super.key,
  });

  final String carId;
  final String carModel;
  final EvolutionsRepository repository;

  @override
  State<EvolutionFormScreen> createState() => _EvolutionFormScreenState();
}

class _EvolutionFormScreenState extends State<EvolutionFormScreen> {
  final _formKey = GlobalKey<FormState>();
  final _titleController = TextEditingController();
  final _descriptionController = TextEditingController();
  final _mileageController = TextEditingController();

  String? _category;
  DateTime? _occurredAt = DateTime.now();
  bool _submitting = false;
  String? _errorMessage;

  @override
  void dispose() {
    _titleController.dispose();
    _descriptionController.dispose();
    _mileageController.dispose();
    super.dispose();
  }

  String? _requiredText(String? value, String message) {
    return (value?.trim().isEmpty ?? true) ? message : null;
  }

  String? _validateMileage(String? value) {
    final text = value?.trim() ?? '';
    if (text.isEmpty) return null;
    final mileage = int.tryParse(text);
    if (mileage == null || mileage < 0) {
      return 'Informe uma quilometragem válida.';
    }
    return null;
  }

  Future<void> _pickDate() async {
    final today = DateTime.now();
    final selected = await showDatePicker(
      context: context,
      initialDate: _occurredAt ?? today,
      firstDate: DateTime(1886),
      lastDate: DateTime(today.year + 1),
    );
    if (selected != null && mounted) setState(() => _occurredAt = selected);
  }

  Future<void> _submit() async {
    FocusScope.of(context).unfocus();
    if (!_formKey.currentState!.validate()) return;

    setState(() {
      _submitting = true;
      _errorMessage = null;
    });

    try {
      final mileage = _mileageController.text.trim();
      final evolution = await widget.repository.create(
        widget.carId,
        EvolutionInput(
          title: _titleController.text,
          description: _descriptionController.text,
          category: _category,
          occurredAt: _occurredAt,
          mileageKm: mileage.isEmpty ? null : int.parse(mileage),
        ),
      );
      if (mounted) Navigator.of(context).pop(evolution);
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _submitting = false;
        _errorMessage = apiErrorMessage(error);
      });
    }
  }

  String _formatDate(DateTime date) {
    final day = date.day.toString().padLeft(2, '0');
    final month = date.month.toString().padLeft(2, '0');
    return '$day/$month/${date.year}';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Registrar evolução')),
      body: SafeArea(
        child: Form(
          key: _formKey,
          child: ListView(
            padding: const EdgeInsets.fromLTRB(20, 16, 20, 32),
            children: [
              Text(
                widget.carModel,
                style: Theme.of(context).textTheme.headlineSmall,
              ),
              const SizedBox(height: 8),
              const Text('Registre uma nova etapa na história deste projeto.'),
              const SizedBox(height: 24),
              TextFormField(
                controller: _titleController,
                autofocus: true,
                textCapitalization: TextCapitalization.sentences,
                decoration: const InputDecoration(
                  labelText: 'Título *',
                  hintText: 'Ex.: Primeira revisão completa',
                  prefixIcon: Icon(Icons.auto_awesome_outlined),
                ),
                maxLength: 120,
                validator: (value) =>
                    _requiredText(value, 'Informe um título para a evolução.'),
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _descriptionController,
                textCapitalization: TextCapitalization.sentences,
                decoration: const InputDecoration(
                  labelText: 'O que mudou? *',
                  hintText: 'Conte o que foi feito e como ficou.',
                  alignLabelWithHint: true,
                ),
                minLines: 4,
                maxLines: 8,
                maxLength: 10000,
                validator: (value) =>
                    _requiredText(value, 'Descreva o que mudou no projeto.'),
              ),
              const SizedBox(height: 12),
              DropdownButtonFormField<String>(
                initialValue: _category,
                decoration: const InputDecoration(
                  labelText: 'Categoria',
                  prefixIcon: Icon(Icons.category_outlined),
                ),
                items: evolutionCategoryLabels.entries
                    .map(
                      (entry) => DropdownMenuItem(
                        value: entry.key,
                        child: Text(entry.value),
                      ),
                    )
                    .toList(growable: false),
                onChanged: _submitting
                    ? null
                    : (value) => setState(() => _category = value),
              ),
              const SizedBox(height: 20),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: _submitting ? null : _pickDate,
                      icon: const Icon(Icons.calendar_today_outlined),
                      label: Text(
                        _occurredAt == null
                            ? 'Adicionar data'
                            : _formatDate(_occurredAt!),
                      ),
                    ),
                  ),
                  if (_occurredAt != null)
                    IconButton(
                      onPressed: _submitting
                          ? null
                          : () => setState(() => _occurredAt = null),
                      tooltip: 'Remover data',
                      icon: const Icon(Icons.close),
                    ),
                ],
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _mileageController,
                keyboardType: TextInputType.number,
                inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                decoration: const InputDecoration(
                  labelText: 'Quilometragem',
                  hintText: 'Opcional',
                  suffixText: 'km',
                  prefixIcon: Icon(Icons.speed_outlined),
                ),
                validator: _validateMileage,
              ),
              if (_errorMessage != null) ...[
                const SizedBox(height: 16),
                Text(
                  _errorMessage!,
                  style: TextStyle(color: Theme.of(context).colorScheme.error),
                ),
              ],
              const SizedBox(height: 28),
              FilledButton.icon(
                onPressed: _submitting ? null : _submit,
                icon: _submitting
                    ? const SizedBox.square(
                        dimension: 18,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.add),
                label: Text(_submitting ? 'Publicando...' : 'Registrar evolução'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
