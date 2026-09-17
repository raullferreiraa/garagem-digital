import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:garagem_mobile/core/network/api_client.dart';
import 'package:garagem_mobile/features/cars/car.dart';
import 'package:garagem_mobile/features/cars/car_detail_screen.dart';
import 'package:garagem_mobile/features/cars/photo_crop_screen.dart';
import 'package:garagem_mobile/features/cars/cars_repository.dart';
import 'package:garagem_mobile/features/evolutions/evolutions_repository.dart';
import 'package:garagem_mobile/features/profile/public_profile_screen.dart';
import 'package:garagem_mobile/features/profile/users_repository.dart';
import 'package:garagem_mobile/features/teams/team.dart';
import 'package:garagem_mobile/features/teams/team_form_screen.dart';
import 'package:garagem_mobile/features/teams/team_invite_sheet.dart';
import 'package:garagem_mobile/features/teams/teams_repository.dart';

enum _TeamImageAction { avatar, cover, removeAvatar, removeCover }

final class TeamDetailScreen extends StatefulWidget {
  const TeamDetailScreen({
    required this.teamId,
    required this.repository,
    required this.carsRepository,
    required this.evolutionsRepository,
    required this.currentUserId,
    required this.usersRepository,
    super.key,
  });

  final String teamId;
  final TeamsRepository repository;
  final CarsRepository carsRepository;
  final EvolutionsRepository evolutionsRepository;
  final String currentUserId;
  final UsersRepository usersRepository;

  @override
  State<TeamDetailScreen> createState() => _TeamDetailScreenState();
}

class _TeamDetailScreenState extends State<TeamDetailScreen> {
  late Future<TeamDetail> _team;
  TeamDetail? _currentTeam;
  bool _acting = false;

  @override
  void initState() {
    super.initState();
    _team = widget.repository.detail(widget.teamId);
  }

  Future<void> _reload() async {
    final updated = await widget.repository.detail(widget.teamId);
    if (!mounted) return;
    setState(() => _currentTeam = updated);
  }

