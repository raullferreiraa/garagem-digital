import 'package:flutter/material.dart';
import 'package:garona_mobile/core/widgets/garona_ui.dart';
import 'package:garona_mobile/core/widgets/garona_premium.dart';
import 'package:garona_mobile/features/cars/car.dart';

/// A garage cover in discovery, and a compact vehicle entry in collections.
class GaronaProjectCard extends StatelessWidget {
  const GaronaProjectCard(
      {required this.car,
      required this.onTap,
      this.highlighted = false,
      this.compact = false,
      super.key});
  final Car car;
  final VoidCallback onTap;
  final bool highlighted, compact;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    final specs = <String>[
      if (car.engine?.trim().isNotEmpty ?? false) car.engine!,
      if (car.estimatedPower?.trim().isNotEmpty ?? false) car.estimatedPower!,
      if (car.color?.trim().isNotEmpty ?? false) car.color!,
    ];
    final identity =
        Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Text(highlighted ? 'SEU PROJETO' : '@${car.ownerUsername}',
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: theme.textTheme.labelSmall
              ?.copyWith(color: colors.onSurfaceVariant, letterSpacing: .5)),
      const SizedBox(height: 6),
      Text(car.displayName,
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
          style: theme.textTheme.titleLarge?.copyWith(
              fontFamily: 'BarlowCondensed',
              fontSize: 27,
              fontWeight: FontWeight.w700)),
      if (car.projectName != null)
        Text(car.model,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: theme.textTheme.bodySmall),
      if (car.year != null)
        Text('${car.year}',
            style:
                theme.textTheme.labelMedium?.copyWith(color: colors.secondary)),
      const SizedBox(height: 8),
      Row(children: [
        Expanded(
            child: Text('Abrir projeto', style: theme.textTheme.labelMedium)),
        Icon(Icons.north_east, size: 18, color: colors.primary)
      ]),
    ]);
    if (compact) {
      return Material(
          color: colors.surfaceContainerLow,
          borderRadius: BorderRadius.circular(20),
          clipBehavior: Clip.antiAlias,
          child: InkWell(
              onTap: onTap,
              child: Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: colors.outlineVariant)),
                child: LayoutBuilder(builder: (context, box) {
                  final narrow = box.maxWidth < 280 ||
                      MediaQuery.textScalerOf(context).scale(14) > 18;
                  final photo = ClipRRect(
                      borderRadius: BorderRadius.circular(12),
                      child: AspectRatio(
                          aspectRatio: 1.15,
                          child: GaronaImage(
                              url: car.photoUrl,
                              fit: BoxFit.contain,
                              semanticLabel: car.model)));
                  if (narrow)
                    return Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          SizedBox(height: 130, child: photo),
                          const SizedBox(height: 12),
                          identity
                        ]);
                  return Row(
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: [
                        SizedBox(width: box.maxWidth * .38, child: photo),
                        const SizedBox(width: 16),
                        Expanded(child: identity),
                      ]);
                }),
              )));
    }
    return Material(
        color: colors.surface,
        borderRadius: BorderRadius.circular(24),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
            onTap: onTap,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                LayoutBuilder(builder: (context, box) {
                  final scale = MediaQuery.textScalerOf(context).scale(16) / 16;
                  return SizedBox(
                      height: box.maxWidth * .92 + (scale - 1).clamp(0, 2) * 90,
                      child: Stack(fit: StackFit.expand, children: [
                        GaronaImage(
                            url: car.photoUrl, semanticLabel: car.model),
                        DecoratedBox(
                            decoration: BoxDecoration(
                                gradient: LinearGradient(
                                    begin: Alignment.topCenter,
                                    end: Alignment.bottomCenter,
                                    colors: [
                              colors.surfaceContainerLowest
                                  .withValues(alpha: .27),
                              colors.surfaceContainerLowest
                                  .withValues(alpha: 0),
                              colors.surfaceContainerLowest
                                  .withValues(alpha: .96)
                            ],
                                    stops: [
                              0,
                              .32,
                              1
                            ]))),
                        Positioned(
                            top: 18,
                            left: 18,
                            right: 18,
                            child: Row(children: [
                              const GaronaLightSignature(width: 24),
                              const SizedBox(width: 8),
                              Expanded(
                                  child: Text(
                                      highlighted
                                          ? 'SEU PROJETO'
                                          : 'GARONA / GARAGENS',
                                      style: theme.textTheme.labelSmall
                                          ?.copyWith(
                                              color: colors.onSurface,
                                              letterSpacing: 2))),
                              if (car.year != null)
                                Text('${car.year}',
                                    style: TextStyle(
                                        fontFamily: 'BarlowCondensed',
                                        fontSize: 24,
                                        color: colors.onSurface)),
                            ])),
                        Positioned(
                            left: 18,
                            right: 18,
                            bottom: 20,
                            child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text('@${car.ownerUsername}',
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      style: theme.textTheme.labelSmall
                                          ?.copyWith(
                                              color: colors.onSurfaceVariant)),
                                  const SizedBox(height: 8),
                                  Text(car.displayName,
                                      maxLines: 2,
                                      overflow: TextOverflow.ellipsis,
                                      style: TextStyle(
                                          fontFamily: 'BarlowCondensed',
                                          fontSize: 38,
                                          fontWeight: FontWeight.w600,
                                          height: .98,
                                          color: colors.onSurface)),
                                  if (car.projectName != null)
                                    Text(car.model,
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis),
                                  if (car.projectStatus?.trim().isNotEmpty ??
                                      false) ...[
                                    const SizedBox(height: 10),
                                    Text(car.projectStatus!,
                                        style: theme.textTheme.labelMedium
                                            ?.copyWith(
                                                color: colors.secondary)),
                                  ],
                                ])),
                      ]));
                }),
                Padding(
                    padding: const EdgeInsets.fromLTRB(18, 16, 18, 18),
                    child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          if (specs.isNotEmpty)
                            Text(specs.join('  ·  '),
                                style: theme.textTheme.labelMedium
                                    ?.copyWith(color: colors.secondary)),
                          if (car.history?.trim().isNotEmpty ?? false) ...[
                            const SizedBox(height: 10),
                            Text(car.history!,
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                                style: theme.textTheme.bodyMedium),
                          ],
                          const SizedBox(height: 14),
                          SizedBox(
                              width: double.infinity,
                              child: Wrap(
                                  alignment: WrapAlignment.spaceBetween,
                                  crossAxisAlignment: WrapCrossAlignment.center,
                                  spacing: 12,
                                  runSpacing: 8,
                                  children: [
                                    Text('Abrir projeto',
                                        style: theme.textTheme.labelLarge),
                                    if (car.likesCount > 0)
                                      _ProjectMetric(
                                          icon: Icons.favorite_border,
                                          count: car.likesCount,
                                          label: car.likesCount == 1
                                              ? 'curtida'
                                              : 'curtidas'),
                                    if (car.commentsCount > 0)
                                      _ProjectMetric(
                                          icon: Icons.chat_bubble_outline,
                                          count: car.commentsCount,
                                          label: car.commentsCount == 1
                                              ? 'comentário'
                                              : 'comentários'),
                                    Icon(Icons.north_east,
                                        color: colors.primary, size: 22),
                                  ])),
                        ])),
              ],
            )));
  }
}

class _ProjectMetric extends StatelessWidget {
  const _ProjectMetric(
      {required this.icon, required this.count, required this.label});
  final IconData icon;
  final int count;
  final String label;

  @override
  Widget build(BuildContext context) => Semantics(
      label: '$count $label',
      excludeSemantics: true,
      child: Row(mainAxisSize: MainAxisSize.min, children: [
        Icon(icon,
            size: 16, color: Theme.of(context).colorScheme.onSurfaceVariant),
        const SizedBox(width: 4),
        Text('$count'),
      ]));
}
