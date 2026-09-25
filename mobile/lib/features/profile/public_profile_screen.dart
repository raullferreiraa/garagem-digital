import 'package:flutter/material.dart';
import 'package:garagem_mobile/core/network/api_client.dart';
import 'package:garagem_mobile/core/sharing/gd_share.dart';
import 'package:garagem_mobile/core/widgets/gd_ui.dart';
import 'package:garagem_mobile/features/cars/car.dart';
import 'package:garagem_mobile/features/cars/car_detail_screen.dart';
import 'package:garagem_mobile/features/cars/cars_repository.dart';
import 'package:garagem_mobile/features/evolutions/evolutions_repository.dart';
import 'package:garagem_mobile/features/messages/conversation_screen.dart';
import 'package:garagem_mobile/features/messages/messages_repository.dart';
import 'package:garagem_mobile/features/profile/public_profile.dart';
import 'package:garagem_mobile/features/profile/social_users_screen.dart';
import 'package:garagem_mobile/features/profile/users_repository.dart';
import 'package:garagem_mobile/features/sharing/share_content.dart';
import 'package:garagem_mobile/features/teams/team_detail_screen.dart';
import 'package:garagem_mobile/features/teams/teams_repository.dart';

typedef _ProfileData = ({PublicProfile profile, List<Car> cars});

final class PublicProfileScreen extends StatefulWidget {
  const PublicProfileScreen({
    required this.userId,
    required this.currentUserId,
    required this.usersRepository,
    required this.carsRepository,
    required this.evolutionsRepository,
    required this.messagesRepository,
    required this.teamsRepository,
    required this.onConversationChanged,
    super.key,
  });

  final String userId;
  final String currentUserId;
  final UsersRepository usersRepository;
  final CarsRepository carsRepository;
  final EvolutionsRepository evolutionsRepository;
  final MessagesRepository messagesRepository;
  final TeamsRepository teamsRepository;
  final VoidCallback onConversationChanged;

  @override
  State<PublicProfileScreen> createState() => _PublicProfileScreenState();
}

final class _PublicProfileScreenState extends State<PublicProfileScreen> {
  late Future<_ProfileData> _data;
  _ProfileData? _visibleData;
  bool _changingFollow = false;
  bool _openingConversation = false;
  bool _reporting = false;
  bool _changingBlock = false;

  @override
  void initState() {
    super.initState();
    _data = _load();
  }

  Future<_ProfileData> _load() async {
    final profile = await widget.usersRepository.profile(widget.userId);
    final cars = await widget.usersRepository.cars(widget.userId);
    return (profile: profile, cars: cars);
  }

  Future<void> _reload() async {
    final loaded = await _load();
    if (!mounted) return;
    setState(() {
      _data = Future.value(loaded);
      _visibleData = loaded;
    });
  }

  PublicProfile _withFollowState(
    PublicProfile profile, {
    required bool followed,
  }) {
    final difference = followed == profile.followedByMe
        ? 0
        : followed
            ? 1
            : -1;
    return PublicProfile(
      id: profile.id,
      name: profile.name,
      username: profile.username,
      projectCount: profile.projectCount,
      followerCount: profile.followerCount + difference,
      followingCount: profile.followingCount,
      followedByMe: followed,
      blockedByMe: profile.blockedByMe,
      avatarUrl: profile.avatarUrl,
      bio: profile.bio,
      city: profile.city,
      state: profile.state,
      team: profile.team,
    );
  }

  PublicProfile _withBlockState(
    PublicProfile profile, {
    required bool blocked,
  }) =>
      PublicProfile(
        id: profile.id,
        name: profile.name,
        username: profile.username,
        projectCount: profile.projectCount,
        followerCount:
            profile.followerCount - (blocked && profile.followedByMe ? 1 : 0),
        followingCount: profile.followingCount,
        followedByMe: blocked ? false : profile.followedByMe,
        blockedByMe: blocked,
        avatarUrl: profile.avatarUrl,
        bio: profile.bio,
        city: profile.city,
        state: profile.state,
        team: blocked ? null : profile.team,
      );