  Future<void> _act(Future<void> Function() action, String success) async {
    setState(() => _acting = true);
    try {
      await action();
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(apiErrorMessage(error))),
        );
      }
      if (mounted) setState(() => _acting = false);
      return;
    }

    try {
      await _reload();
    } catch (error, stackTrace) {
      debugPrint('Falha ao atualizar equipe: $error\n$stackTrace');
    }
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(success)),
      );
    }
    if (mounted) setState(() => _acting = false);
  }

  Future<void> _editTeam(TeamDetail team) async {
    final updated = await Navigator.of(context).push<TeamDetail>(
      MaterialPageRoute(
        builder: (_) => TeamFormScreen(repository: widget.repository, team: team),
      ),
    );
    if (!mounted || updated == null) return;
    setState(() => _currentTeam = updated);
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Equipe atualizada.')),
    );
  }

  Future<void> _showImageOptions(TeamDetail team) async {
    final action = await showModalBottomSheet<_TeamImageAction>(
      context: context,
      showDragHandle: true,
      builder: (context) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const ListTile(title: Text('Imagens da equipe')),
            ListTile(
              leading: const Icon(Icons.account_circle_outlined),
              title: const Text('Alterar foto da equipe'),
              onTap: () => Navigator.of(context).pop(_TeamImageAction.avatar),
            ),
            ListTile(
              leading: const Icon(Icons.panorama_outlined),
              title: const Text('Alterar capa'),
              onTap: () => Navigator.of(context).pop(_TeamImageAction.cover),
            ),
            if (team.avatarUrl != null)
              ListTile(
                leading: const Icon(Icons.delete_outline),
                title: const Text('Remover foto da equipe'),
                onTap: () =>
                    Navigator.of(context).pop(_TeamImageAction.removeAvatar),
              ),
            if (team.coverUrl != null)
              ListTile(
                leading: const Icon(Icons.delete_outline),
                title: const Text('Remover capa'),
                onTap: () =>
                    Navigator.of(context).pop(_TeamImageAction.removeCover),
              ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
    if (!mounted || action == null) return;
    switch (action) {
      case _TeamImageAction.avatar:
      case _TeamImageAction.cover:
        final source = await showModalBottomSheet<ImageSource>(
          context: context,
          showDragHandle: true,
          builder: (context) => SafeArea(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                ListTile(
                  leading: const Icon(Icons.photo_library_outlined),
                  title: const Text('Escolher da galeria'),
                  onTap: () => Navigator.of(context).pop(ImageSource.gallery),
                ),
                ListTile(
                  leading: const Icon(Icons.camera_alt_outlined),
                  title: const Text('Usar câmera'),
                  onTap: () => Navigator.of(context).pop(ImageSource.camera),
                ),
              ],
            ),
          ),
        );
        if (source == null || !mounted) return;
        await _pickAndUploadTeamImage(
          team,
          action == _TeamImageAction.avatar ? 'avatar' : 'capa',
          source,
        );
        break;
      case _TeamImageAction.removeAvatar:
      case _TeamImageAction.removeCover:
        await _removeTeamImage(
          team,
          action == _TeamImageAction.removeAvatar ? 'avatar' : 'capa',
        );
        break;
    }
  }

  Future<void> _pickAndUploadTeamImage(
    TeamDetail team,
    String type,
    ImageSource source,
  ) async {
    try {
      final photo = await ImagePicker().pickImage(
        source: source,
        maxWidth: 2048,
        maxHeight: 2048,
        imageQuality: 90,
      );
      if (photo == null || !mounted) return;
      final bytes = await photo.readAsBytes();
      if (!mounted) return;
      final cropped = await Navigator.of(context).push<Uint8List>(
        MaterialPageRoute(
          builder: (_) => PhotoCropScreen(
            image: bytes,
            aspectRatio: type == 'avatar' ? 1 : 16 / 9,
            title: type == 'avatar' ? 'Enquadrar foto' : 'Enquadrar capa',
          ),
        ),
      );
      if (cropped == null || !mounted) return;
      setState(() => _acting = true);
      final updated = await widget.repository.uploadImage(
        team.id,
        type,
        bytes: cropped,
      );
      if (!mounted) return;
      setState(() {
        _currentTeam = updated;
        _acting = false;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(type == 'avatar' ? 'Foto atualizada.' : 'Capa atualizada.')),
      );
    } catch (error) {
      if (!mounted) return;
      setState(() => _acting = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(apiErrorMessage(error))),
      );
    }
  }

  Future<void> _removeTeamImage(TeamDetail team, String type) async {
    final confirmed = await _confirmMembershipAction(
      title: type == 'avatar' ? 'Remover foto da equipe?' : 'Remover capa?',
      message: 'A imagem atual será removida da equipe.',
      confirmLabel: 'Remover',
    );
    if (!confirmed || !mounted) return;
    setState(() => _acting = true);
    try {
      final updated = await widget.repository.removeImage(team.id, type);
      if (!mounted) return;
      setState(() {
        _currentTeam = updated;
        _acting = false;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Imagem removida.')),
      );
    } catch (error) {
      if (!mounted) return;
      setState(() => _acting = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(apiErrorMessage(error))),
      );
    }
  }

  Future<void> _inviteMember(TeamDetail team) async {
    final invited = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      showDragHandle: true,
      builder: (_) => TeamInviteSheet(
        team: team,
        repository: widget.repository,
        usersRepository: widget.usersRepository,
      ),
    );
    if (invited == true && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Convite enviado.')),
      );
    }
  }

  Future<void> _respondInvite(TeamDetail team, {required bool accept}) async {
    setState(() => _acting = true);
    try {
      await widget.repository.decideInvite(team.id, accept: accept);
    } catch (error) {
      if (!mounted) return;
      setState(() => _acting = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(apiErrorMessage(error))),
      );
      return;
    }

    if (!mounted) return;
    if (!accept) {
      Navigator.of(context).pop();
      return;
    }
    try {
      await _reload();
    } catch (error, stackTrace) {
      debugPrint('Convite aceito, mas a equipe não recarregou: $error\n$stackTrace');
    }
    if (!mounted) return;
    setState(() => _acting = false);
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Você entrou na equipe.')),
    );
  }

  Future<void> _removeMember(
    TeamDetail team,
    TeamMember member,
  ) async {
    setState(() => _acting = true);
    try {
      await widget.repository.removeMember(team.id, member.userId);
    } catch (error) {
      if (!mounted) return;
      setState(() => _acting = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(apiErrorMessage(error))),
      );
      return;
    }

    if (!mounted) return;
    final updated = TeamDetail(
      id: team.id,
      name: team.name,
      slug: team.slug,
      visibility: team.visibility,
      memberCount: team.memberCount > 0 ? team.memberCount - 1 : 0,
      ownerId: team.ownerId,
      members: team.members
          .where((item) => item.userId != member.userId)
          .toList(growable: false),
      cars: team.cars
          .where((car) => car.ownerId != member.userId)
          .toList(growable: false),
      pendingRequests: team.pendingRequests,
      description: team.description,
      avatarUrl: team.avatarUrl,
      coverUrl: team.coverUrl,
      city: team.city,
      state: team.state,
      myRole: team.myRole,
      myRequest: team.myRequest,
      myInvite: team.myInvite,
    );
    setState(() {
      _currentTeam = updated;
      _acting = false;
    });
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Integrante removido.')),
    );
  }

  Future<void> _manageMember(
    TeamDetail team,
    TeamMember member,
  ) async {
    final action = await showModalBottomSheet<String>(
      context: context,
      showDragHandle: true,
      builder: (context) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              title: Text('@${member.username}'),
              subtitle: const Text('Gerenciar integrante'),
            ),
            for (final role in const [
              ('membro', 'Membro', Icons.person_outline),
              ('moderador', 'Moderador', Icons.gavel_outlined),
              ('administrador', 'Administrador', Icons.shield_outlined),
            ])
              RadioListTile<String>(
                value: role.$1,
                groupValue: member.role,
                title: Text(role.$2),
                secondary: Icon(role.$3),
                onChanged: (value) => Navigator.of(context).pop(value),
              ),
            const Divider(),
            ListTile(
              leading: Icon(
                Icons.person_remove_outlined,
                color: Theme.of(context).colorScheme.error,
              ),
              title: Text(
                'Remover da equipe',
                style: TextStyle(color: Theme.of(context).colorScheme.error),
              ),
              onTap: () => Navigator.of(context).pop('remover'),
            ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
    if (!mounted || action == null || action == member.role) return;
    if (action == 'remover') {
      final confirmed = await _confirmMembershipAction(
        title: 'Remover @${member.username}?',
        message:
            'A pessoa e o carro escolhido por ela serão removidos desta equipe.',
        confirmLabel: 'Remover',
      );
      if (!confirmed) return;
      await _removeMember(team, member);
      return;
    }
    await _act(
      () => widget.repository.updateMemberRole(
        team.id,
        member.userId,
        action,
      ),
      'Cargo atualizado.',
    );
  }

  Future<bool> _confirmMembershipAction({
    required String title,
    required String message,
    required String confirmLabel,
  }) async {
    return await showDialog<bool>(
          context: context,
          builder: (context) => AlertDialog(
            title: Text(title),
            content: Text(message),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(context).pop(false),
                child: const Text('Cancelar'),
              ),
              FilledButton(
                onPressed: () => Navigator.of(context).pop(true),
                child: Text(confirmLabel),
              ),
            ],
          ),
        ) ??
        false;
  }

  Future<void> _leaveTeam(TeamDetail team) async {
    final confirmed = await _confirmMembershipAction(
      title: 'Sair da equipe?',
      message:
          'Seu carro também deixará de aparecer na garagem coletiva desta equipe.',
      confirmLabel: 'Sair',
    );
    if (!confirmed) return;
    setState(() => _acting = true);
    try {
      await widget.repository.removeMember(team.id, widget.currentUserId);
      if (mounted) Navigator.of(context).pop();
    } catch (error) {
      if (!mounted) return;
      setState(() => _acting = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(apiErrorMessage(error))),
      );
    }
  }

  Future<void> _chooseCar(TeamDetail team) async {
    final ownCars = await widget.carsRepository.mine();
    if (!mounted) return;
    if (ownCars.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Adicione um carro à sua garagem primeiro.')),
      );
      return;
    }
    final selected = await showModalBottomSheet<String>(
      context: context,
      showDragHandle: true,
      builder: (context) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text('Carro na equipe', style: Theme.of(context).textTheme.titleLarge),
            const SizedBox(height: 8),
            for (final car in ownCars)
              ListTile(
                leading: const Icon(Icons.directions_car_outlined),
                title: Text([car.model, car.year].whereType<Object>().join(' ')),
                trailing: team.cars.any((item) => item.id == car.id)
                    ? const Icon(Icons.check)
                    : null,
                onTap: () => Navigator.pop(context, car.id),
              ),
            if (team.cars.any((car) => car.ownerId == widget.currentUserId))
              ListTile(
                leading: const Icon(Icons.remove_circle_outline),
                title: const Text('Não mostrar carro nesta equipe'),
                onTap: () => Navigator.pop(context, ''),
              ),
          ],
        ),
      ),
    );
    if (selected == null) return;
    await _act(
      () => selected.isEmpty
          ? widget.repository.removeSelectedCar(team.id)
          : widget.repository.selectCar(team.id, selected),
      selected.isEmpty ? 'Carro removido da equipe.' : 'Carro escolhido para a equipe.',
    );
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
          onOwnerTap: car.ownerId == widget.currentUserId
              ? null
              : () => _openProfile(car.ownerId),
        ),
      ),
    );
    if (mounted) await _reload();
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
        ),
      ),
    );
    if (mounted) await _reload();
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<TeamDetail>(
      future: _team,
      builder: (context, snapshot) {
        final team = _currentTeam ?? snapshot.data;
        return Scaffold(
          appBar: AppBar(
            title: Text(team?.name ?? 'Equipe'),
            scrolledUnderElevation: 0,
            actions: [
              if (team?.myRole == 'dono')
                IconButton(
                  tooltip: 'Editar equipe',
                  onPressed: _acting ? null : () => _editTeam(team!),
                  icon: const Icon(Icons.edit_outlined),
                ),
              if (team?.myRole == 'dono')
                IconButton(
                  tooltip: 'Imagens da equipe',
                  onPressed: _acting ? null : () => _showImageOptions(team!),
                  icon: const Icon(Icons.add_photo_alternate_outlined),
                ),
            ],
          ),
          body: snapshot.connectionState == ConnectionState.waiting &&
                  team == null
              ? const Center(child: CircularProgressIndicator())
              : snapshot.hasError && team == null
                  ? Center(
                      child: FilledButton(
                        onPressed: _reload,
                        child: Text(apiErrorMessage(snapshot.error!)),
                      ),
                    )
                  : RefreshIndicator(
                      onRefresh: _reload,
                      child: _content(team!),
                    ),
        );
      },
    );
  }

  Widget _content(TeamDetail team) {
    final colors = Theme.of(context).colorScheme;
    return ListView(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 40),
      children: [
        _TeamHero(team: team),
        const SizedBox(height: 16),
        if (team.myRole == null && team.myInvite == 'pendente') ...[
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: colors.primaryContainer.withValues(alpha: 0.45),
              borderRadius: BorderRadius.circular(18),
            ),
            child: const Row(
              children: [
                Icon(Icons.mail_outline_rounded),
                SizedBox(width: 12),
                Expanded(
                  child: Text(
                    'Você foi convidado para participar desta equipe.',
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(
                child: OutlinedButton(
                  onPressed: _acting
                      ? null
                      : () => _respondInvite(team, accept: false),
                  child: const Text('Recusar'),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: FilledButton(
                  onPressed: _acting
                      ? null
                      : () => _respondInvite(team, accept: true),
                  child: const Text('Aceitar convite'),
                ),
              ),
            ],
          ),
        ],
        if (team.myRole == null &&
            team.myRequest != 'pendente' &&
            team.myInvite != 'pendente')
          FilledButton.icon(
            onPressed: _acting
                ? null
                : () => _act(
                      () => widget.repository.requestEntry(team.id),
                      'Pedido enviado. Aguarde a aprovação da equipe.',
                    ),
            icon: const Icon(Icons.person_add_alt_1),
            label: const Text('Pedir para entrar'),
          ),
        if (team.myRole == null && team.myRequest == 'pendente')
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: colors.tertiaryContainer.withValues(alpha: 0.45),
              borderRadius: BorderRadius.circular(18),
            ),
            child: const Row(
              children: [
                Icon(Icons.schedule),
                SizedBox(width: 12),
                Expanded(
                  child: Text(
                    'Seu pedido está com a equipe. Você poderá escolher um carro depois da aprovação.',
                  ),
                ),
              ],
            ),
          ),
        if (team.myRole != null)
          FilledButton.tonalIcon(
            onPressed: _acting ? null : () => _chooseCar(team),
            icon: const Icon(Icons.swap_horiz),
            label: Text(
              team.cars.any((car) => car.ownerId == widget.currentUserId)
                  ? 'Trocar meu carro na equipe'
                  : 'Escolher meu carro para a equipe',
            ),
          ),
        if (team.myRole == 'dono' || team.myRole == 'administrador') ...[
          const SizedBox(height: 10),
          OutlinedButton.icon(
            onPressed: _acting ? null : () => _inviteMember(team),
            icon: const Icon(Icons.person_add_alt_1_rounded),
            label: const Text('Convidar integrante'),
          ),
        ],
        if (team.myRole != null && team.myRole != 'dono') ...[
          const SizedBox(height: 10),
          TextButton.icon(
            onPressed: _acting ? null : () => _leaveTeam(team),
            icon: const Icon(Icons.logout_rounded),
            label: const Text('Sair da equipe'),
          ),
        ],
        if (team.pendingRequests.isNotEmpty) ...[
          const SizedBox(height: 24),
          _SectionHeader(
            eyebrow: 'GESTÃO',
            title: 'Pedidos de entrada',
            trailing: '${team.pendingRequests.length}',
          ),
          const SizedBox(height: 12),
          for (final request in team.pendingRequests)
            _RequestCard(
              request: request,
              acting: _acting,
              onReject: () => _act(
                () => widget.repository.decideRequest(
                  team.id,
                  request.id,
                  approve: false,
                ),
                'Pedido recusado.',
              ),
              onApprove: () => _act(
                () => widget.repository.decideRequest(
                  team.id,
                  request.id,
                  approve: true,
                ),
                'Novo integrante aprovado.',
              ),
            ),
        ],
        const SizedBox(height: 28),
        _SectionHeader(
          eyebrow: 'PROJETOS ESCOLHIDOS',
          title: 'Garagem da equipe',
          trailing: '${team.cars.length}',
        ),
        const SizedBox(height: 6),
        Text(
          'Cada integrante decide qual máquina representa seu projeto aqui.',
          style: TextStyle(color: colors.onSurfaceVariant),
        ),
        const SizedBox(height: 14),
        if (team.cars.isEmpty)
          Container(
            padding: const EdgeInsets.all(28),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(24),
              border: Border.all(color: colors.outlineVariant),
              gradient: LinearGradient(
                colors: [
                  colors.surfaceContainerHigh,
                  colors.surfaceContainer,
                ],
              ),
            ),
            child: const Column(
              children: [
                Icon(Icons.sports_motorsports_outlined, size: 46),
                SizedBox(height: 12),
                Text(
                  'A garagem ainda está vazia',
                  style: TextStyle(fontWeight: FontWeight.bold),
                ),
                SizedBox(height: 6),
                Text(
                  'Os carros escolhidos pelos integrantes aparecerão juntos aqui.',
                  textAlign: TextAlign.center,
                ),
              ],
            ),
          )
        else
          SizedBox(
            height: 250,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              itemCount: team.cars.length,
              separatorBuilder: (_, __) => const SizedBox(width: 12),
              itemBuilder: (context, index) {
                final car = team.cars[index];
                return _TeamCarCard(
                  car: car,
                  onTap: () => _openCar(car),
                );
              },
            ),
          ),
        const SizedBox(height: 28),
        _SectionHeader(
          eyebrow: 'PESSOAS',
          title: 'Integrantes',
          trailing: '${team.memberCount}',
        ),
        const SizedBox(height: 12),
        AnimatedSize(
          duration: const Duration(milliseconds: 240),
          curve: Curves.easeOutCubic,
          alignment: Alignment.topCenter,
          child: Container(
            decoration: BoxDecoration(
              color: colors.surfaceContainer,
              borderRadius: BorderRadius.circular(22),
            ),
            clipBehavior: Clip.antiAlias,
            child: Column(
              children: [
                for (var index = 0; index < team.members.length; index++) ...[
                  _MemberTile(
                    key: ValueKey(team.members[index].userId),
                    member: team.members[index],
                    canManageRole: team.myRole == 'dono' &&
                        team.members[index].role != 'dono',
                    onTap: () => _openProfile(team.members[index].userId),
                    onRoleTap: () => _manageMember(team, team.members[index]),
                  ),
                  if (index != team.members.length - 1)
                    Divider(height: 1, color: colors.outlineVariant),
                ],
              ],
            ),
          ),
        ),
      ],
    );
  }
}

