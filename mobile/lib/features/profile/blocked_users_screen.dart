import 'package:flutter/material.dart';
import 'package:garagem_mobile/core/network/api_client.dart';
import 'package:garagem_mobile/features/profile/public_profile.dart';
import 'package:garagem_mobile/features/profile/users_repository.dart';

final class BlockedUsersScreen extends StatefulWidget {
  const BlockedUsersScreen({required this.repository, super.key});

  final UsersRepository repository;

  @override
  State<BlockedUsersScreen> createState() => _BlockedUsersScreenState();
}

final class _BlockedUsersScreenState extends State<BlockedUsersScreen> {
  late Future<List<SocialUser>> _users;
  String? _busyId;

  @override
  void initState() {
    super.initState();
    _users = widget.repository.blockedUsers();
  }

  Future<void> _reload() async {
    final users = await widget.repository.blockedUsers();
    if (mounted) {
      setState(() {
        _users = Future.value(users);
      });
    }
  }

  Future<void> _unblock(SocialUser user) async {
    if (_busyId != null) return;
    setState(() => _busyId = user.id);
    try {
      List<SocialUser>? confirmed;
      try {
        await widget.repository.unblock(user.id);
      } catch (_) {
        // Uma falha na resposta não significa necessariamente que o servidor
        // deixou de concluir o desbloqueio.
        confirmed = await widget.repository.blockedUsers();
        if (confirmed.any((item) => item.id == user.id)) rethrow;
      }
      final current = confirmed ?? await _users;
      if (!mounted) return;
      setState(() {
        _users = Future.value(
          current.where((item) => item.id != user.id).toList(),
        );
      });
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(apiErrorMessage(error))),
        );
      }
    } finally {
      if (mounted) setState(() => _busyId = null);
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
        appBar: AppBar(title: const Text('Perfis bloqueados')),
        body: FutureBuilder<List<SocialUser>>(
          future: _users,
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return const Center(child: CircularProgressIndicator());
            }
            if (snapshot.hasError) {
              return Center(
                child: FilledButton.icon(
                  onPressed: _reload,
                  icon: const Icon(Icons.refresh),
                  label: Text(apiErrorMessage(snapshot.error!)),
                ),
              );
            }
            final users = snapshot.data ?? const <SocialUser>[];
            return RefreshIndicator(
              onRefresh: _reload,
              child: ListView(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 40),
                children: users.isEmpty
                    ? const [
                        SizedBox(height: 150),
                        Icon(Icons.block_outlined, size: 48),
                        SizedBox(height: 16),
                        Text('Nenhum perfil bloqueado.',
                            textAlign: TextAlign.center),
                      ]
                    : [
                        for (final user in users)
                          Card(
                            child: ListTile(
                              title: Text(user.name),
                              subtitle: Text('@${user.username}'),
                              trailing: TextButton(
                                onPressed: _busyId == null
                                    ? () => _unblock(user)
                                    : null,
                                child: Text(_busyId == user.id
                                    ? 'Desbloqueando…'
                                    : 'Desbloquear'),
                              ),
                            ),
                          ),
                      ],
              ),
            );
          },
        ),
      );
}
