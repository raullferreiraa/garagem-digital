import 'package:flutter/material.dart';
import 'package:garagem_mobile/core/network/api_client.dart';
import 'package:garagem_mobile/features/events/event.dart';
import 'package:garagem_mobile/features/events/events_repository.dart';
import 'package:garagem_mobile/features/teams/team.dart';

final class EventFormScreen extends StatefulWidget {
  const EventFormScreen(
      {required this.repository, this.team, this.event, super.key});
  final EventsRepository repository;
  final Team? team;
  final GarageEvent? event;
  @override
  State<EventFormScreen> createState() => _EventFormScreenState();
}

class _EventFormScreenState extends State<EventFormScreen> {
  final _form = GlobalKey<FormState>();
  final _name = TextEditingController();
  final _description = TextEditingController();
  final _address = TextEditingController();
  final _city = TextEditingController();
  final _state = TextEditingController();
  late DateTime _startsAt;
  String _organizer = 'usuario';
  String _visibility = 'publico';
  bool _saving = false;
  bool _scheduleNow = false;

  @override
  void initState() {
    super.initState();
    final event = widget.event;
    if (event != null) {
      _name.text = event.name;
      _description.text = event.description ?? '';
      _city.text = event.city ?? '';
      _state.text = event.state ?? '';
    }
    final now = DateTime.now();
    _startsAt = DateTime(now.year, now.month, now.day + 1, 10);
  }

  @override
  void dispose() {
    for (final controller in [_name, _description, _address, _city, _state]) {
      controller.dispose();
    }
    super.dispose();
  }

  Future<void> _pickDate() async {
    final date = await showDatePicker(
        context: context,
        initialDate: _startsAt,
        firstDate: DateTime.now(),
        lastDate: DateTime.now().add(const Duration(days: 730)));
    if (date == null || !mounted) return;
    final time = await showTimePicker(
        context: context, initialTime: TimeOfDay.fromDateTime(_startsAt));
    if (time == null || !mounted) return;
    setState(() => _startsAt =
        DateTime(date.year, date.month, date.day, time.hour, time.minute));
  }

  Future<void> _save() async {
    if (!_form.currentState!.validate()) return;
    setState(() => _saving = true);
    try {
      final input = EventInput(
        name: _name.text,
        description: _description.text,
        startsAt: _scheduleNow ? _startsAt : null,
        address: _address.text,
        city: _city.text,
        state: _state.text,
        organizer: _organizer,
        visibility: _visibility,
      );
      final event = widget.event == null
          ? await widget.repository.create(input)
          : await widget.repository.update(widget.event!.id, input);
      if (mounted) Navigator.of(context).pop(event);
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(apiErrorMessage(error))));
      setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
        appBar: AppBar(
            title: Text(
                widget.event == null ? 'Criar encontro' : 'Editar encontro')),
        body: Form(
          key: _form,
          child: ListView(padding: const EdgeInsets.all(20), children: [
            Text('Crie um ponto de encontro permanente',
                style: Theme.of(context).textTheme.headlineMedium),
            const SizedBox(height: 8),
            const Text(
                'Conte o que reúne vocês. A comunidade continua viva entre uma edição e outra.'),
            const SizedBox(height: 24),
            TextFormField(
              controller: _name,
              maxLength: 140,
              decoration:
                  const InputDecoration(labelText: 'Nome do encontro *'),
              validator: (value) => value == null || value.trim().length < 3
                  ? 'Informe um nome com pelo menos 3 caracteres.'
                  : null,
            ),
            const SizedBox(height: 12),
            TextFormField(
                controller: _description,
                maxLength: 2000,
                maxLines: 4,
                decoration: const InputDecoration(labelText: 'Descrição')),
            const SizedBox(height: 12),
            if (widget.event == null)
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                title: const Text('Agendar primeira edição'),
                subtitle: const Text('Você também pode definir a data depois.'),
                value: _scheduleNow,
                onChanged: _saving
                    ? null
                    : (value) => setState(() => _scheduleNow = value),
              ),
            if (_scheduleNow) ...[
              OutlinedButton.icon(
                  onPressed: _pickDate,
                  icon: const Icon(Icons.calendar_month_outlined),
                  label: Text(_dateLabel(_startsAt))),
              const SizedBox(height: 12),
              TextFormField(
                  controller: _address,
                  decoration: const InputDecoration(
                      labelText: 'Local público',
                      hintText: 'Ex.: estacionamento, praça ou autódromo')),
              const SizedBox(height: 12),
            ],
            Row(children: [
              Expanded(
                  child: TextFormField(
                      controller: _city,
                      decoration: const InputDecoration(labelText: 'Cidade'))),
              const SizedBox(width: 12),
              Expanded(
                  child: TextFormField(
                      controller: _state,
                      decoration: const InputDecoration(labelText: 'Estado'))),
            ]),
            if (widget.team != null && widget.event == null) ...[
              const SizedBox(height: 12),
              DropdownButtonFormField<String>(
                initialValue: _organizer,
                decoration: const InputDecoration(labelText: 'Organizar como'),
                items: [
                  const DropdownMenuItem(
                      value: 'usuario', child: Text('Meu perfil')),
                  DropdownMenuItem(
                      value: 'equipe', child: Text(widget.team!.name))
                ],
                onChanged: (value) => setState(() {
                  _organizer = value!;
                  if (value == 'usuario') _visibility = 'publico';
                }),
              ),
            ],
            if (_organizer == 'equipe') ...[
              const SizedBox(height: 12),
              SwitchListTile.adaptive(
                contentPadding: EdgeInsets.zero,
                title: const Text('Somente para a equipe'),
                subtitle:
                    const Text('O encontro não aparece para outras pessoas.'),
                value: _visibility == 'somente_equipe',
                onChanged: (value) => setState(
                    () => _visibility = value ? 'somente_equipe' : 'publico'),
              ),
            ],
            const SizedBox(height: 28),
            FilledButton.icon(
              onPressed: _saving ? null : _save,
              icon: _saving
                  ? const SizedBox.square(
                      dimension: 18,
                      child: CircularProgressIndicator(strokeWidth: 2))
                  : const Icon(Icons.flag_outlined),
              label: Text(_saving
                  ? 'Salvando…'
                  : widget.event == null
                      ? 'Criar encontro'
                      : 'Salvar alterações'),
            ),
          ]),
        ),
      );
}

String _dateLabel(DateTime value) {
  const months = [
    'jan',
    'fev',
    'mar',
    'abr',
    'mai',
    'jun',
    'jul',
    'ago',
    'set',
    'out',
    'nov',
    'dez'
  ];
  return '${value.day} ${months[value.month - 1]} · ${value.hour}:${value.minute.toString().padLeft(2, '0')}';
}
