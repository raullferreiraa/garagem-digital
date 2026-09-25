import 'package:flutter/material.dart';
import 'package:garagem_mobile/core/network/api_client.dart';
import 'package:garagem_mobile/core/widgets/gd_ui.dart';
import 'package:garagem_mobile/features/profile/public_profile.dart';

final class SocialUsersScreen extends StatefulWidget {
  const SocialUsersScreen({
    required this.title,
    required this.loader,
    required this.onUserTap,
    super.key,
  });

  final String title;
  final Future<List<SocialUser>> Function() loader;
  final ValueChanged<String> onUserTap;

  @override
  State<SocialUsersScreen> createState() => _SocialUsersScreenState();
}

final class _SocialUsersScreenState extends State<SocialUsersScreen> {
  List<SocialUser>? _users;
  Object? _error;
  bool _loading = true;
  int _request = 0;

  @override
  void initState() {
    super.initState();
    _reload();
  }

  Future<void> _reload() async {
    final request = ++_request;
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final users = await widget.loader();
      if (mounted && request == _request) {
        setState(() {
          _users = users;
          _loading = false;
        });
      }
    } catch (error) {
      if (mounted && request == _request) {
        setState(() {
          _error = error;
          _loading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final users = _users;
    return Scaffold(
      appBar: AppBar(title: Text(widget.title)),
      body: users == null
          ? _loading
              ? const GdSkeleton(compact: true)
              : _errorView()
          : RefreshIndicator(
              onRefresh: _reload,
              child: ListView(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: const EdgeInsets.fromLTRB(16, 10, 16, 32),
                children: [
                  if (_loading) const LinearProgressIndicator(),
                  if (_error != null) ...[
                    Text(apiErrorMessage(_error!),
                        style: TextStyle(
                            color: Theme.of(context).colorScheme.error)),
                    TextButton.icon(
                      onPressed: _reload,
                      icon: const Icon(Icons.refresh),
                      label: const Text('Tentar novamente'),
                    ),
                  ],
                  if (users.isEmpty)
                    const Padding(
                      padding: EdgeInsets.symmetric(vertical: 110),
                      child: Column(children: [
                        Icon(Icons.people_outline, size: 56),
                        SizedBox(height: 14),
                        Text('Nenhuma pessoa por aqui ainda.'),
                      ]),
                    )
                  else
                    for (final user in users)
                      Card(
                        child: ListTile(
                          onTap: () => widget.onUserTap(user.id),
                          leading: GdAvatar(
                            name: user.name,
                            url: user.avatarUrl,
                            size: 44,
                          ),
                          title: Text(user.name),
                          subtitle: Text('@${user.username}'),
                          trailing: const Icon(Icons.chevron_right),
                        ),
                      ),
                ],
              ),
            ),
    );
  }

  Widget _errorView() => Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            const Icon(Icons.cloud_off_outlined, size: 40),
            const SizedBox(height: 12),
            Text(apiErrorMessage(_error!), textAlign: TextAlign.center),
            const SizedBox(height: 16),
            FilledButton.icon(
              onPressed: _reload,
              icon: const Icon(Icons.refresh),
              label: const Text('Tentar novamente'),
            ),
          ]),
        ),
      );
}
