import 'package:flutter/material.dart';
import 'package:garagem_mobile/features/evolutions/evolution.dart';
import 'package:garagem_mobile/features/evolutions/evolution_gallery.dart';

enum EvolutionJournalAction { edit, photos, delete }

double evolutionJournalCardHeight(BuildContext context) {
  final scale = MediaQuery.textScalerOf(context).scale(16) / 16;
  return 420 + (scale - 1).clamp(0.0, 2.0) * 160;
}

class EvolutionJournalCard extends StatelessWidget {
  const EvolutionJournalCard({
    required this.evolution,
    required this.date,
    required this.onOpen,
    this.mileage,
    this.onManage,
    super.key,
  });

  final Evolution evolution;
  final String date;
  final String? mileage;
  final VoidCallback onOpen;
  final ValueChanged<EvolutionJournalAction>? onManage;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    return SizedBox(
      height: evolutionJournalCardHeight(context),
      child: Container(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 10),
        decoration: BoxDecoration(
          color: colors.surfaceContainer,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: colors.outlineVariant),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Expanded(
                  child: Wrap(
                    spacing: 8,
                    runSpacing: 4,
                    crossAxisAlignment: WrapCrossAlignment.center,
                    children: [
                      Text(date, style: theme.textTheme.labelMedium),
                      if (evolution.category != null)
                        Text(
                          '· ${evolutionCategoryLabels[evolution.category] ?? evolution.category}',
                          style: theme.textTheme.labelMedium?.copyWith(
                            color: colors.primary,
                          ),
                        ),
                    ],
                  ),
                ),
                if (onManage != null)
                  PopupMenuButton<EvolutionJournalAction>(
                    tooltip: 'Opções da evolução',
                    onSelected: onManage,
                    itemBuilder: (_) => [
                      const PopupMenuItem(
                        value: EvolutionJournalAction.edit,
                        child: ListTile(
                          leading: Icon(Icons.edit_outlined),
                          title: Text('Editar'),
                        ),
                      ),
                      PopupMenuItem(
                        value: EvolutionJournalAction.photos,
                        child: ListTile(
                          leading: const Icon(Icons.photo_library_outlined),
                          title: Text(evolution.photos.isEmpty
                              ? 'Adicionar fotos'
                              : 'Gerenciar fotos'),
                        ),
                      ),
                      const PopupMenuItem(
                        value: EvolutionJournalAction.delete,
                        child: ListTile(
                          leading: Icon(Icons.delete_outline),
                          title: Text('Excluir'),
                        ),
                      ),
                    ],
                  ),
              ],
            ),
            InkWell(
              onTap: onOpen,
              borderRadius: BorderRadius.circular(8),
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 6),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(evolution.title,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: theme.textTheme.titleLarge?.copyWith(
                          fontWeight: FontWeight.w700,
                          height: 1.15,
                        )),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 12),
            Expanded(
              child: evolution.photos.isNotEmpty
                  ? LayoutBuilder(
                      builder: (context, constraints) => Center(
                            child: ClipRRect(
                              borderRadius: BorderRadius.circular(12),
                              child: Stack(
                                children: [
                                  EvolutionPhotoFrame(
                                    image: NetworkImage(
                                        evolution.photos.first.url),
                                    label: 'Foto de ${evolution.title}',
                                    maxHeight:
                                        constraints.maxHeight.clamp(1.0, 260.0),
                                    onTap: onOpen,
                                  ),
                                  Positioned(
                                    right: 8,
                                    bottom: 8,
                                    child: DecoratedBox(
                                      decoration: BoxDecoration(
                                          color: colors.surface
                                              .withValues(alpha: .9),
                                          borderRadius:
                                              BorderRadius.circular(8)),
                                      child: Padding(
                                        padding: const EdgeInsets.symmetric(
                                            horizontal: 8, vertical: 5),
                                        child: Text(
                                            evolution.photos.length == 1
                                                ? '1 foto'
                                                : '${evolution.photos.length} fotos',
                                            style: theme.textTheme.labelSmall),
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ))
                  : InkWell(
                      onTap: onOpen,
                      borderRadius: BorderRadius.circular(12),
                      child: Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(18),
                        decoration: BoxDecoration(
                            color: colors.surfaceContainerHigh,
                            borderRadius: BorderRadius.circular(12)),
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Icon(Icons.auto_stories_outlined,
                                color: colors.primary, size: 26),
                            const SizedBox(height: 12),
                            Flexible(
                                child: Text(evolution.description,
                                    maxLines: 4,
                                    overflow: TextOverflow.ellipsis,
                                    style: theme.textTheme.bodyMedium
                                        ?.copyWith(height: 1.4))),
                          ],
                        ),
                      ),
                    ),
            ),
            const SizedBox(height: 8),
            Divider(height: 1, color: colors.outlineVariant),
            const SizedBox(height: 4),
            Wrap(
              alignment: WrapAlignment.spaceBetween,
              crossAxisAlignment: WrapCrossAlignment.center,
              spacing: 12,
              children: [
                if (mileage != null)
                  Row(mainAxisSize: MainAxisSize.min, children: [
                    Icon(Icons.speed_outlined,
                        size: 16, color: colors.onSurfaceVariant),
                    const SizedBox(width: 6),
                    Text(mileage!, style: theme.textTheme.labelMedium),
                  ]),
                TextButton.icon(
                  onPressed: onOpen,
                  icon: const Icon(Icons.arrow_forward_rounded, size: 17),
                  label: const Text('Ver evolução'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