final class _TeamHero extends StatelessWidget {
  const _TeamHero({required this.team});

  final TeamDetail team;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.all(22),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(28),
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            colors.primaryContainer,
            colors.surfaceContainerHigh,
          ],
        ),
        border: Border.all(color: colors.primary.withValues(alpha: 0.28)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (team.coverUrl != null) ...[
            ClipRRect(
              borderRadius: BorderRadius.circular(18),
              child: Image.network(
                team.coverUrl!,
                width: double.infinity,
                height: 150,
                fit: BoxFit.cover,
                errorBuilder: (_, __, ___) => SizedBox(
                  height: 150,
                  child: Center(
                    child: Icon(Icons.panorama_outlined, color: colors.onSurface),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 18),
          ],
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 72,
                height: 72,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: colors.primary.withValues(alpha: 0.18),
                  borderRadius: BorderRadius.circular(22),
                  border: Border.all(
                    color: colors.primary.withValues(alpha: 0.3),
                  ),
                ),
                clipBehavior: Clip.antiAlias,
                child: team.avatarUrl == null
                    ? Text(
                        team.name.substring(0, 1).toUpperCase(),
                        style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                              fontWeight: FontWeight.w900,
                            ),
                      )
                    : Image.network(
                        team.avatarUrl!,
                        width: 72,
                        height: 72,
                        fit: BoxFit.cover,
                        errorBuilder: (_, __, ___) => Text(
                          team.name.substring(0, 1).toUpperCase(),
                        ),
                      ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: [
                        _StatusPill(
                          icon: team.visibility == 'publica'
                              ? Icons.public
                              : Icons.lock_outline,
                          label: team.visibility == 'publica'
                              ? 'Pública'
                              : 'Privada',
                        ),
                        if (team.myRole != null)
                          _StatusPill(
                            icon: Icons.shield_outlined,
                            label: _roleName(team.myRole!),
                            highlighted: true,
                          ),
                      ],
                    ),
                    const SizedBox(height: 10),
                    Text(
                      team.name,
                      style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                            fontWeight: FontWeight.w900,
                          ),
                    ),
                    if (team.location != null) ...[
                      const SizedBox(height: 5),
                      Row(
                        children: [
                          const Icon(Icons.location_on_outlined, size: 16),
                          const SizedBox(width: 4),
                          Expanded(child: Text(team.location!)),
                        ],
                      ),
                    ],
                  ],
                ),
              ),
            ],
          ),
          if (team.description != null) ...[
            const SizedBox(height: 18),
            Text(
              team.description!,
              style: TextStyle(color: colors.onSurfaceVariant, height: 1.45),
            ),
          ],
          const SizedBox(height: 20),
          Row(
            children: [
              Expanded(
                child: _TeamStat(
                  icon: Icons.people_outline,
                  value: '${team.memberCount}',
                  label: 'integrantes',
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _TeamStat(
                  icon: Icons.directions_car_outlined,
                  value: '${team.cars.length}',
                  label: 'projetos',
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

String _roleName(String role) => switch (role) {
      'dono' => 'Dono',
      'administrador' => 'Administrador',
      'moderador' => 'Moderador',
      _ => 'Membro',
    };

final class _StatusPill extends StatelessWidget {
  const _StatusPill({
    required this.icon,
    required this.label,
    this.highlighted = false,
  });

  final IconData icon;
  final String label;
  final bool highlighted;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 6),
      decoration: BoxDecoration(
        color: highlighted
            ? colors.primary.withValues(alpha: 0.16)
            : colors.surface.withValues(alpha: 0.45),
        borderRadius: BorderRadius.circular(99),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: highlighted ? colors.primary : null),
          const SizedBox(width: 5),
          Text(label, style: Theme.of(context).textTheme.labelMedium),
        ],
      ),
    );
  }
}

