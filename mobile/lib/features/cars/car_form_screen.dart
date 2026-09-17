import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:garagem_mobile/core/network/api_client.dart';
import 'package:garagem_mobile/features/cars/car.dart';
import 'package:garagem_mobile/features/cars/cars_repository.dart';

final class CarFormScreen extends StatefulWidget {
  const CarFormScreen({
    required this.repository,
    this.car,
    super.key,
  });

  final CarsRepository repository;
  final Car? car;

  @override
  State<CarFormScreen> createState() => _CarFormScreenState();
}

class _CarFormScreenState extends State<CarFormScreen> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _modelController;
  late final TextEditingController _yearController;
  late final TextEditingController _colorController;
  late final TextEditingController _plateController;
  late final TextEditingController _historyController;
  late final TextEditingController _engineController;
  late final TextEditingController _transmissionController;
  late final TextEditingController _fuelController;
  late final TextEditingController _powerController;
  late final TextEditingController _preparationController;
  late final TextEditingController _suspensionController;
  late final TextEditingController _wheelSizeController;

  String? _projectStatus;
  bool _plateVisible = false;
  bool _submitting = false;
  String? _errorMessage;

  bool get _editing => widget.car != null;

  @override
  void initState() {
    super.initState();
    final car = widget.car;
    _modelController = TextEditingController(text: car?.model);
    _yearController = TextEditingController(text: car?.year?.toString());
    _colorController = TextEditingController(text: car?.color);
    _plateController = TextEditingController(text: car?.plate);
    _historyController = TextEditingController(text: car?.history);
    _engineController = TextEditingController(text: car?.engine);
    _transmissionController = TextEditingController(text: car?.transmission);
    _fuelController = TextEditingController(text: car?.fuel);
    _powerController = TextEditingController(text: car?.estimatedPower);
    _preparationController = TextEditingController(text: car?.preparation);
    _suspensionController = TextEditingController(text: car?.suspensionType);
    _wheelSizeController = TextEditingController(text: car?.wheelSize?.toString());
    _projectStatus = car?.projectStatus;
    _plateVisible = car?.plateVisible ?? false;
  }

  @override
  void dispose() {
    _modelController.dispose();
    _yearController.dispose();
    _colorController.dispose();
    _plateController.dispose();
    _historyController.dispose();
    _engineController.dispose();
    _transmissionController.dispose();
    _fuelController.dispose();
    _powerController.dispose();
    _preparationController.dispose();
    _suspensionController.dispose();
    _wheelSizeController.dispose();
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

  String? _validateWheelSize(String? value) {
    final text = value?.trim() ?? '';
    if (text.isEmpty) return null;
    final size = int.tryParse(text);
    if (size == null || size < 1 || size > 40) {
      return 'Use um aro entre 1 e 40.';
    }
    return null;
  }

  String? _optional(TextEditingController controller) {
    final value = controller.text.trim();
    return value.isEmpty ? null : value;
  }

  CarInput _input() {
    final year = _yearController.text.trim();
    final wheelSize = _wheelSizeController.text.trim();
    return CarInput(
      model: _modelController.text,
      year: year.isEmpty ? null : int.parse(year),
      color: _optional(_colorController),
      projectStatus: _projectStatus,
      history: _optional(_historyController),
      engine: _optional(_engineController),
      transmission: _optional(_transmissionController),
      fuel: _optional(_fuelController),
      estimatedPower: _optional(_powerController),
      preparation: _optional(_preparationController),
      suspensionType: _optional(_suspensionController),
      wheelSize: wheelSize.isEmpty ? null : int.parse(wheelSize),
      plate: _optional(_plateController),
      plateVisible: _plateVisible,
    );
  }

  Future<void> _submit() async {
    FocusScope.of(context).unfocus();
    if (!_formKey.currentState!.validate()) return;

    setState(() {
      _submitting = true;
      _errorMessage = null;
    });

    try {
      final input = _input();
      final car = _editing
          ? await widget.repository.update(widget.car!.id, input)
          : await widget.repository.create(input);
      if (mounted) Navigator.of(context).pop(car);
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
      appBar: AppBar(title: Text(_editing ? 'Editar carro' : 'Adicionar carro')),
      body: SafeArea(
        child: Form(
          key: _formKey,
          child: ListView(
            padding: const EdgeInsets.fromLTRB(20, 16, 20, 32),
            children: [
              Text(
                _editing ? 'Dados do projeto' : 'Comece pelo essencial',
                style: Theme.of(context).textTheme.headlineSmall,
              ),
              const SizedBox(height: 8),
              Text(
                _editing
                    ? 'Mantenha a história e a ficha do carro atualizadas.'
                    : 'Você poderá completar e atualizar o projeto a qualquer momento.',
              ),
              const SizedBox(height: 24),
              TextFormField(
                controller: _modelController,
                autofocus: !_editing,
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
                items: _statusOptions()
                    .map(
                      (status) => DropdownMenuItem(
                        value: status,
                        child: Text(status),
                      ),
                    )
                    .toList(growable: false),
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
              const SizedBox(height: 8),
              ExpansionTile(
                tilePadding: EdgeInsets.zero,
                childrenPadding: const EdgeInsets.only(bottom: 8),
                title: const Text('Ficha técnica'),
                subtitle: const Text('Motor, câmbio, rodas e preparação'),
                children: [
                  _OptionalField(
                    controller: _engineController,
                    label: 'Motor',
                    maxLength: 100,
                  ),
                  _OptionalField(
                    controller: _transmissionController,
                    label: 'Câmbio',
                    maxLength: 50,
                  ),
                  _OptionalField(
                    controller: _fuelController,
                    label: 'Combustível',
                    maxLength: 120,
                  ),
                  _OptionalField(
                    controller: _powerController,
                    label: 'Potência estimada',
                    hint: 'Ex.: 180 cv',
                    maxLength: 50,
                  ),
                  _OptionalField(
                    controller: _preparationController,
                    label: 'Preparação',
                    maxLength: 100,
                  ),
                  _OptionalField(
                    controller: _suspensionController,
                    label: 'Suspensão',
                    maxLength: 50,
                  ),
                  TextFormField(
                    controller: _wheelSizeController,
                    keyboardType: TextInputType.number,
                    inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                    decoration: const InputDecoration(labelText: 'Aro da roda'),
                    maxLength: 2,
                    validator: _validateWheelSize,
                  ),
                ],
              ),
              const SizedBox(height: 16),
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
                    : Icon(_editing ? Icons.save_outlined : Icons.add),
                label: Text(
                  _submitting
                      ? 'Salvando...'
                      : _editing
                          ? 'Salvar alterações'
                          : 'Adicionar à garagem',
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  List<String> _statusOptions() {
    const defaults = ['Planejamento', 'Em evolução', 'Finalizado'];
    final current = _projectStatus;
    if (current == null || defaults.contains(current)) return defaults;
    return [current, ...defaults];
  }
}

final class _OptionalField extends StatelessWidget {
  const _OptionalField({
    required this.controller,
    required this.label,
    required this.maxLength,
    this.hint,
  });

  final TextEditingController controller;
  final String label;
  final String? hint;
  final int maxLength;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: 12),
      child: TextFormField(
        controller: controller,
        textCapitalization: TextCapitalization.sentences,
        decoration: InputDecoration(labelText: label, hintText: hint),
        maxLength: maxLength,
      ),
    );
  }
}
