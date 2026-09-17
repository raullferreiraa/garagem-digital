import 'dart:async';

import 'package:flutter/material.dart';
import 'package:garagem_mobile/core/network/api_client.dart';
import 'package:garagem_mobile/features/profile/public_profile.dart';
import 'package:garagem_mobile/features/profile/users_repository.dart';
import 'package:garagem_mobile/features/teams/team.dart';
import 'package:garagem_mobile/features/teams/teams_repository.dart';

final class TeamInviteSheet extends StatefulWidget {
  const TeamInviteSheet({
    required this.team,
    required this.repository,
    required this.usersRepository,
    super.key,
  });

  final TeamDetail team;
  final TeamsRepository repository;
  final UsersRepository usersRepository;

  @override
  State<TeamInviteSheet> createState() => _TeamInviteSheetState();
}

final class _TeamInviteSheetState extends State<TeamInviteSheet> {
  final _controller = TextEditingController();
  Timer? _debounce;
  List<SocialUser> _results = const [];
  Object? _error;
  bool _loading = false;
  String? _invitingUserId;

  @override
  void dispose() {
    _debounce?.cancel();
    _controller.dispose();
    super.dispose();
  }

  void _changed(String value) {
    _debounce?.cancel();
    final query = value.trim();
    if (query.length < 2) {
      setState(() {
        _results = const [];
        _error = null;
        _loading = false;
      });
      return;
    }
    setState(() {
      _loading = true;
      _error = null;
    });
    _debounce = Timer(
      const Duration(milliseconds: 250),
      () => _search(query),
    );
  }

  Future<void> _search(String query) async {
    try {
      final users = await widget.usersRepository.search(query);
      if (!mounted || _controller.text.trim() != query) return;
      final memberIds =
          widget.team.members.map((member) => member.userId).toSet();
      setState(() {
        _results = users
            .where((user) => !memberIds.contains(user.id))
            .toList(growable: false);
        _loading = false;
        _error = null;
      });
    } catch (error) {
      if (!mounted || _controller.text.trim() != query) return;
      setState(() {
        _error = error;
        _loading = false;
      });
    }
  }

  Future<void> _invite(SocialUser user) async {
    setState(() => _invitingUserId = user.id);
    try {
      await widget.repository.invite(widget.team.id, user.id);
      if (mounted) Navigator.of(context).pop(true);
    } catch (error) {
      if (!mounted) return;
      setState(() => _invitingUserId = null);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(apiErrorMessage(error))),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final query = _controller.text.trim();
    return FractionallySizedBox(
      heightFactor: 0.86,
      child: Padding(
        padding: EdgeInsets.fromLTRB(
          16,
          4,
          16,
          16 + MediaQuery.viewInsetsOf(context).bottom,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Convidar integrante',
              style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                    fontWeight: FontWeight.w800,
                  ),
            ),
            const SizedBox(height: 6),
            Text(
              'Busque uma pessoa pelo nome ou @username.',
              style: TextStyle(
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _controller,
              autofocus: true,
              onChanged: _changed,
              decoration: const InputDecoration(
                hintText: 'Nome ou @username',
                prefixIcon: Icon(Icons.search_rounded),
              ),
            ),
            const SizedBox(height: 14),
            Expanded(child: _body(query)),
          ],
        ),
      ),
    );
  }

  Widget _body(String query) {
    if (query.length < 2) {
      return const Center(
        child: Text('Digite pelo menos 2 caracteres para buscar.'),
      );
    }
    if (_loading) {
      return const Center(child: CircularProgressIndicator());
    }
    if (_error != null) {
      return Center(child: Text(apiErrorMessage(_error!)));
    }
    if (_results.isEmpty) {
      return const Center(child: Text('Nenhuma pessoa disponível encontrada.'));
    }
    return ListView.separated(
      itemCount: _results.length,
      separatorBuilder: (_, __) => const Divider(height: 1),
      itemBuilder: (context, index) {
        final user = _results[index];
        final initial = user.name.isEmpty ? '?' : user.name[0].toUpperCase();
        final inviting = _invitingUserId == user.id;
        return ListTile(
          contentPadding: const EdgeInsets.symmetric(horizontal: 4, vertical: 6),
          leading: CircleAvatar(
            backgroundImage:
                user.avatarUrl == null ? null : NetworkImage(user.avatarUrl!),
            child: user.avatarUrl == null ? Text(initial) : null,
          ),
          title: Text(
            '@${user.username}',
            style: const TextStyle(fontWeight: FontWeight.w800),
          ),
          subtitle: Text(user.name),
          trailing: FilledButton(
            onPressed: _invitingUserId == null ? () => _invite(user) : null,
            child: inviting
                ? const SizedBox.square(
                    dimension: 18,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Text('Convidar'),
          ),
        );
      },
    );
  }
}