final class _TeamStat extends StatelessWidget {
  const _TeamStat({
    required this.icon,
    required this.value,
    required this.label,
  });

  final IconData icon;
  final String value;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(13),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface.withValues(alpha: 0.4),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        children: [
          Icon(icon, size: 20),
          const SizedBox(width: 10),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(value, style: const TextStyle(fontWeight: FontWeight.w900)),
              Text(label, style: Theme.of(context).textTheme.labelSmall),
            ],
          ),
        ],
      ),
    );
  }
}

final class _SectionHeader extends StatelessWidget {
  const _SectionHeader({
    required this.eyebrow,
    required this.title,
    required this.trailing,
  });

  final String eyebrow;
  final String title;
  final String trailing;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Row(
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                eyebrow,
                style: Theme.of(context).textTheme.labelSmall?.copyWith(
                      color: colors.primary,
                      fontWeight: FontWeight.w900,
                      letterSpacing: 1.1,
                    ),
              ),
              const SizedBox(height: 3),
              Text(title, style: Theme.of(context).textTheme.titleLarge),
            ],
          ),
        ),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
          decoration: BoxDecoration(
            color: colors.surfaceContainerHighest,
            borderRadius: BorderRadius.circular(99),
          ),
          child: Text(trailing),
        ),
      ],
    );
  }
}