  Future<void> _toggleFollow(_ProfileData data) async {
    final previous = data;
    final shouldFollow = !data.profile.followedByMe;
    final optimistic = (
      profile: _withFollowState(data.profile, followed: shouldFollow),
      cars: data.cars,
    );
    setState(() {
      _changingFollow = true;
      _visibleData = optimistic;
    });

    try {
      if (shouldFollow) {
        await widget.usersRepository.follow(data.profile.id);
      } else {
        await widget.usersRepository.unfollow(data.profile.id);
      }

      try {
        final confirmed = await widget.usersRepository.profile(data.profile.id);
        if (mounted) {
          setState(() {
            _visibleData = (profile: confirmed, cars: data.cars);
          });
        }
      } catch (_) {
        // A ação principal já terminou. A confirmação pode esperar o próximo
        // pull-to-refresh sem apresentar um falso erro ao usuário.
      }
    } catch (error) {
      try {
        final confirmed = await widget.usersRepository.profile(data.profile.id);
        if (!mounted) return;
        if (confirmed.followedByMe == shouldFollow) {
          setState(() {
            _visibleData = (profile: confirmed, cars: data.cars);
          });
          return;
        }
      } catch (_) {
        // Se nem a reconciliação responder, restauramos o estado anterior.
      }

      if (mounted) {
        setState(() => _visibleData = previous);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(apiErrorMessage(error))),
        );
      }
    } finally {
      if (mounted) setState(() => _changingFollow = false);
    }
  }

  Future<void> _openProfile(String userId) async {
    await Navigator.of(context).push<void>(
      MaterialPageRoute(
        builder: (_) => PublicProfileScreen(
          userId: userId,
          currentUserId: widget.currentUserId,
          usersRepository: widget.usersRepository,
          carsRepository: widget.carsRepository,
          evolutionsRepository: widget.evolutionsRepository,
          messagesRepository: widget.messagesRepository,
          teamsRepository: widget.teamsRepository,
          onConversationChanged: widget.onConversationChanged,
        ),
      ),
    );
  }

  Future<void> _openConversation(PublicProfile profile) async {
    if (_openingConversation) return;
    setState(() => _openingConversation = true);
    try {
      final conversation =
          await widget.messagesRepository.openDirect(profile.id);
      if (!mounted) return;
      await Navigator.of(context).push<void>(MaterialPageRoute(
        builder: (_) => ConversationScreen(
          conversation: conversation,
          repository: widget.messagesRepository,
          currentUserId: widget.currentUserId,
          onProfileTap: (_) {
            if (Navigator.of(context).canPop()) Navigator.of(context).pop();
          },
          onChanged: widget.onConversationChanged,
        ),
      ));
      widget.onConversationChanged();
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(apiErrorMessage(error))),
        );
      }
    } finally {
      if (mounted) setState(() => _openingConversation = false);
    }
  }

  Future<void> _reportProfile(PublicProfile profile) async {
    if (_reporting) return;
    final detailsController = TextEditingController();
    String reason = 'spam';
    String? validationError;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: const Text('Denunciar perfil'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  'A denúncia será analisada. O perfil não será avisado sobre quem denunciou.',
                  style: Theme.of(context).textTheme.bodyMedium,
                ),
                const SizedBox(height: 16),
                DropdownButtonFormField<String>(
                  initialValue: reason,
                  decoration: const InputDecoration(labelText: 'Motivo'),
                  items: const [
                    DropdownMenuItem(
                        value: 'spam', child: Text('Spam ou golpe')),
                    DropdownMenuItem(
                        value: 'assedio',
                        child: Text('Assédio ou intimidação')),
                    DropdownMenuItem(
                        value: 'conteudo_improprio',
                        child: Text('Conteúdo impróprio')),
                    DropdownMenuItem(
                        value: 'identidade_falsa',
                        child: Text('Identidade falsa')),
                    DropdownMenuItem(
                        value: 'outro', child: Text('Outro motivo')),
                  ],
                  onChanged: (value) => setDialogState(() {
                    reason = value ?? reason;
                    validationError = null;
                  }),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: detailsController,
                  maxLength: 500,
                  minLines: 2,
                  maxLines: 4,
                  textCapitalization: TextCapitalization.sentences,
                  decoration: InputDecoration(
                    labelText: reason == 'outro'
                        ? 'Explique o motivo *'
                        : 'Detalhes (opcional)',
                    errorText: validationError,
                    alignLabelWithHint: true,
                  ),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(false),
              child: const Text('Cancelar'),
            ),
            FilledButton(
              onPressed: () {
                if (reason == 'outro' &&
                    detailsController.text.trim().isEmpty) {
                  setDialogState(
                      () => validationError = 'Explique o motivo da denúncia.');
                  return;
                }
                Navigator.of(dialogContext).pop(true);
              },
              child: const Text('Enviar denúncia'),
            ),
          ],
        ),
      ),
    );
    if (confirmed != true || !mounted) {
      detailsController.dispose();
      return;
    }
    setState(() => _reporting = true);
    try {
      await widget.usersRepository.report(
        profile.id,
        reason: reason,
        details: detailsController.text,
      );
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Denúncia enviada para análise.')),
        );
      }
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(apiErrorMessage(error))),
        );
      }
    } finally {
      detailsController.dispose();
      if (mounted) setState(() => _reporting = false);
    }
  }

  Future<void> _toggleBlock(PublicProfile profile) async {
    if (_changingBlock) return;
    final shouldBlock = !profile.blockedByMe;
    if (shouldBlock) {
      final confirmed = await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('Bloquear perfil?'),
          content: const Text(
            'Vocês deixarão de se seguir, trocar mensagens diretas e interagir '
            'em publicações. É possível desfazer isso depois.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: const Text('Cancelar'),
            ),
            FilledButton(
              onPressed: () => Navigator.of(context).pop(true),
              child: const Text('Bloquear'),
            ),
          ],
        ),
      );
      if (confirmed != true || !mounted) return;
    }
    setState(() => _changingBlock = true);
    try {
      PublicProfile? confirmed;
      try {
        if (shouldBlock) {
          await widget.usersRepository.block(profile.id);
        } else {
          await widget.usersRepository.unblock(profile.id);
        }
      } catch (error) {
        // A resposta pode falhar depois de o servidor concluir a alteração.
        // Reconciliamos o estado antes de afirmar que a ação não funcionou.
        try {
          confirmed = await widget.usersRepository.profile(profile.id);
        } catch (_) {
          rethrow;
        }
        if (confirmed.blockedByMe != shouldBlock) rethrow;
      }
      if (!mounted) return;
      final current = _visibleData ?? await _data;
      if (!mounted) return;
      setState(() => _visibleData = (
            profile: confirmed ??
                _withBlockState(current.profile, blocked: shouldBlock),
            cars: shouldBlock ? <Car>[] : current.cars,
          ));
      try {
        widget.onConversationChanged();
      } catch (_) {
        // Atualizar outras abas não altera o resultado do bloqueio.
      }
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content:
            Text(shouldBlock ? 'Perfil bloqueado.' : 'Perfil desbloqueado.'),
      ));
      try {
        await _reload();
      } catch (_) {
        // A sincronização pode ser repetida no pull-to-refresh.
      }
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(apiErrorMessage(error))),
        );
      }
    } finally {
      if (mounted) setState(() => _changingBlock = false);
    }
  }

  Future<void> _openConnections(
    PublicProfile profile, {
    required bool following,
  }) async {
    await Navigator.of(context).push<void>(
      MaterialPageRoute(
        builder: (_) => SocialUsersScreen(
          title: following ? 'Seguindo' : 'Seguidores',
          loader: () => following
              ? widget.usersRepository.following(profile.id)
              : widget.usersRepository.followers(profile.id),
          onUserTap: _openProfile,
        ),
      ),
    );
    if (mounted) await _reload();
  }

  Future<void> _openCar(Car car) async {
    await Navigator.of(context).push<void>(
      MaterialPageRoute(
        builder: (_) => CarDetailScreen(
          car: car,
          repository: widget.carsRepository,
          evolutionsRepository: widget.evolutionsRepository,
          canManage: car.ownerId == widget.currentUserId,
          currentUserId: widget.currentUserId,
          onProfileTap: _openProfile,
        ),
      ),
    );
    if (mounted) await _reload();
  }

  Future<void> _openTeam(ProfileTeam team) async {
    await Navigator.of(context).push<void>(MaterialPageRoute(
      builder: (_) => TeamDetailScreen(
        teamId: team.id,
        repository: widget.teamsRepository,
        carsRepository: widget.carsRepository,
        evolutionsRepository: widget.evolutionsRepository,
        currentUserId: widget.currentUserId,
        usersRepository: widget.usersRepository,
        messagesRepository: widget.messagesRepository,
        onConversationChanged: widget.onConversationChanged,
      ),
    ));
    if (mounted) await _reload();
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<_ProfileData>(
      future: _data,
      builder: (context, snapshot) {
        final data = _visibleData ?? snapshot.data;
        return Scaffold(
          appBar: AppBar(
            title: const Text('Perfil'),
            actions: [
              if (data != null)
                GdShareAction(
                  payload: ShareContent.profile(data.profile),
                  tooltip: 'Compartilhar perfil',
                ),
              if (data != null && data.profile.id != widget.currentUserId)
                PopupMenuButton<String>(
                  tooltip: 'Mais opções',
                  enabled: !_reporting && !_changingBlock,
                  onSelected: (action) {
                    if (action == 'report') {
                      _reportProfile(data.profile);
                    } else {
                      _toggleBlock(data.profile);
                    }
                  },
                  itemBuilder: (_) => [
                    const PopupMenuItem(
                      value: 'report',
                      child: ListTile(
                        contentPadding: EdgeInsets.zero,
                        leading: Icon(Icons.flag_outlined),
                        title: Text('Denunciar perfil'),
                      ),
                    ),
                    PopupMenuItem(
                      value: 'block',
                      child: ListTile(
                        contentPadding: EdgeInsets.zero,
                        leading: Icon(data.profile.blockedByMe
                            ? Icons.person_add_alt_1_outlined
                            : Icons.block_outlined),
                        title: Text(data.profile.blockedByMe
                            ? 'Desbloquear perfil'
                            : 'Bloquear perfil'),
                      ),
                    ),
                  ],
                ),
            ],
          ),
          body: data != null
              ? RefreshIndicator(
                  onRefresh: _reload,
                  child: _content(data),
                )
              : snapshot.hasError
                  ? Center(
                      child: FilledButton.icon(
                        onPressed: _reload,
                        icon: const Icon(Icons.refresh),
                        label: Text(apiErrorMessage(snapshot.error!)),
                      ),
                    )
                  : const GdSkeleton(),
        );
      },
    );
  }

  Widget _content(_ProfileData data) {
    final profile = data.profile;
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    final isMe = profile.id == widget.currentUserId;
    final location = [profile.city, profile.state]
        .where((item) => item != null && item.isNotEmpty)
        .join(' · ');

    return ListView(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 48),
      children: [
        GdReveal(
            child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(children: [
              Expanded(
                  child: Text(
                'QUEM ESTÁ AO VOLANTE',
                style: theme.textTheme.labelSmall?.copyWith(
                  letterSpacing: 2,
                  color: colors.primary,
                ),
              )),
              Icon(Icons.sports_motorsports_outlined,
                  color: colors.primary, size: 24),
            ]),
            const SizedBox(height: 22),
            Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                GdAvatar(name: profile.name, url: profile.avatarUrl, size: 88),
                const SizedBox(width: 18),
                Expanded(
                    child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(profile.name, style: theme.textTheme.headlineLarge),
                    const SizedBox(height: 3),
                    Text(
                      '@${profile.username}',
                      style: theme.textTheme.bodyMedium
                          ?.copyWith(color: colors.primary),
                    ),
                    if (location.isNotEmpty) ...[
                      const SizedBox(height: 8),
                      Row(children: [
                        Icon(Icons.location_on_outlined,
                            size: 14, color: colors.onSurfaceVariant),
                        const SizedBox(width: 4),
                        Expanded(
                            child: Text(
                          location,
                          style: theme.textTheme.labelMedium
                              ?.copyWith(color: colors.onSurfaceVariant),
                        )),
                      ]),
                    ],
                  ],
                )),
              ],
            ),
            if (profile.bio?.isNotEmpty == true) ...[
              const SizedBox(height: 20),
              Text(profile.bio!,
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: colors.onSurfaceVariant,
                    height: 1.6,
                  )),
            ],
            const SizedBox(height: 20),
            Container(
              padding: const EdgeInsets.symmetric(vertical: 12),
              decoration: BoxDecoration(
                border: Border(
                  top: BorderSide(color: colors.outlineVariant),
                  bottom: BorderSide(color: colors.outlineVariant),
                ),
              ),
              child: Row(children: [
                _Stat(value: profile.projectCount, label: 'projetos'),
                _Stat(
                  value: profile.followerCount,
                  label: 'seguidores',
                  onTap: () => _openConnections(profile, following: false),
                ),
                _Stat(
                  value: profile.followingCount,
                  label: 'seguindo',
                  onTap: () => _openConnections(profile, following: true),
                ),
              ]),
            ),
            if (!isMe && !profile.blockedByMe) ...[
              const SizedBox(height: 18),
              Row(children: [
                Expanded(
                  child: profile.followedByMe
                      ? OutlinedButton.icon(
                          onPressed: _changingFollow
                              ? null
                              : () => _toggleFollow(data),
                          icon: const Icon(Icons.person_remove_outlined),
                          label: const Text('Seguindo'),
                        )
                      : FilledButton.icon(
                          onPressed: _changingFollow
                              ? null
                              : () => _toggleFollow(data),
                          icon: const Icon(Icons.person_add_alt_1),
                          label: const Text('Seguir'),
                        ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: _openingConversation
                        ? null
                        : () => _openConversation(profile),
                    icon: _openingConversation
                        ? const SizedBox.square(
                            dimension: 18,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Icon(Icons.forum_outlined),
                    label: const Text('Mensagem'),
                  ),
                ),
              ]),
            ],
          ],
        )),
        if (profile.blockedByMe) ...[
          const SizedBox(height: 20),
          const Text(
              'Você bloqueou este perfil. Abra o menu para desbloquear.'),
        ],
        if (!profile.blockedByMe) const SizedBox(height: 28),
        if (!profile.blockedByMe) ...[
          if (profile.team != null) ...[
            const GdSectionTitle(title: 'Equipe', eyebrow: 'NA MESMA PISTA'),
            const SizedBox(height: 12),
            Card(
              margin: EdgeInsets.zero,
              child: ListTile(
                leading: GdAvatar(
                  name: profile.team!.name,
                  url: profile.team!.avatarUrl,
                  size: 48,
                ),
                title: Text(profile.team!.name),
                subtitle: const Text('Ver equipe'),
                trailing: const Icon(Icons.chevron_right),
                onTap: () => _openTeam(profile.team!),
              ),
            ),
            const SizedBox(height: 28),
          ],
          GdSectionTitle(
            title: 'Projetos',
            eyebrow: 'A GARAGEM',
            trailing: Text(
              '${data.cars.length}',
              style:
                  theme.textTheme.labelLarge?.copyWith(color: colors.primary),
            ),
          ),
          const SizedBox(height: 14),
          if (data.cars.isEmpty)
            Container(
              padding: const EdgeInsets.all(28),
              decoration: BoxDecoration(
                color: colors.surfaceContainer,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: colors.outlineVariant),
              ),
              child: Column(children: [
                Icon(Icons.garage_outlined, size: 44, color: colors.primary),
                const SizedBox(height: 10),
                const Text('Esta garagem ainda não tem projetos.',
                    textAlign: TextAlign.center),
              ]),
            )
          else
            for (final car in data.cars)
              Padding(
                padding: const EdgeInsets.only(bottom: 16),
                child: GdReveal(
                    child: Card(
                  margin: EdgeInsets.zero,
                  clipBehavior: Clip.antiAlias,
                  child: InkWell(
                    onTap: () => _openCar(car),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        AspectRatio(
                          aspectRatio: 16 / 9,
                          child: GdImage(
                              url: car.photoUrl, semanticLabel: car.model),
                        ),
                        Padding(
                          padding: const EdgeInsets.all(16),
                          child: Row(children: [
                            Expanded(
                                child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                if (car.projectStatus != null) ...[
                                  Text(
                                    car.projectStatus!.toUpperCase(),
                                    style: theme.textTheme.labelSmall?.copyWith(
                                      color: colors.primary,
                                      letterSpacing: 1.5,
                                    ),
                                  ),
                                  const SizedBox(height: 5),
                                ],
                                Text(
                                  [car.model, car.year]
                                      .whereType<Object>()
                                      .join(' '),
                                  style: theme.textTheme.titleLarge,
                                ),
                              ],
                            )),
                            const SizedBox(width: 12),
                            Icon(Icons.north_east_rounded,
                                color: colors.primary, size: 22),
                          ]),
                        ),
                      ],
                    ),
                  ),
                )),
              ),
        ],
      ],
    );
  }
}

final class _Stat extends StatelessWidget {
  const _Stat({
    required this.value,
    required this.label,
    this.onTap,
  });

  final int value;
  final String label;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(14),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 8),
          child: Column(
            children: [
              Text(
                '$value',
                style: Theme.of(context).textTheme.headlineMedium,
              ),
              Text(label,
                  style: Theme.of(context).textTheme.labelSmall?.copyWith(
                        color: Theme.of(context).colorScheme.onSurfaceVariant,
                      )),
            ],
          ),
        ),
      ),
    );
  }
}
