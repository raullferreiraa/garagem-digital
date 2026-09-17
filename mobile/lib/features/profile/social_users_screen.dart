import 'package:flutter/material.dart';
import 'package:garagem_mobile/core/network/api_client.dart';
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
  late Future<List<SocialUser>> _users;

  @override
  void initState() {
    super.initState();
    _users = widget.loader();
  }

  Future<void> _reload() async {
    final next = widget.loader();
    setState(() => _users = next);
    await next;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(widget.title)),
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
            child: users.isEmpty
                ? ListView(
                    physics: const AlwaysScrollableScrollPhysics(),
                    children: const [
                      SizedBox(height: 180),
                      Icon(Icons.people_outline, size: 56),
                      SizedBox(height: 14),
                      Text(
                        'Nenhuma pessoa por aqui ainda.',
                        textAlign: TextAlign.center,
                      ),
                    ],
                  )
                : ListView.separated(
                    physics: const AlwaysScrollableScrollPhysics(),
                    padding: const EdgeInsets.fromLTRB(16, 10, 16, 32),
                    itemCount: users.length,
                    separatorBuilder: (_, __) => const SizedBox(height: 8),
                    itemBuilder: (context, index) {
                      final user = users[index];
                      return Card(
                        child: ListTile(
                          onTap: () => widget.onUserTap(user.id),
                          leading: CircleAvatar(
                            backgroundImage: user.avatarUrl == null
                                ? null
                                : NetworkImage(user.avatarUrl!),
                            child: user.avatarUrl == null
                                ? Text(
                                    user.name
                                        .substring(0, 1)
                                        .toUpperCase(),
                                  )
                                : null,
                          ),
                          title: Text(
                            user.name,
                            style: const TextStyle(
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          subtitle: Text('@${user.username}'),
                          trailing: const Icon(Icons.chevron_right),
                        ),
                      );
                    },
                  ),
          );
        },
      ),
    );
  }
}
