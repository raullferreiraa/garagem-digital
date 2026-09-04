import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:garagem_mobile/core/network/api_client.dart';
import 'package:garagem_mobile/features/cars/cars_repository.dart';

final class CreateCarScreen extends StatefulWidget {
  const CreateCarScreen({required this.repository, super.key});

  final CarsRepository repository;

  @override
  State<CreateCarScreen> createState() => _CreateCarScreenState();
}

class _CreateCarScreenState extends State<CreateCarScreen> {
  final _formKey = GlobalKey<FormState>();
  final _modelController = TextEditingController();
  final _yearController = TextEditingController();
  final _colorController = TextEditingController();
  final _plateController = TextEditingController();
  final _historyController = TextEditingController();

  String? _projectStatus;
  bool _plateVisible = false;
  bool _submitting = false;
  String? _errorMessage;

  @override
  void dispose() {
    _modelController.dispose();
    _yearController.dispose();
    _colorController.dispose();
    _plateController.dispose();
    _historyController.dispose();
    super.dispose();
  }

  String? _validateModel(String? value) {
    final model = value?.trim() ?? '';
    if (model.isEmpty) return 'Informe o modelo do carro.';
    if (model.length > 100) return 'Use no máximo 100 caracteres.';
    return null;
  }

  String? _validateYear(String? value) {
    final text = value?.trim() ?? '';
    if (text.isEmpty) return null;
    final year = int.tryParse(text);
    if (year == null || year < 1886 || year > 2200) {
      return 'Informe um ano válido.';
    }
    return null;
  }

  String? _optional(String value) {
    final trimmed = value.trim();
    return trimmed.isEmpty ? null : trimmed;
  }

  Future<void> _submit() async {
    FocusScope.of(context).unfocus();
    if (!_formKey.currentState!.validate()) return;

    setState(() {
      _submitting = true;
      _errorMessage = null;
    });

    try {
      final yearText = _yearController.text.trim();
      await widget.repository.create(
        model: _modelController.text,
        year: yearText.isEmpty ? null : int.parse(yearText),
        color: _optional(_colorController.text),
        plate: _optional(_plateController.text),
        plateVisible: _plateVisible,
        history: _optional(_historyController.text),
        projectStatus: _projectStatus,
      );
      if (mounted) Navigator.of(context).pop(true);
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _submitting = false;
        _errorMessage = apiErrorMessage(error);
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Adicionar carro')),
      body: SafeArea(
        child: Form(
          key: _formKey,
          child: ListView(
            padding: const EdgeInsets.fromLTRB(20, 16, 20, 32),
            children: [
              Text(
                'Comece pelo essencial',
                style: Theme.of(context).textTheme.headlineSmall,
              ),
              const SizedBox(height: 8),
              const Text(
                'Você poderá completar e atualizar o projeto a qualquer momento.',
              ),
              const SizedBox(height: 24),
              TextFormField(
                controller: _modelController,
                autofocus: true,
                textCapitalization: TextCapitalization.words,
                decoration: const InputDecoration(
                  labelText: 'Modelo *',
                  hintText: 'Ex.: Gol CL',
                  prefixIcon: Icon(Icons.directions_car_outlined),
                ),
                maxLength: 100,
                validator: _validateModel,
              ),
              const SizedBox(height: 12),
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: TextFormField(
                      controller: _yearController,
                      keyboardType: TextInputType.number,
                      inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                      decoration: const InputDecoration(labelText: 'Ano'),
                      maxLength: 4,
                      validator: _validateYear,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: TextFormField(
                      controller: _colorController,
                      textCapitalization: TextCapitalization.words,
                      decoration: const InputDecoration(labelText: 'Cor'),
                      maxLength: 50,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              DropdownButtonFormField<String>(
                initialValue: _projectStatus,
                decoration: const InputDecoration(
                  labelText: 'Fase do projeto',
                  prefixIcon: Icon(Icons.build_outlined),
                ),
                items: const [
                  DropdownMenuItem(
                    value: 'Planejamento',
                    child: Text('Planejamento'),
                  ),
                  DropdownMenuItem(
                    value: 'Em evolução',
                    child: Text('Em evolução'),
                  ),
                  DropdownMenuItem(
                    value: 'Finalizado',
                    child: Text('Finalizado'),
                  ),
                ],
                onChanged: _submitting
                    ? null
                    : (value) => setState(() => _projectStatus = value),
              ),
              const SizedBox(height: 20),
              TextFormField(
                controller: _historyController,
                textCapitalization: TextCapitalization.sentences,
                decoration: const InputDecoration(
                  labelText: 'História do carro',
                  hintText: 'Como esse projeto começou?',
                  alignLabelWithHint: true,
                ),
                minLines: 3,
                maxLines: 6,
                maxLength: 10000,
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _plateController,
                textCapitalization: TextCapitalization.characters,
                decoration: const InputDecoration(
                  labelText: 'Placa',
                  hintText: 'Opcional',
                  prefixIcon: Icon(Icons.badge_outlined),
                ),
                inputFormatters: [LengthLimitingTextInputFormatter(10)],
              ),
              SwitchListTile.adaptive(
                contentPadding: EdgeInsets.zero,
                title: const Text('Mostrar placa publicamente'),
                subtitle: const Text(
                  'Desativado por padrão para proteger sua privacidade.',
                ),
                value: _plateVisible,
                onChanged: _submitting
                    ? null
                    : (value) => setState(() => _plateVisible = value),
              ),
              if (_errorMessage != null) ...[
                const SizedBox(height: 12),
                Text(
                  _errorMessage!,
                  style: TextStyle(color: Theme.of(context).colorScheme.error),
                ),
              ],
              const SizedBox(height: 24),
              FilledButton.icon(
                onPressed: _submitting ? null : _submit,
                icon: _submitting
                    ? const SizedBox.square(
                        dimension: 18,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.add),
                label: Text(_submitting ? 'Salvando...' : 'Adicionar à garagem'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
