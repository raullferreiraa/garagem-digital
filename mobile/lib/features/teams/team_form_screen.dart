import 'package:flutter/material.dart';
import 'package:garagem_mobile/core/network/api_client.dart';
import 'package:garagem_mobile/features/teams/team.dart';
import 'package:garagem_mobile/features/teams/teams_repository.dart';

final class TeamFormScreen extends StatefulWidget {
  const TeamFormScreen({required this.repository, super.key});

  final TeamsRepository repository;

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

  @override
  void dispose() {
    _name.dispose();
    _description.dispose();
    _city.dispose();
    _state.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _saving = true);
    try {
      final team = await widget.repository.create(
        TeamInput(
          name: _name.text,
          description: _description.text,
          city: _city.text,
          state: _state.text,
          visibility: _visibility,
        ),
      );
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
    return Scaffold(
      appBar: AppBar(title: const Text('Criar equipe')),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(20),
          children: [
            Text(
              'Monte seu espaço',
              style: Theme.of(context).textTheme.headlineMedium,
            ),
            const SizedBox(height: 8),
            const Text('Reúna pessoas e os projetos escolhidos por cada integrante.'),
            const SizedBox(height: 24),
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
                  : const Icon(Icons.add),
              label: const Text('Criar equipe'),
            ),
          ],
        ),
      ),
    );
  }
}
