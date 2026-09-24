import 'dart:typed_data';
import 'package:garagem_mobile/core/widgets/form_photo.dart';
import 'package:garagem_mobile/core/widgets/form_validation.dart';
import 'package:flutter/material.dart';
import 'package:garagem_mobile/core/network/api_client.dart';
import 'package:garagem_mobile/features/teams/team.dart';
import 'package:garagem_mobile/features/teams/teams_repository.dart';

final class TeamFormScreen extends StatefulWidget {
  const TeamFormScreen({required this.repository, this.team, super.key});

  final TeamsRepository repository;
  final TeamDetail? team;

  @override
  State<TeamFormScreen> createState() => _TeamFormScreenState();
}

class _TeamFormScreenState extends State<TeamFormScreen> {
  final _formKey = GlobalKey<FormState>();
  final _name = TextEditingController();
  final _description = TextEditingController();
  final _city = TextEditingController();
  final _state = TextEditingController();
  String _visibility = 'publica';
  bool _saving = false;
  Uint8List? _avatar;
  Uint8List? _cover;

  @override
  void initState() {
    super.initState();
    final team = widget.team;
    if (team == null) return;
    _name.text = team.name;
    _description.text = team.description ?? '';
    _city.text = team.city ?? '';
    _state.text = team.state ?? '';
    _visibility = team.visibility;
  }

  @override
  void dispose() {
    _name.dispose();
    _description.dispose();
    _city.dispose();
    _state.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (_saving) return;
    FocusScope.of(context).unfocus();
    if (!validateAndReveal(_formKey)) return;
    setState(() => _saving = true);
    try {
      final input = TeamInput(
        name: _name.text,
        description: _description.text,
        city: _city.text,
        state: _state.text,
        visibility: _visibility,
      );
      var team = widget.team == null
          ? await widget.repository.create(input)
          : await widget.repository.update(widget.team!.id, input);
      if (_avatar != null && mounted) {
        final id = team.id;
        team = await uploadFormPhoto(context, team,
            () => widget.repository.uploadImage(id, 'avatar', bytes: _avatar!));
      }
      if (_cover != null && mounted) {
        final id = team.id;
        team = await uploadFormPhoto(context, team,
            () => widget.repository.uploadImage(id, 'capa', bytes: _cover!));
      }
      if (mounted) Navigator.of(context).pop(team);
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(apiErrorMessage(error))),
      );
      setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return FormSaveGuard(
        saving: _saving,
        child: Scaffold(
          appBar: AppBar(
              title:
                  Text(widget.team == null ? 'Criar equipe' : 'Editar equipe')),
          body: Form(
            key: _formKey,
            child: FormScrollView(
              keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
              padding: const EdgeInsets.all(20),
              children: [
                Text(
                  widget.team == null ? 'Monte seu espaço' : 'Dados da equipe',
                  style: Theme.of(context).textTheme.headlineMedium,
                ),
                const SizedBox(height: 8),
                Text(widget.team == null
                    ? 'Reúna pessoas e os projetos escolhidos por cada integrante.'
                    : 'Atualize como sua equipe aparece para a comunidade.'),
                const SizedBox(height: 24),
                if (widget.team == null) ...[
                  FormPhoto(
                      label: 'Foto da equipe',
                      compact: true,
                      bytes: _avatar,
                      aspectRatio: 1,
                      enabled: !_saving,
                      onChanged: (value) => setState(() => _avatar = value)),
                  FormPhoto(
                      label: 'Capa da equipe',
                      compact: true,
                      aspectRatio: 16 / 9,
                      bytes: _cover,
                      enabled: !_saving,
                      onChanged: (value) => setState(() => _cover = value)),
                ],
                TextFormField(
                  controller: _name,
                  maxLength: 100,
                  decoration: const InputDecoration(
                    labelText: 'Nome da equipe *',
                    prefixIcon: Icon(Icons.groups_outlined),
                  ),
                  validator: (value) => value == null || value.trim().length < 2
                      ? 'Informe o nome da equipe.'
                      : null,
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: _description,
                  maxLength: 500,
                  maxLines: 3,
                  decoration: const InputDecoration(labelText: 'Descrição'),
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: TextFormField(
                        controller: _city,
                        maxLength: 120,
                        decoration: const InputDecoration(labelText: 'Cidade'),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: TextFormField(
                        controller: _state,
                        maxLength: 120,
                        decoration: const InputDecoration(labelText: 'Estado'),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                DropdownButtonFormField<String>(
                  initialValue: _visibility,
                  decoration: const InputDecoration(
                    labelText: 'Visibilidade',
                    prefixIcon: Icon(Icons.visibility_outlined),
                  ),
                  items: const [
                    DropdownMenuItem(value: 'publica', child: Text('Pública')),
                    DropdownMenuItem(value: 'privada', child: Text('Privada')),
                  ],
                  onChanged: (value) => setState(() => _visibility = value!),
                ),
                const SizedBox(height: 28),
                FilledButton.icon(
                  onPressed: _saving ? null : _save,
                  icon: _saving
                      ? const SizedBox.square(
                          dimension: 18,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : Icon(widget.team == null
                          ? Icons.add
                          : Icons.save_outlined),
                  label: Text(_saving
                      ? 'Salvando…'
                      : widget.team == null
                          ? 'Criar equipe'
                          : 'Salvar alterações'),
                ),
              ],
            ),
          ),
        ));
  }
}