final class _RequestCard extends StatelessWidget {
  const _RequestCard({
    required this.request,
    required this.acting,
    required this.onReject,
    required this.onApprove,
  });

  final TeamRequest request;
  final bool acting;
  final VoidCallback onReject;
  final VoidCallback onApprove;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: colors.surfaceContainer,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: colors.primary.withValues(alpha: 0.22)),
      ),
      child: Column(
        children: [
          Row(
            children: [
              CircleAvatar(
                backgroundImage: request.avatarUrl == null
                    ? null
                    : NetworkImage(request.avatarUrl!),
                child: request.avatarUrl == null
                    ? Text(request.name.substring(0, 1).toUpperCase())
                    : null,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      request.name,
                      style: const TextStyle(fontWeight: FontWeight.bold),
                    ),
                    Text('@${request.username}'),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: OutlinedButton(
                  onPressed: acting ? null : onReject,
                  child: const Text('Recusar'),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: FilledButton(
                  onPressed: acting ? null : onApprove,
                  child: const Text('Aprovar'),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

final class _MemberTile extends StatelessWidget {
  const _MemberTile({
    required this.member,
    required this.canManageRole,
    required this.onTap,
    required this.onRoleTap,
    super.key,
  });

  final TeamMember member;
  final bool canManageRole;
  final VoidCallback onTap;
  final VoidCallback onRoleTap;

  @override
  Widget build(BuildContext context) {
    return ListTile(
      onTap: onTap,
      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 5),
      leading: CircleAvatar(
        backgroundImage:
            member.avatarUrl == null ? null : NetworkImage(member.avatarUrl!),
        child: member.avatarUrl == null
            ? Text(member.name.substring(0, 1).toUpperCase())
            : null,
      ),
      title: Text(member.name),
      subtitle: Text('@${member.username}'),
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          _StatusPill(
            icon: member.role == 'dono'
                ? Icons.star_outline
                : member.role == 'administrador'
                    ? Icons.shield_outlined
                    : member.role == 'moderador'
                        ? Icons.gavel_outlined
                        : Icons.person_outline,
            label: _roleName(member.role),
            highlighted: member.role != 'membro',
          ),
          if (canManageRole) ...[
            const SizedBox(width: 4),
            IconButton(
              tooltip: 'Alterar cargo',
              onPressed: onRoleTap,
              icon: const Icon(Icons.manage_accounts_outlined),
            ),
          ],
        ],
      ),
    );
  }
}

final class _TeamCarCard extends StatelessWidget {
  const _TeamCarCard({required this.car, required this.onTap});

  final Car car;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return SizedBox(
      width: 250,
      child: Card(
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            SizedBox(
              height: 150,
              child: car.photoUrl == null
                  ? ColoredBox(
                      color: colors.surfaceContainerHighest,
                      child: const Icon(Icons.directions_car, size: 48),
                    )
                  : Image.network(
                      car.photoUrl!,
                      fit: BoxFit.cover,
                      errorBuilder: (_, __, ___) => ColoredBox(
                        color: colors.surfaceContainerHighest,
                        child: const Icon(Icons.broken_image_outlined),
                      ),
                    ),
            ),
            Expanded(
              child: Padding(
                padding: const EdgeInsets.all(14),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            [car.model, car.year]
                                .whereType<Object>()
                                .join(' '),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: Theme.of(context).textTheme.titleMedium?.copyWith(
                                  fontWeight: FontWeight.w800,
                                ),
                          ),
                        ),
                        const Icon(Icons.arrow_outward, size: 18),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '@${car.ownerUsername}',
                      style: TextStyle(color: colors.onSurfaceVariant),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
      ),
    );
  }
}
